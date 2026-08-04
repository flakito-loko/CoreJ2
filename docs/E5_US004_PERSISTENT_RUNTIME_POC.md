# E5-US004 — Persistent Runtime Proof of Concept (macOS)

**Type:** Isolated proof of concept  
**Status:** Prototype only — **not** wired into production DI / SwiftUI / Adapter  
**Depends on:** `docs/E5_US003_PERSISTENT_RUNTIME_DESIGN.md`  
**Constraints:** FreeJ2ME unmodified. `EmulatorBridgeProtocol`, `RuntimeHostProtocol`, and Adapter public APIs unmodified. Existing `ProcessFreeJ2MEMobilePlatformBootstrap` and one-shot `MobilePlatformBootstrap` remain the production path.

---

## 1. Sequence diagram

```
Swift PersistentRuntimePOCClient          JVM PersistentMobilePlatformDaemon
        |                                              |
        |-- start Process (once) --------------------->|
        |                                              | install SecurityManager
        |<---------------- READY poc=1 ----------------|
        |                                              |
        |-- CREATE 240 320 --------------------------->|
        |        new MobilePlatform + Mobile.setPlatform
        |<--------- OK CREATE id=N w=240 h=320 --------|
        |                                              |
        |-- PAINTER <dir> ---------------------------->|
        |        setPainter(capturing)                 |
        |        synthetic paint ×2                    |
        |<-------------- FRAME … ----------------------|
        |<-------------- FRAME … ----------------------|
        |<--------- OK PAINTER id=N paints=2 ----------|
        |                                              |
        |-- LOAD file://…jar ------------------------->|
        |        platform.loadJar                      |
        |<--------- OK LOAD name=… id=N ---------------|
        |                                              |
        |-- RUN -------------------------------------->|
        |        platform.runJar / startApp            |
        |<--------- OK RUN … started=true -------------|
        |                                              |
        |-- FRAME_PROBE ------------------------------>|
        |        fillLCD + painter.run (same platform) |
        |<-------------- FRAME … ----------------------|
        |<--------- OK FRAME_PROBE id=N … -------------|
        |                                              |
        |-- STOP ------------------------------------->|
        |        clear painter/loader flags            |
        |<-------------- OK STOP id=N -----------------|
        |                                              |
        |-- SHUTDOWN --------------------------------->|
        |<------------- OK SHUTDOWN id=N --------------|
        |        System.exit(0)                        |
        |<-------- process termination ----------------|
```

**Invariant validated:** `Process.run` count = **1**; `id=N` is stable across CREATE → PAINTER → LOAD → RUN → FRAME_PROBE → STOP.

---

## 2. IPC protocol

Transport: **stdin / stdout**, UTF-8, **one record per line**. stderr is diagnostic only.

### 2.1 Lifecycle

| Direction | Line | Meaning |
|-----------|------|---------|
| ← | `READY poc=1` | Daemon listening |
| → | `CREATE <w> <h>` | Construct one `MobilePlatform` |
| ← | `OK CREATE id=<hash> w=<w> h=<h>` | Platform ready |
| → | `PAINTER <frameDir>` | Register capturing painter once |
| ← | `FRAME …` (async / before OK) | Pixel snapshot metadata + file path |
| ← | `OK PAINTER id=<hash> paints=<n>` | Painter registered |
| → | `LOAD <fileURL>` | `MobilePlatform.loadJar` |
| ← | `OK LOAD name=<midlet> id=<hash>` | Loader ready |
| → | `RUN` | `MobilePlatform.runJar` / `startApp` |
| ← | `OK RUN name=<midlet> id=<hash> started=true` | MIDlet started; **JVM stays up** |
| → | `FRAME_PROBE` | Force paint via retained painter |
| ← | `FRAME …` + `OK FRAME_PROBE …` | Post-`runJar` frames on same platform |
| → | `PING` | Liveness / state echo |
| ← | `OK PING id=… painter=… loaded=… running=… paints=…` | |
| → | `STOP` | Best-effort session reset (no Vendor edits) |
| ← | `OK STOP id=<hash>` | |
| → | `SHUTDOWN` | Clean process exit |
| ← | `OK SHUTDOWN id=<hash>` | Then exit 0 |
| ← | `ERR <CODE> <message>` | Command failed; **process remains alive** |

### 2.2 FRAME record

Same shape as the production one-shot bootstrap:

```
FRAME <index> <width> <height> <pixelCount> <checksum> <pixelFormat> <pixelFilePath>
```

Pixels are an independent little-endian ARGB8888 file (FreeJ2ME heap is not shared).

---

## 3. Runtime lifecycle

```
Cold
  → start()           # one JVM
  → READY
  → CREATE            # one MobilePlatform
  → PAINTER           # one painter registration
  → LOAD / RUN        # MIDlet session
  → FRAME_PROBE*      # continuous paint capability
  → STOP              # clear session bindings (POC-level)
  → SHUTDOWN          # destroy JVM
Dead
```

Production Adapter flags that today are “Swift illusions” become **real** in this topology: platform, painter, and loader live in one address space until STOP/SHUTDOWN.

