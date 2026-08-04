import Foundation

/// Provides access to games stored in the user's library.
@MainActor
protocol GameLibraryRepository {
    /// Returns all games currently in the library.
    func fetchGames() -> [InstalledGame]

    /// Stores an installed game in the library.
    func save(_ game: InstalledGame)

    /// Returns the installed game with the given content hash, if one exists.
    func game(withContentHash contentHash: String) -> InstalledGame?
}
