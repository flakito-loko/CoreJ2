import Foundation

/// Strongly typed events published by a `RuntimeHost` toward `EmulatorBridge`.
enum RuntimeEvent: Sendable, Equatable {

    /// Runtime finished starting and is ready to run.
    case started

    /// Runtime entered a suspended state.
    case paused

    /// Runtime left a suspended state.
    case resumed

    /// Runtime finished tearing down.
    case stopped

    /// Runtime failed; associated value carries the underlying error.
    case failed(any Error)

    /// A new LCD framebuffer is available (CPU pixels only — no rendering).
    case frameAvailable(EmulatorFrame)

    // MARK: - Equatable

    static func == (lhs: RuntimeEvent, rhs: RuntimeEvent) -> Bool {
        switch (lhs, rhs) {
        case (.started, .started),
             (.paused, .paused),
             (.resumed, .resumed),
             (.stopped, .stopped):
            return true
        case (.frameAvailable(let lhsFrame), .frameAvailable(let rhsFrame)):
            return lhsFrame == rhsFrame
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
