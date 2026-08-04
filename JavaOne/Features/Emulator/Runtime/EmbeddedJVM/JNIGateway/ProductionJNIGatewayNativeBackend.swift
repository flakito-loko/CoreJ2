import Foundation

#if canImport(Darwin)

@_silgen_name("javaone_jni_gateway_invoke_hello_world_main_cached")
func javaone_jni_gateway_invoke_hello_world_main_cached(
    _ classNativeId: UInt64,
    _ outFramesPushed: UnsafeMutablePointer<Int32>?,
    _ outFramesPopped: UnsafeMutablePointer<Int32>?,
    _ outExceptionType: UnsafeMutablePointer<CChar>?,
    _ outExceptionTypeLen: Int32,
    _ outExceptionMessage: UnsafeMutablePointer<CChar>?,
    _ outExceptionMessageLen: Int32
) -> Int32

@_silgen_name("javaone_jni_gateway_cache_find_class")
func javaone_jni_gateway_cache_find_class(
    _ binaryName: UnsafePointer<CChar>?,
    _ outId: UnsafeMutablePointer<UInt64>?
) -> Int32

@_silgen_name("javaone_jni_gateway_cache_get_method")
func javaone_jni_gateway_cache_get_method(
    _ classId: UInt64,
    _ name: UnsafePointer<CChar>?,
    _ signature: UnsafePointer<CChar>?,
    _ isStatic: Int32,
    _ outId: UnsafeMutablePointer<UInt64>?
) -> Int32

@_silgen_name("javaone_jni_gateway_cache_get_field")
func javaone_jni_gateway_cache_get_field(
    _ classId: UInt64,
    _ name: UnsafePointer<CChar>?,
    _ signature: UnsafePointer<CChar>?,
    _ isStatic: Int32,
    _ outId: UnsafeMutablePointer<UInt64>?
) -> Int32

@_silgen_name("javaone_jni_gateway_cache_clear_all")
func javaone_jni_gateway_cache_clear_all()

@_silgen_name("javaone_jni_gateway_cache_find_class_count")
func javaone_jni_gateway_cache_find_class_count() -> Int32

@_silgen_name("javaone_jni_gateway_cache_get_method_count")
func javaone_jni_gateway_cache_get_method_count() -> Int32

@_silgen_name("javaone_jni_gateway_cache_get_field_count")
func javaone_jni_gateway_cache_get_field_count() -> Int32

@_silgen_name("javaone_jni_gateway_cache_live_global_class_count")
func javaone_jni_gateway_cache_live_global_class_count() -> Int32

@_silgen_name("javaone_jni_gateway_cache_live_global_object_count")
func javaone_jni_gateway_cache_live_global_object_count() -> Int32

@_silgen_name("javaone_jni_gateway_object_create_global")
func javaone_jni_gateway_object_create_global(
    _ classId: UInt64,
    _ outId: UnsafeMutablePointer<UInt64>?
) -> Int32

@_silgen_name("javaone_jni_gateway_object_release_global")
func javaone_jni_gateway_object_release_global(_ objectId: UInt64) -> Int32

@_silgen_name("javaone_jni_gateway_object_contains")
func javaone_jni_gateway_object_contains(_ objectId: UInt64) -> Int32

@_silgen_name("javaone_jni_gateway_register_native")
func javaone_jni_gateway_register_native(
    _ classId: UInt64,
    _ methodName: UnsafePointer<CChar>?,
    _ signature: UnsafePointer<CChar>?,
    _ isStatic: Int32,
    _ token: UInt64
) -> Int32

@_silgen_name("javaone_jni_gateway_unregister_native")
func javaone_jni_gateway_unregister_native(_ token: UInt64) -> Int32

@_silgen_name("javaone_jni_gateway_unregister_all_natives")
func javaone_jni_gateway_unregister_all_natives()

