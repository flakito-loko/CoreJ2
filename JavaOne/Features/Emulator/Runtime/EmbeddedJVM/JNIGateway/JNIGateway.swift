import Foundation

/// Production JNI Gateway contract (Epic 2).
///
/// Sole component authorized to invoke JNI. Does not create or destroy the JVM.
protocol JNIGateway: AnyObject, Sendable {
    /// Consistent with manager readiness and bind/invalidate lifecycle.
    var isUsable: Bool { get }

    /// Associates the gateway with a ready JVM. Fails if manager is not in a usable state.
    func bind() throws

    /// Marks the gateway unusable and releases every cached GlobalRef (classes + objects) / ID table.
    func invalidate()

    /// Resolves a class by JNI binary name. Backed by a GlobalRef cache (FindClass once per name).
    func resolveClass(binaryName: String) throws -> JNIClassId

    /// Resolves a method on a previously resolved class. Backed by a MethodID cache.
    func resolveMethod(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIMethodId

    /// Resolves a field on a previously resolved class (foundation; FieldID cache).
    func resolveField(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIFieldId

    /// Allocates an instance of `classId`, promotes it to a GlobalRef, returns an opaque handle.
    ///
    /// Ownership: Gateway holds the GlobalRef until `releaseObjectReference` or `invalidate()`.
    func createGlobalObjectReference(classId: JNIClassId) throws -> JNIObjectId

    /// Constructs an instance via `NewObject` (`constructorMethodId` must be `<init>`), promotes to GlobalRef.
    ///
    /// Ownership: Gateway holds the GlobalRef until `releaseObjectReference` or `invalidate()`.
    func createGlobalObjectReference(
        classId: JNIClassId,
        constructorMethodId: JNIMethodId,
        arguments: [JNIValue]
    ) throws -> JNIObjectId

    /// `DeleteGlobalRef` for the object and drops the handle. Double-release fails.
    func releaseObjectReference(_ objectId: JNIObjectId) throws

    /// Whether the Gateway currently owns a live GlobalRef for `objectId`.
    func containsObject(_ objectId: JNIObjectId) -> Bool

    /// Static method invocation via opaque class/method handles.
    func callStatic(
        classId: JNIClassId,
        methodId: JNIMethodId,
        arguments: [JNIValue],
        returning: JNIReturnKind
    ) throws -> JNIValue

    /// Instance method invocation via opaque object/method handles.
    func callInstance(
        objectId: JNIObjectId,
        methodId: JNIMethodId,
        arguments: [JNIValue],
        returning: JNIReturnKind
    ) throws -> JNIValue

    /// Registers a Java `native` method implementation that dispatches to a Swift handler.
    ///
    /// The trampoline copies parameters into Swift-owned `JNIValue`s; JNI types never escape.
    func registerNative(
        classId: JNIClassId,
        methodName: String,
        signature: String,
        isStatic: Bool,
        handler: @escaping JNINativeCallbackHandler
    ) throws -> JNINativeRegistrationId

    /// Removes a previously registered native method.
    func unregisterNative(_ registrationId: JNINativeRegistrationId) throws

    /// Production capability: invoke Phase-1 `HelloWorld.main` via cached class/method handles.
    func invokeHelloWorldMain() async throws
}
