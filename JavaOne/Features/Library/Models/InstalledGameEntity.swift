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
    var publisher: String = "Unknown"
    var coverPath: String = ""
    var resolution: String = "240 × 320"
    var isFavorite: Bool = false
    var lastPlayedAt: Date?
    var compatibilityRaw: String = "Ready"

    // MARK: - Init

    init(
        id: UUID,
        title: String,
        jarPath: String,
        importedAt: Date,
        contentHash: String,
        publisher: String = "Unknown",
        coverPath: String = "",
        resolution: String = "240 × 320",
        isFavorite: Bool = false,
        lastPlayedAt: Date? = nil,
        compatibilityRaw: String = GameCompatibility.ready.rawValue
    ) {
        self.id = id
        self.title = title
        self.jarPath = jarPath
        self.importedAt = importedAt
        self.contentHash = contentHash
        self.publisher = publisher
        self.coverPath = coverPath
        self.resolution = resolution
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.compatibilityRaw = compatibilityRaw
    }

    // MARK: - Mapping

    /// Maps this entity to the domain model.
    ///
    /// Resolves the JAR under the current app container when a stored absolute
    /// path went stale (Simulator reinstall / container UUID change).
    func toDomain() -> InstalledGame {
        let resolvedURL = Self.resolvedJarURL(gameID: id, storedPath: jarPath)
        if resolvedURL.path != jarPath {
            jarPath = resolvedURL.path
        }

        let coverURL: URL?
        if coverPath.isEmpty {
            // Discover artwork written by ArtworkStep even for pre-redesign imports.
            let discovered = resolvedURL
                .deletingLastPathComponent()
                .appendingPathComponent("artwork", isDirectory: true)
                .appendingPathComponent("icon.png", isDirectory: false)
            coverURL = FileManager.default.fileExists(atPath: discovered.path) ? discovered : nil
        } else {
            let stored = URL(fileURLWithPath: coverPath)
            coverURL = FileManager.default.fileExists(atPath: stored.path) ? stored : nil
        }

        let size = MIDletLCDGeometry.size(forMidletName: title)
        let resolvedResolution = resolution.isEmpty
            ? "\(size.width) × \(size.height)"
            : resolution

        return InstalledGame(
            id: id,
            title: title,
            jarURL: resolvedURL,
            importedAt: importedAt,
            contentHash: contentHash,
            publisher: publisher.isEmpty ? "Unknown" : publisher,
            coverURL: coverURL,
            resolution: resolvedResolution,
            isFavorite: isFavorite,
            lastPlayedAt: lastPlayedAt,
            compatibility: GameCompatibility(rawValue: compatibilityRaw) ?? .ready
        )
    }

    func apply(_ game: InstalledGame) {
        title = game.title
        jarPath = game.jarURL.path
        importedAt = game.importedAt
        contentHash = game.contentHash
        publisher = game.publisher
        coverPath = game.coverURL?.path ?? ""
        resolution = game.resolution
        isFavorite = game.isFavorite
        lastPlayedAt = game.lastPlayedAt
        compatibilityRaw = game.compatibility.rawValue
    }

    // MARK: - Path Resolution

    /// Returns a usable JAR URL for `gameID`, preferring `storedPath` when it still exists.
    ///
    /// When the absolute path is stale (Simulator reinstall, container UUID change, or a
    /// seed sentinel such as `…/Application/PLACEHOLDER/…`), relocates to
    /// `Documents/JavaOne/Library/<gameID>/game.jar`.
    ///
    /// E12-US002 — Also accepts lowercase UUID folder names. Validation seeds that used
    /// `uuid.uuid4()` created lowercase directories while `UUID.uuidString` is uppercase;
    /// on case-sensitive device volumes that mismatch left PLACEHOLDER paths unresolved.
    static func resolvedJarURL(gameID: UUID, storedPath: String) -> URL {
        let storedURL = URL(fileURLWithPath: storedPath)
        if FileManager.default.fileExists(atPath: storedURL.path) {
            return storedURL
        }

        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return storedURL
        }

        let libraryRoot = documentsURL
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)

        let canonicalID = gameID.uuidString
        let candidateFolderNames = Array(Set([canonicalID, canonicalID.lowercased()]))

        for folderName in candidateFolderNames {
            let relocatedURL = libraryRoot
                .appendingPathComponent(folderName, isDirectory: true)
                .appendingPathComponent("game.jar", isDirectory: false)
            if FileManager.default.fileExists(atPath: relocatedURL.path) {
                return relocatedURL
            }
        }

        // Mixed-case leftovers: match UUID folders case-insensitively.
        if let entries = try? FileManager.default.contentsOfDirectory(
            at: libraryRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let target = canonicalID.lowercased()
            for entry in entries {
                guard entry.lastPathComponent.lowercased() == target else { continue }
                let jarURL = entry.appendingPathComponent("game.jar", isDirectory: false)
                if FileManager.default.fileExists(atPath: jarURL.path) {
                    return jarURL
                }
            }
        }

        return storedURL
    }
}
