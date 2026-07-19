import Foundation

/// Composition root that builds and wires application dependencies.
@MainActor
final class AppDependencyContainer {

    // MARK: - Repositories

    private lazy var gameLibraryRepository: GameLibraryRepository = InMemoryGameLibraryRepository()

    // MARK: - Factories

    /// Creates a view model for the library screen.
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(repository: gameLibraryRepository)
    }
}
