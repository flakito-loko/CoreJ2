import Foundation

/// Abstraction over the native / FreeJ2ME runtime host.
///
/// `EmulatorBridge` owns session validation and lifecycle state. Implementations
/// of this protocol perform the actual runtime work and publish `RuntimeEvent`s.
@MainActor
protocol RuntimeHostProtocol {

    /// Lifecycle and frame signals produced by this host.
    var events: AsyncStream<RuntimeEvent> { get }

    /// Starts (or prepares) a runtime for `configuration`.
    ///
    /// Placeholder hosts must succeed without starting an emulator.
    /// - Parameter configuration: Validated launch inputs from the bridge.
    /// - Throws: If the runtime cannot start.
    func launch(_ configuration: LaunchConfiguration) throws

    /// Suspends runtime activity for `session`.
    /// - Parameter session: The active session to pause.
    /// - Throws: If the runtime cannot pause.
    func pause(_ session: EmulatorSession) throws

    /// Resumes runtime activity for `session`.
    /// - Parameter session: The paused session to resume.
    /// - Throws: If the runtime cannot resume.
    func resume(_ session: EmulatorSession) throws

    /// Tears down runtime activity for `session`.
    /// - Parameter session: The session to stop.
    /// - Throws: If the runtime cannot stop.
    func stop(_ session: EmulatorSession) throws
}
