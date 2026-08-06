# Alea

Dice / chance MIDlet used as the primary smoke title across embedded runtime validation.

| Field | Value |
|-------|-------|
| JAR | `Alea.jar` |
| Status | Playable |
| Avg FPS | ~0.00 (LCD counter stalled after first paints) |
| RMS | N/A (no store written in validation) |
| Touch | Pass |
| Keypad | Pass |
| Audio | Untested |
| TTFF | ~3.3 s |
| Session | ≥5 min sustained |

## Validation history

### E11-US001 — Continuous gameplay
- Launch succeeded; first frame OK.
- During ~301 s of keypad/touch input the accessibility LCD frame counter stayed at **6** (P2 frame continuity).
- Relaunch and post-session launch succeeded.
- No native crash.

### E11-US002 — Relaunch lifecycle
- Repeated launch/stop cycles succeeded after PlatformBootstrap recovery fix.
- Occasional `frames=0` / launchFailed observed on a hop; host recovered with `stopSession` (no `invalidState(ready)`).

### E11-US003 — RMS
- Save root created under `Documents/JavaOne/Saves/<uuid>/`.
- No RecordStore written by this MIDlet during the suite.

## Notes
Alea is playable for interaction testing, but do not treat it as a continuous-animation benchmark until frame continuity improves.
