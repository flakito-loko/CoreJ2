import Foundation
import SwiftData

/// Composition root that builds and wires application dependencies.
@MainActor
final class AppDependencyContainer {

    // MARK: - Dependencies

    private let modelContainer: ModelContainer

    // MARK: - Repositories

    private lazy var gameLibraryRepository: GameLibraryRepository = SwiftDataGameLibraryRepository(
        modelContext: modelContainer.mainContext
    )

    // MARK: - Services

    private lazy var importService: ImportService = FileImportService()

    private lazy var manifestService: ManifestService = JARManifestService()

    private lazy var importSteps: [any ImportStep] = [
        ManifestStep(manifestService: manifestService),
        HashStep(),
        DuplicateDetectionStep(repository: gameLibraryRepository),
        ArtworkStep()
    ]

    private lazy var importPipeline: ImportPipelineProtocol = DefaultImportPipeline(
        importService: importService,
        steps: importSteps
    )

    private lazy var importEngine: ImportEngineProtocol = DefaultImportEngine(
        pipeline: importPipeline
    )

    // MARK: - Init

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Factories

    /// Creates a view model for the library screen.
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(
            repository: gameLibraryRepository,
            importEngine: importEngine
        )
    }
}
