# E5-US003 — Persistent Runtime Design Spike

**Type:** Architecture / feasibility spike (documentation only)  
**Status:** Design — **not implemented**  
**Constraints:** Do not modify FreeJ2ME. Do not change `EmulatorBridgeProtocol`, `RuntimeHostProtocol`, or `FreeJ2MERuntimeAdapter` public APIs. Do not implement the persistent runtime in this story.

**Goal:** Reduce implementation risk before replacing the ephemeral `Process` bootstrap with a runtime that stays alive for the lifetime of an `EmulatorSession`.

---

## 1. Current execution model

### 1.1 End-to-end path today

```
LibraryViewModel.selectGame
  → EmulatorView.task
    → EmulatorViewModel.startSession
      → EmulatorBridge.launch(LaunchConfiguration)
        → FreeJ2MERuntimeHost.launch
          → FreeJ2MERuntimeAdapter.start
            → ProcessFreeJ2MEMobilePlatformBootstrap.(each hook)
              → Foundation.Process (macOS only)
                → java -cp … org.javaone.freej2me.MobilePlatformBootstrap …
                  → new MobilePlatform / setPainter / loadJar / runJar
                  → System.exit / process termination
```

On iOS, every bootstrap hook throws `EmulatorBridgeError.runtimeUnavailable` before any JVM exists.

### 1.2 Swift → Process → JVM → Bootstrap → Exit

| Step | What happens |
|------|----------------|
| **Swift adapter** | `FreeJ2MERuntimeAdapter.start` runs Contract C **sequentially**: `initializeRuntime` (no-op) → `createMobilePlatform` → `registerPainter` → `loadJar` → `runJar`. |
| **Process** | Each of those four hooks calls `runHostJVMBootstrap`, which creates a **new** `Foundation.Process`, runs `bin/java`, and **`waitUntilExit()` on `@MainActor`**. |
| **JVM** | HotSpot (host JDK) with `-Djava.awt.headless=true` and `-Djava.security.manager=allow`. Classpath = compiled FreeJ2ME + JavaOne-owned `MobilePlatformBootstrap`. |
| **Bootstrap** | `MobilePlatformBootstrap.main` constructs `MobilePlatform`, binds `Mobile.setPlatform`, optionally installs painter / loads JAR / calls `runJar()`, prints structured stdout (`OK`, `FRAME`, `LOAD_JAR_OK`, `RUN_JAR_OK`, …), then **exits**. |
| **Exit** | Process terminates. All Java heap state (`MobilePlatform`, `MIDletLoader`, active MIDlet, painter closure, LCD `BufferedImage`) is destroyed. |

### 1.3 Why this is not a session

1. **Four processes per launch (typical).** Adapter state flags (`isMobilePlatformCreated`, `isJarLoaded`, …) are **Swift-side illusions**. The JVM that created the platform is already dead before `loadJar` runs in a fresh process.
2. **`run-jar` re-does everything in one process.** `MobilePlatformBootstrap.runJarSequence` installs painter, `loadJar`, then `runJar()` in a single JVM — the only mode that preserves loader state. Even then, after `START_APP_OK` the bootstrap calls `exitProcess(0)`.
3. **Frames are probe artifacts.** UI `frameAvailable` events today come from `registerPainter`’s synthetic double-paint (or stub bootstraps in tests). `parseRunJarOutput` **ignores** `FRAME` lines emitted during `run-jar`.
4. **No live loop.** There is no long-lived thread delivering continuous paints, input, pause, or stop into FreeJ2ME after launch returns.
5. **pause / resume / stop are no-ops** in the adapter; the host still emits lifecycle events.

### 1.4 What FreeJ2ME actually needs in-process

From `Vendor/FreeJ2ME/.../MobilePlatform.java` (unchanged):

- `MobilePlatform` owns LCD (`PlatformImage` → `BufferedImage`), `loader` (`MIDletLoader`), and `painter` (`Runnable`).
- `loadJar(String)` constructs `MIDletLoader` and assigns `platform.loader`.
- `runJar()` calls `loader.start()` (MIDlet construction + `startApp`).
- `flushGraphics` / `repaint` call `painter.run()` on the **same** platform instance.
- Input APIs (`keyPressed`, pointer*, …) require `Mobile.getDisplay().getCurrent()` on that live instance.

