# Compatibility

JavaOne tracks MIDlet compatibility from **device validation reports**.
This page is generated from [`compatibility/compatibility.json`](https://github.com/flakito-loko/JavaOne/blob/main/compatibility/compatibility.json) — do not hand-edit the matrix.

**Downloads:** [JSON](compatibility/compatibility.json) · [CSV](compatibility/compatibility.csv)

**Validation baseline:** 2026-08-06 · iPhone 17 Pro Max · iOS 26.5.2  
**Runtime:** Production app + embedded OpenJDK Mobile + FreeJ2ME  
**Primary reports:** E11-US001 · E11-US002 · E11-US003

## Snapshot

| Metric | Value |
|--------|-------|
| Titles in corpus | 5 |
| Launch success | 5/5 (100.0%) |
| Playable or better | 5/5 (100.0%) |
| Compatibility (playable+) | **100.0%** |

See also: [Compatibility statistics](compatibility-stats.md) · [Performance](performance.md)

## Corpus matrix

| Game | Vendor | MIDP | Status | FPS | Touch | Keypad | RMS | Audio | Notes |
|------|--------|------|--------|-----|-------|--------|-----|-------|-------|
| [Alea](compatibility/games/Alea.md) | ro.plesoianu | MIDP 2.0 | <span class="status-playable">🟢 Playable</span> | 0.00 | Pass | Pass | N/A | Untested | First paint OK; LCD frame counter stalled (~6) during 5 min continuous input (P2). Relaunch OK after E11-US002. |
| [Astroids](compatibility/games/Astroids.md) | astroids | MIDP 2.0 | <span class="status-playable">🟢 Playable</span> | 13.65 | Pass | Pass | N/A | Untested | Strong game loop on device; frames 72→4174 over ~5 min. Relaunch OK. |
| [Tetris](compatibility/games/Tetris.md) | game.Tetris (fixture) | MIDP 2.0 | <span class="status-playable">🟢 Playable</span> | 4.01 | Pass | Pass | N/A | Untested | Fixture tetris.jar; continuous frames 13→1222. Commercial Tetris_240x320 also present on device but not exercised in the 5-min loop. |
| [Gryzzles](compatibility/games/Gryzzles.md) | game.Gryzzles | MIDP 2.0 | <span class="status-playable">🟢 Playable</span> | — | Pass | Pass | Pass | Untested | E11-US001 failed with RMS NPE. Fixed in E11-US003 (sandbox dataPath). Launches and persists GryzzlesLevel store; relaunch OK. |
| [Ubertris](compatibility/games/Ubertris.md) | ubertris | MIDP 2.0 | <span class="status-playable">🟢 Playable</span> | 11.84 | Pass | Pass | Pass | Untested | First session painted well (65→3637). E11-US001 RMS path + relaunch/bootstrap issues fixed in E11-US002/US003. License Alert remains (P2 UI). |

## Status legend

| Badge | Status | Meaning |
|-------|--------|---------|
| 🟢 | Perfect | Launch, continuous frames, input, and applicable subsystems clean |
| 🟢 | Playable | Launches and sustains interactive gameplay |
| 🟡 | Partial | Launches with significant limitations |
| 🟠 | Launch only | Starts but is not sustainably playable |
| 🔴 | Not working | Fails to launch or is unusable |
| ⚪ | Untested | Not measured in the referenced runs |

## How to read FPS

FPS values come from the E11-US001 accessibility LCD frame counter over ~5 minute sessions.

- **Astroids / Ubertris** — strong continuous painter throughput
- **Tetris** — playable with moderate frame growth
- **Alea** — first paint OK; counter can stall (P2)
- **Gryzzles** — no timed FPS sample from E11-US001; validated after RMS fix in E11-US003

## Audio

Audio / MMAPI was out of scope for E11 validation. Cells marked Untested are intentional.

## Per-game reports

- [Alea](compatibility/games/Alea.md)
- [Astroids](compatibility/games/Astroids.md)
- [Tetris](compatibility/games/Tetris.md)
- [Gryzzles](compatibility/games/Gryzzles.md)
- [Ubertris](compatibility/games/Ubertris.md)
