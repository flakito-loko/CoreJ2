import Foundation

/// A Java ME game owned by CoreJ2's internal library.
struct InstalledGame: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let jarURL: URL
    let importedAt: Date
    /// SHA-256 digest of the JAR contents, as a lowercase hexadecimal string.
    let contentHash: String

    /// `MIDlet-Vendor` / catalog publisher when known.
    var publisher: String
    /// Active cover on disk (custom, metadata, or JAR icon).
    var coverURL: URL?
    /// Display size label (e.g. `240 × 320`).
    var resolution: String
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var compatibility: GameCompatibility

    /// `MIDlet-Version` when present.
    var midletVersion: String
    /// Long-form description from a metadata provider (cached locally).
    var gameDescription: String
    var developer: String
    var genre: String
    var releaseYear: Int?
    /// Local screenshot file URLs (downloaded once).
    var screenshotURLs: [URL]
    /// Cover restored by "Restore Default" (metadata cover or JAR icon).
    var defaultCoverURL: URL?
    /// Provenance of online/catalog metadata.
    var metadataProviderID: String
    /// `true` when the user imported a custom cover.
    var hasCustomCover: Bool

    init(
        id: UUID,
        title: String,
        jarURL: URL,
        importedAt: Date,
        contentHash: String,
        publisher: String = "Unknown",
        coverURL: URL? = nil,
        resolution: String = "240 × 320",
        isFavorite: Bool = false,
        lastPlayedAt: Date? = nil,
        compatibility: GameCompatibility = .ready,
        midletVersion: String = "",
        gameDescription: String = "",
        developer: String = "",
        genre: String = "",
        releaseYear: Int? = nil,
        screenshotURLs: [URL] = [],
        defaultCoverURL: URL? = nil,
        metadataProviderID: String = "",
        hasCustomCover: Bool = false
    ) {
        self.id = id
        self.title = title
        self.jarURL = jarURL
        self.importedAt = importedAt
        self.contentHash = contentHash
        self.publisher = publisher
        self.coverURL = coverURL
        self.resolution = resolution
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.compatibility = compatibility
        self.midletVersion = midletVersion
        self.gameDescription = gameDescription
        self.developer = developer
        self.genre = genre
        self.releaseYear = releaseYear
        self.screenshotURLs = screenshotURLs
        self.defaultCoverURL = defaultCoverURL
        self.metadataProviderID = metadataProviderID
        self.hasCustomCover = hasCustomCover
    }

    func updating(
        title: String? = nil,
        contentHash: String? = nil,
        publisher: String? = nil,
        coverURL: URL?? = nil,
        resolution: String? = nil,
        isFavorite: Bool? = nil,
        lastPlayedAt: Date?? = nil,
        compatibility: GameCompatibility? = nil,
        midletVersion: String? = nil,
        gameDescription: String? = nil,
        developer: String? = nil,
        genre: String? = nil,
        releaseYear: Int?? = nil,
        screenshotURLs: [URL]? = nil,
        defaultCoverURL: URL?? = nil,
        metadataProviderID: String? = nil,
        hasCustomCover: Bool? = nil
    ) -> InstalledGame {
        InstalledGame(
            id: id,
            title: title ?? self.title,
            jarURL: jarURL,
            importedAt: importedAt,
            contentHash: contentHash ?? self.contentHash,
            publisher: publisher ?? self.publisher,
            coverURL: coverURL ?? self.coverURL,
            resolution: resolution ?? self.resolution,
            isFavorite: isFavorite ?? self.isFavorite,
            lastPlayedAt: lastPlayedAt ?? self.lastPlayedAt,
            compatibility: compatibility ?? self.compatibility,
            midletVersion: midletVersion ?? self.midletVersion,
            gameDescription: gameDescription ?? self.gameDescription,
            developer: developer ?? self.developer,
            genre: genre ?? self.genre,
            releaseYear: releaseYear ?? self.releaseYear,
            screenshotURLs: screenshotURLs ?? self.screenshotURLs,
            defaultCoverURL: defaultCoverURL ?? self.defaultCoverURL,
            metadataProviderID: metadataProviderID ?? self.metadataProviderID,
            hasCustomCover: hasCustomCover ?? self.hasCustomCover
        )
    }

    var hasCachedMetadata: Bool {
        !gameDescription.isEmpty || !genre.isEmpty || !metadataProviderID.isEmpty || releaseYear != nil
    }
}
