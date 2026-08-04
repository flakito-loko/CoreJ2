# FreeJ2ME Runtime Contract

**Task:** E3-R002 — Design contract (documentation only)  
**Depends on:** E3-R001 (`docs/FREEJ2ME_ASSESSMENT.md`), E3-US001 Emulator Bridge skeleton  
**Status:** Contract definition — **not implemented in code yet**

This document defines the **runtime contract** between JavaOne and FreeJ2ME: what each side must guarantee, which APIs exist at each boundary, and what remains forbidden.

It does **not** choose the iOS JVM/runtime strategy (that remains an open spike from E3-R001). It freezes the **seam** so Library, ImportEngine, Repository, SwiftData, and ViewModels stay independent while Epic 3 progresses.

---

## 1. Purpose

JavaOne must be able to:

1. Launch an installed MIDlet from an `InstalledGame`.
2. Present frames on iOS.
3. Deliver keypad / pointer input.
4. Play audio (best effort).
5. Persist RMS under the app sandbox.
6. Pause / resume / stop a session cleanly.

…without any FreeJ2ME type leaking into product layers.

---

## 2. Layered contracts

There are **three** contracts, nested:

```
┌──────────────────────────────────────────────────────────┐
│ A. App Contract (Swift)                                  │
│    ViewModel ↔ EmulatorBridgeProtocol                    │
│    Types: LaunchConfiguration, EmulatorSession, errors   │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│ B. Runtime Adapter Contract (Swift ↔ FreeJ2ME host)      │
│    EmulatorBridge → FreeJ2MERuntimeAdapter               │
│    Frames, input, audio, filesystem, lifecycle           │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│ C. FreeJ2ME Core Hooks (upstream-compatible)             │
│    MobilePlatform.loadJar / runJar / setPainter /        │
│    key*/pointer* / dataPath                              │
└──────────────────────────────────────────────────────────┘
```

| Contract | Consumers | May know FreeJ2ME? |
|----------|-----------|--------------------|
| **A. App** | Views, ViewModels, DI factories | **No** |
| **B. Adapter** | `DefaultEmulatorBridge` (future real impl) | **Yes** (isolated module) |
| **C. Core hooks** | Adapter only | **Yes** |

---

## 3. Contract A — App Contract (`EmulatorBridgeProtocol`)

### 3.1 Ownership

- Defined in `Features/Emulator`
- Registered by `AppDependencyContainer.makeEmulatorBridge()`
- **Only** API ViewModels may use to run games

### 3.2 Required operations (target API)

Current skeleton implements only `launch`. The full Epic 3 contract **shall** expose:

| Operation | Semantics |
|-----------|-----------|
| `launch(_: LaunchConfiguration) throws -> EmulatorSession` | Create session, start (or prepare) runtime for `configuration.game` |
| `pause(_ session: EmulatorSession) throws` | Suspend MIDlet activity when supported; keep session valid |
| `resume(_ session: EmulatorSession) throws` | Resume after pause |
| `stop(_ session: EmulatorSession) throws` | Tear down runtime; invalidate session |
| Frame observation | Deliver LCD frames to UI (callback / AsyncStream — TBD in implementation story) |
| Input submission | Key down/up and optional pointer events |

> Implementation stories may stage these APIs. This contract defines the **intended** surface so adapters are not designed around AWT-only flows.

### 3.3 `LaunchConfiguration` (inputs)

**Minimum (today):**

| Field | Required | Meaning |
|-------|----------|---------|
| `game: InstalledGame` | Yes | Includes `id`, `title`, `jarURL`, `contentHash`, `importedAt` |

**Reserved for later configuration (non-breaking additions):**

| Field | Meaning | FreeJ2ME mapping |
|-------|---------|------------------|
| `lcdWidth` / `lcdHeight` | Virtual phone screen | `MobilePlatform` constructor / resize |
| `phoneProfile` | Nokia / Standard / Siemens / Motorola | `Mobile.nokia` etc. / Config |
| `soundEnabled` | Audio master | `Mobile.sound` |
| `rotateDisplay` | 90° LCD present | Frontend rotate flag |
| `targetFPS` | Cap | Config `fps` / sleep in present path |
| `saveDataDirectory` | Writable sandbox root | `MobilePlatform.dataPath` |

Until those fields exist, the adapter must apply **safe defaults** (see §6).

### 3.4 `EmulatorSession` (outputs)

**Minimum (today):** `id`, `configuration`

**Reserved:**

