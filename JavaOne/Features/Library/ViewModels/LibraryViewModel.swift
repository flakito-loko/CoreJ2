import Combine
import Foundation

/// Drives the game library screen.
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

    // MARK: - Dependencies

    private let repository: GameLibraryRepository
    private let importEngine: ImportEngineProtocol

    // MARK: - Init

    init(repository: GameLibraryRepository, importEngine: ImportEngineProtocol) {
        self.repository = repository
        self.importEngine = importEngine
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
