# LIBRARY-US001 — Modern Game Library

**Status:** Complete  
**Device:** iPhone (`00008150-000C70A80EBA401C`)  
**UITest:** `LIBRARYUS001LibraryUITests/testModernLibraryShowsBrandSearchAndLayouts` — **TEST SUCCEEDED**

## Screenshots

| Capture | Path |
|---------|------|
| Grid | `artifacts/library-us001/screenshots/01-library-grid.png` |
| List | `artifacts/library-us001/screenshots/02-library-list.png` |
| With games | `artifacts/library-us001/screenshots/03-library-with-games.png` |

Raw xcresult: `artifacts/library-us001/xcresults/library-ui.xcresult`

## Architecture summary

UI/UX-only redesign of the CoreJ2 library. Emulator / OpenJDK / FreeJ2ME / MMAPI / RMS were not modified.

```
LibraryView (SwiftUI)
  ├─ LibraryTheme — brand tokens, Avenir Next, atmosphere gradients
  ├─ LibraryViewModel — search, layout mode, favorites, lastPlayed, launch
  ├─ GameCardView / GameListRowView — interactive cards
  ├─ GameCoverView — NSCache-backed artwork + GeneratedCoverView placeholder
  └─ Persistence
       InstalledGame (+ publisher, cover, resolution, favorite, lastPlayed, compatibility)
       → InstalledGameEntity (SwiftData)
       → import: ManifestStep (MIDlet-Vendor) + ArtworkStep (coverURL)
```

Top section: **CoreJ2** brand, search, game count, Favorites strip, Recent strip, All Games (LazyVGrid / list).

## Performance notes

- `LazyVGrid` / `LazyVStack` / horizontal `LazyHStack` for deferred cell creation
- `LibraryCoverImageCache` (`NSCache`, count + cost limits) avoids re-decoding covers while scrolling
- Generated covers are pure SwiftUI (no bitmap work) when artwork is missing
- Spring animations on grid ↔ list; search filters on the main actor without reloading disk images

## Validation

- Built + installed on physical iPhone
- UITest asserted CoreJ2 brand, search field, grid/list toggle, and captured three screenshots

## Commit hash

`e610e8c0235d1282b4509702e80097b4e459bb89`.
