import Foundation
import UIKit

/// Manages custom vs default covers for an installed game (all local files).
@MainActor
final class GameCoverStore {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Writes a user-selected image as the active custom cover.
    func applyCustomCover(imageData: Data, to game: InstalledGame) throws -> InstalledGame {
        guard UIImage(data: imageData) != nil else {
            throw CoverStoreError.invalidImage
        }

        let artworkDirectory = game.jarURL
            .deletingLastPathComponent()
            .appendingPathComponent("artwork", isDirectory: true)
        try fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)

        let destination = artworkDirectory.appendingPathComponent("custom-cover.jpg", isDirectory: false)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // Prefer JPEG for custom covers.
        if let jpeg = UIImage(data: imageData)?.jpegData(compressionQuality: 0.92) {
            try jpeg.write(to: destination, options: .atomic)
        } else {
            try imageData.write(to: destination, options: .atomic)
        }

        LibraryCoverImageCache.shared.clear()

        let defaultCover = game.defaultCoverURL
            ?? artworkDirectory.appendingPathComponent("cover.jpg", isDirectory: false).existingFile
            ?? artworkDirectory.appendingPathComponent("icon.png", isDirectory: false).existingFile

        return game.updating(
            coverURL: .some(destination),
            defaultCoverURL: .some(defaultCover),
            hasCustomCover: true
        )
    }

    /// Removes the custom cover and restores the default (metadata cover or JAR icon).
    func restoreDefaultCover(for game: InstalledGame) throws -> InstalledGame {
        let artworkDirectory = game.jarURL
            .deletingLastPathComponent()
            .appendingPathComponent("artwork", isDirectory: true)
        let custom = artworkDirectory.appendingPathComponent("custom-cover.jpg", isDirectory: false)
        if fileManager.fileExists(atPath: custom.path) {
            try fileManager.removeItem(at: custom)
        }

        LibraryCoverImageCache.shared.clear()

        let restored = game.defaultCoverURL
            ?? artworkDirectory.appendingPathComponent("cover.jpg", isDirectory: false).existingFile
            ?? artworkDirectory.appendingPathComponent("icon.png", isDirectory: false).existingFile

        return game.updating(
            coverURL: .some(restored),
            hasCustomCover: false
        )
    }
}

enum CoverStoreError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected file is not a valid image."
        }
    }
}

private extension URL {
    var existingFile: URL? {
        FileManager.default.fileExists(atPath: path) ? self : nil
    }
}
