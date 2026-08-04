import Foundation

/// Publishes `RuntimeEvent` values through a buffered `AsyncStream`.
@MainActor
final class RuntimeEventPipe {

    // MARK: - Properties

    /// Stream observed by bridges, ViewModels, and tests.
    let events: AsyncStream<RuntimeEvent>

    private let continuation: AsyncStream<RuntimeEvent>.Continuation

    // MARK: - Init

    /// Creates a pipe that keeps the newest events when consumers lag.
    /// - Parameter bufferSize: Maximum buffered events before dropping oldest.
    init(bufferSize: Int = 64) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: RuntimeEvent.self,
            bufferingPolicy: .bufferingNewest(bufferSize)
        )
        self.events = stream
        self.continuation = continuation
    }

    // MARK: - Publishing

    /// Yields `event` to all active stream consumers.
    func yield(_ event: RuntimeEvent) {
        continuation.yield(event)
    }

    /// Ends the stream. Further yields are ignored.
    func finish() {
        continuation.finish()
    }
}
