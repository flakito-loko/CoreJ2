import Foundation

/// Reads the MIDlet manifest and resolves title, publisher, and resolution.
@MainActor
final class ManifestStep: ImportStep {

    // MARK: - Dependencies

    private let manifestService: ManifestService

    // MARK: - Init

    init(manifestService: ManifestService) {
        self.manifestService = manifestService
    }

    // MARK: - ImportStep

    /// Updates `context.manifest` and library metadata when possible.
    func run(on context: ImportContext) throws {
        guard let installedGame = context.installedGame else { return }

        do {
            let jarURL = context.importedJarURL ?? installedGame.jarURL
            let manifest = try manifestService.readManifest(from: jarURL)
            context.manifest = manifest

            let midletName = manifest.midletName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle: String
            if let midletName, !midletName.isEmpty {
                resolvedTitle = midletName
            } else {
                context.warnings.append("MIDlet-Name is missing or empty; using the filename title.")
                resolvedTitle = installedGame.title
            }

            let vendor = manifest.vendor?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let publisher: String
            if let vendor, !vendor.isEmpty {
                publisher = vendor
            } else {
                publisher = "Unknown"
            }

            let version = manifest.version?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let size = MIDletLCDGeometry.size(forMidletName: resolvedTitle)
            context.installedGame = installedGame.updating(
                title: resolvedTitle,
                publisher: publisher,
                resolution: "\(size.width) × \(size.height)",
                midletVersion: version
            )
        } catch ManifestServiceError.manifestMissing {
            context.warnings.append("MANIFEST.MF is missing; using the filename title.")
            applyDefaultResolution(to: context, game: installedGame)
        } catch ManifestServiceError.invalidManifest {
            context.warnings.append("MANIFEST.MF is invalid; using the filename title.")
            applyDefaultResolution(to: context, game: installedGame)
        } catch {
            context.warnings.append("Unable to read MANIFEST.MF; using the filename title.")
            applyDefaultResolution(to: context, game: installedGame)
        }
    }

    private func applyDefaultResolution(to context: ImportContext, game: InstalledGame) {
        let size = MIDletLCDGeometry.size(forMidletName: game.title)
        context.installedGame = game.updating(
            resolution: "\(size.width) × \(size.height)"
        )
    }
}
