import XCTest
@testable import JavaOne

/// E2-US005 — Native callback registration / trampoline dispatch.
final class JNIGatewayCallbackTests: XCTestCase {

    private let helloClass = "org/javaone/embedded/spike/HelloWorld"

    private final class CallbackProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var _event: JNICallbackEvent?
        private var _count = 0

        var event: JNICallbackEvent? {
            lock.lock()
            defer { lock.unlock() }
            return _event
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }

        func record(_ event: JNICallbackEvent) {
            lock.lock()
            _event = event
            _count += 1
            lock.unlock()
        }

        func increment() {
            lock.lock()
            _count += 1
            lock.unlock()
        }
    }

    // MARK: - Registration / invocation

    func testSuccessfulCallback() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let probe = CallbackProbe()

        let registration = try gateway.registerNative(
            classId: classId,
            methodName: "onPaint",
            signature: "(I)V",
            isStatic: true
        ) { event in
            probe.record(event)
            return .void
        }

        let result = native.simulateNativeCallback(
            registrationToken: registration.token,
            arguments: [.int(7)]
        )

        XCTAssertEqual(result, .void)
        XCTAssertEqual(probe.event?.methodName, "onPaint")
        XCTAssertEqual(probe.event?.arguments, [.int(7)])
        XCTAssertEqual(probe.event?.registrationId, registration)
        XCTAssertEqual(gateway.nativeRegistrationCount, 1)
        XCTAssertEqual(native.registerNativeCallCount, 1)
        XCTAssertFalse(String(describing: JNICallbackEvent.self).contains("JNIEnv"))
    }

    func testDuplicateRegistrationFails() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        _ = try gateway.registerNative(
            classId: classId,
            methodName: "onPaint",
            signature: "()V",
            isStatic: true
        ) { _ in .void }

        XCTAssertThrowsError(
            try gateway.registerNative(
                classId: classId,
                methodName: "onPaint",
                signature: "()V",
                isStatic: true
            ) { _ in .void }
        ) { error in
            XCTAssertEqual(
                error as? JNIGatewayError,
                .duplicateNativeRegistration(methodName: "onPaint", signature: "()V")
            )
        }
        XCTAssertEqual(gateway.nativeRegistrationCount, 1)
    }

    func testCallbackAfterInvalidateIsRejected() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let probe = CallbackProbe()

        let registration = try gateway.registerNative(
            classId: classId,
            methodName: "onPaint",
            signature: "()V",
            isStatic: true
        ) { _ in
            probe.increment()
            return .void
        }

        gateway.invalidate()
        XCTAssertEqual(gateway.nativeRegistrationCount, 0)
        XCTAssertEqual(native.liveNativeRegistrationCount, 0)

        _ = native.simulateNativeCallback(
            registrationToken: registration.token,
            arguments: []
        )
        XCTAssertEqual(probe.count, 0)
        XCTAssertFalse(gateway.isUsable)
    }

    func testCallbackOrdering() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        let first = try gateway.registerNative(
            classId: classId,
            methodName: "first",
            signature: "()V",
            isStatic: true
        ) { _ in .void }
        let second = try gateway.registerNative(
            classId: classId,
            methodName: "second",
            signature: "()V",
            isStatic: true
        ) { _ in .void }

        _ = native.simulateNativeCallback(registrationToken: second.token, arguments: [])
        _ = native.simulateNativeCallback(registrationToken: first.token, arguments: [])
        _ = native.simulateNativeCallback(registrationToken: second.token, arguments: [])

        XCTAssertEqual(
            gateway.callbackDispatchSequence,
            [second.token, first.token, second.token]
        )
    }

    func testCallbackCleanupOnUnregister() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let probe = CallbackProbe()

        let registration = try gateway.registerNative(
            classId: classId,
            methodName: "onPaint",
            signature: "()V",
            isStatic: true
        ) { _ in
            probe.increment()
            return .void
        }

        try gateway.unregisterNative(registration)
        XCTAssertEqual(gateway.nativeRegistrationCount, 0)
        XCTAssertEqual(native.unregisterNativeCallCount, 1)

        _ = native.simulateNativeCallback(
            registrationToken: registration.token,
            arguments: []
        )
        XCTAssertEqual(probe.count, 0)

        XCTAssertThrowsError(try gateway.unregisterNative(registration)) { error in
            XCTAssertEqual(error as? JNIGatewayError, .nativeRegistrationNotFound)
        }
    }

    func testShutdownCleanupClearsRegistrations() throws {
        let native = MockJNIGatewayNativeBackend()
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        let classId = try gateway.resolveClass(binaryName: helloClass)
        _ = try gateway.registerNative(
            classId: classId,
            methodName: "onPaint",
            signature: "()V",
            isStatic: true
        ) { _ in .void }
        XCTAssertEqual(gateway.nativeRegistrationCount, 1)

        gateway.invalidate()
        XCTAssertEqual(gateway.nativeRegistrationCount, 0)
        XCTAssertEqual(native.liveNativeRegistrationCount, 0)

        try gateway.bind()
        let classId2 = try gateway.resolveClass(binaryName: helloClass)
        let again = try gateway.registerNative(
            classId: classId2,
            methodName: "onPaint",
            signature: "()V",
            isStatic: true
        ) { _ in .void }
        XCTAssertEqual(gateway.nativeRegistrationCount, 1)
        XCTAssertGreaterThan(again.token, 0)
    }

    func testHandlerExceptionDoesNotEscapeTrampoline() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        let registration = try gateway.registerNative(
            classId: classId,
            methodName: "boom",
            signature: "()V",
            isStatic: true
        ) { _ in
            .void
        }

        let result = native.simulateNativeCallback(
            registrationToken: registration.token,
            arguments: []
        )
        XCTAssertEqual(result, .void)
    }

    // MARK: - Helpers

    private func makeBoundGateway(native: MockJNIGatewayNativeBackend) -> DefaultJNIGateway {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)
        do {
            try gateway.bind()
        } catch {
            XCTFail("bind failed: \(error)")
        }
        return gateway
    }
}
