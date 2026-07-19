import SwiftUI

@main
struct JavaOneApp: App {

    // MARK: - Dependencies

    @StateObject private var libraryViewModel: LibraryViewModel

    // MARK: - Init

    init() {
        let dependencies = AppDependencyContainer()
        _libraryViewModel = StateObject(wrappedValue: dependencies.makeLibraryViewModel())
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            LibraryView(viewModel: libraryViewModel)
        }
    }
}
