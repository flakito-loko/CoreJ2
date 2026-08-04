import Foundation

/// Executes FreeJ2ME `MobilePlatform` construction, painter, `loadJar`, and `runJar`.
@MainActor
protocol FreeJ2MEMobilePlatformBootstrapping: AnyObject {

    /// Optional handler for FRAME records streamed after painter registration.
    ///
    /// Ephemeral bootstraps may leave this unused. Persistent bootstraps invoke it
    /// for paints that arrive after `registerPainter` returns (including post-`runJar`).
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)? { get set }

    /// Instantiates FreeJ2ME `MobilePlatform` and binds it via `Mobile.setPlatform`.
    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws

    /// Registers a capturing `Runnable` via `MobilePlatform.setPainter(...)`.
    ///
    /// On each paint the host reads `getLCD()` and returns framebuffer metadata.
    /// Does not extract frames to Metal/SwiftUI or publish `RuntimeEvent`.
    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult

    /// Calls FreeJ2ME `MobilePlatform.loadJar(jarFileURLString)`.
    ///
    /// Does not call `runJar()` or start a MIDlet.
    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult

    /// Calls FreeJ2ME `MobilePlatform.runJar()` after platform + painter + `loadJar`
    /// in one host JVM process (loader state is in-process).
    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult

    /// Tears down the session and releases the runtime (persistent JVM shutdown).
    ///
    /// Ephemeral bootstraps are no-ops. Safe to call when no runtime is active.
    func shutdownRuntime() throws
}

/// Host-JVM bootstrap for FreeJ2ME Contract C hooks.
///
/// On macOS (host), compiles vendored FreeJ2ME (if needed) and runs
/// `org.javaone.freej2me.MobilePlatformBootstrap` in a child process.
///
/// On iOS there is no `Process` API and no App Store JVM, so this type throws
/// `runtimeUnavailable`. FreeJ2ME sources were not modified.
@MainActor
final class ProcessFreeJ2MEMobilePlatformBootstrap: FreeJ2MEMobilePlatformBootstrapping {

    // MARK: - Properties

    /// Unused by the ephemeral Process-per-hook bootstrap (kept for protocol conformance).
    var frameHandler: ((FreeJ2MEFrameCapture) -> Void)?

    // MARK: - Init

    init() {}

    // MARK: - FreeJ2MEMobilePlatformBootstrapping

    func bootstrapMobilePlatform(lcdWidth: Int, lcdHeight: Int) throws {
        #if os(macOS)
        _ = try runHostJVMBootstrap(arguments: [String(lcdWidth), String(lcdHeight)])
        #else
        _ = lcdWidth
        _ = lcdHeight
        throw EmulatorBridgeError.runtimeUnavailable
        #endif
    }

