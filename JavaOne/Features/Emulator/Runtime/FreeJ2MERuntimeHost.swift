import Foundation

/// Production runtime host that forwards lifecycle to `FreeJ2MERuntimeAdapter`.
///
/// Owns `RuntimeEvent` publication and `RuntimeHostProtocol` conformance.
/// FreeJ2ME contact is delegated exclusively to the adapter.
@MainActor
final class FreeJ2MERuntimeHost: RuntimeHostProtocol {

    // MARK: - Properties

    private let eventPipe = RuntimeEventPipe()
    private let adapter: FreeJ2MERuntimeAdapter

    var events: AsyncStream<RuntimeEvent> {
        eventPipe.events
    }

    // MARK: - Init

    /// Creates a host that drives FreeJ2ME through `adapter`.
    /// - Parameter adapter: Only component allowed to touch FreeJ2ME.
    init(adapter: FreeJ2MERuntimeAdapter = FreeJ2MERuntimeAdapter()) {
        self.adapter = adapter
        // Forward captured LCD frames onto the shared event pipe (no rendering).
        self.adapter.onFrameCaptured = { [eventPipe] frame in
            eventPipe.yield(.frameAvailable(frame))
        }
    }

    // MARK: - RuntimeHostProtocol

    /// Asks the adapter to start, then emits `.started` or `.failed`.
    ///
    /// Frame events are yielded during adapter painter registration as they are
    /// captured, before `.started`.
    func launch(_ configuration: LaunchConfiguration) throws {
        do {
            try adapter.start(configuration: configuration)
            eventPipe.yield(.started)
        } catch {
            eventPipe.yield(.failed(error))
            throw error
        }
    }

    /// Asks the adapter to pause, then emits `.paused`.
    func pause(_ session: EmulatorSession) throws {
        _ = session
        try adapter.pause()
        eventPipe.yield(.paused)
    }

    /// Asks the adapter to resume, then emits `.resumed`.
    func resume(_ session: EmulatorSession) throws {
        _ = session
        try adapter.resume()
        eventPipe.yield(.resumed)
    }

    /// Asks the adapter to stop, then emits `.stopped`.
    func stop(_ session: EmulatorSession) throws {
        _ = session
        try adapter.stop()
        eventPipe.yield(.stopped)
    }
}
