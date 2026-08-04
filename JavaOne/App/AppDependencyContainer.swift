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

    // MARK: - Emulator

    private lazy var runtimeHost: RuntimeHostProtocol = makeRuntimeHost()

    private lazy var emulatorBridge: EmulatorBridgeProtocol = DefaultEmulatorBridge(
        runtimeHost: runtimeHost
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
            importEngine: importEngine,
            makeEmulatorViewModel: { [self] in
                makeEmulatorViewModel()
            }
        )
    }

    /// Returns the shared emulator bridge used to launch installed games.
    func makeEmulatorBridge() -> EmulatorBridgeProtocol {
        emulatorBridge
    }

    /// Creates a view model for the emulator LCD surface.
    func makeEmulatorViewModel() -> EmulatorViewModel {
        EmulatorViewModel(bridge: emulatorBridge)
    }

    /// The concrete runtime host wired for production.
    ///
    /// Exposed for DI verification tests. Previews and isolated unit tests should
    /// continue to inject `PlaceholderRuntimeHost` directly.
    var productionRuntimeHost: RuntimeHostProtocol {
        runtimeHost
    }

    /// Builds the production runtime host behind the emulator bridge.
    ///
    /// Pipeline: Library → EmulatorBridge → FreeJ2MERuntimeHost →
    /// FreeJ2MERuntimeAdapter → FreeJ2ME.
    ///
    /// On platforms without a host JVM (iOS), launch fails with the typed
    /// `EmulatorBridgeError.runtimeUnavailable`.
    private func makeRuntimeHost() -> RuntimeHostProtocol {
        FreeJ2MERuntimeHost()
    }
}
