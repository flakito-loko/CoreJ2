# Architecture

JavaOne isolates SwiftUI from FreeJ2ME. All launches cross a bridge so the vendor emulator can evolve with minimal forks.

## Layer stack

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

```mermaid
flowchart TB
  subgraph presentation [Presentation]
    UI[SwiftUI]
  end
  subgraph application [Application]
    Bridge[Bridge]
    Host[Runtime Host]
  end
  subgraph runtime [Embedded runtime]
    JVM[Embedded OpenJDK Mobile]
    FJ[FreeJ2ME]
    Mid[Commercial MIDlet]
  end
  UI --> Bridge --> Host --> JVM --> FJ --> Mid
```

## Ownership and responsibilities

| Layer | Owns | Must not |
|-------|------|----------|
| **SwiftUI** | Layout, chrome, keypad/touch gestures | Call JNI or FreeJ2ME types |
| **Bridge** | Launch/stop API for the app | Embed FreeJ2ME classes |
| **Runtime Host** | Map product models → bootstrap ops | Leak `JNIEnv` upward |
| **Embedded OpenJDK Mobile** | In-process Zero VM | Be replaced by a desktop process on iOS |
| **FreeJ2ME** | MIDP/CLDC + LCD | Be patched except when a story requires a minimal fix |
| **Commercial MIDlet** | Game code | Escape the sandbox |

## Session lifecycle

```mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> Starting: initialize
  Starting --> Ready: platform + painter bound
  Ready --> Ready: runJar / frames
  Ready --> Shutdown: stopSession
  Shutdown --> Starting: initialize again same JVM
  Ready --> Shutdown: failed launch unwind
```

Epic 11 ensured failed launches always unwind via `stopSession`, so the host cannot stick in `ready`.

## Related docs

- [Why JavaOne?](why-javaone.md)
- [Milestones](milestones.md)
- [Technical Reports](technical-reports.md)
- `docs/Architecture/` — embedded JVM ADRs
