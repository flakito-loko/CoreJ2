import SwiftUI
import UniformTypeIdentifiers

/// Displays the user's Java ME game library and launches the emulator.
struct LibraryView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: LibraryViewModel

    // MARK: - UI State

    @State private var isImportPresented = false
    @Namespace private var libraryNamespace
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Init

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LibraryTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    layoutPicker
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImportPresented = true
                    } label: {
                        Label("Import", systemImage: "plus")
                    }
                    .accessibilityLabel("Import Game")
                }
            }
            .fileImporter(
                isPresented: $isImportPresented,
                allowedContentTypes: Self.jarContentTypes,
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleImportResult(result)
            }
            .alert(
                "Import Successful",
                isPresented: successAlertBinding
            ) {
                Button("OK", role: .cancel) {
                    viewModel.dismissSuccessMessage()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .alert(
                "Import Failed",
                isPresented: errorAlertBinding
            ) {
                Button("OK", role: .cancel) {
                    viewModel.dismissErrorMessage()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .navigationDestination(item: gameToLaunchBinding) { game in
                if let emulatorViewModel = viewModel.activeEmulatorViewModel {
                    EmulatorView(viewModel: emulatorViewModel, game: game)
                }
            }
            .sheet(item: $viewModel.gameForDetail) { game in
                GameDetailView(
                    game: game,
                    onPlay: {
                        viewModel.dismissDetail()
                        viewModel.selectGame(game)
                    },
                    onToggleFavorite: { viewModel.toggleFavorite(game) },
                    onRestoreCover: { viewModel.restoreDefaultCover(for: game) },
                    onApplyCoverData: { viewModel.applyCoverImageData($0, to: game) },
                    onRefreshMetadata: { viewModel.refreshMetadata(for: game) },
                    onSettings: { viewModel.handle(.settings, for: game) },
                    onShare: { viewModel.handle(.shareJAR, for: game) },
                    onShowSaveData: { viewModel.handle(.showSaveData, for: game) },
                    onDelete: { viewModel.handle(.delete, for: game) }
                )
            }
            .sheet(item: $viewModel.gameForSettings) { game in
                GameSettingsView(
                    game: game,
                    settings: viewModel.settings(for: game),
                    onToggleFavorite: { viewModel.toggleFavorite(game) },
                    onSave: { settings, compatibility, identity in
                        viewModel.saveSettings(
                            settings,
                            compatibility: compatibility,
                            identity: identity,
                            for: game
                        )
                    },
                    onChangeCover: {
                        viewModel.dismissSettings()
                        viewModel.openDetail(game)
                    }
                )
            }
            .sheet(item: $viewModel.gameForSaveData) { game in
                GameSaveDataView(
                    game: game,
                    rootURL: viewModel.saveDataURL(for: game)
                )
            }
            .sheet(item: $viewModel.gamePendingShare) { game in
                ActivityShareView(items: [game.jarURL])
                    .presentationDetents([.medium])
            }
            .alert(
                deletionTitle,
                isPresented: deletionDialogBinding
            ) {
                Button("Delete Game", role: .destructive) {
                    viewModel.confirmDelete(mode: .gameOnly)
                }
                Button("Delete Everything", role: .destructive) {
                    viewModel.confirmDelete(mode: .everything)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.dismissDeletionPrompt()
                }
            } message: {
                Text("Delete Game removes the JAR and artwork but keeps save data. Delete Everything also removes RMS saves and settings.")
            }
            .overlay(alignment: .top) {
                if viewModel.isEnrichingMetadata {
                    Text("Fetching metadata…")
                        .font(LibraryTheme.metaFont(relativeTo: .caption))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .accessibilityIdentifier("metadata-enriching")
                }
            }
        }
        .onAppear {
            viewModel.loadGames()
        }
    }

    private var deletionTitle: String {
        if let title = viewModel.gamePendingDeletion?.title {
            return "Delete \(title)?"
        }
        return "Delete Game?"
    }

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel.gamePendingDeletion != nil },
            set: { presented in
                if !presented {
                    viewModel.dismissDeletionPrompt()
                }
            }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.games.isEmpty {
            emptyState
        } else {
            libraryScroll
        }
    }

    private var libraryScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LibraryTheme.sectionSpacing) {
                header
                    .padding(.horizontal, LibraryTheme.horizontalPadding)

                if !viewModel.favoriteGames.isEmpty && viewModel.searchText.isEmpty {
                    section(title: "Favorites") {
                        horizontalStrip(games: viewModel.favoriteGames)
                    }
                }

                if !viewModel.recentGames.isEmpty && viewModel.searchText.isEmpty {
                    section(title: "Recent") {
                        horizontalStrip(games: viewModel.recentGames)
                    }
                }

                section(title: viewModel.searchText.isEmpty ? "All Games" : "Results") {
                    gamesCollection
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LibraryTheme.brandName)
                .font(LibraryTheme.brandFont())
                .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.navy)
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.gameCountLabel)
                .font(LibraryTheme.metaFont(relativeTo: .subheadline))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search games", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(LibraryTheme.metaFont(relativeTo: .body))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
            )
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(LibraryTheme.sectionFont())
                .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.ink)
                .padding(.horizontal, LibraryTheme.horizontalPadding)

            content()
        }
    }

    private func horizontalStrip(games: [InstalledGame]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: LibraryTheme.gridSpacing) {
                ForEach(games) { game in
                    GameCardView(
                        game: game,
                        onPlay: { viewModel.selectGame(game) },
                        onToggleFavorite: { viewModel.toggleFavorite(game) },
                        onOpenDetail: { viewModel.openDetail(game) },
                        onAction: { viewModel.handle($0, for: game) }
                    )
                    .frame(width: 168)
                    .matchedGeometryEffect(id: "strip-\(game.id)", in: libraryNamespace)
                }
            }
            .padding(.horizontal, LibraryTheme.horizontalPadding)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var gamesCollection: some View {
        let games = viewModel.filteredGames
        if games.isEmpty {
            Text("No games match your search.")
                .font(LibraryTheme.metaFont(relativeTo: .body))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LibraryTheme.horizontalPadding)
        } else {
            switch viewModel.layoutMode {
            case .grid:
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: LibraryTheme.gridSpacing),
                        GridItem(.flexible(), spacing: LibraryTheme.gridSpacing)
                    ],
                    spacing: LibraryTheme.gridSpacing
                ) {
                    ForEach(games) { game in
                        GameCardView(
                            game: game,
                            onPlay: { viewModel.selectGame(game) },
                            onToggleFavorite: { viewModel.toggleFavorite(game) },
                            onOpenDetail: { viewModel.openDetail(game) },
                            onAction: { viewModel.handle($0, for: game) }
                        )
                        .matchedGeometryEffect(id: "grid-\(game.id)", in: libraryNamespace)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .padding(.horizontal, LibraryTheme.horizontalPadding)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.layoutMode)
                .animation(.easeInOut(duration: 0.22), value: viewModel.searchText)

            case .list:
                LazyVStack(spacing: 4) {
                    ForEach(games) { game in
                        GameListRowView(
                            game: game,
                            onPlay: { viewModel.selectGame(game) },
                            onToggleFavorite: { viewModel.toggleFavorite(game) },
                            onOpenDetail: { viewModel.openDetail(game) },
                            onAction: { viewModel.handle($0, for: game) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.55))
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.handle(.delete, for: game)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                viewModel.handle(.shareJAR, for: game)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(LibraryTheme.teal)
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .padding(.horizontal, LibraryTheme.horizontalPadding)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.layoutMode)
                .animation(.easeInOut(duration: 0.22), value: viewModel.searchText)
            }
        }
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $viewModel.layoutMode) {
            ForEach(LibraryLayoutMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
                    .accessibilityLabel(mode.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 96)
        .onChange(of: viewModel.layoutMode) { _, _ in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(LibraryTheme.brandName)
                .font(LibraryTheme.brandFont())
                .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.navy)

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(LibraryTheme.teal)

            Text("No Games")
                .font(LibraryTheme.sectionFont())

            Text("Import a Java ME game to build your library.")
                .font(LibraryTheme.metaFont(relativeTo: .subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isImportPresented = true
            } label: {
                Text("Import Game")
                    .font(LibraryTheme.metaFont(relativeTo: .body))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(LibraryTheme.teal, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if let selectedFileName = viewModel.selectedFileName {
                Text(selectedFileName)
                    .font(LibraryTheme.metaFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LibraryTheme.horizontalPadding)
    }

    // MARK: - Bindings

    private var gameToLaunchBinding: Binding<InstalledGame?> {
        Binding(
            get: { viewModel.gameToLaunch },
            set: { newValue in
                if newValue == nil {
                    viewModel.dismissEmulator()
                } else {
                    viewModel.gameToLaunch = newValue
                }
            }
        )
    }

    private var successAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSuccessMessage()
                }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissErrorMessage()
                }
            }
        )
    }

    // MARK: - File Types

    private static let jarContentTypes: [UTType] = [
        UTType(filenameExtension: "jar")
            ?? UTType(exportedAs: "com.javaonelabs.java-archive")
    ]
}

