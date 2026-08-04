import Foundation

/// Single entry point for importing games into the JavaOne library.
@MainActor
protocol ImportEngineProtocol {
    /// Imports a JAR from `sourceURL` into the internal library.
    /// - Returns: The installed game created from the imported file.
    /// - Throws: If the import cannot be completed.
    func importJAR(from sourceURL: URL) throws -> InstalledGame
}
