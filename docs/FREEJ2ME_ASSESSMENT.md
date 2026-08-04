# FreeJ2ME Technical Assessment

**Task:** E3-R001 — Research only  
**Scope:** `hex007/freej2me` (upstream FreeJ2ME), with notes on related forks  
**Date:** 2026-08-04  
**JavaOne context:** Epic 3 Emulator Bridge skeleton already exists (`EmulatorBridgeProtocol`, `DefaultEmulatorBridge`, `LaunchConfiguration`, `EmulatorSession`)

This document studies how FreeJ2ME works so JavaOne can design a clean integration **without** coupling Library, ImportEngine, Repository, SwiftData, or ViewModels to the runtime.

> Source inspected: shallow clone of https://github.com/hex007/freej2me  
> Related fork (more active packaging / CLI): https://github.com/TASEmulators/freej2me-plus  
> License: **GPL-3.0** (critical product/legal constraint for App Store distribution)

---

## Executive summary

FreeJ2ME is a **desktop JVM J2ME/MIDP emulator**, not a native C/C++ core that draws frames by itself.

| Layer | Role |
|-------|------|
| `javax.microedition.*` | Reimplemented MIDP/CLDC APIs (Java) |
| `org.recompile.mobile.*` | Platform core: LCD buffer, MIDlet loader, audio, keys |
| Frontends | AWT window, Libretro (pipe + RGB), SDL2 (pipe + RGB) |
| Vendored ASM | Bytecode rewrite when loading MIDlet classes |

**Best integration reference for JavaOne:** the **Libretro / SDL “painter → RGB framebuffer” path**, not the AWT `Frame` UI.

**Hardest constraint for iOS:** FreeJ2ME assumes a full Java SE runtime (`java.awt`, `javax.sound.sampled`, `java.io.File`, reflection, ASM `defineClass`). App Store iOS cannot simply host HotSpot + AWT. Integration therefore requires either:

1. an embedded/alternative Java runtime strategy (technically and policy-constrained), or  
2. a **platform-port** where `MobilePlatform` / graphics / audio backends are replaced with iOS-native implementations while keeping MIDP APIs + MIDlet loading logic as intact as possible.

---

## 1. Overall architecture

### 1.1 Main modules

```
src/
├── org/recompile/freej2me/     # Frontends + config UI
│   ├── FreeJ2ME.java           # AWT standalone main
│   ├── Libretro.java           # Libretro “BIOS” jar (stdin/stdout protocol)
│   ├── Anbu.java               # SDL2 frontend (Java side)
│   ├── Config.java             # Per-game settings overlay
│   └── ScreenShot.java
├── org/recompile/mobile/       # Runtime core
│   ├── Mobile.java             # Global accessors (Display, Platform, key constants)
│   ├── MobilePlatform.java     # LCD, loadJar/runJar, key/pointer, painter hook
│   ├── MIDletLoader.java       # URLClassLoader + manifest + ASM rewrite + startApp
│   ├── PlatformGraphics.java   # Draws into BufferedImage LCD
│   ├── PlatformImage.java
│   ├── PlatformPlayer.java     # MMAPI Player → Java Sound / MIDI
│   └── PlatformFont.java
├── javax/microedition/...      # MIDP / RMS / Media / M3G / IO stubs & impls
├── org/objectweb/asm/          # Vendored ASM for class rewriting
├── libretro/                   # Native C libretro core (spawns `java -jar`)
└── sdl2/                       # Native SDL helper (frame/input IPC)
```

Build (`build.xml`) produces three jars:

| Artifact | Main-Class | Purpose |
|----------|------------|---------|
| `freej2me.jar` | `FreeJ2ME` | Desktop AWT UI |
| `freej2me-lr.jar` | `Libretro` | Libretro companion jar |
| `freej2me-sdl.jar` | `Anbu` | SDL2 companion jar |

### 1.2 Startup flow (conceptual)

```
Frontend main(args)
  → Mobile.setPlatform(new MobilePlatform(width, height))
  → setPainter(Runnable)          // how LCD pixels leave the core
  → MobilePlatform.loadJar(url)   // MIDletLoader(URLClassLoader)
  → optional Config.init()
  → MobilePlatform.runJar()       // reflective MIDlet.startApp()
  → MIDlet draws via Canvas/GameCanvas
  → flushGraphics/repaint → PlatformGraphics → painter.run()
```

### 1.3 Runtime lifecycle

