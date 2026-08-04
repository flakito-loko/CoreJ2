#!/usr/bin/env bash
# E3-US002 — Real JVM: PlatformBootstrap → registerNative → NativeCallbackHost.fireHeartbeat → Swift.
# Harness only; does not modify App Target wiring. No FreeJ2ME / loadJar / runJar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMBED="$ROOT/JavaOne/Features/Emulator/Runtime/EmbeddedJVM"
HOST_JAVA="$EMBED/Bootstrap/NativeCallbackHost.java"
OUT="$ROOT/artifacts/native-callback-host-e3-us002"
BUILD="$OUT/build"
CLASSES="$OUT/classes"
BIN="$BUILD/NativeCallbackHostHarness"

JAVA_HOME_RESOLVED="${JAVAONE_SPIKE_JAVA_HOME:-${JAVA_HOME:-}}"
if [[ -z "$JAVA_HOME_RESOLVED" && -x /private/tmp/javaone-jdk/Contents/Home/bin/java ]]; then
  JAVA_HOME_RESOLVED="/private/tmp/javaone-jdk/Contents/Home"
fi
STAGED="$ROOT/artifacts/openjdk-mobile/staged/current-macos/jdk"
if [[ -x "$STAGED/bin/java" ]]; then
  JAVA_HOME_RESOLVED="$STAGED"
fi
[[ -n "$JAVA_HOME_RESOLVED" && -x "$JAVA_HOME_RESOLVED/bin/javac" ]] || {
  echo "error: JAVA_HOME with javac required" >&2
  exit 1
}
export JAVA_HOME="$JAVA_HOME_RESOLVED"
LIBJVM="$JAVA_HOME/lib/server/libjvm.dylib"
[[ -f "$LIBJVM" ]] || LIBJVM="$JAVA_HOME/lib/libjvm.dylib"
LIB_DIR="$(dirname "$LIBJVM")"

mkdir -p "$OUT" "$BUILD" "$CLASSES"
rm -rf "$CLASSES"
mkdir -p "$CLASSES"
"$JAVA_HOME/bin/javac" -encoding UTF-8 -d "$CLASSES" "$HOST_JAVA"
[[ -f "$CLASSES/org/javaone/bootstrap/NativeCallbackHost.class" ]] || {
  echo "error: NativeCallbackHost.class missing after javac" >&2
  exit 1
}

SWIFT_SOURCES=(
  "$EMBED/EmbeddedJVMState.swift"
  "$EMBED/EmbeddedJVMError.swift"
  "$EMBED/EmbeddedJVMMetrics.swift"
  "$EMBED/EmbeddedJVMConfiguration.swift"
  "$EMBED/EmbeddedJVMNativeRuntime.swift"
  "$EMBED/EmbeddedJVMManager.swift"
  "$EMBED/ProcessRSSSampler.swift"
  "$EMBED/MockEmbeddedJVMNativeRuntime.swift"
  "$EMBED/JNICreateJavaVMNativeRuntime.swift"
  "$EMBED/JNIGateway/EmbeddedJVMReadiness.swift"
  "$EMBED/JNIGateway/JNIGatewayHandles.swift"
  "$EMBED/JNIGateway/JNIGatewayError.swift"
  "$EMBED/JNIGateway/JNIGatewayNativeBackend.swift"
  "$EMBED/JNIGateway/JNIGatewayReferenceCache.swift"
  "$EMBED/JNIGateway/JNIInvocationTypes.swift"
  "$EMBED/JNIGateway/JNICallbackTypes.swift"
  "$EMBED/JNIGateway/JNIGatewayCallbackRegistry.swift"
  "$EMBED/JNIGateway/JNIGatewayTrampolineHost.swift"
  "$EMBED/JNIGateway/JNIGateway.swift"
  "$EMBED/JNIGateway/DefaultJNIGateway.swift"
  "$EMBED/JNIGateway/MockJNIGatewayNativeBackend.swift"
  "$EMBED/JNIGateway/ProductionJNIGatewayNativeBackend.swift"
  "$EMBED/JNIGateway/StubEmbeddedJVMReadiness.swift"
  "$EMBED/PlatformBootstrap/PlatformBootstrapState.swift"
  "$EMBED/PlatformBootstrap/PlatformBootstrapError.swift"
  "$EMBED/PlatformBootstrap/EmbeddedJVMControlling.swift"
  "$EMBED/PlatformBootstrap/PlatformBootstrap.swift"
  "$EMBED/PlatformBootstrap/DefaultPlatformBootstrap.swift"
  "$EMBED/PlatformBootstrap/StubEmbeddedJVMController.swift"
)

