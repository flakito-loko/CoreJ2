import Foundation

/// Internal GlobalRef / MethodID / FieldID / Object cache owned exclusively by `DefaultJNIGateway`.
///
/// Ownership:
/// - Swift tables map opaque tokens ↔ names / native slots.
/// - Native backend owns `jclass` / `jobject` GlobalRefs and raw `jmethodID` / `jfieldID` slots.
/// - `invalidate()` clears Swift tables and deletes every GlobalRef (classes + objects).
/// - Object handles are independently releasable via `releaseObject`.
/// - Returned Call* objects are adopted via `adoptObject`.
///
/// Never caches `JNIEnv` or local references. Never exposes JNI types publicly.
final class JNIGatewayReferenceCache: @unchecked Sendable {

    // MARK: - Types

    struct ClassRecord: Sendable {
        let token: UInt64
        let binaryName: String
        let nativeId: UInt64
    }

    struct MethodRecord: Sendable {
        let token: UInt64
        let classToken: UInt64
        let nativeId: UInt64
        let isStatic: Bool
        let name: String
        let signature: String
    }

    struct ObjectRecord: Sendable {
        let token: UInt64
        let classToken: UInt64
        let nativeId: UInt64
    }

    private struct MethodKey: Hashable, Sendable {
        let classToken: UInt64
        let name: String
        let signature: String
        let isStatic: Bool
    }

    private struct FieldKey: Hashable, Sendable {
        let classToken: UInt64
        let name: String
        let signature: String
        let isStatic: Bool
    }

    // MARK: - Properties

    private let native: any JNIGatewayNativeBackend

    private var nextToken: UInt64 = 1
    private var classesByName: [String: UInt64] = [:]
    private var classesByToken: [UInt64: ClassRecord] = [:]
    private var methodsByKey: [MethodKey: UInt64] = [:]
    private var methodsByToken: [UInt64: MethodRecord] = [:]
    private var fieldsByKey: [FieldKey: UInt64] = [:]
    private var fieldNativeByToken: [UInt64: UInt64] = [:]
    private var objectsByToken: [UInt64: ObjectRecord] = [:]
    /// Tokens that were released explicitly (for double-release detection).
    private var releasedObjectTokens: Set<UInt64> = []

    // MARK: - Init

    init(native: any JNIGatewayNativeBackend) {
        self.native = native
    }

    // MARK: - Resolve (caller must serialize)

    func resolveClass(binaryName: String) throws -> JNIClassId {
        if let existing = classesByName[binaryName], classesByToken[existing] != nil {
            return JNIClassId(token: existing)
        }

        let nativeId = try native.cacheFindClass(binaryName: binaryName)
        let token = nextToken
        nextToken &+= 1
        let record = ClassRecord(token: token, binaryName: binaryName, nativeId: nativeId)
        classesByName[binaryName] = token
        classesByToken[token] = record
        return JNIClassId(token: token)
    }