1. **Construct platform** — allocate LCD `PlatformImage` + `PlatformGraphics`, create `Graphics3D`.
2. **Attach frontend painter** — AWT paints a `Canvas`; Libretro/SDL push RGB bytes.
3. **Load MIDlet** — parse manifest, rewrite classes, instantiate MIDlet.
4. **Start** — invoke `startApp()` (and later pause/destroy via MIDlet APIs as games request).
5. **Event + draw loop** — game/timer threads call `repaint` / `flushGraphics`; `Display.callSerially` runs on a `Timer` (~17 ms).
6. **Teardown** — AWT exits process on window close; Libretro/SDL depend on host process lifetime. There is **no clean multi-session API** designed for embedding inside another app.

---

## 2. Launch process

### 2.1 How a JAR is opened

`MobilePlatform.loadJar(String jarurl)`:

```text
URL jar = new URL(jarurl);
loader = new MIDletLoader(new URL[]{ jar });
```

Expected URL form: `file:///absolute/path/to/game.jar`  
(Windows needs the extra slash style documented in README.)

`MIDletLoader`:

- Extends `URLClassLoader`
- Reads `META-INF/MANIFEST.MF` (several case variants)
- Extracts `MIDlet-Name`, icon, main class from `MIDlet-1` / related attributes
- Sets system/app properties (`microedition.platform`, `MIDP-2.0`, etc.)

### 2.2 Where execution begins

`MobilePlatform.runJar()` → `loader.start()`:

1. `loadClass(mainClassName)` (with ASM rewrite in `findClass` path)
2. Reflective no-arg constructor → `MIDlet` instance
3. `MIDlet.initAppProperties(properties)`
4. Reflective `startApp()` invoke

That is the true “game start” entry — **not** a FreeJ2ME-specific game loop owned by the frontend.

### 2.3 Required launch parameters

**AWT (`FreeJ2ME`)** CLI:

```text
java -jar freej2me.jar 'file:///path/to/midlet.jar' [width] [height] [scale]
```

Defaults if omitted: LCD **240×320**, file dialog if no jar arg.

**Libretro jar** receives structured numeric args from the native core (width, height, rotate, phone type, fps, sound, …) then loads the jar via protocol messages over stdin.

**SDL (`Anbu`)** expects jar path + width + height (and starts native SDL helper).

**Per-game config** (`Config`) can override resolution/sound/phone/rotate/fps; saved under working-directory config paths. Config often **wins over CLI**.

For JavaOne mapping:

| JavaOne | FreeJ2ME |
|---------|----------|
| `InstalledGame.jarURL` | `file://` URL into `loadJar` |
| Future `LaunchConfiguration` size | `MobilePlatform` width/height |
| Future phone profile | Nokia/Siemens/Motorola flags in `Mobile` / Config |
| Future sound toggle | `Mobile.sound` |
| App Documents sandbox | `MobilePlatform.dataPath` for RMS/config |

---

## 3. Rendering

### 3.1 How frames are produced

1. MIDlet draws into a per-`Canvas`/`Displayable` `PlatformImage`.
2. `Canvas.repaint` / `GameCanvas.flushGraphics` / `Display.setCurrent` path calls:

```text
MobilePlatform.flushGraphics / repaint
  → PlatformGraphics.flushGraphics(...)  // blit into LCD BufferedImage
  → painter.run()                        // frontend presents LCD
```

3. LCD pixels live in `MobilePlatform.getLCD()` → `BufferedImage` (`PlatformImage.getCanvas()`).

### 3.2 Rendering backends

| Frontend | Backend |
|----------|---------|
| AWT | `java.awt` `Frame` + `Canvas.paint` draws `getLCD()` |
| Libretro | Painter copies LCD into an internal `BufferedImage`; native core consumes RGB frames via IPC; jar prints `+READY` and speaks a binary stdin protocol |
| SDL2 | Painter extracts `getRGB(...)` → RGB888 byte[] written to SDL process pipe |

There is **no OpenGL/Metal** in the Java core. Everything is **software framebuffer** (`BufferedImage` / int RGB).

### 3.3 Where an iOS renderer should connect

**Primary hook:** `MobilePlatform.setPainter(Runnable)`.

A future iOS adapter should:

1. Own an iOS surface (Metal / CoreAnimation / `UIImage`/`CGImage` path).
2. Install a painter that reads `getLCD()` pixel data (ARGB int buffer).
3. Upload/convert to a GPU texture or `CGImage` on the render thread.

