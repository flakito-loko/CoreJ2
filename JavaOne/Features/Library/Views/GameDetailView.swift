import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Detail sheet: metadata, screenshots, and cover management.
struct GameDetailView: View {
    let game: InstalledGame
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onRestoreCover: () -> Void
    let onApplyCoverData: (Data) -> Void
    let onRefreshMetadata: () -> Void
    var onSettings: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onShowSaveData: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var photoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    coverBlock
                    metaBlock
                    if !game.gameDescription.isEmpty {
                        descriptionBlock
                    }
                    if !game.screenshotURLs.isEmpty {
                        screenshotsBlock
                    }
                    managementActions
                    coverActions
                    Button(action: onPlay) {
                        Text("Play")
                            .font(LibraryTheme.sectionFont(relativeTo: .headline))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LibraryTheme.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play \(game.title)")
                }
                .padding(LibraryTheme.horizontalPadding)
                .padding(.bottom, 28)
            }
            .background(LibraryTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(game.isFavorite ? Color.red.opacity(0.9) : .primary)
                    }
                    .accessibilityLabel(game.isFavorite ? "Remove from favorites" : "Add to favorites")
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image, .jpeg, .png, .heic],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    onApplyCoverData(data)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        onApplyCoverData(data)
                    }
                    photoItem = nil
                }
            }
        }
    }

    private var coverBlock: some View {
        GameCoverView(game: game)
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxWidth: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Cover art for \(game.title)")
    }

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeled("Publisher", game.publisher)
            if !game.developer.isEmpty {
                labeled("Developer", game.developer)
            }
            if !game.genre.isEmpty {
                labeled("Genre", game.genre)
            }
            if let year = game.releaseYear {
                labeled("Year", String(year))
            }
            labeled("Resolution", game.resolution)
            if !game.midletVersion.isEmpty {
                labeled("Version", game.midletVersion)
            }
            if !game.stableIdentity.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHA-256")
                        .font(LibraryTheme.metaFont())
                        .foregroundStyle(.secondary)
                    Text(game.stableIdentity)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("detail-stable-identity")
                }
            }
            CompatibilityBadge(compatibility: game.compatibility)
            if game.hasCachedMetadata {
                Text(game.metadataProviderID.isEmpty ? "Metadata cached offline" : "Cached via \(game.metadataProviderID)")
                    .font(LibraryTheme.metaFont(relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("metadata-cached-badge")
            }
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(LibraryTheme.sectionFont(relativeTo: .title3))
            Text(game.gameDescription)
                .font(LibraryTheme.metaFont(relativeTo: .body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("game-description")
        }
    }

    private var screenshotsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Screenshots")
                .font(LibraryTheme.sectionFont(relativeTo: .title3))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(game.screenshotURLs, id: \.path) { url in
                        if let image = LibraryCoverImageCache.shared.image(at: url) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var managementActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage")
                .font(LibraryTheme.sectionFont(relativeTo: .title3))

            if let onSettings {
                Button(action: onSettings) {
                    actionLabel("Game Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
            if let onShare {
                Button(action: onShare) {
                    actionLabel("Share JAR", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
            if let onShowSaveData {
                Button(action: onShowSaveData) {
                    actionLabel("Show Save Data", systemImage: "folder")
                }
                .buttonStyle(.plain)
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    actionLabel("Delete Game", systemImage: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var coverActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cover")
                .font(LibraryTheme.sectionFont(relativeTo: .title3))

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Import Cover from Photos")
                    Spacer()
                }
                .font(LibraryTheme.metaFont(relativeTo: .body))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.7))
                )
                .foregroundStyle(colorScheme == .dark ? Color.white : LibraryTheme.ink)
            }

            Button {
                isFileImporterPresented = true
            } label: {
                actionLabel("Import Cover from Files", systemImage: "folder")
            }
            .buttonStyle(.plain)

            Button(action: onRestoreCover) {
                actionLabel("Restore Default", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .disabled(!game.hasCustomCover && game.defaultCoverURL == game.coverURL)

            Button(action: onRefreshMetadata) {
                actionLabel("Refresh Metadata", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(LibraryTheme.metaFont())
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(LibraryTheme.metaFont(relativeTo: .body))
                .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.ink)
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer()
        }
        .font(LibraryTheme.metaFont(relativeTo: .body))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.7))
        )
        .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.ink)
    }
}