clang -c "$EMBED/Native/EmbeddedJVMNative.c" \
  -I"$EMBED/Native" -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" \
  -o "$BUILD/EmbeddedJVMNative.o"
clang -c "$EMBED/JNIGateway/Native/JNIGatewayNative.c" \
  -I"$EMBED/JNIGateway/Native" -I"$EMBED/Native" \
  -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" \
  -o "$BUILD/JNIGatewayNative.o"

cat > "$BUILD/main.swift" <<'EOF'
import Foundation

@main
enum Main {
    static func main() async {
        do {
            let javaHome = ProcessInfo.processInfo.environment["JAVAONE_SPIKE_JAVA_HOME"]!
            let classpath = ProcessInfo.processInfo.environment["JAVAONE_SPIKE_CLASSPATH"]!
            let configuration = EmbeddedJVMConfiguration(
                librarySource: .hostJDK(javaHome: URL(fileURLWithPath: javaHome, isDirectory: true)),
                classpath: URL(fileURLWithPath: classpath, isDirectory: true),
                libjvmURL: URL(fileURLWithPath: ProcessInfo.processInfo.environment["JAVAONE_SPIKE_LIBJVM"] ?? "")
            )
            let manager = EmbeddedJVMManager(
                configuration: configuration,
                native: JNICreateJavaVMNativeRuntime()
            )
            let gateway = DefaultJNIGateway(
                readiness: manager,
                native: ProductionJNIGatewayNativeBackend()
            )
            let bootstrap = DefaultPlatformBootstrap(jvm: manager, gateway: gateway)

            fputs("E3-US002: initialize…\n", stderr)
            try await bootstrap.initialize()
            guard bootstrap.isReady else {
                fputs("E3-US002 failed: bootstrap not ready\n", stderr)
                exit(1)
            }

            let classId = try gateway.resolveClass(
                binaryName: DefaultPlatformBootstrap.Infrastructure.callbackHostBinaryName
            )
            let fireId = try gateway.resolveMethod(
                classId: classId,
                name: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatMethodName,
                signature: DefaultPlatformBootstrap.Infrastructure.fireHeartbeatSignature,
                isStatic: true
            )

            fputs("E3-US002: fireHeartbeat ×3…\n", stderr)
            for _ in 0..<3 {
                _ = try gateway.callStatic(
                    classId: classId,
                    methodId: fireId,
                    arguments: [],
                    returning: .void
                )
            }

            guard bootstrap.heartbeatInvocationCount == 3 else {
                fputs(
                    "E3-US002 failed: expected 3 heartbeats, got \(bootstrap.heartbeatInvocationCount)\n",
                    stderr
                )
                exit(1)
            }

            fputs("E3-US002: shutdown…\n", stderr)
            try await bootstrap.shutdown()
            guard bootstrap.state == .shutdown, !gateway.isUsable else {
                fputs("E3-US002 failed: shutdown incomplete\n", stderr)
                exit(1)
            }

            print("E3-US002 OK: NativeCallbackHost.fireHeartbeat → Swift (3 heartbeats)")
            fflush(stdout)
            // DestroyJavaVM can hang on some JDKs; success already validated.
            _exit(0)
        } catch {
            fputs("E3-US002 failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
EOF

swiftc -swift-version 6 -O -parse-as-library \
  "${SWIFT_SOURCES[@]}" \
  "$BUILD/main.swift" \
  "$BUILD/EmbeddedJVMNative.o" \
  "$BUILD/JNIGatewayNative.o" \
  -I"$EMBED/Native" \
  -I"$EMBED/JNIGateway/Native" \
  -L"$LIB_DIR" -ljvm \
  -Xlinker -rpath -Xlinker "$LIB_DIR" \
  -o "$BIN"

export JAVAONE_SPIKE_JAVA_HOME="$JAVA_HOME"
export JAVAONE_SPIKE_CLASSPATH="$CLASSES"
export JAVAONE_SPIKE_LIBJVM="$LIBJVM"
"$BIN"
echo "Harness finished."
