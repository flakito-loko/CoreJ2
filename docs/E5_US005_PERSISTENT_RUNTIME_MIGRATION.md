# E5-US005 — Migrate Production Runtime to Persistent JVM

**Status:** Implemented (macOS host). iOS continues to fail soft with `runtimeUnavailable`.  
**Depends on:** E5-US003 design, E5-US004 POC  
**Constraints honored:** No FreeJ2ME edits. No Bridge / Host / Adapter **public API** changes. No Library / Import Engine changes.

---

## 1. Migration strategy

1. Keep the validated daemon (`PersistentMobilePlatformDaemon`) as the JavaOne-owned JVM entrypoint.
2. Promote POC IPC into production `PersistentProcessFreeJ2MEMobilePlatformBootstrap` conforming to `FreeJ2MEMobilePlatformBootstrapping`.
3. Extend the bootstrap protocol with `frameHandler` + `shutdownRuntime()` (internal seam only).
4. Default `FreeJ2MERuntimeAdapter` to the persistent bootstrap.
5. Implement `Adapter.stop()` → `shutdownRuntime()` (STOP + SHUTDOWN).
6. Retain `ProcessFreeJ2MEMobilePlatformBootstrap` (ephemeral) for rollback and legacy host tests.
7. Leave `AppDependencyContainer` → `FreeJ2MERuntimeHost` → `FreeJ2MERuntimeAdapter()` unchanged at the DI call site; the default bootstrap swap is enough.

Lifecycle now:

```
Launch → Persistent JVM → CREATE MobilePlatform → PAINTER → LOAD → RUN
  → FRAME_PROBE / live paints → Stop → SHUTDOWN
```

---

## 2. Components modified

| Component | Change |
|-----------|--------|
| `FreeJ2MEMobilePlatformBootstrapping` | Added `frameHandler`, `shutdownRuntime()` |
| `ProcessFreeJ2MEMobilePlatformBootstrap` | Protocol stubs; still ephemeral (rollback) |
| `PersistentProcessFreeJ2MEMobilePlatformBootstrap` | **New** production persistent backend + metrics |
| `FreeJ2MERuntimeAdapter` | Default bootstrap = persistent; wires `frameHandler`; `stop()` tears down |
| `FreeJ2MERuntimeHost` | Unchanged public API; inherits adapter default |
| Tests / stubs | Updated for new protocol members; new persistent tests |
| POC client / daemon / script | Unchanged; still available for isolated checks |

---

## 3. Backward compatibility

- `EmulatorBridgeProtocol`, `RuntimeHostProtocol`, and Adapter public methods (`start`, `createMobilePlatform`, `registerPainter`, `loadJar`, `runJar`, `pause`, `resume`, `stop`, `onFrameCaptured`, …) keep the same signatures.
- Call sites that inject a custom bootstrap (stubs, ephemeral Process) continue to work.
- iOS behavior remains typed failure: `runtimeUnavailable`.
- Ephemeral bootstrap tests that explicitly construct `ProcessFreeJ2MEMobilePlatformBootstrap` are unaffected.

---

## 4. Rollback strategy

Inject the ephemeral bootstrap into the adapter (or a future DI hook):

```swift
FreeJ2MERuntimeAdapter(
    platformBootstrap: ProcessFreeJ2MEMobilePlatformBootstrap()
)
```

No protocol or Vendor revert required. Persistent daemon sources can remain unused.

---

## 5. Metrics (production bootstrap)

`PersistentRuntimeBootstrapMetrics`:

| Metric | Field |
|--------|--------|
| JVM startup | `jvmStartupNanoseconds` |
| Launch latency (CREATE…RUN+probe) | `launchLatencyNanoseconds` |
| Memory (approx RSS) | `approximateMemoryBytes` |
| JVM launch count | `jvmLaunchCount` (expect 1) |
| Frames | `frameCount` |
| Clean shutdown | `cleanShutdown` |

---

## 6. Remaining blockers before a playable JavaOne on macOS

1. **Input** — no keypad/pointer bridge to `MobilePlatform.key*` / pointer APIs.
2. **Continuous game frames** — post-`runJar` paint today includes a deliberate `FRAME_PROBE`; real titles must drive FreeJ2ME `painter.run()` via their own repaint loop without relying on the probe.
3. **MainActor I/O** — persistent bootstrap still awaits IPC on MainActor (POC limitation carried forward).
4. **Audio** — Java Sound not wired to Apple audio.
5. **RMS / `dataPath`** — sandbox path not configured on `MobilePlatform`.
6. **Robust MIDlet teardown** — `STOP` is best-effort without Vendor `destroyApp` integration.
7. **SecurityManager** — exit guard deprecated on modern JDKs.
8. **iOS** — still blocked (no Process / embedded JVM / AWT strategy).

macOS can now keep a real session alive for Contract C + frames + clean shutdown; “playable” still needs input (and ideally audio + RMS).

---

## 7. How to verify

```bash
# Host daemon path (optional)
./scripts/run_persistent_runtime_poc.sh

# Unit / integration
xcodebuild test -scheme JavaOne -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -only-testing:JavaOneTests
```

Persistent JVM tests `XCTSkip` on iOS Simulator; run with `JAVA_HOME` on macOS for full host coverage when a macOS test destination exists, or rely on the host script + explicit Persistent bootstrap tests skipped under iOS.
