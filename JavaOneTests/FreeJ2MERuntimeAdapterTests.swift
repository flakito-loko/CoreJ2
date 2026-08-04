import XCTest
@testable import JavaOne

@MainActor
final class FreeJ2MERuntimeAdapterTests: XCTestCase {

    // MARK: - Skeleton / Host Wiring

    func testStartRunsContractCThroughRunJar() throws {
        let jarURL = try makeValidTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)

        try adapter.start(configuration: makeConfiguration(jarURL: jarURL))

        XCTAssertEqual(bootstrap.platformCalls.count, 1)
        XCTAssertEqual(bootstrap.platformCalls[0].0, 240)
        XCTAssertEqual(bootstrap.platformCalls[0].1, 320)
        XCTAssertEqual(bootstrap.painterCalls.count, 1)
        XCTAssertEqual(bootstrap.loadJarCalls.count, 1)
        XCTAssertEqual(bootstrap.runJarCalls.count, 1)
        XCTAssertTrue(bootstrap.loadJarCalls[0].hasPrefix("file://"))
        XCTAssertTrue(adapter.isMobilePlatformCreated)
        XCTAssertTrue(adapter.isPainterRegistered)
        XCTAssertTrue(adapter.isJarLoaded)
        XCTAssertTrue(adapter.isMidletRunning)
        XCTAssertEqual(adapter.paintEventCount, 2)
        XCTAssertEqual(adapter.frameCaptures.count, 2)
        XCTAssertEqual(adapter.frameCaptures[0].pixelCount, 240 * 320)
        XCTAssertNotEqual(adapter.frameCaptures[0].checksum, adapter.frameCaptures[1].checksum)
        XCTAssertEqual(adapter.lastJarLoadResult?.midletName, "Demo Game")
        XCTAssertEqual(adapter.lastJarRunResult?.reachedStartApp, true)
    }

    func testRegisterPainterRequiresPlatformFirst() {
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: RecordingMobilePlatformBootstrap())

        XCTAssertThrowsError(try adapter.registerPainter()) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isPainterRegistered)
    }

    func testLoadJarRequiresPlatformFirst() throws {
        let jarURL = try makeValidTemporaryJAR()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: RecordingMobilePlatformBootstrap())

        XCTAssertThrowsError(try adapter.loadJar(from: makeGame(jarURL: jarURL))) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isJarLoaded)
    }

    func testLoadJarRejectsMissingPathWithTypedFailure() throws {
        let missing = URL(fileURLWithPath: "/tmp/javaone-missing-\(UUID().uuidString).jar")
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        XCTAssertThrowsError(try adapter.loadJar(from: makeGame(jarURL: missing))) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .jarNotFound)
        }
        XCTAssertFalse(adapter.isJarLoaded)
        XCTAssertTrue(bootstrap.loadJarCalls.isEmpty)
    }

    func testLoadJarReturnsTypedResultForValidJAR() throws {
        let jarURL = try makeValidTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        let result = try adapter.loadJar(from: makeGame(jarURL: jarURL))

        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertTrue(result.jarURLString.hasPrefix("file://"))
        XCTAssertTrue(adapter.isJarLoaded)
        XCTAssertEqual(adapter.lastJarLoadResult, result)
        XCTAssertEqual(bootstrap.loadJarCalls.count, 1)
    }

    func testLoadJarMapsMalformedJARToTypedFailure() throws {
        let jarURL = try makeMalformedTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap(loadResult: .failure(.launchFailed))
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        XCTAssertThrowsError(try adapter.loadJar(from: makeGame(jarURL: jarURL))) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isJarLoaded)
        XCTAssertEqual(bootstrap.loadJarCalls.count, 1)
    }

    func testRunJarRequiresLoadJarFirst() throws {
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: RecordingMobilePlatformBootstrap())
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        XCTAssertThrowsError(try adapter.runJar()) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isMidletRunning)
    }

    func testRunJarReturnsTypedResult() throws {
        let jarURL = try makeValidTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        try adapter.loadJar(from: makeGame(jarURL: jarURL))

        let result = try adapter.runJar()

        XCTAssertTrue(result.reachedStartApp)
        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertTrue(adapter.isMidletRunning)
        XCTAssertEqual(adapter.lastJarRunResult, result)
        XCTAssertEqual(bootstrap.runJarCalls.count, 1)
    }

    func testRunJarMapsStartupFailureToTypedError() throws {
        let jarURL = try makeValidTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap(runResult: .failure(.launchFailed))
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        try adapter.loadJar(from: makeGame(jarURL: jarURL))

        XCTAssertThrowsError(try adapter.runJar()) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isMidletRunning)
    }

    func testLifecyclePlaceholdersSucceed() throws {
        let jarURL = try makeValidTemporaryJAR()
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)

        try adapter.initializeRuntime(configuration: makeConfiguration(jarURL: jarURL))
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        try adapter.registerPainter()
        try adapter.loadJar(from: makeGame(jarURL: jarURL))
        try adapter.runJar()
        try adapter.pause()
        try adapter.resume()

        XCTAssertTrue(adapter.isPainterRegistered)
        XCTAssertTrue(adapter.isJarLoaded)
        XCTAssertTrue(adapter.isMidletRunning)
        XCTAssertEqual(adapter.paintEventCount, 2)
        XCTAssertEqual(adapter.frameCaptures.count, 2)

        try adapter.stop()
        XCTAssertEqual(bootstrap.shutdownCallCount, 1)
        XCTAssertFalse(adapter.isMobilePlatformCreated)
        XCTAssertFalse(adapter.isPainterRegistered)
        XCTAssertFalse(adapter.isJarLoaded)
        XCTAssertFalse(adapter.isMidletRunning)
        XCTAssertEqual(adapter.paintEventCount, 0)
        XCTAssertTrue(adapter.frameCaptures.isEmpty)
    }

    func testRegisterPainterCapturesFramebufferMetadata() throws {
        let bootstrap = RecordingMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        var published: [EmulatorFrame] = []
        adapter.onFrameCaptured = { published.append($0) }

        let result = try adapter.registerPainter()

        XCTAssertEqual(result.paintEventCount, 2)
        XCTAssertEqual(result.frames.count, 2)
        XCTAssertEqual(result.frames[0].width, 240)
        XCTAssertEqual(result.frames[0].height, 320)
        XCTAssertEqual(result.frames[0].pixelCount, 76800)
        XCTAssertEqual(result.frames[0].pixels.count, 76800 * 4)
        XCTAssertEqual(result.frames[0].pixelFormat, "TYPE_INT_ARGB")
        XCTAssertNotEqual(result.frames[0].checksum, result.frames[1].checksum)
        XCTAssertEqual(adapter.frameCaptures, result.frames)
        XCTAssertEqual(adapter.lastFrameCapture, result.frames.last)
        XCTAssertEqual(published.count, 2)
        XCTAssertEqual(published[0].pixelCount, 76800)
        XCTAssertNotEqual(published[0].pixels, published[1].pixels)
    }

    func testFreeJ2MEFileURLStringUsesFileScheme() {
        let url = URL(fileURLWithPath: "/tmp/game.jar")
        let string = FreeJ2MERuntimeAdapter.freeJ2MEFileURLString(from: url)
        XCTAssertTrue(string.hasPrefix("file://"))
        XCTAssertTrue(string.contains("game.jar"))
    }

    // MARK: - Helpers

    private func makeConfiguration(jarURL: URL) -> LaunchConfiguration {
        LaunchConfiguration(game: makeGame(jarURL: jarURL))
    }

    private func makeGame(jarURL: URL) -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: "Test Game",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: "abc123"
        )
    }

    private func makeValidTemporaryJAR() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jarURL = directory.appendingPathComponent("demo.jar")
        let manifest = """
        Manifest-Version: 1.0
        MIDlet-1: Demo Game, , com.example.DemoMIDlet
        MIDlet-Name: Demo Game
        MIDlet-Vendor: JavaOne
        MIDlet-Version: 1.0
        MicroEdition-Configuration: CLDC-1.0
        MicroEdition-Profile: MIDP-2.0

        """
        try AdapterTestJARBuilder.makeJAR(manifestText: manifest).write(to: jarURL)
        return jarURL
    }

    private func makeMalformedTemporaryJAR() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jarURL = directory.appendingPathComponent("broken.jar")
        // ZIP without a usable MIDlet-1 manifest entry.
        try AdapterTestJARBuilder.makeJAR(manifestText: "Manifest-Version: 1.0\n").write(to: jarURL)
        return jarURL
    }
}

