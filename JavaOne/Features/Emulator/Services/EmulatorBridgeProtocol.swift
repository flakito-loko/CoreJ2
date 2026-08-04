import Foundation

/// Single entry point for launching and controlling installed Java ME games.
///
/// JavaOne talks to the underlying emulator only through this bridge so FreeJ2ME
/// can be integrated later without coupling UI or Library code to the runtime.
@MainActor
protocol EmulatorBridgeProtocol {

    /// Lifecycle and frame signals forwarded from the underlying runtime host.
    var runtimeEvents: AsyncStream<RuntimeEvent> { get }

    /// Prepares an emulator session for `configuration`.
    ///
    /// Placeholder implementations must not start an emulator process.
    /// - Returns: A session representing the prepared launch.
    /// - Throws: If the session cannot be prepared.
    func launch(_ configuration: LaunchConfiguration) throws -> EmulatorSession

    /// Suspends a running session.
    ///
    /// - Parameter session: Session currently in `.running`.
    /// - Throws: `EmulatorBridgeError.invalidSession` when the transition is not allowed.
    func pause(_ session: EmulatorSession) throws

    /// Resumes a paused session.
    ///
    /// - Parameter session: Session currently in `.paused`.
    /// - Throws: `EmulatorBridgeError.invalidSession` when the transition is not allowed.
    func resume(_ session: EmulatorSession) throws

    /// Tears down a running or paused session.
    ///
    /// Transitions through `.stopping` into `.stopped`.
    /// - Parameter session: Session currently in `.running` or `.paused`.
    /// - Throws: `EmulatorBridgeError.invalidSession` when the transition is not allowed.
    func stop(_ session: EmulatorSession) throws
}
