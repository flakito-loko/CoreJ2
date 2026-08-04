import Foundation

/// Process-level control of the Embedded JVM for PlatformBootstrap.
///
/// Implemented by `EmbeddedJVMManager` via extension — the manager source is not modified.
protocol EmbeddedJVMControlling: EmbeddedJVMReadiness {
    /// Ensures exactly one JVM exists and is ready for JNI.
    func ensureStarted() async throws

    /// Ordered process shutdown of the Embedded JVM.
    func shutdown() async throws
}

extension EmbeddedJVMManager: EmbeddedJVMControlling {}
