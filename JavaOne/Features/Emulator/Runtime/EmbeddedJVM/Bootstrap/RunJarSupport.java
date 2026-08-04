package org.javaone.bootstrap;

import java.io.ByteArrayOutputStream;
import java.io.OutputStream;
import java.io.PrintStream;

import org.recompile.mobile.MobilePlatform;

/**
 * JavaOne-owned helper that invokes {@link MobilePlatform#runJar()} and verifies
 * that FreeJ2ME constructed a MIDlet and reached {@code startApp()}.
 *
 * <p>Not FreeJ2ME. Mirrors the Process {@code MobilePlatformBootstrap} run-jar
 * contract ({@code Create MIDlet} + {@code START_APP_OK}) without requiring
 * framebuffer / Display / repaint.
 *
 * <p>E3-US006 — Vendor {@code runJar()} swallows exceptions; success is determined
 * by stdout markers, not by JNI exception status.
 */
public final class RunJarSupport {

    static final String CREATE_MIDLET_MARKER = "Create MIDlet";
    static final String START_APP_OK_MARKER = "START_APP_OK";

    private RunJarSupport() {
    }

    /**
     * Calls {@code platform.runJar()} while teeing {@code System.out}, then returns
     * whether both MIDlet construction and {@code startApp} markers were observed.
     *
     * <p>JNI: {@code runAndVerifyStartApp(Lorg/recompile/mobile/MobilePlatform;)Z}
     */
    public static boolean runAndVerifyStartApp(MobilePlatform platform) {
        if (platform == null) {
            return false;
        }

        final PrintStream originalOut = System.out;
        final ByteArrayOutputStream captured = new ByteArrayOutputStream();
        final PrintStream tee = new PrintStream(new OutputStream() {
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
            // Vendor normally swallows failures; still treat unexpected throw as failure.
            System.setOut(originalOut);
            return false;
        } finally {
            System.setOut(originalOut);
            tee.flush();
        }

        final String output = captured.toString();
        return output.contains(CREATE_MIDLET_MARKER) && output.contains(START_APP_OK_MARKER);
    }
}
