import Foundation

#if os(macOS)

/// Metrics captured by the persistent-runtime proof of concept (E5-US004).
struct PersistentRuntimePOCMetrics: Equatable, Sendable {
    /// Wall time to start the JVM and receive `READY`.
    var jvmStartupNanoseconds: UInt64 = 0
    /// Per-command round-trip latencies (command name → ns).
    var commandLatenciesNanoseconds: [String: UInt64] = [:]
    /// Approximate resident memory of the Java child after the session is warm (bytes).
    var approximateMemoryBytes: UInt64 = 0
    /// Number of times `Process.run` was invoked for the daemon (must be 1).
    var jvmLaunchCount: Int = 0
    /// Platform identity hash echoed by the daemon (stable across commands).
    var platformIdentity: Int?
    /// FRAME lines observed during the session.
    var frameCount: Int = 0
    /// Whether shutdown completed with `OK SHUTDOWN`.
    var cleanShutdown: Bool = false
    /// Recovered from a deliberate bad command without killing the JVM.
    var failureRecoverySucceeded: Bool = false
}

/// Line-oriented IPC client for `PersistentMobilePlatformDaemon`.
///
/// Isolated proof of concept — not wired into `AppDependencyContainer`,
/// SwiftUI, or `ProcessFreeJ2MEMobilePlatformBootstrap`.
@MainActor
final class PersistentRuntimePOCClient {

    // MARK: - Types

    enum POCError: Error, Equatable {
        case runtimeUnavailable
        case launchFailed(String)
        case unexpectedResponse(String)
        case timeout
    }

    // MARK: - Properties

    private(set) var metrics = PersistentRuntimePOCMetrics()
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutBuffer = Data()
    private var pendingLines: [String] = []
    private let frameDirectory: URL

    // MARK: - Init

    init(frameDirectory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("JavaOnePersistentPOC-\(UUID().uuidString)", isDirectory: true)
    ) {
        self.frameDirectory = frameDirectory
    }

    // MARK: - Lifecycle

    /// Starts exactly one JVM running the persistent daemon and waits for `READY`.
    func start() throws {
        guard process == nil else {
            throw POCError.launchFailed("daemon already started")
        }

        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)

        let javaHome = try Self.resolveJavaHome()
        let classes = try Self.ensureCompiledClasses(javaHome: javaHome)
        let javaURL = javaHome.appendingPathComponent("bin/java")

        let child = Process()
        child.executableURL = javaURL
        child.arguments = [
            "-Djava.awt.headless=true",
            "-Djava.security.manager=allow",
            "-cp", classes.path(percentEncoded: false),
            "org.javaone.freej2me.PersistentMobilePlatformDaemon"
        ]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe

