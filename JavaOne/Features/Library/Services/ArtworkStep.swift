import Foundation

/// Extracts the primary MIDlet icon from the imported JAR into the game library folder.
@MainActor
final class ArtworkStep: ImportStep {

    // MARK: - Dependencies

    private let fileManager: FileManager

    // MARK: - Init

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - ImportStep

    /// Writes `artwork/icon.png` beside the imported JAR when a manifest icon is available.
    func run(on context: ImportContext) throws {
        guard let jarURL = context.importedJarURL ?? context.installedGame?.jarURL else {
            context.warnings.append("Unable to extract artwork: imported JAR is unavailable.")
            return
        }

        guard let iconPath = context.manifest?.iconPath?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !iconPath.isEmpty else {
            context.warnings.append("No MIDlet icon found in the manifest.")
            return
        }

        let iconData: Data
        do {
            guard let entryData = try JARArchiveReader.data(
                forEntryNamed: iconPath,
                inArchiveAt: jarURL
            ) else {
                context.warnings.append("MIDlet icon path was not found inside the JAR.")
                return
            }
            iconData = entryData
        } catch {
            context.warnings.append("Unable to read the MIDlet icon from the JAR.")
            return
        }

        do {
            let artworkURL = try writeIcon(iconData, nextToJARAt: jarURL)
            context.artworkURL = artworkURL
        } catch {
            context.warnings.append("Unable to save the extracted MIDlet icon.")
        }
    }

    // MARK: - Private

    private func writeIcon(_ iconData: Data, nextToJARAt jarURL: URL) throws -> URL {
        let gameDirectory = jarURL.deletingLastPathComponent()
        let artworkDirectory = gameDirectory.appendingPathComponent("artwork", isDirectory: true)
        try fileManager.createDirectory(
            at: artworkDirectory,
            withIntermediateDirectories: true
        )

        let iconURL = artworkDirectory.appendingPathComponent("icon.png", isDirectory: false)
        if fileManager.fileExists(atPath: iconURL.path) {
            try fileManager.removeItem(at: iconURL)
        }
        try iconData.write(to: iconURL, options: .atomic)
        return iconURL
    }
}
