import Combine
import CoreGraphics
import Foundation

/// Drives the emulator LCD surface screen.
///
/// Owns session launch/stop against `EmulatorBridgeProtocol`, observes
/// `runtimeEvents`, and converts `frameAvailable` payloads into `CGImage`.
@MainActor
final class EmulatorViewModel: ObservableObject {

    // MARK: - Published State

    /// Metadata from the most recent successfully rendered frame, if any.
    @Published private(set) var surfaceMetadata: EmulatorSurfaceMetadata?

    /// Latest LCD bitmap for SwiftUI (`Image(decorative:scale:)`).
    @Published private(set) var lcdImage: CGImage?

    /// Number of frames successfully converted and published.
    @Published private(set) var receivedFrameCount = 0

    /// `true` after at least one frame has been rendered to `lcdImage`.
    @Published private(set) var hasReceivedFrame = false

    /// Active emulator session created by `startSession(for:)`, if any.
    @Published private(set) var activeSession: EmulatorSession?

    /// Configuration used for the active (or last) launch attempt.
    @Published private(set) var lastLaunchConfiguration: LaunchConfiguration?

    /// User-facing error from a failed launch.
    @Published var launchErrorMessage: String?

    // MARK: - Dependencies

    private let bridge: EmulatorBridgeProtocol
    private var observationTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameter bridge: App-facing emulator API (events + lifecycle).
    init(bridge: EmulatorBridgeProtocol) {
        self.bridge = bridge
    }

    // MARK: - Session Lifecycle

    /// Starts observing runtime events, then launches `game` through the bridge.
    ///
    /// Observation begins first so `frameAvailable` events emitted during launch
    /// are not missed.
    func startSession(for game: InstalledGame) async {
        guard activeSession == nil else {
            return
        }

        launchErrorMessage = nil
        startObservingRuntimeEvents()
        // Allow the AsyncStream consumer to attach before launch publishes events.
        await Task.yield()

        do {
            try launch(game: game)
        } catch {
            launchErrorMessage = error.localizedDescription
            stopObservingRuntimeEvents()
        }
    }

    /// Creates `LaunchConfiguration` and calls `EmulatorBridge.launch`.
    func launch(game: InstalledGame) throws {
        let configuration = LaunchConfiguration(game: game)
        lastLaunchConfiguration = configuration
        activeSession = try bridge.launch(configuration)
    }

    /// Stops the active session (if any) and cancels event observation.
    func endSession() {
        if let session = activeSession {
            try? bridge.stop(session)
            activeSession = nil
        }
        stopObservingRuntimeEvents()
        resetSurfaceState()
    }

    /// Clears the launch error alert message.
    func dismissLaunchError() {
        launchErrorMessage = nil
    }

    // MARK: - Observation

    /// Starts consuming `bridge.runtimeEvents` until cancelled or stopped.
    func startObservingRuntimeEvents() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.bridge.runtimeEvents {
                guard !Task.isCancelled else { break }
                self.handleRuntimeEvent(event)
            }
        }
    }

    /// Cancels the runtime event observation task.
    func stopObservingRuntimeEvents() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Event Handling

    /// Applies a runtime event to published surface state.
    ///
    /// Exposed for unit tests that inject events without a live stream.
    func handleRuntimeEvent(_ event: RuntimeEvent) {
        guard case .frameAvailable(let frame) = event else {
            return
        }
        applyFrame(frame)
    }

    // MARK: - Private

    private func applyFrame(_ frame: EmulatorFrame) {
        guard frame.pixels.count == frame.width * frame.height * 4 else {
            return
        }
        guard let image = EmulatorFrameCGImageConverter.makeCGImage(from: frame) else {
            return
        }
        guard image.width == frame.width, image.height == frame.height else {
            return
        }

        surfaceMetadata = EmulatorSurfaceMetadata(
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            pixelCount: frame.pixelCount
        )
        lcdImage = image
        receivedFrameCount += 1
        hasReceivedFrame = true
    }

    private func resetSurfaceState() {
        surfaceMetadata = nil
        lcdImage = nil
        receivedFrameCount = 0
        hasReceivedFrame = false
        lastLaunchConfiguration = nil
        launchErrorMessage = nil
    }
}