| Field | Meaning |
|-------|---------|
| `state` | `prepared` / `running` / `paused` / `stopped` / `failed` |
| `lcdSize` | Actual runtime LCD size |
| `startedAt` | Session start time |

Session IDs are opaque to FreeJ2ME. The adapter maps `session.id` → internal runtime handle.

### 3.5 Error contract (App-facing)

Errors thrown across `EmulatorBridgeProtocol` must be Swift types (e.g. `EmulatorBridgeError`), never Java exceptions.

Suggested cases:

| Case | When |
|------|------|
| `jarNotFound` | `game.jarURL` missing/unreadable |
| `launchFailed` | `loadJar` / `runJar` failed |
| `invalidSession` | pause/resume/stop on unknown/stopped session |
| `runtimeUnavailable` | Host Java/runtime not ready (iOS strategy pending) |
| `alreadyRunning` | Second launch while another session is active (v1: single session) |

### 3.6 Non-goals of Contract A

- No FreeJ2ME class names
- No RMS / RecordStore APIs
- No Java Sound / MIDI types
- No Libretro protocol bytes
- No ImportEngine types

---

## 4. Contract B — Runtime Adapter Contract

### 4.1 Component

Working name: **`FreeJ2MERuntimeAdapter`**

Lives under Emulator feature (or a dedicated Emulator/Runtime target later).  
Implements the machinery behind `EmulatorBridgeProtocol`.

### 4.2 Lifecycle state machine

```
          launch()
             │
             ▼
        ┌─────────┐
        │ starting│
        └────┬────┘
             │ success
             ▼
        ┌─────────┐   pause()    ┌─────────┐
        │ running │─────────────▶│ paused  │
        └────┬────┘◀─────────────└────┬────┘
             │ resume()               │
             │                        │
             │        stop()          │ stop()
             ▼                        ▼
        ┌─────────────────────────────┐
        │          stopped            │
        └─────────────────────────────┘
             │
             └── failed (terminal; requires new launch)
```

**Rules:**

1. **v1 supports one active session** per process (simplifies FreeJ2ME statics in `Mobile` / `Display`).
2. `stop` is idempotent.
3. After `stop` or `failed`, the `EmulatorSession` id must not accept input/frames.
4. `launch` while another session is `running`/`paused` → `alreadyRunning` (or implicit stop — **prefer explicit error** in v1).

### 4.3 Frame contract

Derived from FreeJ2ME’s painter model (`MobilePlatform.setPainter` + `getLCD()`).

| Property | Contract |
|----------|----------|
| Pixel format (logical) | 32-bit ARGB (FreeJ2ME `BufferedImage` / `getRGB` path) |
| Dimensions | `lcdWidth × lcdHeight` from platform (default 240×320) |
| Delivery cadence | Whenever MIDlet calls `repaint` / `flushGraphics` (variable FPS) |
| Thread | **May be any FreeJ2ME worker thread** |
| Adapter duty | Convert/copy pixels; hop to MainActor / Metal queue before UI touch |
| Backpressure | Drop frames if UI cannot keep up (never block MIDlet unboundedly) |

**App-facing frame payload (conceptual):**

```text
EmulatorFrame {
  sessionID
  width, height
  pixelFormat  // e.g. bgra8Unorm or rgba8
  bytes / CVPixelBuffer / MTLTexture handle
  timestamp
}
```

Exact Swift type is an implementation detail; the contract requires **session-scoped, sized, CPU- or GPU-accessible pixels** without Java types.

### 4.4 Input contract

| Host event | Adapter action | FreeJ2ME hook |
|------------|----------------|---------------|
| Softkey / keypad down | Map → Mobile keycode | `MobilePlatform.keyPressed` |
| Key up | Map → Mobile keycode | `MobilePlatform.keyReleased` |
| Key repeat (optional) | | `MobilePlatform.keyRepeated` |
| Touch down | Scale into LCD coords | `pointerPressed` |
| Touch move | | `pointerDragged` |
| Touch up | | `pointerReleased` |

**Coordinate space:** LCD pixels with origin top-left of the virtual screen (0…width-1, 0…height-1), matching FreeJ2ME pointer paths after AWT scale correction.

**Keycode space:** FreeJ2ME `Mobile` constants (Canvas numeric keys + Nokia softkeys). Mapping tables live **inside the adapter**, not in ViewModels.

**Threading:** Input methods may be called from MainActor; adapter must be safe w.r.t. FreeJ2ME’s threads (serialize onto a dedicated runtime queue if required).

