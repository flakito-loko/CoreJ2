# FreeJ2ME Source Audit

**Task:** E3-R004 — Official FreeJ2ME source audit (documentation only)  
**Upstream audited:** [hex007/freej2me](https://github.com/hex007/freej2me)  
**Pinned revision:** `b1c4cf13e012938f9d5270621fddea60e5554858` (tip of default branch at audit time; merge `b1c4cf1`)  
**Method:** Read-only shallow clone outside the JavaOne tree — **no FreeJ2ME or JavaOne source was modified**  
**Depends on:** E3-R001 (`FREEJ2ME_ASSESSMENT.md`), E3-R002 (`FREEJ2ME_RUNTIME_CONTRACT.md`), E3-R003 (`FREEJ2ME_INTEGRATION_STRATEGY.md`)

---

## 1. Verification against `FREEJ2ME_ASSESSMENT.md`

Overall: **the live hex007 tree matches the assessment**. The assessment’s architecture, startup story, and iOS risks remain accurate.

| Assessment claim | Audit finding | Match? |
|------------------|---------------|--------|
| Layout `src/org/recompile/{freej2me,mobile}`, `javax/microedition`, vendored ASM, `libretro/`, `sdl2/` | Present under `src/` | Yes |
| Core types `Mobile`, `MobilePlatform`, `MIDletLoader`, `PlatformGraphics`, `PlatformImage`, `PlatformPlayer`, `PlatformFont` | All present under `src/org/recompile/mobile/` | Yes |
| Frontends `FreeJ2ME`, `Libretro`, `Anbu`, `Config`, `ScreenShot` | Present under `src/org/recompile/freej2me/` | Yes |
| Build produces `freej2me.jar` / `freej2me-lr.jar` / `freej2me-sdl.jar` with those Main-Classes | Confirmed in `build.xml` | Yes |
| Startup: `setPlatform` → `setPainter` → `loadJar` → `runJar` → paint/flush → `painter.run()` | Confirmed in all three frontends + `MobilePlatform` | Yes |
| Best iOS reference = Libretro/SDL painter path, not AWT Frame | Libretro/Anbu painters copy `getLCD()` / pipe RGB; AWT paints a `Canvas` component | Yes |
| LCD via `BufferedImage` / AWT graphics | `PlatformImage` / `PlatformGraphics` | Yes |
| Audio via Java Sound / MIDI in `PlatformPlayer` | `javax.sound.sampled` + `javax.sound.midi` | Yes |
| RMS under `dataPath` | `RecordStore` uses `Mobile.getPlatform().dataPath + "./rms/..."` | Yes |
| ASM rewrite in loader | `MIDletLoader.loadClass` + `org.objectweb.asm` | Yes |
| `System.exit` in loader / frontends | Present (hostile to embedding) | Yes |
| GPL-3 | `LICENSE` is GPL-3 (with ASM exception note) | Yes |

**Minor assessment gaps (not contradictions):**

- Extra mobile helper: `WavImaAdpcmDecoder.java` (used by audio path).
- AWT also appears in `javax/microedition/lcdui/game/LayerManager.java` (not only mobile/frontends).
- FreeJ2ME has **no method named `launch()`**; “launch” in JavaOne maps to frontend `main` + `loadJar`/`runJar`.
- `setPainter()` is installed **before** `startApp()`, not after the first `repaint()` (see §3).

**Counts at audited SHA:** ~317 Java files total (~158 `javax`, ~107 ASM, ~13 `org.recompile`, plus `libretro`/`sdl2` natives).

---

## 2. Symbol locations

Paths relative to the FreeJ2ME repository root.

| Symbol / API | Path | Notes |
|--------------|------|-------|
| **MobilePlatform** | `src/org/recompile/mobile/MobilePlatform.java` | LCD, loader, painter, keys/pointer, `loadJar`/`runJar`, `flushGraphics`/`repaint` |
| **MIDletLoader** | `src/org/recompile/mobile/MIDletLoader.java` | Extends `URLClassLoader`; manifest; ASM `loadClass`; reflective `startApp` |
| **PlatformGraphics** | `src/org/recompile/mobile/PlatformGraphics.java` | Implements MIDP `Graphics` over AWT `Graphics2D` / `BufferedImage` |
| **PlatformImage** | `src/org/recompile/mobile/PlatformImage.java` | Owns `BufferedImage` LCD/offscreen buffers |
| **Display** | `src/javax/microedition/lcdui/Display.java` | Singleton current displayable; `setCurrent`; ~17 ms `Timer` for `callSerially` |
| **Canvas** | `src/javax/microedition/lcdui/Canvas.java` | `paint` → `MobilePlatform.repaint` → `painter.run()` |
| **GameCanvas** | `src/javax/microedition/lcdui/game/GameCanvas.java` | `flushGraphics` → `MobilePlatform.flushGraphics` → `painter.run()` |
| **setPainter()** | `MobilePlatform.setPainter(Runnable)` L88–91 | Field `painter`; default no-op in ctor |
| **loadJar()** | `MobilePlatform.loadJar(String)` L153–168 | `new URL` + `new MIDletLoader(URL[])` |
| **runJar()** | `MobilePlatform.runJar()` L170–181 | `loader.start()` |
| **getLCD()** | `MobilePlatform.getLCD()` | Returns `lcd.getCanvas()` (`BufferedImage`) |
| **dataPath** | `MobilePlatform.dataPath` (public `String`) | Set by frontends (e.g. Libretro); read by RMS |
| **Mobile** | `src/org/recompile/mobile/Mobile.java` | Static platform/display/G3D; key constants; `sound` / phone flags |

---

## 3. Real call graph: host start → `startApp` → first present → painter

There is **no** FreeJ2ME `launch()` API. The graph below is the **actual** desktop/embed frontend sequence (AWT `FreeJ2ME.main` shown; Libretro/Anbu are isomorphic for the core hooks).

### 3.1 Important ordering correction

`setPainter()` is **not** reached after the first `repaint()`. Frontends call it **during platform bring-up, before** `loadJar` / `runJar`. The first MIDlet present then **invokes** the already-installed painter.

```text
Frontend main / host bring-up
│
├─ Mobile.setPlatform(new MobilePlatform(w, h))
│     ├─ new PlatformImage(w,h) + PlatformGraphics
│     ├─ Mobile.setGraphics3D(new Graphics3D())
│     └─ painter = empty Runnable   // placeholder
│
├─ MobilePlatform.setPainter(hostPainter)     ← INSTALLED HERE (before MIDlet)
│     // AWT: lcd.paint(...)
│     // Libretro/Anbu: copy getLCD() / push RGB
│
├─ MobilePlatform.dataPath = <sandbox>        ← (Libretro sets; JavaOne must always set)
│
├─ MobilePlatform.loadJar("file:///.../game.jar")
│     └─ new MIDletLoader(URL[])
│           └─ loadManifest() + System properties
│
├─ optional Config.init() / settings → resizeLCD, Mobile.sound, phone flags
│
└─ MobilePlatform.runJar()
      └─ MIDletLoader.start()
            ├─ loadClass(mainClass)          // ASM rewrite path
            ├─ reflective ctor → MIDlet
            ├─ MIDlet.initAppProperties(...)
            └─ reflective startApp()         ★ MIDlet.startApp()
                  │
                  │  (typical game)
                  ▼
            Display.getDisplay(midlet).setCurrent(canvas|gameCanvas|form...)
                  │
                  ├─ Displayable.showNotify()
                  ├─ current.notifySetCurrent()
                  │     └─ Canvas.notifySetCurrent() → Canvas.repaint()   ★ often first paint
                  │           ├─ paint(PlatformGraphics)
                  │           └─ MobilePlatform.repaint(img,…)
                  │                 ├─ PlatformGraphics.flushGraphics(...)  // blit into LCD buffer
                  │                 └─ painter.run()                        ★ first frame drain
                  │
                  └─ MobilePlatform.flushGraphics(...)   // also from setCurrent path
                        ├─ PlatformGraphics.flushGraphics(...)
                        └─ painter.run()

Later frames (game loop / timers / threads owned by MIDlet):
  Canvas.repaint() ──────────────► MobilePlatform.repaint() ──► painter.run()
  GameCanvas.flushGraphics() ────► MobilePlatform.flushGraphics() ──► painter.run()
  Display.callSerially(Runnable) ► Timer (~17ms) executes queued runnables
```

### 3.2 Compact “JavaOne mental model” graph

```text
JavaOne FreeJ2MERuntimeHost / Adapter
        │
        ▼
Mobile.setPlatform + dataPath + setPainter     (prepare)
        │
        ▼
loadJar(fileURL) → MIDletLoader
        │
        ▼
runJar() → startApp()
        │
        ▼
setCurrent / repaint / flushGraphics
        │
        ▼
painter.run() → (future) RuntimeEvent.frameAvailable + pixels from getLCD()
```

---

## 4. Every place JavaOne will eventually need to connect

These are **integration seams**. Prefer connecting from Swift/`FreeJ2MERuntimeAdapter` (or JNI façade) **without** editing FreeJ2ME unless listed as allowlisted in E3-R003.

### 4.1 Mandatory startup (Contract C — already targeted)

| Seam | FreeJ2ME API | JavaOne action |
|------|--------------|----------------|
| Construct platform | `new MobilePlatform(w,h)` + `Mobile.setPlatform` | LCD defaults 240×320 (or LaunchConfiguration) |
| Sandbox | `MobilePlatform.dataPath` | `Documents/JavaOne/Saves/<gameUUID>/` |
| Frame drain hook | `setPainter(Runnable)` | Copy/convert `getLCD()` → emit `RuntimeEvent.frameAvailable` (later) |
| Open MIDlet | `loadJar(file:///…)` | Pass standardized file URL from `InstalledGame.jarURL` |
| Start MIDlet | `runJar()` → `MIDletLoader.start` → `startApp` | Map failure → `RuntimeEvent.failed` / `launchFailed` |

### 4.2 First frame / rendering

| Seam | Location | JavaOne action |
|------|----------|----------------|
| Painter callback | Runnable passed to `setPainter` | Hop to MainActor/Metal; never block MIDlet unboundedly |
| Pixel source | `MobilePlatform.getLCD()` → `BufferedImage` | Read ARGB; later adapt if AWT buffer unavailable on iOS runtime |
| Present paths | `MobilePlatform.repaint` / `flushGraphics` | Already call `painter.run()` — do not bypass |

### 4.3 Input

| Seam | API | JavaOne action |
|------|-----|----------------|
| Keys | `keyPressed` / `keyReleased` / `keyRepeated` | Map virtual keypad → `Mobile` keycodes |
| Pointer | `pointerPressed` / `Dragged` / `Released` | Scale UIKit → LCD coords |
| GameCanvas bitmask | `keyState` via `updateKeyState` | Filled by key APIs; consumed by `GameCanvas.getKeyStates()` |

### 4.4 Display / lifecycle

| Seam | API | JavaOne action |
|------|-----|----------------|
| Current screen | `Display.setCurrent` | Triggers flush + often first paint |
| Serial events | `Display.callSerially` + Timer | Runs on FreeJ2ME timer thread — adapter must tolerate non-main painter |
| Pause/resume/destroy | MIDlet lifecycle (`pauseApp` / `destroyApp`) | Not cleanly exposed as host APIs today; future host work |
| Sound master | `Mobile.sound` | Honor LaunchConfiguration when added |
| Phone profile | `Mobile.nokia` / `siemens` / `motorola` | Optional config |

### 4.5 Persistence / audio (post-startup)

| Seam | Location | JavaOne action |
|------|----------|----------------|
| RMS | `javax.microedition.rms.RecordStore` via `dataPath` | Ensure directory exists & is writable |
| MMAPI Player | `PlatformPlayer` | Eventually replace Java Sound with AVAudioEngine behind façade (likely fork) |

### 4.6 Explicit non-connect (do not wire JavaOne to these)

| Piece | Reason |
|-------|--------|
| `org.recompile.freej2me.FreeJ2ME` AWT UI | Desktop window/listeners |
| `Libretro` stdin protocol / `src/libretro/*` native core | RetroArch host model |
| `Anbu` + `src/sdl2/*` | Desktop SDL IPC |
| Spawning `java -jar` | Impossible on iOS |

---

## 5. Places that should NEVER be modified

Aligns with E3-R001 §10.6 and E3-R003 §6.

| Zone | Path / pattern | Why |
|------|----------------|-----|
| Vendored ASM | `src/org/objectweb/asm/**` | Stability + separate license surface |
| MIDlet game content | User JARs | Not FreeJ2ME; never rewrite |
| Broad MIDP semantics | Most of `src/javax/microedition/**` | Compatibility; only upstream-style fixes if ever |
| AWT desktop frontend | `FreeJ2ME.java`, AWT pieces of `Config` UI | Wrong target |
| Libretro native + protocol | `src/libretro/**`, Libretro IO protocol | Wrong host |
| SDL helper | `src/sdl2/**`, Anbu native protocol | Wrong host |
| ASM rewrite policy “redesign” | `MIDletLoader` class transform logic | High regression risk |
| Opportunistic game-specific hacks in core | Scattered conditionals | Prefer adapter / documented fork patches |

**Rare allowlisted fork points (only if runtime forces it — see E3-R003):**  
`System.exit` in `MIDletLoader` / `MIDlet`; `PlatformPlayer` backends; AWT `BufferedImage` access behind an interface; embed-safe `dataPath` init. Prefer **not** changing `setPainter` / `loadJar` / `runJar` signatures.

---

## 6. Dependency inventory

### 6.1 AWT (`java.awt` / related)

**Direct Java importers (9 files):**

| File | Role |
|------|------|
| `MobilePlatform.java` | `BufferedImage` LCD; unused-looking `KeyEvent` import |
| `PlatformImage.java` | `BufferedImage`, `Graphics2D`, transforms |
| `PlatformGraphics.java` | Full graphics implementation on AWT |
| `PlatformFont.java` | AWT fonts |
| `FreeJ2ME.java` | Frame, Canvas, listeners |
| `Libretro.java` | `BufferedImage` surface for RGB extract |
| `Anbu.java` | Image/RGB for SDL pipe |
| `Config.java` | UI / images |
| `LayerManager.java` | AWT usage inside MIDP game layer |

**Impact:** Core LCD path is AWT-shaped. An iOS-capable runtime must provide AWT-compatible buffers **or** JavaOne must fork thin graphics backends.

### 6.2 Java Sound

| File | APIs |
|------|------|
| `PlatformPlayer.java` | `javax.sound.sampled.AudioSystem` / `Clip`; `javax.sound.midi.MidiSystem` / `Sequencer` |
| `WavImaAdpcmDecoder.java` | WAV/ADPCM decode supporting player |

**Impact:** No `javax.sound` on typical iOS embeddings → audio backend replacement (fork or runtime shim).

### 6.3 File I/O

| Area | Usage |
|------|--------|
| `RecordStore.java` | `File`, `FileOutputStream`, `Files`, `Paths`; paths under `dataPath` |
| Frontends (`Config`, `ScreenShot`, `FreeJ2ME`, `Libretro`, `Anbu`) | Config/screenshots/jar paths |
| `MIDletLoader` | JAR via `URLClassLoader` / resource streams (not raw `File` for game code) |
| ASM util/xml | Tooling only |

**Impact:** JavaOne must set `dataPath` to the app sandbox; never rely on process CWD.

### 6.4 Threads / timers

| Location | Mechanism |
|----------|-----------|
| `Display` | `java.util.Timer` + `TimerTask` every **17 ms** for `callSerially` |
| `Libretro` / `Anbu` | Timers for host I/O polling |
| MIDlets | May create their own threads (standard J2ME practice); FreeJ2ME does not serialize all game work onto one thread |
| Painter | Invoked on whatever thread called `repaint`/`flushGraphics` (often MIDlet or timer) |

**Impact:** Adapter must assume **non-MainActor** painter callbacks.

### 6.5 Reflection

| Location | Usage |
|----------|--------|
| `MIDletLoader.start` | `getConstructor`, `newInstance`, `getDeclaredMethod("startApp")`, `invoke`, `setAccessible` |
| `MIDletLoader.loadClass` | `defineClass` after ASM rewrite |

**Impact:** Requires a runtime that allows reflective MIDlet construction and custom class definition.

### 6.6 ASM (ObjectWeb)

| Location | Usage |
|----------|--------|
| Entire `src/org/objectweb/asm/**` | Vendored ASM tree |
| `MIDletLoader` | `ClassReader` / `ClassWriter` / adapters to rewrite loaded MIDlet bytecode |

**Impact:** Class loading is not “plain URLClassLoader”; ASM is load-bearing. Do not strip or replace casually. LICENSE notes ASM is **not** under GPL-3.

---

## 7. Precise integration checklist

Use this as the gate list before claiming “FreeJ2ME runs inside JavaOne.”

### 7.1 Repository / legal

- [ ] Add `Vendor/FreeJ2ME` submodule at a pinned hex007 SHA (E3-R003).
- [ ] Confirm GPL-3 (+ ASM notice) review status for distribution.
- [ ] Document audited SHA in the bump PR.

### 7.2 Runtime prerequisite (critical gate)

- [ ] Decide iOS execution strategy (embedded JVM / alternative) — **without this, hooks below cannot run on device**.
- [ ] Prove `URLClassLoader` + `defineClass` + reflection work on that runtime.
- [ ] Prove AWT `BufferedImage` path **or** schedule allowlisted graphics fork.

### 7.3 Startup wiring (Swift → Contract C)

- [ ] `Mobile.setPlatform(new MobilePlatform(w, h))` with agreed LCD size.
- [ ] Set `dataPath` to `Documents/JavaOne/Saves/<gameUUID>/` and create directories.
- [ ] Install `setPainter` **before** `loadJar`.
- [ ] Format JAR as `file:///<absolute-path>` and call `loadJar`.
- [ ] Call `runJar`; map exceptions / `System.exit` risk to Swift errors (fork guard if needed).
- [ ] Emit `RuntimeEvent.started` only after successful `runJar` entry (or defined success criteria).
- [ ] Emit `RuntimeEvent.failed` on load/start failure; never leave orphan sessions.

### 7.4 First frame

- [ ] Painter reads `getLCD()` (or equivalent pixel API).
- [ ] Convert to iOS pixel format; hop to render queue / MainActor.
- [ ] Publish `RuntimeEvent.frameAvailable` (payload story).
- [ ] Drop frames under backpressure; do not deadlock `stop`.

### 7.5 Input / audio / RMS

- [ ] Keypad → `MobilePlatform.key*`.
- [ ] Touch → `pointer*` in LCD space.
- [ ] RMS read/write under sandbox `dataPath`.
- [ ] Audio: mute via `Mobile.sound`; replace Java Sound when required.

### 7.6 Isolation

- [ ] No FreeJ2ME types in Library / Import / Views / ViewModels.
- [ ] Only Emulator Runtime / adapter / JNI façade touch FreeJ2ME.
- [ ] Do not link AWT frontend, Libretro native, or SDL helper into the iOS app target.
- [ ] Keep DI on `PlaceholderRuntimeHost` until checklist 7.2–7.4 pass.

### 7.7 Verification

- [ ] Unit: adapter maps configuration → prepare / loadJar / runJar order.
- [ ] Device/sim: one known MIDlet reaches `startApp` without process exit.
- [ ] Device/sim: at least one `painter.run()` observed.
- [ ] Compatibility corpus smoke (expand over time).

---

## 8. Summary

The official **hex007/freej2me** tree at `b1c4cf1` **confirms** `FREEJ2ME_ASSESSMENT.md`. The real present path is:

**`setPainter` (early) → `loadJar` → `runJar`/`startApp` → `Display.setCurrent` / `Canvas.repaint` / `GameCanvas.flushGraphics` → `MobilePlatform.repaint|flushGraphics` → `painter.run()`.**

JavaOne’s first durable connections are exactly Contract C: **platform + `dataPath` + painter + `loadJar` + `runJar`**, then pixels from **`getLCD()`**. Everything else (AWT buffers, Java Sound, `System.exit`, ASM/`defineClass`) is either a **runtime prerequisite** or an **allowlisted fork**, not a reason to rewrite MIDP.

---

## Related documents

| Doc | Role |
|-----|------|
| `docs/FREEJ2ME_ASSESSMENT.md` | E3-R001 architecture assessment |
| `docs/FREEJ2ME_RUNTIME_CONTRACT.md` | E3-R002 seam contracts |
| `docs/FREEJ2ME_INTEGRATION_STRATEGY.md` | E3-R003 vendor/submodule policy |
| `docs/EMULATOR_ARCHITECTURE.md` | JavaOne bridge layout |

---

## Out of scope for E3-R004

- Modifying FreeJ2ME or JavaOne application code  
- Adding the submodule  
- Implementing JNI  
- Commits
