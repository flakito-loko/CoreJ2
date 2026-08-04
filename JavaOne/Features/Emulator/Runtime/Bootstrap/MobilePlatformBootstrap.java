package org.javaone.freej2me;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.security.Permission;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.recompile.mobile.Mobile;
import org.recompile.mobile.MobilePlatform;

/**
 * JavaOne-owned host bootstrap for FreeJ2ME {@link MobilePlatform}.
 *
 * <p>Lives outside {@code Vendor/FreeJ2ME}. Invoked by
 * {@code FreeJ2MERuntimeAdapter} via a host JVM process until an embedded
 * iOS Java runtime exists.
 *
 * <p>Usage:
 * <ul>
 *   <li>{@code MobilePlatformBootstrap <width> <height>} — create platform only</li>
 *   <li>{@code MobilePlatformBootstrap <width> <height> register-painter} —
 *       install capturing painter, mutate LCD, invoke painter twice, emit
 *       {@code FRAME} metadata (no SwiftUI / Metal / RuntimeEvent)</li>
 *   <li>{@code MobilePlatformBootstrap <width> <height> load-jar <fileURL>}</li>
 *   <li>{@code MobilePlatformBootstrap <width> <height> run-jar <fileURL>}</li>
 * </ul>
 */
public final class MobilePlatformBootstrap {

    private static final AtomicBoolean allowProcessExit = new AtomicBoolean(false);

    private MobilePlatformBootstrap() {}

    public static void main(String[] args) {
        installExitGuard();

        if (args.length < 2) {
            System.err.println(
                "usage: MobilePlatformBootstrap <lcdWidth> <lcdHeight>"
                    + " [register-painter <frameDir> | load-jar <fileURL> | run-jar <fileURL>]"
            );
            exitProcess(1);
        }

        final int width = Integer.parseInt(args[0]);
        final int height = Integer.parseInt(args[1]);
        final String mode = args.length >= 3 ? args[2] : null;

        final MobilePlatform platform = new MobilePlatform(width, height);
        Mobile.setPlatform(platform);

        if (Mobile.getPlatform() == null) {
            System.err.println("Mobile.getPlatform() returned null");
            exitProcess(2);
        }
        if (Mobile.getPlatform().lcdWidth != width || Mobile.getPlatform().lcdHeight != height) {
            System.err.println("LCD size mismatch");
            exitProcess(3);
        }

        final BufferedImage lcd = Mobile.getPlatform().getLCD();
        if (lcd == null || lcd.getWidth() != width || lcd.getHeight() != height) {
            System.err.println("getLCD() buffer invalid");
            exitProcess(4);
        }

        if (mode == null) {
            System.out.println("OK " + width + "x" + height);
            exitProcess(0);
        }

        if ("register-painter".equals(mode)) {
            if (args.length < 4) {
                System.err.println("usage: ... register-painter <frameOutputDir>");
                exitProcess(1);
            }
            registerPainterWithFrameCapture(platform, args[3]);
            exitProcess(0);
        }

        if ("load-jar".equals(mode)) {
            if (args.length < 4) {
                System.err.println("usage: ... load-jar <fileURL>");
                exitProcess(1);
            }
            final String midletName = loadJar(platform, args[3]);
            System.out.println("LOAD_JAR_OK " + midletName);
            exitProcess(0);
        }

        if ("run-jar".equals(mode)) {
            if (args.length < 4) {
                System.err.println("usage: ... run-jar <fileURL>");
                exitProcess(1);
            }
            runJarSequence(platform, args[3]);
            return;
        }

        System.err.println("Unknown mode: " + mode);
        exitProcess(1);
    }

