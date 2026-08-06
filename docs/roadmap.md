# Roadmap

Mirror of the repository [ROADMAP.md](https://github.com/javaonelabs/JavaOne/blob/main/ROADMAP.md).

## Current version

**1.0.0-dev** — real MIDlets on device via embedded OpenJDK Mobile + FreeJ2ME.

## Next milestones

1. Compatibility sweep (Epic 12+) and public matrix expansion
2. Audio / MMAPI validation
3. Alea frame-continuity (P2)
4. App Store packaging & legal review
5. UX polish and shipping screenshots

## Completed Epics

### Epic 1 — Game Library
SwiftData-backed library and empty-state UX.

### Epic 2 — Import Engine
Manifest, SHA-256, duplicate detection, artwork extraction pipeline.

### Epic 3 — Emulator Bridge & FreeJ2ME Host
Bridge protocols, RuntimeHost, vendor submodule, MIDlet startup path.

### Epic 4 — Renderer / Emulator Surface
LCD frames into the SwiftUI emulator surface.

### Epic 5 — Persistent Runtime
Long-lived runtime design and migration notes.

### Epic 6 — Embedded OpenJDK Mobile + FreeJ2ME
In-process Zero JVM, FreeJ2ME classpath, smoke and stability.

### Epic 7 — OpenJDK Java Home / JNI Bring-up
Device-capable `JNI_CreateJavaVM` with correct `java.home`.

### Epic 8 — JNI Gateway Throwable Path
Safe throwable propagation through JNI.

### Epic 9 — Embedded AWT Runtime
Graphics stack sufficient for FreeJ2ME LCD buffers.

### Epic 10 — Font, ImageIO & RunJar Hardening
Fonts, image decoders, and RunJar diagnostics.

### Epic 11 — Device Gameplay, Lifecycle & RMS
5-minute corpus validation; relaunch recovery; sandbox RMS.

## Epic board

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
