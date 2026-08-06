import Foundation
import SwiftData

/// Composition root that builds and wires application dependencies.
///
/// E4-US006 — production embeds one shared runtime graph:
/// `EmbeddedJVMManager` → `DefaultJNIGateway` → `DefaultPlatformBootstrap` →
/// `FreeJ2MERuntimeHost(platformBootstrap:)` → `DefaultEmulatorBridge`.
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

    private lazy var metadataProvider: any MetadataProvider = {
        var providers: [any MetadataProvider] = [
            CatalogMetadataProvider.loadDefault()
        ]
        // Optional remote endpoint — not hardcoded to a single public website.
        if let endpoint = UserDefaults.standard.string(forKey: "CoreJ2MetadataEndpoint"),
           let url = URL(string: endpoint) {
            providers.insert(HTTPMetadataProvider(baseURL: url, providerID: "http.user"), at: 0)
        }
        return CompositeMetadataProvider(providers: providers)
    }()

    private lazy var metadataEnricher: GameMetadataEnricher = GameMetadataEnricher(
        provider: metadataProvider
    )

    private lazy var coverStore: GameCoverStore = GameCoverStore()

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

    // MARK: - Embedded Runtime Graph (shared, process-scoped)

    private lazy var embeddedJVMManager: EmbeddedJVMManager = EmbeddedJVMManager(
        configuration: Self.makeEmbeddedJVMConfiguration(),
        native: JNICreateJavaVMNativeRuntime()
    )

    private lazy var jniGateway: DefaultJNIGateway = DefaultJNIGateway(
        readiness: embeddedJVMManager,
        native: ProductionJNIGatewayNativeBackend()
    )

    private lazy var platformBootstrap: DefaultPlatformBootstrap = DefaultPlatformBootstrap(
        jvm: embeddedJVMManager,
        gateway: jniGateway
    )

    private lazy var runtimeHost: RuntimeHostProtocol = FreeJ2MERuntimeHost(
        platformBootstrap: platformBootstrap
    )

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
            },
            metadataEnricher: metadataEnricher,
            coverStore: coverStore
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

    // MARK: - Production Graph Accessors (DI verification)

    /// The concrete runtime host wired for production.
    ///
    /// Previews and isolated unit tests should continue to inject
    /// `PlaceholderRuntimeHost` / Adapter stubs directly.
    var productionRuntimeHost: RuntimeHostProtocol {
        runtimeHost
    }

    /// Shared `EmbeddedJVMManager` owned by this container.
    var productionEmbeddedJVMManager: EmbeddedJVMManager {
        embeddedJVMManager
    }

    /// Shared `DefaultJNIGateway` owned by this container.
    var productionJNIGateway: DefaultJNIGateway {
        jniGateway
    }

    /// Shared `DefaultPlatformBootstrap` injected into the production host.
    var productionPlatformBootstrap: DefaultPlatformBootstrap {
        platformBootstrap
    }

    // MARK: - Application Lifetime

    /// Destroys the process-scoped Embedded JVM (E4-US007).
    ///
    /// Call only on application termination — never for per-game session stop.
    func shutdownEmbeddedRuntime() async {
        try? await platformBootstrap.shutdown()
    }

    // MARK: - Private

    /// Resolves classpath / java.home for the process-scoped Embedded JVM.
    ///
    /// E6-US003 — prefers the bundled OpenJDK Mobile layout:
    /// `OpenJDKMobile/java.home` + `OpenJDKMobile/classpath` (FreeJ2ME + bootstrap classes).
    private static func makeEmbeddedJVMConfiguration() -> EmbeddedJVMConfiguration {
        if let resourceRoot = Bundle.main.resourceURL {
            let staged = resourceRoot.appendingPathComponent("OpenJDKMobile", isDirectory: true)
            let javaHome = staged.appendingPathComponent("java.home", isDirectory: true)
            let classpath = staged.appendingPathComponent("classpath", isDirectory: true)
            if FileManager.default.fileExists(atPath: javaHome.path) {
                return EmbeddedJVMConfiguration(
                    librarySource: .openJDKMobile(stagedRoot: staged, javaHome: javaHome),
                    classpath: classpath,
                    libjvmURL: nil
                )
            }
        }

        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("JavaOne/Runtime", isDirectory: true)

        return EmbeddedJVMConfiguration(
            librarySource: .openJDKMobile(
                stagedRoot: supportRoot,
                javaHome: supportRoot.appendingPathComponent("java.home", isDirectory: true)
            ),
            classpath: supportRoot.appendingPathComponent("classpath", isDirectory: true)
        )
    }
}
