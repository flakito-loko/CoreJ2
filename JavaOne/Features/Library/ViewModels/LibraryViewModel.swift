import Combine
import Foundation

/// Drives the game library screen and presentation of the emulator.
@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var games: [InstalledGame] = []

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

    /// Prepares an emulator view model and presents `EmulatorView` for `game`.
    func selectGame(_ game: InstalledGame) {
        activeEmulatorViewModel = makeEmulatorViewModel()
        gameToLaunch = game
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
