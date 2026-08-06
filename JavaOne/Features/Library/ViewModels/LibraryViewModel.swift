import Combine
import Foundation
import SwiftUI

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

    /// Game presented in the detail / cover sheet.
    @Published var gameForDetail: InstalledGame?

    /// True while metadata enrichment is running after import.
    @Published private(set) var isEnrichingMetadata = false

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
                || game.genre.localizedCaseInsensitiveContains(query)
                || game.developer.localizedCaseInsensitiveContains(query)
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
    private let metadataEnricher: GameMetadataEnricher
    private let coverStore: GameCoverStore

    // MARK: - Init

    init(
        repository: GameLibraryRepository,
        importEngine: ImportEngineProtocol,
        makeEmulatorViewModel: @escaping () -> EmulatorViewModel,
        metadataEnricher: GameMetadataEnricher,
        coverStore: GameCoverStore = GameCoverStore()
    ) {
        self.repository = repository
        self.importEngine = importEngine
        self.makeEmulatorViewModel = makeEmulatorViewModel
        self.metadataEnricher = metadataEnricher
        self.coverStore = coverStore
    }

    // MARK: - Intentions

    func loadGames() {
        games = repository.fetchGames()
        Task { await enrichGamesMissingMetadata() }
    }

    /// Backfills catalog/HTTP metadata for titles imported before LIBRARY-US002.
    private func enrichGamesMissingMetadata() async {
        let pending = games.filter { !$0.hasCachedMetadata }
        guard !pending.isEmpty else { return }
        isEnrichingMetadata = true
        defer { isEnrichingMetadata = false }
        for game in pending {
            let enriched = await metadataEnricher.enrich(game)
            if enriched.hasCachedMetadata || enriched.coverURL != game.coverURL {
                repository.save(enriched)
            }
        }
        games = repository.fetchGames()
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileName = url.lastPathComponent
            Task { await importSelectedJAR(from: url) }
        case .failure:
            break
        }
    }

    func toggleFavorite(_ game: InstalledGame) {
        let updated = game.updating(isFavorite: !game.isFavorite)
        repository.save(updated)
        games = repository.fetchGames()
        refreshDetailIfNeeded(updated.id)
    }

    func selectGame(_ game: InstalledGame) {
        let updated = game.updating(lastPlayedAt: .some(Date()))
        repository.save(updated)
        games = repository.fetchGames()

        activeEmulatorViewModel = makeEmulatorViewModel()
        gameToLaunch = games.first(where: { $0.id == updated.id }) ?? updated
    }

    func openDetail(_ game: InstalledGame) {
        gameForDetail = game
    }

    func dismissDetail() {
        gameForDetail = nil
    }

    func dismissEmulator() {
        gameToLaunch = nil
        activeEmulatorViewModel = nil
    }

    func dismissSuccessMessage() {
        successMessage = nil
    }

    func dismissErrorMessage() {
        errorMessage = nil
    }

    /// Re-runs provider lookup for an existing game (uses cache afterward).
    func refreshMetadata(for game: InstalledGame) {
        Task {
            isEnrichingMetadata = true
            defer { isEnrichingMetadata = false }
            let enriched = await metadataEnricher.enrich(game)
            repository.save(enriched)
            games = repository.fetchGames()
            refreshDetailIfNeeded(game.id)
        }
    }

    func applyCoverImageData(_ data: Data, to game: InstalledGame) {
        do {
            let updated = try coverStore.applyCustomCover(imageData: data, to: game)
            repository.save(updated)
            games = repository.fetchGames()
            refreshDetailIfNeeded(game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreDefaultCover(for game: InstalledGame) {
        do {
            let updated = try coverStore.restoreDefaultCover(for: game)
            repository.save(updated)
            games = repository.fetchGames()
            refreshDetailIfNeeded(game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func importSelectedJAR(from url: URL) async {
        do {
            var installedGame = try importEngine.importJAR(from: url)
            repository.save(installedGame)
            games = repository.fetchGames()

            isEnrichingMetadata = true
            installedGame = await metadataEnricher.enrich(installedGame)
            isEnrichingMetadata = false
            repository.save(installedGame)
            games = repository.fetchGames()

            errorMessage = nil
            let metaNote = installedGame.hasCachedMetadata ? " Metadata cached for offline use." : ""
            successMessage = "\"\(url.lastPathComponent)\" was imported successfully.\(metaNote)"
        } catch {
            isEnrichingMetadata = false
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func refreshDetailIfNeeded(_ id: UUID) {
        if gameForDetail?.id == id {
            gameForDetail = games.first(where: { $0.id == id })
        }
    }
}
