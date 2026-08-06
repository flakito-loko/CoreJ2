import SwiftUI

/// Identity edit payload from Game Settings.
struct GameIdentityEdits: Equatable {
    var displayTitle: String
    var publisher: String
    var genre: String
    var releaseYearText: String
    var resetDisplayTitle: Bool
    var resetPublisher: Bool
    var resetGenre: Bool
    var resetYear: Bool
}

/// Per-game settings sheet (library-side; keyed by SHA-256 identity).
struct GameSettingsView: View {
    let game: InstalledGame
    @State private var notes: String
    @State private var compatibilityRaw: String
    @State private var displayTitle: String
    @State private var publisher: String
    @State private var genre: String
    @State private var releaseYearText: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onSave: (GameSettings, GameCompatibility, GameIdentityEdits) -> Void
    let onChangeCover: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        game: InstalledGame,
        settings: GameSettings,
        onToggleFavorite: @escaping () -> Void,
        onSave: @escaping (GameSettings, GameCompatibility, GameIdentityEdits) -> Void,
        onChangeCover: @escaping () -> Void
    ) {
        self.game = game
        self._notes = State(initialValue: settings.notes)
        self._compatibilityRaw = State(
            initialValue: settings.preferredCompatibility ?? game.compatibility.rawValue
        )
        self._displayTitle = State(initialValue: game.isDisplayTitleCustom ? game.displayTitle : game.title)
        self._publisher = State(initialValue: game.publisher)
        self._genre = State(initialValue: game.genre)
        self._releaseYearText = State(
            initialValue: game.releaseYear.map(String.init) ?? ""
        )
        self.isFavorite = game.isFavorite
        self.onToggleFavorite = onToggleFavorite
        self.onSave = onSave
        self.onChangeCover = onChangeCover
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHA-256")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(game.stableIdentity)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("stable-identity-hash")
                    }
                    LabeledContent("Official Name", value: game.officialTitle.isEmpty ? "—" : game.officialTitle)
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Artwork and metadata stay linked by SHA-256. Official Name is preserved when you rename the game.")
                }

                Section("Display Name") {
                    TextField("Display Name", text: $displayTitle)
                        .accessibilityIdentifier("edit-display-title")
                    if game.isDisplayTitleCustom {
                        Text("Custom")
                            .font(.caption)
                            .foregroundStyle(LibraryTheme.teal)
                    }
                    Button("Reset to Official Name") {
                        displayTitle = game.officialTitle
                    }
                    .disabled(displayTitle == game.officialTitle || game.officialTitle.isEmpty)
                }

                Section("Optional Metadata") {
                    TextField("Publisher", text: $publisher)
                        .accessibilityIdentifier("edit-publisher")
                    if game.isPublisherCustom {
                        Label("Custom publisher", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(LibraryTheme.teal)
                    }
                    Button("Reset Publisher") {
                        publisher = game.officialPublisher
                    }
                    .disabled(publisher == game.officialPublisher)

                    TextField("Genre", text: $genre)
                        .accessibilityIdentifier("edit-genre")
                    if game.isGenreCustom {
                        Label("Custom genre", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(LibraryTheme.teal)
                    }
                    Button("Reset Genre") {
                        genre = game.officialGenre
                    }
                    .disabled(genre == game.officialGenre)

                    TextField("Year", text: $releaseYearText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("edit-year")
                    if game.isReleaseYearCustom {
                        Label("Custom year", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(LibraryTheme.teal)
                    }
                    Button("Reset Year") {
                        releaseYearText = game.officialReleaseYear.map(String.init) ?? ""
                    }
                }

                Section("Library") {
                    Button(isFavorite ? "Remove Favorite" : "Add Favorite", action: onToggleFavorite)
                    Picker("Compatibility", selection: $compatibilityRaw) {
                        Text("Ready").tag(GameCompatibility.ready.rawValue)
                        Text("Limited").tag(GameCompatibility.limited.rawValue)
                        Text("Unknown").tag(GameCompatibility.unknown.rawValue)
                    }
                    Button("Change Cover…", action: onChangeCover)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .accessibilityIdentifier("game-settings-form")
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let settings = GameSettings(
                            notes: notes,
                            preferredCompatibility: compatibilityRaw
                        )
                        let compatibility = GameCompatibility(rawValue: compatibilityRaw) ?? game.compatibility
                        let edits = GameIdentityEdits(
                            displayTitle: displayTitle,
                            publisher: publisher,
                            genre: genre,
                            releaseYearText: releaseYearText,
                            resetDisplayTitle: displayTitle.trimmingCharacters(in: .whitespacesAndNewlines) == game.officialTitle
                                || displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            resetPublisher: publisher == game.officialPublisher,
                            resetGenre: genre == game.officialGenre,
                            resetYear: releaseYearText == (game.officialReleaseYear.map(String.init) ?? "")
                        )
                        onSave(settings, compatibility, edits)
                        dismiss()
                    }
                    .accessibilityIdentifier("save-game-settings")
                }
            }
        }
    }
}
