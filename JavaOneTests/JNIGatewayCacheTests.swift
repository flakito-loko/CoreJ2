import XCTest
@testable import JavaOne

/// E2-US002 — Global reference / MethodID / FieldID cache.
final class JNIGatewayCacheTests: XCTestCase {

    private let helloClass = "org/javaone/embedded/spike/HelloWorld"
    private let otherClass = "java/lang/String"

    // MARK: - Class cache

    func testClassCacheMissPerformsFindClassOnce() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)

        let id = try gateway.resolveClass(binaryName: helloClass)

        XCTAssertGreaterThan(id.token, 0)
        XCTAssertEqual(native.findClassInvocationCount, 1)
        XCTAssertEqual(native.cacheFindClassCallCount, 1)
        XCTAssertEqual(gateway.cachedClassCount, 1)
        XCTAssertEqual(native.liveGlobalClassRefCount, 1)
    }

    func testClassCacheHitSkipsFindClassAndReturnsSameHandle() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)

        let first = try gateway.resolveClass(binaryName: helloClass)
        let second = try gateway.resolveClass(binaryName: helloClass)

        XCTAssertEqual(first, second)
        XCTAssertEqual(native.findClassInvocationCount, 1)
        XCTAssertEqual(native.cacheFindClassCallCount, 1)
        XCTAssertEqual(gateway.cachedClassCount, 1)
        XCTAssertEqual(native.liveGlobalClassRefCount, 1)
    }

    func testDuplicateResolutionAcrossDistinctClasses() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)

        let a = try gateway.resolveClass(binaryName: helloClass)
        let b = try gateway.resolveClass(binaryName: otherClass)
        let a2 = try gateway.resolveClass(binaryName: helloClass)

        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, a2)
        XCTAssertEqual(native.findClassInvocationCount, 2)
        XCTAssertEqual(native.cacheFindClassCallCount, 2)
        XCTAssertEqual(gateway.cachedClassCount, 2)
        XCTAssertEqual(native.liveGlobalClassRefCount, 2)
    }

    // MARK: - Method cache

    func testMethodCacheHitSkipsJNILookup() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        let first = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "([Ljava/lang/String;)V",
            isStatic: true
        )
        let second = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "([Ljava/lang/String;)V",
            isStatic: true
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(native.getMethodIDInvocationCount, 1)
        XCTAssertEqual(native.cacheGetMethodIDCallCount, 1)
        XCTAssertEqual(gateway.cachedMethodCount, 1)
    }

    // MARK: - Field foundation

    func testFieldResolutionIsCached() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)

        let first = try gateway.resolveField(
            classId: classId,
            name: "completed",
            signature: "Z",
            isStatic: true
        )
        let second = try gateway.resolveField(
            classId: classId,
            name: "completed",
            signature: "Z",
            isStatic: true
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(native.getFieldIDInvocationCount, 1)
        XCTAssertEqual(native.cacheGetFieldIDCallCount, 1)
        XCTAssertEqual(gateway.cachedFieldCount, 1)
    }

    // MARK: - Invalidation / shutdown cleanup

    func testInvalidateReleasesEveryGlobalRefAndClearsTables() throws {
        let native = MockJNIGatewayNativeBackend()
        let gateway = makeBoundGateway(native: native)
        let classId = try gateway.resolveClass(binaryName: helloClass)
        _ = try gateway.resolveMethod(
            classId: classId,
            name: "main",
            signature: "([Ljava/lang/String;)V",
            isStatic: true
        )
        _ = try gateway.resolveField(
            classId: classId,
            name: "completed",
            signature: "Z",
            isStatic: true
        )

        XCTAssertEqual(native.liveGlobalClassRefCount, 1)
        XCTAssertGreaterThan(gateway.cachedClassCount, 0)

        gateway.invalidate()

        XCTAssertEqual(native.liveGlobalClassRefCount, 0)
        XCTAssertEqual(gateway.cachedClassCount, 0)
        XCTAssertEqual(gateway.cachedMethodCount, 0)
        XCTAssertEqual(gateway.cachedFieldCount, 0)
        XCTAssertFalse(gateway.isUsable)
    }

    func testShutdownCleanupAllowsRebindWithFreshCache() throws {
        let native = MockJNIGatewayNativeBackend()
        let readiness = StubEmbeddedJVMReadiness(state: .ready)
        let gateway = DefaultJNIGateway(readiness: readiness, native: native)

        try gateway.bind()
        _ = try gateway.resolveClass(binaryName: helloClass)
        XCTAssertEqual(native.findClassInvocationCount, 1)
        gateway.invalidate()
        XCTAssertEqual(native.liveGlobalClassRefCount, 0)

        try gateway.bind()
        let again = try gateway.resolveClass(binaryName: helloClass)
        XCTAssertGreaterThan(again.token, 0)
        XCTAssertEqual(native.findClassInvocationCount, 2)
        XCTAssertEqual(native.liveGlobalClassRefCount, 1)
        XCTAssertEqual(native.cacheFindClassCallCount, 2)
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
