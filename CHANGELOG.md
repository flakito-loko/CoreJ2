# Changelog

All notable changes to JavaOne are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) where practical for pre-release tags.

## [Unreleased]

### Added

- Public documentation website (MkDocs Material) — **DOCS-US001**
- Compatibility corpus data (`compatibility/compatibility.json`, `.csv`) from E11 device validation
- GitHub Pages deployment workflow

### Fixed

- PlatformBootstrap relaunch lifecycle (`invalidState(ready)`) — E11-US002
- Sandboxed MIDP RMS `dataPath` for Gryzzles / Ubertris — E11-US003

## [1.0.0-dev] — 2026-08-06

Development baseline after embedded runtime bring-up and device gameplay validation.

### Added

- Game library (SwiftData) — Epic 1
- Import Engine (manifest, hash, duplicates, artwork) — Epic 2
- Emulator Bridge, RuntimeHost, FreeJ2ME bootstrap through MIDlet startup — Epic 3
- Emulator surface / renderer path — Epic 4
- Persistent runtime design and migration — Epic 5
- Embedded OpenJDK Mobile + FreeJ2ME on iOS — Epic 6
- OpenJDK `java.home` / JNI create path — Epic 7
- JNI Gateway throwable handling — Epic 8
- Embedded AWT runtime for LCD frames — Epic 9
- Font / ImageIO / RunJar hardening — Epic 10
- Device gameplay validation, relaunch lifecycle, RMS compatibility — Epic 11

### Validation tags

| Tag | Meaning |
|-----|---------|
| `v0.2-import-engine` | Epic 2 complete |
| `v0.6-midlet-startup` | Epic 3 FreeJ2ME bootstrap through MIDlet startup |

## Legend

- **Added** for new capabilities
- **Changed** for behavior changes
- **Fixed** for bug fixes
- **Removed** for removals
