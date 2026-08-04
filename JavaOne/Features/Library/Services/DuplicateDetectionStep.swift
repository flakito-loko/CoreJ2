import Foundation

/// Rejects imports whose JAR content hash already exists in the library.
@MainActor
final class DuplicateDetectionStep: ImportStep {

    // MARK: - Dependencies

    private let repository: GameLibraryRepository

    // MARK: - Init

    init(repository: GameLibraryRepository) {
        self.repository = repository
    }

    // MARK: - ImportStep

    /// Throws ``ImportEngineError/duplicateGame`` when `contentHash` is already installed.
    func run(on context: ImportContext) throws {
        guard let contentHash = context.contentHash, !contentHash.isEmpty else {
            context.warnings.append("Unable to check for duplicates: content hash is unavailable.")
            return
        }

        if repository.game(withContentHash: contentHash) != nil {
            throw ImportEngineError.duplicateGame
        }
    }
}