**Conclusion:** A persistent session requires **one** Java runtime address space that retains the same `MobilePlatform` (and thus loader + MIDlet + painter) from launch until stop.

---

## 2. Persistent runtime model

### 2.1 Target lifecycle (aligned with `EmulatorSession`)

```
Launch (Bridge validates → Host.launch → Adapter.start)
  ↓
Initialize JVM / embedded runtime          [once per session or process]
  ↓
Create MobilePlatform + Mobile.setPlatform
  ↓
Register Painter (callback → pixel copy → Swift)
  ↓
Configure dataPath (sandbox RMS)           [required for real games; not wired today]
  ↓
Load MIDlet (loadJar)
  ↓
Run MIDlet (runJar / loader.start)         [returns after startApp; game threads continue]
  ↓
Frame loop (painter.run on FreeJ2ME paint path)
  ↓
Receive input (key*/pointer* → Display)    [future; out of this spike’s implementation]
  ↓
Pause (suspend MIDlet / timers as supported)
  ↓
Resume
  ↓
Stop (destroyApp / clear Display / drop refs)
  ↓
Destroy runtime (optional: tear down JVM if session-scoped)
```

### 2.2 Session semantics

| Phase | Persistent runtime behavior | Maps to existing APIs |
|-------|-----------------------------|------------------------|
| Launch | Bring up (or attach to) JVM; create platform; painter; load; run; host yields `.started` after adapter `start` succeeds. Frames may arrive **before** `.started` (already true today). | `RuntimeHost.launch` / `Adapter.start` unchanged signatures |
| Running | Painter callbacks keep producing `EmulatorFrame` copies; game threads live inside Java. | `onFrameCaptured` → Host pipe → Bridge → ViewModel |
| Pause / Resume | Adapter implements real suspend/resume against FreeJ2ME/Display (or documented best-effort). Host still yields `.paused` / `.resumed`. | `pause()` / `resume()` keep empty public surface, gain behavior |
| Stop | Stop MIDlet activity, unregister painter, clear platform binding, finish or reset event stream policy, destroy session-scoped JVM if any. | `stop()` |
| Destroy | No second launch until previous stop completed (Bridge already enforces `runtimeAlreadyRunning`). | Bridge validation unchanged |

### 2.3 Process topology options (feasibility)

These are **design choices**, not implementations. FreeJ2ME Vendor stays unmodified; JavaOne-owned façade may grow.

| Option | Description | Fits iOS? | Fits “one platform instance”? |
|--------|-------------|-----------|-------------------------------|
| **A. Long-lived child Process (macOS host)** | One `java` process; Swift talks via stdin/stdout or local IPC for commands + frames. | No (`Process` unavailable on iOS) | Yes, inside that process |
| **B. In-process embedded JVM (JNI/FFI)** | JVM (or alternate Java runtime) loaded into the app; Adapter calls FreeJ2ME via JNI. | Conditionally — **the** iOS spike | Yes |
| **C. Hybrid** | macOS: A for development; iOS: B when available. Same Adapter/Host APIs. | Partial | Yes if both backends share Contract C |

**Spike recommendation:** Treat **B** as the product target for iOS; keep **A** as a macOS engineering harness that evolves from today’s ephemeral Process into a **single persistent Process** so Contract C and frame streaming can be proven **before** an embedded JVM exists.

### 2.4 Persistent Process harness (macOS-first design)

Without changing Adapter public APIs, replace `ProcessFreeJ2MEMobilePlatformBootstrap` internals (or add a parallel `PersistentProcess…` behind the same `FreeJ2MEMobilePlatformBootstrapping` protocol) so that:

