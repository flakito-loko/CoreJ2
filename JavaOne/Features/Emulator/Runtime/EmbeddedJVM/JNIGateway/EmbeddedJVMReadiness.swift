import Foundation

/// Read-only JVM readiness surface for `JNIGateway`.
///
/// Implemented by `EmbeddedJVMManager` via extension — the manager source is not modified.
protocol EmbeddedJVMReadiness: AnyObject, Sendable {
    var state: EmbeddedJVMState { get }
}

extension EmbeddedJVMManager: EmbeddedJVMReadiness {}
