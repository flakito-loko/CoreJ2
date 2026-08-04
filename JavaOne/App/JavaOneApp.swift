import SwiftData
import SwiftUI

@main
struct JavaOneApp: App {

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    @StateObject private var libraryViewModel: LibraryViewModel

    // MARK: - Init

    init() {
        let container: ModelContainer

        do {
            container = try ModelContainer(for: InstalledGameEntity.self)
        } catch {
            fatalError("Failed to create the SwiftData model container: \(error)")
        }

        modelContainer = container
        let dependencies = AppDependencyContainer(modelContainer: container)
        _libraryViewModel = StateObject(wrappedValue: dependencies.makeLibraryViewModel())
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            LibraryView(viewModel: libraryViewModel)
        }
        .modelContainer(modelContainer)
    }
}
