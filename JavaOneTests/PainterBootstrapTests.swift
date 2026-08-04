import XCTest
@testable import JavaOne

/// E3-US004 — MobilePlatform painter Runnable registration via PlatformBootstrap.
final class PainterBootstrapTests: XCTestCase {

    // MARK: - Contract

    func testPainterContractConstants() {
        XCTAssertEqual(
            DefaultPlatformBootstrap.Painter.binaryName,
            "org/javaone/bootstrap/PainterRunnable"
        )
        XCTAssertEqual(DefaultPlatformBootstrap.Painter.runMethodName, "run")
        XCTAssertEqual(DefaultPlatformBootstrap.Painter.runSignature, "()V")
        XCTAssertEqual(
            DefaultPlatformBootstrap.FreeJ2ME.setPainterSignature,
            "(Ljava/lang/Runnable;)V"
        )
    }

    // MARK: - Registration

    func testPainterRegistrationCreatesRunnableAndCallsSetPainter() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let painterId = try XCTUnwrap(fixture.bootstrap.painterObjectId)
        let platformId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertTrue(fixture.gateway.containsObject(painterId))
        XCTAssertTrue(fixture.gateway.containsObject(platformId))
        XCTAssertEqual(fixture.bootstrap.registeredNativeCount, 2)
        XCTAssertEqual(fixture.native.registerNativeCallCount, 2)
        XCTAssertEqual(fixture.native.objectCreateCount, 2)

        let last = try XCTUnwrap(fixture.native.lastInvokeRequest)
        XCTAssertFalse(last.isStatic)
        XCTAssertEqual(last.arguments.count, 1)
        if case .object = last.arguments[0] {
            // setPainter(runnable)
        } else {
            XCTFail("expected object argument to setPainter, got \(last.arguments)")
        }
    }

    // MARK: - Callback

    func testPainterNativeCallbackReachesSwift() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        // Heartbeat is first registration; painter `run` is second.
        XCTAssertEqual(fixture.native.registrationTokensInOrder.count, 2)
        let painterToken = try XCTUnwrap(fixture.native.registrationTokensInOrder.last)
        _ = fixture.native.simulateNativeCallback(registrationToken: painterToken, arguments: [])

        XCTAssertEqual(fixture.bootstrap.paintInvocationCount, 1)
        XCTAssertEqual(fixture.bootstrap.heartbeatInvocationCount, 0)
    }

    func testFirePaintEntryDispatchesToRegisteredNative() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()

        let painterToken = try XCTUnwrap(fixture.native.registrationTokensInOrder.last)
        let painterId = try XCTUnwrap(fixture.bootstrap.painterObjectId)
        fixture.native.invokeHandler = { _ in
            _ = fixture.native.simulateNativeCallback(registrationToken: painterToken, arguments: [])
            return .void
        }

        let painterClassId = try fixture.gateway.resolveClass(
            binaryName: DefaultPlatformBootstrap.Painter.binaryName
        )
        let fireId = try fixture.gateway.resolveMethod(
            classId: painterClassId,
            name: DefaultPlatformBootstrap.Painter.firePaintMethodName,
            signature: DefaultPlatformBootstrap.Painter.firePaintSignature,
            isStatic: false
        )
        let result = try fixture.gateway.callInstance(
            objectId: painterId,
            methodId: fireId,
            arguments: [],
            returning: .void
        )

        XCTAssertEqual(result, .void)
        XCTAssertEqual(fixture.bootstrap.paintInvocationCount, 1)
    }

    // MARK: - Shutdown

    func testShutdownReleasesPainterAndPlatform() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let painterId = try XCTUnwrap(fixture.bootstrap.painterObjectId)
        let platformId = try XCTUnwrap(fixture.bootstrap.mobilePlatformObjectId)
        let painterToken = try XCTUnwrap(fixture.native.registrationTokensInOrder.last)

        try await fixture.bootstrap.shutdown()

        XCTAssertNil(fixture.bootstrap.painterObjectId)
        XCTAssertNil(fixture.bootstrap.mobilePlatformObjectId)
        XCTAssertFalse(fixture.gateway.containsObject(painterId))
        XCTAssertFalse(fixture.gateway.containsObject(platformId))
        XCTAssertEqual(fixture.native.objectReleaseCount, 2)
        XCTAssertEqual(fixture.native.liveGlobalObjectRefCount, 0)
        XCTAssertEqual(fixture.native.liveNativeRegistrationCount, 0)

        _ = fixture.native.simulateNativeCallback(registrationToken: painterToken, arguments: [])
        XCTAssertEqual(fixture.bootstrap.paintInvocationCount, 0)
    }

    // MARK: - Repeated initialize

    func testRepeatedInitializeAfterShutdownReinstallsPainter() async throws {
        let fixture = makeFixture()
        try await fixture.bootstrap.initialize()
        let firstPainter = try XCTUnwrap(fixture.bootstrap.painterObjectId)
        try await fixture.bootstrap.shutdown()

        try await fixture.bootstrap.initialize()
        let secondPainter = try XCTUnwrap(fixture.bootstrap.painterObjectId)

        XCTAssertTrue(fixture.gateway.containsObject(secondPainter))
        XCTAssertFalse(fixture.gateway.containsObject(firstPainter))
        XCTAssertEqual(fixture.native.objectCreateCount, 4)
        XCTAssertEqual(fixture.bootstrap.registeredNativeCount, 2)

        let painterToken = try XCTUnwrap(fixture.native.registrationTokensInOrder.last)
        _ = fixture.native.simulateNativeCallback(registrationToken: painterToken, arguments: [])
        XCTAssertEqual(fixture.bootstrap.paintInvocationCount, 1)
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
