import XCTest
@testable import JavaOne

@MainActor
final class PersistentProcessFreeJ2MEMobilePlatformBootstrapTests: XCTestCase {

    func testPersistentBootstrapSingleJVMSessionWithPostRunFramesAndCleanShutdown() throws {
        try skipUnlessHostJavaIsAvailable()

        #if os(macOS)
        let bootstrap = PersistentProcessFreeJ2MEMobilePlatformBootstrap()
        var streamedFrames = 0
        bootstrap.frameHandler = { _ in
            streamedFrames += 1
        }

        let jarURL = try makeExecutableProbeJAR()
        defer {
            try? bootstrap.shutdownRuntime()
            try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent())
        }

        let fileURL = jarURL.standardizedFileURL.absoluteString

        do {
            try bootstrap.bootstrapMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            let painter = try bootstrap.registerPainter(lcdWidth: 240, lcdHeight: 320)
            XCTAssertGreaterThanOrEqual(painter.frames.count, 2)

            _ = try bootstrap.loadJar(
                lcdWidth: 240,
                lcdHeight: 320,
                jarFileURLString: fileURL
            )
            let run = try bootstrap.runJar(
                lcdWidth: 240,
                lcdHeight: 320,
                jarFileURLString: fileURL
            )
            XCTAssertTrue(run.reachedStartApp)

            XCTAssertEqual(bootstrap.metrics.jvmLaunchCount, 1)
            XCTAssertNotNil(bootstrap.metrics.platformIdentity)
            XCTAssertGreaterThan(bootstrap.metrics.jvmStartupNanoseconds, 0)
            XCTAssertGreaterThan(bootstrap.metrics.launchLatencyNanoseconds, 0)
            XCTAssertGreaterThanOrEqual(bootstrap.metrics.frameCount, 3)
            XCTAssertGreaterThan(bootstrap.metrics.approximateMemoryBytes, 0)
            XCTAssertGreaterThanOrEqual(streamedFrames, 1)

            try bootstrap.shutdownRuntime()
            XCTAssertTrue(bootstrap.metrics.cleanShutdown)
            XCTAssertEqual(bootstrap.metrics.jvmLaunchCount, 1)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip("Persistent FreeJ2ME bootstrap requires a host JVM")
        }
        #else
        throw XCTSkip("Persistent bootstrap is macOS-only")
        #endif
    }

    func testAdapterDefaultUsesPersistentBootstrapAndStopShutsDown() throws {
        try skipUnlessHostJavaIsAvailable()

        #if os(macOS)
        let bootstrap = PersistentProcessFreeJ2MEMobilePlatformBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        var frames = 0
        adapter.onFrameCaptured = { _ in frames += 1 }

        let jarURL = try makeExecutableProbeJAR()
        defer {
            try? adapter.stop()
            try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent())
        }

        let game = InstalledGame(
            id: UUID(),
            title: "Probe",
            jarURL: jarURL,
            importedAt: Date(),
            contentHash: "abc123"
        )

        do {
            try adapter.start(configuration: LaunchConfiguration(game: game))
            XCTAssertTrue(adapter.isMidletRunning)
            XCTAssertGreaterThanOrEqual(frames, 3)
            XCTAssertEqual(bootstrap.metrics.jvmLaunchCount, 1)

            try adapter.stop()
            XCTAssertFalse(adapter.isMidletRunning)
            XCTAssertTrue(bootstrap.metrics.cleanShutdown)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip("Persistent FreeJ2ME bootstrap requires a host JVM")
        }
        #else
        throw XCTSkip("Persistent bootstrap is macOS-only")
        #endif
    }

    func testAdapterStopInvokesBootstrapShutdown() throws {
        let bootstrap = RecordingShutdownBootstrap()
        let adapter = FreeJ2MERuntimeAdapter(platformBootstrap: bootstrap)
        try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        try adapter.stop()
        XCTAssertEqual(bootstrap.shutdownCallCount, 1)
        XCTAssertFalse(adapter.isMobilePlatformCreated)
    }

    // MARK: - Helpers

    private func skipUnlessHostJavaIsAvailable() throws {
        #if os(iOS)
        throw XCTSkip("Persistent JVM bootstrap is macOS-only")
        #else
        guard let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"],
              !javaHome.isEmpty else {
            throw XCTSkip("JAVA_HOME is required")
        }
        let javaURL = URL(fileURLWithPath: javaHome).appendingPathComponent("bin/java")
        guard FileManager.default.isExecutableFile(atPath: javaURL.path) else {
            throw XCTSkip("JAVA_HOME does not contain a usable bin/java")
        }
        #endif
    }

    private func makeExecutableProbeJAR() throws -> URL {
        #if os(iOS)
        throw XCTSkip("Executable MIDlet fixtures require host javac")
        #else
        guard let javaHomePath = ProcessInfo.processInfo.environment["JAVA_HOME"] else {
            throw XCTSkip("JAVA_HOME required")
        }
        let javaHome = URL(fileURLWithPath: javaHomePath, isDirectory: true)

        // Warm ephemeral compile cache for FreeJ2ME classes used by fixture javac.
        let ephemeral = ProcessFreeJ2MEMobilePlatformBootstrap()
        do {
            try ephemeral.bootstrapMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip("Host JVM FreeJ2ME bootstrap unavailable")
        }

        let freej2meClasses = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOneFreeJ2MEBootstrap/classes", isDirectory: true)
        let fixturesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "JavaOne/Features/Emulator/Runtime/Bootstrap/fixtures",
                isDirectory: true
            )
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fixtureClasses = work.appendingPathComponent("classes", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureClasses, withIntermediateDirectories: true)

        let source = fixturesRoot.appendingPathComponent("ProbeMIDlet.java")
        let javac = Process()
        javac.executableURL = javaHome.appendingPathComponent("bin/javac")
        javac.arguments = [
            "-encoding", "UTF-8",
            "-cp", freej2meClasses.path(percentEncoded: false),
            "-d", fixtureClasses.path(percentEncoded: false),
            source.path(percentEncoded: false)
        ]
        javac.standardOutput = Pipe()
        javac.standardError = Pipe()
        try javac.run()
        javac.waitUntilExit()
        guard javac.terminationStatus == 0 else {
            throw EmulatorBridgeError.launchFailed
        }

        let classRelative = "org/javaone/freej2me/fixtures/ProbeMIDlet.class"
        let classData = try Data(contentsOf: fixtureClasses.appendingPathComponent(classRelative))
        let manifest = """
        Manifest-Version: 1.0
        MIDlet-1: Probe MIDlet, , org.javaone.freej2me.fixtures.ProbeMIDlet
        MIDlet-Name: Probe MIDlet
        MIDlet-Vendor: JavaOne
        MIDlet-Version: 1.0
        MicroEdition-Configuration: CLDC-1.0
        MicroEdition-Profile: MIDP-2.0

        """
        let jarURL = work.appendingPathComponent("probe.jar")
        try PersistentBootstrapTestJARBuilder.makeJAR(
            manifestText: manifest,
            extraEntries: [(classRelative, classData)]
        ).write(to: jarURL)
        return jarURL
        #endif
    }
}

