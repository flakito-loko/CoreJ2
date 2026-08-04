import Foundation

/// Session metrics for the production persistent JVM bootstrap (E5-US005).
struct PersistentRuntimeBootstrapMetrics: Equatable, Sendable {
    /// Wall time from process start to `READY`.
    var jvmStartupNanoseconds: UInt64 = 0
    /// Wall time for the full Contract C sequence after JVM is ready (CREATE…RUN).
    var launchLatencyNanoseconds: UInt64 = 0
    /// Approximate child RSS after a warm session (bytes).
    var approximateMemoryBytes: UInt64 = 0
    /// Number of `Process.run` invocations (must stay 1 per session).
    var jvmLaunchCount: Int = 0
    /// Daemon `MobilePlatform` identity hash, stable for the session.
    var platformIdentity: Int?
    /// FRAME lines observed (registration + post-run).
    var frameCount: Int = 0
    /// `true` after a successful `SHUTDOWN`.
    var cleanShutdown: Bool = false
}

#if os(macOS)

/// Production bootstrap that drives FreeJ2ME through one persistent JVM daemon.
///
/// Replaces ephemeral Process-per-hook for macOS host sessions. Uses
/// `PersistentMobilePlatformDaemon` (JavaOne-owned). Does not modify FreeJ2ME.
///
/// Rollback: inject `ProcessFreeJ2MEMobilePlatformBootstrap` into the adapter.
@MainActor
final class PersistentProcessFreeJ2MEMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {

    // MARK: - Protocol

    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?

    // MARK: - Metrics

    private(set) var metrics = PersistentRuntimeBootstrapMetrics()

    // MARK: - Process State

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutBuffer = Data()
    private var pendingLines: [String] = []
    private var streamFramesToHandler = false
    private var collectedRegistrationFrames: [FreeJ2MEFrameCapture] = []
    private let frameDirectory: URL
    private var sessionLaunchStart: UInt64?

    // MARK: - Init

    init(
        frameDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOnePersistentRuntime-\(UUID().uuidString)", isDirectory: true)
    ) {
        self.frameDirectory = frameDirectory
    }

    // MARK: - FreeJ2MEMobilePlatformBootstrapping

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        try ensureDaemonRunning()
        sessionLaunchStart = DispatchTime.now().uptimeNanoseconds
        let line = try send(
            "CREATE \(lcdWidth) \(lcdHeight)",
            expectPrefix: "OK CREATE",
            timeoutSeconds: 30
        )
        metrics.platformIdentity = Self.parseIdentity(line)
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        _ = lcdWidth
        _ = lcdHeight
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        collectedRegistrationFrames = []
        streamFramesToHandler = false

        try writeCommand("PAINTER \(frameDirectory.path(percentEncoded: false))")
        let deadline = Date().addingTimeInterval(60)
        var okLine: String?
        while Date() < deadline {
            let line = try awaitNextLine(timeoutSeconds: deadline.timeIntervalSinceNow)
            if line.hasPrefix("FRAME ") {
                if let frame = Self.parseFrameLine(line) {
                    collectedRegistrationFrames.append(frame)
                    metrics.frameCount += 1
                }
                continue
            }
            if line.hasPrefix("OK PAINTER") {
                okLine = line
                break
            }
            if line.hasPrefix("ERR ") {
                throw EmulatorBridgeError.launchFailed
            }
        }
        guard okLine != nil, collectedRegistrationFrames.count >= 2 else {
            throw EmulatorBridgeError.launchFailed
        }

