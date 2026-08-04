import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Phase-1 harness entry: EmbeddedJVMManager → JVM → HelloWorld → destroy + metrics.
///
/// Not part of the JavaOne App Target. Built by `scripts/embedded-jvm/run_phase1_hello_world.sh`.

@main
enum EmbeddedJVMPhase1Main {
    static func main() async {
        do {
            let timedOut = try await runSpike()
            if timedOut {
                // Avoid hanging process exit on a stuck DestroyJavaVM worker thread.
                _exit(0)
            }
            exit(0)
        } catch {
            fputs("Phase-1 spike failed: \(error)\n", stderr)
            exit(1)
        }
    }

    /// Returns `true` when destroy timed out (caller should `_exit`).
    @discardableResult
    private static func runSpike() async throws -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let javaHome = env["JAVAONE_SPIKE_JAVA_HOME"] ?? env["JAVA_HOME"], !javaHome.isEmpty else {
            throw EmbeddedJVMError.invalidConfiguration("JAVAONE_SPIKE_JAVA_HOME / JAVA_HOME required")
        }
        guard let classpath = env["JAVAONE_SPIKE_CLASSPATH"], !classpath.isEmpty else {
            throw EmbeddedJVMError.invalidConfiguration("JAVAONE_SPIKE_CLASSPATH required")
        }
        let backend = env["JAVAONE_SPIKE_BACKEND"] ?? "host-jdk"
        let libjvmPath = env["JAVAONE_SPIKE_LIBJVM"]
        let metricsOut = env["JAVAONE_SPIKE_METRICS_OUT"]

        let javaHomeURL = URL(fileURLWithPath: javaHome, isDirectory: true)
        let classpathURL = URL(fileURLWithPath: classpath, isDirectory: true)
        let libjvmURL = libjvmPath.map { URL(fileURLWithPath: $0) }

        let source: EmbeddedJVMLibrarySource
        if backend == "openjdk-mobile" {
            let staged = env["JAVAONE_SPIKE_MOBILE_STAGED"].map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? javaHomeURL
            source = .openJDKMobile(stagedRoot: staged, javaHome: javaHomeURL)
        } else {
            source = .hostJDK(javaHome: javaHomeURL)
        }

        let configuration = EmbeddedJVMConfiguration(
            librarySource: source,
            classpath: classpathURL,
            libjvmURL: libjvmURL
        )

        #if canImport(Darwin)
        let native = JNICreateJavaVMNativeRuntime()
        #else
        throw EmbeddedJVMError.invalidConfiguration("Darwin required for Phase-1 native spike")
        #endif

        let manager = EmbeddedJVMManager(configuration: configuration, native: native)

        print("==> ensureStarted (\(configuration.backendLabel))")
        try await manager.ensureStarted()
        print("    state=\(manager.state.rawValue)")

        print("==> runHelloWorld")
        try await manager.runHelloWorld()
        print("    completed=\(manager.didCompleteHelloWorld)")

        print("==> shutdown / destroy")
        try await manager.shutdown()
        print("    state=\(manager.state.rawValue)")

        let metrics = manager.metrics
        let payload: [String: Any] = [
            "phase": "1",
            "backend": metrics.backendLabel,
            "helloWorldCompleted": manager.didCompleteHelloWorld,
            "finalState": manager.state.rawValue,
            "startupMs": metrics.startupMilliseconds,
            "helloWorldMs": metrics.helloWorldMilliseconds,
            "destroyMs": metrics.destroyMilliseconds,
            "destroyTimedOut": metrics.destroyTimedOut,
            "startupNs": metrics.startupNanoseconds,
            "helloWorldNs": metrics.helloWorldNanoseconds,
            "destroyNs": metrics.destroyNanoseconds,
            "rssBeforeCreateBytes": metrics.rssBeforeCreateBytes as Any,
            "rssAfterReadyBytes": metrics.rssAfterReadyBytes as Any,
            "rssAfterHelloBytes": metrics.rssAfterHelloBytes as Any,
            "rssAfterDestroyBytes": metrics.rssAfterDestroyBytes as Any,
            "rssDeltaCreateBytes": metrics.rssDeltaCreateBytes as Any,
            "libjvmBytes": metrics.libjvmBytes as Any,
            "helloWorldClassBytes": metrics.helloWorldClassBytes as Any,
            "javaHome": javaHome,
            "classpath": classpath,
            "libjvmPath": libjvmPath as Any,
            "notes": backend == "openjdk-mobile"
                ? "OpenJDK Mobile linkage"
                : "Host OpenJDK JNI_CreateJavaVM stand-in until Fase 0 Mobile libjvm is staged for the agreed target",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: data, encoding: .utf8) ?? "{}"
        if let metricsOut, !metricsOut.isEmpty {
            try data.write(to: URL(fileURLWithPath: metricsOut), options: .atomic)
            print("==> metrics written to \(metricsOut)")
        }
        print(text)
        fflush(stdout)
        return metrics.destroyTimedOut
    }
}