@MainActor
private final class RecordingShutdownBootstrap: FreeJ2MEMobilePlatformBootstrapping {
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?
    private(set) var shutdownCallCount = 0

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        _ = lcdWidth
        _ = lcdHeight
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        FreeJ2MEPainterRegistrationResult(paintEventCount: 0, frames: [])
    }

    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        FreeJ2MEJarLoadResult(midletName: "x", jarURLString: jarFileURLString)
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        FreeJ2MEJarRunResult(midletName: "x", jarURLString: jarFileURLString, reachedStartApp: true)
    }

    func shutdownRuntime() throws {
        shutdownCallCount += 1
    }
}

private enum PersistentBootstrapTestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeJAR(
        manifestText: String,
        extraEntries: [(String, Data)] = []
    ) throws -> Data {
        var entries: [(String, Data)] = [("META-INF/MANIFEST.MF", Data(manifestText.utf8))]
        entries.append(contentsOf: extraEntries)
        var local = Data()
        var central = Data()
        var offset: UInt32 = 0
        for (name, payload) in entries {
            let nameData = Data(name.utf8)
            let localHeaderOffset = offset
            var localHeader = Data()
            localHeader.appendUInt32(localFileHeaderSignature)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(crc32(payload))
            localHeader.appendUInt32(UInt32(payload.count))
            localHeader.appendUInt32(UInt32(payload.count))
            localHeader.appendUInt16(UInt16(nameData.count))
            localHeader.appendUInt16(0)
            localHeader.append(nameData)
            localHeader.append(payload)
            local.append(localHeader)
            offset += UInt32(localHeader.count)

            var centralHeader = Data()
            centralHeader.appendUInt32(centralDirectorySignature)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(20)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(crc32(payload))
            centralHeader.appendUInt32(UInt32(payload.count))
            centralHeader.appendUInt32(UInt32(payload.count))
            centralHeader.appendUInt16(UInt16(nameData.count))
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt16(0)
            centralHeader.appendUInt32(0)
            centralHeader.appendUInt32(localHeaderOffset)
            centralHeader.append(nameData)
            central.append(centralHeader)
        }
        var end = Data()
        end.appendUInt32(endOfCentralDirectorySignature)
        end.appendUInt16(0)
        end.appendUInt16(0)
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt32(UInt32(central.count))
        end.appendUInt32(UInt32(local.count))
        end.appendUInt16(0)
        return local + central + end
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xffffffff
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xedb88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
