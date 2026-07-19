import SwiftUI

/// Displays the user's Java ME game library.
struct LibraryView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: LibraryViewModel

    // MARK: - Init

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var gameList: some View {
        List(viewModel.games) { game in
            Text(game.title)
        }
    }
}

// MARK: - Previews

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView(
            viewModel: LibraryViewModel(
                repository: InMemoryGameLibraryRepository()
            )
        )
    }
}
