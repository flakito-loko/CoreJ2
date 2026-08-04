#!/usr/bin/env bash
# Phase 1.5 harness — same EmbeddedJVMManager + HelloWorld; Temurin vs OpenJDK Mobile.
# Does not modify App Target or EmbeddedJVMManager sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMBED="$ROOT/JavaOne/Features/Emulator/Runtime/EmbeddedJVM"
SPIKE_JAVA="$EMBED/Spike/HelloWorld.java"
NATIVE_C="$EMBED/Native/EmbeddedJVMNative.c"
BRIDGE_H="$EMBED/Native/EmbeddedJVMBridgingHeader.h"
OUT="$ROOT/artifacts/embedded-jvm-phase1_5"
BUILD="$OUT/build"
CLASSES="$OUT/classes"
PHASE1_METRICS="$ROOT/artifacts/embedded-jvm-phase1/metrics.json"
TEMURIN_METRICS="$OUT/metrics-temurin.json"
MOBILE_METRICS="$OUT/metrics-openjdk-mobile.json"
COMPARE_JSON="$OUT/comparison.json"
COMPARE_MD="$OUT/comparison.md"

mkdir -p "$OUT" "$BUILD" "$CLASSES"

TEMURIN_HOME="${JAVAONE_TEMURIN_HOME:-/private/tmp/javaone-jdk/Contents/Home}"
[[ -x "$TEMURIN_HOME/bin/javac" ]] || { echo "error: Temurin JAVA_HOME missing: $TEMURIN_HOME" >&2; exit 1; }

STAGED_MACOS="$ROOT/artifacts/openjdk-mobile/staged/current-macos"
if [[ ! -d "$STAGED_MACOS/jdk" ]]; then
  STAGED_MACOS="$ROOT/artifacts/openjdk-mobile/staged/current"
fi
[[ -d "$STAGED_MACOS/jdk" ]] || {
  echo "error: OpenJDK Mobile macOS stage missing. Run:" >&2
  echo "  ./scripts/openjdk-mobile/build-macos-host.sh" >&2
  exit 1
}
MOBILE_JAVA_HOME="$STAGED_MACOS/jdk"
MOBILE_LIBJVM="$(find "$MOBILE_JAVA_HOME" -name 'libjvm.dylib' | head -1)"
[[ -f "$MOBILE_LIBJVM" ]] || { echo "error: Mobile libjvm.dylib missing under $MOBILE_JAVA_HOME" >&2; exit 1; }

TEMURIN_LIBJVM="$TEMURIN_HOME/lib/server/libjvm.dylib"
[[ -f "$TEMURIN_LIBJVM" ]] || TEMURIN_LIBJVM="$TEMURIN_HOME/lib/libjvm.dylib"

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
)

compile_hello() {
  local javac="$1"
  rm -rf "$CLASSES"
  mkdir -p "$CLASSES"
  "$javac" -encoding UTF-8 -d "$CLASSES" "$SPIKE_JAVA"
}

build_and_run() {
  local label="$1"
  local java_home="$2"
  local libjvm="$3"
  local backend="$4"
  local metrics_out="$5"

  local lib_dir
  lib_dir="$(dirname "$libjvm")"
  local bin="$BUILD/EmbeddedJVMHelloWorld-$label"

  echo "==> [$label] compile native + link against $libjvm"
  clang -c "$NATIVE_C" \
    -I"$EMBED/Native" \
    -I"$java_home/include" \
    -I"$java_home/include/darwin" \
    -o "$BUILD/EmbeddedJVMNative-$label.o"

  swiftc -swift-version 6 -O -parse-as-library \
    "${SWIFT_SOURCES[@]}" \
    "$ROOT/Spike/EmbeddedJVMPhase1/main.swift" \
    "$BUILD/EmbeddedJVMNative-$label.o" \
    -import-objc-header "$BRIDGE_H" \
    -I"$EMBED/Native" \
    -L"$lib_dir" \
    -ljvm \
    -Xlinker -rpath -Xlinker "$lib_dir" \
    -o "$bin"

  export JAVAONE_SPIKE_JAVA_HOME="$java_home"
  export JAVAONE_SPIKE_CLASSPATH="$CLASSES"
  export JAVAONE_SPIKE_BACKEND="$backend"
  export JAVAONE_SPIKE_LIBJVM="$libjvm"
  export JAVAONE_SPIKE_METRICS_OUT="$metrics_out"
  unset JAVAONE_SPIKE_MOBILE_STAGED || true
  if [[ "$backend" == "openjdk-mobile" ]]; then
    export JAVAONE_SPIKE_MOBILE_STAGED="$STAGED_MACOS"
  fi

  echo "==> [$label] run HelloWorld via EmbeddedJVMManager"
  "$bin"
}

