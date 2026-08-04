import Foundation

/// Test double for `EmbeddedJVMControlling` without a real JVM.
final class StubEmbeddedJVMController: EmbeddedJVMControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var stateStorage: EmbeddedJVMState

    private(set) var ensureStartedCount = 0
    private(set) var shutdownCount = 0
    var ensureStartedError: Error?
    var shutdownError: Error?

    init(initialState: EmbeddedJVMState = .notInitialized) {
        self.stateStorage = initialState
    }

    var state: EmbeddedJVMState {
        lock.lock()
        defer { lock.unlock() }
        return stateStorage
    }

    func ensureStarted() async throws {
        try performEnsureStarted()
    }

    func shutdown() async throws {
        try performShutdown()
    }

    // MARK: - Sync helpers (NSLock is not usable directly in async contexts)

    private func performEnsureStarted() throws {
        lock.lock()
        defer { lock.unlock() }
        ensureStartedCount += 1
        if let ensureStartedError {
            throw ensureStartedError
        }
        stateStorage = .ready
    }

    private func performShutdown() throws {
        lock.lock()
        defer { lock.unlock() }
        shutdownCount += 1
        if let shutdownError {
            throw shutdownError
        }
        stateStorage = .destroyed
    }
}
