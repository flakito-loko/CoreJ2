import Foundation

/// Domain errors for `JNIGateway`. No JNI types are part of this surface.
enum JNIGatewayError: Error, Sendable, Equatable {
    /// Manager state does not allow JNI (`notInitialized`, `starting`, `shutdown`, `destroyed`, `failed`).
    case jvmNotReady(EmbeddedJVMState)
    /// Gateway was invalidated or never bound.
    case gatewayInvalidated
    /// Native attach / env acquisition failed.
    case threadAttachFailed(Int32)
    /// `FindClass` failed (after clearing any pending exception).
    case classNotFound(String)
    /// `GetStaticMethodID` / `GetMethodID` failed.
    case methodNotFound(className: String, methodName: String, signature: String)
    /// `GetStaticFieldID` / `GetFieldID` failed (foundation).
    case fieldNotFound(className: String, fieldName: String, signature: String)
    /// Object handle unknown, already released, or invalidated.
    case objectNotFound
    /// `releaseObjectReference` called twice for the same handle.
    case objectAlreadyReleased
    /// Method handle missing, wrong static/instance kind, or incompatible with the call.
    case invalidMethodHandle
    /// Argument or return kind incompatible with the requested operation.
    case typeMismatch(expected: String, actual: String)
    /// Java exception was pending; cleared and mapped.
    case javaException(type: String, message: String)
    /// Local-frame / resource failure.
    case resourceExhausted
    /// HelloWorld completed flag was false after `main`.
    case helloWorldDidNotComplete
    /// Underlying native backend unavailable (e.g. App Target without linked libjvm).
    case nativeUnavailable
    /// Unexpected native / JNI error code.
    case nativeFailure(Int32)
    /// `registerNative` for an already-registered class/name/signature.
    case duplicateNativeRegistration(methodName: String, signature: String)
    /// Unknown or already-removed native registration.
    case nativeRegistrationNotFound
    /// Trampoline invoked while Gateway is not usable.
    case callbackRejected
}
