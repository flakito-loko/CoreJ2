import Foundation

/// Lifecycle states for an emulator session.
///
/// Matches the FreeJ2ME runtime contract state machine used by the bridge
/// before and after a real runtime is attached.
enum EmulatorSessionState: String, Equatable, Sendable, CaseIterable {

    /// Session exists but has not begun starting the runtime.
    case idle

    /// Runtime is being prepared or started.
    case starting

    /// Runtime is active and may accept frames and input.
    case running

    /// Runtime is suspended; session remains valid.
    case paused

    /// Runtime teardown is in progress.
    case stopping

    /// Runtime has been torn down cleanly (terminal).
    case stopped

    /// Runtime failed; requires a new launch (terminal).
    case failed
}
