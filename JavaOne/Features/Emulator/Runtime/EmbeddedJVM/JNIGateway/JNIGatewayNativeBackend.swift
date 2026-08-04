import Foundation

/// Opaque backend that performs JNI. Implementations must not leak `JNIEnv` / `jobject` to callers.
protocol JNIGatewayNativeBackend: Sendable {
    // MARK: HelloWorld invoke

    /// Invokes `HelloWorld.main` using a previously cached global class ref (`cacheFindClass`).
    func invokeHelloWorldMain(cachedClassNativeId: UInt64) throws

    /// Diagnostic: local frames pushed during the last invoke (tests).
    var lastLocalFramesPushed: Int { get }

    /// Diagnostic: local frames popped during the last invoke (tests).
    var lastLocalFramesPopped: Int { get }

    // MARK: Global-ref / ID cache (E2-US002)

    /// FindClass → NewGlobalRef → DeleteLocalRef → store. Returns opaque native class id.
    func cacheFindClass(binaryName: String) throws -> UInt64

    /// GetMethodID / GetStaticMethodID → store. Returns opaque native method id.
    func cacheGetMethodID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64

    /// GetFieldID / GetStaticFieldID → store (foundation). Returns opaque native field id.
    func cacheGetFieldID(
        classNativeId: UInt64,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> UInt64

    /// DeleteGlobalRef for every cached class and object; drop method/field ID tables.
    func cacheClearAll()

    // MARK: Object GlobalRefs (E2-US003)

    /// AllocObject → NewGlobalRef → DeleteLocalRef → store. Returns opaque native object id.
    func objectCreateGlobal(classNativeId: UInt64) throws -> UInt64

    /// NewObjectA(constructor) → NewGlobalRef → DeleteLocalRef → store.
    func objectNewGlobal(
        classNativeId: UInt64,
        constructorMethodNativeId: UInt64,
        arguments: [JNINativeArg]
    ) throws -> UInt64

    /// DeleteGlobalRef for one stored object. Returns false if `objectNativeId` is unknown.
    @discardableResult
    func objectReleaseGlobal(objectNativeId: UInt64) -> Bool

    /// Whether a native object GlobalRef slot is live.
    func objectContains(objectNativeId: UInt64) -> Bool

    /// How many times FindClass ran (cache misses at native layer).
    var findClassInvocationCount: Int { get }

    /// How many times Get(Static)MethodID ran.
    var getMethodIDInvocationCount: Int { get }

    /// How many times Get(Static)FieldID ran.
    var getFieldIDInvocationCount: Int { get }

    /// Live global class references currently held by the native cache.
    var liveGlobalClassRefCount: Int { get }

    /// Live global object references currently held by the native cache.
    var liveGlobalObjectRefCount: Int { get }

    // MARK: Generic invoke (E2-US004)

    /// Performs CallStatic* / Call* with PushLocalFrame discipline. Object results are already GlobalRefs.
    func invoke(_ request: JNINativeInvokeRequest) throws -> JNINativeResult

    // MARK: Native callbacks (E2-US005)

    /// `RegisterNatives` for one method bound to an opaque registration token.
    func registerNativeMethod(
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool,
        registrationToken: UInt64
    ) throws

    /// `UnregisterNatives` / drop one registration at the native layer.
    func unregisterNativeMethod(registrationToken: UInt64) throws

    /// Clears every native registration (Gateway invalidate / shutdown).
    func unregisterAllNativeMethods()

    /// Test / trampoline hook: simulate a Java→native call with already-copied arguments.
    func simulateNativeCallback(
        registrationToken: UInt64,
        arguments: [JNINativeArg]
    ) -> JNINativeResult
}
