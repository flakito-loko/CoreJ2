import Foundation

/// Lifecycle of the iOS JNI PlatformBootstrap skeleton (E3-US001).
///
/// Process-level only: no MIDlet session, no FreeJ2ME, no Contract C yet.
enum PlatformBootstrapState: Sendable, Equatable {
    /// Not started.
    case uninitialized
    /// `ensureStarted` / gateway bind / native registration in progress.
    case starting
    /// JVM ready, gateway bound, infrastructure natives registered.
    case ready
    /// Teardown in progress.
    case shuttingDown
    /// Clean shutdown completed (safe to `initialize` again after a new JVM if applicable).
    case shutdown
    /// Unrecoverable failure for this bootstrap instance.
    case failed(String)
}
