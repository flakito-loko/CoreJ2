import Foundation

/// Lightweight per-game settings stored under the stable SHA-256 identity.
struct GameSettings: Codable, Equatable, Sendable {
    var notes: String
    var preferredCompatibility: String?

    init(notes: String = "", preferredCompatibility: String? = nil) {
        self.notes = notes
        self.preferredCompatibility = preferredCompatibility
    }
}

@MainActor
final class GameSettingsStore {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(for contentHash: String) -> GameSettings {
        guard !contentHash.isEmpty,
              let url = LibraryGamePaths.settingsURL(contentHash: contentHash, fileManager: fileManager),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(GameSettings.self, from: data) else {
            return GameSettings()
        }
        return decoded
    }

    func save(_ settings: GameSettings, for contentHash: String) {
        guard !contentHash.isEmpty,
              let url = LibraryGamePaths.settingsURL(contentHash: contentHash, fileManager: fileManager),
              let data = try? JSONEncoder().encode(settings) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}
