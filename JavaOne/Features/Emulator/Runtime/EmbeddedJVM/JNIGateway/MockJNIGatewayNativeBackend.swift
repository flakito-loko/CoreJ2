import Foundation

/// In-memory backend for unit tests (no real JNI). Simulates GlobalRef / MethodID / FieldID cache.
final class MockJNIGatewayNativeBackend: JNIGatewayNativeBackend, @unchecked Sendable {
    private let lock = NSLock()

    var shouldFailWith: JNIGatewayError?
    var invokeCount = 0
    private(set) var lastLocalFramesPushedStorage = 0
    private(set) var lastLocalFramesPoppedStorage = 0
    private(set) var lastCachedClassNativeId: UInt64?

    private var nextNativeId: UInt64 = 1
    private var classesByName: [String: UInt64] = [:]
    private var classNamesById: [UInt64: String] = [:]
    private var methods: [String: UInt64] = [:]
    private var fields: [String: UInt64] = [:]
    private var objectsById: [UInt64: UInt64] = [:] // objectNativeId → classNativeId

    private(set) var findClassInvocationCountStorage = 0
    private(set) var getMethodIDInvocationCountStorage = 0
    private(set) var getFieldIDInvocationCountStorage = 0
    private(set) var cacheFindClassCallCountStorage = 0
    private(set) var cacheGetMethodIDCallCountStorage = 0
    private(set) var cacheGetFieldIDCallCountStorage = 0
    private(set) var objectCreateCountStorage = 0
    private(set) var objectReleaseCountStorage = 0
    private(set) var genericInvokeCountStorage = 0
    private(set) var lastInvokeRequest: JNINativeInvokeRequest?
    private(set) var lastConstructorArgumentsStorage: [JNINativeArg] = []
    private(set) var constructorArgumentsHistoryStorage: [[JNINativeArg]] = []

    /// Optional override for generic `invoke` (unit tests).
    var invokeHandler: ((JNINativeInvokeRequest) throws -> JNINativeResult)?

    /// Arguments passed to the last `objectNewGlobal` (constructor) call.
    var lastConstructorArguments: [JNINativeArg] {
        lock.lock()
        defer { lock.unlock() }
        return lastConstructorArgumentsStorage
    }

    /// Every constructor argument list passed to `objectNewGlobal` (oldest first).
    var constructorArgumentsHistory: [[JNINativeArg]] {
        lock.lock()
        defer { lock.unlock() }
        return constructorArgumentsHistoryStorage
    }

