# Roadmap

Public product and engineering roadmap for JavaOne.

For the documentation-site mirror, see [docs/roadmap.md](docs/roadmap.md).

## Current version

**1.0.0-dev** — embedded FreeJ2ME on OpenJDK Mobile runs real MIDlets on physical iPhone, with library import, virtual keypad/touch, and sandboxed RMS.

## Next milestones

1. **Compatibility sweep (Epic 12)** — expand corpus beyond the five canary titles; publish results into `compatibility/`.
2. **Audio / MMAPI** — validate and document audio status per title.
3. **Alea frame continuity** — address P2 LCD stall under continuous input.
4. **App Store packaging** — legal review (FreeJ2ME GPL), size budget, entitlements.
5. **Polish** — first-party HIG UX, screenshots, onboarding.

## Completed Epics

| Epic | Title | Status |
|------|-------|--------|
| 1 | Game Library | Completed |
| 2 | Import Engine | Completed |
| 3 | Emulator Bridge & FreeJ2ME Host | Completed |
| 4 | Renderer / Emulator Surface | Completed |
| 5 | Persistent Runtime | Completed |
| 6 | Embedded OpenJDK Mobile + FreeJ2ME | Completed |
| 7 | OpenJDK Java Home / JNI Bring-up | Completed |
| 8 | JNI Gateway Throwable Path | Completed |
| 9 | Embedded AWT Runtime | Completed |
| 10 | Font, ImageIO & RunJar Hardening | Completed |
| 11 | Device Gameplay, Lifecycle & RMS | Completed |

## Epic summaries

### Epic 1 — Game Library
Empty-to-populated library with SwiftData entities, repository pattern, and Library UI.

### Epic 2 — Import Engine
Pipeline steps: Manifest → Hash → DuplicateDetection → Artwork. Content-addressed installs.

### Epic 3 — Emulator Bridge & FreeJ2ME Host
`EmulatorBridgeProtocol`, session lifecycle, `RuntimeHost`, vendor FreeJ2ME submodule, bootstrap through MIDlet startup.

### Epic 4 — Renderer / Emulator Surface
LCD surface metadata, frame presentation into SwiftUI emulator view.

### Epic 5 — Persistent Runtime
Design and migration for a long-lived JVM/session model (macOS process path + iOS embedded direction).

### Epic 6 — Embedded OpenJDK Mobile + FreeJ2ME
Replace stubs, embed Zero JVM, FreeJ2ME classpath, real MIDlet smoke, stability and exit containment.

### Epic 7 — OpenJDK Java Home / JNI Bring-up
Correct `java.home` / boot classpath so `JNI_CreateJavaVM` succeeds on device.

### Epic 8 — JNI Gateway Throwable Path
Propagate and contain Java throwables through the gateway without aborting the host incorrectly.

### Epic 9 — Embedded AWT Runtime
Enough `java.awt.image` / graphics natives for FreeJ2ME `PlatformImage` and first LCD frames on iOS.

### Epic 10 — Font, ImageIO & RunJar Hardening
FontManager/fontconfig, ImageIO sandbox, JPEG, and RunJar failure diagnosis for embedded classpath.

### Epic 11 — Device Gameplay, Lifecycle & RMS
5-minute corpus validation; PlatformBootstrap relaunch recovery; sandbox RMS `dataPath` for Gryzzles/Ubertris.

## Longer term

- Broader commercial JAR compatibility
- Save-state / freeze (if productized beyond MIDP RMS)
- Controllers / accessibility
- Keep FreeJ2ME upstream drift minimal via the bridge layer
