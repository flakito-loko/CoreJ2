# LIBRARY-US002 — Online Metadata & Artwork

**Status:** Complete  
**Device:** iPhone (`00008150-000C70A80EBA401C`)  
**Tests:** `MetadataProviderTests` + `LIBRARYUS002MetadataUITests` — **TEST SUCCEEDED**

## What shipped

1. **Manifest** — `MIDlet-Name`, `MIDlet-Vendor`, `MIDlet-Version`
2. **`MetadataProvider` protocol** + `CompositeMetadataProvider`, `CatalogMetadataProvider`, `HTTPMetadataProvider` (configurable base URL via `UserDefaults` key `CoreJ2MetadataEndpoint` — no single website hardcoding)
3. **On import / backfill** — enricher downloads cover/screenshots when URLs exist, writes `metadata.json` + local artwork; thereafter fully offline
4. **Placeholder** — existing `GeneratedCoverView` when no cover on disk
5. **Cover controls** — Change Cover via Photos / Files, Restore Default

## Architecture

```
Import JAR
  → Manifest / Hash / Artwork (local icon)
  → GameMetadataEnricher(MetadataProvider)
       → catalog and/or HTTP lookup
       → download cover/screenshots once
       → persist metadata.json + SwiftData fields

GameDetailView
  → Photos / Files / Restore Default (GameCoverStore)
```

Offline: SwiftData + `Documents/.../metadata.json` + `artwork/` files. Network is only used on first enrich when a provider returns remote URLs.

## Screenshots

See `artifacts/library-us002/screenshots/`

## Commit hash

Pending commit.
