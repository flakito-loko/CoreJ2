import Foundation

/// Expected JNI return kind for a generic call (Swift-native; no JNI types).
enum JNIReturnKind: Sendable, Equatable {
    case void
    case boolean
    case int
    case long
    case float
    case double
    case string
    case object
}

/// Typed value crossing the Gateway public API (arguments and results).
///
/// Object values use opaque `JNIObjectId` only — never `jobject`.
enum JNIValue: Sendable, Equatable {
    case void
    case boolean(Bool)
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case string(String)
    case object(JNIObjectId)
    /// Null object / null String reference.
    case null
}

// MARK: - Native wire types (internal)

/// Argument after Swift handle → native id resolution.
enum JNINativeArg: Sendable, Equatable {
    case boolean(Bool)
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case string(String)
    case object(UInt64)
    case null
}

/// Result from native before Swift adopts object GlobalRefs into `JNIObjectId`.
enum JNINativeResult: Sendable, Equatable {
    case void
    case boolean(Bool)
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case string(String)
    case object(nativeId: UInt64)
    case null
}

/// Opaque invoke request for `JNIGatewayNativeBackend`.
struct JNINativeInvokeRequest: Sendable {
    let classNativeId: UInt64
    let methodNativeId: UInt64
    let isStatic: Bool
    /// `nil` for static calls.
    let receiverObjectNativeId: UInt64?
    let arguments: [JNINativeArg]
    let returnKind: JNIReturnKind
}