/// C trampoline → Swift host. No `JNIEnv` / `jobject` parameters.
/// Args/out are `javaone_jgw_value` buffers (raw to keep `@_cdecl` ABI-safe).
@_cdecl("javaone_jni_gateway_trampoline_dispatch")
func javaone_jni_gateway_trampoline_dispatch(
    _ token: UInt64,
    _ args: UnsafeRawPointer?,
    _ argc: Int32,
    _ outResult: UnsafeMutableRawPointer?
) {
    var nativeArgs: [JNINativeArg] = []
    if let args, argc > 0 {
        let typed = args.assumingMemoryBound(to: JavaOneJgwValue.self)
        for index in 0..<Int(argc) {
            let value = typed[index]
            switch value.kind {
            case 1:
                nativeArgs.append(.boolean(value.i32 != 0))
            case 2:
                nativeArgs.append(.int(value.i32))
            case 3:
                nativeArgs.append(.long(value.i64))
            case 4:
                nativeArgs.append(.float(value.f32))
            case 5:
                nativeArgs.append(.double(value.f64))
            case 6:
                if let str = value.str {
                    nativeArgs.append(.string(String(cString: str)))
                } else {
                    nativeArgs.append(.null)
                }
            case 7:
                nativeArgs.append(.object(value.object_id))
            case 8:
                nativeArgs.append(.null)
            default:
                break
            }
        }
    }
    let result = JNIGatewayTrampolineHost.dispatch(token: token, arguments: nativeArgs)
    guard let outResult else { return }
    let out = outResult.assumingMemoryBound(to: JavaOneJgwValue.self)
    out.pointee = JavaOneJgwValue()
    switch result {
    case .void:
        out.pointee.kind = 0
    case .boolean(let flag):
        out.pointee.kind = 1
        out.pointee.i32 = flag ? 1 : 0
    case .int(let number):
        out.pointee.kind = 2
        out.pointee.i32 = number
    case .long(let number):
        out.pointee.kind = 3
        out.pointee.i64 = number
    case .float(let number):
        out.pointee.kind = 4
        out.pointee.f32 = number
    case .double(let number):
        out.pointee.kind = 5
        out.pointee.f64 = number
    case .string:
        out.pointee.kind = 6
    case .object(let nativeId):
        out.pointee.kind = 7
        out.pointee.object_id = nativeId
    case .null:
        out.pointee.kind = 8
    }
}

struct JavaOneJgwValue {
    var kind: Int32 = 0
    var i32: Int32 = 0
    var i64: Int64 = 0
    var f32: Float = 0
    var f64: Double = 0
    var str: UnsafePointer<CChar>?
    var object_id: UInt64 = 0
}

@_silgen_name("javaone_jni_gateway_object_new_global")
func javaone_jni_gateway_object_new_global(
    _ classId: UInt64,
    _ constructorMethodId: UInt64,
    _ args: UnsafePointer<JavaOneJgwValue>?,
    _ argc: Int32,
    _ outId: UnsafeMutablePointer<UInt64>?
) -> Int32

@_silgen_name("javaone_jni_gateway_call")
func javaone_jni_gateway_call(
    _ classId: UInt64,
    _ methodId: UInt64,
    _ isStatic: Int32,
    _ receiverObjectId: UInt64,
    _ args: UnsafePointer<JavaOneJgwValue>?,
    _ argc: Int32,
    _ returnKind: Int32,
    _ outResult: UnsafeMutablePointer<JavaOneJgwValue>?,
    _ outString: UnsafeMutablePointer<CChar>?,
    _ outStringLen: Int32,
    _ outFramesPushed: UnsafeMutablePointer<Int32>?,
    _ outFramesPopped: UnsafeMutablePointer<Int32>?,
    _ outExceptionType: UnsafeMutablePointer<CChar>?,
    _ outExceptionTypeLen: Int32,
    _ outExceptionMessage: UnsafeMutablePointer<CChar>?,
    _ outExceptionMessageLen: Int32
) -> Int32

