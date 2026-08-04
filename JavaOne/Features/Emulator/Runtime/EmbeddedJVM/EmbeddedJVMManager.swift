import Foundation

/// Owns the single in-process Embedded JVM lifecycle (Phase 1 spike).
///
/// Position (architecture): inside the future iOS PlatformBootstrap backend.
/// This type does **not** implement Bridge, Host, Adapter, UI, FreeJ2ME, or JNI Gateway.
///
/// Phase-1 scope: `NotInitialized → Starting → Ready → Shutdown → Destroyed`,
/// plus a one-shot Hello World invoke while `Ready`.
public final class EmbeddedJVMManager: @unchecked Sendable {

    // MARK: - Properties

    private let lock = NSLock()
    private let native: any EmbeddedJVMNativeRuntime
    private let configuration: EmbeddedJVMConfiguration
    private let runtimeQueue: DispatchQueue

    private var stateStorage: EmbeddedJVMState = .notInitialized
    private var metricsStorage = EmbeddedJVMMetrics()
    private var helloWorldCompleted = false

    // MARK: - Init

    /// Creates a manager. Does not start the JVM.
    public init(
        configuration: EmbeddedJVMConfiguration,
        native: any EmbeddedJVMNativeRuntime,
        runtimeQueue: DispatchQueue = DispatchQueue(label: "JavaOne.EmbeddedJVM", qos: .userInitiated)
    ) {
        self.configuration = configuration
        self.native = native
        self.runtimeQueue = runtimeQueue
        self.metricsStorage.backendLabel = configuration.backendLabel
        if let libjvm = configuration.libjvmURL {
            metricsStorage.libjvmBytes = fileSize(libjvm)
        }
        metricsStorage.helloWorldClassBytes = directoryClassSize(configuration.classpath)
    }

    // MARK: - Observation

    public var state: EmbeddedJVMState {
        lock.lock()
        defer { lock.unlock() }
        return stateStorage
    }

    public var metrics: EmbeddedJVMMetrics {
        lock.lock()
        defer { lock.unlock() }
        return metricsStorage
    }

    public var didCompleteHelloWorld: Bool {
        lock.lock()
        defer { lock.unlock() }
        return helloWorldCompleted
    }

    // MARK: - Lifecycle

    /// Ensures exactly one JVM exists. Transitions to `ready` on success.
    public func ensureStarted() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            runtimeQueue.async {
                do {
                    try self.ensureStartedSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs the Phase-1 Hello World class on the existing JVM. Does not load JARs or FreeJ2ME.
    public func runHelloWorld() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            runtimeQueue.async {
                do {
                    try self.runHelloWorldSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Ordered process shutdown: `ready → shutdown → destroyed`.
    public func shutdown() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            runtimeQueue.async {
                do {
                    try self.shutdownSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Sync (runtime queue)

    private func ensureStartedSync() throws {
        lock.lock()
        switch stateStorage {
        case .ready:
            lock.unlock()
            return
        case .starting:
            lock.unlock()
            throw EmbeddedJVMError.alreadyStarting
        case .shutdown:
            lock.unlock()
            throw EmbeddedJVMError.failed("Cannot start during shutdown")
        case .destroyed:
            lock.unlock()
            throw EmbeddedJVMError.destroyed
        case .failed:
            lock.unlock()
            throw EmbeddedJVMError.failed("Manager is in Failed state")
        case .notInitialized:
            if native.isJVMCreated {
                stateStorage = .failed
                lock.unlock()
                throw EmbeddedJVMError.secondJVMRejected
            }
            stateStorage = .starting
            metricsStorage.rssBeforeCreateBytes = ProcessRSSSampler.residentBytes()
            lock.unlock()
        }

        let started = DispatchTime.now().uptimeNanoseconds
        do {
            try native.createJVM(
                javaHomePath: configuration.javaHomeURL.path,
                classpath: configuration.classpath.path
            )
            let elapsed = DispatchTime.now().uptimeNanoseconds &- started
            lock.lock()
            stateStorage = .ready
            metricsStorage.startupNanoseconds = elapsed
            metricsStorage.rssAfterReadyBytes = ProcessRSSSampler.residentBytes()
            lock.unlock()
        } catch let error as EmbeddedJVMError {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw error
        } catch {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw EmbeddedJVMError.failed(String(describing: error))
        }
    }

    private func runHelloWorldSync() throws {
        lock.lock()
        guard stateStorage == .ready else {
            let current = stateStorage
            lock.unlock()
            if current == .destroyed { throw EmbeddedJVMError.destroyed }
            throw EmbeddedJVMError.notReady
        }
        lock.unlock()

        let jniName = configuration.helloWorldMainClass
            .replacingOccurrences(of: ".", with: "/")
        let started = DispatchTime.now().uptimeNanoseconds
        do {
            try native.runHelloWorld(mainClassJNI: jniName)
            let elapsed = DispatchTime.now().uptimeNanoseconds &- started
            lock.lock()
            helloWorldCompleted = true
            metricsStorage.helloWorldNanoseconds = elapsed
            metricsStorage.rssAfterHelloBytes = ProcessRSSSampler.residentBytes()
            lock.unlock()
        } catch let error as EmbeddedJVMError {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw error
        } catch {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw EmbeddedJVMError.failed(String(describing: error))
        }
    }

    private func shutdownSync() throws {
        lock.lock()
        switch stateStorage {
        case .destroyed:
            lock.unlock()
            return
        case .notInitialized:
            stateStorage = .destroyed
            lock.unlock()
            return
        case .starting:
            lock.unlock()
            throw EmbeddedJVMError.failed("Cannot shutdown while Starting")
        case .shutdown:
            lock.unlock()
            throw EmbeddedJVMError.alreadyRunning
        case .failed, .ready:
            stateStorage = .shutdown
            lock.unlock()
        }

        let started = DispatchTime.now().uptimeNanoseconds
        do {
            if native.isJVMCreated {
                try native.destroyJVM()
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds &- started
            lock.lock()
            stateStorage = .destroyed
            metricsStorage.destroyNanoseconds = elapsed
            metricsStorage.destroyTimedOut = false
            metricsStorage.rssAfterDestroyBytes = ProcessRSSSampler.residentBytes()
            lock.unlock()
        } catch EmbeddedJVMError.nativeDestroyTimedOut {
            // JVM ownership released at process level; Phase-1 treats this as Destroyed
            // with an explicit metric flag (HotSpot DestroyJavaVM may block forever).
            let elapsed = DispatchTime.now().uptimeNanoseconds &- started
            lock.lock()
            stateStorage = .destroyed
            metricsStorage.destroyNanoseconds = elapsed
            metricsStorage.destroyTimedOut = true
            metricsStorage.rssAfterDestroyBytes = ProcessRSSSampler.residentBytes()
            lock.unlock()
        } catch let error as EmbeddedJVMError {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw error
        } catch {
            lock.lock()
            stateStorage = .failed
            lock.unlock()
            throw EmbeddedJVMError.failed(String(describing: error))
        }
    }

    // MARK: - Helpers

    private func fileSize(_ url: URL) -> UInt64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return UInt64(size)
    }

    private func directoryClassSize(_ classpath: URL) -> UInt64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: classpath, includingPropertiesForKeys: [.fileSizeKey]) else {
            return fileSize(classpath)
        }
        var total: UInt64 = 0
        var found = false
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "class" else { continue }
            if let size = fileSize(fileURL) {
                total += size
                found = true
            }
        }
        return found ? total : fileSize(classpath)
    }
}
