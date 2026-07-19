import Combine
import Foundation

/// Drives the game library screen.
@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var games: [Game] = []

    // MARK: - Dependencies

    private let repository: GameLibraryRepository

    // MARK: - Init

    init(repository: GameLibraryRepository) {
        self.repository = repository
    }

    // MARK: - Intentions

    /// Loads games from the library repository.
    func loadGames() {
        games = repository.fetchGames()
    }
}
