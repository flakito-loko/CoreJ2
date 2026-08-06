# JavaOne

**Embedded Java ME Emulator for iPhone**

Run classic J2ME games natively on iOS using an embedded OpenJDK Mobile runtime and FreeJ2ME.

<p align="center">
  <img src="docs/images/brand/logo.svg" alt="JavaOne" width="120" />
</p>

<p align="center">
  <a href="https://flakito-loko.github.io/JavaOne/"><img src="https://img.shields.io/badge/status-Alpha-orange?style=for-the-badge" alt="Alpha" /></a>
  <a href="https://github.com/flakito-loko/JavaOne/releases"><img src="https://img.shields.io/badge/version-1.0.0--dev-blue?style=for-the-badge" alt="Version" /></a>
  <a href="https://github.com/flakito-loko/JavaOne"><img src="https://img.shields.io/badge/license-See%20repo-lightgrey?style=for-the-badge" alt="License" /></a>
  <a href="https://github.com/flakito-loko/JavaOne/actions/workflows/docs.yml"><img src="https://img.shields.io/github/actions/workflow/status/flakito-loko/JavaOne/docs.yml?branch=main&style=for-the-badge&label=Docs" alt="Docs CI" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/iOS-Device-000000?logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/OpenJDK-Mobile-007396?logo=openjdk&logoColor=white" alt="OpenJDK" />
  <img src="https://img.shields.io/badge/FreeJ2ME-Embedded-2EA44F" alt="FreeJ2ME" />
  <img src="https://img.shields.io/badge/GitHub%20Pages-Live-222?logo=github" alt="Pages" />
  <a href="https://flakito-loko.github.io/JavaOne/"><img src="https://img.shields.io/badge/Documentation-Online-0A84FF" alt="Documentation" /></a>
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
- 📥 [Source Code](https://github.com/flakito-loko/JavaOne)

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

More: Astroids · Alea · Gryzzles · Settings — same folder, drop-in PNG/WebP replacements.

---

## Animated captures

GIF slots (placeholders only — no fake footage):

| Gameplay | Launch | Library | Touch |
|:--------:|:------:|:-------:|:-----:|
| ![Gameplay](docs/images/gifs/gameplay-placeholder.svg) | ![Launch](docs/images/gifs/launch-placeholder.svg) | ![Library](docs/images/gifs/library-placeholder.svg) | ![Touch](docs/images/gifs/touch-controls-placeholder.svg) |

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
| [Milestones](https://flakito-loko.github.io/JavaOne/milestones/) | Engineering timeline |
| [Roadmap](https://flakito-loko.github.io/JavaOne/roadmap/) | Epics and progress |
| [Performance](https://flakito-loko.github.io/JavaOne/performance/) | Benchmark placeholders |
| [FAQ](https://flakito-loko.github.io/JavaOne/faq/) | Common questions |

Local preview:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

---

## Status

🚧 **Alpha** — runs commercial MIDlets on physical iPhone; public corpus and packaging still expanding.

Current version: **1.0.0-dev** · Current epic focus: **Epic 12 — Compatibility Program**

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

---

## License

Application licensing: see repository terms when published.  
Vendor FreeJ2ME: **GPL-3.0** (`Vendor/FreeJ2ME`).  
Compatibility JARs are third-party fixtures for validation only.

---

<p align="center">
  <a href="https://github.com/flakito-loko/JavaOne">GitHub</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/">Documentation</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/roadmap/">Roadmap</a> ·
  <a href="https://flakito-loko.github.io/JavaOne/compatibility/">Compatibility</a>
</p>

<p align="center">Copyright © JavaOne contributors</p>