**Do not** depend on AWT `FreeJ2ME.LCD` for iOS.

Libretro/Anbu already prove the correct separation: **core draws LCD; frontend only presents pixels**.

---

## 4. Input

### 4.1 Keyboard mapping

Frontends map host keys → Mobile keycodes (`Mobile.KEY_NUM*`, Nokia softkeys, etc.).

Documented defaults (`KEYMAP.md` / README):

- `Q` / `W` — softkeys  
- Arrows — nav or 2/4/6/8 depending on phone mode  
- Number row / numpad — keypad  
- `E` / `R` — `*` / `#`  
- Enter — fire / 5  
- Esc — FreeJ2ME config menu (AWT)

Phone profiles change arrow semantics (Standard vs Nokia vs Siemens vs Motorola).

### 4.2 Pointer / touch

AWT mouse listeners convert scaled/rotated coordinates to:

- `MobilePlatform.pointerPressed/Released/Dragged(x, y)`
- Forwarded to `Display.getCurrent()` (`Canvas` pointer methods)

### 4.3 Event dispatch

```text
Host input
  → Frontend mapping
  → MobilePlatform.keyPressed/Released/Repeated or pointer*
  → update GameCanvas keyState bitmask (for getKeyStates)
  → Displayable/Canvas key*/pointer* callbacks
```

Libretro polls stdin on a 1 ms `Timer` and synthesizes the same `MobilePlatform` calls.

**iOS implication:** Map touch / virtual keypad → the same `MobilePlatform` methods. Never send UIKit events into MIDP types from ViewModels.

---

## 5. Audio

### 5.1 Pipeline

```text
javax.microedition.media.Manager / Player
  → PlatformPlayer
      → MIDI: javax.sound.midi.Sequencer
      → WAV: javax.sound.sampled.AudioSystem + Clip
      → IMA-ADPCM WAV: WavImaAdpcmDecoder then Clip
      → unsupported types: silent stub player
```

Gated by `Mobile.sound`.

### 5.2 APIs used

- Java Sound (`javax.sound.sampled`)
- Java MIDI (`javax.sound.midi`)

### 5.3 Integration points

Replace or wrap `PlatformPlayer` backends with **AVAudioEngine** / AudioQueue equivalents while keeping the `javax.microedition.media.Player` façade.

AMR/MPEG paths are incomplete upstream (“No Player For…” stubs).

---

## 6. MIDP runtime

### 6.1 Display

`javax.microedition.lcdui.Display`:

- Singleton wired through `Mobile.setDisplay`
- `setCurrent(Displayable)` triggers flush of current screen image
- `callSerially(Runnable)` queued and drained by `Timer` every **17 ms** (~60 Hz)

### 6.2 Canvas

Abstract `Canvas` creates a full-screen `PlatformImage`, implements key game-action mapping, and routes `repaint` to `MobilePlatform.repaint`.

### 6.3 GameCanvas

Extends Canvas; `flushGraphics` copies the offscreen buffer through `MobilePlatform.flushGraphics` (immediate present via painter).

`getKeyStates()` reads `MobilePlatform.keyState` bitmask updated in `updateKeyState`.

### 6.4 Event loop

There is **no single global FreeJ2ME game loop**.

- MIDlets use their own `Thread`s / `Timer`s / `Display.callSerially`
- Frontends may sleep in paint for FPS limit (`Thread.sleep` when `limitFPS > 0`)
- Libretro IO timer is separate (input pump)

JavaOne must assume **multiple Java threads** calling into painter and audio.

---

## 7. Threading model

| Thread / timer | Role |
|----------------|------|
| Main / EDT (AWT) | Window, key/mouse, some painting |
| MIDlet threads | Game logic, animation, blocking I/O |
| `Display` Timer (~17 ms) | `callSerially` queue |
| Libretro Timer (1 ms) | stdin command pump |
| Java Sound / MIDI threads | Audio playback callbacks |
| Painter | Often invoked on the thread that called `flushGraphics`/`repaint` |

**No dedicated “render thread” abstraction** in the core — presentation is synchronous with `painter.run()` after blit.

**iOS risk:** Painter may run off the main thread. The adapter must hop to MainActor/Metal queue safely.

---

## 8. File access

### 8.1 Resource loading

- MIDlet resources via `URLClassLoader` / `MIDletLoader.getMIDletResourceAsStream`
- `Mobile.getResourceAsStream` delegates to loader

