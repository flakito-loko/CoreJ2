import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Drives the game library screen and presentation of the emulator.
@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var games: [InstalledGame] = []
    @Published var searchText: String = ""
    @Published var layoutMode: LibraryLayoutMode = .grid
    @Published private(set) var selectedFileName: String?
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var gameToLaunch: InstalledGame?
    @Published var gameForDetail: InstalledGame?
    @Published var gameForSettings: InstalledGame?
    @Published var gameForSaveData: InstalledGame?
    @Published var gamePendingShare: InstalledGame?
    @Published var gamePendingDeletion: InstalledGame?
    @Published private(set) var isEnrichingMetadata = false

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
                || game.contentHash.localizedCaseInsensitiveContains(query)
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
    private let installationManager: GameInstallationManager
    private let settingsStore: GameSettingsStore
    private let identityRegistry: GameIdentityRegistry

    // MARK: - Init

    init(
        repository: GameLibraryRepository,
        importEngine: ImportEngineProtocol,
        makeEmulatorViewModel: @escaping () -> EmulatorViewModel,
        metadataEnricher: GameMetadataEnricher,
        coverStore: GameCoverStore = GameCoverStore(),
        installationManager: GameInstallationManager = GameInstallationManager(),
        settingsStore: GameSettingsStore = GameSettingsStore(),
        identityRegistry: GameIdentityRegistry = .shared
    ) {
        self.repository = repository
        self.importEngine = importEngine
        self.makeEmulatorViewModel = makeEmulatorViewModel
        self.metadataEnricher = metadataEnricher
        self.coverStore = coverStore
        self.installationManager = installationManager
        self.settingsStore = settingsStore
        self.identityRegistry = identityRegistry
    }

    // MARK: - Intentions

    func loadGames() {
        games = repository.fetchGames()
        for game in games where !game.contentHash.isEmpty {
            identityRegistry.bind(contentHash: game.contentHash, installID: game.id)
        }
        Task { await enrichGamesMissingMetadata() }
    }

    private func enrichGamesMissingMetadata() async {
        let pending = games.filter { game in
            if !game.hasCachedMetadata { return true }
            // Re-enrich when catalog may now supply artwork for an install with no cover.
            if !game.hasCustomCover && game.coverURL == nil { return true }
            return false
        }
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

    func handle(_ action: LibraryGameAction, for game: InstalledGame) {
        switch action {
        case .play:
            selectGame(game)
        case .settings:
            presentSettings(game)
        case .favorite:
            toggleFavorite(game)
        case .changeCover:
            openDetail(game)
        case .shareJAR:
            presentShare(game)
        case .showSaveData:
            presentSaveData(game)
        case .delete:
            // Dismiss sheets so the native confirmation dialog is visible.
            gameForDetail = nil
            gameForSettings = nil
            gameForSaveData = nil
            gamePendingDeletion = game
        }
    }

    /// Presents settings after clearing other library sheets (iOS won't stack sibling `.sheet`s).
    private func presentSettings(_ game: InstalledGame) {
        let needsSettle = gameForDetail != nil || gameForSaveData != nil || gamePendingShare != nil
        gameForDetail = nil
        gameForSaveData = nil
        gamePendingShare = nil
        if needsSettle {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                gameForSettings = game
            }
        } else {
            gameForSettings = game
        }
    }

    private func presentSaveData(_ game: InstalledGame) {
        let needsSettle = gameForDetail != nil || gameForSettings != nil
        gameForDetail = nil
        gameForSettings = nil
        if needsSettle {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                gameForSaveData = game
            }
        } else {
            gameForSaveData = game
        }
    }

    private func presentShare(_ game: InstalledGame) {
        let needsSettle = gameForDetail != nil || gameForSettings != nil
        gameForDetail = nil
        gameForSettings = nil
        if needsSettle {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                gamePendingShare = game
            }
        } else {
            gamePendingShare = game
        }
    }

    func toggleFavorite(_ game: InstalledGame) {
        let updated = game.updating(isFavorite: !game.isFavorite)
        repository.save(updated)
        games = repository.fetchGames()
        refreshPresented(updated.id)
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

    func dismissDetail() { gameForDetail = nil }
    func dismissSettings() { gameForSettings = nil }
    func dismissSaveData() { gameForSaveData = nil }
    func dismissShare() { gamePendingShare = nil }
    func dismissDeletionPrompt() { gamePendingDeletion = nil }

    func dismissEmulator() {
        gameToLaunch = nil
        activeEmulatorViewModel = nil
    }

    func dismissSuccessMessage() { successMessage = nil }
    func dismissErrorMessage() { errorMessage = nil }

    func settings(for game: InstalledGame) -> GameSettings {
        settingsStore.load(for: game.contentHash)
    }

    func saveSettings(
        _ settings: GameSettings,
        compatibility: GameCompatibility,
        identity: GameIdentityEdits,
        for game: InstalledGame
    ) {
        settingsStore.save(settings, for: game.contentHash)

        let trimmedDisplay = identity.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let useOfficialTitle = identity.resetDisplayTitle || trimmedDisplay.isEmpty || trimmedDisplay == game.officialTitle
        let parsedYear = Int(identity.releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines))

        var updated = game.updating(
            publisher: identity.resetPublisher ? game.officialPublisher : identity.publisher,
            compatibility: compatibility,
            genre: identity.resetGenre ? game.officialGenre : identity.genre,
            releaseYear: identity.resetYear
                ? .some(game.officialReleaseYear)
                : .some(parsedYear),
            displayTitle: useOfficialTitle ? "" : trimmedDisplay,
            isDisplayTitleCustom: !useOfficialTitle,
            isPublisherCustom: !identity.resetPublisher && identity.publisher != game.officialPublisher,
            isGenreCustom: !identity.resetGenre && identity.genre != game.officialGenre,
            isReleaseYearCustom: !identity.resetYear && parsedYear != game.officialReleaseYear
        )

        // Keep effective publisher/genre aligned when resetting.
        if identity.resetPublisher {
            updated = updated.updating(publisher: game.officialPublisher, isPublisherCustom: false)
        }
        if identity.resetGenre {
            updated = updated.updating(genre: game.officialGenre, isGenreCustom: false)
        }

        repository.save(updated)
        games = repository.fetchGames()
        refreshPresented(game.id)
    }

    func saveDataURL(for game: InstalledGame) -> URL? {
        installationManager.saveDataDirectory(for: game)
    }

    func refreshMetadata(for game: InstalledGame) {
        Task {
            isEnrichingMetadata = true
            defer { isEnrichingMetadata = false }
            let enriched = await metadataEnricher.enrich(game)
            repository.save(enriched)
            games = repository.fetchGames()
            refreshPresented(game.id)
        }
    }

    func applyCoverImageData(_ data: Data, to game: InstalledGame) {
        do {
            let updated = try coverStore.applyCustomCover(imageData: data, to: game)
            repository.save(updated)
            games = repository.fetchGames()
            refreshPresented(game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreDefaultCover(for game: InstalledGame) {
        do {
            let updated = try coverStore.restoreDefaultCover(for: game)
            repository.save(updated)
            games = repository.fetchGames()
            refreshPresented(game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes library files and optionally RMS / settings / identity binding.
    func confirmDelete(mode: GameDeletionMode) {
        guard let game = gamePendingDeletion else { return }
        gamePendingDeletion = nil
        do {
            try installationManager.delete(game, mode: mode)
            repository.delete(game)
            if gameForDetail?.id == game.id { gameForDetail = nil }
            if gameForSettings?.id == game.id { gameForSettings = nil }
            if gameForSaveData?.id == game.id { gameForSaveData = nil }
            games = repository.fetchGames()
            let kept = mode == .gameOnly ? " Save data was kept." : " All related data was removed."
            successMessage = "\"\(game.title)\" deleted.\(kept)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func importSelectedJAR(from url: URL) async {
        do {
            var installedGame = try importEngine.importJAR(from: url)
            identityRegistry.bind(contentHash: installedGame.contentHash, installID: installedGame.id)
            repository.save(installedGame)
            games = repository.fetchGames()

            isEnrichingMetadata = true
            installedGame = await metadataEnricher.enrich(installedGame)
            isEnrichingMetadata = false
            repository.save(installedGame)
            games = repository.fetchGames()

            errorMessage = nil
            let metaNote = installedGame.hasCachedMetadata ? " Metadata cached for offline use." : ""
            let idNote = " Identity \(installedGame.stableIdentity.prefix(12))…"
            successMessage = "\"\(url.lastPathComponent)\" was imported successfully.\(metaNote)\(idNote)"
        } catch {
            isEnrichingMetadata = false
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPresented(_ id: UUID) {
        if gameForDetail?.id == id {
            gameForDetail = games.first(where: { $0.id == id })
        }
        if gameForSettings?.id == id {
            gameForSettings = games.first(where: { $0.id == id })
        }
    }
}
