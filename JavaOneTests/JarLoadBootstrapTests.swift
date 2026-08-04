import XCTest
@testable import JavaOne

/// E3-US005 — `MobilePlatform.loadJar` via PlatformBootstrap (no `runJar`).
final class JarLoadBootstrapTests: XCTestCase {

    // MARK: - Successful load

    func testSuccessfulLoadJarVerifiesManifestName() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let jarURL = try makeValidTemporaryJAR()
        let expectedURLString = jarURL.standardizedFileURL.absoluteString
        installLoadJarMock(on: fixture.native, loadResult: .boolean(true), midletName: .string("Demo Game"))

        let result = try await fixture.bootstrap.loadJar(url: jarURL)

        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertEqual(result.jarURLString, expectedURLString)
        XCTAssertEqual(fixture.bootstrap.lastJarLoadResult, result)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
        XCTAssertGreaterThanOrEqual(fixture.native.genericInvokeCount, 2)
    }

    // MARK: - Missing / malformed

    func testMissingJarMapsToJarNotFound() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.jar")
        let invokeBefore = fixture.native.genericInvokeCount

        do {
            _ = try await fixture.bootstrap.loadJar(url: missing)
            XCTFail("expected jarNotFound")
        } catch let error as PlatformBootstrapError {
            guard case .jarNotFound = error else {
                return XCTFail("expected jarNotFound, got \(error)")
            }
        }

        XCTAssertEqual(fixture.native.genericInvokeCount, invokeBefore)
        XCTAssertNil(fixture.bootstrap.lastJarLoadResult)
    }

    func testMalformedJarMapsToMalformedJar() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeMalformedTemporaryJAR()
        installLoadJarMock(on: fixture.native, loadResult: .boolean(true), midletName: .null)

        do {
            _ = try await fixture.bootstrap.loadJar(url: jarURL)
            XCTFail("expected malformedJar")
        } catch let error as PlatformBootstrapError {
            guard case .malformedJar = error else {
                return XCTFail("expected malformedJar, got \(error)")
            }
        }

        XCTAssertNil(fixture.bootstrap.lastJarLoadResult)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
    }

    func testLoadJarFalseMapsToLoadJarFailed() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native, loadResult: .boolean(false), midletName: .string("ignored"))

        do {
            _ = try await fixture.bootstrap.loadJar(url: jarURL)
            XCTFail("expected loadJarFailed")
        } catch let error as PlatformBootstrapError {
            guard case .loadJarFailed = error else {
                return XCTFail("expected loadJarFailed, got \(error)")
            }
        }

        XCTAssertNil(fixture.bootstrap.lastJarLoadResult)
    }

    // MARK: - Repeated load / shutdown

    func testRepeatedLoadAttemptsSucceed() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let first = try makeValidTemporaryJAR()
        let second = try makeValidTemporaryJAR(named: "Second Game")

        installLoadJarMock(on: fixture.native, loadResult: .boolean(true), midletName: .string("Demo Game"))
        let result1 = try await fixture.bootstrap.loadJar(url: first)
        XCTAssertEqual(result1.midletName, "Demo Game")

        installLoadJarMock(on: fixture.native, loadResult: .boolean(true), midletName: .string("Second Game"))
        let result2 = try await fixture.bootstrap.loadJar(url: second)
        XCTAssertEqual(result2.midletName, "Second Game")
        XCTAssertEqual(fixture.bootstrap.lastJarLoadResult, result2)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
    }

    func testShutdownClearsJarLoadResultAndRejectsFurtherLoad() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native, loadResult: .boolean(true), midletName: .string("Demo Game"))
        _ = try await fixture.bootstrap.loadJar(url: jarURL)
        XCTAssertNotNil(fixture.bootstrap.lastJarLoadResult)

        try await fixture.bootstrap.shutdown()

        XCTAssertNil(fixture.bootstrap.lastJarLoadResult)
        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertNil(fixture.bootstrap.painterObjectId)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 0)

        do {
            _ = try await fixture.bootstrap.loadJar(url: jarURL)
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.shutdown))
        }
    }

    func testLoadJarBeforeInitializeFails() async throws {
        let fixture = makeFixture()
        let jarURL = try makeValidTemporaryJAR()

        do {
            _ = try await fixture.bootstrap.loadJar(url: jarURL)
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.uninitialized))
        }
    }

    // MARK: - Helpers

    private struct Fixture {
        let jvm: StubEmbeddedJVMController
        let native: MockJNIGatewayNativeBackend
        let gateway: DefaultJNIGateway
        let bootstrap: DefaultPlatformBootstrap
    }

    private func makeFixture() -> Fixture {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)
        return Fixture(jvm: jvm, native: native, gateway: gateway, bootstrap: bootstrap)
    }

    /// Routes `loadJar` (instance + string arg) and `midletNameAfterLoad` (static + object arg).
    private func installLoadJarMock(
        on native: MockJNIGatewayNativeBackend,
        loadResult: JNINativeResult,
        midletName: JNINativeResult
    ) {
        native.invokeHandler = { request in
            if !request.isStatic,
               request.arguments.count == 1,
               case .string = request.arguments[0] {
                return loadResult
            }
            if request.isStatic,
               request.arguments.count == 1,
               case .object = request.arguments[0] {
                return midletName
            }
            return .void
        }
    }

    private func makeValidTemporaryJAR(named midletName: String = "Demo Game") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jarURL = directory.appendingPathComponent("demo.jar")
        let manifest = """
        Manifest-Version: 1.0
        MIDlet-1: \(midletName), , com.example.DemoMIDlet
        MIDlet-Name: \(midletName)
        MIDlet-Vendor: JavaOne
        MIDlet-Version: 1.0
        MicroEdition-Configuration: CLDC-1.0
        MicroEdition-Profile: MIDP-2.0

        """
        try JarLoadTestJARBuilder.makeJAR(manifestText: manifest).write(to: jarURL)
        return jarURL
    }

    private func makeMalformedTemporaryJAR() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jarURL = directory.appendingPathComponent("broken.jar")
        try JarLoadTestJARBuilder.makeJAR(manifestText: "Manifest-Version: 1.0\n").write(to: jarURL)
        return jarURL
    }
}

