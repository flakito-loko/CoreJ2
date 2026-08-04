import XCTest
@testable import JavaOne

/// E2-US004 — Generic callStatic / callInstance.
final class JNIGatewayInvocationTests: XCTestCase {

    private let helloClass = "org/javaone/embedded/spike/HelloWorld"

    // MARK: - Static

    func testStaticVoidInvocation() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "([Ljava/lang/String;)V",
            isStatic: true
        )

        let result = try gateway.callStatic(
            classId: classId,
            methodId: methodId,
            arguments: [],
            returning: .void
        )

        XCTAssertEqual(result, .void)
        XCTAssertEqual(native.genericInvokeCount, 1)
        XCTAssertEqual(native.lastInvokeRequest?.isStatic, true)
        XCTAssertEqual(native.lastLocalFramesPushed, 1)
        XCTAssertEqual(native.lastLocalFramesPopped, 1)
    }

    func testStaticPrimitiveArgumentsAndReturn() throws {
        let native = MockJNIGatewayNativeBackend()
        native.invokeHandler = { request in
            XCTAssertEqual(request.arguments.count, 3)
            XCTAssertEqual(request.arguments[0], .int(2))
            XCTAssertEqual(request.arguments[1], .long(3))
            XCTAssertEqual(request.arguments[2], .boolean(true))
            return .int(42)
        }
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "sum",
            signature: "(IJZ)I",
            isStatic: true
        )

        let result = try gateway.callStatic(
            classId: classId,
            methodId: methodId,
            arguments: [.int(2), .long(3), .boolean(true)],
            returning: .int
        )

        XCTAssertEqual(result, .int(42))
    }

    func testStaticStringReturn() throws {
        let native = MockJNIGatewayNativeBackend()
        native.invokeHandler = { _ in .string("pong") }
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "echo",
            signature: "(Ljava/lang/String;)Ljava/lang/String;",
            isStatic: true
        )

        let result = try gateway.callStatic(
            classId: classId,
            methodId: methodId,
            arguments: [.string("ping")],
            returning: .string
        )

        XCTAssertEqual(result, .string("pong"))
        XCTAssertEqual(native.lastInvokeRequest?.arguments.first, .string("ping"))
    }

    // MARK: - Instance

    func testInstanceVoidInvocation() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let objectId = try gateway.createGlobalObjectReference(classId: classId)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "run",
            signature: "()V",
            isStatic: false
        )

        let result = try gateway.callInstance(
            objectId: objectId,
            methodId: methodId,
            arguments: [],
            returning: .void
        )

        XCTAssertEqual(result, .void)
        XCTAssertEqual(native.lastInvokeRequest?.isStatic, false)
        XCTAssertNotNil(native.lastInvokeRequest?.receiverObjectNativeId)
    }

    func testObjectArgumentPassesNativeId() throws {
        let native = MockJNIGatewayNativeBackend()
        var seenObjectNativeId: UInt64?
        native.invokeHandler = { request in
            if case .object(let id) = request.arguments.first {
                seenObjectNativeId = id
            }
            return .void
        }
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let objectId = try gateway.createGlobalObjectReference(classId: classId)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "accept",
            signature: "(Ljava/lang/Object;)V",
            isStatic: true
        )

        _ = try gateway.callStatic(
            classId: classId,
            methodId: methodId,
            arguments: [.object(objectId)],
            returning: .void
        )

        XCTAssertNotNil(seenObjectNativeId)
        XCTAssertGreaterThan(seenObjectNativeId ?? 0, 0)
    }

    func testObjectReturnBecomesOpaqueHandle() throws {
        let native = MockJNIGatewayNativeBackend()
        native.invokeHandler = { request in
            // Allocate a fresh native global id as CallObject would.
            return .object(nativeId: 9_001)
        }
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "factory",
            signature: "()Ljava/lang/Object;",
            isStatic: true
        )

        let result = try gateway.callStatic(
            classId: classId,
            methodId: methodId,
            arguments: [],
            returning: .object
        )

        guard case .object(let objectId) = result else {
            return XCTFail("expected object handle")
        }
        XCTAssertTrue(gateway.containsObject(objectId))
        XCTAssertEqual(gateway.retainedObjectCount, 1)
        XCTAssertEqual(native.liveGlobalObjectRefCount, 1)
    }

    // MARK: - Errors / cleanup

    func testJavaExceptionMapping() throws {
        let native = MockJNIGatewayNativeBackend()
        native.shouldFailWith = .javaException(type: "java.lang.IllegalStateException", message: "bad")
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "boom",
            signature: "()V",
            isStatic: true
        )

        XCTAssertThrowsError(
            try gateway.callStatic(
                classId: classId,
                methodId: methodId,
                arguments: [],
                returning: .void
            )
        ) { error in
            XCTAssertEqual(
                error as? JNIGatewayError,
                .javaException(type: "java.lang.IllegalStateException", message: "bad")
            )
        }
        XCTAssertEqual(native.lastLocalFramesPushed, 1)
        XCTAssertEqual(native.lastLocalFramesPopped, 1)
    }

    func testInvalidObjectAndMethod() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let staticMethod = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "()V",
            isStatic: true
        )
        let instanceMethod = try gateway.resolveMethod(
            classId: classId,
            name: "run",
            signature: "()V",
            isStatic: false
        )

        XCTAssertThrowsError(
            try gateway.callInstance(
                objectId: JNIObjectId(token: 99),
                methodId: instanceMethod,
                arguments: [],
                returning: .void
            )
        ) { error in
            XCTAssertEqual(error as? JNIGatewayError, .objectNotFound)
        }

        let objectId = try gateway.createGlobalObjectReference(classId: classId)
        XCTAssertThrowsError(
            try gateway.callInstance(
                objectId: objectId,
                methodId: staticMethod,
                arguments: [],
                returning: .void
            )
        ) { error in
            guard case .typeMismatch = error as? JNIGatewayError else {
                return XCTFail("expected typeMismatch, got \(error)")
            }
        }

        XCTAssertThrowsError(
            try gateway.callStatic(
                classId: classId,
                methodId: JNIMethodId(token: 123_456),
                arguments: [],
                returning: .void
            )
        ) { error in
            XCTAssertEqual(error as? JNIGatewayError, .invalidMethodHandle)
        }
    }

    func testTypeMismatchOnReturn() throws {
        let native = MockJNIGatewayNativeBackend()
        native.invokeHandler = { _ in .string("nope") }
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "x",
            signature: "()I",
            isStatic: true
        )

        XCTAssertThrowsError(
            try gateway.callStatic(
                classId: classId,
                methodId: methodId,
                arguments: [],
                returning: .int
            )
        ) { error in
            guard case .typeMismatch = error as? JNIGatewayError else {
                return XCTFail("expected typeMismatch, got \(error)")
            }
        }
    }

    func testInvalidObjectArgument() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let methodId = try gateway.resolveMethod(
            classId: classId,
            name: "accept",
            signature: "(Ljava/lang/Object;)V",
            isStatic: true
        )

        XCTAssertThrowsError(
            try gateway.callStatic(
                classId: classId,
                methodId: methodId,
                arguments: [.object(JNIObjectId(token: 7))],
                returning: .void
            )
        ) { error in
            XCTAssertEqual(error as? JNIGatewayError, .objectNotFound)
        }
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
