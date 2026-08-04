#!/usr/bin/env bash
# E2-US001 — Real JVM HelloWorld via DefaultJNIGateway (not Manager.runHelloWorld).
# Harness only; does not modify App Target wiring.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMBED="$ROOT/JavaOne/Features/Emulator/Runtime/EmbeddedJVM"
SPIKE_JAVA="$EMBED/Spike/HelloWorld.java"
OUT="$ROOT/artifacts/jni-gateway-e2-us001"
BUILD="$OUT/build"
CLASSES="$OUT/classes"
BIN="$BUILD/JNIGatewayHelloWorld"

JAVA_HOME_RESOLVED="${JAVAONE_SPIKE_JAVA_HOME:-${JAVA_HOME:-}}"
if [[ -z "$JAVA_HOME_RESOLVED" && -x /private/tmp/javaone-jdk/Contents/Home/bin/java ]]; then
  JAVA_HOME_RESOLVED="/private/tmp/javaone-jdk/Contents/Home"
fi
# Prefer staged OpenJDK Mobile when present
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
"$JAVA_HOME/bin/javac" -encoding UTF-8 -d "$CLASSES" "$SPIKE_JAVA"

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
            try await manager.ensureStarted()
            let gateway = DefaultJNIGateway(
                readiness: manager,
                native: ProductionJNIGatewayNativeBackend()
            )
            try gateway.bind()
            try await gateway.invokeHelloWorldMain()
            gateway.invalidate()
            try await manager.shutdown()
            print("E2-US001 OK: JNIGateway invoked HelloWorld.main")
            if manager.metrics.destroyTimedOut { _exit(0) }
            exit(0)
        } catch {
            fputs("E2-US001 failed: \(error)\n", stderr)
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
