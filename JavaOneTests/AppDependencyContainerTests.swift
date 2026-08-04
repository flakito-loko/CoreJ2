import SwiftData
import XCTest
@testable import JavaOne

@MainActor
final class AppDependencyContainerTests: XCTestCase {

    // MARK: - Production DI

    func testProductionRuntimeHostIsFreeJ2MERuntimeHost() throws {
        let container = try makeContainer()

        XCTAssertTrue(container.productionRuntimeHost is FreeJ2MERuntimeHost)
    }

    func testMakeEmulatorViewModelUsesSharedBridgeBackedByFreeJ2MEHost() throws {
        let container = try makeContainer()
        _ = container.makeEmulatorViewModel()

        XCTAssertTrue(container.productionRuntimeHost is FreeJ2MERuntimeHost)
        let first = container.makeEmulatorBridge()
        let second = container.makeEmulatorBridge()
        XCTAssertTrue((first as AnyObject) === (second as AnyObject))
    }

    // MARK: - Graceful Unavailable Runtime (iOS)

    func testLaunchThroughProductionPipelineFailsGracefullyWhenRuntimeUnavailable() async throws {
        let container = try makeContainer()
        let viewModel = container.makeEmulatorViewModel()
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let game = InstalledGame(
            id: UUID(),
            title: "DI Launch Probe",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: "deadbeef"
        )

        await viewModel.startSession(for: game)

        #if os(iOS)
        XCTAssertNil(viewModel.activeSession)
        XCTAssertEqual(
            viewModel.launchErrorMessage,
            EmulatorBridgeError.runtimeUnavailable.localizedDescription
        )
        #else
        // macOS host JVM may succeed or fail depending on Java / FreeJ2ME tooling.
        // Either a running session or a typed launch error is acceptable here.
        XCTAssertTrue(
            viewModel.activeSession != nil || viewModel.launchErrorMessage != nil
        )
        #endif
    }

    // MARK: - Helpers

    private func makeContainer() throws -> AppDependencyContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: InstalledGameEntity.self,
            configurations: configuration
        )
        return AppDependencyContainer(modelContainer: modelContainer)
    }

    private func makeTemporaryJAR() throws -> URL {
        let jarURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jar")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: jarURL)
        return jarURL
    }
}
