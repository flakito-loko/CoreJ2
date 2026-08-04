import CryptoKit
import Foundation

/// Calculates the SHA-256 digest of the imported JAR for an import session.
@MainActor
final class HashStep: ImportStep {

    // MARK: - ImportStep

    /// Reads the imported JAR and stores its lowercase SHA-256 hex digest in the context.
    func run(on context: ImportContext) throws {
        guard let jarURL = context.importedJarURL ?? context.installedGame?.jarURL else {
            context.warnings.append("Unable to hash JAR: imported file is unavailable.")
            return
        }

        do {
            let jarData = try Data(contentsOf: jarURL)
            let digest = SHA256.hash(data: jarData)
            let contentHash = digest.map { byte in
                String(format: "%02x", byte)
            }.joined()

            context.contentHash = contentHash

            if let installedGame = context.installedGame {
                context.installedGame = InstalledGame(
                    id: installedGame.id,
                    title: installedGame.title,
                    jarURL: installedGame.jarURL,
                    importedAt: installedGame.importedAt,
                    contentHash: contentHash
                )
            }
        } catch {
            context.warnings.append("Unable to calculate SHA-256 for the imported JAR.")
        }
    }
}