1. First `bootstrapMobilePlatform` **starts** the JVM child (or attaches) and sends `CREATE_PLATFORM`.
2. Subsequent `registerPainter` / `loadJar` / `runJar` send commands to the **same** process.
3. Painter frames stream as asynchronous `FRAME` messages (or shared-memory later) for the session lifetime.
4. `stop` sends `STOP` / `DESTROY` and waits for clean exit.

This proves persistence without waiting on App Store JVM policy.

---

## 3. Required architectural changes

Public protocols and Adapter method signatures stay fixed. Changes are **behind** those seams.

| Component | Change needed | Responsibility after change | Complexity | Risk |
|-----------|---------------|-----------------------------|------------|------|
| **`ProcessFreeJ2MEMobilePlatformBootstrap`** (or successor conforming to `FreeJ2MEMobilePlatformBootstrapping`) | Stop spawning one JVM per hook; hold session process / channel; stream frames; map stop. | Sole executor of Contract C against a **live** Java side | **High** | Process I/O races; MainActor blocking; incomplete teardown |
| **`MobilePlatformBootstrap.java` (JavaOne-owned)** | Evolve from one-shot `main` to a **command loop** (or daemon mode): create once, accept load/run/pause/stop, stream FRAME, exit only on destroy | Keep FreeJ2ME untouched; own embed façade | **High** | Protocol design; `System.exit` from MIDlets; thread model |
| **`FreeJ2MERuntimeAdapter` (implementation only)** | Keep `start`/`pause`/`resume`/`stop` signatures; make flags reflect **real** live state; implement pause/resume/stop against bootstrap; avoid treating multi-process probes as truth | FreeJ2ME contact + Contract C orchestration | **Medium** | State machine bugs if bootstrap lies |
| **`FreeJ2MERuntimeHost` (implementation only)** | Possibly hop frame yields off MainActor; ensure `.stopped` after destroy; document frame-before-started | Event publication + lifecycle events | **Low–Medium** | Dropped events under `bufferingNewest(64)` |
| **`RuntimeEventPipe`** | Consider finish-on-stop + new pipe per session, or reset policy; optional dedicated frame channel | Backpressure / session isolation | **Medium** | Breaking tests that assume singleton stream |
| **`DefaultEmulatorBridge`** | No protocol change; may need clearer coupling of stop → host destroy so shared bridge can relaunch | Session validation + single active session | **Low** | Already rejects second launch |
| **`EmulatorViewModel` / Views** | No required change for persistence spike; already observe-before-launch | UI session lifetime | **Low** | None if Bridge/Host correct |
| **DI (`AppDependencyContainer`)** | Swap bootstrap implementation when ready | Wire persistent backend | **Low** | Premature enable on iOS → soft fail already |
| **New: frame transport** | File dump → streaming IPC / ring buffer / JNI direct ByteBuffer | Pixel path without Vendor edits | **High** | Latency, copies, thread safety |
| **New: embedded JVM façade (iOS)** | Separate from Process bootstrap; same bootstrapping protocol | Make iOS possible at all | **Very High** | Technical + App Store |
| **Tests** | Persistent harness tests (macOS); stub still for unit; XCTSkip iOS until B exists | Prove one process / multi-command / stop | **Medium** | Flaky Process tests |

**Explicit non-changes (this spike / next implementation stories):**

- `EmulatorBridgeProtocol`
- `RuntimeHostProtocol`
- Public API surface of `FreeJ2MERuntimeAdapter` (`start`, `createMobilePlatform`, `registerPainter`, `loadJar`, `runJar`, `pause`, `resume`, `stop`, `onFrameCaptured`, …)
- `Vendor/FreeJ2ME` sources

---

## 4. Adapter responsibilities vs Host

### 4.1 Remains inside `FreeJ2MERuntimeAdapter`

- Sole component allowed to know FreeJ2ME / bootstrap types.
- Contract C sequencing and ordering guards.
- JAR path validation at the FreeJ2ME boundary.
- Mapping bootstrap results → adapter state flags and typed results (`FreeJ2MEJarLoadResult`, frame captures).
- Invoking `onFrameCaptured` with **app-facing** `EmulatorFrame` (no SwiftUI/Metal).
- Implementing real `pause` / `resume` / `stop` **effects** via bootstrap (still no public API change).
- Choosing LCD defaults and `file://` URL formatting for `loadJar`.

