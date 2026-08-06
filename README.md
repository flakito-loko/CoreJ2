# JavaOne

Native iOS emulator for **Java ME (J2ME)**.

JavaOne aims to be the best J2ME emulator available for iPhone and iPad, with a first-party Apple feel — SwiftUI, SwiftData, and a clean bridge to an embedded FreeJ2ME runtime on OpenJDK Mobile.

## Status

| Item | Value |
|------|-------|
| Current version | **1.0** (development / pre-App Store) |
| Platform | iOS (device + simulator tooling) |
| Runtime path | SwiftUI → Bridge → RuntimeHost → PlatformBootstrap → JNIGateway → Embedded OpenJDK Mobile → FreeJ2ME → MIDlet |
| Documentation site | [GitHub Pages](https://javaonelabs.github.io/JavaOne/) (MkDocs Material) |

## Features

- Game library with SwiftData persistence
- JAR import pipeline (manifest, hash, duplicate detection, artwork)
- Emulator bridge isolating UI from FreeJ2ME
- Embedded OpenJDK Mobile (Zero) + FreeJ2ME on device
- Virtual keypad + touch mapping
- Sandboxed MIDP RMS under `Documents/JavaOne/Saves/`

## Documentation

| Doc | Description |
|-----|-------------|
| [Getting Started](docs/getting-started.md) | Install and run a MIDlet |
| [Building](docs/building.md) | Build the app and embedded runtime |
| [Architecture](docs/architecture.md) | Layer diagram and design rules |
| [Compatibility](docs/compatibility.md) | Device-validated MIDlet matrix |
| [Roadmap](docs/roadmap.md) | Epics and milestones |
| [FAQ](docs/faq.md) | Common questions |
| [Technical Reports](docs/technical-reports.md) | Engineering reports index |
| [CONTRIBUTING](CONTRIBUTING.md) | How to contribute |
| [SECURITY](SECURITY.md) | Vulnerability reporting |
| [CODE_OF_CONDUCT](CODE_OF_CONDUCT.md) | Community standards |
| [CHANGELOG](CHANGELOG.md) | Release history |
| [ROADMAP](ROADMAP.md) | Product roadmap (repo root) |

Machine-readable compatibility data lives in [`compatibility/`](compatibility/).

## Quick start (developers)

```bash
# Open the Xcode project
open JavaOne.xcodeproj

# Preview documentation locally
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

See [Building](docs/building.md) for OpenJDK Mobile and FreeJ2ME classpath steps.

## Architecture at a glance

```text
SwiftUI
  → Bridge
    → RuntimeHost
      → PlatformBootstrap
        → JNIGateway
          → Embedded OpenJDK Mobile
            → FreeJ2ME
              → MIDlet
```

FreeJ2ME is integrated through a bridge layer with as few upstream modifications as possible.

## License

Application code: see repository license terms when published.  
Vendor FreeJ2ME: **GPL-3.0** (see `Vendor/FreeJ2ME`).  
Compatibility corpus JARs are third-party fixtures used for validation only.

## Disclaimer

JavaOne is under active development. Compatibility results describe specific devices, iOS builds, and validation dates — not a guarantee for every JAR.
