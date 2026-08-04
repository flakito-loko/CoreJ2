import XCTest
@testable import JavaOne

@MainActor
final class FreeJ2MERuntimeHostTests: XCTestCase {

    // MARK: - Protocol Conformance

    func testConformsToRuntimeHostProtocol() {
        let host: any RuntimeHostProtocol = makeHost()
        XCTAssertTrue(host is FreeJ2MERuntimeHost)
    }

    // MARK: - Placeholder Startup

    func testLaunchSucceedsWithAdapterSkeleton() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = makeHost()
        try host.launch(makeConfiguration(jarURL: jarURL))
    }

    func testPauseResumeAndStopSucceedAsPlaceholders() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let host = makeHost()
        let configuration = makeConfiguration(jarURL: jarURL)
        try host.launch(configuration)
        let session = EmulatorSession(
            configuration: configuration,
            state: .running
        )

        try host.pause(session)
        try host.resume(session)
        try host.stop(session)
    }

    func testBridgeLaunchSucceedsWithFreeJ2MERuntimeHost() throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge(runtimeHost: makeHost())
        let session = try bridge.launch(makeConfiguration(jarURL: jarURL))

        XCTAssertEqual(session.state, .running)
        try bridge.pause(session)
        try bridge.resume(session)
        try bridge.stop(session)
        XCTAssertEqual(session.state, .stopped)
    }

    func testFrameAvailableEventsReachEmulatorViewModel() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }

        let bridge = DefaultEmulatorBridge(runtimeHost: makeHost())
        let viewModel = EmulatorViewModel(bridge: bridge)
        let game = InstalledGame(
            id: UUID(),
            title: "Frame Probe",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: "abc123"
        )

        await viewModel.startSession(for: game)

        let expectation = expectation(description: "frames from FreeJ2MERuntimeHost")
        Task { @MainActor in
            while viewModel.receivedFrameCount < 2 {
                await Task.yield()
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(viewModel.activeSession)
        XCTAssertTrue(viewModel.hasReceivedFrame)
        XCTAssertEqual(viewModel.surfaceMetadata?.width, 240)
        XCTAssertEqual(viewModel.lcdImage?.width, 240)
    }

    // MARK: - Helpers

    private func makeHost() -> FreeJ2MERuntimeHost {
        FreeJ2MERuntimeHost(
            adapter: FreeJ2MERuntimeAdapter(platformBootstrap: StubMobilePlatformBootstrap())
        )
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

@MainActor
private final class StubMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        _ = lcdWidth
        _ = lcdHeight
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        _ = lcdWidth
        _ = lcdHeight
        return FreeJ2MEPainterRegistrationResult(
            paintEventCount: 2,
            frames: [
                FreeJ2MEFrameCapture(
                    paintIndex: 1,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: lcdWidth * lcdHeight,
                    checksum: 1,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: HostTestPixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFFE11D48)
                ),
                FreeJ2MEFrameCapture(
                    paintIndex: 2,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: lcdWidth * lcdHeight,
                    checksum: 2,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: HostTestPixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFF2563EB)
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

private enum HostTestPixels {
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