        streamFramesToHandler = true
        return FreeJ2MEPainterRegistrationResult(
            paintEventCount: collectedRegistrationFrames.count,
            frames: collectedRegistrationFrames
        )
    }

    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        _ = lcdWidth
        _ = lcdHeight
        let line = try send(
            "LOAD \(jarFileURLString)",
            expectPrefix: "OK LOAD",
            timeoutSeconds: 60
        )
        let name = Self.parseName(line) ?? "Unknown"
        return FreeJ2MEJarLoadResult(midletName: name, jarURLString: jarFileURLString)
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        _ = lcdWidth
        _ = lcdHeight
        let line = try send("RUN", expectPrefix: "OK RUN", timeoutSeconds: 60)
        guard line.contains("started=true") else {
            throw EmulatorBridgeError.launchFailed
        }
        let name = Self.parseName(line) ?? "Unknown"

        // Ensure at least one frame after runJar on the live painter (ProbeMIDlets
        // may not paint; real games also benefit from an immediate LCD snapshot).
        try sendExpectingFramesThenOK(
            command: "FRAME_PROBE",
            okPrefix: "OK FRAME_PROBE",
            minimumFrames: 1,
            timeoutSeconds: 30
        )

        if let start = sessionLaunchStart {
            metrics.launchLatencyNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            sessionLaunchStart = nil
        }
        sampleMemory()

        return FreeJ2MEJarRunResult(
            midletName: name,
            jarURLString: jarFileURLString,
            reachedStartApp: true
        )
    }

    func shutdownRuntime() throws {
        guard process != nil else { return }
        do {
            let response = try send("STOP", expectPrefix: "OK STOP", timeoutSeconds: 30)
            _ = response
        } catch {
            // Continue to SHUTDOWN even if STOP fails.
        }
        streamFramesToHandler = false
        do {
            let response = try send("SHUTDOWN", expectPrefix: "OK SHUTDOWN", timeoutSeconds: 30)
            metrics.cleanShutdown = response.hasPrefix("OK SHUTDOWN")
        } catch {
            metrics.cleanShutdown = false
            forceTerminate()
            throw EmulatorBridgeError.launchFailed
        }
        tearDownProcessHandles()
        process?.waitUntilExit()
        process = nil
        metrics.platformIdentity = nil
    }

    // MARK: - Daemon Lifecycle

    private func ensureDaemonRunning() throws {
        if let process, process.isRunning {
            return
        }
        try startDaemon()
    }

    private func startDaemon() throws {
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        metrics = PersistentRuntimeBootstrapMetrics()

        let javaHome = try Self.resolveJavaHome()
        let classes = try Self.ensureCompiledClasses(javaHome: javaHome)
        let child = Process()
        child.executableURL = javaHome.appendingPathComponent("bin/java")
        child.arguments = [
            "-Djava.awt.headless=true",
            "-Djava.security.manager=allow",
            "-cp", classes.path(percentEncoded: false),
            "org.javaone.freej2me.PersistentMobilePlatformDaemon"
        ]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = Pipe()

        let startupStart = DispatchTime.now().uptimeNanoseconds
        do {
            try child.run()
        } catch {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        metrics.jvmLaunchCount += 1
        process = child
        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutBuffer = Data()
        pendingLines = []

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.ingest(stdout: data)
            }
        }

        let ready = try awaitLine(prefix: "READY", timeoutSeconds: 60)
        metrics.jvmStartupNanoseconds = DispatchTime.now().uptimeNanoseconds - startupStart
        guard ready.hasPrefix("READY") else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
    }

    private func forceTerminate() {
        tearDownProcessHandles()
        process?.terminate()
        process?.waitUntilExit()
        process = nil
    }

    private func tearDownProcessHandles() {
        stdinHandle?.closeFile()
        stdinHandle = nil
        if let stdout = process?.standardOutput as? Pipe {
            stdout.fileHandleForReading.readabilityHandler = nil
        }
    }

    private func sampleMemory() {
        guard let pid = process?.processIdentifier else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-o", "rss=", "-p", String(pid)]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let kilobytes = UInt64(text) {
                metrics.approximateMemoryBytes = kilobytes * 1024
            }
        } catch {
            // Best-effort.
        }
    }

    // MARK: - IPC

    private func send(_ command: String, expectPrefix: String, timeoutSeconds: TimeInterval) throws -> String {
        try writeCommand(command)
        return try awaitLine(prefix: expectPrefix, timeoutSeconds: timeoutSeconds)
    }

    private func sendExpectingFramesThenOK(
        command: String,
        okPrefix: String,
        minimumFrames: Int,
        timeoutSeconds: TimeInterval
    ) throws {
        try writeCommand(command)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var frames = 0
        while Date() < deadline {
            let line = try awaitNextLine(timeoutSeconds: deadline.timeIntervalSinceNow)
            if line.hasPrefix("FRAME ") {
                frames += 1
                metrics.frameCount += 1
                // `frameHandler` is invoked from `ingest` when streaming is enabled.
                continue
            }
            if line.hasPrefix(okPrefix) {
                guard frames >= minimumFrames else {
                    throw EmulatorBridgeError.launchFailed
                }
                return
            }
            if line.hasPrefix("ERR ") {
                throw EmulatorBridgeError.launchFailed
            }
        }
        throw EmulatorBridgeError.launchFailed
    }

    private func writeCommand(_ command: String) throws {
        guard let stdinHandle, let process, process.isRunning else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        var payload = Data(command.utf8)
        payload.append(0x0A)
        try stdinHandle.write(contentsOf: payload)
    }

    private func ingest(stdout data: Data) {
        stdoutBuffer.append(data)
        while let range = stdoutBuffer.range(of: Data([0x0A])) {
            let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<range.lowerBound)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex..<range.upperBound)
            guard let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !line.isEmpty else {
                continue
            }
            if streamFramesToHandler, line.hasPrefix("FRAME "), let frame = Self.parseFrameLine(line) {
                // Async paints (and frames observed while awaiting commands).
                frameHandler?(frame)
            }
            pendingLines.append(line)
        }
    }

    private func awaitLine(prefix: String, timeoutSeconds: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let index = pendingLines.firstIndex(where: {
                $0.hasPrefix(prefix) || $0.hasPrefix("ERR ")
            }) {
                let line = pendingLines.remove(at: index)
                if line.hasPrefix("ERR ") {
                    throw EmulatorBridgeError.launchFailed
                }
                return line
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        throw EmulatorBridgeError.launchFailed
    }

    private func awaitNextLine(timeoutSeconds: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(max(timeoutSeconds, 0.01))
        while Date() < deadline {
            if !pendingLines.isEmpty {
                return pendingLines.removeFirst()
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        throw EmulatorBridgeError.launchFailed
    }

    // MARK: - Parsing / resolve

    private static func parseIdentity(_ line: String) -> Int? {
        guard let idPart = line.split(separator: " ").first(where: { $0.hasPrefix("id=") }) else {
            return nil
        }
        return Int(idPart.dropFirst(3))
    }

    private static func parseName(_ line: String) -> String? {
        guard let namePart = line.split(separator: " ").first(where: { $0.hasPrefix("name=") }) else {
            return nil
        }
        let raw = String(namePart.dropFirst(5))
        // Names may contain spaces encoded as remaining tokens after name= in OK lines:
        // OK LOAD name=Probe MIDlet id=…
        if let range = line.range(of: "name=") {
            let after = line[range.upperBound...]
            if let idRange = after.range(of: " id=") {
                return String(after[..<idRange.lowerBound])
            }
            return String(after)
        }
        return raw.isEmpty ? nil : raw
    }

    private static func parseFrameLine(_ line: String) -> FreeJ2MEFrameCapture? {
        let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 7, parts[0] == "FRAME",
              let paintIndex = Int(parts[1]),
              let width = Int(parts[2]),
              let height = Int(parts[3]),
              let pixelCount = Int(parts[4]),
              let checksum = UInt64(parts[5]) else {
            return nil
        }
        let pixelFormat = parts[6]
        let path = parts[7...].joined(separator: " ")
        guard !path.isEmpty,
              let pixels = try? Data(contentsOf: URL(fileURLWithPath: path)),
              pixels.count == pixelCount * 4 else {
            return nil
        }
        return FreeJ2MEFrameCapture(
            paintIndex: paintIndex,
            width: width,
            height: height,
            pixelCount: pixelCount,
            checksum: checksum,
            pixelFormat: pixelFormat,
            pixels: pixels
        )
    }

    private static func resolveJavaHome() throws -> URL {
        if let environment = ProcessInfo.processInfo.environment["JAVA_HOME"],
           !environment.isEmpty {
            let home = URL(fileURLWithPath: environment, isDirectory: true)
            if FileManager.default.isExecutableFile(atPath: home.appendingPathComponent("bin/java").path) {
                return home
            }
        }
        throw EmulatorBridgeError.runtimeUnavailable
    }

    private static func ensureCompiledClasses(javaHome: URL) throws -> URL {
        let vendorRoot = try resolveVendorRoot()
        let daemonSource = try resolveDaemonSource()
        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOnePersistentRuntimePOC", isDirectory: true)
        let classesDirectory = cacheRoot.appendingPathComponent("classes", isDirectory: true)
        let stampFile = cacheRoot.appendingPathComponent("classpath.stamp")

        let mobilePlatformSource = vendorRoot
            .appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
        let stampPayload = [
            mobilePlatformSource.path(percentEncoded: false),
            daemonSource.path(percentEncoded: false),
            modificationDateString(for: mobilePlatformSource),
            modificationDateString(for: daemonSource)
        ].joined(separator: "|")

        let daemonClass = classesDirectory
            .appendingPathComponent("org/javaone/freej2me/PersistentMobilePlatformDaemon.class")
        if FileManager.default.fileExists(atPath: daemonClass.path),
           let existing = try? String(contentsOf: stampFile, encoding: .utf8),
           existing == stampPayload {
            return classesDirectory
        }

        try? FileManager.default.removeItem(at: classesDirectory)
        try FileManager.default.createDirectory(at: classesDirectory, withIntermediateDirectories: true)

        let sourcesList = cacheRoot.appendingPathComponent("sources.txt")
        let vendorSources = try FileManager.default
            .subpathsOfDirectory(atPath: vendorRoot.appendingPathComponent("src").path)
            .filter { $0.hasSuffix(".java") }
            .map {
                vendorRoot.appendingPathComponent("src").appendingPathComponent($0)
                    .path(percentEncoded: false)
            }
            .sorted()
        let allSources = vendorSources + [daemonSource.path(percentEncoded: false)]
        try allSources.joined(separator: "\n").write(to: sourcesList, atomically: true, encoding: .utf8)

        let javac = Process()
        javac.executableURL = javaHome.appendingPathComponent("bin/javac")
        javac.arguments = [
            "-encoding", "UTF-8",
            "-g",
            "-d", classesDirectory.path(percentEncoded: false),
            "@\(sourcesList.path(percentEncoded: false))"
        ]
        javac.standardOutput = Pipe()
        javac.standardError = Pipe()
        do {
            try javac.run()
            javac.waitUntilExit()
        } catch {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        guard javac.terminationStatus == 0 else {
            throw EmulatorBridgeError.launchFailed
        }
        try stampPayload.write(to: stampFile, atomically: true, encoding: .utf8)
        return classesDirectory
    }

    private static func resolveVendorRoot() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["JAVAONE_FREEJ2ME_ROOT"],
           !override.isEmpty {
            let root = URL(fileURLWithPath: override, isDirectory: true)
            let marker = root.appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
            guard FileManager.default.fileExists(atPath: marker.path) else {
                throw EmulatorBridgeError.runtimeUnavailable
            }
            return root
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        let root = url.appendingPathComponent("Vendor/FreeJ2ME", isDirectory: true)
        let marker = root.appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        return root
    }

    private static func resolveDaemonSource() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        let source = url
            .appendingPathComponent("Bootstrap")
            .appendingPathComponent("PersistentMobilePlatformDaemon.java")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        return source
    }

    private static func modificationDateString(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        if let date = values?.contentModificationDate {
            return String(date.timeIntervalSince1970)
        }
        return "missing"
    }
}

#else

/// iOS stub — persistent Process bootstrap is unavailable without a host JVM.
@MainActor
final class PersistentProcessFreeJ2MEMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?
    private(set) var metrics = PersistentRuntimeBootstrapMetrics()

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        _ = lcdWidth
        _ = lcdHeight
        throw EmulatorBridgeError.runtimeUnavailable
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        _ = lcdWidth
        _ = lcdHeight
        throw EmulatorBridgeError.runtimeUnavailable
    }

    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        _ = lcdWidth
        _ = lcdHeight
        _ = jarFileURLString
        throw EmulatorBridgeError.runtimeUnavailable
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        _ = lcdWidth
        _ = lcdHeight
        _ = jarFileURLString
        throw EmulatorBridgeError.runtimeUnavailable
    }

    func shutdownRuntime() throws {}
}

#endif
