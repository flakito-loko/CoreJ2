import Foundation

/// Errors thrown across `EmulatorBridgeProtocol`.
///
/// App-facing only — never wrap Java / FreeJ2ME exceptions directly.
enum EmulatorBridgeError: LocalizedError, Equatable, Sendable {

    /// The configured JAR path does not exist.
    case jarNotFound

    /// The configured JAR exists but cannot be read.
    case jarNotReadable

    /// A launch was requested while another session is still active.
    case runtimeAlreadyRunning

    /// `LaunchConfiguration` failed pre-flight validation.
    case invalidConfiguration

    /// FreeJ2ME `loadJar` / `runJar` (or platform preparation) failed.
    case launchFailed

    /// No usable Java / FreeJ2ME host runtime is available in this environment.
    case runtimeUnavailable

    /// pause, resume, or stop was requested for a session in an invalid state.
    case invalidSession

    var errorDescription: String? {
        switch self {
        case .jarNotFound:
            return "The game JAR could not be found."
        case .jarNotReadable:
            return "The game JAR could not be read."
        case .runtimeAlreadyRunning:
            return "An emulator session is already active."
        case .invalidConfiguration:
            return "The launch configuration is invalid."
        case .launchFailed:
            return "The emulator runtime failed to start."
        case .runtimeUnavailable:
            return "The FreeJ2ME runtime is unavailable on this platform."
        case .invalidSession:
            return "The emulator session cannot accept this lifecycle operation."
        }
    }
}
