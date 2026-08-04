package org.javaone.freej2me;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.Permission;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.recompile.mobile.Mobile;
import org.recompile.mobile.MobilePlatform;

/**
 * JavaOne-owned persistent FreeJ2ME runtime proof of concept (E5-US004).
 *
 * <p>Lives outside {@code Vendor/FreeJ2ME}. Keeps a single JVM +
 * {@link MobilePlatform} alive and accepts line-oriented commands on stdin.
 * Not used by production {@code ProcessFreeJ2MEMobilePlatformBootstrap}.
 *
 * <p>Protocol: see {@code docs/E5_US004_PERSISTENT_RUNTIME_POC.md}.
 */
public final class PersistentMobilePlatformDaemon {

    private static final AtomicBoolean allowProcessExit = new AtomicBoolean(false);
    private static final Object stdoutLock = new Object();

    private MobilePlatform platform;
    private int platformIdentity;
    private File frameDirectory;
    private final AtomicInteger paintIndex = new AtomicInteger(0);
    private boolean painterRegistered;
    private boolean jarLoaded;
    private boolean midletRunning;
    private String midletName = "";

    private PersistentMobilePlatformDaemon() {}

    public static void main(String[] args) throws Exception {
        installExitGuard();
        final PersistentMobilePlatformDaemon daemon = new PersistentMobilePlatformDaemon();
        daemon.emit("READY poc=1");
        final BufferedReader reader = new BufferedReader(
            new InputStreamReader(System.in, StandardCharsets.UTF_8)
        );
        String line;
        while ((line = reader.readLine()) != null) {
            final String trimmed = line.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            try {
                if (!daemon.handleCommand(trimmed)) {
                    break;
                }
            } catch (Throwable t) {
                daemon.emit(
                    "ERR INTERNAL "
                        + sanitize(t.getClass().getSimpleName() + ": " + String.valueOf(t.getMessage()))
                );
            }
        }
    }

    /**
     * @return {@code false} when the process should exit
     */
    private boolean handleCommand(String line) {
        final String[] parts = line.split("\\s+", 3);
        final String cmd = parts[0].toUpperCase();

        switch (cmd) {
            case "CREATE":
                return handleCreate(parts);
            case "PAINTER":
                return handlePainter(parts);
            case "LOAD":
                return handleLoad(parts);
            case "RUN":
                return handleRun();
            case "FRAME_PROBE":
                return handleFrameProbe();
            case "PING":
                return handlePing();
            case "STOP":
                return handleStop();
            case "SHUTDOWN":
                return handleShutdown();
            default:
                emit("ERR UNKNOWN_COMMAND " + sanitize(cmd));
                return true;
        }
    }

    private boolean handleCreate(String[] parts) {
        if (platform != null) {
            emit("ERR ALREADY_CREATED id=" + platformIdentity);
            return true;
        }
        if (parts.length < 3) {
            emit("ERR USAGE CREATE <width> <height>");
            return true;
        }
        final int width = Integer.parseInt(parts[1]);
        final int height = Integer.parseInt(parts[2].trim().split("\\s+")[0]);
        platform = new MobilePlatform(width, height);
        Mobile.setPlatform(platform);
        platformIdentity = System.identityHashCode(platform);

        if (Mobile.getPlatform() == null || Mobile.getPlatform().getLCD() == null) {
            emit("ERR CREATE_FAILED platform_invalid");
            platform = null;
            return true;
        }

        emit("OK CREATE id=" + platformIdentity + " w=" + width + " h=" + height);
        return true;
    }

    private boolean handlePainter(String[] parts) {
        if (platform == null) {
            emit("ERR NO_PLATFORM");
            return true;
        }
        if (painterRegistered) {
            emit("ERR PAINTER_ALREADY_REGISTERED id=" + platformIdentity);
            return true;
        }
        if (parts.length < 2) {
            emit("ERR USAGE PAINTER <frameOutputDir>");
            return true;
        }
        frameDirectory = new File(parts[1].trim());
        if (!frameDirectory.isDirectory() && !frameDirectory.mkdirs()) {
            emit("ERR PAINTER_DIR " + sanitize(frameDirectory.getAbsolutePath()));
            return true;
        }

        platform.setPainter(new Runnable() {
            @Override
            public void run() {
                try {
                    final int index = paintIndex.incrementAndGet();
                    final FrameSnapshot snap = captureFrame(platform, index, frameDirectory);
                    emit(
                        "FRAME "
                            + snap.paintIndex + " "
                            + snap.width + " "
                            + snap.height + " "
                            + snap.pixelCount + " "
                            + Long.toUnsignedString(snap.checksum) + " "
                            + snap.pixelFormat + " "
                            + snap.pixelFile.getAbsolutePath()
                    );
                } catch (Throwable t) {
                    emit(
                        "ERR FRAME "
                            + sanitize(t.getClass().getSimpleName() + ": " + String.valueOf(t.getMessage()))
                    );
                }
            }
        });
        painterRegistered = true;

        // Prove painter works immediately (synthetic double paint).
        fillLCD(platform, Color.RED);
        platform.painter.run();
        fillLCD(platform, Color.BLUE);
        platform.painter.run();

        emit("OK PAINTER id=" + platformIdentity + " paints=" + paintIndex.get());
        return true;
    }

