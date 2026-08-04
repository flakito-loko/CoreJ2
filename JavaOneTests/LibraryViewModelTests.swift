import XCTest
@testable import JavaOne

@MainActor
final class LibraryViewModelTests: XCTestCase {

    func testSelectGamePreparesEmulatorPresentation() {
        let viewModel = makeViewModel()
        let game = makeGame()

        viewModel.selectGame(game)

        XCTAssertEqual(viewModel.gameToLaunch, game)
        XCTAssertNotNil(viewModel.activeEmulatorViewModel)
    }

    func testDismissEmulatorClearsPresentationState() {
        let viewModel = makeViewModel()
        viewModel.selectGame(makeGame())

        viewModel.dismissEmulator()

        XCTAssertNil(viewModel.gameToLaunch)
        XCTAssertNil(viewModel.activeEmulatorViewModel)
    }

    func testSelectGameCreatesFreshEmulatorViewModelEachTime() {
        let viewModel = makeViewModel()
        viewModel.selectGame(makeGame())
        let first = viewModel.activeEmulatorViewModel

        viewModel.dismissEmulator()
        viewModel.selectGame(makeGame())
        let second = viewModel.activeEmulatorViewModel

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }

    // MARK: - Helpers

    private func makeViewModel() -> LibraryViewModel {
        LibraryViewModel(
            repository: InMemoryGameLibraryRepository(),
            importEngine: StubImportEngine(),
            makeEmulatorViewModel: {
                EmulatorViewModel(bridge: DefaultEmulatorBridge())
            }
        )
    }

    private func makeGame() -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: "Sonic",
            jarURL: URL(fileURLWithPath: "/tmp/sonic.jar"),
            importedAt: Date(),
            contentHash: "deadbeef"
        )
    }
}

// MARK: - Stubs

private struct StubImportEngine: ImportEngineProtocol {
    func importJAR(from url: URL) throws -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: url.deletingPathExtension().lastPathComponent,
            jarURL: url,
            importedAt: Date(),
            contentHash: "stub"
        )
    }
}
