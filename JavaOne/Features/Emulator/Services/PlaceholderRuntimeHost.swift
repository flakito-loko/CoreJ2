import Foundation

/// Lightweight no-op runtime host for unit tests and SwiftUI previews.
///
/// Production wiring uses `FreeJ2MERuntimeHost` via `AppDependencyContainer`.
/// Do not use this type as the shipping host.
@MainActor
final class PlaceholderRuntimeHost: RuntimeHostProtocol {

    // MARK: - Properties

    private let eventPipe = RuntimeEventPipe()

    var events: AsyncStream<RuntimeEvent> {
        eventPipe.events
    }

    // MARK: - Init

    init() {}

    // MARK: - RuntimeHostProtocol

    func launch(_ configuration: LaunchConfiguration) throws {
        _ = configuration
        eventPipe.yield(.started)
    }

    func pause(_ session: EmulatorSession) throws {
        _ = session
        eventPipe.yield(.paused)
    }

    func resume(_ session: EmulatorSession) throws {
        _ = session
        eventPipe.yield(.resumed)
    }

    func stop(_ session: EmulatorSession) throws {
        _ = session
        eventPipe.yield(.stopped)
    }
}
