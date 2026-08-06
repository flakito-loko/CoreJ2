import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct JavaOneApp: App {

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    private let dependencies: AppDependencyContainer
    @StateObject private var libraryViewModel: LibraryViewModel

    // MARK: - Init

    init() {
        let container: ModelContainer

        do {
            container = try ModelContainer(for: InstalledGameEntity.self)
        } catch {
            // LIBRARY-US001 — new library metadata fields may invalidate an older store.
            // Wipe SwiftData stores under Application Support and recreate.
            if let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first {
                let candidates = [
                    appSupport.appendingPathComponent("default.store"),
                    appSupport.appendingPathComponent("default.store-shm"),
                    appSupport.appendingPathComponent("default.store-wal"),
                    appSupport.appendingPathComponent("SwiftData", isDirectory: true)
                ]
                for url in candidates {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            do {
                container = try ModelContainer(for: InstalledGameEntity.self)
            } catch {
                fatalError("Failed to create the SwiftData model container: \(error)")
            }
        }

        modelContainer = container
        let dependencyContainer = AppDependencyContainer(modelContainer: container)
        dependencies = dependencyContainer
        _libraryViewModel = StateObject(wrappedValue: dependencyContainer.makeLibraryViewModel())
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            LibraryView(viewModel: libraryViewModel)
                #if canImport(UIKit)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willTerminateNotification
                    )
                ) { _ in
                    Task { @MainActor in
                        await dependencies.shutdownEmbeddedRuntime()
                    }
                }
                #endif
        }
        .modelContainer(modelContainer)
    }
}
