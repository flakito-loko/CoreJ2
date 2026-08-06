import Foundation

/// On-disk layout for library installs, caches, settings, and save roots.
///
/// Save path mirrors `RMSSaveDirectory` (`Documents/JavaOne/Saves/<installUUID>/`)
/// so library management can clean up without modifying emulator/RMS code.
enum LibraryGamePaths {

    static func documentsRoot(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func libraryRoot(fileManager: FileManager = .default) -> URL? {
        documentsRoot(fileManager: fileManager)?
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
    }

    static func gameDirectory(for game: InstalledGame, fileManager: FileManager = .default) -> URL {
        game.jarURL.deletingLastPathComponent()
    }

    static func savesDirectory(installID: UUID, fileManager: FileManager = .default) -> URL? {
        documentsRoot(fileManager: fileManager)?
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
            .appendingPathComponent(installID.uuidString, isDirectory: true)
    }

    /// Per-game settings keyed by stable SHA-256 identity (not filename).
    static func settingsURL(contentHash: String, fileManager: FileManager = .default) -> URL? {
        guard let root = documentsRoot(fileManager: fileManager) else { return nil }
        let dir = root
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("Settings", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(contentHash.lowercased()).json", isDirectory: false)
    }

    /// Optional hash-keyed metadata cache (future sync / offline).
    static func metadataCacheDirectory(contentHash: String, fileManager: FileManager = .default) -> URL? {
        guard let root = documentsRoot(fileManager: fileManager) else { return nil }
        return root
            .appendingPathComponent("JavaOne", isDirectory: true)
            .appendingPathComponent("MetadataCache", isDirectory: true)
            .appendingPathComponent(contentHash.lowercased(), isDirectory: true)
    }
}

/// How aggressively to remove a game from the device.
enum GameDeletionMode: String, Equatable, Sendable {
    /// Removes JAR, artwork, and metadata cache. Keeps RMS saves and per-game settings.
    case gameOnly
    /// Also removes RMS, settings, covers, screenshots, and identity binding.
    case everything
}

/// Performs library-side install cleanup and path queries.
@MainActor
final class GameInstallationManager {

    private let fileManager: FileManager
    private let identityRegistry: GameIdentityRegistry

    init(
        fileManager: FileManager = .default,
        identityRegistry: GameIdentityRegistry = .shared
    ) {
        self.fileManager = fileManager
        self.identityRegistry = identityRegistry
    }

    func delete(_ game: InstalledGame, mode: GameDeletionMode) throws {
        switch mode {
        case .gameOnly:
            try removeLibraryPayload(for: game)
            // Keep identity binding + Saves/<uuid> so reimport restores the same install ID.
        case .everything:
            try removeLibraryPayload(for: game)
            try removeSaveData(for: game)
            try removeSettings(for: game)
            try removeMetadataCache(for: game)
            identityRegistry.removeBinding(forContentHash: game.contentHash)
        }
    }

    func saveDataDirectory(for game: InstalledGame) -> URL? {
        LibraryGamePaths.savesDirectory(installID: game.id, fileManager: fileManager)
    }

    func saveDataExists(for game: InstalledGame) -> Bool {
        guard let url = saveDataDirectory(for: game) else { return false }
        guard fileManager.fileExists(atPath: url.path) else { return false }
        let contents = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
        return !contents.isEmpty
    }

    // MARK: - Private

    private func removeLibraryPayload(for game: InstalledGame) throws {
        let directory = LibraryGamePaths.gameDirectory(for: game, fileManager: fileManager)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        // Also clear hash-keyed metadata cache (covers/screenshots mirrored for sync).
        try removeMetadataCache(for: game)
    }

    private func removeSaveData(for game: InstalledGame) throws {
        guard let url = LibraryGamePaths.savesDirectory(installID: game.id, fileManager: fileManager),
              fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func removeSettings(for game: InstalledGame) throws {
        guard !game.contentHash.isEmpty,
              let url = LibraryGamePaths.settingsURL(contentHash: game.contentHash, fileManager: fileManager),
              fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func removeMetadataCache(for game: InstalledGame) throws {
        guard !game.contentHash.isEmpty,
              let url = LibraryGamePaths.metadataCacheDirectory(
                contentHash: game.contentHash,
                fileManager: fileManager
              ),
              fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }
}
