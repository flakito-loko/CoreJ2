/// Phase-1 subset of the EmbeddedJVMManager state machine.
///
/// FreeJ2ME / session occupation states are intentionally absent until later phases.
public enum EmbeddedJVMState: String, Sendable, Equatable {
    /// No JVM exists in this process.
    case notInitialized
    /// `JNI_CreateJavaVM` (or equivalent) in progress.
    case starting
    /// JVM is alive; Hello World may run. FreeJ2ME is not loaded.
    case ready
    /// Ordered teardown in progress.
    case shutdown
    /// JVM no longer exists after successful destroy.
    case destroyed
    /// Startup or fatal failure; JNI edge is not usable.
    case failed
}
