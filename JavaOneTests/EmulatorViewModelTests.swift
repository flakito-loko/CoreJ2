import CoreGraphics
import XCTest
@testable import JavaOne

@MainActor
final class EmulatorViewModelTests: XCTestCase {

    // MARK: - Frame Reception

    func testHandleFrameAvailableUpdatesSurfaceMetadataAndImage() {
        let viewModel = EmulatorViewModel(bridge: FakeEmulatorBridge())
        let frame = makeFrame(width: 240, height: 320, argb: 0xFFE11D48)

        viewModel.handleRuntimeEvent(.frameAvailable(frame))

        XCTAssertTrue(viewModel.hasReceivedFrame)
        XCTAssertEqual(viewModel.receivedFrameCount, 1)
        XCTAssertEqual(viewModel.surfaceMetadata?.width, 240)
        XCTAssertEqual(viewModel.surfaceMetadata?.height, 320)
        XCTAssertEqual(viewModel.lcdImage?.width, 240)
    }

    func testMultipleFramesUpdateImageDimensions() {
        let viewModel = EmulatorViewModel(bridge: FakeEmulatorBridge())

        viewModel.handleRuntimeEvent(.frameAvailable(makeFrame(width: 240, height: 320, argb: 1)))
        viewModel.handleRuntimeEvent(.frameAvailable(makeFrame(width: 176, height: 220, argb: 2)))

        XCTAssertEqual(viewModel.receivedFrameCount, 2)
        XCTAssertEqual(viewModel.lcdImage?.width, 176)
        XCTAssertEqual(viewModel.lcdImage?.height, 220)
    }

    func testNonFrameEventsDoNotMutateSurface() {
        let viewModel = EmulatorViewModel(bridge: FakeEmulatorBridge())

        viewModel.handleRuntimeEvent(.started)
        viewModel.handleRuntimeEvent(.stopped)

        XCTAssertFalse(viewModel.hasReceivedFrame)
        XCTAssertNil(viewModel.lcdImage)
    }

    // MARK: - Launch Flow

