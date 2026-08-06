import Foundation

/// Downloads provider metadata once and persists it beside the installed JAR for offline use.
@MainActor
final class GameMetadataEnricher {

    private let provider: any MetadataProvider
    private let session: URLSession
    private let fileManager: FileManager

    init(
        provider: any MetadataProvider,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.provider = provider
        self.session = session
        self.fileManager = fileManager
    }

    /// Looks up metadata and writes local artifacts under the game directory.
    ///
    /// Custom display fields are preserved; official metadata is always refreshed.
    func enrich(_ game: InstalledGame) async -> InstalledGame {
        let query = GameMetadataQuery(
            title: game.officialTitle.isEmpty ? game.title : game.officialTitle,
            vendor: {
                let p = game.officialPublisher.isEmpty ? game.publisher : game.officialPublisher
                return p == "Unknown" ? nil : p
            }(),
            version: game.midletVersion.isEmpty ? nil : game.midletVersion,
            contentHash: game.contentHash
        )

        guard let record = await provider.lookup(query) else {
            return game
        }

        let gameDirectory = game.jarURL.deletingLastPathComponent()
        let artworkDirectory = gameDirectory.appendingPathComponent("artwork", isDirectory: true)
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)

        var coverURL = game.coverURL
        var defaultCoverURL = game.defaultCoverURL ?? game.coverURL
        var screenshotURLs = game.screenshotURLs

        if let remoteCover = record.coverRemoteURL,
           let localCover = await download(
            remoteCover,
            to: artworkDirectory.appendingPathComponent("cover.jpg", isDirectory: false)
           ) {
            if !game.hasCustomCover {
                coverURL = localCover
            }
            defaultCoverURL = localCover
        } else if defaultCoverURL == nil {
            defaultCoverURL = game.coverURL
        }

        if !record.screenshotRemoteURLs.isEmpty {
            let shotsDirectory = artworkDirectory.appendingPathComponent("screenshots", isDirectory: true)
            try? fileManager.createDirectory(at: shotsDirectory, withIntermediateDirectories: true)
            var locals: [URL] = []
            for (index, remote) in record.screenshotRemoteURLs.prefix(6).enumerated() {
                let dest = shotsDirectory.appendingPathComponent("shot-\(index).jpg", isDirectory: false)
                if let local = await download(remote, to: dest) {
                    locals.append(local)
                }
            }
            if !locals.isEmpty {
                screenshotURLs = locals
            }
        }

        let nextOfficialTitle = record.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? game.officialTitle
        let nextOfficialPublisher = record.publisher?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? game.officialPublisher
        let nextOfficialGenre = record.genre?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? game.officialGenre
        let nextOfficialYear = record.releaseYear ?? game.officialReleaseYear
        let nextCompatibility: GameCompatibility = {
            if let raw = record.compatibility?.trimmingCharacters(in: .whitespacesAndNewlines),
               let mapped = GameCompatibility(rawValue: raw) {
                return mapped
            }
            // Map catalog labels that differ from raw enum cases.
            switch record.compatibility?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "perfect", "playable":
                return .ready
            case "partial", "limited":
                return .limited
            case "launch only", "unknown", "untested", "not working":
                return .unknown
            default:
                return game.compatibility
            }
        }()

        let enriched = game.updating(
            publisher: game.isPublisherCustom ? game.publisher : (nextOfficialPublisher),
            coverURL: .some(coverURL),
            resolution: record.resolution ?? game.resolution,
            compatibility: nextCompatibility,
            gameDescription: record.description ?? game.gameDescription,
            developer: record.developer ?? game.developer,
            genre: game.isGenreCustom ? game.genre : (nextOfficialGenre),
            releaseYear: game.isReleaseYearCustom ? .some(game.releaseYear) : .some(nextOfficialYear),
            screenshotURLs: screenshotURLs,
            defaultCoverURL: .some(defaultCoverURL),
            metadataProviderID: record.providerID,
            hasCustomCover: game.hasCustomCover,
            officialTitle: nextOfficialTitle,
            displayTitle: game.isDisplayTitleCustom ? game.displayTitle : "",
            officialPublisher: nextOfficialPublisher,
            officialGenre: nextOfficialGenre,
            officialReleaseYear: .some(nextOfficialYear),
            isDisplayTitleCustom: game.isDisplayTitleCustom,
            isPublisherCustom: game.isPublisherCustom,
            isGenreCustom: game.isGenreCustom,
            isReleaseYearCustom: game.isReleaseYearCustom
        )

        persistSidecar(enriched, record: record, in: gameDirectory)
        mirrorIdentityCache(enriched, record: record)
        return enriched
    }

    // MARK: - Private

    private func mirrorIdentityCache(_ game: InstalledGame, record: GameMetadataRecord) {
        guard !game.contentHash.isEmpty,
              let cacheDir = LibraryGamePaths.metadataCacheDirectory(
                contentHash: game.contentHash,
                fileManager: fileManager
              ) else {
            return
        }
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        persistSidecar(game, record: record, in: cacheDir)
    }

    private func download(_ remote: URL, to destination: URL) async -> URL? {
        do {
            let (data, response) = try await session.data(from: remote)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard !data.isEmpty else { return nil }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            return nil
        }
    }

    private func persistSidecar(
        _ game: InstalledGame,
        record: GameMetadataRecord,
        in gameDirectory: URL
    ) {
        let payload: [String: Any] = [
            "officialTitle": game.officialTitle,
            "displayTitle": game.displayTitle,
            "title": game.title,
            "description": game.gameDescription,
            "publisher": game.publisher,
            "officialPublisher": game.officialPublisher,
            "developer": game.developer,
            "genre": game.genre,
            "officialGenre": game.officialGenre,
            "releaseYear": game.releaseYear as Any,
            "officialReleaseYear": game.officialReleaseYear as Any,
            "resolution": game.resolution,
            "midletVersion": game.midletVersion,
            "providerID": record.providerID,
            "contentHash": game.contentHash,
            "cachedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let url = gameDirectory.appendingPathComponent("metadata.json", isDirectory: false)
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
