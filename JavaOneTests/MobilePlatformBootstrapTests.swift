import XCTest
@testable import JavaOne

/// E3-US003 — FreeJ2ME MobilePlatform construction + `Mobile.setPlatform` via PlatformBootstrap.
final class MobilePlatformBootstrapTests: XCTestCase {

    // MARK: - Successful bootstrap

    func testSuccessfulBootstrapConstructsAndBindsPlatform() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        XCTAssertTrue(fixture.bootstrap.isReady)
        let platformId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertTrue(fixture.gateway.containsObject(platformId))
        XCTAssertEqual(fixture.native.objectCreateCount, 2)
        XCTAssertEqual(fixture.native.constructorArgumentsHistory.first, [.int(240), .int(320)])
        XCTAssertEqual(fixture.bootstrap.registeredNativeCount, 2)
        XCTAssertGreaterThanOrEqual(fixture.native.genericInvokeCount, 2)
        XCTAssertNotNil(fixture.bootstrap.painterObjectId)

        // Last invoke is setPainter (instance); setPlatform ran earlier.
        let last = try XCTUnwrap(fixture.native.lastInvokeRequest)
        XCTAssertFalse(last.isStatic)
        XCTAssertEqual(last.arguments.count, 1)
        if case .object = last.arguments[0] {
            // setPainter(runnable)
        } else {
            XCTFail("expected object argument to setPainter, got \(last.arguments)")
        }
    }

    func testCustomLCDDimensionsPassedToConstructor() async throws {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(
            jvm: jvm,
            gateway: gateway,
            lcdWidth: 176,
            lcdHeight: 220
        )

        try await bootstrap.initialize()

        XCTAssertEqual(native.constructorArgumentsHistory.first, [.int(176), .int(220)])
    }

    // MARK: - Repeated initialize

    func testRepeatedInitializeFailsWhileReady() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        do {
            try await fixture.bootstrap.initialize()
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.ready))
        }
        XCTAssertNotNil(fixture.bootstrap.mobilePlatformObjectId)
    }

    func testReinitializeAfterShutdownCreatesNewPlatform() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let firstId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        try await fixture.bootstrap.shutdown()

        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertFalse(fixture.gateway.containsObject(firstId))

        try await fixture.bootstrap.initialize()
        let secondId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertTrue(fixture.gateway.containsObject(secondId))
        XCTAssertEqual(fixture.native.objectCreateCount, 4)
    }

    // MARK: - Shutdown / object release

    func testShutdownReleasesPlatformGlobalRef() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let platformId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 2)

        try await fixture.bootstrap.shutdown()

        XCTAssertEqual(fixture.bootstrap.state, .shutdown)
        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertNil(fixture.bootstrap.painterObjectId)
        XCTAssertFalse(fixture.gateway.containsObject(platformId))
        XCTAssertEqual(fixture.native.objectReleaseCount, 2)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 0)
        XCTAssertFalse(fixture.gateway.isUsable)
    }

    // MARK: - Invalid JVM state

    func testInitializeFailsWhenJVMCannotStart() async throws {
        let jvm = StubEmbeddedJVMController()
        jvm.ensureStartedError = EmbeddedJVMError.failed("no-jvm")
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        do {
            try await bootstrap.initialize()
            XCTFail("expected failure")
        } catch is PlatformBootstrapError {
            if case .failed = bootstrap.state {
                // ok
            } else {
                XCTFail("expected failed state, got \(bootstrap.state)")
            }
        }
        XCTAssertNil(bootstrap.mobilePlatformObjectId)
        XCTAssertEqual(native.objectCreateCount, 0)
        XCTAssertFalse(gateway.isUsable)
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
}
