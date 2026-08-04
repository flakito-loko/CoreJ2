import XCTest
@testable import JavaOne

/// E3-US001 — PlatformBootstrap JNI skeleton lifecycle.
final class PlatformBootstrapTests: XCTestCase {

    func testInitializeBindsGatewayAndRegistersNative() async throws {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        XCTAssertEqual(bootstrap.state, .uninitialized)
        XCTAssertFalse(bootstrap.isReady)

        try await bootstrap.initialize()

        XCTAssertTrue(bootstrap.isReady)
        XCTAssertEqual(bootstrap.state, .ready)
        XCTAssertEqual(jvm.ensureStartedCount, 1)
        XCTAssertEqual(jvm.state, .ready)
        XCTAssertTrue(gateway.isUsable)
        XCTAssertEqual(bootstrap.registeredNativeCount, 2)
        XCTAssertEqual(native.registerNativeCallCount, 2)
        XCTAssertEqual(native.liveNativeRegistrationCount, 2)
        XCTAssertNotNil(bootstrap.mobilePlatformObjectId)
        XCTAssertNotNil(bootstrap.painterObjectId)
        XCTAssertEqual(native.objectCreateCount, 2)
    }

    func testShutdownInvalidatesGatewayAndStopsJVM() async throws {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        try await bootstrap.initialize()
        try await bootstrap.shutdown()

        XCTAssertEqual(bootstrap.state, .shutdown)
        XCTAssertFalse(bootstrap.isReady)
        XCTAssertFalse(gateway.isUsable)
        XCTAssertNil(bootstrap.mobilePlatformObjectId)
        XCTAssertEqual(bootstrap.registeredNativeCount, 0)
        XCTAssertEqual(native.liveNativeRegistrationCount, 0)
        XCTAssertEqual(jvm.shutdownCount, 1)
        XCTAssertEqual(jvm.state, .destroyed)
    }

    func testFullLifecycleOrder() async throws {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        try await bootstrap.initialize()
        XCTAssertEqual(jvm.ensureStartedCount, 1)
        XCTAssertTrue(gateway.isUsable)
        XCTAssertEqual(native.registerNativeCallCount, 2)

        let registrationToken = native.registrationTokensInOrder.first
        XCTAssertNotNil(registrationToken)
        if let token = registrationToken {
            _ = native.simulateNativeCallback(registrationToken: token, arguments: [])
            XCTAssertEqual(bootstrap.heartbeatInvocationCount, 1)
        }

        try await bootstrap.shutdown()
        XCTAssertEqual(jvm.shutdownCount, 1)
        XCTAssertFalse(gateway.isUsable)
    }

    func testDoubleInitializeFails() async throws {
        let jvm = StubEmbeddedJVMController()
        let gateway = DefaultJNIGateway(
            readiness: jvm,
            native: MockJNIGatewayNativeBackend()
        )
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        try await bootstrap.initialize()
        do {
            try await bootstrap.initialize()
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.ready))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testDoubleShutdownFails() async throws {
        let jvm = StubEmbeddedJVMController()
        let gateway = DefaultJNIGateway(
            readiness: jvm,
            native: MockJNIGatewayNativeBackend()
        )
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        try await bootstrap.initialize()
        try await bootstrap.shutdown()
        do {
            try await bootstrap.shutdown()
            XCTFail("expected invalidState")
        } catch let error as PlatformBootstrapError {
            XCTAssertEqual(error, .invalidState(.shutdown))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testInitializeFailsWhenJVMCannotStart() async throws {
        let jvm = StubEmbeddedJVMController()
        jvm.ensureStartedError = EmbeddedJVMError.failed("boom")
        let gateway = DefaultJNIGateway(
            readiness: jvm,
            native: MockJNIGatewayNativeBackend()
        )
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
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertFalse(gateway.isUsable)
    }

    func testReinitializeAfterShutdown() async throws {
        let jvm = StubEmbeddedJVMController()
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: jvm, native: native)
        let bootstrap = DefaultPlatformBootstrap(jvm: jvm, gateway: gateway)

        try await bootstrap.initialize()
        try await bootstrap.shutdown()

        // Fresh gateway binding after JVM stub is "restarted" by ensureStarted.
        try await bootstrap.initialize()
        XCTAssertTrue(bootstrap.isReady)
        XCTAssertEqual(jvm.ensureStartedCount, 2)
        XCTAssertEqual(bootstrap.registeredNativeCount, 2)
    }
}