// MARK: - Previews

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        let repository = InMemoryGameLibraryRepository(games: [
            InstalledGame(
                id: UUID(),
                title: "Miami Nights",
                jarURL: URL(fileURLWithPath: "/tmp/miami.jar"),
                importedAt: Date().addingTimeInterval(-86_400),
                contentHash: "abc",
                publisher: "Gameloft",
                resolution: "320 × 240",
                isFavorite: true,
                lastPlayedAt: Date().addingTimeInterval(-3_600),
                compatibility: .ready
            ),
            InstalledGame(
                id: UUID(),
                title: "Asphalt 3",
                jarURL: URL(fileURLWithPath: "/tmp/asphalt.jar"),
                importedAt: Date(),
                contentHash: "def",
                publisher: "Gameloft",
                resolution: "240 × 320",
                isFavorite: false,
                lastPlayedAt: nil,
                compatibility: .limited
            )
        ])
        LibraryView(
            viewModel: LibraryViewModel(
                repository: repository,
                importEngine: DefaultImportEngine(
                    pipeline: DefaultImportPipeline(
                        importService: FileImportService(),
                        steps: [
                            ManifestStep(manifestService: JARManifestService()),
                            HashStep(),
                            DuplicateDetectionStep(repository: repository),
                            ArtworkStep()
                        ]
                    )
                ),
                makeEmulatorViewModel: {
                    EmulatorViewModel(bridge: DefaultEmulatorBridge())
                },
                metadataEnricher: GameMetadataEnricher(
                    provider: CatalogMetadataProvider(entries: CatalogEntry.seedEntries)
                )
            )
        )
    }
}
