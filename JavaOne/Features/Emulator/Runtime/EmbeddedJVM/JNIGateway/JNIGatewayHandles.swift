import Foundation

/// Opaque class handle. Never carries a JNI `jclass` / `JNIEnv` across the public API.
struct JNIClassId: Hashable, Sendable, Equatable {
    let token: UInt64
}

/// Opaque method handle. Never carries a JNI `jmethodID` across the public API.
struct JNIMethodId: Hashable, Sendable, Equatable {
    let token: UInt64
}

/// Opaque field handle (foundation for later stories). Never carries a JNI `jfieldID` publicly.
struct JNIFieldId: Hashable, Sendable, Equatable {
    let token: UInt64
}

/// Opaque Java object handle. Never carries a JNI `jobject` across the public API.
struct JNIObjectId: Hashable, Sendable, Equatable {
    let token: UInt64
}
