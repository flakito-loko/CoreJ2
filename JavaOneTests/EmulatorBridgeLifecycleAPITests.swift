import XCTest
@testable import JavaOne

@MainActor
final class EmulatorBridgeLifecycleAPITests: XCTestCase {

    // MARK: - Pause

    func testPauseMovesRunningSessionToPaused() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))

        try bridge.pause(session)

        XCTAssertEqual(session.state, .paused)
        XCTAssertNil(session.endedAt)
    }

    // MARK: - Resume

    func testResumeMovesPausedSessionToRunning() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))
        try bridge.pause(session)

        try bridge.resume(session)

        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.endedAt)
    }

    // MARK: - Stop

    func testStopMovesRunningSessionToStopped() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))

        try bridge.stop(session)

        XCTAssertEqual(session.state, .stopped)
        XCTAssertNotNil(session.endedAt)
    }

    func testStopMovesPausedSessionToStopped() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))
        try bridge.pause(session)

        try bridge.stop(session)

        XCTAssertEqual(session.state, .stopped)
        XCTAssertNotNil(session.endedAt)
    }

    // MARK: - Invalid Transitions

    func testPauseThrowsWhenSessionIsPaused() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))
        try bridge.pause(session)

        XCTAssertThrowsError(try bridge.pause(session)) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .invalidSession)
        }
        XCTAssertEqual(session.state, .paused)
    }

    func testResumeThrowsWhenSessionIsRunning() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))

        XCTAssertThrowsError(try bridge.resume(session)) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .invalidSession)
        }
        XCTAssertEqual(session.state, .running)
    }

    func testStopThrowsWhenSessionIsAlreadyStopped() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))
        try bridge.stop(session)

        XCTAssertThrowsError(try bridge.stop(session)) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .invalidSession)
        }
        XCTAssertEqual(session.state, .stopped)
    }

    func testPauseThrowsWhenSessionIsIdle() {
        let bridge = DefaultEmulatorBridge()
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar"))
        )

        XCTAssertThrowsError(try bridge.pause(session)) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .invalidSession)
        }
        XCTAssertEqual(session.state, .idle)
    }

    func testStopThrowsWhenSessionIsFailed() {
        let bridge = DefaultEmulatorBridge()
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")),
            state: .failed,
            endedAt: Date()
        )

        XCTAssertThrowsError(try bridge.stop(session)) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .invalidSession)
        }
        XCTAssertEqual(session.state, .failed)
    }

    // MARK: - Helpers

    private func makeConfiguration(jarURL: URL) -> LaunchConfiguration {
        LaunchConfiguration(
            game: InstalledGame(
                id: UUID(),
                title: "Test Game",
                jarURL: jarURL,
                importedAt: Date(),
                contentHash: "abc123"
            )
        )
    }

    private func makeTemporaryJAR() throws -> URL {
        let jarURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jar")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: jarURL)
        return jarURL
    }
}
