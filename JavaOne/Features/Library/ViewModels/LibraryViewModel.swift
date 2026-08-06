import Combine
import Foundation

/// Drives the game library screen and presentation of the emulator.
@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var games: [InstalledGame] = []

    /// Free-text filter over title and publisher.
    @Published var searchText: String = ""

    /// Grid or list presentation.
    @Published var layoutMode: LibraryLayoutMode = .grid

    /// File name of the most recently picked JAR, if any.
    @Published private(set) var selectedFileName: String?

    /// User-facing message shown after a successful import.
    @Published var successMessage: String?

    /// User-facing message shown after a failed import.
    @Published var errorMessage: String?

    /// Game selected for emulator presentation; `nil` dismisses the emulator.
    @Published var gameToLaunch: InstalledGame?

    /// View model bound to the presented `EmulatorView`, if any.
    private(set) var activeEmulatorViewModel: EmulatorViewModel?

    // MARK: - Derived

    var gameCountLabel: String {
        let count = games.count
        return count == 1 ? "1 game" : "\(count) games"
    }

    var filteredGames: [InstalledGame] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return games }
        return games.filter { game in
            game.title.localizedCaseInsensitiveContains(query)
                || game.publisher.localizedCaseInsensitiveContains(query)
        }
    }

    var favoriteGames: [InstalledGame] {
        games
            .filter(\.isFavorite)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var recentGames: [InstalledGame] {
        games
            .compactMap { game -> (InstalledGame, Date)? in
                guard let played = game.lastPlayedAt else { return nil }
                return (game, played)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
            .map(\.0)
    }

    // MARK: - Dependencies

    private let repository: GameLibraryRepository
    private let importEngine: ImportEngineProtocol
    private let makeEmulatorViewModel: () -> EmulatorViewModel

    // MARK: - Init

    /// - Parameters:
    ///   - repository: Library persistence.
    ///   - importEngine: JAR import pipeline.
    ///   - makeEmulatorViewModel: Factory for a fresh emulator surface VM per launch.
    init(
        repository: GameLibraryRepository,
        importEngine: ImportEngineProtocol,
        makeEmulatorViewModel: @escaping () -> EmulatorViewModel
    ) {
        self.repository = repository
        self.importEngine = importEngine
        self.makeEmulatorViewModel = makeEmulatorViewModel
    }

    // MARK: - Intentions

    /// Loads games from the library repository.
    func loadGames() {
        games = repository.fetchGames()
    }

    /// Handles the result of the system file importer.
    /// Cancellation is ignored. A selected JAR is copied into the internal library.
    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileName = url.lastPathComponent
            importSelectedJAR(from: url)
        case .failure:
            break
        }
    }

    /// Toggles favorite state and persists the change.
    func toggleFavorite(_ game: InstalledGame) {
        let updated = game.updating(isFavorite: !game.isFavorite)
        repository.save(updated)
        games = repository.fetchGames()
    }

    /// Prepares an emulator view model and presents `EmulatorView` for `game`.
    func selectGame(_ game: InstalledGame) {
        let updated = game.updating(lastPlayedAt: .some(Date()))
        repository.save(updated)
        games = repository.fetchGames()

        activeEmulatorViewModel = makeEmulatorViewModel()
        gameToLaunch = games.first(where: { $0.id == updated.id }) ?? updated
    }

    /// Dismisses the emulator screen and releases its view model.
    func dismissEmulator() {
        gameToLaunch = nil
        activeEmulatorViewModel = nil
    }

    /// Clears the success alert message.
    func dismissSuccessMessage() {
        successMessage = nil
    }

    /// Clears the error alert message.
    func dismissErrorMessage() {
        errorMessage = nil
    }

    // MARK: - Private

    private func importSelectedJAR(from url: URL) {
        do {
            let installedGame = try importEngine.importJAR(from: url)
            repository.save(installedGame)
            games = repository.fetchGames()
            errorMessage = nil
            successMessage = "\"\(url.lastPathComponent)\" was imported successfully."
        } catch {
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}
