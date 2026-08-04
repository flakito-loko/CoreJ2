#!/usr/bin/env bash
# E5-US004 — Host-side validation for PersistentMobilePlatformDaemon (macOS).
# Does not touch production bootstrap or FreeJ2ME sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${JAVA_HOME:-}" ]]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 17+)"
  export JAVA_HOME
fi
JAVA="$JAVA_HOME/bin/java"
JAVAC="$JAVA_HOME/bin/javac"
JAR_BIN="$JAVA_HOME/bin/jar"

CACHE="${TMPDIR:-/tmp}/JavaOnePersistentRuntimePOC-script"
CLASSES="$CACHE/classes"
FRAMES="$CACHE/frames"
SOURCES="$CACHE/sources.txt"
rm -rf "$CACHE"
mkdir -p "$CLASSES" "$FRAMES"

VENDOR_SRC="$ROOT/Vendor/FreeJ2ME/src"
DAEMON="$ROOT/JavaOne/Features/Emulator/Runtime/Bootstrap/PersistentMobilePlatformDaemon.java"
FIXTURE="$ROOT/JavaOne/Features/Emulator/Runtime/Bootstrap/fixtures/ProbeMIDlet.java"

echo "==> Compiling FreeJ2ME + PersistentMobilePlatformDaemon"
find "$VENDOR_SRC" -name '*.java' | sort > "$SOURCES"
echo "$DAEMON" >> "$SOURCES"
"$JAVAC" -encoding UTF-8 -g -Xlint:none -d "$CLASSES" @"$SOURCES" 2>"$CACHE/javac.err" || {
  cat "$CACHE/javac.err" >&2
  exit 1
}

echo "==> Building ProbeMIDlet JAR"
FIX_CLASSES="$CACHE/fix-classes"
mkdir -p "$FIX_CLASSES"
"$JAVAC" -encoding UTF-8 -cp "$CLASSES" -d "$FIX_CLASSES" "$FIXTURE"
JAR_DIR="$CACHE/jar"
mkdir -p "$JAR_DIR/META-INF" "$JAR_DIR/org/javaone/freej2me/fixtures"
cp "$FIX_CLASSES/org/javaone/freej2me/fixtures/ProbeMIDlet.class" \
  "$JAR_DIR/org/javaone/freej2me/fixtures/"
cat > "$JAR_DIR/META-INF/MANIFEST.MF" <<'EOF'
Manifest-Version: 1.0
MIDlet-1: Probe MIDlet, , org.javaone.freej2me.fixtures.ProbeMIDlet
MIDlet-Name: Probe MIDlet
MIDlet-Vendor: JavaOne
MIDlet-Version: 1.0
MicroEdition-Configuration: CLDC-1.0
MicroEdition-Profile: MIDP-2.0

EOF
JAR="$CACHE/probe.jar"
"$JAR_BIN" cfm "$JAR" "$JAR_DIR/META-INF/MANIFEST.MF" \
  -C "$JAR_DIR" org/javaone/freej2me/fixtures/ProbeMIDlet.class
JAR_URL="file://$JAR"

OUT_LOG="$CACHE/daemon.out"
ERR_LOG="$CACHE/daemon.err"
CMD_FIFO="$CACHE/cmd.fifo"
mkfifo "$CMD_FIFO"

"$JAVA" -Djava.awt.headless=true -Djava.security.manager=allow \
  -cp "$CLASSES" org.javaone.freej2me.PersistentMobilePlatformDaemon \
  <"$CMD_FIFO" >"$OUT_LOG" 2>"$ERR_LOG" &
DAEMON_PID=$!
START_NS=$(python3 -c 'import time; print(time.monotonic())')
exec 3>"$CMD_FIFO"

cleanup() {
  exec 3>&- 2>/dev/null || true
  kill "$DAEMON_PID" 2>/dev/null || true
  wait "$DAEMON_PID" 2>/dev/null || true
}
trap cleanup EXIT

LINE_MARK=0

mark_log() {
  LINE_MARK=$(wc -l < "$OUT_LOG" | tr -d ' ')
}

