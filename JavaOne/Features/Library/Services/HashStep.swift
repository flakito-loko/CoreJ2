import Foundation

/// Calculates / verifies the SHA-256 digest of the imported JAR.
@MainActor
final class HashStep: ImportStep {

    private let identityRegistry: GameIdentityRegistry

    init(identityRegistry: GameIdentityRegistry = .shared) {
        self.identityRegistry = identityRegistry
    }

    // MARK: - ImportStep

    func run(on context: ImportContext) throws {
        guard let jarURL = context.importedJarURL ?? context.installedGame?.jarURL else {
            context.warnings.append("Unable to hash JAR: imported file is unavailable.")
            return
        }

        do {
            let contentHash = try GameIdentity.sha256Hex(ofFileAt: jarURL)
            context.contentHash = contentHash

            if let installedGame = context.installedGame {
                identityRegistry.bind(contentHash: contentHash, installID: installedGame.id)
                context.installedGame = installedGame.updating(contentHash: contentHash)
            }
        } catch {
            context.warnings.append("Unable to calculate SHA-256 for the imported JAR.")
        }
    }
}
