import Foundation

/// Reads the MIDlet manifest and resolves the final game title for an import session.
@MainActor
final class ManifestStep: ImportStep {

    // MARK: - Dependencies

    private let manifestService: ManifestService

    // MARK: - Init

    init(manifestService: ManifestService) {
        self.manifestService = manifestService
    }

    // MARK: - ImportStep

    /// Updates `context.manifest` and the installed game title when possible.
    func run(on context: ImportContext) throws {
        guard let installedGame = context.installedGame else { return }

        do {
            let jarURL = context.importedJarURL ?? installedGame.jarURL
            let manifest = try manifestService.readManifest(from: jarURL)
            context.manifest = manifest

            if let midletName = manifest.midletName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !midletName.isEmpty {
                context.installedGame = InstalledGame(
                    id: installedGame.id,
                    title: midletName,
                    jarURL: installedGame.jarURL,
                    importedAt: installedGame.importedAt,
                    contentHash: installedGame.contentHash
                )
                return
            }

            context.warnings.append("MIDlet-Name is missing or empty; using the filename title.")
        } catch ManifestServiceError.manifestMissing {
            context.warnings.append("MANIFEST.MF is missing; using the filename title.")
        } catch ManifestServiceError.invalidManifest {
            context.warnings.append("MANIFEST.MF is invalid; using the filename title.")
        } catch {
            context.warnings.append("Unable to read MANIFEST.MF; using the filename title.")
        }
    }
}
