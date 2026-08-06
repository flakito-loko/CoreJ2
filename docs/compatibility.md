# Compatibility

JavaOne tracks MIDlet compatibility from **device validation reports**, not anecdotal runs.

Machine-readable sources:

- Repo: [`compatibility/compatibility.json`](https://github.com/javaonelabs/JavaOne/blob/main/compatibility/compatibility.json) · [`compatibility.csv`](https://github.com/javaonelabs/JavaOne/blob/main/compatibility/compatibility.csv)
- Site downloads: [JSON](compatibility/compatibility.json) · [CSV](compatibility/compatibility.csv)

**Validation baseline:** 2026-08-06 · iPhone 17 Pro Max · iOS 26.5.2  
**Runtime:** Production app + embedded OpenJDK Mobile + FreeJ2ME  
**Primary reports:** E11-US001 (gameplay), E11-US002 (relaunch), E11-US003 (RMS)

## Corpus matrix

| Game | Status | FPS | RMS | Touch | Keypad | Audio | Notes |
|------|--------|-----|-----|-------|--------|-------|-------|
| [Alea](compatibility/games/Alea.md) | Playable | 0.00 | N/A | Pass | Pass | Untested | First paint OK; LCD frame counter stalled (~6) during 5 min continuous input (P2). Relaunch OK after E11-US002. |
| [Astroids](compatibility/games/Astroids.md) | Playable | 13.65 | N/A | Pass | Pass | Untested | Strong game loop on device; frames 72→4174 over ~5 min. Relaunch OK. |
| [Tetris](compatibility/games/Tetris.md) | Playable | 4.01 | N/A | Pass | Pass | Untested | Fixture tetris.jar; continuous frames 13→1222. Commercial Tetris_240x320 also present on device but not exercised in the 5-min loop. |
| [Gryzzles](compatibility/games/Gryzzles.md) | Playable | — | Pass | Pass | Pass | Untested | E11-US001 failed with RMS NPE. Fixed in E11-US003 (sandbox dataPath). Launches and persists GryzzlesLevel store; relaunch OK. |
| [Ubertris](compatibility/games/Ubertris.md) | Playable | 11.84 | Pass | Pass | Pass | Untested | First session painted well (65→3637). E11-US001 RMS path + relaunch/bootstrap issues fixed in E11-US002/US003. License Alert remains (P2 UI). |

## Status legend

| Status | Meaning |
|--------|---------|
| Playable | Launches and sustains interactive gameplay on device |
| Partial | Launches with significant limitations |
| Broken | Fails to launch or is unusable |
| Untested | Not measured in the referenced validation runs |

## How to read FPS

FPS values come from the E11-US001 accessibility LCD frame counter over ~5 minute sessions.

- **Astroids / Ubertris** show strong continuous painter throughput.
- **Tetris** is playable with moderate frame growth.
- **Alea** paints initially but the counter stalls (input-driven / sparse updates) — still marked Playable for interaction, with a P2 note.
- **Gryzzles** has no 5-minute FPS sample from E11-US001 because launch failed before the RMS fix; post-fix launches succeeded in E11-US003 without a timed FPS capture.

## Audio

Audio / MMAPI was **out of scope** for E11 validation. Cells marked Untested are intentional.

## Per-game reports

- [Alea](compatibility/games/Alea.md)
- [Astroids](compatibility/games/Astroids.md)
- [Tetris](compatibility/games/Tetris.md)
- [Gryzzles](compatibility/games/Gryzzles.md)
- [Ubertris](compatibility/games/Ubertris.md)