// MARK: - Recording Bootstrap

@MainActor
private final class RecordingMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {

    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?
    private(set) var shutdownCallCount = 0

    enum LoadOutcome {
        case success(FreeJ2MEJarLoadResult)
        case failure(EmulatorBridgeError)
    }

    enum RunOutcome {
        case success(FreeJ2MEJarRunResult)
        case failure(EmulatorBridgeError)
    }

    private(set) var platformCalls: [(Int, Int)] = []
    private(set) var painterCalls: [(Int, Int)] = []
    private(set) var loadJarCalls: [String] = []
    private(set) var runJarCalls: [String] = []

    private let loadOutcome: LoadOutcome
    private let runOutcome: RunOutcome

    init(
        loadResult: LoadOutcome = .success(
            FreeJ2MEJarLoadResult(midletName: "Demo Game", jarURLString: "file:///tmp/demo.jar")
        ),
        runResult: RunOutcome = .success(
            FreeJ2MEJarRunResult(
                midletName: "Demo Game",
                jarURLString: "file:///tmp/demo.jar",
                reachedStartApp: true
            )
        )
    ) {
        self.loadOutcome = loadResult
        self.runOutcome = runResult
    }

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        platformCalls.append((lcdWidth, lcdHeight))
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        painterCalls.append((lcdWidth, lcdHeight))
        let pixelCount = lcdWidth * lcdHeight
        return FreeJ2MEPainterRegistrationResult(
            paintEventCount: 2,
            frames: [
                FreeJ2MEFrameCapture(
                    paintIndex: 1,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: pixelCount,
                    checksum: 0x1111,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: TestFramePixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFFE11D48)
                ),
                FreeJ2MEFrameCapture(
                    paintIndex: 2,
                    width: lcdWidth,
                    height: lcdHeight,
                    pixelCount: pixelCount,
                    checksum: 0x2222,
                    pixelFormat: "TYPE_INT_ARGB",
                    pixels: TestFramePixels.solid(width: lcdWidth, height: lcdHeight, argb: 0xFF2563EB)
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
        loadJarCalls.append(jarFileURLString)
        switch loadOutcome {
        case .success(let template):
            return FreeJ2MEJarLoadResult(
                midletName: template.midletName,
                jarURLString: jarFileURLString
            )
        case .failure(let error):
            throw error
        }
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        _ = lcdWidth
        _ = lcdHeight
        runJarCalls.append(jarFileURLString)
        switch runOutcome {
        case .success(let template):
            return FreeJ2MEJarRunResult(
                midletName: template.midletName,
                jarURLString: jarFileURLString,
                reachedStartApp: template.reachedStartApp
            )
        case .failure(let error):
            throw error
        }
    }

    func shutdownRuntime() throws {
        shutdownCallCount += 1
    }
}

// MARK: - Test pixels

private enum TestFramePixels {
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

// MARK: - Minimal ZIP builder

private enum AdapterTestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeJAR(manifestText: String) throws -> Data {
        try makeStoredZIP(entries: [
            ("META-INF/MANIFEST.MF", Data(manifestText.utf8)),
            ("placeholder.txt", Data("ok".utf8))
        ])
    }

