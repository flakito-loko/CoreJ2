import XCTest
@testable import JavaOne

final class JNIGatewayTests: XCTestCase {

    // MARK: - JVM readiness

    func testBindFailsWhenJVMNotReady() {
        let readiness = StubEmbeddedJVMReadiness(state: .notInitialized)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        XCTAssertThrowsError(try gateway.bind()) { error in
            XCTAssertEqual(error as? JNIGatewayError, .jvmNotReady(.notInitialized))
        }
        XCTAssertFalse(gateway.isUsable)
        XCTAssertEqual(native.invokeCount, 0)
    }

    func testInvokeFailsWhenNotBound() async {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        do {
            try await gateway.invokeHelloWorldMain()
            XCTFail("expected gatewayInvalidated")
        } catch let error as JNIGatewayError {
            XCTAssertEqual(error, .gatewayInvalidated)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - HelloWorld success

    func testHelloWorldExecutesSuccessfully() async throws {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        XCTAssertTrue(gateway.isUsable)
        try await gateway.invokeHelloWorldMain()

        XCTAssertEqual(native.invokeCount, 1)
        XCTAssertNotNil(native.lastCachedClassNativeId)
        XCTAssertEqual(native.findClassInvocationCount, 1)
        XCTAssertEqual(native.getMethodIDInvocationCount, 1)
    }

    // MARK: - Java exception mapping

    func testJavaExceptionMapsToSwiftError() async {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        native.shouldFailWith = .javaException(type: "java.lang.RuntimeException", message: "boom")
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try? gateway.bind()

        do {
            try await gateway.invokeHelloWorldMain()
            XCTFail("expected javaException")
        } catch let error as JNIGatewayError {
            XCTAssertEqual(
                error,
                .javaException(type: "java.lang.RuntimeException", message: "boom")
            )
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - Local references

    func testLocalReferencesAreReleasedOnSuccess() async throws {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        try await gateway.invokeHelloWorldMain()

        XCTAssertEqual(native.lastLocalFramesPushed, 1)
        XCTAssertEqual(native.lastLocalFramesPopped, 1)
    }

    func testLocalReferencesAreReleasedOnJavaException() async {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        native.shouldFailWith = .javaException(type: "java.lang.Exception", message: "x")
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try? gateway.bind()
        _ = try? await gateway.invokeHelloWorldMain()

        XCTAssertEqual(native.lastLocalFramesPushed, 1)
        XCTAssertEqual(native.lastLocalFramesPopped, 1)
    }

    // MARK: - Opaque public API

    func testOpaqueHandlesDoNotExposeJNIPointerTypes() throws {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let gateway = DefaultJNIGateway(readiness: readiness, native: MockJNIGatewayNativeBackend())
        try gateway.bind()

        let classId = try gateway.resolveClass(binaryName: "org/javaone/embedded/spike/HelloWorld")
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "([Ljava/lang/String;)V",
            isStatic: true
        )

        XCTAssertGreaterThan(classId.token, 0)
        XCTAssertGreaterThan(methodId.token, 0)
        XCTAssertNotEqual(
            String(describing: type(of: classId)),
            "OpaquePointer"
        )
        XCTAssertFalse(String(describing: JNIClassId.self).contains("OpaquePointer"))
        XCTAssertFalse(String(describing: JNIMethodId.self).contains("JNIEnv"))
        XCTAssertFalse(String(describing: JNIGatewayError.self).contains("jobject"))
    }

    func testInvalidateRejectsFurtherUse() async throws {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        gateway.invalidate()
        XCTAssertFalse(gateway.isUsable)

        do {
            try await gateway.invokeHelloWorldMain()
            XCTFail("expected gatewayInvalidated")
        } catch let error as JNIGatewayError {
            XCTAssertEqual(error, .gatewayInvalidated)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(native.invokeCount, 0)
    }

    func testStateTransitionAwayFromReadyRejectsInvoke() async throws {
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let native = MockJNIGatewayNativeBackend()
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)
        try gateway.bind()

        readiness.state = .destroyed

        do {
            try await gateway.invokeHelloWorldMain()
            XCTFail("expected jvmNotReady")
        } catch let error as JNIGatewayError {
            XCTAssertEqual(error, .jvmNotReady(.destroyed))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
