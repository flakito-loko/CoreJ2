import SwiftUI

/// Compact row for list presentation.
struct GameListRowView: View {
    let game: InstalledGame
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            GameCoverView(game: game)
                .frame(width: 72, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(game.title)
                        .font(LibraryTheme.cardTitleFont())
                        .foregroundStyle(colorScheme == .dark ? .white : LibraryTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button(action: onToggleFavorite) {
                        Image(systemName: game.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(game.isFavorite ? LibraryTheme.gold : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(game.isFavorite ? "Remove from favorites" : "Add to favorites")
                }

                Text(game.publisher)
                    .font(LibraryTheme.metaFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(game.resolution)
                        .font(LibraryTheme.metaFont(relativeTo: .caption2))
                        .foregroundStyle(.tertiary)
                    CompatibilityBadge(compatibility: game.compatibility)
                }

                Text(lastPlayedLabel)
                    .font(LibraryTheme.metaFont(relativeTo: .caption2))
                    .foregroundStyle(.secondary)
            }

            Button(action: onPlay) {
                Text("Play")
                    .font(LibraryTheme.metaFont(relativeTo: .subheadline))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(LibraryTheme.teal, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(game.title)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private var lastPlayedLabel: String {
        guard let date = game.lastPlayedAt else {
            return "Not played yet"
        }
        return "Played \(date.formatted(.relative(presentation: .named)))"
    }
}
