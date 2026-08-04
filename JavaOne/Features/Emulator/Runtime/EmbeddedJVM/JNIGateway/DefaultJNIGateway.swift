import Foundation

/// Default production `JNIGateway`.
///
/// Verifies JVM readiness via `EmbeddedJVMReadiness`, owns `JNIGatewayReferenceCache`,
/// and performs JNI only through `JNIGatewayNativeBackend`.
final class DefaultJNIGateway: JNIGateway, @unchecked Sendable {

    // MARK: - Constants

    private enum HelloWorldDefaults {
        static let classJNIName = "org/javaone/embedded/spike/HelloWorld"
        static let mainName = "main"
        static let mainSignature = "([Ljava/lang/String;)V"
    }

    // MARK: - Properties

    private let lock = NSLock()
    private let readiness: any EmbeddedJVMReadiness
    private let native: any JNIGatewayNativeBackend
    private let callQueue: DispatchQueue
    private let cache: JNIGatewayReferenceCache
    private let callbacks = JNIGatewayCallbackRegistry()

    private var bound = false
    private var invalidated = false

    // MARK: - Init

    init(
        readiness: any EmbeddedJVMReadiness,
        native: any JNIGatewayNativeBackend,
        callQueue: DispatchQueue = DispatchQueue(label: "JavaOne.JNIGateway", qos: .userInitiated)
    ) {
        self.readiness = readiness
        self.native = native
        self.callQueue = callQueue
        self.cache = JNIGatewayReferenceCache(native: native)
    }

    // MARK: - Diagnostics (tests)

