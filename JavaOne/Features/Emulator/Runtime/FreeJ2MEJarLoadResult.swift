import Foundation

/// Typed success result of FreeJ2ME `MobilePlatform.loadJar(...)`.
///
/// Produced only when FreeJ2ME constructed a `MIDletLoader` and successfully
/// read a `MIDlet-1` entry from the JAR manifest. Does not imply the MIDlet
/// was started — `runJar()` is intentionally not called.
struct FreeJ2MEJarLoadResult: Equatable, Sendable {

    /// Display name from the JAR's `MIDlet-1` manifest attribute.
    let midletName: String

    /// Absolute `file://` URL string passed to FreeJ2ME `loadJar`.
    let jarURLString: String
}
