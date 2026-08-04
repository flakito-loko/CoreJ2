import Foundation

/// Sole JavaOne component allowed to talk to vendored FreeJ2ME (`Vendor/FreeJ2ME`).
///
/// Owns the Contract C sequence: runtime init → `MobilePlatform` → painter →
/// `loadJar` → `runJar` → lifecycle.
///
/// Platform / painter / load / run execute FreeJ2ME via the host JVM bootstrap.
@MainActor
final class FreeJ2MERuntimeAdapter {

    // MARK: - Constants

    private enum Defaults {
        static let lcdWidth = 240
        static let lcdHeight = 320
    }

    // MARK: - Properties

    private let platformBootstrap: FreeJ2MEMobilePlatformBootstrapping

    /// `true` after a successful `createMobilePlatform` call.
    private(set) var isMobilePlatformCreated = false

    /// `true` after a successful `registerPainter` call.
    private(set) var isPainterRegistered = false

    /// `true` after a successful `loadJar` call.
    private(set) var isJarLoaded = false

    /// `true` after a successful `runJar` call (`startApp` reached).
    private(set) var isMidletRunning = false

    /// Last successful `loadJar` result, if any.
    private(set) var lastJarLoadResult: FreeJ2MEJarLoadResult?

    /// Last successful `runJar` result, if any.
    private(set) var lastJarRunResult: FreeJ2MEJarRunResult?

    /// Framebuffer snapshots from painter callbacks (`getLCD()` + pixel copy).
    private(set) var frameCaptures: [FreeJ2MEFrameCapture] = []

    /// Most recent framebuffer metadata capture, if any.
    private(set) var lastFrameCapture: FreeJ2MEFrameCapture?

    /// Called for each captured LCD frame so the host can publish `frameAvailable`.
    ///
    /// Wired by `FreeJ2MERuntimeHost` to `RuntimeEventPipe`. Never renders.
    var onFrameCaptured: ((EmulatorFrame) -> Void)?

    /// Number of paint notifications observed by the adapter.
    private(set) var paintEventCount = 0

    /// LCD width of the last created `MobilePlatform`, if any.
    private(set) var mobilePlatformLCDWidth = 0

    /// LCD height of the last created `MobilePlatform`, if any.
    private(set) var mobilePlatformLCDHeight = 0

    // MARK: - Init

    /// - Parameter platformBootstrap: Executes FreeJ2ME platform / painter / load / run hooks.
    ///   Defaults to the persistent JVM bootstrap on all platforms (iOS fails with
    ///   `runtimeUnavailable`). Inject `ProcessFreeJ2MEMobilePlatformBootstrap` to roll back.
    init(
        platformBootstrap: FreeJ2MEMobilePlatformBootstrapping = PersistentProcessFreeJ2MEMobilePlatformBootstrap()
    ) {
        self.platformBootstrap = platformBootstrap
        self.platformBootstrap.frameHandler = { [weak self] capture in
            self?.ingestStreamedFrame(capture)
        }
    }

    // MARK: - Host Entry

    /// Runs Contract C through `runJar` (framebuffer metadata only; no UI publishing).
    func start(configuration: LaunchConfiguration) throws {
        try initializeRuntime(configuration: configuration)
        try createMobilePlatform(lcdWidth: Defaults.lcdWidth, lcdHeight: Defaults.lcdHeight)
        try registerPainter()
        try loadJar(from: configuration.game)
        try runJar()
    }

    // MARK: - Runtime Initialization

    /// Future: bring up an embedded Java/FreeJ2ME host inside the app process.
    func initializeRuntime(configuration: LaunchConfiguration) throws {
        _ = configuration
    }

