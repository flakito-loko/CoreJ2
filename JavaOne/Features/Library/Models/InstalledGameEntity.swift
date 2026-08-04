import Foundation
import SwiftData

/// SwiftData persistence model for an installed Java ME game.
@Model
final class InstalledGameEntity {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var title: String
    var jarPath: String
    var importedAt: Date
    var contentHash: String

    // MARK: - Init

    init(
        id: UUID,
        title: String,
        jarPath: String,
        importedAt: Date,
        contentHash: String
    ) {
        self.id = id
        self.title = title
        self.jarPath = jarPath
        self.importedAt = importedAt
        self.contentHash = contentHash
    }

    // MARK: - Mapping

    /// Maps this entity to the domain model.
    func toDomain() -> InstalledGame {
        InstalledGame(
            id: id,
            title: title,
            jarURL: URL(fileURLWithPath: jarPath),
            importedAt: importedAt,
            contentHash: contentHash
        )
    }
}