    /**
     * Installs the official {@code setPainter} hook. On each {@code painter.run()}
     * the callback reads {@link MobilePlatform#getLCD()}, copies every ARGB pixel
     * to an independent file under {@code frameOutputDir}, and emits a {@code FRAME}
     * line (no SwiftUI / Metal).
     *
     * <p>Invokes the painter twice with distinct LCD contents so Swift can confirm
     * updated framebuffers and publish multiple {@code frameAvailable} events.
     */
    private static void registerPainterWithFrameCapture(
        MobilePlatform platform,
        String frameOutputDir
    ) {
        final java.io.File outputDir = new java.io.File(frameOutputDir);
        if (!outputDir.isDirectory() && !outputDir.mkdirs()) {
            System.err.println("Cannot create frame output directory: " + frameOutputDir);
            exitProcess(8);
        }

        final AtomicInteger paintEvents = new AtomicInteger(0);
        final AtomicInteger lastPixelCount = new AtomicInteger(0);
        final long[] checksums = new long[8];
        final AtomicInteger checksumCount = new AtomicInteger(0);

        platform.setPainter(new Runnable() {
            @Override
            public void run() {
                final int index = paintEvents.incrementAndGet();
                final FrameSnapshot snap = captureFrame(platform, index, outputDir);
                lastPixelCount.set(snap.pixelCount);
                final int slot = checksumCount.getAndIncrement();
                if (slot < checksums.length) {
                    checksums[slot] = snap.checksum;
                }
                System.out.println(
                    "FRAME "
                        + snap.paintIndex + " "
                        + snap.width + " "
                        + snap.height + " "
                        + snap.pixelCount + " "
                        + Long.toUnsignedString(snap.checksum) + " "
                        + snap.pixelFormat + " "
                        + snap.pixelFile.getAbsolutePath()
                );
            }
        });

        // Distinct framebuffer contents → distinct checksums across painter runs.
        fillLCD(platform, new Color(0xE11D48)); // rose
        platform.painter.run();
        fillLCD(platform, new Color(0x2563EB)); // blue
        platform.painter.run();

        if (paintEvents.get() < 2) {
            System.err.println("Painter callback did not execute twice");
            exitProcess(5);
        }
        if (checksumCount.get() < 2 || checksums[0] == checksums[1]) {
            System.err.println("Framebuffers did not change between painter callbacks");
            exitProcess(6);
        }
        if (lastPixelCount.get() != platform.lcdWidth * platform.lcdHeight) {
            System.err.println("Pixel count mismatch");
            exitProcess(7);
        }

        System.out.println("PAINTER_OK " + paintEvents.get());
        System.out.println("FRAME_CAPTURE_OK " + paintEvents.get());
    }

    /** Capturing painter for run-jar (frames emitted only if FreeJ2ME paints). */
    private static void installCapturingPainter(MobilePlatform platform) {
        final AtomicInteger paintEvents = new AtomicInteger(0);
        final java.io.File outputDir = new java.io.File(
            System.getProperty("java.io.tmpdir"),
            "javaone-runjar-frames-" + System.nanoTime()
        );
        outputDir.mkdirs();
        platform.setPainter(new Runnable() {
            @Override
            public void run() {
                final int index = paintEvents.incrementAndGet();
                final FrameSnapshot snap = captureFrame(platform, index, outputDir);
                System.out.println(
                    "FRAME "
                        + snap.paintIndex + " "
                        + snap.width + " "
                        + snap.height + " "
                        + snap.pixelCount + " "
                        + Long.toUnsignedString(snap.checksum) + " "
                        + snap.pixelFormat + " "
                        + snap.pixelFile.getAbsolutePath()
                );
            }
        });
    }

    private static FrameSnapshot captureFrame(
        MobilePlatform platform,
        int paintIndex,
        java.io.File outputDir
    ) {
        // Official FreeJ2ME framebuffer accessor.
        final BufferedImage lcd = platform.getLCD();
        if (lcd == null) {
            throw new IllegalStateException("getLCD() returned null");
        }
        final int width = lcd.getWidth();
        final int height = lcd.getHeight();
        if (width != platform.lcdWidth || height != platform.lcdHeight) {
            throw new IllegalStateException(
                "LCD size mismatch: " + width + "x" + height
                    + " vs platform " + platform.lcdWidth + "x" + platform.lcdHeight
            );
        }

        final int pixelCount = width * height;
        final int[] pixels = new int[pixelCount];
        // TYPE_INT_ARGB packed pixels — proves the buffer is readable.
        lcd.getRGB(0, 0, width, height, pixels, 0, width);

        long checksum = 0xcbf29ce484222325L;
        for (int i = 0; i < pixels.length; i++) {
            checksum ^= (pixels[i] & 0xffffffffL);
            checksum *= 0x100000001b3L;
        }

        final java.io.File pixelFile = new java.io.File(outputDir, "frame-" + paintIndex + ".argb");
        writeLittleEndianARGB(pixelFile, pixels);

        final String pixelFormat = pixelFormatName(lcd.getType());
        return new FrameSnapshot(
            paintIndex,
            width,
            height,
            pixelCount,
            checksum,
            pixelFormat,
            pixelFile
        );
    }

