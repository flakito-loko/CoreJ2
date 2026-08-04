import XCTest
@testable import JavaOne

@MainActor
final class FreeJ2MEMobilePlatformBootstrapTests: XCTestCase {

    // MARK: - Real FreeJ2ME Execution

    func testCreateMobilePlatformConstructsFreeJ2MEMobilePlatform() throws {
        try skipUnlessHostJavaIsAvailable()

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertTrue(adapter.isMobilePlatformCreated)
        XCTAssertEqual(adapter.mobilePlatformLCDWidth, 240)
        XCTAssertEqual(adapter.mobilePlatformLCDHeight, 320)
    }

    func testBootstrapDoesNotInvokeLoadOrRunJar() throws {
        try skipUnlessHostJavaIsAvailable()

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 176, lcdHeight: 220)
            try adapter.registerPainter()
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertTrue(adapter.isMobilePlatformCreated)
        XCTAssertTrue(adapter.isPainterRegistered)
        XCTAssertFalse(adapter.isJarLoaded)
        XCTAssertEqual(adapter.paintEventCount, 2)
        XCTAssertEqual(adapter.frameCaptures.count, 2)
        XCTAssertEqual(adapter.frameCaptures[0].width, 176)
        XCTAssertEqual(adapter.frameCaptures[0].height, 220)
        XCTAssertEqual(adapter.frameCaptures[0].pixelCount, 176 * 220)
        XCTAssertNotEqual(adapter.frameCaptures[0].checksum, adapter.frameCaptures[1].checksum)
        XCTAssertEqual(adapter.mobilePlatformLCDWidth, 176)
        XCTAssertEqual(adapter.mobilePlatformLCDHeight, 220)
    }

    func testRegisterPainterUsesOfficialSetPainterHook() throws {
        try skipUnlessHostJavaIsAvailable()

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            try adapter.registerPainter()
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertTrue(adapter.isPainterRegistered)
        XCTAssertEqual(adapter.paintEventCount, 2)
        XCTAssertEqual(adapter.lastFrameCapture?.pixelFormat, "TYPE_INT_ARGB")
        XCTAssertEqual(adapter.lastFrameCapture?.pixelCount, 240 * 320)
    }

    func testRegisterPainterCapturesChangingFramebuffers() throws {
        try skipUnlessHostJavaIsAvailable()

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        let result: FreeJ2MEPainterRegistrationResult
        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            result = try adapter.registerPainter()
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertEqual(result.frames.count, 2)
        XCTAssertEqual(result.frames[0].width, 240)
        XCTAssertEqual(result.frames[0].height, 320)
        XCTAssertEqual(result.frames[0].pixelCount, 76800)
        XCTAssertEqual(result.frames[1].pixelCount, 76800)
        XCTAssertEqual(result.frames[0].pixelFormat, "TYPE_INT_ARGB")
        XCTAssertNotEqual(result.frames[0].checksum, result.frames[1].checksum)
        XCTAssertEqual(adapter.frameCaptures.count, 2)
    }

    func testLoadJarSucceedsForValidJAR() throws {
        try skipUnlessHostJavaIsAvailable()

        let jarURL = try makeValidTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        let result: FreeJ2MEJarLoadResult
        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            result = try adapter.loadJar(from: makeGame(jarURL: jarURL))
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertTrue(result.jarURLString.hasPrefix("file://"))
        XCTAssertTrue(adapter.isJarLoaded)
        XCTAssertEqual(adapter.lastJarLoadResult, result)
    }

    func testLoadJarFailsForInvalidPath() throws {
        try skipUnlessHostJavaIsAvailable()

        let missing = URL(fileURLWithPath: "/tmp/javaone-missing-\(UUID().uuidString).jar")
        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertThrowsError(try adapter.loadJar(from: makeGame(jarURL: missing))) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .jarNotFound)
        }
        XCTAssertFalse(adapter.isJarLoaded)
    }

    func testLoadJarFailsForMalformedJAR() throws {
        try skipUnlessHostJavaIsAvailable()

        let jarURL = try makeMalformedTemporaryJAR()
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertThrowsError(try adapter.loadJar(from: makeGame(jarURL: jarURL))) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isJarLoaded)
    }

    func testRunJarReachesStartAppForProbeMIDlet() throws {
        try skipUnlessHostJavaIsAvailable()

        let jarURL = try makeExecutableProbeJAR(failing: false)
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        let result: FreeJ2MEJarRunResult
        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            try adapter.loadJar(from: makeGame(jarURL: jarURL))
            result = try adapter.runJar()
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertTrue(result.reachedStartApp)
        XCTAssertEqual(result.midletName, "Probe MIDlet")
        XCTAssertTrue(adapter.isMidletRunning)
    }

    func testRunJarMapsStartupFailureToTypedError() throws {
        try skipUnlessHostJavaIsAvailable()

        let jarURL = try makeExecutableProbeJAR(failing: true)
        defer { try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent()) }

        let adapter = FreeJ2MERuntimeAdapter(
            platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
        )

        do {
            try adapter.createMobilePlatform(lcdWidth: 240, lcdHeight: 320)
            try adapter.loadJar(from: makeGame(jarURL: jarURL))
        } catch EmulatorBridgeError.runtimeUnavailable {
            throw XCTSkip(
                "In-process FreeJ2ME bootstrap requires a host JVM (macOS Process). " +
                "Verified via MobilePlatformBootstrap on the host JDK; iOS has no JVM yet."
            )
        }

        XCTAssertThrowsError(try adapter.runJar()) { error in
            XCTAssertEqual(error as? EmulatorBridgeError, .launchFailed)
        }
        XCTAssertFalse(adapter.isMidletRunning)
    }

    // MARK: - Helpers

    private func skipUnlessHostJavaIsAvailable() throws {
        #if os(iOS)
        throw XCTSkip("Host JVM MobilePlatform bootstrap is macOS-only until an iOS Java runtime exists")
        #else
        guard let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"],
              !javaHome.isEmpty else {
            throw XCTSkip("JAVA_HOME is required to execute FreeJ2ME MobilePlatform bootstrap")
        }
        let javaURL = URL(fileURLWithPath: javaHome).appendingPathComponent("bin/java")
        guard FileManager.default.isExecutableFile(atPath: javaURL.path) else {
            throw XCTSkip("JAVA_HOME does not contain a usable bin/java")
        }
        #endif
    }

    private func makeGame(jarURL: URL) -> InstalledGame {
        InstalledGame(
            id: UUID(),
            title: "Demo Game",
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
        try BootstrapTestJARBuilder.makeJAR(manifestText: manifest).write(to: jarURL)
        return jarURL
    }

    private func makeMalformedTemporaryJAR() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jarURL = directory.appendingPathComponent("broken.jar")
        try BootstrapTestJARBuilder.makeJAR(manifestText: "Manifest-Version: 1.0\n").write(to: jarURL)
        return jarURL
    }

    /// Compiles JavaOne probe fixtures against FreeJ2ME and packages an executable JAR.
    private func makeExecutableProbeJAR(failing: Bool) throws -> URL {
        #if os(iOS)
        throw XCTSkip("Executable MIDlet fixtures require host javac")
        #else
        guard let javaHomePath = ProcessInfo.processInfo.environment["JAVA_HOME"] else {
            throw XCTSkip("JAVA_HOME required")
        }
        let javaHome = URL(fileURLWithPath: javaHomePath, isDirectory: true)
        let vendorRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Vendor/FreeJ2ME", isDirectory: true)
        let fixturesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "JavaOne/Features/Emulator/Runtime/Bootstrap/fixtures",
                isDirectory: true
            )

        // Ensure FreeJ2ME classes exist via a no-op platform bootstrap compile.
        let bootstrap = ProcessFreeJ2MEMobilePlatformBootstrap()
        try bootstrap.bootstrapMobilePlatform(lcdWidth: 240, lcdHeight: 320)

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOneFreeJ2MEBootstrap", isDirectory: true)
        let freej2meClasses = cacheRoot.appendingPathComponent("classes", isDirectory: true)
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fixtureClasses = work.appendingPathComponent("classes", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureClasses, withIntermediateDirectories: true)

        let sourceName = failing ? "FailingMIDlet.java" : "ProbeMIDlet.java"
        let classSimpleName = failing ? "FailingMIDlet" : "ProbeMIDlet"
        let midletName = failing ? "Failing MIDlet" : "Probe MIDlet"
        let source = fixturesRoot.appendingPathComponent(sourceName)

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

        let classRelative = "org/javaone/freej2me/fixtures/\(classSimpleName).class"
        let classFile = fixtureClasses.appendingPathComponent(classRelative)
        let classData = try Data(contentsOf: classFile)

        let manifest = """
        Manifest-Version: 1.0
        MIDlet-1: \(midletName), , org.javaone.freej2me.fixtures.\(classSimpleName)
        MIDlet-Name: \(midletName)
        MIDlet-Vendor: JavaOne
        MIDlet-Version: 1.0
        MicroEdition-Configuration: CLDC-1.0
        MicroEdition-Profile: MIDP-2.0

        """
        let jarURL = work.appendingPathComponent(failing ? "failing.jar" : "probe.jar")
        try BootstrapTestJARBuilder.makeJAR(
            manifestText: manifest,
            extraEntries: [(classRelative, classData)]
        ).write(to: jarURL)

        _ = vendorRoot
        return jarURL
        #endif
    }
}

// MARK: - Minimal ZIP builder

private enum BootstrapTestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeJAR(
        manifestText: String,
        extraEntries: [(name: String, data: Data)] = []
    ) throws -> Data {
        var entries: [(name: String, data: Data)] = [
            ("META-INF/MANIFEST.MF", Data(manifestText.utf8))
        ]
        entries.append(contentsOf: extraEntries)
        if extraEntries.isEmpty {
            entries.append(("placeholder.txt", Data("ok".utf8)))
        }
        return try makeStoredZIP(entries: entries)
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
