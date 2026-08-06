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
    func enrich(_ game: InstalledGame) async -> InstalledGame {
        let query = GameMetadataQuery(
            title: game.title,
            vendor: game.publisher == "Unknown" ? nil : game.publisher,
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

        let enriched = game.updating(
            title: record.title,
            publisher: record.publisher,
            coverURL: .some(coverURL),
            resolution: record.resolution,
            gameDescription: record.description,
            developer: record.developer,
            genre: record.genre,
            releaseYear: .some(record.releaseYear),
            screenshotURLs: screenshotURLs,
            defaultCoverURL: .some(defaultCoverURL),
            metadataProviderID: record.providerID,
            hasCustomCover: game.hasCustomCover
        )

        persistSidecar(enriched, record: record, in: gameDirectory)
        return enriched
    }

    // MARK: - Private

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
            "title": game.title,
            "description": game.gameDescription,
            "publisher": game.publisher,
            "developer": game.developer,
            "genre": game.genre,
            "releaseYear": game.releaseYear as Any,
            "resolution": game.resolution,
            "midletVersion": game.midletVersion,
            "providerID": record.providerID,
            "cachedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let url = gameDirectory.appendingPathComponent("metadata.json", isDirectory: false)
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}
