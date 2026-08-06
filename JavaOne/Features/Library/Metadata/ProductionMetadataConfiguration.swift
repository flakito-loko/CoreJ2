import Foundation

/// Production metadata endpoints for CoreJ2.
///
/// Sources are **JSON catalogs / lookup APIs only** — never HTML scraping.
/// Override with UserDefaults keys without shipping a new binary.
enum ProductionMetadataConfiguration {

    /// UserDefaults key for a custom `/lookup` API base URL (`HTTPMetadataProvider`).
    static let lookupEndpointDefaultsKey = "CoreJ2MetadataEndpoint"

    /// UserDefaults key for a remote JSON catalog URL (`RemoteJSONCatalogMetadataProvider`).
    static let catalogURLDefaultsKey = "CoreJ2MetadataCatalogURL"

    /// Default production JSON catalog (GitHub raw). Schema matches `GameMetadataCatalog.json`.
    static let defaultCatalogURL = URL(
        string: "https://raw.githubusercontent.com/flakito-loko/CoreJ2/main/docs/metadata/catalog.json"
    )!

    /// Resolves the active catalog URL (user override → production default).
    static func resolvedCatalogURL(
        defaults: UserDefaults = .standard
    ) -> URL {
        if let raw = defaults.string(forKey: catalogURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return defaultCatalogURL
    }

    /// Optional lookup API base URL.
    static func resolvedLookupBaseURL(
        defaults: UserDefaults = .standard
    ) -> URL? {
        guard let raw = defaults.string(forKey: lookupEndpointDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }
}