    /// Every Swift → native `cacheFindClass` entry (proves Swift-layer hits skip native).
    var cacheFindClassCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cacheFindClassCallCountStorage
    }

    /// Every Swift → native `cacheGetMethodID` entry.
    var cacheGetMethodIDCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cacheGetMethodIDCallCountStorage
    }

    /// Every Swift → native `cacheGetFieldID` entry.
    var cacheGetFieldIDCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cacheGetFieldIDCallCountStorage
    }

    var lastLocalFramesPushed: Int {
        lock.lock()
        defer { lock.unlock() }
        return lastLocalFramesPushedStorage
    }

    var lastLocalFramesPopped: Int {
        lock.lock()
        defer { lock.unlock() }
        return lastLocalFramesPoppedStorage
    }

    var findClassInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return findClassInvocationCountStorage
    }

    var getMethodIDInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return getMethodIDInvocationCountStorage
    }

    var getFieldIDInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return getFieldIDInvocationCountStorage
    }

    var liveGlobalClassRefCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return classNamesById.count
    }

    var liveGlobalObjectRefCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return objectsById.count
    }

    var objectCreateCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return objectCreateCountStorage
    }

    var objectReleaseCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return objectReleaseCountStorage
    }

    var genericInvokeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return genericInvokeCountStorage
    }

    func invokeHelloWorldMain(cachedClassNativeId: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        lastCachedClassNativeId = cachedClassNativeId
        lastLocalFramesPushedStorage = 1
        guard classNamesById[cachedClassNativeId] != nil else {
            lastLocalFramesPoppedStorage = 1
            throw JNIGatewayError.classNotFound("<uncached>")
        }
        if let shouldFailWith {
            lastLocalFramesPoppedStorage = 1
            throw shouldFailWith
        }
        invokeCount += 1
        lastLocalFramesPoppedStorage = 1
    }

    func cacheFindClass(binaryName: String) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        cacheFindClassCallCountStorage += 1
        if let existing = classesByName[binaryName] {
            return existing
        }
        findClassInvocationCountStorage += 1
        let id = nextNativeId
        nextNativeId &+= 1
        classesByName[binaryName] = id
        classNamesById[id] = binaryName
        return id
    }

    func cacheGetMethodID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        cacheGetMethodIDCallCountStorage += 1
        guard classNamesById[classNativeId] != nil else {
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        let key = "\(classNativeId)|\(isStatic)|\(name)|\(signature)"
        if let existing = methods[key] {
            return existing
        }
        getMethodIDInvocationCountStorage += 1
        let id = nextNativeId
        nextNativeId &+= 1
        methods[key] = id
        return id
    }

    func cacheGetFieldID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        cacheGetFieldIDCallCountStorage += 1
        guard classNamesById[classNativeId] != nil else {
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        let key = "\(classNativeId)|f|\(isStatic)|\(name)|\(signature)"
        if let existing = fields[key] {
            return existing
        }
        getFieldIDInvocationCountStorage += 1
        let id = nextNativeId
        nextNativeId &+= 1
        fields[key] = id
        return id
    }

    func cacheClearAll() {
        lock.lock()
        classesByName.removeAll(keepingCapacity: false)
        classNamesById.removeAll(keepingCapacity: false)
        methods.removeAll(keepingCapacity: false)
        fields.removeAll(keepingCapacity: false)
        objectsById.removeAll(keepingCapacity: false)
        lastConstructorArgumentsStorage = []
        constructorArgumentsHistoryStorage.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    func objectCreateGlobal(classNativeId: UInt64) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard classNamesById[classNativeId] != nil else {
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        objectCreateCountStorage += 1
        let id = nextNativeId
        nextNativeId &+= 1
        objectsById[id] = classNativeId
        return id
    }

    func objectNewGlobal(
        classNativeId: UInt64,
        constructorMethodNativeId: UInt64,
        arguments: [JNINativeArg]
    ) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard classNamesById[classNativeId] != nil else {
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        guard methods.values.contains(constructorMethodNativeId) else {
            throw JNIGatewayError.invalidMethodHandle
        }
        lastConstructorArgumentsStorage = arguments
        constructorArgumentsHistoryStorage.append(arguments)
        objectCreateCountStorage += 1
        let id = nextNativeId
        nextNativeId &+= 1
        objectsById[id] = classNativeId
        return id
    }

    func objectReleaseGlobal(objectNativeId: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard objectsById.removeValue(forKey: objectNativeId) != nil else {
            return false
        }
        objectReleaseCountStorage += 1
        return true
    }

    func objectContains(objectNativeId: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return objectsById[objectNativeId] != nil
    }

    func invoke(_ request: JNINativeInvokeRequest) throws -> JNINativeResult {
        lock.lock()
        lastInvokeRequest = request
        genericInvokeCountStorage += 1
        lastLocalFramesPushedStorage = 1
        guard classNamesById[request.classNativeId] != nil else {
            lastLocalFramesPoppedStorage = 1
            lock.unlock()
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        if !request.isStatic {
            guard let receiver = request.receiverObjectNativeId,
                  objectsById[receiver] != nil else {
                lastLocalFramesPoppedStorage = 1
                lock.unlock()
                throw JNIGatewayError.objectNotFound
            }
        }
        for argument in request.arguments {
            if case .object(let nativeId) = argument, objectsById[nativeId] == nil {
                lastLocalFramesPoppedStorage = 1
                lock.unlock()
                throw JNIGatewayError.objectNotFound
            }
        }
        if let shouldFailWith {
            lastLocalFramesPoppedStorage = 1
            lock.unlock()
            throw shouldFailWith
        }
        let handler = invokeHandler
        lock.unlock()

        // Invoke outside the mock lock so handlers may call `simulateNativeCallback`
        // (Java→native re-entry) without deadlocking — mirrors DefaultJNIGateway.
        let result: JNINativeResult
        if let handler {
            result = try handler(request)
        } else {
            result = defaultResult(for: request.returnKind, classNativeId: request.classNativeId)
        }

        lock.lock()
        lastLocalFramesPoppedStorage = 1
        if case .object(let nativeId) = result {
            objectsById[nativeId] = request.classNativeId
        }
        lock.unlock()
        return result
    }

    private func defaultResult(for kind: JNIReturnKind, classNativeId: UInt64) -> JNINativeResult {
        switch kind {
        case .void:
            return .void
        case .boolean:
            return .boolean(false)
        case .int:
            return .int(0)
        case .long:
            return .long(0)
        case .float:
            return .float(0)
        case .double:
            return .double(0)
        case .string:
            return .string("")
        case .object:
            let id = nextNativeId
            nextNativeId &+= 1
            objectsById[id] = classNativeId
            return .object(nativeId: id)
        }
    }

    // MARK: - Native callbacks

    private struct NativeRegistration {
        let classNativeId: UInt64
        let methodName: String
        let signature: String
        let isStatic: Bool
    }

    private var nativeRegistrations: [UInt64: NativeRegistration] = [:]
    private(set) var registerNativeCallCountStorage = 0
    private(set) var unregisterNativeCallCountStorage = 0
    private(set) var registrationTokensInOrderStorage: [UInt64] = []

    var registerNativeCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return registerNativeCallCountStorage
    }

    var unregisterNativeCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return unregisterNativeCallCountStorage
    }

    var liveNativeRegistrationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return nativeRegistrations.count
    }

    var registrationTokensInOrder: [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return registrationTokensInOrderStorage
    }

    func registerNativeMethod(
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool,
        registrationToken: UInt64
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard classNamesById[classNativeId] != nil else {
            throw JNIGatewayError.classNotFound("<invalid-native-class>")
        }
        registerNativeCallCountStorage += 1
        nativeRegistrations[registrationToken] = NativeRegistration(
            classNativeId: classNativeId,
            methodName: methodName,
            signature: signature,
            isStatic: isStatic
        )
        registrationTokensInOrderStorage.append(registrationToken)
    }

    func unregisterNativeMethod(registrationToken: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        guard nativeRegistrations.removeValue(forKey: registrationToken) != nil else {
            throw JNIGatewayError.nativeRegistrationNotFound
        }
        unregisterNativeCallCountStorage += 1
        registrationTokensInOrderStorage.removeAll { $0 == registrationToken }
    }

    func unregisterAllNativeMethods() {
        lock.lock()
        nativeRegistrations.removeAll(keepingCapacity: false)
        registrationTokensInOrderStorage.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    func simulateNativeCallback(
        registrationToken: UInt64,
        arguments: [JNINativeArg]
    ) -> JNINativeResult {
        lock.lock()
        let exists = nativeRegistrations[registrationToken] != nil
        lock.unlock()
        guard exists else {
            return .void
        }
        return JNIGatewayTrampolineHost.dispatch(
            token: registrationToken,
            arguments: arguments
        )
    }
}
