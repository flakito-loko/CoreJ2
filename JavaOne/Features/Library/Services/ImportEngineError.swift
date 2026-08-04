import Foundation

/// Errors produced by the import engine.
enum ImportEngineError: LocalizedError, Equatable {
    /// A game with the same content hash is already installed.
    case duplicateGame

    var errorDescription: String? {
        switch self {
        case .duplicateGame:
            return "This game is already in your library."
        }
    }
}
