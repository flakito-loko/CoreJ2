import SwiftUI

/// Interactive game card for grid presentation.
struct GameCardView: View {
    let game: InstalledGame
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    var onOpenDetail: (() -> Void)? = nil
    var onAction: ((LibraryGameAction) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Button {
                    onOpenDetail?()
                } label: {
                    GameCoverView(game: game)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: LibraryTheme.coverCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: LibraryTheme.coverCornerRadius, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details for \(game.title)")

                Button(action: onToggleFavorite) {
                    Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(game.isFavorite ? Color.red.opacity(0.9) : .white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(game.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(LibraryTheme.cardTitleFont())
                    .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(game.publisher)
                    .font(LibraryTheme.metaFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !game.genre.isEmpty {
                    Text(game.genre)
                        .font(LibraryTheme.metaFont(relativeTo: .caption2))
                        .foregroundStyle(LibraryTheme.teal)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(game.resolution)
                        .font(LibraryTheme.metaFont(relativeTo: .caption2))
                        .foregroundStyle(.tertiary)
                    CompatibilityBadge(compatibility: game.compatibility)
                }

                Text(lastPlayedLabel)
                    .font(LibraryTheme.metaFont(relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onPlay) {
                Text("Play")
                    .font(LibraryTheme.metaFont(relativeTo: .subheadline))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LibraryTheme.teal, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(game.title)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
        )
        .accessibilityElement(children: .contain)
        .contextMenu {
            gameContextMenu
        }
    }

    @ViewBuilder
    private var gameContextMenu: some View {
        ForEach(LibraryGameAction.allCases) { action in
            Button(
                role: action.isDestructive ? .destructive : nil,
                action: { onAction?(action) }
            ) {
                Label(
                    action.title(isFavorite: game.isFavorite),
                    systemImage: action == .favorite
                        ? (game.isFavorite ? "heart.slash" : "heart.fill")
                        : action.systemImage
                )
            }
        }
    }

    private var lastPlayedLabel: String {
        guard let date = game.lastPlayedAt else {
            return "Not played yet"
        }
        return "Played \(date.formatted(.relative(presentation: .named)))"
    }
}

struct CompatibilityBadge: View {
    let compatibility: GameCompatibility

    var body: some View {
        Text(compatibility.badgeTitle)
            .font(LibraryTheme.metaFont(relativeTo: .caption2))
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.18), in: Capsule())
            .foregroundStyle(badgeColor)
            .accessibilityLabel("Compatibility \(compatibility.badgeTitle)")
    }

    private var badgeColor: Color {
        switch compatibility {
        case .ready: return LibraryTheme.teal
        case .limited: return LibraryTheme.gold
        case .unknown: return .secondary
        }
    }
}
