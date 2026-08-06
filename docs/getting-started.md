# Getting Started

## Requirements

- iPhone or iPad (device validation targets recent iOS)
- A Java ME `.jar` you are legally allowed to run
- A development build of CoreJ2 (App Store release pending)

## Install a game

1. Open CoreJ2.
2. Use the library import flow to select a `.jar`.
3. The Import Engine reads the manifest, computes a content hash, rejects duplicates, and extracts artwork when present.
4. The title appears in your library.

## Launch

1. Tap a game in the library.
2. The Emulator Bridge starts a session through RuntimeHost → PlatformBootstrap.
3. Wait for the first LCD frame.
4. Use the virtual keypad and/or touch surface.

## Saves (RMS)

MIDP RecordStore data is written under:

```text
Documents/JavaOne/Saves/<game-uuid>/rms/...
```

Do not rely on relative `./rms/` paths from desktop FreeJ2ME docs — CoreJ2 configures a sandbox `dataPath` per game.

## Tips

- Prefer titles listed on the [Compatibility](compatibility.md) page for first tests.
- If a launch fails, leave the emulator and try again; relaunch recovery was hardened in Epic 11.
- Audio may be silent — MMAPI validation is still upcoming.

## Next

- [Building](building.md) from source
- [FAQ](faq.md)