    private static func makeStoredZIP(entries: [(name: String, data: Data)]) throws -> Data {
        var localFiles = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            offsets.append(UInt32(localFiles.count))

            var localHeader = Data()
            localHeader.appendUInt32(localFileHeaderSignature)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(0)
            localHeader.appendUInt32(UInt32(entry.data.count))
            localHeader.appendUInt32(UInt32(entry.data.count))
            localHeader.appendUInt16(UInt16(nameData.count))
            localHeader.appendUInt16(0)
            localHeader.append(nameData)
            localHeader.append(entry.data)
            localFiles.append(localHeader)

            var centralHeader = Data()
            centralHeader.appendUInt32(centralDirectorySignature)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(0)
            centralHeader.appendUInt32(UInt32(entry.data.count))
            centralHeader.appendUInt32(UInt32(entry.data.count))
            centralHeader.appendUInt16(UInt16(nameData.count))
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(0)
            centralHeader.appendUInt32(offsets[offsets.count - 1])
            centralHeader.append(nameData)
            centralDirectory.append(centralHeader)
        }

        var endRecord = Data()
        endRecord.appendUInt32(endOfCentralDirectorySignature)
        endRecord.appendUInt16(0)
        endRecord.appendUInt16(0)
        endRecord.appendUInt16(UInt16(entries.count))
        endRecord.appendUInt16(UInt16(entries.count))
        endRecord.appendUInt32(UInt32(centralDirectory.count))
        endRecord.appendUInt32(UInt32(localFiles.count))
        endRecord.appendUInt16(0)

        var zip = Data()
        zip.append(localFiles)
        zip.append(centralDirectory)
        zip.append(endRecord)
        return zip
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: 2))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: 4))
    }
}
