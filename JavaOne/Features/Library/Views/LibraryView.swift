import SwiftUI
import UniformTypeIdentifiers

/// Displays the user's Java ME game library and launches the emulator.
struct LibraryView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: LibraryViewModel

    // MARK: - UI State

    @State private var isImportPresented = false

    // MARK: - Init

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import Game") {
                            isImportPresented = true
                        }
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
        }
        .onAppear {
            viewModel.loadGames()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.games.isEmpty {
            emptyState
        } else {
            gameList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Games")
                .font(.title2.weight(.semibold))

            Text("Import a Java ME game to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let selectedFileName = viewModel.selectedFileName {
                Text(selectedFileName)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var gameList: some View {
        List(viewModel.games) { game in
            Button {
                viewModel.selectGame(game)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Tap to play")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
        let repository = InMemoryGameLibraryRepository()
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
                }
            )
        )
    }
}
