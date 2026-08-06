import Foundation

/// Tries metadata providers in order until one returns a hit.
struct CompositeMetadataProvider: MetadataProvider {
    let providerID = "composite"
    private let providers: [any MetadataProvider]

    init(providers: [any MetadataProvider]) {
        self.providers = providers
    }

    func lookup(_ query: GameMetadataQuery) async -> GameMetadataRecord? {
        for provider in providers {
            if let record = await provider.lookup(query) {
                return record
            }
        }
        return nil
    }
}
