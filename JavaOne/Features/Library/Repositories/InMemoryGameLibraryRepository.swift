import Foundation

/// An in-memory game library that starts empty.
/// Used until persistent storage is introduced.
final class InMemoryGameLibraryRepository: GameLibraryRepository {
    private var games: [Game]

    init(games: [Game] = []) {
        self.games = games
    }

    func fetchGames() -> [Game] {
        games
    }
}
