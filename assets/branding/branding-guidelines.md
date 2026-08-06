# JavaOne Branding Guidelines

Official visual identity for JavaOne. Assets live in `assets/branding/`.

## Brand summary

JavaOne is an **embedded Java ME emulator for iPhone**. The mark combines a minimal phone silhouette, an LCD panel, a geometric diamond (embedded core), and retro keypad dots — original artwork, **not** derived from Oracle Java / coffee-cup marks.

## Logo files

| File | Use |
|------|-----|
| `isotype.svg` | Symbol only — favicon, app mark, avatar |
| `logo.svg` | Primary lockup (transparent, blue wordmark) |
| `logo-dark.svg` | Lockup on dark plate (`#0B1220`) |
| `logo-light.svg` | Lockup on white plate |
| `logo-square.svg` | Square crop of the isotype |
| `favicon.svg` | Site / browser icon |
| `banner-github.png` | GitHub repository banner (1280×640) |
| `social-preview.png` | Open Graph / social card (1200×630) |
| `splash.png` | Splash / marketing still |
| `app-icon-concept.png` | App icon concept (1024×1024) |

## Color palette

| Token | Hex | Role |
|-------|-----|------|
| Primary | `#2563EB` | Brand, CTAs, LCD |
| Secondary | `#60A5FA` | Accents, highlights |
| Background | `#0B1220` | Dark surfaces |
| White | `#FFFFFF` | Light text / light surfaces |
| Gray | `#94A3B8` | Secondary text |

Do not introduce Oracle red/orange “Java” colors into the brand system.

## Typography

Open fonts only:

- **Space Grotesk** — display / titles
- **Inter** — body / UI

MkDocs loads these via Google Fonts. Do not embed proprietary typefaces.

## Spacing

- Clear space around the isotype: **≥ 1/8 of the mark height** on all sides.
- Clear space around the lockup: **≥ height of the capital “J”** on all sides.
- Do not crowd the logo against other UI chrome.

## Minimum size

| Asset | Minimum |
|-------|---------|
| Isotype | 24×24 px digital |
| Lockup | 120 px wide digital |
| Print isotype | 8 mm |

Below minimum size, use the isotype alone (drop the wordmark).

## Logo usage — Do

- Use SVG whenever possible.
- Keep proportions locked (no stretch).
- Prefer `logo-dark.svg` on dark UIs and `logo-light.svg` on light UIs.
- Use the isotype for avatars, favicons, and small badges.

## Logo usage — Don’t

- Don’t recolor the diamond/LCD into Oracle Java orange/red.
- Don’t add gradients, shadows, or 3D bevels to the official SVGs.
- Don’t place the logo on busy photography without a scrim.
- Don’t rotate or skew the mark.
- Don’t recreate a coffee cup, steam, or “JAVA” wordmark imitation.
- Don’t use low-contrast gray-on-gray.

## Status icons (compatibility)

| Status | Icon | Color cue |
|--------|------|-----------|
| Perfect | ● | `#22C55E` |
| Playable | ● | `#22C55E` |
| Partial | ● | `#EAB308` |
| Launch only | ● | `#F97316` |
| Not working | ● | `#EF4444` |

## Voice

Technical, precise, emulator-community tone (PPSSPP / Dolphin / RPCS3 presentation quality) without copying their marks.

## Generation

Raster assets were composed with Pillow using Inter + Space Grotesk (OFL). To regenerate:

```bash
# fonts under assets/branding/fonts/ (gitignored)
.venv-docs/bin/python scripts/docs/generate_branding_assets.py
```
