#!/usr/bin/env bash
# Phase 1 — EmbeddedJVMManager → JVM → HelloWorld → destroy + metrics.
# Isolated harness (not App Target). Does not load FreeJ2ME or product JARs.
# Does not implement JNI Gateway / Bridge / Host / Adapter / UI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMBED="$ROOT/JavaOne/Features/Emulator/Runtime/EmbeddedJVM"
SPIKE_JAVA="$EMBED/Spike/HelloWorld.java"
NATIVE_C="$EMBED/Native/EmbeddedJVMNative.c"
BRIDGE_H="$EMBED/Native/EmbeddedJVMBridgingHeader.h"
OUT="$ROOT/artifacts/embedded-jvm-phase1"
BUILD="$OUT/build"
CLASSES="$OUT/classes"
METRICS_JSON="$OUT/metrics.json"
STATE_BIN="$BUILD/EmbeddedJVMPhase1StateTests"
HELLO_BIN="$BUILD/EmbeddedJVMHelloWorld"

mkdir -p "$OUT" "$BUILD" "$CLASSES"

# --- Resolve JVM backend ---
# Prefer staged OpenJDK Mobile only when a *host-linkable* libjvm is present.
# iOS device `libjvm.a` (Zero) cannot be linked into a macOS harness; in that case
# we still record the staged artifact size but execute via host OpenJDK JNI API.
STAGED_CURRENT="$ROOT/artifacts/openjdk-mobile/staged/current"
MOBILE_LIBJVM=""
if [[ -d "$STAGED_CURRENT" ]]; then
  MOBILE_LIBJVM="$(find "$STAGED_CURRENT" -name 'libjvm.a' -o -name 'libjvm.dylib' 2>/dev/null | head -1 || true)"
fi

JAVA_HOME_RESOLVED="${JAVAONE_SPIKE_JAVA_HOME:-${JAVA_HOME:-}}"
if [[ -z "$JAVA_HOME_RESOLVED" ]]; then
  if [[ -x /private/tmp/javaone-jdk/Contents/Home/bin/java ]]; then
    JAVA_HOME_RESOLVED="/private/tmp/javaone-jdk/Contents/Home"
  elif [[ -x /usr/libexec/java_home ]]; then
    JAVA_HOME_RESOLVED="$(/usr/libexec/java_home 2>/dev/null || true)"
  fi
fi
[[ -n "$JAVA_HOME_RESOLVED" && -x "$JAVA_HOME_RESOLVED/bin/javac" ]] \
  || { echo "error: JDK with javac required (set JAVA_HOME)" >&2; exit 1; }

export JAVA_HOME="$JAVA_HOME_RESOLVED"
JAVAC="$JAVA_HOME/bin/javac"
JAVA="$JAVA_HOME/bin/java"

HOST_LIBJVM="$JAVA_HOME/lib/server/libjvm.dylib"
[[ -f "$HOST_LIBJVM" ]] || HOST_LIBJVM="$JAVA_HOME/lib/libjvm.dylib"
[[ -f "$HOST_LIBJVM" ]] || { echo "error: libjvm not found under $JAVA_HOME" >&2; exit 1; }

BACKEND="host-jdk"
LINK_LIBJVM="$HOST_LIBJVM"
JAVA_HOME_FOR_VM="$JAVA_HOME"
if [[ -n "$MOBILE_LIBJVM" && "$MOBILE_LIBJVM" == *.dylib ]]; then
  BACKEND="openjdk-mobile"
  LINK_LIBJVM="$MOBILE_LIBJVM"
  echo "==> Using staged OpenJDK Mobile dylib: $MOBILE_LIBJVM"
else
  echo "==> Using host OpenJDK for JNI_CreateJavaVM spike: $JAVA_HOME"
  if [[ -n "$MOBILE_LIBJVM" ]]; then
    echo "    note: staged Mobile libjvm exists but is not host-linkable ($MOBILE_LIBJVM); size still recorded if requested."
  else
    echo "    note: no OpenJDK Mobile staged artifact — Fase 0 build still required for device/simulator Mobile."
  fi
fi

LIB_DIR="$(dirname "$LINK_LIBJVM")"

echo "==> Compiling HelloWorld.java"
rm -rf "$CLASSES"
mkdir -p "$CLASSES"
"$JAVAC" -encoding UTF-8 -d "$CLASSES" "$SPIKE_JAVA"
HELLO_CLASS="$CLASSES/org/javaone/embedded/spike/HelloWorld.class"
[[ -f "$HELLO_CLASS" ]] || { echo "error: HelloWorld.class missing" >&2; exit 1; }

SWIFT_SOURCES=(
  "$EMBED/EmbeddedJVMState.swift"
  "$EMBED/EmbeddedJVMError.swift"
  "$EMBED/EmbeddedJVMMetrics.swift"
  "$EMBED/EmbeddedJVMConfiguration.swift"
  "$EMBED/EmbeddedJVMNativeRuntime.swift"
  "$EMBED/EmbeddedJVMManager.swift"
  "$EMBED/ProcessRSSSampler.swift"
  "$EMBED/MockEmbeddedJVMNativeRuntime.swift"
)

echo "==> State-machine tests (mock native)"
swiftc -swift-version 6 -O -parse-as-library \
  "${SWIFT_SOURCES[@]}" \
  "$ROOT/Spike/EmbeddedJVMPhase1/StateMachineMain.swift" \
  -o "$STATE_BIN"
"$STATE_BIN"

echo "==> Compiling native EmbeddedJVMNative.c"
clang -c "$NATIVE_C" \
  -I"$EMBED/Native" \
  -I"$JAVA_HOME/include" \
  -I"$JAVA_HOME/include/darwin" \
  -o "$BUILD/EmbeddedJVMNative.o"

echo "==> Linking Hello World spike executable"
swiftc -swift-version 6 -O -parse-as-library \
  "${SWIFT_SOURCES[@]}" \
  "$EMBED/JNICreateJavaVMNativeRuntime.swift" \
  "$ROOT/Spike/EmbeddedJVMPhase1/main.swift" \
  "$BUILD/EmbeddedJVMNative.o" \
  -import-objc-header "$BRIDGE_H" \
  -I"$EMBED/Native" \
  -L"$LIB_DIR" \
  -ljvm \
  -Xlinker -rpath -Xlinker "$LIB_DIR" \
  -o "$HELLO_BIN"

export JAVAONE_SPIKE_JAVA_HOME="$JAVA_HOME_FOR_VM"
export JAVAONE_SPIKE_CLASSPATH="$CLASSES"
export JAVAONE_SPIKE_BACKEND="$BACKEND"
export JAVAONE_SPIKE_LIBJVM="$LINK_LIBJVM"
export JAVAONE_SPIKE_METRICS_OUT="$METRICS_JSON"
if [[ -n "$MOBILE_LIBJVM" ]]; then
  export JAVAONE_SPIKE_MOBILE_STAGED="$STAGED_CURRENT"
fi

# Prefer recording Mobile libjvm size when present even if execution used host.
if [[ -n "$MOBILE_LIBJVM" && "$BACKEND" == "host-jdk" ]]; then
  export JAVAONE_SPIKE_LIBJVM="$MOBILE_LIBJVM"
fi

echo "==> Running EmbeddedJVM Hello World spike"
"$HELLO_BIN"

echo
echo "Phase 1 harness finished."
echo "Metrics: $METRICS_JSON"
