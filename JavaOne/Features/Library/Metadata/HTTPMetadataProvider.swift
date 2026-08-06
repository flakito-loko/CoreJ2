import Foundation

/// Fetches metadata from a configurable HTTP endpoint.
///
/// Expected response JSON (flexible / best-effort):
/// ```
/// {
///   "title": "...",
///   "description": "...",
///   "publisher": "...",
///   "developer": "...",
///   "genre": "...",
///   "releaseYear": 2005,
///   "resolution": "240 × 320",
///   "coverURL": "https://...",
///   "screenshotURLs": ["https://..."]
/// }
/// ```
///
/// The base URL is injected — CoreJ2 does not hardcode a single website.
struct HTTPMetadataProvider: MetadataProvider {
    let providerID: String
    let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL,
        providerID: String = "http",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.providerID = providerID
        self.session = session
    }

    func lookup(_ query: GameMetadataQuery) async -> GameMetadataRecord? {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("lookup"),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "name", value: query.title),
            URLQueryItem(name: "vendor", value: query.vendor),
            URLQueryItem(name: "version", value: query.version),
            URLQueryItem(name: "hash", value: query.contentHash)
        ].filter { $0.value?.isEmpty == false }

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(HTTPMetadataPayload.self, from: data)
            return decoded.toRecord(providerID: providerID)
        } catch {
            return nil
        }
    }
}

private struct HTTPMetadataPayload: Codable {
    var title: String?
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
            publisher: publisher,
            developer: developer,
            genre: genre,
            releaseYear: releaseYear,
            resolution: resolution,
            coverRemoteURL: coverURL.flatMap(URL.init(string:)),
            screenshotRemoteURLs: (screenshotURLs ?? []).compactMap(URL.init(string:)),
            providerID: providerID
        )
    }
}