    func registerPainter(lcdWidth: Int, lcdHeight: Int) throws -> FreeJ2MEPainterRegistrationResult {
        #if os(macOS)
        let frameDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOneFrames-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: frameDirectory) }

        let output = try runHostJVMBootstrap(
            arguments: [
                String(lcdWidth),
                String(lcdHeight),
                "register-painter",
                frameDirectory.path(percentEncoded: false)
            ]
        )
        return try Self.parsePainterOutput(
            stdout: output.stdout,
            status: output.status,
            expectedWidth: lcdWidth,
            expectedHeight: lcdHeight
        )
        #else
        _ = lcdWidth
        _ = lcdHeight
        throw EmulatorBridgeError.runtimeUnavailable
        #endif
    }

    func loadJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        #if os(macOS)
        let output = try runHostJVMBootstrap(
            arguments: [
                String(lcdWidth),
                String(lcdHeight),
                "load-jar",
                jarFileURLString
            ]
        )
        return try Self.parseLoadJarOutput(
            stdout: output.stdout,
            status: output.status,
            jarFileURLString: jarFileURLString
        )
        #else
        _ = lcdWidth
        _ = lcdHeight
        _ = jarFileURLString
        throw EmulatorBridgeError.runtimeUnavailable
        #endif
    }

    func runJar(
        lcdWidth: Int,
        lcdHeight: Int,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        #if os(macOS)
        let output = try runHostJVMBootstrap(
            arguments: [
                String(lcdWidth),
                String(lcdHeight),
                "run-jar",
                jarFileURLString
            ]
        )
        return try Self.parseRunJarOutput(
            stdout: output.stdout,
            status: output.status,
            jarFileURLString: jarFileURLString
        )
        #else
        _ = lcdWidth
        _ = lcdHeight
        _ = jarFileURLString
        throw EmulatorBridgeError.runtimeUnavailable
        #endif
    }

    /// Ephemeral bootstrap has no long-lived JVM to tear down.
    func shutdownRuntime() throws {}

    #if os(macOS)

    // MARK: - Host JVM

    private struct HostJVMOutput {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private func runHostJVMBootstrap(arguments: [String]) throws -> HostJVMOutput {
        let javaHome = try Self.resolveJavaHome()
        let vendorRoot = try Self.resolveVendorRoot()
        let bootstrapSource = try Self.resolveBootstrapSource()
        let classesDirectory = try Self.ensureCompiledClasses(
            javaHome: javaHome,
            vendorRoot: vendorRoot,
            bootstrapSource: bootstrapSource
        )

        let javaURL = javaHome.appendingPathComponent("bin/java")
        let process = Process()
        process.executableURL = javaURL
        process.arguments = [
            "-Djava.awt.headless=true",
            // Required on JDK 17+ so the bootstrap can install an exit-only SecurityManager
            // that blocks FreeJ2ME's System.exit failure paths without forking Vendor.
            "-Djava.security.manager=allow",
            "-cp", classesDirectory.path(percentEncoded: false),
            "org.javaone.freej2me.MobilePlatformBootstrap"
        ] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw EmulatorBridgeError.runtimeUnavailable
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = HostJVMOutput(
            status: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )

        // Platform modes fail closed on non-zero status.
        // `register-painter` / `load-jar` / `run-jar` map status via their parsers.
        let mapsOwnStatus =
            arguments.contains("register-painter")
            || arguments.contains("load-jar")
            || arguments.contains("run-jar")
        if !mapsOwnStatus, output.status != 0 {
            throw EmulatorBridgeError.launchFailed
        }

        return output
    }

    private static func parsePainterOutput(
        stdout: String,
        status: Int32,
        expectedWidth: Int,
        expectedHeight: Int
    ) throws -> FreeJ2MEPainterRegistrationResult {
        guard status == 0 else {
            throw EmulatorBridgeError.launchFailed
        }

        let lines = stdoutLines(stdout)
        let frames = lines.compactMap { parseFrameLine($0) }

        guard frames.count >= 2 else {
            throw EmulatorBridgeError.launchFailed
        }
        for frame in frames {
            guard frame.width == expectedWidth,
                  frame.height == expectedHeight,
                  frame.pixelCount == expectedWidth * expectedHeight else {
                throw EmulatorBridgeError.launchFailed
            }
        }
        guard frames[0].checksum != frames[1].checksum else {
            throw EmulatorBridgeError.launchFailed
        }
        guard lines.contains(where: { $0.hasPrefix("FRAME_CAPTURE_OK ") }) else {
            throw EmulatorBridgeError.launchFailed
        }

        let paintCount: Int
        if let painterLine = lines.first(where: { $0.hasPrefix("PAINTER_OK ") }),
           let value = Int(painterLine.dropFirst("PAINTER_OK ".count)) {
            paintCount = value
        } else {
            paintCount = frames.count
        }

        return FreeJ2MEPainterRegistrationResult(
            paintEventCount: paintCount,
            frames: frames
        )
    }

    private static func parseFrameLine(_ line: String) -> FreeJ2MEFrameCapture? {
        // FRAME <index> <width> <height> <pixelCount> <checksum> <pixelFormat> <pixelFilePath>
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

    private static func parseLoadJarOutput(
        stdout: String,
        status: Int32,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarLoadResult {
        let lines = stdoutLines(stdout)

        if let okLine = lines.first(where: { $0.hasPrefix("LOAD_JAR_OK ") }) {
            let midletName = String(okLine.dropFirst("LOAD_JAR_OK ".count))
                .trimmingCharacters(in: .whitespaces)
            guard !midletName.isEmpty else {
                throw EmulatorBridgeError.launchFailed
            }
            return FreeJ2MEJarLoadResult(
                midletName: midletName,
                jarURLString: jarFileURLString
            )
        }

        if lines.contains("LOAD_JAR_MALFORMED") || status == 22 {
            throw EmulatorBridgeError.launchFailed
        }

        if lines.contains("LOAD_JAR_FAIL") || status == 21 {
            throw EmulatorBridgeError.launchFailed
        }

        throw EmulatorBridgeError.launchFailed
    }

    private static func parseRunJarOutput(
        stdout: String,
        status: Int32,
        jarFileURLString: String
    ) throws -> FreeJ2MEJarRunResult {
        let lines = stdoutLines(stdout)

        if let okLine = lines.first(where: { $0.hasPrefix("RUN_JAR_OK ") }) {
            let midletName = String(okLine.dropFirst("RUN_JAR_OK ".count))
                .trimmingCharacters(in: .whitespaces)
            guard !midletName.isEmpty else {
                throw EmulatorBridgeError.launchFailed
            }
            return FreeJ2MEJarRunResult(
                midletName: midletName,
                jarURLString: jarFileURLString,
                reachedStartApp: true
            )
        }

        if lines.contains("RUN_JAR_FAIL") || status == 31 {
            throw EmulatorBridgeError.launchFailed
        }

        if lines.contains("LOAD_JAR_MALFORMED") || status == 22 {
            throw EmulatorBridgeError.launchFailed
        }

        if lines.contains("LOAD_JAR_FAIL") || status == 21 {
            throw EmulatorBridgeError.launchFailed
        }

        throw EmulatorBridgeError.launchFailed
    }

    private static func stdoutLines(_ stdout: String) -> [String] {
        stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func resolveJavaHome() throws -> URL {
        if let environment = ProcessInfo.processInfo.environment["JAVA_HOME"],
           !environment.isEmpty {
            let home = URL(fileURLWithPath: environment, isDirectory: true)
            if FileManager.default.isExecutableFile(atPath: home.appendingPathComponent("bin/java").path) {
                return home
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        process.arguments = ["-v", "17+"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw EmulatorBridgeError.runtimeUnavailable
        }

        guard process.terminationStatus == 0 else {
            throw EmulatorBridgeError.runtimeUnavailable
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else {
            throw EmulatorBridgeError.runtimeUnavailable
        }

        let home = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.isExecutableFile(atPath: home.appendingPathComponent("bin/java").path) else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        return home
    }

    private static func resolveVendorRoot() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["JAVAONE_FREEJ2ME_ROOT"],
           !override.isEmpty {
            let root = URL(fileURLWithPath: override, isDirectory: true)
            try verifyVendorRoot(root)
            return root
        }

        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        let root = url.appendingPathComponent("Vendor/FreeJ2ME", isDirectory: true)
        try verifyVendorRoot(root)
        return root
    }

    private static func verifyVendorRoot(_ root: URL) throws {
        let marker = root
            .appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
        guard FileManager.default.fileExists(atPath: marker.path(percentEncoded: false)) else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
    }

    private static func resolveBootstrapSource() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        let source = url
            .appendingPathComponent("Bootstrap")
            .appendingPathComponent("MobilePlatformBootstrap.java")
        guard FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) else {
            throw EmulatorBridgeError.runtimeUnavailable
        }
        return source
    }

    private static func ensureCompiledClasses(
        javaHome: URL,
        vendorRoot: URL,
        bootstrapSource: URL
    ) throws -> URL {
        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("JavaOneFreeJ2MEBootstrap", isDirectory: true)
        let classesDirectory = cacheRoot.appendingPathComponent("classes", isDirectory: true)
        let stampFile = cacheRoot.appendingPathComponent("classpath.stamp")

        let mobilePlatformSource = vendorRoot
            .appendingPathComponent("src/org/recompile/mobile/MobilePlatform.java")
        let stampPayload = [
            mobilePlatformSource.path(percentEncoded: false),
            bootstrapSource.path(percentEncoded: false),
            modificationDateString(for: mobilePlatformSource),
            modificationDateString(for: bootstrapSource)
        ].joined(separator: "|")

        if FileManager.default.fileExists(
            atPath: classesDirectory
                .appendingPathComponent("org/javaone/freej2me/MobilePlatformBootstrap.class")
                .path
        ),
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

        let allSources = vendorSources + [bootstrapSource.path(percentEncoded: false)]
        try allSources.joined(separator: "\n").write(to: sourcesList, atomically: true, encoding: .utf8)

        let javac = javaHome.appendingPathComponent("bin/javac")
        let process = Process()
        process.executableURL = javac
        process.arguments = [
            "-encoding", "UTF-8",
            "-g",
            "-d", classesDirectory.path(percentEncoded: false),
            "@\(sourcesList.path(percentEncoded: false))"
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw EmulatorBridgeError.runtimeUnavailable
        }

        guard process.terminationStatus == 0 else {
            throw EmulatorBridgeError.launchFailed
        }

        try stampPayload.write(to: stampFile, atomically: true, encoding: .utf8)
        return classesDirectory
    }

    private static func modificationDateString(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        if let date = values?.contentModificationDate {
            return String(date.timeIntervalSince1970)
        }
        return "missing"
    }

    #endif
}
