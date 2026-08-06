import Foundation

/// Resolves metadata from a local JSON catalog (bundle + Documents override).
///
/// The catalog may include remote cover/screenshot URLs; those are downloaded
/// once by `GameMetadataEnricher` and then used fully offline.
struct CatalogMetadataProvider: MetadataProvider {
    let providerID = "catalog"

    private let catalog: [CatalogEntry]

    init(entries: [CatalogEntry]) {
        self.catalog = entries
    }

    /// Loads bundled catalog plus optional Documents override.
    static func loadDefault(fileManager: FileManager = .default) -> CatalogMetadataProvider {
        var entries: [CatalogEntry] = []

        if let bundled = Bundle.main.url(forResource: "GameMetadataCatalog", withExtension: "json"),
           let data = try? Data(contentsOf: bundled),
           let decoded = try? JSONDecoder().decode(CatalogFile.self, from: data) {
            entries.append(contentsOf: decoded.games)
        }

        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let override = documents
                .appendingPathComponent("JavaOne", isDirectory: true)
                .appendingPathComponent("MetadataCatalog", isDirectory: true)
                .appendingPathComponent("catalog.json", isDirectory: false)
            if let data = try? Data(contentsOf: override),
               let decoded = try? JSONDecoder().decode(CatalogFile.self, from: data) {
                // Documents entries win on duplicate keys.
                entries.append(contentsOf: decoded.games)
            }
        }

        if entries.isEmpty {
            entries = CatalogEntry.seedEntries
        }

        return CatalogMetadataProvider(entries: entries)
    }

    func lookup(_ query: GameMetadataQuery) async -> GameMetadataRecord? {
        let titleKey = Self.normalize(query.title)
        let vendorKey = query.vendor.map(Self.normalize)

        if let byHash = catalog.last(where: {
            guard let hash = $0.contentHash else { return false }
            return hash.lowercased() == query.contentHash.lowercased()
        }) {
            return byHash.toRecord(providerID: providerID)
        }

        if let exact = catalog.last(where: {
            Self.normalize($0.title) == titleKey
                && (vendorKey == nil || $0.vendor.map(Self.normalize) == vendorKey)
        }) {
            return exact.toRecord(providerID: providerID)
        }

        if let fuzzy = catalog.last(where: {
            let candidate = Self.normalize($0.title)
            return titleKey.contains(candidate) || candidate.contains(titleKey)
        }) {
            return fuzzy.toRecord(providerID: providerID)
        }

        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
    }
}

// MARK: - Catalog models

struct CatalogFile: Codable, Sendable {
    let games: [CatalogEntry]
}

struct CatalogEntry: Codable, Equatable, Sendable {
    var title: String
    var vendor: String?
    var version: String?
    var contentHash: String?
    var description: String?
    var publisher: String?
    var developer: String?
    var genre: String?
    var releaseYear: Int?
    var resolution: String?
    var coverURL: String?
    var screenshotURLs: [String]?

    func toRecord(providerID: String) -> GameMetadataRecord {
        GameMetadataRecord(
            title: title,
            description: description,
            publisher: publisher ?? vendor,
            developer: developer ?? publisher ?? vendor,
            genre: genre,
            releaseYear: releaseYear,
            resolution: resolution,
            coverRemoteURL: coverURL.flatMap(URL.init(string:)),
            screenshotRemoteURLs: (screenshotURLs ?? []).compactMap(URL.init(string:)),
            providerID: providerID
        )
    }

    /// Built-in seed used when no JSON catalog is bundled yet.
    static let seedEntries: [CatalogEntry] = [
        CatalogEntry(
            title: "Miami Nights",
            vendor: "Gameloft",
            version: nil,
            contentHash: nil,
            description: "Cruise the neon streets of Miami in this classic Java ME racing adventure from Gameloft.",
            publisher: "Gameloft",
            developer: "Gameloft",
            genre: "Racing",
            releaseYear: 2005,
            resolution: "320 × 240",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Asphalt 3",
            vendor: "Gameloft",
            version: nil,
            contentHash: nil,
            description: "High-speed arcade racing with licensed cars on the Java ME platform.",
            publisher: "Gameloft",
            developer: "Gameloft",
            genre: "Racing",
            releaseYear: 2006,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Tetris",
            vendor: nil,
            version: nil,
            contentHash: nil,
            description: "The timeless falling-block puzzle that defined a generation of mobile gaming.",
            publisher: "Various",
            developer: "Various",
            genre: "Puzzle",
            releaseYear: 1984,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Astroids",
            vendor: nil,
            version: nil,
            contentHash: nil,
            description: "Arcade space shooter — clear the field of asteroids and survive the swarm.",
            publisher: "Unknown",
            developer: "Unknown",
            genre: "Shooter",
            releaseYear: nil,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Gryzzles",
            vendor: nil,
            version: nil,
            contentHash: nil,
            description: "Match-three puzzle adventure used in CoreJ2 RMS validation suites.",
            publisher: "Unknown",
            developer: "Unknown",
            genre: "Puzzle",
            releaseYear: nil,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Alea Jacta Est",
            vendor: nil,
            version: nil,
            contentHash: nil,
            description: "Strategy title from the CoreJ2 compatibility corpus.",
            publisher: "Unknown",
            developer: "Unknown",
            genre: "Strategy",
            releaseYear: nil,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Doom RPG",
            vendor: "id Software",
            version: nil,
            contentHash: nil,
            description: "Turn-based RPG set in the Doom universe, built for Java ME handsets.",
            publisher: "id Software",
            developer: "Fountainhead Entertainment",
            genre: "RPG",
            releaseYear: 2005,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        ),
        CatalogEntry(
            title: "Sonic Jump",
            vendor: "Sega",
            version: nil,
            contentHash: nil,
            description: "Vertical jump-and-run starring Sonic, adapted for feature phones.",
            publisher: "Sega",
            developer: "Sega",
            genre: "Platform",
            releaseYear: 2005,
            resolution: "240 × 320",
            coverURL: nil,
            screenshotURLs: nil
        )
    ]
}