/// Production backend: GlobalRef / MethodID / FieldID / Object cache + HelloWorld invoke.
///
/// Requires the Embedded JVM process image already created (`javaone_embedded_jvm_create`).
/// Does not create or destroy the JVM.
final class ProductionJNIGatewayNativeBackend: JNIGatewayNativeBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var pushed = 0
    private var popped = 0

    init() {}

    var lastLocalFramesPushed: Int {
        lock.lock()
        defer { lock.unlock() }
        return pushed
    }

    var lastLocalFramesPopped: Int {
        lock.lock()
        defer { lock.unlock() }
        return popped
    }

    var findClassInvocationCount: Int {
        Int(javaone_jni_gateway_cache_find_class_count())
    }

    var getMethodIDInvocationCount: Int {
        Int(javaone_jni_gateway_cache_get_method_count())
    }

    var getFieldIDInvocationCount: Int {
        Int(javaone_jni_gateway_cache_get_field_count())
    }

    var liveGlobalClassRefCount: Int {
        Int(javaone_jni_gateway_cache_live_global_class_count())
    }

    var liveGlobalObjectRefCount: Int {
        Int(javaone_jni_gateway_cache_live_global_object_count())
    }

    func invokeHelloWorldMain(cachedClassNativeId: UInt64) throws {
        var pushedOut: Int32 = 0
        var poppedOut: Int32 = 0
        var excType = [CChar](repeating: 0, count: 256)
        var excMessage = [CChar](repeating: 0, count: 512)

        let code: Int32 = excType.withUnsafeMutableBufferPointer { typeBuf in
            excMessage.withUnsafeMutableBufferPointer { msgBuf in
                javaone_jni_gateway_invoke_hello_world_main_cached(
                    cachedClassNativeId,
                    &pushedOut,
                    &poppedOut,
                    typeBuf.baseAddress,
                    Int32(typeBuf.count),
                    msgBuf.baseAddress,
                    Int32(msgBuf.count)
                )
            }
        }

        lock.lock()
        pushed = Int(pushedOut)
        popped = Int(poppedOut)
        lock.unlock()

        if code == 0 {
            return
        }
        throw mapNativeCode(code, excType: excType, excMessage: excMessage, className: "<cached>")
    }

    func cacheFindClass(binaryName: String) throws -> UInt64 {
        var outId: UInt64 = 0
        let code: Int32 = binaryName.withCString { namePtr in
            javaone_jni_gateway_cache_find_class(namePtr, &outId)
        }
        if code == 0 {
            return outId
        }
        throw mapNativeCode(code, excType: [], excMessage: [], className: binaryName)
    }

    func cacheGetMethodID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        var outId: UInt64 = 0
        let code: Int32 = name.withCString { namePtr in
            signature.withCString { sigPtr in
                javaone_jni_gateway_cache_get_method(
                    classNativeId,
                    namePtr,
                    sigPtr,
                    isStatic ? 1 : 0,
                    &outId
                )
            }
        }
        if code == 0 {
            return outId
        }
        throw mapNativeCode(
            code,
            excType: [],
            excMessage: [],
            className: "<cached>",
            methodName: name,
            signature: signature
        )
    }

    func cacheGetFieldID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        var outId: UInt64 = 0
        let code: Int32 = name.withCString { namePtr in
            signature.withCString { sigPtr in
                javaone_jni_gateway_cache_get_field(
                    classNativeId,
                    namePtr,
                    sigPtr,
                    isStatic ? 1 : 0,
                    &outId
                )
            }
        }
        if code == 0 {
            return outId
        }
        throw mapNativeCode(
            code,
            excType: [],
            excMessage: [],
            className: "<cached>",
            methodName: name,
            signature: signature
        )
    }

    func cacheClearAll() {
        javaone_jni_gateway_cache_clear_all()
    }

    func objectCreateGlobal(classNativeId: UInt64) throws -> UInt64 {
        var outId: UInt64 = 0
        let code = javaone_jni_gateway_object_create_global(classNativeId, &outId)
        if code == 0 {
            return outId
        }
        throw mapNativeCode(code, excType: [], excMessage: [], className: "<object>")
    }

    func objectNewGlobal(
        classNativeId: UInt64,
        constructorMethodNativeId: UInt64,
        arguments: [JNINativeArg]
    ) throws -> UInt64 {
        var stringStorage: [UnsafeMutablePointer<CChar>] = []
        defer {
            for pointer in stringStorage {
                free(pointer)
            }
        }
        let cArgs: [JavaOneJgwValue] = arguments.map { arg in
            var value = JavaOneJgwValue()
            switch arg {
            case .boolean(let flag):
                value.kind = 1
                value.i32 = flag ? 1 : 0
            case .int(let number):
                value.kind = 2
                value.i32 = number
            case .long(let number):
                value.kind = 3
                value.i64 = number
            case .float(let number):
                value.kind = 4
                value.f32 = number
            case .double(let number):
                value.kind = 5
                value.f64 = number
            case .string(let text):
                value.kind = 6
                let dup = strdup(text)
                if let dup {
                    stringStorage.append(dup)
                    value.str = UnsafePointer(dup)
                }
            case .object(let nativeId):
                value.kind = 7
                value.object_id = nativeId
            case .null:
                value.kind = 8
            }
            return value
        }
        var outId: UInt64 = 0
        let code: Int32 = cArgs.withUnsafeBufferPointer { argsBuf in
            javaone_jni_gateway_object_new_global(
                classNativeId,
                constructorMethodNativeId,
                argsBuf.baseAddress,
                Int32(arguments.count),
                &outId
            )
        }
        if code == 0 {
            return outId
        }
        throw mapNativeCode(code, excType: [], excMessage: [], className: "<new>")
    }

    func objectReleaseGlobal(objectNativeId: UInt64) -> Bool {
        javaone_jni_gateway_object_release_global(objectNativeId) != 0
    }

    func objectContains(objectNativeId: UInt64) -> Bool {
        javaone_jni_gateway_object_contains(objectNativeId) != 0
    }

    func invoke(_ request: JNINativeInvokeRequest) throws -> JNINativeResult {
        var stringStorage: [UnsafeMutablePointer<CChar>] = []
        defer {
            for pointer in stringStorage {
                free(pointer)
            }
        }

        let cArgs: [JavaOneJgwValue] = request.arguments.map { arg in
            var value = JavaOneJgwValue()
            switch arg {
            case .boolean(let flag):
                value.kind = 1
                value.i32 = flag ? 1 : 0
            case .int(let number):
                value.kind = 2
                value.i32 = number
            case .long(let number):
                value.kind = 3
                value.i64 = number
            case .float(let number):
                value.kind = 4
                value.f32 = number
            case .double(let number):
                value.kind = 5
                value.f64 = number
            case .string(let text):
                value.kind = 6
                let dup = strdup(text)
                if let dup {
                    stringStorage.append(dup)
                    value.str = UnsafePointer(dup)
                }
            case .object(let nativeId):
                value.kind = 7
                value.object_id = nativeId
            case .null:
                value.kind = 8
            }
            return value
        }

        var outResult = JavaOneJgwValue()
        var pushedOut: Int32 = 0
        var poppedOut: Int32 = 0
        var stringOut = [CChar](repeating: 0, count: 4096)
        var excType = [CChar](repeating: 0, count: 256)
        var excMessage = [CChar](repeating: 0, count: 512)

        let code: Int32 = cArgs.withUnsafeBufferPointer { argsBuf in
            stringOut.withUnsafeMutableBufferPointer { strBuf in
                excType.withUnsafeMutableBufferPointer { typeBuf in
                    excMessage.withUnsafeMutableBufferPointer { msgBuf in
                        javaone_jni_gateway_call(
                            request.classNativeId,
                            request.methodNativeId,
                            request.isStatic ? 1 : 0,
                            request.receiverObjectNativeId ?? 0,
                            argsBuf.baseAddress,
                            Int32(request.arguments.count),
                            Self.cReturnKind(request.returnKind),
                            &outResult,
                            strBuf.baseAddress,
                            Int32(strBuf.count),
                            &pushedOut,
                            &poppedOut,
                            typeBuf.baseAddress,
                            Int32(typeBuf.count),
                            msgBuf.baseAddress,
                            Int32(msgBuf.count)
                        )
                    }
                }
            }
        }

        lock.lock()
        pushed = Int(pushedOut)
        popped = Int(poppedOut)
        lock.unlock()

        if code != 0 {
            throw mapNativeCode(code, excType: excType, excMessage: excMessage, className: "<call>")
        }
        return decodeNativeResult(outResult, stringOut: stringOut, expected: request.returnKind)
    }

    func registerNativeMethod(
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool,
        registrationToken: UInt64
    ) throws {
        let code: Int32 = methodName.withCString { namePtr in
            signature.withCString { sigPtr in
                javaone_jni_gateway_register_native(
                    classNativeId,
                    namePtr,
                    sigPtr,
                    isStatic ? 1 : 0,
                    registrationToken
                )
            }
        }
        if code != 0 {
            throw mapNativeCode(
                code,
                excType: [],
                excMessage: [],
                className: "<native>",
                methodName: methodName,
                signature: signature
            )
        }
    }

    func unregisterNativeMethod(registrationToken: UInt64) throws {
        let code = javaone_jni_gateway_unregister_native(registrationToken)
        if code != 0 {
            throw mapNativeCode(code, excType: [], excMessage: [], className: "<native>")
        }
    }

    func unregisterAllNativeMethods() {
        javaone_jni_gateway_unregister_all_natives()
    }

    func simulateNativeCallback(
        registrationToken: UInt64,
        arguments: [JNINativeArg]
    ) -> JNINativeResult {
        JNIGatewayTrampolineHost.dispatch(token: registrationToken, arguments: arguments)
    }

    private static func cReturnKind(_ kind: JNIReturnKind) -> Int32 {
        switch kind {
        case .void: return 0
        case .boolean: return 1
        case .int: return 2
        case .long: return 3
        case .float: return 4
        case .double: return 5
        case .string: return 6
        case .object: return 7
        }
    }

    private func decodeNativeResult(
        _ result: JavaOneJgwValue,
        stringOut: [CChar],
        expected: JNIReturnKind
    ) -> JNINativeResult {
        switch result.kind {
        case 0:
            return .void
        case 1:
            return .boolean(result.i32 != 0)
        case 2:
            return .int(result.i32)
        case 3:
            return .long(result.i64)
        case 4:
            return .float(result.f32)
        case 5:
            return .double(result.f64)
        case 6:
            return .string(cStringArrayToString(stringOut))
        case 7:
            return .object(nativeId: result.object_id)
        case 8:
            return .null
        default:
            switch expected {
            case .void: return .void
            case .boolean: return .boolean(false)
            case .int: return .int(0)
            case .long: return .long(0)
            case .float: return .float(0)
            case .double: return .double(0)
            case .string: return .string("")
            case .object: return .null
            }
        }
    }

    private func mapNativeCode(
        _ code: Int32,
        excType: [CChar],
        excMessage: [CChar],
        className: String,
        methodName: String = "main",
        signature: String = "([Ljava/lang/String;)V"
    ) -> JNIGatewayError {
        switch code {
        case -1:
            return .jvmNotReady(.notInitialized)
        case -2:
            return .threadAttachFailed(code)
        case -3:
            return .resourceExhausted
        case -4:
            return .classNotFound(className)
        case -5:
            return .methodNotFound(
                className: className,
                methodName: methodName,
                signature: signature
            )
        case -6:
            let type = cStringArrayToString(excType)
            let message = cStringArrayToString(excMessage)
            return .javaException(
                type: type.isEmpty ? "java.lang.Throwable" : type,
                message: message
            )
        case -7:
            return .helloWorldDidNotComplete
        case -8:
            return .nativeUnavailable
        case -9:
            return .fieldNotFound(
                className: className,
                fieldName: methodName,
                signature: signature
            )
        case -10:
            return .objectNotFound
        case -11:
            return .typeMismatch(expected: "compatible JNI types", actual: "mismatch")
        case -12:
            return .nativeRegistrationNotFound
        default:
            return .nativeFailure(code)
        }
    }

    private func cStringArrayToString(_ buffer: [CChar]) -> String {
        let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

#else

final class ProductionJNIGatewayNativeBackend: JNIGatewayNativeBackend, @unchecked Sendable {
    var lastLocalFramesPushed: Int { 0 }
    var lastLocalFramesPopped: Int { 0 }
    var findClassInvocationCount: Int { 0 }
    var getMethodIDInvocationCount: Int { 0 }
    var getFieldIDInvocationCount: Int { 0 }
    var liveGlobalClassRefCount: Int { 0 }
    var liveGlobalObjectRefCount: Int { 0 }

    func invokeHelloWorldMain(cachedClassNativeId: UInt64) throws {
        _ = cachedClassNativeId
        throw JNIGatewayError.nativeUnavailable
    }

    func cacheFindClass(binaryName: String) throws -> UInt64 {
        _ = binaryName
        throw JNIGatewayError.nativeUnavailable
    }

    func cacheGetMethodID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        _ = (classNativeId, name, signature, isStatic)
        throw JNIGatewayError.nativeUnavailable
    }

    func cacheGetFieldID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64 {
        _ = (classNativeId, name, signature, isStatic)
        throw JNIGatewayError.nativeUnavailable
    }

    func cacheClearAll() {}

    func objectCreateGlobal(classNativeId: UInt64) throws -> UInt64 {
        _ = classNativeId
        throw JNIGatewayError.nativeUnavailable
    }

    func objectNewGlobal(
        classNativeId: UInt64,
        constructorMethodNativeId: UInt64,
        arguments: [JNINativeArg]
    ) throws -> UInt64 {
        _ = (classNativeId, constructorMethodNativeId, arguments)
        throw JNIGatewayError.nativeUnavailable
    }

    func objectReleaseGlobal(objectNativeId: UInt64) -> Bool {
        _ = objectNativeId
        return false
    }

    func objectContains(objectNativeId: UInt64) -> Bool {
        _ = objectNativeId
        return false
    }

    func invoke(_ request: JNINativeInvokeRequest) throws -> JNINativeResult {
        _ = request
        throw JNIGatewayError.nativeUnavailable
    }

    func registerNativeMethod(
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool,
        registrationToken: UInt64
    ) throws {
        _ = (classNativeId, methodName, signature, isStatic, registrationToken)
        throw JNIGatewayError.nativeUnavailable
    }

    func unregisterNativeMethod(registrationToken: UInt64) throws {
        _ = registrationToken
        throw JNIGatewayError.nativeUnavailable
    }

    func unregisterAllNativeMethods() {}

    func simulateNativeCallback(
        registrationToken: UInt64,
        arguments: [JNINativeArg]
    ) -> JNINativeResult {
        _ = (registrationToken, arguments)
        return .void
    }
}

#endif
