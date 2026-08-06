import SwiftUI

/// Per-game settings sheet (library-side; keyed by SHA-256 identity).
struct GameSettingsView: View {
    let game: InstalledGame
    @State private var notes: String
    @State private var compatibilityRaw: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onSave: (GameSettings, GameCompatibility) -> Void
    let onChangeCover: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        game: InstalledGame,
        settings: GameSettings,
        onToggleFavorite: @escaping () -> Void,
        onSave: @escaping (GameSettings, GameCompatibility) -> Void,
        onChangeCover: @escaping () -> Void
    ) {
        self.game = game
        self._notes = State(initialValue: settings.notes)
        self._compatibilityRaw = State(
            initialValue: settings.preferredCompatibility ?? game.compatibility.rawValue
        )
        self.isFavorite = game.isFavorite
        self.onToggleFavorite = onToggleFavorite
        self.onSave = onSave
        self.onChangeCover = onChangeCover
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    LabeledContent("Title", value: game.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHA-256")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(game.stableIdentity)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("stable-identity-hash")
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
                        onSave(settings, compatibility)
                        dismiss()
                    }
                }
            }
        }
    }
}
