import XCTest
@testable import JavaOne

/// E3-US006 — `MobilePlatform.runJar` via PlatformBootstrap (no rendering).
final class JarRunBootstrapTests: XCTestCase {

    // MARK: - Successful run

    func testSuccessfulRunJarReachesStartApp() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)

        installRunJarMock(on: fixture.native, verifyResult: .boolean(true))
        let result = try await fixture.bootstrap.runJar()

        XCTAssertEqual(result.midletName, "Demo Game")
        XCTAssertTrue(result.reachedStartApp)
        XCTAssertEqual(result.jarURLString, jarURL.standardizedFileURL.absoluteString)
        XCTAssertEqual(fixture.bootstrap.lastJarRunResult, result)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
    }

    // MARK: - Without loadJar

    func testRunWithoutLoadJarFails() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        do {
            _ = try await fixture.bootstrap.runJar()
            XCTFail("expected midletNotLoaded")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .midletNotLoaded)
        }

        XCTAssertNil(fixture.bootstrap.lastJarRunResult)
    }

    // MARK: - Failure during startApp

    func testRunJarVerificationFailureMapsToRunJarFailed() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)

        installRunJarMock(on: fixture.native, verifyResult: .boolean(false))

        do {
            _ = try await fixture.bootstrap.runJar()
            XCTFail("expected runJarFailed")
        } catch let error as PlatformBootstrapError {
            guard case .runJarFailed = error else {
                return XCTFail("expected runJarFailed, got \(error)")
            }
        }

        XCTAssertNil(fixture.bootstrap.lastJarRunResult)
        XCTAssertEqual(fixture.bootstrap.state, .ready)
    }

    func testJavaExceptionDuringRunMapsToGatewayFailure() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)

        fixture.native.invokeHandler = { _ in
            throw JNIGatewayError.javaException(
                type: "javax.microedition.midlet.MIDletStateChangeException",
                message: "boom"
            )
        }

        do {
            _ = try await fixture.bootstrap.runJar()
            XCTFail("expected gatewayFailure")
        } catch let error as PlatformBootstrapError {
            guard case .gatewayFailure = error else {
                return XCTFail("expected gatewayFailure, got \(error)")
            }
        }

        XCTAssertNil(fixture.bootstrap.lastJarRunResult)
    }

    // MARK: - Repeated run

    func testRepeatedRunIsRejected() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)
        installRunJarMock(on: fixture.native, verifyResult: .boolean(true))
        _ = try await fixture.bootstrap.runJar()

        do {
            _ = try await fixture.bootstrap.runJar()
            XCTFail("expected alreadyRunning")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .alreadyRunning)
        }
    }

    // MARK: - Shutdown

    func testShutdownClearsRunResultAndReleasesJNIObjects() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let jarURL = try makeValidTemporaryJAR()
        installLoadJarMock(on: fixture.native)
        _ = try await fixture.bootstrap.loadJar(url: jarURL)
        installRunJarMock(on: fixture.native, verifyResult: .boolean(true))
        _ = try await fixture.bootstrap.runJar()
        XCTAssertNotNil(fixture.bootstrap.lastJarRunResult)

        try await fixture.bootstrap.shutdown()

        XCTAssertNil(fixture.bootstrap.lastJarLoadResult)
        XCTAssertNil(fixture.bootstrap.lastJarRunResult)
        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertNil(fixture.bootstrap.painterObjectId)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 0)

        do {
            _ = try await fixture.bootstrap.runJar()
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.shutdown))
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
        try JarRunTestJARBuilder.makeJAR(manifestText: manifest).write(to: jarURL)
        return jarURL
    }
}

// MARK: - Minimal ZIP (stored) JAR builder

private enum JarRunTestJARBuilder {
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