        let startupStart = DispatchTime.now().uptimeNanoseconds
        do {
            try child.run()
        } catch {
            throw POCError.runtimeUnavailable
        }
        metrics.jvmLaunchCount += 1
        process = child
        stdinHandle = stdinPipe.fileHandleForWriting

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
            throw POCError.unexpectedResponse(ready)
        }
    }

    /// Sends `SHUTDOWN` and waits for the process to exit.
    func shutdown() throws {
        let response = try send("SHUTDOWN", expectPrefix: "OK SHUTDOWN", timeoutSeconds: 30)
        metrics.cleanShutdown = response.hasPrefix("OK SHUTDOWN")
        stdinHandle?.closeFile()
        stdinHandle = nil
        if let stdout = process?.standardOutput as? Pipe {
            stdout.fileHandleForReading.readabilityHandler = nil
        }
        process?.waitUntilExit()
        process = nil
    }

    // MARK: - Commands

    @discardableResult
    func create(width: Int = 240, height: Int = 320) throws -> String {
        let line = try timed("CREATE") {
            try send("CREATE \(width) \(height)", expectPrefix: "OK CREATE", timeoutSeconds: 30)
        }
        metrics.platformIdentity = Self.parseIdentity(line)
        return line
    }

    @discardableResult
    func registerPainter() throws -> String {
        try timed("PAINTER") {
            // Drain synthetic FRAME lines then OK PAINTER.
            try sendExpectingFramesThenOK(
                command: "PAINTER \(frameDirectory.path(percentEncoded: false))",
                okPrefix: "OK PAINTER",
                minimumFrames: 2,
                timeoutSeconds: 30
            )
        }
    }

    @discardableResult
    func load(jarFileURLString: String) throws -> String {
        try timed("LOAD") {
            try send("LOAD \(jarFileURLString)", expectPrefix: "OK LOAD", timeoutSeconds: 60)
        }
    }

    @discardableResult
    func runJar() throws -> String {
        try timed("RUN") {
            try send("RUN", expectPrefix: "OK RUN", timeoutSeconds: 60)
        }
    }

    @discardableResult
    func frameProbe() throws -> String {
        try timed("FRAME_PROBE") {
            try sendExpectingFramesThenOK(
                command: "FRAME_PROBE",
                okPrefix: "OK FRAME_PROBE",
                minimumFrames: 1,
                timeoutSeconds: 30
            )
        }
    }

    @discardableResult
    func ping() throws -> String {
        try timed("PING") {
            try send("PING", expectPrefix: "OK PING", timeoutSeconds: 15)
        }
    }

    @discardableResult
    func stop() throws -> String {
        try timed("STOP") {
            try send("STOP", expectPrefix: "OK STOP", timeoutSeconds: 30)
        }
    }

    /// Sends an invalid command; expects `ERR` while the process stays alive.
    func probeFailureRecovery() throws {
        let err = try send("NOT_A_REAL_COMMAND", expectPrefix: "ERR", timeoutSeconds: 15)
        let stillAlive = try ping()
        metrics.failureRecoverySucceeded =
            err.hasPrefix("ERR") && stillAlive.hasPrefix("OK PING")
    }

    /// Samples approximate RSS for the Java child via `ps`.
    func sampleMemory() {
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
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let kilobytes = UInt64(text) {
                metrics.approximateMemoryBytes = kilobytes * 1024
            }
        } catch {
            // Best-effort metric only.
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
    ) throws -> String {
        try writeCommand(command)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var frames = 0
        var okLine: String?
        while Date() < deadline {
            let line = try awaitNextLine(timeoutSeconds: deadline.timeIntervalSinceNow)
            if line.hasPrefix("FRAME ") {
                frames += 1
                metrics.frameCount += 1
                continue
            }
            if line.hasPrefix(okPrefix) {
                okLine = line
                break
            }
            if line.hasPrefix("ERR ") {
                throw POCError.launchFailed(line)
            }
        }
        guard let okLine else { throw POCError.timeout }
        guard frames >= minimumFrames else {
            throw POCError.launchFailed("expected \(minimumFrames) frames, got \(frames)")
        }
        return okLine
    }

    private func writeCommand(_ command: String) throws {
        guard let stdinHandle, let process, process.isRunning else {
            throw POCError.runtimeUnavailable
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
            if let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty {
                pendingLines.append(line)
            }
        }
    }

    private func awaitLine(prefix: String, timeoutSeconds: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let index = pendingLines.firstIndex(where: { $0.hasPrefix(prefix) || $0.hasPrefix("ERR ") }) {
                let line = pendingLines.remove(at: index)
                if line.hasPrefix("ERR ") {
                    throw POCError.launchFailed(line)
                }
                return line
            }
            // Pump any already-buffered data; readabilityHandler may lag in tests.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        throw POCError.timeout
    }

    private func awaitNextLine(timeoutSeconds: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(max(timeoutSeconds, 0.01))
        while Date() < deadline {
            if !pendingLines.isEmpty {
                return pendingLines.removeFirst()
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        throw POCError.timeout
    }

    private func timed(_ name: String, work: () throws -> String) rethrows -> String {
        let start = DispatchTime.now().uptimeNanoseconds
        let result = try work()
        metrics.commandLatenciesNanoseconds[name] =
            DispatchTime.now().uptimeNanoseconds - start
        return result
    }

    private static func parseIdentity(_ line: String) -> Int? {
        // OK CREATE id=123 w=240 h=320
        guard let idPart = line.split(separator: " ").first(where: { $0.hasPrefix("id=") }) else {
            return nil
        }
        return Int(idPart.dropFirst(3))
    }

    // MARK: - Compile / resolve

    private static func resolveJavaHome() throws -> URL {
        if let environment = ProcessInfo.processInfo.environment["JAVA_HOME"],
           !environment.isEmpty {
            let home = URL(fileURLWithPath: environment, isDirectory: true)
            if FileManager.default.isExecutableFile(atPath: home.appendingPathComponent("bin/java").path) {
                return home
            }
        }
        throw POCError.runtimeUnavailable
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
                vendorRoot
                    .appendingPathComponent("src")
                    .appendingPathComponent($0)
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
            throw POCError.runtimeUnavailable
        }
        guard javac.terminationStatus == 0 else {
            throw POCError.launchFailed("javac failed for PersistentMobilePlatformDaemon")
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
                throw POCError.runtimeUnavailable
            }
            return root
        }
        var url = URL(fileURLWithPath: #filePath)
        // …/JavaOne/Features/Emulator/Runtime/POC/ThisFile.swift → repo root
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        let root = url.appendingPathComponent("Vendor/FreeJ2ME", isDirectory: true)
        let marker = root.appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw POCError.runtimeUnavailable
        }
        return root
    }

    private static func resolveDaemonSource() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        // …/Runtime/POC/ThisFile.swift → …/Runtime/Bootstrap/PersistentMobilePlatformDaemon.java
        url.deleteLastPathComponent()
        let source = url
            .appendingPathComponent("Bootstrap")
            .appendingPathComponent("PersistentMobilePlatformDaemon.java")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw POCError.runtimeUnavailable
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

/// iOS stub — persistent Process POC is macOS-only.
@MainActor
final class PersistentRuntimePOCClient {
    struct POCError: Error {
        static let runtimeUnavailable = POCError()
    }

    private(set) var metrics = PersistentRuntimePOCMetrics()

    func start() throws {
        throw POCError.runtimeUnavailable
    }
}

struct PersistentRuntimePOCMetrics: Equatable, Sendable {
    var jvmStartupNanoseconds: UInt64 = 0
    var commandLatenciesNanoseconds: [String: UInt64] = [:]
    var approximateMemoryBytes: UInt64 = 0
    var jvmLaunchCount: Int = 0
    var platformIdentity: Int?
    var frameCount: Int = 0
    var cleanShutdown: Bool = false
    var failureRecoverySucceeded: Bool = false
}

#endif
