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
            let entities = try modelContext.fetch(descriptor)
            let games = entities.map { $0.toDomain() }
            if modelContext.hasChanges {
                try modelContext.save()
            }
            return games
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
                existing.apply(game)
            } else {
                let entity = InstalledGameEntity(
                    id: game.id,
                    title: game.title,
                    jarPath: game.jarURL.path,
                    importedAt: game.importedAt,
                    contentHash: game.contentHash,
                    publisher: game.publisher,
                    coverPath: game.coverURL?.path ?? "",
                    resolution: game.resolution,
                    isFavorite: game.isFavorite,
                    lastPlayedAt: game.lastPlayedAt,
                    compatibilityRaw: game.compatibility.rawValue,
                    midletVersion: game.midletVersion,
                    gameDescription: game.gameDescription,
                    developer: game.developer,
                    genre: game.genre,
                    releaseYear: game.releaseYear,
                    screenshotPathsJoined: game.screenshotURLs.map(\.path).joined(separator: "|"),
                    defaultCoverPath: game.defaultCoverURL?.path ?? "",
                    metadataProviderID: game.metadataProviderID,
                    hasCustomCover: game.hasCustomCover,
                    officialTitle: game.officialTitle,
                    displayTitle: game.displayTitle,
                    officialPublisher: game.officialPublisher,
                    officialGenre: game.officialGenre,
                    officialReleaseYear: game.officialReleaseYear,
                    isDisplayTitleCustom: game.isDisplayTitleCustom,
                    isPublisherCustom: game.isPublisherCustom,
                    isGenreCustom: game.isGenreCustom,
                    isReleaseYearCustom: game.isReleaseYearCustom
                )
                modelContext.insert(entity)
            }
            try modelContext.save()
        } catch {
            // The protocol does not surface persistence errors to callers.
        }
    }

    func delete(_ game: InstalledGame) {
        let gameID = game.id
        let descriptor = FetchDescriptor<InstalledGameEntity>(
            predicate: #Predicate { entity in
                entity.id == gameID
            }
        )

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
                try modelContext.save()
            }
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
