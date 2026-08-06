import Foundation

/// Parsed attributes from a Java ME JAR manifest.
struct MidletManifest: Equatable, Sendable {
    /// Value of the `MIDlet-Name` attribute, if present.
    let midletName: String?

    /// Value of the `MIDlet-Vendor` attribute, if present.
    let vendor: String?

    /// Value of the `MIDlet-Version` attribute, if present.
    let version: String?

    /// Relative path of the primary MIDlet icon inside the JAR, if present.
    let iconPath: String?
}
