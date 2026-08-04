package org.javaone.bootstrap;

/**
 * JavaOne-owned native callback host for {@code PlatformBootstrap}.
 *
 * <p>This class is <strong>not</strong> FreeJ2ME and is <strong>not</strong> MobilePlatform.
 * PlatformBootstrap registers implementations for the {@code native} methods via
 * {@code JNIGateway.registerNative} after the Embedded JVM is ready.
 *
 * <p>Classpath: compiled to {@code .class} on a directory classpath (same pattern as
 * {@code HelloWorld}); not loaded from a product JAR in this story.
 *
 * <p>E3-US002 — infrastructure callbacks only (heartbeat). No rendering / MIDlet hooks yet.
 */
public final class NativeCallbackHost {

    /**
     * Diagnostic counter incremented by {@link #fireHeartbeat()} after a successful native call.
     * Harnesses may read this field; production Swift ownership of heartbeat counts lives in
     * PlatformBootstrap.
     */
    public static volatile int fireCount;

    private NativeCallbackHost() {
    }

    /**
     * Infrastructure heartbeat native.
     *
     * <p>Must match PlatformBootstrap registration:
     * binary name {@code org/javaone/bootstrap/NativeCallbackHost},
     * method {@code onBootstrapHeartbeat}, signature {@code ()V}, static.
     */
    public static native void onBootstrapHeartbeat();

    /**
     * Java entry point that invokes the registered native heartbeat.
     *
     * <p>Used by harnesses (and future Java-side callers) after
     * {@code JNIGateway.registerNative} has bound the implementation.
     */
    public static void fireHeartbeat() {
        onBootstrapHeartbeat();
        fireCount++;
    }

    /** Resets harness diagnostics. */
    public static void resetDiagnostics() {
        fireCount = 0;
    }
}
