import Foundation

/// Default iOS PlatformBootstrap (E3-US001…E3-US007).
///
/// Sequence on `initialize()`:
/// 1. `EmbeddedJVMControlling.ensureStarted()`
/// 2. `gateway.bind()`
/// 3. Register `NativeCallbackHost.onBootstrapHeartbeat` (infrastructure)
/// 4. `resolveClass(Mobile)` / `resolveClass(MobilePlatform)`
/// 5. `NewObject MobilePlatform(width, height)` → retain `JNIObjectId`
/// 6. `Mobile.setPlatform(platform)`
/// 7. Register `PainterRunnable.run`, construct Runnable, `MobilePlatform.setPainter`
///
/// After ready:
/// - `loadJar(url:)` → `MobilePlatform.loadJar` + `JarLoadSupport` name check
/// - `runJar()` → `RunJarSupport.runAndVerifyStartApp` (Vendor `runJar` + markers)
/// - `verifyDisplay()` → `DisplaySupport.inspectStatus` (Display + current Displayable)
///
/// Ownership: Bootstrap owns MobilePlatform + painter `JNIObjectId`s; Gateway owns GlobalRefs;
/// Manager owns JVM lifetime. No repaint / framebuffer / pixel extraction.
final class DefaultPlatformBootstrap: PlatformBootstrap, @unchecked Sendable {

    // MARK: - Constants

    /// Contract with `org.javaone.bootstrap.NativeCallbackHost` (JavaOne-owned).
    enum Infrastructure {
        static let callbackHostBinaryName = "org/javaone/bootstrap/NativeCallbackHost"
        static let heartbeatMethodName = "onBootstrapHeartbeat"
        static let heartbeatSignature = "()V"
        static let fireHeartbeatMethodName = "fireHeartbeat"
        static let fireHeartbeatSignature = "()V"
    }

    /// JavaOne-owned painter Runnable (not FreeJ2ME).
    enum Painter {
        static let binaryName = "org/javaone/bootstrap/PainterRunnable"
        static let constructorName = "<init>"
        static let constructorSignature = "()V"
        static let runMethodName = "run"
        static let runSignature = "()V"
        static let firePaintMethodName = "firePaint"
        static let firePaintSignature = "()V"
    }

    /// FreeJ2ME MobilePlatform bind (Vendor read-only; resolved via classpath).
    enum FreeJ2ME {
        static let mobileBinaryName = "org/recompile/mobile/Mobile"
        static let mobilePlatformBinaryName = "org/recompile/mobile/MobilePlatform"
        static let constructorName = "<init>"
        static let constructorSignature = "(II)V"
        static let setPlatformName = "setPlatform"
        static let setPlatformSignature = "(Lorg/recompile/mobile/MobilePlatform;)V"
        static let setPainterName = "setPainter"
        static let setPainterSignature = "(Ljava/lang/Runnable;)V"
        static let loadJarName = "loadJar"
        static let loadJarSignature = "(Ljava/lang/String;)Z"
        static let runJarName = "runJar"
        static let runJarSignature = "()V"
        static let defaultLCDWidth: Int32 = 240
        static let defaultLCDHeight: Int32 = 320
    }

    /// JavaOne-owned post-loadJar verification (not FreeJ2ME).
    enum JarLoad {
        static let supportBinaryName = "org/javaone/bootstrap/JarLoadSupport"
        static let midletNameMethodName = "midletNameAfterLoad"
        static let midletNameSignature =
            "(Lorg/recompile/mobile/MobilePlatform;)Ljava/lang/String;"
    }

    /// JavaOne-owned runJar + startApp marker verification (not FreeJ2ME).
    enum JarRun {
        static let supportBinaryName = "org/javaone/bootstrap/RunJarSupport"
        static let runAndVerifyMethodName = "runAndVerifyStartApp"
        static let runAndVerifySignature = "(Lorg/recompile/mobile/MobilePlatform;)Z"
    }

    /// JavaOne-owned Display lifecycle inspection (not FreeJ2ME).
    enum DisplayInspection {
        static let supportBinaryName = "org/javaone/bootstrap/DisplaySupport"
        static let inspectStatusMethodName = "inspectStatus"
        static let inspectStatusSignature = "()Ljava/lang/String;"
        static let statusNoDisplay = "NO_DISPLAY"
        static let statusNoCurrent = "NO_CURRENT"
        static let statusOKPrefix = "OK:"
    }

