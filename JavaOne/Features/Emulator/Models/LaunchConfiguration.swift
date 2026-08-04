import Foundation

/// Inputs required to launch an installed Java ME game through the emulator bridge.
struct LaunchConfiguration: Equatable, Sendable, Hashable {

    // MARK: - Properties

    /// The installed game that should be launched.
    let game: InstalledGame

    // MARK: - Init

    init(game: InstalledGame) {
        self.game = game
    }
}
