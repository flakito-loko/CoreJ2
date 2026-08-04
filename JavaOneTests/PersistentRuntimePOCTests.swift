import XCTest
@testable import JavaOne

@MainActor
final class PersistentRuntimePOCTests: XCTestCase {

    func testPersistentDaemonKeepsSingleJVMAndPlatformAlive() throws {
        try skipUnlessHostJavaIsAvailable()

        #if os(macOS)
        let client = PersistentRuntimePOCClient()
        let jarURL = try makeExecutableProbeJAR()
        defer {
            try? client.shutdown()
            try? FileManager.default.removeItem(at: jarURL.deletingLastPathComponent())
        }

        try client.start()
        XCTAssertEqual(client.metrics.jvmLaunchCount, 1)
        XCTAssertGreaterThan(client.metrics.jvmStartupNanoseconds, 0)

        let create = try client.create()
        let identity = client.metrics.platformIdentity
        XCTAssertNotNil(identity)
        XCTAssertTrue(create.contains("id=\(identity!)"))

        try client.registerPainter()
        XCTAssertGreaterThanOrEqual(client.metrics.frameCount, 2)

        // Failure recovery: bad command must not kill the JVM.
        try client.probeFailureRecovery()
        XCTAssertTrue(client.metrics.failureRecoverySucceeded)

        let pingBefore = try client.ping()
        XCTAssertTrue(pingBefore.contains("id=\(identity!)"))
        XCTAssertTrue(pingBefore.contains("painter=true"))

        let fileURL = jarURL.standardizedFileURL.absoluteString
        try client.load(jarFileURLString: fileURL)
        try client.runJar()

        let framesBeforeProbe = client.metrics.frameCount
        let probe = try client.frameProbe()
        XCTAssertTrue(probe.contains("id=\(identity!)"))
        XCTAssertTrue(probe.contains("midletRunning=true"))
        XCTAssertGreaterThan(client.metrics.frameCount, framesBeforeProbe)

        client.sampleMemory()
        XCTAssertGreaterThan(client.metrics.approximateMemoryBytes, 0)

        try client.stop()
        let pingAfterStop = try client.ping()
        XCTAssertTrue(pingAfterStop.contains("id=\(identity!)"))
        XCTAssertTrue(pingAfterStop.contains("running=false"))

        // Still a single JVM launch for the whole session.
        XCTAssertEqual(client.metrics.jvmLaunchCount, 1)

        try client.shutdown()
        XCTAssertTrue(client.metrics.cleanShutdown)

        // Latencies recorded for primary commands.
        XCTAssertNotNil(client.metrics.commandLatenciesNanoseconds["CREATE"])
        XCTAssertNotNil(client.metrics.commandLatenciesNanoseconds["LOAD"])
        XCTAssertNotNil(client.metrics.commandLatenciesNanoseconds["RUN"])
        XCTAssertNotNil(client.metrics.commandLatenciesNanoseconds["FRAME_PROBE"])
        #else
        throw XCTSkip("Persistent runtime POC requires macOS Process + host JVM")
        #endif
    }

    // MARK: - Helpers

    private func skipUnlessHostJavaIsAvailable() throws {
        #if os(iOS)
        throw XCTSkip("Persistent runtime POC is macOS-only")
        #else
        guard let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"],
              !javaHome.isEmpty else {
            throw XCTSkip("JAVA_HOME is required for the persistent runtime POC")
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

        // Warm production bootstrap compile cache so FreeJ2ME classes exist.
        let bootstrap = ProcessFreeJ2MEMobilePlatformBootstrap()
        do {
            try bootstrap.bootstrapMobilePlatform(lcdWidth: 240, lcdHeight: 320)
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
        try POCTestJARBuilder.makeJAR(
            manifestText: manifest,
            extraEntries: [(classRelative, classData)]
        ).write(to: jarURL)
        return jarURL
        #endif
    }
}

// MARK: - Minimal ZIP builder

private enum POCTestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeJAR(
        manifestText: String,
        extraEntries: [(String, Data)] = []
    ) throws -> Data {
        var entries: [(String, Data)] = [
            ("META-INF/MANIFEST.MF", Data(manifestText.utf8))
        ]
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
        (0..<256).map { index -> UInt32 in
            var c = UInt32(index)
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
