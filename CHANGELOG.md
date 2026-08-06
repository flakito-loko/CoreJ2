# Changelog

All notable changes to JavaOne, organized by epic.

## [0.9.0-alpha] — 2026-08-06

### Documentation

- Public project refresh (DOCS-US004): README, GitHub Pages, screenshots, GIFs, and gameplay videos
- Position JavaOne as a device-validated commercial J2ME runner (Miami Nights reference title)
- Status table, architecture stack, and roadmap split (completed / current / future)

### Media

- Device screenshots under `docs/assets/screenshots/`
- Optimized gameplay GIFs under `docs/assets/gifs/`
- Full MP4 recordings under `docs/assets/videos/`

## [Unreleased]

### Branding

- Official JavaOne visual identity (BRAND-US001): isotype, logos, banner, social preview, splash, app icon concept
- Brand guidelines and MkDocs/README integration (`assets/branding/`)

### Documentation

- Public documentation and website polish (DOCS-US002)
- Why JavaOne, milestones, performance, compatibility statistics
- Screenshot and GIF placeholder layout
- MkDocs Material branding for `flakito-loko/JavaOne`

## Epic 12 — Compatibility Program (in progress)

- Corpus expansion beyond canary titles
- Public compatibility.json / CSV as source of truth
- Statistics charts generated from validation data

## Epic 11 — Device Gameplay, Lifecycle & RMS

- E11-US001 continuous gameplay validation on physical iPhone
- E11-US002 PlatformBootstrap relaunch recovery
- E11-US003 sandboxed RMS `dataPath` (Gryzzles / Ubertris)

## Epic 10 — Font, ImageIO & RunJar Hardening

- FontManager / fontconfig bring-up
- ImageIO sandbox paths
- JPEG decode path
- RunJar failure diagnostics

## Epic 9 — Embedded AWT Runtime

- Enough `java.awt.image` / graphics natives for FreeJ2ME LCD buffers
- First LCD frame path on iOS

## Epic 8 — JNI Gateway Throwable Path

- Safe Java throwable propagation through JNIGateway

## Epic 7 — OpenJDK Java Home / JNI Bring-up

- Correct `java.home` / boot classpath
- Successful `JNI_CreateJavaVM` on device

## Epic 6 — Embedded OpenJDK Mobile + FreeJ2ME

- Replace native JVM stubs
- Embedded FreeJ2ME classpath
- Real MIDlet smoke, stability, exit containment, painter safety

## Epic 5 — Persistent Runtime

- Persistent JVM / session design and migration notes

## Epic 4 — Renderer / Emulator Surface

- LCD surface metadata and SwiftUI frame presentation

## Epic 3 — Emulator Bridge & FreeJ2ME Host

- Bridge protocols, RuntimeHost, vendor FreeJ2ME submodule
- Bootstrap through MIDlet startup (`v0.6-midlet-startup`)

## Epic 2 — Import Engine

- Manifest → Hash → DuplicateDetection → Artwork (`v0.2-import-engine`)

## Epic 1 — Game Library

- SwiftData library and empty-state UX

## Documentation site (DOCS-US001)

- Initial MkDocs Material site and GitHub Pages workflow
