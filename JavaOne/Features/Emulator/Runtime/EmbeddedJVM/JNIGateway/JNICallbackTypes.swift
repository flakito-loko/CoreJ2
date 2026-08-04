import Foundation

/// Opaque native-method registration handle. Never carries JNI function pointers publicly.
struct JNINativeRegistrationId: Hashable, Sendable, Equatable {
    let token: UInt64
}

/// Swift-owned callback payload delivered by the Gateway trampoline.
///
/// All values are copies / opaque handles — never `JNIEnv` or `jobject`.
struct JNICallbackEvent: Sendable {
    let registrationId: JNINativeRegistrationId
    let methodName: String
    let signature: String
    let isStatic: Bool
    let arguments: [JNIValue]
}

/// Handler invoked on the trampoline path after parameters are copied into Swift-owned values.
typealias JNINativeCallbackHandler = @Sendable (JNICallbackEvent) -> JNIValue