    func resolveMethod(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIMethodId {
        guard let record = classesByToken[classId.token] else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        let key = MethodKey(
            classToken: classId.token,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
        if let existing = methodsByKey[key], methodsByToken[existing] != nil {
            return JNIMethodId(token: existing)
        }

        let nativeMethodId = try native.cacheGetMethodID(
            classNativeId: record.nativeId,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
        let token = nextToken
        nextToken &+= 1
        let methodRecord = MethodRecord(
            token: token,
            classToken: classId.token,
            nativeId: nativeMethodId,
            isStatic: isStatic,
            name: name,
            signature: signature
        )
        methodsByKey[key] = token
        methodsByToken[token] = methodRecord
        return JNIMethodId(token: token)
    }

    func resolveField(
        classId: JNIClassId,
        name: String,
        signature: String,
        isStatic: Bool
    ) throws -> JNIFieldId {
        guard let record = classesByToken[classId.token] else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        let key = FieldKey(
            classToken: classId.token,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
        if let existing = fieldsByKey[key] {
            return JNIFieldId(token: existing)
        }

        let nativeFieldId = try native.cacheGetFieldID(
            classNativeId: record.nativeId,
            name: name,
            signature: signature,
            isStatic: isStatic
        )
        let token = nextToken
        nextToken &+= 1
        fieldsByKey[key] = token
        fieldNativeByToken[token] = nativeFieldId
        return JNIFieldId(token: token)
    }

    // MARK: - Objects

    func createObject(classId: JNIClassId) throws -> JNIObjectId {
        guard let classRecord = classesByToken[classId.token] else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        let nativeObjectId = try native.objectCreateGlobal(classNativeId: classRecord.nativeId)
        return adoptObject(nativeId: nativeObjectId, classToken: classId.token)
    }

    func createObject(
        classId: JNIClassId,
        constructorMethodId: JNIMethodId,
        arguments: [JNINativeArg]
    ) throws -> JNIObjectId {
        guard let classRecord = classesByToken[classId.token] else {
            throw JNIGatewayError.classNotFound("<invalid-class-id>")
        }
        guard let methodRecord = methodsByToken[constructorMethodId.token] else {
            throw JNIGatewayError.invalidMethodHandle
        }
        guard methodRecord.classToken == classId.token, !methodRecord.isStatic else {
            throw JNIGatewayError.invalidMethodHandle
        }
        let nativeObjectId = try native.objectNewGlobal(
            classNativeId: classRecord.nativeId,
            constructorMethodNativeId: methodRecord.nativeId,
            arguments: arguments
        )
        return adoptObject(nativeId: nativeObjectId, classToken: classId.token)
    }

    /// Registers a native object GlobalRef produced by Call* into an opaque handle.
    func adoptObject(nativeId: UInt64, classToken: UInt64) -> JNIObjectId {
        let token = nextToken
        nextToken &+= 1
        objectsByToken[token] = ObjectRecord(
            token: token,
            classToken: classToken,
            nativeId: nativeId
        )
        releasedObjectTokens.remove(token)
        return JNIObjectId(token: token)
    }

    func releaseObject(_ objectId: JNIObjectId) throws {
        if releasedObjectTokens.contains(objectId.token) {
            throw JNIGatewayError.objectAlreadyReleased
        }
        guard let record = objectsByToken.removeValue(forKey: objectId.token) else {
            throw JNIGatewayError.objectNotFound
        }
        releasedObjectTokens.insert(objectId.token)
        _ = native.objectReleaseGlobal(objectNativeId: record.nativeId)
    }

    func containsObject(_ objectId: JNIObjectId) -> Bool {
        objectsByToken[objectId.token] != nil
    }

    func objectRecord(for objectId: JNIObjectId) -> ObjectRecord? {
        objectsByToken[objectId.token]
    }

    func classRecord(for classId: JNIClassId) -> ClassRecord? {
        classesByToken[classId.token]
    }

    func methodRecord(for methodId: JNIMethodId) -> MethodRecord? {
        methodsByToken[methodId.token]
    }

    /// Clears Swift tables and DeleteGlobalRef for every cached class and object.
    func invalidate() {
        classesByName.removeAll(keepingCapacity: false)
        classesByToken.removeAll(keepingCapacity: false)
        methodsByKey.removeAll(keepingCapacity: false)
        methodsByToken.removeAll(keepingCapacity: false)
        fieldsByKey.removeAll(keepingCapacity: false)
        fieldNativeByToken.removeAll(keepingCapacity: false)
        objectsByToken.removeAll(keepingCapacity: false)
        releasedObjectTokens.removeAll(keepingCapacity: false)
        native.cacheClearAll()
    }

    var cachedClassCount: Int { classesByToken.count }
    var cachedMethodCount: Int { methodsByToken.count }
    var cachedFieldCount: Int { fieldsByKey.count }
    var retainedObjectCount: Int { objectsByToken.count }
}
