# LIBRARY-US005 — Production Metadata Database

**Status:** Complete  
**Catalog URL:** https://flakito-loko.github.io/CoreJ2/metadata/catalog.json  
**Version:** `1.0.0`

## Games populated

| Title | SHA-256 on device | Cover | Screenshots |
|-------|-------------------|-------|-------------|
| Miami Nights | yes | yes | 2 |
| Tetris (×3 hashes) | yes | yes | 1 |
| Astroids | yes | yes | 1 |
| Bounce | yes | yes | — |
| Johnny Crash | yes | yes | — |
| Gryzzles | yes | yes | 1 |
| Ubertris | yes | yes | — |
| Alea / Alea Jacta Est | yes | yes | — |
| Asphalt 3 / 4 | title | yes | — |
| Doom RPG | title | yes | — |
| Worms World Party | title | yes | — |
| Sonic Jump | title | yes | — |

## Layout

```
docs/metadata/
  catalog.json          # versioned production catalog
  covers/*.jpg
  screenshots/*.jpg
```

## App wiring

`ProductionMetadataConfiguration.defaultCatalogURL` → GitHub Pages catalog.  
`RemoteJSONCatalogMetadataProvider` unchanged abstraction; retries after failed fetches.  
Library backfill also re-enriches installs missing covers.

## Commit hash

`089084fd355ed89a850ad946280d5978ad26381b`