### 4.2 Belongs to `FreeJ2MERuntimeHost`

- Conformance to `RuntimeHostProtocol`.
- Ownership of `RuntimeEventPipe` and publication of `.started` / `.failed` / `.paused` / `.resumed` / `.stopped` / `.frameAvailable`.
- Wiring `adapter.onFrameCaptured` → `eventPipe.yield(.frameAvailable)`.
- **Not** constructing `MobilePlatform`, touching Vendor, or parsing Java stdout.
- **Not** rendering or talking to ViewModels (Bridge sits above).

### 4.3 Belongs to Bridge (unchanged contract)

- Pre-flight validation, `EmulatorSession` state machine, single-active-session policy.
- Forwarding `runtimeEvents` from Host.

### 4.4 Boundary rule

```
Host  = “when did the runtime start/stop, and here are frames as RuntimeEvent”
Adapter = “how do we drive FreeJ2ME Contract C and copy pixels”
Bootstrap = “how do we keep one Java runtime alive and obey commands”
```

---

## 5. Runtime ownership

| Asset | Owner (persistent model) | Notes |
|-------|--------------------------|-------|
| **JVM / embedded runtime** | Bootstrap façade (Process child **or** in-process engine). Adapter holds the façade; Host does not. | Session-scoped preferred until multi-game concurrency is designed. |
| **`MobilePlatform`** | Java side (FreeJ2ME object). Bootstrap creates/binds it; Adapter tracks “created” flag only. | Must not be recreated mid-session. |
| **`MIDletLoader` (`platform.loader`)** | FreeJ2ME `MobilePlatform` after `loadJar`. | Dead if process exits. |
| **Active MIDlet** | FreeJ2ME / Display after `runJar` / `loader.start()`. | Pause/stop must go through MIDP lifecycle where possible. |
| **Frame callbacks (`painter`)** | Registered by Bootstrap/Adapter onto `MobilePlatform.setPainter`. Pixel **copies** become `EmulatorFrame`; Host publishes events. | Painter may run on FreeJ2ME threads — not MainActor. |
| **Lifecycle events** | Host publishes; Bridge owns `EmulatorSession`; ViewModel mirrors session for UI. | Dual session mirrors already exist; do not add a third owner. |
| **Event pipe** | Host | Consider per-session pipe on stop to avoid stale consumers. |

---

## 6. Threading

### 6.1 Problem today

- Entire Contract C runs on `@MainActor`.
- `Process.waitUntilExit()` blocks the UI thread for javac/java duration.
- Painter probes complete before `start` returns; no concurrent paint after launch.

### 6.2 Proposed model

```
FreeJ2ME paint / game threads
  → painter.run()
    → copy ARGB to owned buffer (Java or JNI)
      → handoff to Swift runtime queue (non-MainActor)
        → build EmulatorFrame (Data copy)
          → hop to MainActor
            → Host eventPipe.yield(.frameAvailable)
              → EmulatorViewModel.applyFrame → CGImage
```

| Concern | Proposal |
|---------|----------|
| **Background threads** | Java MIDlet + paint path stay off the Apple main thread. Process I/O / JNI callbacks land on a dedicated Swift serial executor (e.g. “FreeJ2MERuntime”). |
| **MainActor** | Only Host yield + ViewModel mutation + Bridge session transitions. Never `waitUntilExit` on MainActor; use async Process APIs or a detached worker for the macOS harness. |
| **Synchronization** | Single-writer for pipe yields; Adapter state mutations only on MainActor **or** only on the runtime executor (pick one; do not mix). Prefer: runtime executor owns Adapter mutable flags; Host hop publishes events. *If Adapter remains `@MainActor`, frame handoff must `MainActor.assumeIsolated` / `await MainActor.run` with clear backpressure.* |
| **Backpressure** | Keep `bufferingNewest(N)` for frames (drop old LCD frames under load — correct for display). Do **not** mix critical lifecycle events in a buffer that drops under frame flood — either separate streams internally then merge carefully, or reserve buffer slots / prioritize lifecycle. |
| **Input (future)** | UI → MainActor → Bridge → Host → Adapter → runtime executor → Java `key*`/`pointer*` (never call Java from SwiftUI draw). |
| **Cancellation** | `stop` must be synchronous enough for Bridge invariants, but teardown work can complete on the runtime executor; ViewModel already cancels its `for await` Task. |

