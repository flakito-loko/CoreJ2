---
hide:
  - navigation
  - toc
---

<div class="javaone-hero" markdown="1">

<p class="javaone-hero__logo" markdown="1">
![JavaOne](assets/branding/isotype.svg){ width="96" }
</p>

# JavaOne

<p class="javaone-hero__tagline">Embedded Java ME Emulator for iPhone</p>

![Banner](assets/branding/banner-github.png)

<p class="javaone-hero__lead">
Run classic J2ME games natively on iOS using an embedded OpenJDK Mobile runtime and FreeJ2ME.
</p>

<p class="javaone-hero__badges" markdown="1">
[![Alpha](https://img.shields.io/badge/status-Alpha-orange)](https://github.com/flakito-loko/JavaOne)
[![Version](https://img.shields.io/badge/version-1.0.0--dev-blue)](https://github.com/flakito-loko/JavaOne)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://github.com/flakito-loko/JavaOne)
[![iOS](https://img.shields.io/badge/iOS-Device-000000?logo=apple&logoColor=white)](https://github.com/flakito-loko/JavaOne)
[![Docs](https://img.shields.io/badge/Docs-GitHub%20Pages-0A84FF)](https://flakito-loko.github.io/JavaOne/)
</p>

<p class="javaone-hero__actions" markdown="1">
[📖 Documentation](getting-started.md){ .md-button .md-button--primary }
[🎮 Compatibility](compatibility.md){ .md-button }
[🏗 Architecture](architecture.md){ .md-button }
[🗺 Roadmap](roadmap.md){ .md-button }
[📥 Source Code](https://github.com/flakito-loko/JavaOne){ .md-button }
</p>

</div>

---

## Features

<div class="grid cards" markdown>

-   :material-chip: **Embedded OpenJDK Mobile**
-   :material-language-java: **FreeJ2ME runtime**
-   :material-apple: **Native SwiftUI frontend**
-   :material-monitor: **LCD rendering**
-   :material-gesture-tap: **Touch**
-   :material-keyboard: **Virtual keypad**
-   :material-memory: **Persistent JVM**
-   :material-content-save: **RMS support**
-   :material-gamepad-variant: **Commercial MIDlets**

</div>

---

## Screenshots

<div class="javaone-shots" markdown>

![Main Menu](images/screenshots/main-menu.svg)
![Library](images/screenshots/library.svg)
![Tetris](images/screenshots/tetris.svg)
![Astroids](images/screenshots/astroids.svg)

</div>

More placeholders: [Alea](images/screenshots/alea.svg) · [Gryzzles](images/screenshots/gryzzles.svg) · [Settings](images/screenshots/settings.svg)  
See [Screenshots](screenshots/index.md).

---

## Animated captures

Placeholders only — replace with real `.gif` files when available.

| Gameplay | Launch | Library | Touch controls |
|:--------:|:------:|:-------:|:--------------:|
| ![Gameplay](images/gifs/gameplay-placeholder.svg) | ![Launch](images/gifs/launch-placeholder.svg) | ![Library](images/gifs/library-placeholder.svg) | ![Touch](images/gifs/touch-controls-placeholder.svg) |

---

## Runtime stack

```mermaid
flowchart TD
  A[SwiftUI] --> B[EmulatorView]
  B --> C[Bridge]
  C --> D[RuntimeHost]
  D --> E[PlatformBootstrap]
  E --> F[JNIGateway]
  F --> G[Embedded OpenJDK Mobile]
  G --> H[FreeJ2ME]
  H --> I[MIDlet]
```

---

## Explore

| Page | Why |
|------|-----|
| [Why JavaOne?](why-javaone.md) | Vision and technical rationale |
| [Getting Started](getting-started.md) | First launch |
| [Compatibility](compatibility.md) | Device-validated matrix |
| [Milestones](milestones.md) | How we got here |
| [Architecture](architecture.md) | Ownership by layer |
| [Roadmap](roadmap.md) | Epics and progress |
| [Performance](performance.md) | Benchmark placeholders |
| [FAQ](faq.md) | Common questions |
| [Branding](branding.md) | Visual identity |

---

<div class="javaone-footer-note" markdown="1">

🚧 **Alpha** · [GitHub](https://github.com/flakito-loko/JavaOne) · [Roadmap](roadmap.md) · [Compatibility](compatibility.md) · [License / Security](https://github.com/flakito-loko/JavaOne/blob/main/SECURITY.md)

</div>
