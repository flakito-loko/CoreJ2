import Foundation

/// Pure state-machine checks for Phase 1 (mock native — no real JVM).
enum EmbeddedJVMPhase1StateTests {
    static func main() async {
        var failures = 0

        do {
            let native = MockEmbeddedJVMNativeRuntime()
            let manager = makeManager(native: native)
            try await manager.ensureStarted()
            precondition(manager.state == .ready)
            try await manager.runHelloWorld()
            precondition(manager.didCompleteHelloWorld)
            precondition(native.helloCount == 1)
            try await manager.shutdown()
            precondition(manager.state == .destroyed)
            precondition(native.destroyCount == 1)
            precondition(native.createCount == 1)
            print("  [ok] happy path Ready → Hello → Destroyed")
        } catch {
            fputs("  [FAIL] happy path: \(error)\n", stderr)
            failures += 1
        }

        do {
            let native = MockEmbeddedJVMNativeRuntime()
            let manager = makeManager(native: native)
            try await manager.ensureStarted()
            try await manager.ensureStarted()
            precondition(native.createCount == 1)
            print("  [ok] idempotent ensureStarted")
        } catch {
            fputs("  [FAIL] idempotent ensureStarted: \(error)\n", stderr)
            failures += 1
        }

        do {
            let native = MockEmbeddedJVMNativeRuntime()
            let manager = makeManager(native: native)
            do {
                try await manager.runHelloWorld()
                fputs("  [FAIL] reject hello before start: expected notReady\n", stderr)
                failures += 1
            } catch EmbeddedJVMError.notReady {
                print("  [ok] reject hello before start")
            }
        } catch {
            fputs("  [FAIL] reject hello before start: \(error)\n", stderr)
            failures += 1
        }

        do {
            let native = MockEmbeddedJVMNativeRuntime()
            native.createShouldFail = true
            let manager = makeManager(native: native)
            do {
                try await manager.ensureStarted()
                fputs("  [FAIL] create failure: expected nativeCreateFailed\n", stderr)
                failures += 1
            } catch EmbeddedJVMError.nativeCreateFailed {
                precondition(manager.state == .failed)
                print("  [ok] create failure → Failed")
            }
        } catch {
            fputs("  [FAIL] create failure: \(error)\n", stderr)
            failures += 1
        }

        if failures > 0 {
            fputs("EmbeddedJVM Phase-1 state tests: \(failures) failure(s)\n", stderr)
            exit(1)
        }
        print("EmbeddedJVM Phase-1 state tests: OK")
    }

    private static func makeManager(native: MockEmbeddedJVMNativeRuntime) -> EmbeddedJVMManager {
        let configuration = EmbeddedJVMConfiguration(
            librarySource: .hostJDK(javaHome: URL(fileURLWithPath: "/tmp")),
            classpath: URL(fileURLWithPath: "/tmp")
        )
        return EmbeddedJVMManager(configuration: configuration, native: native)
    }
}

@main
enum EmbeddedJVMPhase1StateTestsMain {
    static func main() async {
        await EmbeddedJVMPhase1StateTests.main()
    }
}
