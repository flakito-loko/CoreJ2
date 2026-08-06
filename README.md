# JavaOne

**Run classic Java ME (J2ME) games natively on iPhone and iPad.**

Embedded OpenJDK Mobile · FreeJ2ME · SwiftUI · Open Source

<p align="center">
  <img src="docs/assets/gifs/miami-nights.gif" alt="Miami Nights gameplay on JavaOne" width="360" />
</p>

<p align="center">
  <em>Miami Nights: Singles in the City — gameplay on a physical iPhone</em>
</p>

<p align="center">
  <a href="https://flakito-loko.github.io/JavaOne/"><img src="https://img.shields.io/badge/status-Alpha-orange?style=for-the-badge" alt="Alpha" /></a>
  <a href="https://github.com/flakito-loko/JavaOne/releases"><img src="https://img.shields.io/badge/version-0.9.0--alpha-blue?style=for-the-badge" alt="Version" /></a>
  <a href="https://github.com/flakito-loko/JavaOne"><img src="https://img.shields.io/badge/license-See%20repo-lightgrey?style=for-the-badge" alt="License" /></a>
  <a href="https://github.com/flakito-loko/JavaOne/actions/workflows/docs.yml"><img src="https://img.shields.io/github/actions/workflow/status/flakito-loko/JavaOne/docs.yml?branch=main&style=for-the-badge&label=Docs" alt="Docs CI" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/iOS-Device-000000?logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/OpenJDK-Mobile-2563EB?logo=openjdk&logoColor=white" alt="OpenJDK" />
  <img src="https://img.shields.io/badge/FreeJ2ME-Embedded-60A5FA" alt="FreeJ2ME" />
  <a href="https://flakito-loko.github.io/JavaOne/"><img src="https://img.shields.io/badge/Documentation-Online-2563EB" alt="Documentation" /></a>
</p>

<p align="center">
  <a href="https://flakito-loko.github.io/JavaOne/">Documentation</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/compatibility/">Compatibility</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/architecture/">Architecture</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/roadmap/">Roadmap</a> ·
  <a href="https://github.com/flakito-loko/JavaOne">Source</a>
</p>

---

## Current Status

| Feature | Status |
|---------|--------|
| Embedded OpenJDK Mobile | ✅ |
| FreeJ2ME Runtime | ✅ |
| Commercial MIDlets | ✅ |
| LCD Rendering | ✅ |
| Touch Input | ✅ |
| Virtual Keypad | ✅ |
| Save / Load (RMS) | ✅ |
| Multiple Launch Cycles | ✅ |
| Gameplay | ✅ |
| Silent Audio Compatibility | ✅ |
| Native Audio Playback | 🚧 In Progress |
| Compatibility Expansion | 🚧 In Progress |

---

## Reference Game

### Miami Nights: Singles in the City

Validated on:

- Physical iPhone
- Embedded OpenJDK Mobile
- FreeJ2ME
- SwiftUI frontend

**Current validation**

| Check | Result |
|-------|--------|
| Launch | ✓ |
| Menus | ✓ |
| Gameplay | ✓ |
| Save | ✓ |
| Load | ✓ |
| Dialogs | ✓ |
| Stable gameplay | ✓ |
| No crashes during manual play session | ✓ |

**Remaining work**

- Native MMAPI audio backend
- Compatibility expansion

<p align="center">
  <img src="docs/assets/screenshots/miami-nights-gameplay.PNG" alt="Miami Nights gameplay with virtual keypad" width="280" />
  &nbsp;
  <img src="docs/assets/screenshots/miami-nights-menu.PNG" alt="Miami Nights menu on JavaOne" width="280" />
</p>

<p align="center">
  <em>Gameplay and menu — Miami Nights on device</em>
</p>

---

## Showcase