### 8.2 RMS

`javax.microedition.rms.RecordStore` persists under:

```text
{dataPath}/rms/{suitename}/{recordStoreName}
```

Uses `java.io.File` / `Files.createDirectories` / `FileOutputStream`.

### 8.3 Save / config files

- Config: `{dataPath}/config/{appname}/...` (`Config.java`)
- Screenshots: `{dataPath}/screenshots`
- Working directory matters; FreeJ2ME expects a writable filesystem root via `MobilePlatform.dataPath`

**JavaOne mapping:** set `dataPath` to something like  
`Documents/JavaOne/Saves/<gameUUID>/` so RMS stays per-game and sandbox-safe.

---

## 9. Native dependencies

### 9.1 Java version

- Targets classic Java SE APIs used by Ant `javac` (effectively **Java 8-era** surface: AWT, Java Sound, MIDI).
- Requires a **JRE/JDK on host** for desktop/libretro (“JRE 8+” in community docs).

### 9.2 Third-party / vendored

- **ASM** (vendored under `org.objectweb.asm`) for MIDlet bytecode rewriting
- Optional native:
  - `src/libretro` C core
  - `src/sdl2` C++ helper

### 9.3 Platform assumptions

- Desktop OS process model
- AWT available (AWT frontend)
- Blocking filesystem paths
- Ability to `defineClass` / reflective MIDlet start
- Libretro variant assumes ability to spawn `java -jar` (problematic in iOS sandbox)

### 9.4 License

GPL-3.0 — distributing a modified FreeJ2ME runtime linked into JavaOne has **compliance implications** (source offer, copyleft). Treat as a first-class product risk, not only a technical one.

---

## 10. Integration proposal (JavaOne)

### 10.1 Keep these completely independent

| JavaOne area | Must remain free of FreeJ2ME types |
|--------------|-------------------------------------|
| Library UI | No |
| ImportEngine / Pipeline / Steps | No |
| `GameLibraryRepository` / SwiftData | No |
| ViewModels | Depend only on `EmulatorBridgeProtocol` |
| Domain `InstalledGame` | Only supplies `jarURL` + ids to `LaunchConfiguration` |

### 10.2 Recommended layering

```
ViewModel
  → EmulatorBridgeProtocol.launch(LaunchConfiguration)
      → FreeJ2MERuntimeAdapter   (Epic 3 implementation detail)
          → MobilePlatform + MIDletLoader + MIDP APIs
          → iOSPainter (Metal/CG)
          → iOSAudioBackend
          → iOSFileDataPath
```

### 10.3 Minimum adapter layer

**`FreeJ2MERuntimeAdapter`** (name illustrative) should own:

1. Mapping `LaunchConfiguration` → `file://` jar URL + LCD size + phone profile + `dataPath`
2. Constructing `MobilePlatform`, installing iOS painter/audio/file backends
3. Calling `loadJar` / `runJar`
4. Forwarding pause/resume/stop to MIDlet lifecycle when exposed
5. Converting LCD pixels → frames for SwiftUI/Metal
6. Converting Swift input events → `MobilePlatform` key/pointer APIs
7. Isolating all `org.recompile.*` / `javax.microedition.*` imports inside the Emulator feature module

### 10.4 Responsibilities of `EmulatorBridge`

Already aligned with E3-US001:

- Stable Swift API for the app (`launch`, later pause/resume/stop)
- Session identity (`EmulatorSession`)
- Error surface suitable for UI alerts
- **No** FreeJ2ME types in the protocol
- Swap implementations via DI (`DefaultEmulatorBridge` → real adapter)

### 10.5 Responsibilities of `FreeJ2MERuntimeAdapter`

- Host/runtime bring-up
- Painter / audio / RMS path bridging to iOS
- Thread hops to MainActor for UI frames
- Lifecycle of one game session
- Logging/telemetry boundaries

### 10.6 Parts that should never be modified inside FreeJ2ME (prefer)

Avoid editing upstream unless unavoidable:

| Leave alone | Why |
|-------------|-----|
| MIDlet game jars | Content |
| Vendored ASM tree | Stability / legal surface |
| Most `javax.microedition.*` semantics | Compatibility |
| Libretro C core / AWT UI | Wrong target for iOS |
| Game-specific hacks scattered in core | Prefer adapter or documented forks |

**Acceptable thin change points** (if a fork is unavoidable):

