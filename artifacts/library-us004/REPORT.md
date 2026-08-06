# LIBRARY-US004 — Metadata Activation + Editable Game Identity

**Status:** Complete  
**Device:** iPhone (`00008150-000C70A80EBA401C`)  
**Tests:** `EditableIdentityTests` + `LIBRARYUS004IdentityUITests` — **TEST SUCCEEDED**

## Architecture summary

### Part A — Production metadata (no HTML scraping)
- `ProductionMetadataConfiguration` resolves the live JSON catalog URL  
  (`https://raw.githubusercontent.com/flakito-loko/CoreJ2/main/docs/metadata/catalog.json`)  
  with optional overrides: `CoreJ2MetadataCatalogURL` / `CoreJ2MetadataEndpoint`.
- Provider chain (first hit wins), via existing `MetadataProvider` abstraction:
  1. Optional `HTTPMetadataProvider` (user lookup API)
  2. `RemoteJSONCatalogMetadataProvider` (production JSON catalog + Documents cache)
  3. Bundled `CatalogMetadataProvider` (`GameMetadataCatalog.json`)
- Import / library load still runs `GameMetadataEnricher` automatically when online metadata is available.

### Part B — Editable identity
| Field | Behavior |
|--------|----------|
| Official Name | From manifest / providers; never overwritten by user rename |
| Display Name | User override; **priority in all UI** (`InstalledGame.title`) |
| Publisher / Genre / Year | Optional edits; flagged `is*Custom` |
| Artwork | Remains keyed by JAR **SHA-256** (`contentHash`) |

Enrichment updates official fields only and preserves custom display/publisher/genre/year.

Game Settings sheet edits persist through SwiftData (`InstalledGameEntity`). Sibling sheets dismiss before settings presents so UITests/device can open Settings from Detail.

## Screenshots

See `artifacts/library-us004/screenshots/`

## Validation report

| Check | Result |
|-------|--------|
| Production catalog endpoint configured (JSON, not scrape) | Pass |
| Provider abstraction retained (composite chain) | Pass |
| Auto metadata on import / enrich | Pass (unit + device wait for enriching) |
| Display Name priority over Official | Pass (`EditableIdentityTests`) |
| Custom fields preserved across enrich | Pass (`EditableIdentityTests`) |
| Display Name edit persists | Pass (`LIBRARYUS004IdentityUITests`) |
| Artwork / identity by SHA-256 | Pass (model + settings Identity section) |
| OpenJDK / FreeJ2ME / Emulator / MMAPI / RMS unmodified in this commit | Pass |

## Commit hash

_(filled after commit)_
