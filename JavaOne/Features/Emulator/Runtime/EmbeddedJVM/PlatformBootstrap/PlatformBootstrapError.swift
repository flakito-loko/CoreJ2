import Foundation

/// Domain errors for iOS PlatformBootstrap. No JNI types escape.
enum PlatformBootstrapError: Error, Sendable, Equatable {
    /// Operation rejected for the current lifecycle state.
    case invalidState(PlatformBootstrapState)
    /// Embedded JVM failed to become ready.
    case jvmUnavailable(String)
    /// JNIGateway bind / registration / invoke failed.
    case gatewayFailure(String)
    /// Bootstrap already shut down and cannot restart without a fresh dependency graph.
    case alreadyShutdown
    /// JAR path does not exist on disk.
    case jarNotFound(String)
    /// JAR path exists but is not readable.
    case jarNotReadable(String)
    /// `MobilePlatform.loadJar` returned false or failed at the JNI boundary.
    case loadJarFailed(String)
    /// Loader missing or `MIDlet-1` name empty after `loadJar`.
    case malformedJar(String)
    /// `runJar` called without a successful prior `loadJar`.
    case midletNotLoaded
    /// `runJar` already completed successfully for the current loaded JAR.
    case alreadyRunning
    /// `runJar` / startApp verification failed (markers missing or FreeJ2ME failed silently).
    case runJarFailed(String)
    /// Display verification called without a successful prior `runJar`.
    case midletNotRunning
    /// FreeJ2ME Display singleton is missing after `runJar`.
    case displayNotPresent
    /// Display exists but no current Displayable (`setCurrent` not observed).
    case noCurrentDisplayable
}