    func testStartSessionCreatesConfigurationAndSession() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }
        let game = makeGame(jarURL: jarURL)
        let bridge = FakeEmulatorBridge(emitsFramesOnLaunch: false)
        let viewModel = EmulatorViewModel(bridge: bridge)

        await viewModel.startSession(for: game)

        XCTAssertEqual(viewModel.lastLaunchConfiguration?.game, game)
        XCTAssertEqual(viewModel.activeSession?.configuration.game.id, game.id)
        XCTAssertEqual(viewModel.activeSession?.state, .running)
        XCTAssertNil(viewModel.launchErrorMessage)
        XCTAssertEqual(bridge.launchCount, 1)
    }

    func testStartSessionReceivesFramesPublishedDuringLaunch() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }
        let game = makeGame(jarURL: jarURL)
        let bridge = FakeEmulatorBridge(emitsFramesOnLaunch: true)
        let viewModel = EmulatorViewModel(bridge: bridge)

        await viewModel.startSession(for: game)

        let expectation = expectation(description: "frames rendered")
        Task { @MainActor in
            while viewModel.receivedFrameCount < 2 {
                await Task.yield()
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertTrue(viewModel.hasReceivedFrame)
        XCTAssertEqual(viewModel.receivedFrameCount, 2)
        XCTAssertEqual(viewModel.surfaceMetadata?.width, 240)
        XCTAssertEqual(viewModel.surfaceMetadata?.height, 320)
        XCTAssertEqual(viewModel.lcdImage?.width, 240)
    }

    func testEndSessionStopsBridgeAndClearsSurface() async throws {
        let jarURL = try makeTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL) }
        let viewModel = EmulatorViewModel(bridge: FakeEmulatorBridge(emitsFramesOnLaunch: true))
        await viewModel.startSession(for: makeGame(jarURL: jarURL))

        let expectation = expectation(description: "frame")
        Task { @MainActor in
            while !viewModel.hasReceivedFrame { await Task.yield() }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 2.0)

        viewModel.endSession()

        XCTAssertNil(viewModel.activeSession)
        XCTAssertNil(viewModel.lcdImage)
        XCTAssertFalse(viewModel.hasReceivedFrame)
        XCTAssertEqual(viewModel.receivedFrameCount, 0)
    }

    // MARK: - CGImage Converter

    func testConverterRejectsMismatchedPixelByteCount() {
        let image = EmulatorFrameCGImageConverter.makeCGImage(
            width: 10,
            height: 10,
            pixelFormat: .argb8888,
            pixels: Data(count: 16)
        )
        XCTAssertNil(image)
    }

    // MARK: - Helpers

    private func makeGame(jarURL: URL) -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: "Test Game",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: "abc123"
        )
    }

    private func makeTemporaryJAR() throws -> URL {
        let jarURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jar")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: jarURL)
        return jarURL
    }

    private func makeFrame(width: Int, height: Int, argb: UInt32) -> EmulatorFrame {
        let pixels = solidPixels(width: width, height: height, argb: argb)
        return try! XCTUnwrap(
            EmulatorFrame(width: width, height: height, pixelFormat: .argb8888, pixels: pixels)
        )
    }

    private func solidPixels(width: Int, height: Int, argb: UInt32) -> Data {
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

final class EmulatorFrameCGImageConverterTests: XCTestCase {

    func testConvertsARGB8888BufferToMatchingCGImage() throws {
        let width = 8
        let height = 4
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { raw in
            let buffer = raw.bindMemory(to: UInt32.self)
            for index in 0..<(width * height) {
                buffer[index] = UInt32(0xFF112233).littleEndian
            }
        }
        let frame = try XCTUnwrap(
            EmulatorFrame(width: width, height: height, pixelFormat: .argb8888, pixels: pixels)
        )
        let image = try XCTUnwrap(EmulatorFrameCGImageConverter.makeCGImage(from: frame))
        XCTAssertEqual(image.width, width)
        XCTAssertEqual(image.height, height)
    }

    func testRejectsMismatchedPixelByteCount() {
        XCTAssertNil(
            EmulatorFrameCGImageConverter.makeCGImage(
                width: 10,
                height: 10,
                pixelFormat: .argb8888,
                pixels: Data(count: 16)
            )
        )
    }

    func testRejectsZeroDimensions() {
        XCTAssertNil(
            EmulatorFrameCGImageConverter.makeCGImage(
                width: 0,
                height: 10,
                pixelFormat: .argb8888,
                pixels: Data()
            )
        )
    }
}

// MARK: - Fake Bridge

@MainActor
private final class FakeEmulatorBridge: EmulatorBridgeProtocol {

    private let pipe = RuntimeEventPipe()
    private let emitsFramesOnLaunch: Bool
    private(set) var launchCount = 0
    private(set) var stopCount = 0

    init(emitsFramesOnLaunch: Bool = false) {
        self.emitsFramesOnLaunch = emitsFramesOnLaunch
    }

    var runtimeEvents: AsyncStream<RuntimeEvent> {
        pipe.events
    }

    func publish(_ event: RuntimeEvent) {
        pipe.yield(event)
    }

    func launch(_ configuration: LaunchConfiguration) throws -> EmulatorSession {
        launchCount += 1
        if emitsFramesOnLaunch {
            pipe.yield(.frameAvailable(Self.makeFrame(width: 240, height: 320, argb: 0xFFE11D48)))
            pipe.yield(.frameAvailable(Self.makeFrame(width: 240, height: 320, argb: 0xFF2563EB)))
        }
        pipe.yield(.started)
        return EmulatorSession(configuration: configuration, state: .running)
    }

    func pause(_ session: EmulatorSession) throws {
        session.transition(to: .paused)
    }

    func resume(_ session: EmulatorSession) throws {
        session.transition(to: .running)
    }

    func stop(_ session: EmulatorSession) throws {
        stopCount += 1
        session.transition(to: .stopped)
        pipe.yield(.stopped)
    }

    private static func makeFrame(width: Int, height: Int, argb: UInt32) -> EmulatorFrame {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { raw in
            let buffer = raw.bindMemory(to: UInt32.self)
            for index in 0..<(width * height) {
                buffer[index] = argb.littleEndian
            }
        }
        return EmulatorFrame(width: width, height: height, pixelFormat: .argb8888, pixels: data)!
    }
}
