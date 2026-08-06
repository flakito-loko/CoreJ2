import Foundation

/// Downloads a full JSON game catalog from a remote URL and serves lookups offline from cache.
///
/// Protocol: plain JSON (`CatalogFile`) — no HTML scraping.
actor RemoteJSONCatalogMetadataProvider: MetadataProvider {
    nonisolated let providerID = "remote.catalog"

    private let catalogURL: URL
    private let session: URLSession
    private let fileManager: FileManager
    private var cachedProvider: CatalogMetadataProvider?
    private var lastFetchAttempt: Date?
    private let minimumRefreshInterval: TimeInterval

    init(
        catalogURL: URL,
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        minimumRefreshInterval: TimeInterval = 60 * 60
    ) {
        self.catalogURL = catalogURL
        self.session = session
        self.fileManager = fileManager
        self.minimumRefreshInterval = minimumRefreshInterval
    }

    func lookup(_ query: GameMetadataQuery) async -> GameMetadataRecord? {
        await refreshIfNeeded()
        let provider = currentProvider()
        guard let record = await provider.lookup(query) else { return nil }
        return GameMetadataRecord(
            title: record.title,
            description: record.description,
            publisher: record.publisher,
            developer: record.developer,
            genre: record.genre,
            releaseYear: record.releaseYear,
            resolution: record.resolution,
            coverRemoteURL: record.coverRemoteURL,
            screenshotRemoteURLs: record.screenshotRemoteURLs,
            providerID: providerID
        )
    }

    func refreshCatalog() async {
        lastFetchAttempt = nil
        await refreshIfNeeded(force: true)
    }

    // MARK: - Private

    private func currentProvider() -> CatalogMetadataProvider {
        if let cachedProvider {
            return cachedProvider
        }
        let entries = loadCachedEntries() + CatalogEntry.seedEntries
        let provider = CatalogMetadataProvider(entries: entries)
        cachedProvider = provider
        return provider
    }

    private func refreshIfNeeded(force: Bool = false) async {
        if !force, let lastFetchAttempt,
           Date().timeIntervalSince(lastFetchAttempt) < minimumRefreshInterval,
           cachedProvider != nil {
            return
        }
        lastFetchAttempt = Date()

        var request = URLRequest(url: catalogURL)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return
            }
            let decoded = try JSONDecoder().decode(CatalogFile.self, from: data)
            try persistCache(data)
            cachedProvider = CatalogMetadataProvider(entries: decoded.games)
        } catch {
            // Offline / unreachable — keep bundled + Documents cache.
        }
    }

    private func persistCache(_ data: Data) throws {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let dir = documents
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("MetadataCatalog", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("catalog.json", isDirectory: false)
        try data.write(to: url, options: .atomic)
    }

    private func loadCachedEntries() -> [CatalogEntry] {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let url = documents
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("MetadataCatalog", isDirectory: true)
            .appendingPathComponent("catalog.json", isDirectory: false)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CatalogFile.self, from: data) else {
            return []
        }
        return decoded.games
    }
}
