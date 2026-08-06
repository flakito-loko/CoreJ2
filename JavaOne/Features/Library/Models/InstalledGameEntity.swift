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

    var midletVersion: String = ""
    var gameDescription: String = ""
    var developer: String = ""
    var genre: String = ""
    var releaseYear: Int?
    var screenshotPathsJoined: String = ""
    var defaultCoverPath: String = ""
    var metadataProviderID: String = ""
    var hasCustomCover: Bool = false

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
        compatibilityRaw: String = GameCompatibility.ready.rawValue,
        midletVersion: String = "",
        gameDescription: String = "",
        developer: String = "",
        genre: String = "",
        releaseYear: Int? = nil,
        screenshotPathsJoined: String = "",
        defaultCoverPath: String = "",
        metadataProviderID: String = "",
        hasCustomCover: Bool = false
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
        self.midletVersion = midletVersion
        self.gameDescription = gameDescription
        self.developer = developer
        self.genre = genre
        self.releaseYear = releaseYear
        self.screenshotPathsJoined = screenshotPathsJoined
        self.defaultCoverPath = defaultCoverPath
        self.metadataProviderID = metadataProviderID
        self.hasCustomCover = hasCustomCover
    }

    // MARK: - Mapping

    func toDomain() -> InstalledGame {
        let resolvedURL = Self.resolvedJarURL(gameID: id, storedPath: jarPath)
        if resolvedURL.path != jarPath {
            jarPath = resolvedURL.path
        }

        let artworkRoot = resolvedURL
            .deletingLastPathComponent()
            .appendingPathComponent("artwork", isDirectory: true)

        let coverURL = Self.resolveExistingURL(
            storedPath: coverPath,
            fallbacks: [
                artworkRoot.appendingPathComponent("custom-cover.jpg"),
                artworkRoot.appendingPathComponent("cover.jpg"),
                artworkRoot.appendingPathComponent("icon.png")
            ]
        )

        let defaultCoverURL = Self.resolveExistingURL(
            storedPath: defaultCoverPath,
            fallbacks: [
                artworkRoot.appendingPathComponent("cover.jpg"),
                artworkRoot.appendingPathComponent("icon.png")
            ]
        )

        let screenshots: [URL]
        if screenshotPathsJoined.isEmpty {
            let shotsDir = artworkRoot.appendingPathComponent("screenshots", isDirectory: true)
            if let entries = try? FileManager.default.contentsOfDirectory(
                at: shotsDir,
                includingPropertiesForKeys: nil
            ) {
                screenshots = entries
                    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
            } else {
                screenshots = []
            }
        } else {
            screenshots = screenshotPathsJoined
                .split(separator: "|")
                .map { URL(fileURLWithPath: String($0)) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        let size = MIDletLCDGeometry.size(forMidletName: title)
        let resolvedResolution = resolution.isEmpty
            ? "\(size.width) × \(size.height)"
            : resolution

        // Hydrate text metadata from sidecar when SwiftData predates LIBRARY-US002 fields.
        var description = gameDescription
        var developerValue = developer
        var genreValue = genre
        var year = releaseYear
        var provider = metadataProviderID
        var version = midletVersion
        let sidecar = resolvedURL
            .deletingLastPathComponent()
            .appendingPathComponent("metadata.json", isDirectory: false)
        if description.isEmpty,
           let data = try? Data(contentsOf: sidecar),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            description = json["description"] as? String ?? description
            developerValue = json["developer"] as? String ?? developerValue
            genreValue = json["genre"] as? String ?? genreValue
            year = json["releaseYear"] as? Int ?? year
            provider = json["providerID"] as? String ?? provider
            version = json["midletVersion"] as? String ?? version
        }

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
            compatibility: GameCompatibility(rawValue: compatibilityRaw) ?? .ready,
            midletVersion: version,
            gameDescription: description,
            developer: developerValue,
            genre: genreValue,
            releaseYear: year,
            screenshotURLs: screenshots,
            defaultCoverURL: defaultCoverURL,
            metadataProviderID: provider,
            hasCustomCover: hasCustomCover
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
        midletVersion = game.midletVersion
        gameDescription = game.gameDescription
        developer = game.developer
        genre = game.genre
        releaseYear = game.releaseYear
        screenshotPathsJoined = game.screenshotURLs.map(\.path).joined(separator: "|")
        defaultCoverPath = game.defaultCoverURL?.path ?? ""
        metadataProviderID = game.metadataProviderID
        hasCustomCover = game.hasCustomCover
    }

    // MARK: - Path Resolution

    private static func resolveExistingURL(storedPath: String, fallbacks: [URL]) -> URL? {
        if !storedPath.isEmpty {
            let stored = URL(fileURLWithPath: storedPath)
            if FileManager.default.fileExists(atPath: stored.path) {
                return stored
            }
        }
        return fallbacks.first { FileManager.default.fileExists(atPath: $0.path) }
    }

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
