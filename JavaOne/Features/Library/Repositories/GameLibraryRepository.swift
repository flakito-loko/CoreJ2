import Foundation

/// Provides access to games stored in the user's library.
protocol GameLibraryRepository {
    /// Returns all games currently in the library.
    func fetchGames() -> [Game]
}
