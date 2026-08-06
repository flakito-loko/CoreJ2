import Foundation

/// Query used by metadata providers to resolve a MIDlet.
struct GameMetadataQuery: Equatable, Sendable {
    let title: String
    let vendor: String?
    let version: String?
    let contentHash: String
}

/// Provider-agnostic metadata payload before local persistence.
struct GameMetadataRecord: Equatable, Sendable {
    var title: String?
    var description: String?
    var publisher: String?
    var developer: String?
    var genre: String?
    var releaseYear: Int?
    var resolution: String?
    var compatibility: String?
    /// Remote cover to download once and cache locally.
    var coverRemoteURL: URL?
    /// Optional remote screenshots to download once.
    var screenshotRemoteURLs: [URL]
    /// Identifier of the provider that produced this record.
    var providerID: String

    init(
        title: String? = nil,
        description: String? = nil,
        publisher: String? = nil,
        developer: String? = nil,
        genre: String? = nil,
        releaseYear: Int? = nil,
        resolution: String? = nil,
        compatibility: String? = nil,
        coverRemoteURL: URL? = nil,
        screenshotRemoteURLs: [URL] = [],
        providerID: String
    ) {
        self.title = title
        self.description = description
        self.publisher = publisher
        self.developer = developer
        self.genre = genre
        self.releaseYear = releaseYear
        self.resolution = resolution
        self.compatibility = compatibility
        self.coverRemoteURL = coverRemoteURL
        self.screenshotRemoteURLs = screenshotRemoteURLs
        self.providerID = providerID
    }
}

/// Abstraction for online (or catalog) metadata sources.
///
/// Multiple concrete providers can be composed; nothing in CoreJ2
/// hardcodes a single website as the only source of truth.
protocol MetadataProvider: Sendable {
    /// Stable identifier for diagnostics and local provenance.
    var providerID: String { get }

    /// Returns metadata when this provider can resolve `query`, otherwise `nil`.
    func lookup(_ query: GameMetadataQuery) async -> GameMetadataRecord?
}
