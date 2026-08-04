import XCTest
@testable import JavaOne

@MainActor
final class EmulatorSessionLifecycleTests: XCTestCase {

    // MARK: - Initial Lifecycle

    func testSessionStartsIdleWithNoEndedAt() {
        let session = EmulatorSession(configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")))

        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.endedAt)
        XCTAssertNotNil(session.startedAt)
    }

    // MARK: - State Transitions

    func testTransitionFromStartingToRunning() {
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")),
            state: .starting
        )

        session.transition(to: .running)

        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.endedAt)
    }

    func testPauseResumeAndStopTransitions() {
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")),
            state: .running
        )

        session.transition(to: .paused)
        XCTAssertEqual(session.state, .paused)
        XCTAssertNil(session.endedAt)

        session.transition(to: .running)
        XCTAssertEqual(session.state, .running)

        session.transition(to: .stopping)
        XCTAssertEqual(session.state, .stopping)
        XCTAssertNil(session.endedAt)

        session.transition(to: .stopped)
        XCTAssertEqual(session.state, .stopped)
        XCTAssertNotNil(session.endedAt)
    }

    func testFailedTransitionRecordsEndedAt() {
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")),
            state: .starting
        )

        session.transition(to: .failed)

        XCTAssertEqual(session.state, .failed)
        XCTAssertNotNil(session.endedAt)
    }

    func testTerminalEndedAtIsNotOverwritten() {
        let session = EmulatorSession(
            configuration: makeConfiguration(jarURL: URL(fileURLWithPath: "/tmp/unused.jar")),
            state: .running
        )

        session.transition(to: .stopped)
        let firstEndedAt = session.endedAt

        session.transition(to: .failed)

        XCTAssertEqual(session.endedAt, firstEndedAt)
    }

    // MARK: - Unique Session IDs

    func testLaunchProducesUniqueSessionIDs() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let configuration = makeConfiguration(jarURL: jarURL)

        let first = try bridge.launch(configuration)
        try bridge.stop(first)
        let second = try bridge.launch(configuration)

        XCTAssertNotEqual(first.id, second.id)
    }

    // MARK: - Launch Returns Running Session

    func testLaunchReturnsRunningSession() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge()
        let configuration = makeConfiguration(jarURL: jarURL)

        let session = try bridge.launch(configuration)

        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.configuration, configuration)
        XCTAssertNil(session.endedAt)
        XCTAssertLessThanOrEqual(session.startedAt, Date())
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
