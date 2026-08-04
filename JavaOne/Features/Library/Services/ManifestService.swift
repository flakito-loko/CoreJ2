import Foundation

/// Reads MIDlet metadata from a Java ME JAR.
protocol ManifestService {
    /// Reads and parses `META-INF/MANIFEST.MF` from the JAR at `jarURL`.
    /// - Throws: If the JAR cannot be read, the manifest is missing, or it is invalid.
    func readManifest(from jarURL: URL) throws -> MidletManifest
}

/// Errors produced while reading a JAR manifest.
enum ManifestServiceError: Error, Equatable {
    case unableToReadJAR
    case manifestMissing
    case invalidManifest
}
