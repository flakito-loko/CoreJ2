import SwiftUI

/// Lists on-disk RMS / save files for a game (read-only library view).
struct GameSaveDataView: View {
    let game: InstalledGame
    let rootURL: URL?

    @Environment(\.dismiss) private var dismiss

    private var files: [URL] {
        guard let rootURL,
              FileManager.default.fileExists(atPath: rootURL.path),
              let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        var result: [URL] = []
        for case let url as URL in enumerator {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let rootURL {
                        Text(rootURL.path)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("save-data-path")
                    } else {
                        Text("Save directory unavailable.")
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("RMS saves live under Documents/JavaOne/Saves/<install UUID>. Delete Game keeps this folder; Delete Everything removes it.")
                }

                Section("Files") {
                    if files.isEmpty {
                        Text("No save data found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(files, id: \.path) { file in
                            Text(file.path.replacingOccurrences(of: rootURL?.path ?? "", with: ""))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Save Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: rootURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share Save Folder")
                    }
                }
            }
        }
    }
}
