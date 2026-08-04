import Foundation

/// Owns native callback registrations and dispatches trampoline events to Swift handlers.
///
/// Lifecycle: register → (Java/Mock dispatch) → unregister / `invalidate()`.
/// Does not retain `JNIEnv`. Object arguments arrive as already-copied native GlobalRef ids
/// and are adopted into opaque `JNIObjectId` values before the handler runs.
final class JNIGatewayCallbackRegistry: @unchecked Sendable {

    // MARK: - Types

    private struct Key: Hashable {
        let classToken: UInt64
        let methodName: String
        let signature: String
        let isStatic: Bool
    }

    private struct Entry {
        let id: JNINativeRegistrationId
        let key: Key
        let classNativeId: UInt64
        let handler: JNINativeCallbackHandler
    }

    // MARK: - Properties

    private var nextToken: UInt64 = 1
    private var entriesByToken: [UInt64: Entry] = [:]
    private var tokensByKey: [Key: UInt64] = [:]
    /// Monotonic dispatch order counter for tests.
    private(set) var dispatchSequence: [UInt64] = []

    // MARK: - Register / unregister

    func register(
        classToken: UInt64,
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool,
        handler: @escaping JNINativeCallbackHandler
    ) throws -> JNINativeRegistrationId {
        let key = Key(
            classToken: classToken,
            methodName: methodName,
            signature: signature,
            isStatic: isStatic
        )
        if tokensByKey[key] != nil {
            throw JNIGatewayError.duplicateNativeRegistration(
                methodName: methodName,
                signature: signature
            )
        }
        let token = nextToken
        nextToken &+= 1
        let id = JNINativeRegistrationId(token: token)
        entriesByToken[token] = Entry(
            id: id,
            key: key,
            classNativeId: classNativeId,
            handler: handler
        )
        tokensByKey[key] = token
        return id
    }

    func unregister(_ registrationId: JNINativeRegistrationId) throws -> (classNativeId: UInt64, methodName: String, signature: String, isStatic: Bool) {
        guard let entry = entriesByToken.removeValue(forKey: registrationId.token) else {
            throw JNIGatewayError.nativeRegistrationNotFound
        }
        tokensByKey[entry.key] = nil
        return (
            entry.classNativeId,
            entry.key.methodName,
            entry.key.signature,
            entry.key.isStatic
        )
    }

    func entry(for registrationId: JNINativeRegistrationId) -> (
        classNativeId: UInt64,
        methodName: String,
        signature: String,
        isStatic: Bool
    )? {
        guard let entry = entriesByToken[registrationId.token] else { return nil }
        return (
            entry.classNativeId,
            entry.key.methodName,
            entry.key.signature,
            entry.key.isStatic
        )
    }

    /// Removes every registration. Returns snapshots for native UnregisterNatives.
    @discardableResult
    func removeAll() -> [(classNativeId: UInt64, methodName: String, signature: String, isStatic: Bool)] {
        let snapshot = entriesByToken.values.map {
            ($0.classNativeId, $0.key.methodName, $0.key.signature, $0.key.isStatic)
        }
        entriesByToken.removeAll(keepingCapacity: false)
        tokensByKey.removeAll(keepingCapacity: false)
        dispatchSequence.removeAll(keepingCapacity: false)
        return snapshot
    }

    var registrationCount: Int { entriesByToken.count }

    // MARK: - Dispatch

    struct PreparedDispatch {
        let handler: JNINativeCallbackHandler
        let event: JNICallbackEvent
    }

    func prepareDispatch(
        token: UInt64,
        nativeArguments: [JNINativeArg],
        adoptObject: (UInt64) -> JNIObjectId
    ) throws -> PreparedDispatch {
        guard let entry = entriesByToken[token] else {
            throw JNIGatewayError.nativeRegistrationNotFound
        }
        dispatchSequence.append(token)
        let values: [JNIValue] = nativeArguments.map { arg in
            switch arg {
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
            case .object(let nativeId):
                return .object(adoptObject(nativeId))
            case .null:
                return .null
            }
        }
        let event = JNICallbackEvent(
            registrationId: entry.id,
            methodName: entry.key.methodName,
            signature: entry.key.signature,
            isStatic: entry.key.isStatic,
            arguments: values
        )
        return PreparedDispatch(handler: entry.handler, event: event)
    }
}
