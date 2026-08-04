import Foundation

/// Process-wide bridge from native trampolines into the active `DefaultJNIGateway`.
///
/// Only one gateway is active for callbacks at a time (bind installs, invalidate clears).
enum JNIGatewayTrampolineHost {
    private static let lock = NSLock()
    nonisolated(unsafe) private static weak var active: DefaultJNIGateway?

    static func install(_ gateway: DefaultJNIGateway) {
        lock.lock()
        active = gateway
        lock.unlock()
    }

    static func clear(_ gateway: DefaultJNIGateway) {
        lock.lock()
        if active === gateway {
            active = nil
        }
        lock.unlock()
    }

    /// Entry used by Mock / Production trampolines. Never receives `JNIEnv` / `jobject`.
    static func dispatch(token: UInt64, arguments: [JNINativeArg]) -> JNINativeResult {
        lock.lock()
        let gateway = active
        lock.unlock()
        guard let gateway else {
            return .void
        }
        return gateway.dispatchNativeCallback(token: token, arguments: arguments)
    }
}
