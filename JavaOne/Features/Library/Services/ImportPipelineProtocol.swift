import Foundation

/// Executes the import flow for a selected game file.
@MainActor
protocol ImportPipelineProtocol {
    /// Runs the import flow for the JAR at `sourceURL`.
    /// - Returns: The installed game produced by the pipeline.
    /// - Throws: If the import cannot be completed.
    func run(from sourceURL: URL) throws -> InstalledGame
}