    var cachedClassCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.cachedClassCount
    }

    var cachedMethodCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.cachedMethodCount
    }

    var cachedFieldCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.cachedFieldCount
    }

    var retainedObjectCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.retainedObjectCount
    }

    var nativeRegistrationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callbacks.registrationCount
    }

    var callbackDispatchSequence: [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return callbacks.dispatchSequence
    }

    // MARK: - JNIGateway

    var isUsable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isUsableLocked()
    }

    func bind() throws {
        lock.lock()
        defer { lock.unlock() }
        let state = readiness.state
        guard Self.isJNIAllowed(state) else {
            throw JNIGatewayError.jvmNotReady(state)
        }
        invalidated = false
        bound = true
        JNIGatewayTrampolineHost.install(self)
    }

    func invalidate() {
        lock.lock()
        bound = false
        invalidated = true
        _ = callbacks.removeAll()
        native.unregisterAllNativeMethods()
        cache.invalidate()
        JNIGatewayTrampolineHost.clear(self)
        lock.unlock()
    }

    func resolveClass(binaryName: String) throws -> JNIClassId {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try cache.resolveClass(binaryName: binaryName)
    }

    func resolveMethod(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIMethodId {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try cache.resolveMethod(
            classId: classId,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
    }

    func resolveField(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIFieldId {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try cache.resolveField(
            classId: classId,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
    }

    func createGlobalObjectReference(classId: JNIClassId) throws -> JNIObjectId {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try cache.createObject(classId: classId)
    }

    func createGlobalObjectReference(
        classId: JNIClassId,
        constructorMethodId: JNIMethodId,
        arguments: [JNIValue]
    ) throws -> JNIObjectId {
        // Unlock before NewObject so constructor-side natives can re-enter the trampoline.
        let classNativeId: UInt64
        let methodNativeId: UInt64
        let classToken: UInt64
        let nativeArgs: [JNINativeArg]
        lock.lock()
        do {
            try ensureUsableLocked()
            guard let classRecord = cache.classRecord(for: classId) else {
                throw JNIGatewayError.classNotFound("<invalid-class-id>")
            }
            guard let methodRecord = cache.methodRecord(for: constructorMethodId) else {
                throw JNIGatewayError.invalidMethodHandle
            }
            guard methodRecord.classToken == classId.token, !methodRecord.isStatic else {
                throw JNIGatewayError.invalidMethodHandle
            }
            classNativeId = classRecord.nativeId
            methodNativeId = methodRecord.nativeId
            classToken = classId.token
            nativeArgs = try arguments.map { try encodeArgument($0) }
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        let nativeObjectId = try native.objectNewGlobal(
            classNativeId: classNativeId,
            constructorMethodNativeId: methodNativeId,
            arguments: nativeArgs
        )

        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return cache.adoptObject(nativeId: nativeObjectId, classToken: classToken)
    }

    func releaseObjectReference(_ objectId: JNIObjectId) throws {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        try cache.releaseObject(objectId)
    }

    func containsObject(_ objectId: JNIObjectId) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache.containsObject(objectId)
    }

    func callStatic(
        classId: JNIClassId,
        methodId: JNIMethodId,
        arguments: [JNIValue],
        returning: JNIReturnKind
    ) throws -> JNIValue {
        // Unlock before native.invoke so Java→native trampolines can re-enter
        // `dispatchNativeCallback` without deadlocking on `lock`.
        let request: JNINativeInvokeRequest
        let classToken: UInt64
        lock.lock()
        do {
            try ensureUsableLocked()
            let prepared = try prepareCall(
                classId: classId,
                objectId: nil,
                methodId: methodId,
                arguments: arguments,
                returning: returning,
                requireStatic: true
            )
            request = prepared.request
            classToken = prepared.classToken
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        let nativeResult = try native.invoke(request)

        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try decodeResult(nativeResult, expected: returning, classToken: classToken)
    }

    func callInstance(
        objectId: JNIObjectId,
        methodId: JNIMethodId,
        arguments: [JNIValue],
        returning: JNIReturnKind
    ) throws -> JNIValue {
        let request: JNINativeInvokeRequest
        let classToken: UInt64
        lock.lock()
        do {
            try ensureUsableLocked()
            guard let methodRecord = cache.methodRecord(for: methodId) else {
                throw JNIGatewayError.invalidMethodHandle
            }
            guard cache.objectRecord(for: objectId) != nil else {
                throw JNIGatewayError.objectNotFound
            }
            let classId = JNIClassId(token: methodRecord.classToken)
            let prepared = try prepareCall(
                classId: classId,
                objectId: objectId,
                methodId: methodId,
                arguments: arguments,
                returning: returning,
                requireStatic: false
            )
            request = prepared.request
            classToken = prepared.classToken
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        let nativeResult = try native.invoke(request)

        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        return try decodeResult(nativeResult, expected: returning, classToken: classToken)
    }

    func registerNative(
        classId: JNIClassId,
        methodName: String,
        signature: String,
        isStatic: Bool,
        handler: @escaping JNINativeCallbackHandler
    ) throws -> JNINativeRegistrationId {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        guard let classRecord = cache.classRecord(for: classId) else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        let registrationId = try callbacks.register(
            classToken: classId.token,
            classNativeId: classRecord.nativeId,
            methodName: methodName,
            signature: signature,
            isStatic: isStatic,
            handler: handler
        )
        do {
            try native.registerNativeMethod(
                classNativeId: classRecord.nativeId,
                methodName: methodName,
                signature: signature,
                isStatic: isStatic,
                registrationToken: registrationId.token
            )
        } catch {
            _ = try? callbacks.unregister(registrationId)
            throw error
        }
        return registrationId
    }

    func unregisterNative(_ registrationId: JNINativeRegistrationId) throws {
        lock.lock()
        defer { lock.unlock() }
        try ensureUsableLocked()
        guard callbacks.entry(for: registrationId) != nil else {
            throw JNIGatewayError.nativeRegistrationNotFound
        }
        try native.unregisterNativeMethod(registrationToken: registrationId.token)
        _ = try callbacks.unregister(registrationId)
    }

    func invokeHelloWorldMain() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            callQueue.async {
                do {
                    try self.invokeHelloWorldMainSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    /// Trampoline entry: validates usability, copies args into opaque handles, invokes handler.
    func dispatchNativeCallback(token: UInt64, arguments: [JNINativeArg]) -> JNINativeResult {
        lock.lock()
        guard isUsableLocked() else {
            lock.unlock()
            return .void
        }
        let prepared: JNIGatewayCallbackRegistry.PreparedDispatch
        do {
            prepared = try callbacks.prepareDispatch(
                token: token,
                nativeArguments: arguments,
                adoptObject: { nativeId in
                    self.cache.adoptObject(nativeId: nativeId, classToken: 0)
                }
            )
        } catch {
            lock.unlock()
            return .void
        }
        lock.unlock()

        let value = prepared.handler(prepared.event)

        lock.lock()
        defer { lock.unlock() }
        guard isUsableLocked() else {
            return .void
        }
        return encodeHandlerResult(value)
    }

    private func encodeHandlerResult(_ value: JNIValue) -> JNINativeResult {
        switch value {
        case .void:
            return .void
        case .boolean(let flag):
            return .boolean(flag)
        case .int(let number):
            return .int(number)
        case .long(let number):
            return .long(number)
        case .float(let number):
            return .float(number)
        case .double(let number):
            return .double(number)
        case .string(let text):
            return .string(text)
        case .object(let objectId):
            if let record = cache.objectRecord(for: objectId) {
                return .object(nativeId: record.nativeId)
            }
            return .null
        case .null:
            return .null
        }
    }

    private struct PreparedCall {
        let request: JNINativeInvokeRequest
        let classToken: UInt64
    }

    /// Builds an invoke request while `lock` is held. Does not call into JNI.
    private func prepareCall(
        classId: JNIClassId,
        objectId: JNIObjectId?,
        methodId: JNIMethodId,
        arguments: [JNIValue],
        returning: JNIReturnKind,
        requireStatic: Bool
    ) throws -> PreparedCall {
        guard let classRecord = cache.classRecord(for: classId) else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        guard let methodRecord = cache.methodRecord(for: methodId) else {
            throw JNIGatewayError.invalidMethodHandle
        }
        if methodRecord.isStatic != requireStatic {
            throw JNIGatewayError.typeMismatch(
                expected: requireStatic ? "static method" : "instance method",
                actual: methodRecord.isStatic ? "static method" : "instance method"
            )
        }
        if methodRecord.classToken != classId.token, requireStatic {
            throw JNIGatewayError.invalidMethodHandle
        }

        let receiverNativeId: UInt64?
        if requireStatic {
            receiverNativeId = nil
        } else {
            guard let objectId, let objectRecord = cache.objectRecord(for: objectId) else {
                throw JNIGatewayError.objectNotFound
            }
            receiverNativeId = objectRecord.nativeId
        }

        let nativeArgs = try arguments.map { try encodeArgument($0) }
        let request = JNINativeInvokeRequest(
            classNativeId: classRecord.nativeId,
            methodNativeId: methodRecord.nativeId,
            isStatic: requireStatic,
            receiverObjectNativeId: receiverNativeId,
            arguments: nativeArgs,
            returnKind: returning
        )
        return PreparedCall(request: request, classToken: classId.token)
    }

    private func encodeArgument(_ value: JNIValue) throws -> JNINativeArg {
        switch value {
        case .void:
            throw JNIGatewayError.typeMismatch(expected: "argument value", actual: "void")
        case .boolean(let flag):
            return .boolean(flag)
        case .int(let number):
            return .int(number)
        case .long(let number):
            return .long(number)
        case .float(let number):
            return .float(number)
        case .double(let number):
            return .double(number)
        case .string(let text):
            return .string(text)
        case .object(let objectId):
            guard let record = cache.objectRecord(for: objectId) else {
                throw JNIGatewayError.objectNotFound
            }
            return .object(record.nativeId)
        case .null:
            return .null
        }
    }

    private func decodeResult(
        _ result: JNINativeResult,
        expected: JNIReturnKind,
        classToken: UInt64
    ) throws -> JNIValue {
        switch (expected, result) {
        case (.void, .void):
            return .void
        case (.boolean, .boolean(let flag)):
            return .boolean(flag)
        case (.int, .int(let number)):
            return .int(number)
        case (.long, .long(let number)):
            return .long(number)
        case (.float, .float(let number)):
            return .float(number)
        case (.double, .double(let number)):
            return .double(number)
        case (.string, .string(let text)):
            return .string(text)
        case (.string, .null):
            return .null
        case (.object, .object(let nativeId)):
            return .object(cache.adoptObject(nativeId: nativeId, classToken: classToken))
        case (.object, .null):
            return .null
        default:
            throw JNIGatewayError.typeMismatch(
                expected: String(describing: expected),
                actual: String(describing: result)
            )
        }
    }

    private func invokeHelloWorldMainSync() throws {
        let nativeClassId: UInt64
        lock.lock()
        do {
            try ensureUsableLocked()
            let classId = try cache.resolveClass(binaryName: HelloWorldDefaults.classJNIName)
            _ = try cache.resolveMethod(
                classId: classId,
                name: HelloWorldDefaults.mainName,
                signature: HelloWorldDefaults.mainSignature,
                isStatic: true
            )
            guard let record = cache.classRecord(for: classId) else {
                throw JNIGatewayError.classNotFound(HelloWorldDefaults.classJNIName)
            }
            nativeClassId = record.nativeId
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        try native.invokeHelloWorldMain(cachedClassNativeId: nativeClassId)
    }

    private func isUsableLocked() -> Bool {
        bound && !invalidated && Self.isJNIAllowed(readiness.state)
    }

    private func ensureUsableLocked() throws {
        if invalidated || !bound {
            throw JNIGatewayError.gatewayInvalidated
        }
        let state = readiness.state
        guard Self.isJNIAllowed(state) else {
            throw JNIGatewayError.jvmNotReady(state)
        }
    }

    private static func isJNIAllowed(_ state: EmbeddedJVMState) -> Bool {
        switch state {
        case .ready:
            return true
        case .notInitialized, .starting, .shutdown, .destroyed, .failed:
            return false
        }
    }
}