---

## 4. Thread model

| Thread | Role |
|--------|------|
| Swift MainActor (tests / POC client) | Sends commands; parses lines; records metrics. Uses `RunLoop` briefly while waiting (POC only — not a production UI pattern). |
| JVM main | Command loop (`readLine` → handle). |
| FreeJ2ME / MIDlet threads | May run after `runJar`; painter may be invoked from FreeJ2ME paint paths. |
| Painter callback | Synchronizes stdout via `stdoutLock` before emitting `FRAME` / `ERR FRAME`. |

**POC limitation:** the client is `@MainActor` and blocks waiting for lines. E5-US003 still recommends a dedicated runtime executor before production adoption.

---

## 5. Measured metrics (POC client / host script)

Captured in `PersistentRuntimePOCMetrics` and printed by `scripts/run_persistent_runtime_poc.sh`.

| Metric | Field / script key | Notes |
|--------|--------------------|-------|
| JVM startup | `jvmStartupNanoseconds` / `startup_ms` | Connect stdin → `READY` |
| Command latency | `commandLatenciesNanoseconds[name]` / `run_ms` | CREATE, PAINTER, LOAD, RUN, FRAME_PROBE, … |
| Memory | `approximateMemoryBytes` / `rss_kb` | Child RSS via `/bin/ps` (~60 MB observed on host JDK 17) |
| Launch count | `jvmLaunchCount` | Must remain `1` |
| Frames | `frameCount` / `frames` | PAINTER synthetics + FRAME_PROBE (≥ 3) |
| Clean shutdown | `cleanShutdown` | `OK SHUTDOWN` observed |
| Failure recovery | `failureRecoverySucceeded` | `ERR` on bad command + subsequent `PING` |

**Host sample (JDK 17, this machine):** single JVM; stable platform id; 3 frames; ~59 MB RSS; STOP+SHUTDOWN clean. Sub-second command latencies (script timers are coarse for warm daemon).

**XCTest:** `PersistentRuntimePOCTests` exercises the Swift client on **macOS**; on iOS Simulator it `XCTSkip`s (no `Process`). The app target remains iOS-only — production code paths unchanged.

---

## 6. Known limitations

1. **macOS-only.** iOS has no `Process` / host JDK; client stubs throw `runtimeUnavailable`.
2. **Not production.** Not connected to Bridge, Host, Adapter, DI, or SwiftUI.
3. **Does not replace** `ProcessFreeJ2MEMobilePlatformBootstrap` or one-shot `MobilePlatformBootstrap`.
4. **`FRAME_PROBE` is synthetic** after `ProbeMIDlet` (which does not paint). It proves painter + platform survival, not a continuous game render loop.
5. **`STOP` is best-effort** (clear painter / loader refs) — not a full MIDP `destroyApp` / Display teardown (would require deeper FreeJ2ME integration or an allowlisted fork).
6. **stdin/stdout framing** is line-based; not binary-safe for paths with newlines; no length-prefix yet.
7. **MainActor blocking** in the POC client is unacceptable for shipping UI.
8. **SecurityManager** exit guard is fragile on modern JDKs (same as production bootstrap).
9. **No input / audio / dataPath** in this POC.
10. **Shared stdout** with FreeJ2ME `System.out` noise is mitigated for `RUN` via tee, but remains a protocol risk.

---

## 7. Artifacts

| Piece | Path |
|-------|------|
| Daemon | `JavaOne/Features/Emulator/Runtime/Bootstrap/PersistentMobilePlatformDaemon.java` |
| Swift client | `JavaOne/Features/Emulator/Runtime/POC/PersistentRuntimePOCClient.swift` |
| Host script | `scripts/run_persistent_runtime_poc.sh` |
| Tests | `JavaOneTests/PersistentRuntimePOCTests.swift` |
| Design | `docs/E5_US003_PERSISTENT_RUNTIME_DESIGN.md` |

---

## 8. Recommendation

**Yes — JavaOne should migrate toward this architecture**, in stages:

1. **Adopt the persistent-process model on macOS** as the next engineering backend behind `FreeJ2MEMobilePlatformBootstrapping` (replacing ephemeral Process-per-hook), without changing Bridge/Host/Adapter public APIs.
2. **Keep the one-shot bootstrap** until the persistent backend passes the same Contract C tests.
3. **Do not treat this POC as shippable** — promote only after: async I/O off MainActor, robust STOP, streaming frames from real paints, and session-scoped event pipe hygiene (E5-US003 M4–M7).
4. **iOS remains gated** on an embedded JVM / AWT strategy (E5-US003 M9). This POC validates session semantics; it does **not** remove the iOS runtime blocker.

**Bottom line:** The ephemeral Process model is insufficient for a real `EmulatorSession`. This POC confirms a single JVM + single `MobilePlatform` can survive CREATE → PAINTER → LOAD → RUN → post-run frames → STOP → SHUTDOWN. Proceed with a production-quality persistent bootstrap on macOS; keep Vendor FreeJ2ME unmodified.
