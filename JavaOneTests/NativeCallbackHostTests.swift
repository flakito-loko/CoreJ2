import XCTest
@testable import JavaOne

/// E3-US002 — `org.javaone.bootstrap.NativeCallbackHost` ↔ PlatformBootstrap heartbeat.
final class NativeCallbackHostTests: XCTestCase {

    // MARK: - Contract

    func testJavaContractMatchesBootstrapRegistration() {
        XCTAssertEqual(
            DefaultPlatformBootstrap.Infrastructure.callbackHostBinaryName,
            "org/javaone/bootstrap/NativeCallbackHost"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.Infrastructure.heartbeatMethodName,
            "onBootstrapHeartbeat"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.Infrastructure.heartbeatSignature,
            "()V"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.Infrastructure.fireHeartbeatMethodName,
            "fireHeartbeat"
        )
        XCTAssertEqual(
            DefaultPlatformBootstrap.Infrastructure.fireHeartbeatSignature,
            "()V"
        )
    }

    // MARK: - Registration

    func testCallbackRegistrationTargetsNativeCallbackHost() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        XCTAssertEqual(fixture.native.registerNativeCallCount, 2)
        XCTAssertEqual(fixture.native.liveNativeRegistrationCount, 2)
        XCTAssertEqual(fixture.bootstrap.registeredNativeCount, 2)
        XCTAssertTrue(fixture.gateway.isUsable)

        let classId = try fixture.gateway.resolveClass(
            binaryName: DefaultPlatformBootstrap.Infrastructure.callbackHostBinaryName
        )
        _ = try fixture.gateway.resolveMethod(
            classId: classId,
            name: DefaultPlatformBootstrap.Infrastructure.heartbeatMethodName,
            signature: DefaultPlatformBootstrap.Infrastructure.heartbeatSignature,
            isStatic: true
        )
        _ = try fixture.gateway.resolveMethod(
            classId: classId,
            name: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatMethodName,
            signature: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatSignature,
            isStatic: true
        )
    }

    // MARK: - Invocation

    func testHeartbeatNativeInvokesSwiftCallback() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let token = try XCTUnwrap(fixture.native.registrationTokensInOrder.first)
        _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])

        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)
    }

    func testFireHeartbeatEntryDispatchesToRegisteredNative() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let token = try XCTUnwrap(fixture.native.registrationTokensInOrder.first)
        fixture.native.invokeHandler = { _ in
            _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
            return .void
        }

        let classId = try fixture.gateway.resolveClass(
            binaryName: DefaultPlatformBootstrap.Infrastructure.callbackHostBinaryName
        )
        let fireId = try fixture.gateway.resolveMethod(
            classId: classId,
            name: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatMethodName,
            signature: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatSignature,
            isStatic: true
        )
        let result = try fixture.gateway.callStatic(
            classId: classId,
            methodId: fireId,
            arguments: [],
            returning: .void
        )

        XCTAssertEqual(result, .void)
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)
        XCTAssertGreaterThanOrEqual(fixture.native.genericInvokeCount, 1)
    }

    func testMultipleHeartbeatInvocations() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let token = try XCTUnwrap(fixture.native.registrationTokensInOrder.first)
        for _ in 0..<5 {
            _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
        }

        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 5)
        XCTAssertEqual(fixture.native.liveNativeRegistrationCount, 2)
    }

    // MARK: - Unregister / shutdown

    func testUnregisterStopsFurtherCallbacks() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let token = try XCTUnwrap(fixture.native.registrationTokensInOrder.first)
        _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)

        try fixture.gateway.unregisterNative(JNINativeRegistrationId(token: token))

        XCTAssertEqual(fixture.native.unregisterNativeCallCount, 1)
        XCTAssertEqual(fixture.native.liveNativeRegistrationCount, 1)

        _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)
    }

    func testShutdownUnregistersAndRejectsCallbacks() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let token = try XCTUnwrap(fixture.native.registrationTokensInOrder.first)
        _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)

        try await fixture.bootstrap.shutdown()

        XCTAssertEqual(fixture.bootstrap.state, .shutdown)
        XCTAssertFalse(fixture.gateway.isUsable)
        XCTAssertEqual(fixture.bootstrap.registeredNativeCount, 0)
        XCTAssertEqual(fixture.native.liveNativeRegistrationCount, 0)
        XCTAssertGreaterThanOrEqual(fixture.native.unregisterNativeCallCount, 1)

        _ = fixture.native.simulateNativeCallback(registrationToken: token, arguments: [])
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 1)
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