    /// Creates FreeJ2ME `MobilePlatform(width, height)` and binds it with `Mobile.setPlatform`.
    ///
    /// Does not load a MIDlet, call `loadJar` / `runJar`, or register a painter.
    func createMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        try platformBootstrap.bootstrapMobilePlatform(lcdWidth: lcdWidth, lcdHeight: lcdHeight)
        mobilePlatformLCDWidth = lcdWidth
        mobilePlatformLCDHeight = lcdHeight
        isMobilePlatformCreated = true
    }

    /// Registers FreeJ2ME `setPainter` with a capturing callback.
    ///
    /// When `painter.run()` fires, the host reads `MobilePlatform.getLCD()`,
    /// copies packed ARGB pixels, and notifies `onFrameCaptured` for each frame.
    /// No Metal textures, SwiftUI, or UIKit images.
    @discardableResult
    func registerPainter() throws -> FreeJ2MEPainterRegistrationResult {
        guard isMobilePlatformCreated else {
            throw EmulatorBridgeError.launchFailed
        }

        let result = try platformBootstrap.registerPainter(
            lcdWidth: mobilePlatformLCDWidth,
            lcdHeight: mobilePlatformLCDHeight
        )
        recordPainterResult(result)
        isPainterRegistered = true
        return result
    }

    /// Records painter framebuffer metadata and publishes app-facing frames.
    func recordPainterResult(_ result: FreeJ2MEPainterRegistrationResult) {
        frameCaptures.append(contentsOf: result.frames)
        lastFrameCapture = result.frames.last
        paintEventCount += result.paintEventCount

        for capture in result.frames {
            guard let frame = capture.makeEmulatorFrame() else {
                continue
            }
            onFrameCaptured?(frame)
        }
    }

    /// Records that FreeJ2ME invoked the registered painter (unit-test helper).
    func notePaintEvent() {
        paintEventCount += 1
    }

    // MARK: - MIDlet Loading

    /// Loads an installed game's JAR via FreeJ2ME `MobilePlatform.loadJar(...)`.
    @discardableResult
    func loadJar(from game: InstalledGame) throws -> FreeJ2MEJarLoadResult {
        try loadJar(from: game.jarURL)
    }

    /// Loads a JAR at `jarURL` via FreeJ2ME `MobilePlatform.loadJar(...)`.
    @discardableResult
    func loadJar(from jarURL: URL) throws -> FreeJ2MEJarLoadResult {
        guard isMobilePlatformCreated else {
            throw EmulatorBridgeError.launchFailed
        }

        try validateJARPath(jarURL)

        let fileURLString = Self.freeJ2MEFileURLString(from: jarURL)
        let result = try platformBootstrap.loadJar(
            lcdWidth: mobilePlatformLCDWidth,
            lcdHeight: mobilePlatformLCDHeight,
            jarFileURLString: fileURLString
        )

        isJarLoaded = true
        lastJarLoadResult = result
        return result
    }

    /// Starts the loaded MIDlet via FreeJ2ME `MobilePlatform.runJar()`.
    @discardableResult
    func runJar() throws -> FreeJ2MEJarRunResult {
        guard isJarLoaded, let loaded = lastJarLoadResult else {
            throw EmulatorBridgeError.launchFailed
        }

        let result = try platformBootstrap.runJar(
            lcdWidth: mobilePlatformLCDWidth,
            lcdHeight: mobilePlatformLCDHeight,
            jarFileURLString: loaded.jarURLString
        )

        isMidletRunning = true
        lastJarRunResult = result
        return result
    }

    // MARK: - Lifecycle

    /// Future: suspend FreeJ2ME MIDlet activity.
    func pause() throws {}

    /// Future: resume FreeJ2ME MIDlet activity.
    func resume() throws {}

    /// Tears down FreeJ2ME runtime bindings and shuts down the persistent JVM when used.
    func stop() throws {
        try platformBootstrap.shutdownRuntime()
        isMobilePlatformCreated = false
        isPainterRegistered = false
        isJarLoaded = false
        isMidletRunning = false
        lastJarLoadResult = nil
        lastJarRunResult = nil
        frameCaptures = []
        lastFrameCapture = nil
        paintEventCount = 0
        mobilePlatformLCDWidth = 0
        mobilePlatformLCDHeight = 0
    }

    // MARK: - Private

    private func ingestStreamedFrame(_ capture: FreeJ2MEFrameCapture) {
        frameCaptures.append(capture)
        lastFrameCapture = capture
        paintEventCount += 1
        guard let frame = capture.makeEmulatorFrame() else {
            return
        }
        onFrameCaptured?(frame)
    }

    private func validateJARPath(_ jarURL: URL) throws {
        let path = jarURL.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else {
            throw EmulatorBridgeError.jarNotFound
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw EmulatorBridgeError.jarNotReadable
        }
    }

    /// Absolute `file://` URL string accepted by FreeJ2ME `MobilePlatform.loadJar`.
    static func freeJ2MEFileURLString(from jarURL: URL) -> String {
        if jarURL.isFileURL {
            return jarURL.standardizedFileURL.absoluteString
        }
        return URL(fileURLWithPath: jarURL.path).standardizedFileURL.absoluteString
    }
}
