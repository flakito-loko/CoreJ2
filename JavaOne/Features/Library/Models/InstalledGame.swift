import Foundation

/// A Java ME game owned by CoreJ2's internal library.
struct InstalledGame: Identifiable, Equatable, Hashable {
    let id: UUID
    let jarURL: URL
    let importedAt: Date
    /// SHA-256 digest of the JAR contents (permanent game identity).
    let contentHash: String

    var stableIdentity: String { contentHash }

    // MARK: - Official metadata (providers / manifest only)

    var officialTitle: String
    var officialPublisher: String
    var officialGenre: String
    var officialReleaseYear: Int?

    // MARK: - Display / effective

    /// User display-name override. Empty → `officialTitle` is shown.
    var displayTitle: String
    /// Effective library title (display name has priority).
    var title: String {
        let trimmed = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? officialTitle : trimmed
    }

    var publisher: String
    var genre: String
    var releaseYear: Int?

    var isDisplayTitleCustom: Bool
    var isPublisherCustom: Bool
    var isGenreCustom: Bool
    var isReleaseYearCustom: Bool

    var coverURL: URL?
    var resolution: String
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var compatibility: GameCompatibility
    var midletVersion: String
    var gameDescription: String
    var developer: String
    var screenshotURLs: [URL]
    var defaultCoverURL: URL?
    var metadataProviderID: String
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
        hasCustomCover: Bool = false,
        officialTitle: String? = nil,
        displayTitle: String = "",
        officialPublisher: String? = nil,
        officialGenre: String? = nil,
        officialReleaseYear: Int? = nil,
        isDisplayTitleCustom: Bool = false,
        isPublisherCustom: Bool = false,
        isGenreCustom: Bool = false,
        isReleaseYearCustom: Bool = false
    ) {
        self.id = id
        self.jarURL = jarURL
        self.importedAt = importedAt
        self.contentHash = contentHash
        self.officialTitle = (officialTitle?.isEmpty == false) ? officialTitle! : title
        self.displayTitle = displayTitle
        self.officialPublisher = officialPublisher ?? publisher
        self.publisher = publisher
        self.officialGenre = officialGenre ?? genre
        self.genre = genre
        self.officialReleaseYear = officialReleaseYear ?? releaseYear
        self.releaseYear = releaseYear
        self.isDisplayTitleCustom = isDisplayTitleCustom
        self.isPublisherCustom = isPublisherCustom
        self.isGenreCustom = isGenreCustom
        self.isReleaseYearCustom = isReleaseYearCustom
        self.coverURL = coverURL
        self.resolution = resolution
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.compatibility = compatibility
        self.midletVersion = midletVersion
        self.gameDescription = gameDescription
        self.developer = developer
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
        hasCustomCover: Bool? = nil,
        officialTitle: String? = nil,
        displayTitle: String? = nil,
        officialPublisher: String? = nil,
        officialGenre: String? = nil,
        officialReleaseYear: Int?? = nil,
        isDisplayTitleCustom: Bool? = nil,
        isPublisherCustom: Bool? = nil,
        isGenreCustom: Bool? = nil,
        isReleaseYearCustom: Bool? = nil
    ) -> InstalledGame {
        // Pipeline `title:` updates the official name (and display when not customized).
        var nextOfficialTitle = officialTitle ?? self.officialTitle
        var nextDisplayTitle = displayTitle ?? self.displayTitle
        var nextTitleCustom = isDisplayTitleCustom ?? self.isDisplayTitleCustom
        if let title {
            nextOfficialTitle = title
            if !(isDisplayTitleCustom ?? self.isDisplayTitleCustom) {
                nextDisplayTitle = ""
                nextTitleCustom = false
            }
        }

        return InstalledGame(
            id: id,
            title: nextOfficialTitle,
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
            hasCustomCover: hasCustomCover ?? self.hasCustomCover,
            officialTitle: nextOfficialTitle,
            displayTitle: nextDisplayTitle,
            officialPublisher: officialPublisher ?? self.officialPublisher,
            officialGenre: officialGenre ?? self.officialGenre,
            officialReleaseYear: {
                if let officialReleaseYear { return officialReleaseYear }
                return self.officialReleaseYear
            }(),
            isDisplayTitleCustom: nextTitleCustom,
            isPublisherCustom: isPublisherCustom ?? self.isPublisherCustom,
            isGenreCustom: isGenreCustom ?? self.isGenreCustom,
            isReleaseYearCustom: isReleaseYearCustom ?? self.isReleaseYearCustom
        )
    }

    var hasCachedMetadata: Bool {
        !gameDescription.isEmpty || !officialGenre.isEmpty || !metadataProviderID.isEmpty || officialReleaseYear != nil
    }
}