### 4.5 Audio contract

| Requirement | Contract |
|-------------|---------|
| Control | Honor `soundEnabled` (future LaunchConfiguration) / mute |
| Formats | WAV + MIDI best-effort initially; AMR/MPEG may stay silent |
| Backend | Adapter may replace Java Sound with AVAudioEngine **behind** MMAPI `Player` façade |
| Failure | Audio failure must **not** fail launch |

### 4.6 Filesystem / RMS contract

| Path | Mapping |
|------|---------|
| MIDlet JAR | Read-only `InstalledGame.jarURL` (library install path) |
| Runtime data root | `Documents/JavaOne/Saves/<game.id.uuid>/` → `MobilePlatform.dataPath` |
| RMS | `{dataPath}/rms/...` (FreeJ2ME default layout) |
| Config (optional) | `{dataPath}/config/...` |

**Rules:**

- Never write RMS into the Import library tree (`Documents/JavaOne/Library/...`) unless explicitly decided later.
- Never use process CWD as FreeJ2ME does on desktop; always set `dataPath`.
- Artwork under Library remains Import’s concern; runtime does not own it.

### 4.7 Launch parameter defaults (when LaunchConfiguration is minimal)

| Parameter | Default |
|-----------|---------|
| LCD size | 240 × 320 |
| Phone profile | Nokia (widest game compatibility in FreeJ2ME practice) |
| Sound | On |
| Rotate | Off |
| FPS cap | Uncapped (0) |
| dataPath | `Documents/JavaOne/Saves/<gameUUID>/` |
| Jar URL | `file://` form of `game.jarURL.path` |

### 4.8 Jar URL formatting

Adapter MUST pass FreeJ2ME a URL acceptable to `new URL(jarurl)` / `URLClassLoader`:

```text
file:///<absolute-path-to-game.jar>
```

On iOS, paths are absolute sandbox paths; encode spaces and special characters correctly.

---

## 5. Contract C — FreeJ2ME Core Hooks

These are the **only** FreeJ2ME entry points the adapter should rely on for v1 (from E3-R001):

### 5.1 Mandatory hooks

| Hook | Use |
|------|-----|
| `Mobile.setPlatform(MobilePlatform)` | Bind LCD size |
| `MobilePlatform.setPainter(Runnable)` | Frame drain |
| `MobilePlatform.getLCD()` | Read pixels |
| `MobilePlatform.dataPath` | RMS/config root |
| `MobilePlatform.loadJar(String url)` | Open MIDlet |
| `MobilePlatform.runJar()` | `startApp` |
| `MobilePlatform.keyPressed/Released/Repeated` | Keys |
| `MobilePlatform.pointerPressed/Dragged/Released` | Pointer |
| `Mobile.sound` | Mute |

### 5.2 Explicitly out of contract (do not depend on for iOS)

| Piece | Reason |
|-------|--------|
| `org.recompile.freej2me.FreeJ2ME` AWT UI | Desktop only |
| Libretro stdin binary protocol | Hosted by RetroArch native core |
| `Anbu` + SDL native helper | Desktop IPC |
| `System.exit` error paths in loader | Embedding-hostile; guard in fork if needed |
| Spawning `java -jar` | Impossible on iOS |

### 5.3 Modification policy

| Zone | Policy |
|------|--------|
| MIDlet jars | Never modify |
| `javax.microedition.*` semantics | Avoid changes; fix only with upstream-style patches in a managed fork |
| `org.objectweb.asm` | Do not touch |
| AWT/Libretro/SDL frontends | Do not use on iOS; leave upstream |
| `MobilePlatform` painter/dataPath | Use as-is |
| `PlatformPlayer` / graphics backends | Replace behind façades in managed fork if SE APIs unavailable |

---

## 6. Isolation rules (hard)

### 6.1 Must not import FreeJ2ME / MIDP / ASM

- `Features/Library/**`
- ImportEngine / Pipeline / Steps
- Repositories / SwiftData entities
- SwiftUI Views
- ViewModels (except `EmulatorBridgeProtocol` + Launch/Session models)

### 6.2 Allowed to know FreeJ2ME

- `FreeJ2MERuntimeAdapter` and its private helpers
- Optional future `JavaOne/Vendor/FreeJ2ME` (or SPM/binary) target
- Build scripts that package the runtime

### 6.3 Dependency direction

