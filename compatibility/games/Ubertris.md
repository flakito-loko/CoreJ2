# Ubertris

Tetris-like MIDlet with license Alert + RecordStore usage.

| Field | Value |
|-------|-------|
| JAR | `Ubertris.jar` |
| Status | Playable (after E11-US002 / E11-US003) |
| Avg FPS | **11.84** (first session, E11-US001) |
| RMS | **Pass** (`licenseStore`) after E11-US003 |
| Touch | Pass |
| Keypad | Pass |
| Audio | Untested |
| TTFF | ~1 s |
| Session | ≥5 min first session |
| Frames | 65 → 3637 (first session) |

## Validation history

### E11-US001 — Partial / blockers
- First session painted and accepted input.
- Logged `RecordStoreException: Problem Creating Record Store Path ./rms/Ubertris`.
- Relaunch returned `frames=0` / `launchFailed`.
- Failed relaunch left PlatformBootstrap in `invalidState(ready)` (**P0**), blocking later launches.

### E11-US002 — Lifecycle fixed
- Host always `stopSession` on PlatformBootstrap launch failure.
- `beginStartingSync` recovers from `.ready` / `.failed`.
- Repeated Alea→Ubertris→Astroids→Tetris cycles Pass without `invalidState(ready)`.

### E11-US003 — RMS fixed
- `licenseStore` created under sandbox Saves path.
- Relaunch persistence Pass.
- License Alert still appears (expected UI; P2).

## Notes
Ubertris is the combined canary for RMS + relaunch lifecycle.
