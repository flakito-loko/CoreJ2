package org.javaone.bootstrap;

/**
 * JavaOne-owned painter {@link Runnable} for {@code PlatformBootstrap}.
 *
 * <p>Not FreeJ2ME. PlatformBootstrap registers {@link #run()} via
 * {@code JNIGateway.registerNative}, constructs an instance, and passes it to
 * {@code MobilePlatform.setPainter(Runnable)}.
 *
 * <p>E3-US004 — callback path only. No rendering, BufferedImage, or MIDlet.
 */
public final class PainterRunnable implements Runnable {

    /** Diagnostic counter for harnesses after {@link #firePaint()}. */
    public static volatile int fireCount;

    public PainterRunnable() {
    }

    /**
     * Painter entry invoked by FreeJ2ME ({@code painter.run()}) once installed.
     *
     * <p>Must match PlatformBootstrap registration: instance {@code run} / {@code ()V}.
     */
    @Override
    public native void run();

    /**
     * Java entry that invokes the registered native (harness / synthetic probe).
     */
    public void firePaint() {
        run();
        fireCount++;
    }

    /** Resets harness diagnostics. */
    public static void resetDiagnostics() {
        fireCount = 0;
    }
}