| Preview | Caption |
|:-------:|---------|
| <img src="docs/assets/gifs/miami-nights.gif" alt="Miami Nights GIF" width="220" /> | **Miami Nights** — commercial title, playable session on physical iPhone |
| <img src="docs/assets/gifs/tetris.gif" alt="Tetris GIF" width="220" /> | **Tetris** — LCD rendering and virtual keypad |
| <img src="docs/assets/gifs/astroids.gif" alt="Astroids GIF" width="220" /> | **Astroids** — touch + keypad input path |

| Screenshot | Caption |
|:----------:|---------|
| <img src="docs/assets/screenshots/library.PNG" alt="JavaOne library" width="200" /> | **Library** — SwiftUI game list and import |
| <img src="docs/assets/screenshots/tetris.PNG" alt="Tetris on JavaOne" width="200" /> | **Tetris** — FreeJ2ME LCD surface |
| <img src="docs/assets/screenshots/astroids.PNG" alt="Astroids on JavaOne" width="200" /> | **Astroids** — device capture |
| <img src="docs/assets/screenshots/gryzzles.PNG" alt="Gryzzles on JavaOne" width="200" /> | **Gryzzles** — RMS / save path validation |

More captures: [Screenshots](https://flakito-loko.github.io/JavaOne/screenshots/)

---

## Gameplay Videos

Full device recordings (MP4):

| Title | Video |
|-------|-------|
| Miami Nights | [miami-nights.MP4](docs/assets/videos/miami-nights.MP4) |
| Tetris | [tetris.mp4](docs/assets/videos/tetris.mp4) |
| Astroids | [astroids.MP4](docs/assets/videos/astroids.MP4) |

HTML5 playback is available on the [documentation site](https://flakito-loko.github.io/JavaOne/).

---

## Architecture

```text
SwiftUI
  ↓
Bridge
  ↓
Runtime Host
  ↓
Embedded OpenJDK Mobile
  ↓
FreeJ2ME
  ↓
Commercial MIDlet
```

Details: [Architecture](https://flakito-loko.github.io/JavaOne/architecture/)

---

## Roadmap

### Completed Milestones

- Embedded JVM (OpenJDK Mobile Zero)
- FreeJ2ME Integration
- AWT
- ImageIO
- JPEG
- FontManager
- RMS
- Commercial MIDlets
- Miami Nights gameplay

### Current Work

- Native MMAPI Audio
- Compatibility Database

### Future Work

- Controller support
- Per-game settings
- Save States
- Performance optimization
- Shader pipeline

Full plan: [Roadmap](https://flakito-loko.github.io/JavaOne/roadmap/)

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](https://flakito-loko.github.io/JavaOne/getting-started/) | Install and launch a MIDlet |
| [Why JavaOne?](https://flakito-loko.github.io/JavaOne/why-javaone/) | Vision and technical rationale |
| [Architecture](https://flakito-loko.github.io/JavaOne/architecture/) | Layer ownership |
| [Compatibility](https://flakito-loko.github.io/JavaOne/compatibility/) | Device-validated matrix |
| [Roadmap](https://flakito-loko.github.io/JavaOne/roadmap/) | Milestones and next steps |
| [FAQ](https://flakito-loko.github.io/JavaOne/faq/) | Common questions |

```bash
python3 -m venv .venv-docs && source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

---

## Brand

Official assets: [`assets/branding/`](assets/branding/) · [Guidelines](assets/branding/branding-guidelines.md)

Palette: `#2563EB` · `#60A5FA` · `#0B1220` · `#FFFFFF` · `#94A3B8`

---

## Status

🚧 **Alpha · v0.9.0-alpha** — commercial J2ME titles run on physical iPhone with embedded OpenJDK Mobile. Native audio playback and broader compatibility are in progress.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

---

## License

Application licensing: see repository terms when published.  
Vendor FreeJ2ME: **GPL-3.0** (`Vendor/FreeJ2ME`).  
Brand assets: original JavaOne identity (see branding guidelines).

---

<p align="center">
  <a href="https://github.com/flakito-loko/JavaOne">GitHub</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/">Documentation</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/roadmap/">Roadmap</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/compatibility/">Compatibility</a>
</p>

<p align="center">Copyright © JavaOne contributors</p>
