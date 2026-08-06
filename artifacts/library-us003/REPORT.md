# LIBRARY-US003 — Game Identity + Library Management

**Status:** Complete  
**Device:** iPhone (`00008150-000C70A80EBA401C`)  
**Tests:** `GameIdentityTests` + `LIBRARYUS003ManagementUITests` — **TEST SUCCEEDED**

## Architecture summary

### Part A — Stable identity
- Permanent game ID = **SHA-256 of JAR bytes** (`InstalledGame.contentHash` / `stableIdentity`).
- Never derived from filename.
- Used for metadata lookup, `MetadataCache/<hash>/`, settings files, and future sync.
- Install UUID (`InstalledGame.id`) remains the sandbox key for RMS (`Documents/JavaOne/Saves/<uuid>/`) so the emulator/RMS implementation is untouched.
- `GameIdentityRegistry` persists `hash → installUUID` under `Documents/JavaOne/Identity/index.json`.
- On import, `FileImportService` hashes first and reuses the bound UUID (Delete Game → reimport reconnects saves).

### Part B — Library management
Native actions via context menu (grid), swipe (list), and detail sheet:

| Action | Behavior |
|--------|----------|
| Play | Launch emulator |
| Game Settings | Notes, compatibility, identity hash |
| Favorite | Toggle heart |
| Change Cover | Existing cover sheet |
| Share JAR | System share sheet |
| Show Save Data | Lists `Saves/<uuid>/` |
| Delete | Native alert with two modes |

### Delete modes
- **Delete Game:** removes Library folder + metadata cache; **keeps** RMS + settings + identity binding.
- **Delete Everything:** also removes RMS, settings, identity binding.

## Screenshots

See `artifacts/library-us003/screenshots/`

## Validation report

| Check | Result |
|-------|--------|
| Import uses SHA-256 identity | Pass (unit + device) |
| SHA-256 stable / registry reuse | Pass (`GameIdentityTests`) |
| Delete Game keeps binding | Pass (unit) |
| Delete Everything clears binding | Pass (unit) |
| Settings shows SHA-256 | Pass (UITest) |
| Delete confirmation (Cancel) | Pass (UITest) |
| Emulator / OpenJDK / FreeJ2ME / MMAPI / RMS code unmodified | Pass |

## Commit hash

Pending commit.