    // MARK: - Properties

    private let lock = NSLock()
    private let workQueue: DispatchQueue
    private let jvm: any EmbeddedJVMControlling
    private let gateway: any JNIGateway
    private let lcdWidth: Int32
    private let lcdHeight: Int32

    private var stateStorage: PlatformBootstrapState = .uninitialized
    private var nativeRegistrations: [JNINativeRegistrationId] = []
    private var heartbeatCountStorage = 0
    private var paintCountStorage = 0
    private var mobilePlatformObjectIdStorage: JNIObjectId?
    private var painterObjectIdStorage: JNIObjectId?
    private var lastJarLoadResultStorage: FreeJ2MEJarLoadResult?
    private var lastJarRunResultStorage: FreeJ2MEJarRunResult?
    private var lastDisplayResultStorage: FreeJ2MEDisplayResult?

    // MARK: - Init

    /// - Parameters:
    ///   - jvm: Embedded JVM controller (typically `EmbeddedJVMManager`).
    ///   - gateway: Bound only after the JVM is ready; must share the same readiness source as `jvm`.
    ///   - lcdWidth: Passed to `MobilePlatform(int,int)`.
    ///   - lcdHeight: Passed to `MobilePlatform(int,int)`.
    init(
        jvm: any EmbeddedJVMControlling,
        gateway: any JNIGateway,
        lcdWidth: Int32 = FreeJ2ME.defaultLCDWidth,
        lcdHeight: Int32 = FreeJ2ME.defaultLCDHeight,
        workQueue: DispatchQueue = DispatchQueue(label: "JavaOne.PlatformBootstrap", qos: .userInitiated)
    ) {
        self.jvm = jvm
        self.gateway = gateway
        self.lcdWidth = lcdWidth
        self.lcdHeight = lcdHeight
        self.workQueue = workQueue
    }

    // MARK: - Diagnostics (tests)

