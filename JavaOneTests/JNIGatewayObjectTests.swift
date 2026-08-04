import XCTest
@testable import JavaOne

/// E2-US003 — Java object GlobalRef handles.
final class JNIGatewayObjectTests: XCTestCase {

    private let helloClass = "org/javaone/embedded/spike/HelloWorld"

    // MARK: - Creation / lookup

    func testObjectCreationReturnsOpaqueHandle() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        let objectId = try gateway.createGlobalObjectReference(classId: classId)

        XCTAssertGreaterThan(objectId.token, 0)
        XCTAssertTrue(gateway.containsObject(objectId))
        XCTAssertEqual(gateway.retainedObjectCount, 1)
        XCTAssertEqual(native.liveGlobalObjectRefCount, 1)
        XCTAssertEqual(native.objectCreateCount, 1)
        XCTAssertFalse(String(describing: JNIObjectId.self).contains("jobject"))
    }

    func testConstructedObjectPassesConstructorArguments() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let ctor = try gateway.resolveMethod(
            classId: classId,
            name: "<init>",
            signature: "(II)V",
            isStatic: false
        )

        let objectId = try gateway.createGlobalObjectReference(
            classId: classId,
            constructorMethodId: ctor,
            arguments: [.int(240), .int(320)]
        )

        XCTAssertTrue(gateway.containsObject(objectId))
        XCTAssertEqual(native.objectCreateCount, 1)
        XCTAssertEqual(native.lastConstructorArguments, [.int(240), .int(320)])
    }

    func testObjectLookupReflectsOwnership() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let objectId = try gateway.createGlobalObjectReference(classId: classId)
        let unknown = JNIObjectId(token: 9_999_999)

        XCTAssertTrue(gateway.containsObject(objectId))
        XCTAssertFalse(gateway.containsObject(unknown))
    }

    // MARK: - Release

    func testObjectReleaseDropsGlobalRef() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let objectId = try gateway.createGlobalObjectReference(classId: classId)

        try gateway.releaseObjectReference(objectId)

        XCTAssertFalse(gateway.containsObject(objectId))
        XCTAssertEqual(gateway.retainedObjectCount, 0)
        XCTAssertEqual(native.liveGlobalObjectRefCount, 0)
        XCTAssertEqual(native.objectReleaseCount, 1)
    }

    func testDoubleReleaseFails() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let objectId = try gateway.createGlobalObjectReference(classId: classId)

        try gateway.releaseObjectReference(objectId)

        XCTAssertThrowsError(try gateway.releaseObjectReference(objectId)) { error in
            XCTAssertEqual(error as? JNIGatewayError, .objectAlreadyReleased)
        }
        XCTAssertEqual(native.objectReleaseCount, 1)
        XCTAssertEqual(native.liveGlobalObjectRefCount, 0)
    }

    func testReleaseUnknownObjectFails() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        try gateway.bind()

        XCTAssertThrowsError(
            try gateway.releaseObjectReference(JNIObjectId(token: 42))
        ) { error in
            XCTAssertEqual(error as? JNIGatewayError, .objectNotFound)
        }
    }

    // MARK: - Invalidate / shutdown

    func testInvalidateReleasesEveryObject() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        let a = try gateway.createGlobalObjectReference(classId: classId)
        let b = try gateway.createGlobalObjectReference(classId: classId)

        XCTAssertEqual(native.liveGlobalObjectRefCount, 2)

        gateway.invalidate()

        XCTAssertEqual(native.liveGlobalObjectRefCount, 0)
        XCTAssertEqual(gateway.retainedObjectCount, 0)
        XCTAssertFalse(gateway.containsObject(a))
        XCTAssertFalse(gateway.containsObject(b))
        XCTAssertFalse(gateway.isUsable)
    }

    func testShutdownCleanupAllowsFreshObjectsAfterRebind() throws {
        let native = MockJNIGatewayNativeBackend()
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        let classId = try gateway.resolveClass(binaryName: helloClass)
        _ = try gateway.createGlobalObjectReference(classId: classId)
        XCTAssertEqual(native.liveGlobalObjectRefCount, 1)

        gateway.invalidate()
        XCTAssertEqual(native.liveGlobalObjectRefCount, 0)

        try gateway.bind()
        let classId2 = try gateway.resolveClass(binaryName: helloClass)
        let again = try gateway.createGlobalObjectReference(classId: classId2)
        XCTAssertTrue(gateway.containsObject(again))
        XCTAssertEqual(native.liveGlobalObjectRefCount, 1)
        XCTAssertEqual(gateway.retainedObjectCount, 1)
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
