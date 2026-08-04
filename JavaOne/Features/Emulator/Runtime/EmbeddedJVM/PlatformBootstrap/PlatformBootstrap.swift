import Foundation

/// iOS PlatformBootstrap — sole product-side consumer of `JNIGateway`.
///
/// Owns Contract C orchestration for MobilePlatform, painter, `loadJar`, `runJar`,
/// and Display lifecycle verification (no repaint / framebuffer / rendering yet).
///
/// Does **not** know SwiftUI, Library, `EmulatorSession`, or `RuntimeEvent`.
protocol PlatformBootstrap: AnyObject, Sendable {
    /// Current lifecycle state.
    var state: PlatformBootstrapState { get }

    /// `true` when `state == .ready`.
    var isReady: Bool { get }

    /// Opaque handle for the constructed `MobilePlatform` while ready; `nil` otherwise.
    ///
    /// Ownership: Bootstrap retains the `JNIObjectId`; Gateway owns the underlying GlobalRef.
    var mobilePlatformObjectId: JNIObjectId? { get }

    /// Opaque handle for the installed painter `Runnable` while ready; `nil` otherwise.
    ///
    /// Ownership: Bootstrap retains the `JNIObjectId`; Gateway owns the underlying GlobalRef.
    var painterObjectId: JNIObjectId? { get }

    /// Last successful `loadJar` result while ready; cleared on shutdown.
    var lastJarLoadResult: FreeJ2MEJarLoadResult? { get }

    /// Last successful `runJar` result while ready; cleared on shutdown.
    var lastJarRunResult: FreeJ2MEJarRunResult? { get }

    /// Last successful Display verification while ready; cleared on shutdown / new load.
    var lastDisplayResult: FreeJ2MEDisplayResult? { get }

    /// Starts the JVM (if needed), binds `JNIGateway`, registers infrastructure natives,
    /// constructs `MobilePlatform`, calls `Mobile.setPlatform`, and installs the painter.
    func initialize() async throws

    /// Loads a JAR via `MobilePlatform.loadJar` and verifies `MIDletLoader` / manifest name.
    ///
    /// Requires `state == .ready`. Does **not** call `runJar` or start a MIDlet.
    func loadJar(url: URL) async throws -> FreeJ2MEJarLoadResult

    /// Starts the loaded MIDlet via `MobilePlatform.runJar()` → `MIDletLoader.start()` → `startApp()`.
    ///
    /// Requires a successful prior `loadJar`. Does **not** validate Display / frames.
    func runJar() async throws -> FreeJ2MEJarRunResult

    /// Verifies FreeJ2ME Display singleton + current Displayable after a successful `runJar`.
    ///
    /// Requires `lastJarRunResult`. Does **not** call repaint or extract LCD pixels.
    /// Repeated calls are allowed and succeed when Display state is unchanged.
    func verifyDisplay() async throws -> FreeJ2MEDisplayResult

    /// Releases painter + MobilePlatform handles, unregisters natives, invalidates the gateway,
    /// and shuts down the Embedded JVM.
    func shutdown() async throws
}