    var registeredNativeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return nativeRegistrations.count
    }

    var heartbeatInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return heartbeatCountStorage
    }

    var paintInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return paintCountStorage
    }

    // MARK: - PlatformBootstrap

    var state: PlatformBootstrapState {
        lock.lock()
        defer { lock.unlock() }
        return stateStorage
    }

    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        if case .ready = stateStorage { return true }
        return false
    }

    var mobilePlatformObjectId: JNIObjectId? {
        lock.lock()
        defer { lock.unlock() }
        return mobilePlatformObjectIdStorage
    }

    var painterObjectId: JNIObjectId? {
        lock.lock()
        defer { lock.unlock() }
        return painterObjectIdStorage
    }

    var lastJarLoadResult: FreeJ2MEJarLoadResult? {
        lock.lock()
        defer { lock.unlock() }
        return lastJarLoadResultStorage
    }

    var lastJarRunResult: FreeJ2MEJarRunResult? {
        lock.lock()
        defer { lock.unlock() }
        return lastJarRunResultStorage
    }

    var lastDisplayResult: FreeJ2MEDisplayResult? {
        lock.lock()
        defer { lock.unlock() }
        return lastDisplayResultStorage
    }

    func initialize() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workQueue.async {
                do {
                    try self.beginStartingSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        do {
            try await jvm.ensureStarted()
        } catch {
            await setStateAsync(.failed(String(describing: error)))
            throw PlatformBootstrapError.jvmUnavailable(String(describing: error))
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workQueue.async {
                do {
                    try self.bindGatewayRegisterAndCreatePlatformSync()
                    self.lock.lock()
                    self.stateStorage = .ready
                    self.lock.unlock()
                    continuation.resume()
                } catch {
                    self.lock.lock()
                    self.stateStorage = .failed(String(describing: error))
                    self.lock.unlock()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func shutdown() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workQueue.async {
                do {
                    try self.beginShuttingDownSync()
                    self.releasePainterAndPlatformSync()
                    self.unregisterAllNativesSync()
                    self.gateway.invalidate()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        do {
            try await jvm.shutdown()
        } catch {
            await setStateAsync(.failed(String(describing: error)))
            throw PlatformBootstrapError.jvmUnavailable(String(describing: error))
        }

        await setStateAsync(.shutdown)
    }

    func loadJar(url: URL) async throws -> FreeJ2MEJarLoadResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FreeJ2MEJarLoadResult, Error>) in
            workQueue.async {
                do {
                    let result = try self.loadJarSync(url: url)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func runJar() async throws -> FreeJ2MEJarRunResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FreeJ2MEJarRunResult, Error>) in
            workQueue.async {
                do {
                    let result = try self.runJarSync()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func verifyDisplay() async throws -> FreeJ2MEDisplayResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FreeJ2MEDisplayResult, Error>) in
            workQueue.async {
                do {
                    let result = try self.verifyDisplaySync()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func loadJarSync(url: URL) throws -> FreeJ2MEJarLoadResult {
        lock.lock()
        let currentState = stateStorage
        let platformObjectId = mobilePlatformObjectIdStorage
        lock.unlock()

        guard case .ready = currentState, let platformObjectId else {
            throw PlatformBootstrapError.invalidState(currentState)
        }

        let fileURL = Self.standardizedFileURL(from: url)
        try Self.validateJarURL(fileURL)
        let jarURLString = fileURL.absoluteString

        do {
            let platformClassId = try gateway.resolveClass(binaryName: FreeJ2ME.mobilePlatformBinaryName)
            let loadJarMethodId = try gateway.resolveMethod(
                classId: platformClassId,
                name: FreeJ2ME.loadJarName,
                signature: FreeJ2ME.loadJarSignature,
                isStatic: false
            )
            let loadedValue = try gateway.callInstance(
                objectId: platformObjectId,
                methodId: loadJarMethodId,
                arguments: [.string(jarURLString)],
                returning: .boolean
            )
            guard case .boolean(true) = loadedValue else {
                throw PlatformBootstrapError.loadJarFailed(jarURLString)
            }

            let supportClassId = try gateway.resolveClass(binaryName: JarLoad.supportBinaryName)
            let midletNameMethodId = try gateway.resolveMethod(
                classId: supportClassId,
                name: JarLoad.midletNameMethodName,
                signature: JarLoad.midletNameSignature,
                isStatic: true
            )
            let nameValue = try gateway.callStatic(
                classId: supportClassId,
                methodId: midletNameMethodId,
                arguments: [.object(platformObjectId)],
                returning: .string
            )
            guard case .string(let midletName) = nameValue, !midletName.isEmpty else {
                throw PlatformBootstrapError.malformedJar(jarURLString)
            }

            let result = FreeJ2MEJarLoadResult(midletName: midletName, jarURLString: jarURLString)
            lock.lock()
            lastJarLoadResultStorage = result
            // A new load invalidates any prior run / display verification for this session.
            lastJarRunResultStorage = nil
            lastDisplayResultStorage = nil
            lock.unlock()
            return result
        } catch let error as PlatformBootstrapError {
            throw error
        } catch {
            throw PlatformBootstrapError.gatewayFailure(String(describing: error))
        }
    }

    private func runJarSync() throws -> FreeJ2MEJarRunResult {
        lock.lock()
        let currentState = stateStorage
        let platformObjectId = mobilePlatformObjectIdStorage
        let loadResult = lastJarLoadResultStorage
        let priorRun = lastJarRunResultStorage
        lock.unlock()

        guard case .ready = currentState, let platformObjectId else {
            throw PlatformBootstrapError.invalidState(currentState)
        }
        guard let loadResult else {
            throw PlatformBootstrapError.midletNotLoaded
        }
        if priorRun != nil {
            throw PlatformBootstrapError.alreadyRunning
        }

        do {
            let supportClassId = try gateway.resolveClass(binaryName: JarRun.supportBinaryName)
            let verifyMethodId = try gateway.resolveMethod(
                classId: supportClassId,
                name: JarRun.runAndVerifyMethodName,
                signature: JarRun.runAndVerifySignature,
                isStatic: true
            )
            let verifyValue = try gateway.callStatic(
                classId: supportClassId,
                methodId: verifyMethodId,
                arguments: [.object(platformObjectId)],
                returning: .boolean
            )
            guard case .boolean(true) = verifyValue else {
                throw PlatformBootstrapError.runJarFailed(loadResult.jarURLString)
            }

            let result = FreeJ2MEJarRunResult(
                midletName: loadResult.midletName,
                jarURLString: loadResult.jarURLString,
                reachedStartApp: true
            )
            lock.lock()
            lastJarRunResultStorage = result
            lastDisplayResultStorage = nil
            lock.unlock()
            return result
        } catch let error as PlatformBootstrapError {
            throw error
        } catch {
            throw PlatformBootstrapError.gatewayFailure(String(describing: error))
        }
    }

    private func verifyDisplaySync() throws -> FreeJ2MEDisplayResult {
        lock.lock()
        let currentState = stateStorage
        let runResult = lastJarRunResultStorage
        lock.unlock()

        guard case .ready = currentState else {
            throw PlatformBootstrapError.invalidState(currentState)
        }
        guard let runResult else {
            throw PlatformBootstrapError.midletNotRunning
        }

        do {
            let supportClassId = try gateway.resolveClass(
                binaryName: DisplayInspection.supportBinaryName
            )
            let inspectMethodId = try gateway.resolveMethod(
                classId: supportClassId,
                name: DisplayInspection.inspectStatusMethodName,
                signature: DisplayInspection.inspectStatusSignature,
                isStatic: true
            )
            let statusValue = try gateway.callStatic(
                classId: supportClassId,
                methodId: inspectMethodId,
                arguments: [],
                returning: .string
            )
            guard case .string(let status) = statusValue else {
                throw PlatformBootstrapError.displayNotPresent
            }

            if status == DisplayInspection.statusNoDisplay {
                throw PlatformBootstrapError.displayNotPresent
            }
            if status == DisplayInspection.statusNoCurrent {
                throw PlatformBootstrapError.noCurrentDisplayable
            }
            guard status.hasPrefix(DisplayInspection.statusOKPrefix) else {
                throw PlatformBootstrapError.noCurrentDisplayable
            }

            let className = String(status.dropFirst(DisplayInspection.statusOKPrefix.count))
            let result = FreeJ2MEDisplayResult(
                midletName: runResult.midletName,
                jarURLString: runResult.jarURLString,
                displayInitialized: true,
                hasCurrentDisplayable: true,
                currentDisplayableClassName: className.isEmpty ? nil : className
            )
            lock.lock()
            lastDisplayResultStorage = result
            lock.unlock()
            return result
        } catch let error as PlatformBootstrapError {
            throw error
        } catch {
            throw PlatformBootstrapError.gatewayFailure(String(describing: error))
        }
    }

    private static func standardizedFileURL(from url: URL) -> URL {
        if url.isFileURL {
            return url.standardizedFileURL
        }
        return URL(fileURLWithPath: url.path).standardizedFileURL
    }

    private static func validateJarURL(_ fileURL: URL) throws {
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw PlatformBootstrapError.jarNotFound(path)
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw PlatformBootstrapError.jarNotReadable(path)
        }
    }

    private func setStateAsync(_ state: PlatformBootstrapState) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            workQueue.async {
                self.lock.lock()
                self.stateStorage = state
                self.lock.unlock()
                continuation.resume()
            }
        }
    }

    private func beginStartingSync() throws {
        lock.lock()
        defer { lock.unlock() }
        switch stateStorage {
        case .uninitialized, .shutdown:
            stateStorage = .starting
            paintCountStorage = 0
            heartbeatCountStorage = 0
        case .ready, .starting, .shuttingDown, .failed:
            throw PlatformBootstrapError.invalidState(stateStorage)
        }
    }

    private func beginShuttingDownSync() throws {
        lock.lock()
        defer { lock.unlock() }
        switch stateStorage {
        case .ready, .starting, .failed, .uninitialized:
            stateStorage = .shuttingDown
        case .shuttingDown, .shutdown:
            throw PlatformBootstrapError.invalidState(stateStorage)
        }
    }

    private func bindGatewayRegisterAndCreatePlatformSync() throws {
        do {
            try gateway.bind()
            try registerInfrastructureNativesSync()
            try createAndBindMobilePlatformSync()
            try installPainterSync()
        } catch let error as PlatformBootstrapError {
            releasePainterAndPlatformSync()
            gateway.invalidate()
            throw error
        } catch {
            releasePainterAndPlatformSync()
            gateway.invalidate()
            throw PlatformBootstrapError.gatewayFailure(String(describing: error))
        }
    }

    private func registerInfrastructureNativesSync() throws {
        let classId = try gateway.resolveClass(binaryName: Infrastructure.callbackHostBinaryName)
        let registration = try gateway.registerNative(
            classId: classId,
            methodName: Infrastructure.heartbeatMethodName,
            signature: Infrastructure.heartbeatSignature,
            isStatic: true
        ) { [weak self] _ in
            self?.noteHeartbeat()
            return .void
        }
        lock.lock()
        nativeRegistrations.append(registration)
        lock.unlock()
    }

    private func createAndBindMobilePlatformSync() throws {
        let mobileClassId = try gateway.resolveClass(binaryName: FreeJ2ME.mobileBinaryName)
        let platformClassId = try gateway.resolveClass(binaryName: FreeJ2ME.mobilePlatformBinaryName)
        let constructorId = try gateway.resolveMethod(
            classId: platformClassId,
            name: FreeJ2ME.constructorName,
            signature: FreeJ2ME.constructorSignature,
            isStatic: false
        )
        let platformObjectId = try gateway.createGlobalObjectReference(
            classId: platformClassId,
            constructorMethodId: constructorId,
            arguments: [.int(lcdWidth), .int(lcdHeight)]
        )
        lock.lock()
        mobilePlatformObjectIdStorage = platformObjectId
        lock.unlock()

        let setPlatformId = try gateway.resolveMethod(
            classId: mobileClassId,
            name: FreeJ2ME.setPlatformName,
            signature: FreeJ2ME.setPlatformSignature,
            isStatic: true
        )
        _ = try gateway.callStatic(
            classId: mobileClassId,
            methodId: setPlatformId,
            arguments: [.object(platformObjectId)],
            returning: .void
        )
    }

    private func installPainterSync() throws {
        guard let platformObjectId = mobilePlatformObjectIdStorage else {
            throw PlatformBootstrapError.gatewayFailure("MobilePlatform handle missing before setPainter")
        }

        let painterClassId = try gateway.resolveClass(binaryName: Painter.binaryName)
        let registration = try gateway.registerNative(
            classId: painterClassId,
            methodName: Painter.runMethodName,
            signature: Painter.runSignature,
            isStatic: false
        ) { [weak self] _ in
            self?.notePaint()
            return .void
        }
        lock.lock()
        nativeRegistrations.append(registration)
        lock.unlock()

        let constructorId = try gateway.resolveMethod(
            classId: painterClassId,
            name: Painter.constructorName,
            signature: Painter.constructorSignature,
            isStatic: false
        )
        let painterObjectId = try gateway.createGlobalObjectReference(
            classId: painterClassId,
            constructorMethodId: constructorId,
            arguments: []
        )
        lock.lock()
        painterObjectIdStorage = painterObjectId
        lock.unlock()

        let platformClassId = try gateway.resolveClass(binaryName: FreeJ2ME.mobilePlatformBinaryName)
        let setPainterId = try gateway.resolveMethod(
            classId: platformClassId,
            name: FreeJ2ME.setPainterName,
            signature: FreeJ2ME.setPainterSignature,
            isStatic: false
        )
        _ = try gateway.callInstance(
            objectId: platformObjectId,
            methodId: setPainterId,
            arguments: [.object(painterObjectId)],
            returning: .void
        )
    }

    private func noteHeartbeat() {
        lock.lock()
        heartbeatCountStorage += 1
        lock.unlock()
    }

    private func notePaint() {
        lock.lock()
        paintCountStorage += 1
        lock.unlock()
    }

    private func releasePainterAndPlatformSync() {
        lock.lock()
        let painterId = painterObjectIdStorage
        let platformId = mobilePlatformObjectIdStorage
        painterObjectIdStorage = nil
        mobilePlatformObjectIdStorage = nil
        lastJarLoadResultStorage = nil
        lastJarRunResultStorage = nil
        lastDisplayResultStorage = nil
        lock.unlock()
        if let painterId {
            try? gateway.releaseObjectReference(painterId)
        }
        if let platformId {
            try? gateway.releaseObjectReference(platformId)
        }
    }

    private func unregisterAllNativesSync() {
        lock.lock()
        let registrations = nativeRegistrations
        nativeRegistrations.removeAll(keepingCapacity: false)
        lock.unlock()
        for registration in registrations {
            try? gateway.unregisterNative(registration)
        }
    }
}