// MARK: - Minimal ZIP (stored) JAR builder

private enum JarLoadTestJARBuilder {
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    static func makeJAR(manifestText: String) throws -> Data {
        let entryName = "META-INF/MANIFEST.MF"
        let payload = Data(manifestText.utf8)
        var local = Data()
        var central = Data()

        let nameData = Data(entryName.utf8)
        let localOffset = UInt32(local.count)

        local.append(contentsOf: localFileHeaderSignature.littleEndianBytes)
        local.append(contentsOf: UInt16(20).littleEndianBytes) // version needed
        local.append(contentsOf: UInt16(0).littleEndianBytes) // flags
        local.append(contentsOf: UInt16(0).littleEndianBytes) // stored
        local.append(contentsOf: UInt16(0).littleEndianBytes) // time
        local.append(contentsOf: UInt16(0).littleEndianBytes) // date
        local.append(contentsOf: UInt32(0).littleEndianBytes) // crc (0 ok for tests)
        local.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        local.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        local.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes) // extra
        local.append(nameData)
        local.append(payload)

        central.append(contentsOf: centralDirectorySignature.littleEndianBytes)
        central.append(contentsOf: UInt16(20).littleEndianBytes)
        central.append(contentsOf: UInt16(20).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt32(0).littleEndianBytes)
        central.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        central.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        central.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt16(0).littleEndianBytes)
        central.append(contentsOf: UInt32(0).littleEndianBytes)
        central.append(contentsOf: localOffset.littleEndianBytes)
        central.append(nameData)

        var end = Data()
        end.append(contentsOf: endOfCentralDirectorySignature.littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)
        end.append(contentsOf: UInt16(1).littleEndianBytes)
        end.append(contentsOf: UInt16(1).littleEndianBytes)
        end.append(contentsOf: UInt32(central.count).littleEndianBytes)
        end.append(contentsOf: UInt32(local.count).littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)

        return local + central + end
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian, Array.init)
    }
}