    private boolean handleLoad(String[] parts) {
        if (platform == null) {
            emit("ERR NO_PLATFORM");
            return true;
        }
        if (parts.length < 2) {
            emit("ERR USAGE LOAD <fileURL>");
            return true;
        }
        final String jarURL = parts.length >= 3 ? parts[1] + " " + parts[2] : parts[1];
        final String url = jarURL.trim();
        final boolean loaded;
        try {
            loaded = platform.loadJar(url);
        } catch (Throwable t) {
            emit("ERR LOAD_FAIL " + sanitize(String.valueOf(t.getMessage())));
            return true;
        }
        if (!loaded || platform.loader == null) {
            emit("ERR LOAD_FAIL loader_null");
            return true;
        }
        midletName = platform.loader.name;
        if (midletName == null || midletName.trim().isEmpty()) {
            emit("ERR LOAD_MALFORMED");
            return true;
        }
        jarLoaded = true;
        midletRunning = false;
        emit("OK LOAD name=" + sanitize(midletName) + " id=" + platformIdentity);
        return true;
    }

    private boolean handleRun() {
        if (platform == null) {
            emit("ERR NO_PLATFORM");
            return true;
        }
        if (!jarLoaded || platform.loader == null) {
            emit("ERR NOT_LOADED");
            return true;
        }
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
            emit("ERR RUN_FAIL " + sanitize(String.valueOf(t.getMessage())));
            return true;
        }
        System.setOut(originalOut);
        tee.flush();
        final String output = captured.toString();
        final boolean constructed = output.contains("Create MIDlet");
        final boolean started = output.contains("START_APP_OK");
        if (!constructed || !started) {
            emit("ERR RUN_FAIL startApp_not_reached");
            return true;
        }
        midletRunning = true;
        emit(
            "OK RUN name=" + sanitize(midletName)
                + " id=" + platformIdentity
                + " started=true"
        );
        return true;
    }

    /**
     * Forces a paint through the registered painter after {@code RUN}, proving the
     * same {@link MobilePlatform} and painter survive without restarting the JVM.
     */
    private boolean handleFrameProbe() {
        if (platform == null) {
            emit("ERR NO_PLATFORM");
            return true;
        }
        if (!painterRegistered) {
            emit("ERR NO_PAINTER");
            return true;
        }
        fillLCD(platform, new Color(0x11, 0xD4, 0x8A));
        platform.painter.run();
        emit(
            "OK FRAME_PROBE id=" + platformIdentity
                + " paints=" + paintIndex.get()
                + " midletRunning=" + midletRunning
        );
        return true;
    }

    private boolean handlePing() {
        emit(
            "OK PING id=" + platformIdentity
                + " painter=" + painterRegistered
                + " loaded=" + jarLoaded
                + " running=" + midletRunning
                + " paints=" + paintIndex.get()
        );
        return true;
    }

    private boolean handleStop() {
        if (platform == null) {
            emit("ERR NO_PLATFORM");
            return true;
        }
        // Best-effort session reset without modifying FreeJ2ME.
        platform.setPainter(new Runnable() {
            @Override
            public void run() {}
        });
        painterRegistered = false;
        jarLoaded = false;
        midletRunning = false;
        midletName = "";
        platform.loader = null;
        emit("OK STOP id=" + platformIdentity);
        return true;
    }

    private boolean handleShutdown() {
        emit("OK SHUTDOWN id=" + platformIdentity);
        allowProcessExit.set(true);
        System.exit(0);
        return false;
    }

    private void emit(String line) {
        synchronized (stdoutLock) {
            System.out.println(line);
            System.out.flush();
        }
    }

    private static String sanitize(String value) {
        if (value == null) {
            return "";
        }
        return value.replace('\n', ' ').replace('\r', ' ').trim();
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

    private static FrameSnapshot captureFrame(
        MobilePlatform platform,
        int paintIndex,
        File outputDir
    ) throws Exception {
        final BufferedImage lcd = platform.getLCD();
        if (lcd == null) {
            throw new IllegalStateException("getLCD() returned null");
        }
        final int width = lcd.getWidth();
        final int height = lcd.getHeight();
        final int pixelCount = width * height;
        final int[] pixels = new int[pixelCount];
        lcd.getRGB(0, 0, width, height, pixels, 0, width);

        long checksum = 0xcbf29ce484222325L;
        for (int i = 0; i < pixels.length; i++) {
            checksum ^= (pixels[i] & 0xffffffffL);
            checksum *= 0x100000001b3L;
        }

        final File pixelFile = new File(outputDir, "poc-frame-" + paintIndex + ".argb");
        writeLittleEndianARGB(pixelFile, pixels);
        final String pixelFormat = lcd.getType() == BufferedImage.TYPE_INT_ARGB
            ? "TYPE_INT_ARGB"
            : "TYPE_" + lcd.getType();
        return new FrameSnapshot(paintIndex, width, height, pixelCount, checksum, pixelFormat, pixelFile);
    }

    private static void writeLittleEndianARGB(File file, int[] pixels) throws Exception {
        final ByteBuffer buffer = ByteBuffer
            .allocate(pixels.length * 4)
            .order(ByteOrder.LITTLE_ENDIAN);
        for (int pixel : pixels) {
            buffer.putInt(pixel);
        }
        Files.write(file.toPath(), buffer.array());
    }

    private static void installExitGuard() {
        try {
            System.setSecurityManager(new SecurityManager() {
                @Override
                public void checkExit(int status) {
                    if (!allowProcessExit.get()) {
                        throw new SecurityException(
                            "System.exit(" + status + ") blocked by JavaOne POC daemon"
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
                "SecurityManager unavailable; FreeJ2ME System.exit may kill the POC process"
            );
        }
    }

    private static final class FrameSnapshot {
        final int paintIndex;
        final int width;
        final int height;
        final int pixelCount;
        final long checksum;
        final String pixelFormat;
        final File pixelFile;

        FrameSnapshot(
            int paintIndex,
            int width,
            int height,
            int pixelCount,
            long checksum,
            String pixelFormat,
            File pixelFile
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
