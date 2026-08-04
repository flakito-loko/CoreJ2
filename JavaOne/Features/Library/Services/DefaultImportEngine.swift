import Foundation

/// Default import engine that delegates import execution to an import pipeline.
@MainActor
final class DefaultImportEngine: ImportEngineProtocol {

    // MARK: - Dependencies

    private let pipeline: ImportPipelineProtocol

    // MARK: - Init

    init(pipeline: ImportPipelineProtocol) {
        self.pipeline = pipeline
    }

    // MARK: - ImportEngineProtocol

    func importJAR(from sourceURL: URL) throws -> InstalledGame {
        try pipeline.run(from: sourceURL)
    }
}
