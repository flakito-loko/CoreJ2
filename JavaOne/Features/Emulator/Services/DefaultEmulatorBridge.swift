import Foundation

/// Emulator bridge that validates launches and delegates runtime work to a host.
@MainActor
final class DefaultEmulatorBridge: EmulatorBridgeProtocol {

    // MARK: - Properties

    private let runtimeHost: RuntimeHostProtocol

    /// The session currently owned by this bridge, if any.
    private var activeSession: EmulatorSession?

    // MARK: - Init

    /// Creates a bridge that drives session lifecycle through `runtimeHost`.
    ///
    /// - Parameter runtimeHost: Runtime abstraction. Defaults to
    ///   `PlaceholderRuntimeHost` for previews and isolated unit tests.
    ///   Production injects `FreeJ2MERuntimeHost` from `AppDependencyContainer`.
    init(runtimeHost: RuntimeHostProtocol = PlaceholderRuntimeHost()) {
        self.runtimeHost = runtimeHost
    }

    // MARK: - EmulatorBridgeProtocol

    var runtimeEvents: AsyncStream<RuntimeEvent> {
        runtimeHost.events
    }

    /// Validates `configuration`, asks the host to launch, then marks the session `.running`.
    func launch(_ configuration: LaunchConfiguration) throws -> EmulatorSession {
        try validateLaunch(configuration)

        let session = EmulatorSession(
            configuration: configuration,
            state: .starting,
            startedAt: Date()
        )

        do {
            try runtimeHost.launch(configuration)
            session.transition(to: .running)
            activeSession = session
            return session
        } catch {
            session.transition(to: .failed)
            throw error
        }
    }

    /// Asks the host to pause, then moves a `.running` session to `.paused`.
    func pause(_ session: EmulatorSession) throws {
        guard session.state == .running else {
            throw EmulatorBridgeError.invalidSession
        }
        try runtimeHost.pause(session)
        session.transition(to: .paused)
    }

    /// Asks the host to resume, then moves a `.paused` session to `.running`.
    func resume(_ session: EmulatorSession) throws {
        guard session.state == .paused else {
            throw EmulatorBridgeError.invalidSession
        }
        try runtimeHost.resume(session)
        session.transition(to: .running)
    }

    /// Asks the host to stop, then moves through `.stopping` to `.stopped`.
    func stop(_ session: EmulatorSession) throws {
        switch session.state {
        case .running, .paused:
            try runtimeHost.stop(session)
            session.transition(to: .stopping)
            session.transition(to: .stopped)
            if activeSession?.id == session.id {
                activeSession = nil
            }
        case .idle, .starting, .stopping, .stopped, .failed:
            throw EmulatorBridgeError.invalidSession
        }
    }

    // MARK: - Validation

    private func validateLaunch(_ configuration: LaunchConfiguration) throws {
        try validateConfiguration(configuration)
        try validateJAR(at: configuration.game.jarURL)

        if hasActiveSession {
            throw EmulatorBridgeError.runtimeAlreadyRunning
        }
    }

    private func validateConfiguration(_ configuration: LaunchConfiguration) throws {
        let game = configuration.game
        let trimmedTitle = game.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            throw EmulatorBridgeError.invalidConfiguration
        }

        guard !game.contentHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmulatorBridgeError.invalidConfiguration
        }

        guard game.jarURL.isFileURL else {
            throw EmulatorBridgeError.invalidConfiguration
        }
    }

    private func validateJAR(at jarURL: URL) throws {
        let path = jarURL.path(percentEncoded: false)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            throw EmulatorBridgeError.jarNotFound
        }

        guard fileManager.isReadableFile(atPath: path) else {
            throw EmulatorBridgeError.jarNotReadable
        }
    }

    private var hasActiveSession: Bool {
        guard let session = activeSession else {
            return false
        }

        switch session.state {
        case .starting, .running, .paused, .stopping:
            return true
        case .idle, .stopped, .failed:
            return false
        }
    }
}
