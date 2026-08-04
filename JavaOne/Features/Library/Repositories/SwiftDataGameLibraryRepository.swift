import Foundation
import SwiftData

/// Persists installed games using SwiftData.
@MainActor
final class SwiftDataGameLibraryRepository: GameLibraryRepository {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - GameLibraryRepository

    func fetchGames() -> [InstalledGame] {
        let descriptor = FetchDescriptor<InstalledGameEntity>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor).map { $0.toDomain() }
        } catch {
            return []
        }
    }

    func save(_ game: InstalledGame) {
        let gameID = game.id
        let descriptor = FetchDescriptor<InstalledGameEntity>(
            predicate: #Predicate { entity in
                entity.id == gameID
            }
        )

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.title = game.title
                existing.jarPath = game.jarURL.path
                existing.importedAt = game.importedAt
                existing.contentHash = game.contentHash
            } else {
                modelContext.insert(
                    InstalledGameEntity(
                        id: game.id,
                        title: game.title,
                        jarPath: game.jarURL.path,
                        importedAt: game.importedAt,
                        contentHash: game.contentHash
                    )
                )
            }
            try modelContext.save()
        } catch {
            // The protocol does not surface persistence errors to callers.
        }
    }

    func game(withContentHash contentHash: String) -> InstalledGame? {
        let hash = contentHash
        let descriptor = FetchDescriptor<InstalledGameEntity>(
            predicate: #Predicate { entity in
                entity.contentHash == hash
            }
        )

        do {
            return try modelContext.fetch(descriptor).first?.toDomain()
        } catch {
            return nil
        }
    }
}
