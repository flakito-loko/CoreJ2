import Foundation

/// A prepared emulator session for a single launched game.
///
/// Sessions are reference types so lifecycle transitions keep a stable `id`
/// while `state` and `endedAt` evolve. Future FreeJ2ME integration will drive
/// these transitions from the runtime adapter without changing session identity.
@MainActor
final class EmulatorSession: Identifiable {

    // MARK: - Properties

    /// Unique identifier for this session.
    let id: UUID

    /// Launch configuration that produced this session.
    let configuration: LaunchConfiguration

    /// Current lifecycle state.
    private(set) var state: EmulatorSessionState

    /// When this session entered the lifecycle (typically at `.starting`).
    let startedAt: Date

    /// When the session reached a terminal state (`.stopped` or `.failed`).
    private(set) var endedAt: Date?

    // MARK: - Init

    /// Creates a session in the given lifecycle state.
    ///
    /// - Parameters:
    ///   - id: Stable session identity. Defaults to a new UUID.
    ///   - configuration: Launch inputs for this session.
    ///   - state: Initial lifecycle state. Defaults to `.idle`.
    ///   - startedAt: Session start timestamp. Defaults to now.
    ///   - endedAt: Terminal timestamp when already ended; otherwise `nil`.
    init(
        id: UUID = UUID(),
        configuration: LaunchConfiguration,
        state: EmulatorSessionState = .idle,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = id
        self.configuration = configuration
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    // MARK: - Lifecycle

    /// Applies a lifecycle transition.
    ///
    /// Terminal states (`.stopped`, `.failed`) record `endedAt` once.
    /// - Parameter newState: The next session state.
    func transition(to newState: EmulatorSessionState) {
        state = newState

        switch newState {
        case .stopped, .failed:
            if endedAt == nil {
                endedAt = Date()
            }
        case .idle, .starting, .running, .paused, .stopping:
            break
        }
    }
}
