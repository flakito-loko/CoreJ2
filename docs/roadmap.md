# Roadmap

## Current version

**1.0.0-dev** · 🚧 Alpha

## Current epic

**Epic 12 — Compatibility Program** — expand corpus, keep `compatibility.json` authoritative, publish stats.

## Progress

| Track | Progress |
|-------|----------|
| Epic 1 · Game Library | <progress value="100" max="100"></progress> 100% |
| Epic 2 · Import Engine | <progress value="100" max="100"></progress> 100% |
| Epic 3 · Bridge & Host | <progress value="100" max="100"></progress> 100% |
| Epic 4 · Renderer | <progress value="100" max="100"></progress> 100% |
| Epic 5 · Persistent Runtime | <progress value="100" max="100"></progress> 100% |
| Epic 6 · Embedded FreeJ2ME | <progress value="100" max="100"></progress> 100% |
| Epic 7 · JNI / java.home | <progress value="100" max="100"></progress> 100% |
| Epic 8 · Gateway throwables | <progress value="100" max="100"></progress> 100% |
| Epic 9 · Embedded AWT | <progress value="100" max="100"></progress> 100% |
| Epic 10 · Font / ImageIO | <progress value="100" max="100"></progress> 100% |
| Epic 11 · Gameplay / RMS | <progress value="100" max="100"></progress> 100% |
| Epic 12 · Compatibility | <progress value="20" max="100"></progress> 20% |
| Audio / MMAPI | <progress value="0" max="100"></progress> 0% |
| Distribution packaging | <progress value="0" max="100"></progress> 0% |

## Completed epics

### Epic 1 — Game Library
SwiftData-backed library UX.

### Epic 2 — Import Engine
Manifest, hash, duplicates, artwork.

### Epic 3 — Emulator Bridge & FreeJ2ME Host
Bridge, RuntimeHost, vendor submodule, MIDlet startup.

### Epic 4 — Renderer / Emulator Surface
LCD frames into SwiftUI.

### Epic 5 — Persistent Runtime
Long-lived JVM design.

### Epic 6 — Embedded OpenJDK Mobile + FreeJ2ME
In-process Zero + FreeJ2ME classpath.

### Epic 7 — OpenJDK Java Home / JNI Bring-up
Device `JNI_CreateJavaVM`.

### Epic 8 — JNI Gateway Throwable Path
Safe exception propagation.

### Epic 9 — Embedded AWT Runtime
Graphics natives for LCD.

### Epic 10 — Font, ImageIO & RunJar Hardening
Fonts, codecs, RunJar diagnostics.

### Epic 11 — Device Gameplay, Lifecycle & RMS
5-minute corpus; relaunch recovery; sandbox RMS.

## Upcoming epics

1. **Epic 12** — Compatibility Program (current)
2. Audio / MMAPI validation epic
3. Frame-continuity / painter polish
4. Packaging & legal review

## Long-term goals

- Broad commercial title coverage
- First-party HIG polish and shipping screenshots
- Minimal FreeJ2ME upstream drift
- Sustainable public compatibility database

Repo mirror: [https://github.com/flakito-loko/JavaOne/blob/main/ROADMAP.md](https://github.com/flakito-loko/JavaOne/blob/main/ROADMAP.md)
