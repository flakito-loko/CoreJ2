import Foundation

/// Errors owned by the Phase-1 Embedded JVM spike.
public enum EmbeddedJVMError: Error, Sendable, Equatable {
    case alreadyStarting
    case alreadyRunning
    case notReady
    case destroyed
    case failed(String)
    case nativeCreateFailed(Int32)
    case nativeHelloFailed(Int32)
    case nativeDestroyFailed(Int32)
    /// Destroy started but HotSpot blocked past the Phase-1 watchdog.
    case nativeDestroyTimedOut
    case invalidConfiguration(String)
    case secondJVMRejected
}
