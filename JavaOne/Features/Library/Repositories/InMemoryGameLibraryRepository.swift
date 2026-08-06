import Foundation

/// An in-memory game library used for SwiftUI previews and tests.
@MainActor
final class InMemoryGameLibraryRepository: GameLibraryRepository {
    private var games: [InstalledGame]

    init(games: [InstalledGame] = []) {
        self.games = games
    }

    func fetchGames() -> [InstalledGame] {
        games
    }

    func save(_ game: InstalledGame) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index] = game
        } else {
            games.append(game)
        }
    }

    func delete(_ game: InstalledGame) {
        games.removeAll { $0.id == game.id }
    }

    func game(withContentHash contentHash: String) -> InstalledGame? {
        games.first { $0.contentHash == contentHash }
    }
}
