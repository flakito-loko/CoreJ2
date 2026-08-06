# Gryzzles

Puzzle MIDlet that exercises MIDP RecordStore during `startApp`.

| Field | Value |
|-------|-------|
| JAR | `gryzzles.jar` |
| Status | Playable (after E11-US003) |
| Avg FPS | Not measured in 5-min loop (launch failed in E11-US001) |
| RMS | **Pass** (`GryzzlesLevel`) |
| Touch | Pass (post-fix) |
| Keypad | Pass (post-fix) |
| Audio | Untested |

## Validation history

### E11-US001 — Broken
- Launch failed: `NullPointerException` in `RecordStore.getNumRecords()` because `store == null` during `startApp`.
- Severity **P1**. App process survived; later titles could still launch until Ubertris relaunch stuck the bootstrap.

### E11-US003 — Fixed
Root cause: FreeJ2ME built RMS paths as `./rms/<suitename>` relative to a non-writable iOS CWD when `dataPath` was empty.

CoreJ2 now configures sandbox `dataPath` under `Documents/JavaOne/Saves/<gameUUID>/` before `loadJar`/`runJar`.

Results:
- Launch success
- Store written: `rms/Gryzzles/GryzzlesLevel`
- Relaunch reuses the same UUID path

## Notes
Treat Gryzzles as the RMS regression canary for embedded iOS.
