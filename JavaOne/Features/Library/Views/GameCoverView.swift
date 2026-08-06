import SwiftUI
import UIKit

/// Deterministic gradient cover when a MIDlet has no extracted artwork.
struct GeneratedCoverView: View {
    let title: String
    let publisher: String
    let resolution: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: 0, y: h * 0.55))
                    path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.35))
                    path.addLine(to: CGPoint(x: w, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(palette[1].opacity(0.35))
            }

            VStack(spacing: 8) {
                Text(initials)
                    .font(.custom("AvenirNext-Heavy", size: 42, relativeTo: .largeTitle))
                    .foregroundStyle(.white.opacity(0.95))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(title)
                    .font(LibraryTheme.cardTitleFont())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(publisher)
                    .font(LibraryTheme.metaFont())
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                Text(resolution)
                    .font(LibraryTheme.metaFont(relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Generated cover for \(title)")
    }

    private var initials: String {
        let words = title
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().isEmpty ? "J2" : letters.joined().uppercased()
    }

    private var palette: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.05, green: 0.28, blue: 0.36), Color(red: 0.10, green: 0.55, blue: 0.52)],
            [Color(red: 0.12, green: 0.18, blue: 0.28), Color(red: 0.22, green: 0.42, blue: 0.48)],
            [Color(red: 0.18, green: 0.22, blue: 0.16), Color(red: 0.35, green: 0.48, blue: 0.28)],
            [Color(red: 0.22, green: 0.16, blue: 0.14), Color(red: 0.55, green: 0.38, blue: 0.22)],
            [Color(red: 0.10, green: 0.20, blue: 0.32), Color(red: 0.18, green: 0.45, blue: 0.58)],
            [Color(red: 0.16, green: 0.14, blue: 0.22), Color(red: 0.32, green: 0.36, blue: 0.52)]
        ]
        let index = abs(title.hashValue) % palettes.count
        return palettes[index]
    }
}

/// Cover artwork with cached disk image or generated placeholder.
struct GameCoverView: View {
    let game: InstalledGame

    @State private var cachedImage: UIImage?

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                GeneratedCoverView(
                    title: game.title,
                    publisher: game.publisher,
                    resolution: game.resolution
                )
            }
        }
        .onAppear(perform: loadCover)
        .onChange(of: game.coverURL) { _, _ in
            loadCover()
        }
    }

    private func loadCover() {
        guard let url = game.coverURL else {
            cachedImage = nil
            return
        }
        cachedImage = LibraryCoverImageCache.shared.image(at: url)
    }
}