wait_for_new() {
  local pattern="$1"
  local timeout="${2:-90}"
  local start
  start=$(date +%s)
  while true; do
    local hit
    hit=$(tail -n +"$((LINE_MARK + 1))" "$OUT_LOG" 2>/dev/null | grep -E "$pattern" | tail -1 || true)
    if [[ -n "$hit" ]]; then
      echo "$hit"
      LINE_MARK=$(wc -l < "$OUT_LOG" | tr -d ' ')
      return 0
    fi
    local err
    err=$(tail -n +"$((LINE_MARK + 1))" "$OUT_LOG" 2>/dev/null | grep -E '^ERR ' | tail -1 || true)
    if [[ -n "$err" && "$pattern" == ^OK* ]]; then
      echo "Command failed: $err" >&2
      cat "$ERR_LOG" >&2 || true
      exit 1
    fi
    if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
      echo "Daemon exited early" >&2
      cat "$ERR_LOG" >&2 || true
      cat "$OUT_LOG" >&2 || true
      exit 1
    fi
    if (( $(date +%s) - start >= timeout )); then
      echo "Timeout waiting for: $pattern" >&2
      tail -n +"$((LINE_MARK + 1))" "$OUT_LOG" >&2 || true
      cat "$ERR_LOG" >&2 || true
      exit 1
    fi
    sleep 0.05
  done
}

send() {
  mark_log
  printf '%s\n' "$1" >&3
}

echo "==> Waiting READY"
READY=$(wait_for_new '^READY ')
READY_NS=$(python3 -c 'import time; print(time.monotonic())')
STARTUP_MS=$(python3 -c "print(round((${READY_NS}-${START_NS})*1000, 1))")
echo "    $READY  (jvm_startup_ms=$STARTUP_MS)"

send "CREATE 240 320"
CREATE=$(wait_for_new '^OK CREATE ')
ID=$(echo "$CREATE" | sed -E 's/.*id=([0-9]+).*/\1/')
echo "    $CREATE"

send "PAINTER $FRAMES"
PAINTER=$(wait_for_new '^OK PAINTER ')
echo "    $PAINTER"
FRAMES_AFTER_PAINTER=$(grep -c '^FRAME ' "$OUT_LOG" || true)
if (( FRAMES_AFTER_PAINTER < 2 )); then
  echo "Expected >=2 FRAME lines after PAINTER" >&2
  exit 1
fi

send "NOT_A_REAL_COMMAND"
ERR=$(wait_for_new '^ERR ')
echo "    recovery: $ERR"
send "PING"
PING1=$(wait_for_new '^OK PING ')
echo "    $PING1"
echo "$PING1" | grep -q "id=$ID"

send "LOAD $JAR_URL"
LOAD=$(wait_for_new '^OK LOAD ')
echo "    $LOAD"
echo "$LOAD" | grep -q "id=$ID"

T0=$(python3 -c 'import time; print(time.monotonic())')
send "RUN"
RUN=$(wait_for_new '^OK RUN ')
T1=$(python3 -c 'import time; print(time.monotonic())')
RUN_MS=$(python3 -c "print(round((${T1}-${T0})*1000, 1))")
echo "    $RUN  (run_latency_ms=$RUN_MS)"
echo "$RUN" | grep -q "id=$ID"

send "FRAME_PROBE"
PROBE=$(wait_for_new '^OK FRAME_PROBE ')
echo "    $PROBE"
echo "$PROBE" | grep -q "id=$ID"
echo "$PROBE" | grep -q 'midletRunning=true'
FRAMES_TOTAL=$(grep -c '^FRAME ' "$OUT_LOG" || true)
if (( FRAMES_TOTAL <= FRAMES_AFTER_PAINTER )); then
  echo "Expected additional FRAME after FRAME_PROBE" >&2
  exit 1
fi

RSS_KB=$(ps -o rss= -p "$DAEMON_PID" | tr -d ' ')
echo "    approx_rss_kb=$RSS_KB"

send "STOP"
STOP=$(wait_for_new '^OK STOP ')
echo "    $STOP"
echo "$STOP" | grep -q "id=$ID"

kill -0 "$DAEMON_PID"

send "SHUTDOWN"
wait_for_new '^OK SHUTDOWN ' >/dev/null
exec 3>&-
wait "$DAEMON_PID" || true
trap - EXIT

echo
echo "PASS — single JVM pid=$DAEMON_PID platform_id=$ID frames=$FRAMES_TOTAL startup_ms=$STARTUP_MS run_ms=$RUN_MS rss_kb=$RSS_KB"