echo "==> Compile HelloWorld.java (same Phase-1 source) with Temurin javac"
compile_hello "$TEMURIN_HOME/bin/javac"

# Preserve Phase-1 Temurin baseline if present; else re-run Temurin now.
if [[ -f "$PHASE1_METRICS" ]]; then
  cp "$PHASE1_METRICS" "$TEMURIN_METRICS"
  echo "==> Reusing Phase-1 Temurin metrics → $TEMURIN_METRICS"
else
  build_and_run "temurin" "$TEMURIN_HOME" "$TEMURIN_LIBJVM" "host-jdk" "$TEMURIN_METRICS"
fi

build_and_run "mobile" "$MOBILE_JAVA_HOME" "$MOBILE_LIBJVM" "openjdk-mobile" "$MOBILE_METRICS"

python3 - <<'PY' "$TEMURIN_METRICS" "$MOBILE_METRICS" "$COMPARE_JSON" "$COMPARE_MD"
import json, sys
from pathlib import Path

temurin_path, mobile_path, out_json, out_md = sys.argv[1:5]
t = json.loads(Path(temurin_path).read_text())
m = json.loads(Path(mobile_path).read_text())

def num(d, *keys):
    for k in keys:
        if k in d and d[k] is not None:
            return d[k]
    return None

rows = [
    ("Startup (ms)", num(t, "startupMs"), num(m, "startupMs")),
    ("RSS Δ create (bytes)", num(t, "rssDeltaCreateBytes"), num(m, "rssDeltaCreateBytes")),
    ("RSS after Ready (bytes)", num(t, "rssAfterReadyBytes"), num(m, "rssAfterReadyBytes")),
    ("libjvm size (bytes)", num(t, "libjvmBytes"), num(m, "libjvmBytes")),
    ("Destroy (ms)", num(t, "destroyMs"), num(m, "destroyMs")),
    ("Destroy timed out", num(t, "destroyTimedOut"), num(m, "destroyTimedOut")),
    ("Final state", num(t, "finalState"), num(m, "finalState")),
    ("HelloWorld completed", num(t, "helloWorldCompleted"), num(m, "helloWorldCompleted")),
]

comparison = {
    "phase": "1.5",
    "temurin": t,
    "openjdkMobile": m,
    "table": [
        {"metric": name, "temurin": tv, "openjdkMobile": mv}
        for name, tv, mv in rows
    ],
    "helloWorldSameSource": True,
    "embeddedJVMManagerUnchanged": True,
    "appTargetUnchanged": True,
}
Path(out_json).write_text(json.dumps(comparison, indent=2, sort_keys=True) + "\n")

def fmt(v):
    if isinstance(v, float):
        return f"{v:.3f}"
    return str(v)

lines = [
    "# Temurin vs OpenJDK Mobile (Phase 1.5)",
    "",
    "| Metric | Temurin | OpenJDK Mobile |",
    "|--------|---------|----------------|",
]
for name, tv, mv in rows:
    lines.append(f"| {name} | {fmt(tv)} | {fmt(mv)} |")
lines.append("")
Path(out_md).write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY

echo
echo "Phase 1.5 comparison written:"
echo "  $COMPARE_MD"
echo "  $COMPARE_JSON"
echo "  $MOBILE_METRICS"
