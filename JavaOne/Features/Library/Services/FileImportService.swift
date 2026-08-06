import Foundation

/// Imports JAR files into the on-device JavaOne library using `FileManager`.
///
/// LIBRARY-US003 — chooses the install UUID from ``GameIdentityRegistry`` using the
/// JAR's SHA-256 so reimports after "Delete Game" reconnect to existing RMS saves.
final class FileImportService: ImportService {

    // MARK: - Dependencies

    private let fileManager: FileManager
    private let identityRegistry: GameIdentityRegistry

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        identityRegistry: GameIdentityRegistry = .shared
    ) {
        self.fileManager = fileManager
        self.identityRegistry = identityRegistry
    }

    // MARK: - ImportService

    func importJAR(from sourceURL: URL) throws -> InstalledGame {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let contentHash = try GameIdentity.sha256Hex(ofFileAt: sourceURL)
        let gameID = identityRegistry.installID(forContentHash: contentHash)
        identityRegistry.bind(contentHash: contentHash, installID: gameID)

        let gameDirectory = try makeGameDirectory(id: gameID)
        let destinationURL = gameDirectory.appendingPathComponent("game.jar", isDirectory: false)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return InstalledGame(
            id: gameID,
            title: sourceURL.deletingPathExtension().lastPathComponent,
            jarURL: destinationURL,
            importedAt: Date(),
            contentHash: contentHash
        )
    }

    // MARK: - Private

    private func makeGameDirectory(id: UUID) throws -> URL {
        let libraryRoot = try libraryRootURL()
        let gameDirectory = libraryRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: gameDirectory,
            withIntermediateDirectories: true
        )
        return gameDirectory
    }

    private func libraryRootURL() throws -> URL {
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw ImportServiceError.documentsDirectoryUnavailable
        }

        let libraryRoot = documentsURL
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)

        try fileManager.createDirectory(
            at: libraryRoot,
            withIntermediateDirectories: true
        )

        return libraryRoot
    }
}
