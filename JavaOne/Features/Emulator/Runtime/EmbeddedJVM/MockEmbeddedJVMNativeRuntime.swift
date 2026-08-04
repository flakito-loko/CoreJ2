import Foundation

/// In-memory native stub for state-machine tests (no real JVM).
public final class MockEmbeddedJVMNativeRuntime: EmbeddedJVMNativeRuntime, @unchecked Sendable {
    private let lock = NSLock()
    private var created = false
    public var createShouldFail = false
    public var helloShouldFail = false
    public var destroyShouldFail = false
    public private(set) var createCount = 0
    public private(set) var helloCount = 0
    public private(set) var destroyCount = 0

    public init() {}

    public var isJVMCreated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return created
    }

    public func createJVM(javaHomePath: String, classpath: String) throws {
        _ = javaHomePath
        _ = classpath
        lock.lock()
        defer { lock.unlock() }
        if created { throw EmbeddedJVMError.secondJVMRejected }
        if createShouldFail { throw EmbeddedJVMError.nativeCreateFailed(1) }
        created = true
        createCount += 1
    }

    public func runHelloWorld(mainClassJNI: String) throws {
        _ = mainClassJNI
        lock.lock()
        defer { lock.unlock() }
        guard created else { throw EmbeddedJVMError.notReady }
        if helloShouldFail { throw EmbeddedJVMError.nativeHelloFailed(1) }
        helloCount += 1
    }

    public func destroyJVM() throws {
        lock.lock()
        defer { lock.unlock() }
        guard created else { return }
        if destroyShouldFail { throw EmbeddedJVMError.nativeDestroyFailed(1) }
        created = false
        destroyCount += 1
    }
}
