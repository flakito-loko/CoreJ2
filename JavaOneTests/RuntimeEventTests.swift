import XCTest
@testable import JavaOne

@MainActor
final class RuntimeEventTests: XCTestCase {

    // MARK: - Event Order

    func testFreeJ2MEHostEmitsLifecycleEventsInOrder() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = FreeJ2MERuntimeHost(
            adapter: FreeJ2MERuntimeAdapter(platformBootstrap: EventTestMobilePlatformBootstrap())
        )
        let configuration = makeConfiguration(jarURL: jarURL)
        let session = EmulatorSession(
            configuration: configuration,
            state: .running
        )

        let collector = Task {
            await collectEvents(from: host.events, untilCount: 6)
        }
        await Task.yield()

        try host.launch(configuration)
        try host.pause(session)
        try host.resume(session)
        try host.stop(session)

        let events = await collector.value
        let lifecycle = events.filter(\.isLifecycleEvent)
        XCTAssertEqual(lifecycle, [.started, .paused, .resumed, .stopped])
    }

    func testPlaceholderHostEmitsLifecycleEventsInOrder() async throws {
        let host = PlaceholderRuntimeHost()
        let session = EmulatorSession(
            configuration: makeConfiguration(),
            state: .running
        )

        let collector = Task {
            await collectEvents(from: host.events, untilCount: 4)
        }
        await Task.yield()

        try host.launch(makeConfiguration())
        try host.pause(session)
        try host.resume(session)
        try host.stop(session)

        let events = await collector.value
        XCTAssertEqual(events, [.started, .paused, .resumed, .stopped])
    }

    // MARK: - Frame Availability

    func testLaunchPublishesFrameAvailableEvents() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = FreeJ2MERuntimeHost(
            adapter: FreeJ2MERuntimeAdapter(platformBootstrap: EventTestMobilePlatformBootstrap())
        )
        let configuration = makeConfiguration(jarURL: jarURL)

        let collector = Task {
            await collectEvents(from: host.events, untilCount: 3)
        }
        await Task.yield()

        try host.launch(configuration)

        let events = await collector.value
        let frames = events.compactMap(\.emulatorFrame)
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].width, 240)
        XCTAssertEqual(frames[0].height, 320)
        XCTAssertEqual(frames[0].pixelCount, 240 * 320)
        XCTAssertEqual(frames[0].pixels.count, 240 * 320 * 4)
        XCTAssertEqual(frames[0].pixelFormat, .argb8888)
        XCTAssertEqual(frames[1].width, 240)
        XCTAssertEqual(frames[1].height, 320)
        XCTAssertEqual(frames[1].pixelCount, 76800)
        XCTAssertNotEqual(frames[0].pixels, frames[1].pixels)
        XCTAssertEqual(events.last, .started)
    }

    func testEmulatorBridgeForwardsFrameAvailableEvents() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = FreeJ2MERuntimeHost(
            adapter: FreeJ2MERuntimeAdapter(platformBootstrap: EventTestMobilePlatformBootstrap())
        )
        let bridge = DefaultEmulatorBridge(runtimeHost: host)

        let collector = Task {
            await collectEvents(from: bridge.runtimeEvents, untilCount: 3)
        }
        await Task.yield()

        _ = try bridge.launch(makeConfiguration(jarURL: jarURL))

        let events = await collector.value
        XCTAssertEqual(events.compactMap(\.emulatorFrame).count, 2)
        XCTAssertEqual(events.last, .started)
    }

    // MARK: - Bridge Observation

    func testEmulatorBridgeForwardsRuntimeEvents() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = FreeJ2MERuntimeHost(
            adapter: FreeJ2MERuntimeAdapter(platformBootstrap: EventTestMobilePlatformBootstrap())
        )
        let bridge = DefaultEmulatorBridge(runtimeHost: host)

        let collector = Task {
            await collectEvents(from: bridge.runtimeEvents, untilCount: 6)
        }
        await Task.yield()

        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))
        try bridge.pause(session)
        try bridge.resume(session)
        try bridge.stop(session)

        let events = await collector.value
        let lifecycle = events.filter(\.isLifecycleEvent)
        XCTAssertEqual(lifecycle, [.started, .paused, .resumed, .stopped])
        XCTAssertEqual(session.state, .stopped)
    }

    // MARK: - Helpers

    private func collectEvents(
        from stream: AsyncStream<RuntimeEvent>,
        untilCount count: Int
    ) async -> [RuntimeEvent] {
        var events: [RuntimeEvent] = []
        for await event in stream {
            events.append(event)
            if events.count == count {
                break
            }
        }
        return events
    }

    private func makeConfiguration(
        jarURL: URL = URL(fileURLWithPath: "/tmp/unused.jar")
    ) -> LaunchConfiguration {
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

private extension RuntimeEvent {
    var isLifecycleEvent: Bool {
        switch self {
        case .started, .paused, .resumed, .stopped, .failed:
            return true
        case .frameAvailable:
            return false
        }
    }

    var emulatorFrame: EmulatorFrame? {
        if case .frameAvailable(let frame) = self {
            return frame
        }
        return nil
    }
}

@MainActor
private final class EventTestMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        _ = lcdWidth
        _ = lcdHeight
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        FreeJ2MEPainterRegistrationResult(
            paintEventCount: 2,
            frames: [
                FreeJ2MEFrameCapture(
                    paintIndex: 1,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: lcdWidth * lcdHeight,
                    checksum: 1,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: EventTestPixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFFE11D48)
                ),
                FreeJ2MEFrameCapture(
                    paintIndex: 2,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: lcdWidth * lcdHeight,
                    checksum: 2,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: EventTestPixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFF2563EB)
                )
            ]
        )
    }

    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        _ = lcdWidth
        _ = lcdHeight
        return FreeJ2MEJarLoadResult(midletName: "Stub", jarURLString: jarFileURLString)
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        _ = lcdWidth
        _ = lcdHeight
        return FreeJ2MEJarRunResult(
            midletName: "Stub",
            jarURLString: jarFileURLString,
            reachedStartApp: true
        )
    }

    func shutdownRuntime() throws {}
}

private enum EventTestPixels {
    static func solid(width: Int, height: Int, argb: UInt32) -> Data {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { raw in
            let buffer = raw.bindMemory(to: UInt32.self)
            for index in 0..<(width * height) {
                buffer[index] = argb.littleEndian
            }
        }
        return data
    }
}