    /** Writes an independent LE ARGB8888 copy — FreeJ2ME heap is not shared with Swift. */
    private static void writeLittleEndianARGB(java.io.File file, int[] pixels) {
        final java.nio.ByteBuffer buffer = java.nio.ByteBuffer
            .allocate(pixels.length * 4)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        for (int pixel : pixels) {
            buffer.putInt(pixel);
        }
        try {
            java.nio.file.Files.write(file.toPath(), buffer.array());
        } catch (java.io.IOException ex) {
            throw new IllegalStateException("Failed to write frame pixels: " + file, ex);
        }
    }

    private static void fillLCD(MobilePlatform platform, Color color) {
        final BufferedImage lcd = platform.getLCD();
        final Graphics2D g = lcd.createGraphics();
        try {
            g.setColor(color);
            g.fillRect(0, 0, lcd.getWidth(), lcd.getHeight());
        } finally {
            g.dispose();
        }
    }

    private static String pixelFormatName(int type) {
        if (type == BufferedImage.TYPE_INT_ARGB) {
            return "TYPE_INT_ARGB";
        }
        if (type == BufferedImage.TYPE_INT_RGB) {
            return "TYPE_INT_RGB";
        }
        return "TYPE_" + type;
    }

    private static String loadJar(MobilePlatform platform, String jarURL) {
        final boolean loaded;
        try {
            loaded = platform.loadJar(jarURL);
        } catch (Throwable t) {
            System.out.println("LOAD_JAR_FAIL");
            System.err.println(t.getMessage());
            exitProcess(21);
            return null;
        }

        if (!loaded || platform.loader == null) {
            System.out.println("LOAD_JAR_FAIL");
            exitProcess(21);
            return null;
        }

        final String midletName = platform.loader.name;
        if (midletName == null || midletName.trim().isEmpty()) {
            System.out.println("LOAD_JAR_MALFORMED");
            exitProcess(22);
            return null;
        }
        return midletName;
    }

    private static void runJarSequence(MobilePlatform platform, String jarURL) {
        installCapturingPainter(platform);
        final String midletName = loadJar(platform, jarURL);
        System.out.println("LOAD_JAR_OK " + midletName);

        final java.io.PrintStream originalOut = System.out;
        final java.io.ByteArrayOutputStream captured = new java.io.ByteArrayOutputStream();
        final java.io.PrintStream tee = new java.io.PrintStream(new java.io.OutputStream() {
            @Override
            public void write(int b) {
                captured.write(b);
                originalOut.write(b);
            }

            @Override
            public void write(byte[] b, int off, int len) {
                captured.write(b, off, len);
                originalOut.write(b, off, len);
            }
        }, true);
        System.setOut(tee);

        try {
            platform.runJar();
        } catch (Throwable t) {
            System.setOut(originalOut);
            System.out.println("RUN_JAR_FAIL");
            System.err.println(t.getMessage());
            exitProcess(31);
            return;
        }

        System.setOut(originalOut);
        tee.flush();
        final String output = captured.toString();

        final boolean constructed = output.contains("Create MIDlet");
        final boolean started = output.contains("START_APP_OK");

        if (!constructed || !started) {
            System.out.println("RUN_JAR_FAIL");
            exitProcess(31);
            return;
        }

        System.out.println("RUN_JAR_OK " + midletName);
        exitProcess(0);
    }

    private static void installExitGuard() {
        try {
            System.setSecurityManager(new SecurityManager() {
                @Override
                public void checkExit(int status) {
                    if (!allowProcessExit.get()) {
                        throw new SecurityException(
                            "System.exit(" + status + ") blocked by JavaOne bootstrap"
                        );
                    }
                }

                @Override
                public void checkPermission(Permission perm) {}

                @Override
                public void checkPermission(Permission perm, Object context) {}
            });
        } catch (UnsupportedOperationException ex) {
            System.err.println(
                "SecurityManager unavailable; FreeJ2ME System.exit may kill the process"
            );
        }
    }

    private static void exitProcess(int status) {
        allowProcessExit.set(true);
        System.exit(status);
    }

    private static final class FrameSnapshot {
        final int paintIndex;
        final int width;
        final int height;
        final int pixelCount;
        final long checksum;
        final String pixelFormat;
        final java.io.File pixelFile;

        FrameSnapshot(
            int paintIndex,
            int width,
            int height,
            int pixelCount,
            long checksum,
            String pixelFormat,
            java.io.File pixelFile
        ) {
            this.paintIndex = paintIndex;
            this.width = width;
            this.height = height;
            this.pixelCount = pixelCount;
            this.checksum = checksum;
            this.pixelFormat = pixelFormat;
            this.pixelFile = pixelFile;
        }
    }
}