import Foundation

/// Typed success result of FreeJ2ME `MobilePlatform.runJar()`.
///
/// Produced only when the MIDlet was constructed and `startApp()` ran to
/// completion. Does not imply framebuffer output or `Display.setCurrent()`.
struct FreeJ2MEJarRunResult: Equatable, Sendable {

    /// Display name from the JAR's `MIDlet-1` manifest attribute.
    let midletName: String

    /// Absolute `file://` URL string loaded into FreeJ2ME.
    let jarURLString: String

    /// `true` when FreeJ2ME reached reflective `MIDlet.startApp()`.
    let reachedStartApp: Bool
}
