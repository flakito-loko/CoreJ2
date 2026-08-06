import Foundation

/// A Java ME game owned by CoreJ2's internal library.
struct InstalledGame: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let jarURL: URL
    let importedAt: Date
    /// SHA-256 digest of the JAR contents, as a lowercase hexadecimal string.
    let contentHash: String

    /// `MIDlet-Vendor` when known.
    var publisher: String
    /// Extracted MIDlet icon on disk, when available.
    var coverURL: URL?
    /// Display size label (e.g. `240 × 320`).
    var resolution: String
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var compatibility: GameCompatibility

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
        compatibility: GameCompatibility = .ready
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
    }

    func updating(
        title: String? = nil,
        contentHash: String? = nil,
        publisher: String? = nil,
        coverURL: URL?? = nil,
        resolution: String? = nil,
        isFavorite: Bool? = nil,
        lastPlayedAt: Date?? = nil,
        compatibility: GameCompatibility? = nil
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
            compatibility: compatibility ?? self.compatibility
        )
    }
}