### 6.3 Memory of frames

Retain current rule: **copy** out of FreeJ2ME/`BufferedImage` into independent `Data`. CGImage may share that `Data` via `CGDataProvider` if immutable. No shared mutable framebuffer across the language boundary.

---

## 7. iOS blockers

| Blocker | Why it blocks a persistent session on device |
|---------|-----------------------------------------------|
| **Embedded JVM** | No App Store–viable HotSpot. Alternate runtimes (interpreter, AOT, third-party) are unproven for FreeJ2ME’s SE surface. Without this, Contract C cannot execute in-process. |
| **`Process` / child `java`** | Unavailable / inappropriate on iOS. Current bootstrap is macOS-only by construction. |
| **AWT** | `PlatformImage` / `PlatformGraphics` / `getLCD()` are AWT `BufferedImage`-shaped. Headless AWT must work on the chosen runtime **or** an allowlisted graphics backend fork is required (Vendor fork policy — out of scope to implement here, but a hard dependency). |
| **`BufferedImage` LCD** | Painter path copies from `getLCD()`. If the runtime cannot provide this type, persistence alone does not help. |
| **`System.exit`** | FreeJ2ME / MIDlet failure paths may call `System.exit`. In a child Process, exit kills the session (recoverable). **In-process**, exit kills the **app** unless a SecurityManager / runtime trap exists (SecurityManager itself is deprecated/removed on modern JDKs — already a fragile guard on JDK 17). |
| **Java Sound** | `javax.sound.sampled` / MIDI backends assumed by FreeJ2ME audio. Needs replacement or stub for iOS; not required for “persistent LCD + input” MVP but blocks “playable”. |
| **ASM / `defineClass`** | MIDlet loading uses bytecode rewriting. Runtime must allow dynamic class definition. |
| **App Store restrictions** | Interpreted code download policies, GPL-3 compliance/distribution, JIT restrictions, large native runtimes, private API risk of exotic JVMs. Legal + technical gate. |
| **No clean embed teardown API in FreeJ2ME** | Upstream is desktop/libretro-oriented; multi-session embed is not a first-class API. Persistence must be designed in JavaOne’s façade without editing Vendor initially — may later force an allowlisted fork for `destroyApp` / exit traps. |

**Ordering:** Embedded JVM + AWT/`BufferedImage` feasibility **gates** iOS. Persistent Process on macOS **de-risks** session/frame/stop design independently.

---

## 8. Migration plan

Each step is independently testable. Difficulty: Low / Medium / High.