```
Library ──provides──▶ InstalledGame ──into──▶ LaunchConfiguration
                                              │
ImportEngine ──✕── (no dependency either way) │
                                              ▼
                                         EmulatorBridge
                                              │
                                              ▼
                                      RuntimeAdapter
                                              │
                                              ▼
                                         FreeJ2ME
```

---

## 7. Threading & concurrency contract

| Rule | Requirement |
|------|-------------|
| App API | `@MainActor` for `EmulatorBridgeProtocol` (matches current skeleton) |
| Painter | Assume **non-main** FreeJ2ME threads |
| Frame publish | Adapter hops to MainActor / render queue |
| Input | May enter on MainActor; adapter serializes to runtime |
| Stop | Must cancel painters/audio and release session before returning |
| Re-entrancy | `stop` during painter callback must be safe (no deadlock) |

---

## 8. Single-session policy (v1)

FreeJ2ME uses process-wide statics (`Mobile`, `Display`). Until the runtime is proven re-entrant:

1. Only **one** `EmulatorSession` may be active.
2. Library “Play” must stop or refuse if a session exists.
3. Multi-instance support is **out of contract** for Epic 3.

---

## 9. Observability contract

Adapter SHOULD emit structured logs (OSLog) for:

- launch begin/end + game id + LCD size  
- loadJar failure  
- painter first-frame  
- stop/teardown  
- audio backend fallback  

Must not log full jar paths in production privacy builds if policy requires redaction (optional).

---

## 10. Testing contract

| Layer | Test style |
|-------|------------|
| App / ViewModel | Fake `EmulatorBridgeProtocol` |
| Adapter unit | Mock painter sink + fake filesystem roots |
| Runtime integration | Real FreeJ2ME + sample JARs (CI machine / future device harness) |
| Library / Import | **Zero** FreeJ2ME tests required |

---

## 11. Open decisions (not frozen by this contract)

These block production integration but **do not** block documenting the seam:

1. **How Java bytecode executes on iOS** (embedded runtime vs large port).  
2. **GPL-3 distribution strategy** for App Store.  
3. Exact Swift frame type (`AsyncStream<EmulatorFrame>` vs delegate).  
4. Upstream choice: `hex007/freej2me` vs `freej2me-plus`.  
5. Whether pause maps to `MIDlet.pauseApp` or only freezes presentation.

---

## 12. Acceptance criteria for a future implementation story

An implementation satisfies this contract when:

1. ViewModel launches via `EmulatorBridgeProtocol` only.  
2. Frames appear from FreeJ2ME LCD through the painter hook (or an agreed stub path during runtime spike).  
3. At least numeric keypad + softkeys reach `MobilePlatform`.  
4. RMS writes land under `Documents/JavaOne/Saves/<gameUUID>/`.  
5. `stop` ends the session without requiring process kill.  
6. Library / Import / SwiftData modules still contain **no** FreeJ2ME references.  
7. Default / placeholder bridge can remain for builds without the runtime packed.

---

## 13. Suggested next stories

| ID | Title | Outcome |
|----|-------|---------|
| E3-R003 | iOS Java Runtime Decision Spike | Choose execution strategy; update risk score |
| E3-US002 | Expand EmulatorBridge API | pause/resume/stop + frame/input surfaces in Swift |
| E3-US003 | FreeJ2MERuntimeAdapter Skeleton | Maps LaunchConfiguration → loadJar/runJar (may no-op present) |
| E3-US004 | iOS Painter Prototype | LCD pixels → Metal/CGImage |
| E3-US005 | Input Bridge | Virtual keypad → Mobile keycodes |
| E3-US006 | Library Play Wiring | ViewModel → bridge only |

---

## 14. Related documents

| Doc | Role |
|-----|------|
| `docs/EMULATOR_ARCHITECTURE.md` | JavaOne bridge architecture |
| `docs/FREEJ2ME_ASSESSMENT.md` | FreeJ2ME internals (E3-R001) |
| `docs/FREEJ2ME_RUNTIME_CONTRACT.md` | This seam contract (E3-R002) |
| `AGENTS.md` | Bridge FreeJ2ME; minimize upstream edits |

---

## 15. Summary

**Contract A** keeps the product Swift-clean.  
**Contract B** defines adapter lifecycle, frames, input, audio, and sandbox paths.  
**Contract C** pins FreeJ2ME hooks to `MobilePlatform` painter/load/run/input/`dataPath` — the Libretro/SDL integration style — and rejects AWT/libretro-process assumptions for iOS.

This is the runtime contract Epic 3 implementations must obey.
