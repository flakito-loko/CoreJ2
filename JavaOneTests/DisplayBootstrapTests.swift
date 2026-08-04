import XCTest
@testable import JavaOne

/// E3-US007 — FreeJ2ME Display lifecycle verification via PlatformBootstrap.
final class DisplayBootstrapTests: XCTestCase {

    // MARK: - Successful activation

    func testSuccessfulDisplayActivation() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)

        installDisplayMock(on: fixture.native, status: "OK:Canvas")
        let result = try await fixture.bootstrap.verifyDisplay()

        XCTAssertTrue(result.displayInitialized)
        XCTAssertTrue(result.hasCurrentDisplayable)
        XCTAssertTrue(result.displayLifecycleReached)
        XCTAssertEqual(result.currentDisplayableClassName, "Canvas")
        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertEqual(fixture.bootstrap.lastDisplayResult, result)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
    }

    func testRepeatedVerificationSucceeds() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)
        installDisplayMock(on: fixture.native, status: "OK:Canvas")

        let first = try await fixture.bootstrap.verifyDisplay()
        let second = try await fixture.bootstrap.verifyDisplay()

        XCTAssertEqual(first, second)
        XCTAssertEqual(fixture.bootstrap.lastDisplayResult, second)
    }

    // MARK: - Missing Display / Displayable

    func testMissingDisplayMapsToDisplayNotPresent() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)
        installDisplayMock(on: fixture.native, status: "NO_DISPLAY")

        do {
            _ = try await fixture.bootstrap.verifyDisplay()
            XCTFail("expected displayNotPresent")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .displayNotPresent)
        }
        XCTAssertNil(fixture.bootstrap.lastDisplayResult)
    }

    func testMissingDisplayableMapsToNoCurrentDisplayable() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)
        installDisplayMock(on: fixture.native, status: "NO_CURRENT")

        do {
            _ = try await fixture.bootstrap.verifyDisplay()
            XCTFail("expected noCurrentDisplayable")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .noCurrentDisplayable)
        }
        XCTAssertNil(fixture.bootstrap.lastDisplayResult)
    }

    // MARK: - Malformed / ordering

    func testVerifyWithoutRunJarFails() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)

        do {
            _ = try await fixture.bootstrap.verifyDisplay()
            XCTFail("expected midletNotRunning")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .midletNotRunning)
        }
    }

    func testMalformedStatusMapsToNoCurrentDisplayable() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)
        installDisplayMock(on: fixture.native, status: "UNEXPECTED")

        do {
            _ = try await fixture.bootstrap.verifyDisplay()
            XCTFail("expected noCurrentDisplayable")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .noCurrentDisplayable)
        }
    }

    // MARK: - Shutdown

    func testShutdownClearsDisplayResult() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        try await loadAndRun(fixture: fixture)
        installDisplayMock(on: fixture.native, status: "OK:Form")
        _ = try await fixture.bootstrap.verifyDisplay()
        XCTAssertNotNil(fixture.bootstrap.lastDisplayResult)

        try await fixture.bootstrap.shutdown()

        XCTAssertNil(fixture.bootstrap.lastDisplayResult)
        XCTAssertNil(fixture.bootstrap.lastJarRunResult)
        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 0)

        do {
            _ = try await fixture.bootstrap.verifyDisplay()
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.shutdown))
        }
    }

    // MARK: - Contract

    func testDisplayInspectionConstants() {
        XCTAssertEqual(
            DefaultPlatformBootstrap.DisplayInspection.supportBinaryName,
            "org/javaone/bootstrap/DisplaySupport"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.DisplayInspection.inspectStatusMethodName,
            "inspectStatus"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.DisplayInspection.inspectStatusSignature,
            "()Ljava/lang/String;"
        )
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

    private func loadAndRun(fixture: Fixture) async throws {
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)
        installRunJarMock(on: fixture.native, verifyResult: .boolean(true))
        _ = try await fixture.bootstrap.runJar()
    }

    private func installLoadJarMock(on native: MockJNIGatewayNativeBackend) {
        native.invokeHandler = { request in
            if !request.isStatic,
               request.arguments.count == 1,
               case .string = request.arguments[0] {
                return .boolean(true)
            }
            if request.isStatic,
               request.arguments.count == 1,
               case .object = request.arguments[0] {
                return .string("Demo Game")
            }
            return .void
        }
    }

    private func installRunJarMock(
        on native: MockJNIGatewayNativeBackend,
        verifyResult: JNINativeResult
    ) {
        native.invokeHandler = { request in
            if request.isStatic,
               request.arguments.count == 1,
               case .object = request.arguments[0] {
                return verifyResult
            }
            return .void
        }
    }

    private func installDisplayMock(on native: MockJNIGatewayNativeBackend, status: String) {
        native.invokeHandler = { request in
            if request.isStatic, request.arguments.isEmpty {
                return .string(status)
            }
            return .void
        }
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
        try DisplayTestJARBuilder.makeJAR(manifestText: manifest).write(to: jarURL)
        return jarURL
    }
}

// MARK: - Minimal ZIP (stored) JAR builder

private enum DisplayTestJARBuilder {
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
        local.append(contentsOf: UInt16(20).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes)
        local.append(contentsOf: UInt32(0).littleEndianBytes)
        local.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        local.append(contentsOf: UInt32(payload.count).littleEndianBytes)
        local.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
        local.append(contentsOf: UInt16(0).littleEndianBytes)
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