| Step | Work | Testability | Difficulty |
|------|------|-------------|------------|
| **M0 — Freeze seams** | Confirm Bridge / Host / Adapter public APIs remain the integration contract; document this spike as source of truth for persistence. | Review-only / existing unit tests green | **Low** |
| **M1 — Persistent command protocol (design)** | Specify stdin/stdout or length-prefixed messages: `CREATE`, `PAINTER`, `LOAD`, `RUN`, `PAUSE`, `RESUME`, `STOP`, `FRAME`, errors. | Golden fixtures for parser | **Medium** |
| **M2 — JavaOne bootstrap daemon mode (macOS)** | Extend `MobilePlatformBootstrap` with a long-running loop **without** modifying Vendor. One JVM; commands mutate one `MobilePlatform`. | Java unit / process integration: create→load→run→stop; assert same PID | **High** |
| **M3 — Swift persistent Process bootstrap** | New or evolved bootstrap conforming to `FreeJ2MEMobilePlatformBootstrapping`; Adapter DI swap on macOS tests. | Adapter tests against real persistent Process; flags survive across hooks | **High** |
| **M4 — Streaming frames** | Parse continuous `FRAME` during RUN; call `onFrameCaptured` asynchronously; prove ViewModel LCD updates after `start` returns. | Integration: probe MIDlet paints N frames; VM `receivedFrameCount >= N` | **High** |
| **M5 — MainActor unblocking** | Move Process I/O off MainActor; Host hop for yields. | UI responsiveness test / timeout tests under slow JVM | **Medium** |
| **M6 — Real stop / pause / resume** | Implement adapter lifecycle against daemon; Bridge session still drives API. | Launch → pause → resume → stop → second launch succeeds | **Medium** |
| **M7 — Event pipe session hygiene** | finish/reset stream on stop; avoid dropped lifecycle under frame flood. | Concurrent frame + stop ordering tests | **Medium** |
| **M8 — dataPath / RMS sandbox** | Wire `MobilePlatform.dataPath` to app container (façade only). | File written under sandbox path | **Medium** |
| **M9 — Embedded JVM spike (iOS)** | Separate feasibility: load runtime, hello JNI, AWT headless `BufferedImage`, SecurityManager/`System.exit` trap. **Go/no-go gate.** | Spike harness app or macOS-equivalent in-process first | **High** |
| **M10 — In-process bootstrap backend** | Implement `FreeJ2MEMobilePlatformBootstrapping` via JNI/FFI; same Adapter. | Contract C tests on chosen runtime | **High** |
| **M11 — Production DI** | Point iOS DI at in-process backend when M9–M10 pass; keep Process harness for Mac Catalyst/dev if desired. | `AppDependencyContainer` tests + device smoke | **Medium** |

**Suggested sequence for risk reduction:** M0 → M1 → M2 → M3 → M4 → M5 → M6 → M7, **in parallel** with M9. Do not start M10/M11 until M9 is green.

---

## 9. Design decisions locked by this spike

1. **Persistence is mandatory** for a real `EmulatorSession`; ephemeral Process-per-hook cannot be the product model.
2. **Public Bridge / Host / Adapter APIs do not need to change** to introduce persistence; the bootstrapping backend and JavaOne-owned Java façade do.
3. **Host vs Adapter split stays:** events in Host, FreeJ2ME contact in Adapter.
4. **Frames remain copies**; painter may be asynchronous relative to `launch` returning.
5. **macOS persistent Process** is the proving ground; **embedded JVM** is the iOS gate.
6. **Vendor/FreeJ2ME remains unmodified** until an allowlisted fork is explicitly approved (AWT/`System.exit` may force that later — tracked as risk, not as this story’s work).

---

## 10. Out of scope (explicit)

- Implementing persistent runtime, JNI, or daemon bootstrap.
- Input, audio, save states, Metal renderer.
- Modifying FreeJ2ME.
- Changing `EmulatorBridgeProtocol`, `RuntimeHostProtocol`, or Adapter public APIs.
- Choosing a specific commercial/OSS embedded JVM vendor (belongs to M9).

---

## 11. References (codebase)

| Artifact | Path |
|----------|------|
| Host | `JavaOne/Features/Emulator/Runtime/FreeJ2MERuntimeHost.swift` |
| Adapter | `JavaOne/Features/Emulator/Runtime/FreeJ2MERuntimeAdapter.swift` |
| Process bootstrap | `JavaOne/Features/Emulator/Runtime/FreeJ2MEMobilePlatformBootstrap.swift` |
| Java façade | `JavaOne/Features/Emulator/Runtime/Bootstrap/MobilePlatformBootstrap.java` |
| FreeJ2ME platform | `Vendor/FreeJ2ME/src/org/recompile/mobile/MobilePlatform.java` |
| Prior contracts | `docs/FREEJ2ME_RUNTIME_CONTRACT.md`, `docs/FREEJ2ME_ASSESSMENT.md`, `docs/FREEJ2ME_INTEGRATION_STRATEGY.md` |
| E5-R001 audit | Canvas `e5-r001-integration-audit` (read-only integration audit) |

---

*End of E5-US003 design spike document.*
