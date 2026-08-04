import Foundation

/// Shared mutable state for a single import session.
///
/// `ImportPipeline` owns and updates this context while importing a game.
/// Future import steps can extend the context with additional fields
/// (compatibility, progress, temporary directories)
/// without changing the pipeline entry point.
final class ImportContext {

    // MARK: - Session Identity

    /// Original JAR selected by the user.
    let sourceURL: URL

    // MARK: - Import Artifacts

    /// Destination URL of the JAR copied into the JavaOne library, if available.
    var importedJarURL: URL?

    /// Parsed MIDlet manifest, when reading succeeds.
    var manifest: MidletManifest?

    /// Final installed game produced by the pipeline, if available.
    var installedGame: InstalledGame?

    /// SHA-256 digest of the imported JAR, as a lowercase hexadecimal string.
    var contentHash: String?

    /// File URL of the extracted MIDlet icon, when available.
    var artworkURL: URL?

    // MARK: - Diagnostics

    /// Non-fatal issues encountered during the import session.
    var warnings: [String]

    // MARK: - Init

    /// Creates a new import session for `sourceURL`.
    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        self.warnings = []
    }
}