- `MobilePlatform.setPainter` usage (no change needed if already injectable)
- New platform backends replacing `PlatformPlayer` / AWT-dependent pieces
- `dataPath` initialization
- Possibly abstracting `BufferedImage` access behind an interface **in a JavaOne-managed fork**, not drive-by edits

### 10.7 Major risks

| Risk | Severity | Notes |
|------|----------|-------|
| **No JVM on iOS App Store** | Critical | Biggest architectural risk; may force Multi-OS Engine / custom runtime / large port |
| AWT / Java Sound dependency | High | Must replace for iOS |
| GPL-3 copyleft | High | Legal/distribution strategy needed early |
| Thread-unsafe painter callbacks | High | Must synchronize for Metal/UIKit |
| `System.exit` in loader error paths | Medium | Embedding-hostile; needs fork guard |
| Incomplete audio codecs | Medium | Some games silent |
| Per-game config / RMS path assumptions | Medium | Must sandbox under Documents |
| freej2me-plus divergence | Medium | Choose upstream vs plus early |
| M3G / JSR optional APIs | Medium | 3D games may fail |

### 10.8 Practical integration strategies (ordered)

1. **Framebuffer-adapter strategy (recommended research target)**  
   Keep MIDP + loader; replace presentation/audio/FS backends; run on an iOS-capable Java runtime if one is chosen.

2. **Process/libretro strategy**  
   Unrealistic on iOS (can’t spawn `java -jar` like RetroArch desktop).

3. **Full rewrite of FreeJ2ME in Swift**  
   Out of scope; abandons “don’t modify FreeJ2ME much.”

4. **Server-side / remote play**  
   Not aligned with native emulator product goals.

---

## Scores

| Metric | Score | Rationale |
|--------|-------|-----------|
| **Architecture complexity** | **7 / 10** | Clean MIDP core + injectable painter, but three frontends, ASM loading, timers, and SE dependencies add complexity |
| **Estimated integration difficulty (into native iOS JavaOne)** | **9 / 10** | Not because FreeJ2ME is undocumented — because **running its JVM/AWT stack on iOS** is the hard part |

Desktop embedding difficulty would be ~5/10 (Libretro-style). iOS App Store shipping is the jump to 9.

---

## Suggested Epic 3 roadmap (after this assessment)

1. **E3-R001** — this assessment (done as documentation).  
2. **Runtime decision spike** — choose how Java bytecode will execute on device (policy + tech). Gate all coding on this.  
3. **Expand `EmulatorBridgeProtocol`** — pause/resume/stop + frame callback / input APIs (still placeholders OK).  
4. **`FreeJ2MERuntimeAdapter` skeleton** — maps `LaunchConfiguration` → load/run, still no pixels on device if runtime undecided.  
5. **iOS Painter prototype** — LCD ARGB → Metal/CGImage (can be stubbed with synthetic frames first).  
6. **Input bridge** — virtual keypad → `MobilePlatform` keycodes.  
7. **Audio backend spike** — replace Java Sound for one WAV/MIDI path.  
8. **RMS `dataPath` sandbox** — per-game Documents folder.  
9. **Wire Library “Play”** — ViewModel → `EmulatorBridge` only.  
10. **Compatibility harness** — corpus of JARs; track FreeJ2ME vs JavaOne results.  
11. **Legal review** — GPL-3 compliance plan before TestFlight.

Until step 2 is decided, treat FreeJ2ME as a **vendored research dependency**, not a production iOS runtime.

---

## Relationship to existing JavaOne docs

- `docs/EMULATOR_ARCHITECTURE.md` — JavaOne-side bridge contracts (Swift).  
- `docs/FREEJ2ME_ASSESSMENT.md` — FreeJ2ME-side runtime reality (this file).

Together they define the seam: **Swift bridge stays stable; FreeJ2ME stays behind an adapter; Library/Import never import FreeJ2ME.**

---

## References

- Upstream repo: https://github.com/hex007/freej2me  
- Active plus fork: https://github.com/TASEmulators/freej2me-plus  
- Key source files reviewed: `FreeJ2ME.java`, `Libretro.java`, `Anbu.java`, `MobilePlatform.java`, `Mobile.java`, `MIDletLoader.java`, `PlatformPlayer.java`, `PlatformGraphics.java`, `Display.java`, `Canvas.java`, `GameCanvas.java`, `RecordStore.java`, `build.xml`, `KEYMAP.md`, `README.md`
