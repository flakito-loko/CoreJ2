# JavaOne

**Embedded Java ME Emulator for iPhone**

Run classic J2ME games natively on iOS using an embedded OpenJDK Mobile runtime and FreeJ2ME.

<p align="center">
  <img src="assets/branding/logo-dark.svg" alt="JavaOne" width="420" />
</p>

<p align="center">
  <img src="assets/branding/banner-github.png" alt="JavaOne banner" width="100%" />
</p>

<p align="center">
  <a href="https://flakito-loko.github.io/JavaOne/"><img src="https://img.shields.io/badge/status-Alpha-orange?style=for-the-badge" alt="Alpha" /></a>
  <a href="https://github.com/flakito-loko/JavaOne"><img src="https://img.shields.io/badge/version-1.0.0--dev-blue?style=for-the-badge" alt="Version" /></a>
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

---

## Hero

| | |
|:--|:--|
| **JavaOne** | Embedded Java ME on iPhone — SwiftUI shell, in-process OpenJDK Mobile, FreeJ2ME MIDlets. |
| **Tagline** | Classic phones. Modern Apple devices. One embedded JVM. |

**Quick links**

- 📖 [Documentation](https://flakito-loko.github.io/JavaOne/)
- 🎮 [Compatibility](https://flakito-loko.github.io/JavaOne/compatibility/)
- 🏗 [Architecture](https://flakito-loko.github.io/JavaOne/architecture/)
- 🗺 [Roadmap](https://flakito-loko.github.io/JavaOne/roadmap/)
- 🎨 [Branding](https://flakito-loko.github.io/JavaOne/branding/)
- 📥 [Source Code](https://github.com/flakito-loko/JavaOne)

<p align="center">
  <img src="assets/branding/isotype.svg" alt="JavaOne isotype" width="96" />
</p>

---

## Features

- ✅ Embedded OpenJDK Mobile
- ✅ FreeJ2ME runtime
- ✅ Native SwiftUI frontend
- ✅ LCD rendering
- ✅ Touch
- ✅ Virtual keypad
- ✅ Persistent JVM
- ✅ RMS support
- ✅ Commercial MIDlets

---

## Screenshots

Placeholders until device captures land (`docs/images/screenshots/`):

| Main Menu | Library | Emulator |
|:---------:|:-------:|:--------:|
| ![Main Menu](docs/images/screenshots/main-menu.svg) | ![Library](docs/images/screenshots/library.svg) | ![Tetris](docs/images/screenshots/tetris.svg) |

---

## Brand

Official assets and usage rules: [`assets/branding/`](assets/branding/) · [Guidelines](assets/branding/branding-guidelines.md)

Palette: `#2563EB` · `#60A5FA` · `#0B1220` · `#FFFFFF` · `#94A3B8`  
Type: Space Grotesk + Inter (OFL)

---

## Runtime stack

```text
SwiftUI → EmulatorView → Bridge → RuntimeHost → PlatformBootstrap
       → JNIGateway → Embedded OpenJDK Mobile → FreeJ2ME → MIDlet
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](https://flakito-loko.github.io/JavaOne/getting-started/) | Install and launch a MIDlet |
| [Why JavaOne?](https://flakito-loko.github.io/JavaOne/why-javaone/) | Vision and technical rationale |
| [Architecture](https://flakito-loko.github.io/JavaOne/architecture/) | Layer ownership |
| [Compatibility](https://flakito-loko.github.io/JavaOne/compatibility/) | Device-validated matrix |
| [Branding](https://flakito-loko.github.io/JavaOne/branding/) | Visual identity |
| [Roadmap](https://flakito-loko.github.io/JavaOne/roadmap/) | Epics and progress |
| [FAQ](https://flakito-loko.github.io/JavaOne/faq/) | Common questions |

```bash
python3 -m venv .venv-docs && source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

---

## Status

🚧 **Alpha** — runs commercial MIDlets on physical iPhone; public corpus still expanding.

**1.0.0-dev** · Current focus: **Epic 12 — Compatibility Program**

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
  <a href="https://flakito-loko.github.io/JavaOne/compatibility/">Compatibility</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/branding/">Branding</a>
</p>

<p align="center">Copyright © JavaOne contributors</p>
