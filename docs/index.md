---
hide:
  - navigation
  - toc
---

<div class="corej2-hero" markdown="1">

# CoreJ2

<p class="corej2-hero__tagline">Run classic Java ME (J2ME) games natively on iPhone & iPad.</p>

<p class="corej2-hero__pills" markdown="1">
`Embedded OpenJDK Mobile` · `FreeJ2ME` · `SwiftUI` · `Open Source`
</p>

<p class="corej2-hero__gif" markdown="1">
![Miami Nights gameplay on CoreJ2](assets/gifs/miami-nights.gif){ width="360" }
</p>

<p class="corej2-hero__caption">Miami Nights: Singles in the City — gameplay on a physical iPhone</p>

<p class="corej2-hero__badges" markdown="1">
[![Alpha](https://img.shields.io/badge/status-Alpha-orange)](https://github.com/flakito-loko/CoreJ2)
[![Version](https://img.shields.io/badge/version-0.9.0--alpha-blue)](https://github.com/flakito-loko/CoreJ2/releases)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://github.com/flakito-loko/CoreJ2)
[![iOS](https://img.shields.io/badge/iOS-Device-000000?logo=apple&logoColor=white)](https://github.com/flakito-loko/CoreJ2)
[![Docs](https://img.shields.io/badge/Docs-GitHub%20Pages-0A84FF)](https://flakito-loko.github.io/CoreJ2/)
</p>

<p class="corej2-hero__actions" markdown="1">
[📖 Documentation](getting-started.md){ .md-button .md-button--primary }
[🎮 Compatibility](compatibility.md){ .md-button }
[🏗 Architecture](architecture.md){ .md-button }
[🗺 Roadmap](roadmap.md){ .md-button }
[📥 Source Code](https://github.com/flakito-loko/CoreJ2){ .md-button }
</p>

</div>

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

Validated on physical iPhone with embedded OpenJDK Mobile, FreeJ2ME, and a SwiftUI frontend.

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

**Remaining work:** native MMAPI audio backend · compatibility expansion

<div class="corej2-shots corej2-shots--pair" markdown>

<figure markdown>
![Miami Nights gameplay](assets/screenshots/miami-nights-gameplay.PNG)
<figcaption>Gameplay with virtual keypad</figcaption>
</figure>

<figure markdown>
![Miami Nights menu](assets/screenshots/miami-nights-menu.PNG)
<figcaption>In-game menu on device</figcaption>
</figure>

</div>

---

## Showcase

### GIF previews

<div class="corej2-gallery" markdown>

<figure markdown>
![Miami Nights GIF](assets/gifs/miami-nights.gif)
<figcaption>Miami Nights — commercial title, playable session</figcaption>
</figure>

<figure markdown>
![Tetris GIF](assets/gifs/tetris.gif)
<figcaption>Tetris — LCD rendering and virtual keypad</figcaption>
</figure>

<figure markdown>
![Astroids GIF](assets/gifs/astroids.gif)
<figcaption>Astroids — touch + keypad input path</figcaption>
</figure>

</div>

### Screenshots

<div class="corej2-gallery" markdown>

<figure markdown>
![Library](assets/screenshots/library.PNG)
<figcaption>Library — SwiftUI game list and import</figcaption>
</figure>

<figure markdown>
![Tetris](assets/screenshots/tetris.PNG)
<figcaption>Tetris — FreeJ2ME LCD surface</figcaption>
</figure>

<figure markdown>
![Astroids](assets/screenshots/astroids.PNG)
<figcaption>Astroids — device capture</figcaption>
</figure>

<figure markdown>
![Gryzzles](assets/screenshots/gryzzles.PNG)
<figcaption>Gryzzles — RMS / save path validation</figcaption>
</figure>

</div>

See [Screenshots](screenshots/index.md).

---

## Gameplay Videos

<div class="corej2-videos" markdown>

### Miami Nights

<video controls playsinline preload="metadata" poster="assets/screenshots/miami-nights-gameplay.PNG" width="360">
  <source src="assets/videos/miami-nights.MP4" type="video/mp4">
</video>

[Download MP4](assets/videos/miami-nights.MP4)

### Tetris

<video controls playsinline preload="metadata" poster="assets/screenshots/tetris.PNG" width="360">
  <source src="assets/videos/tetris.mp4" type="video/mp4">
</video>

[Download MP4](assets/videos/tetris.mp4)

### Astroids

<video controls playsinline preload="metadata" poster="assets/screenshots/astroids.PNG" width="360">
  <source src="assets/videos/astroids.MP4" type="video/mp4">
</video>

[Download MP4](assets/videos/astroids.MP4)

</div>

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

Full layer ownership: [Architecture](architecture.md)

---

## Compatibility Database

Device-validated titles live in the public [Compatibility](compatibility.md) matrix. Expansion is ongoing (Epic 12).

[Browse compatibility →](compatibility.md){ .md-button }

---

## Documentation

| Page | Why |
|------|-----|
| [Why CoreJ2?](why-corej2.md) | Vision and technical rationale |
| [Getting Started](getting-started.md) | First launch |
| [Compatibility](compatibility.md) | Device-validated matrix |
| [Architecture](architecture.md) | Ownership by layer |
| [Roadmap](roadmap.md) | Completed, current, future |
| [Milestones](milestones.md) | Engineering timeline |
| [FAQ](faq.md) | Common questions |
| [Branding](branding.md) | Visual identity |

---

<div class="corej2-footer-note" markdown="1">

🚧 **Alpha · v0.9.0-alpha** · [GitHub](https://github.com/flakito-loko/CoreJ2) · [Roadmap](roadmap.md) · [Compatibility](compatibility.md)

</div>
