# Emulator Architecture

CoreJ2 integrates the Java ME runtime through a dedicated **Emulator Bridge** layer.

The goal is to launch installed games without coupling SwiftUI, Library, or ImportEngine to FreeJ2ME.

FreeJ2ME should be integrated later with as few changes as possible to the original emulator and to the rest of CoreJ2.

---

## Current Status (E3-US001)

Epic 3 introduces the skeleton only:

| Piece | Status |
|-------|--------|
| `EmulatorBridgeProtocol` | Present |
| `DefaultEmulatorBridge` | Placeholder (does not start an emulator) |
| `LaunchConfiguration` | Minimal (`InstalledGame`) |
| `EmulatorSession` | Minimal (`id` + configuration) |
| UI launch flow | Not wired yet |
| FreeJ2ME | Not integrated |

`DefaultEmulatorBridge.launch(_:)` returns an `EmulatorSession` and does **not** start FreeJ2ME or any native process.

---

## Design Principles

1. **Single entry point** — UI / ViewModels talk only to `EmulatorBridgeProtocol`.
2. **Protocol-oriented** — FreeJ2ME is an implementation detail behind the bridge.
3. **Stable data contracts** — `LaunchConfiguration` and `EmulatorSession` evolve without rewriting Library or Import.
4. **Composition root** — `AppDependencyContainer` owns wiring (`makeEmulatorBridge()`).
5. **Isolation** — ImportEngine and EmulatorBridge remain independent features.

These match `AGENTS.md`: bridge FreeJ2ME without modifying the original emulator more than necessary.

---

## Layer Diagram

```
┌─────────────────────────────────────────┐
│  SwiftUI / ViewModels (future launch)   │
└───────────────────┬─────────────────────┘
                    │ LaunchConfiguration
                    ▼
┌─────────────────────────────────────────┐
│         EmulatorBridgeProtocol          │
│   (single entry point for launching)    │
└───────────────────┬─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         DefaultEmulatorBridge           │
│     (placeholder → FreeJ2ME later)      │
└───────────────────┬─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│     FreeJ2ME runtime (not integrated)   │
│   frames / audio / input / save states  │
└─────────────────────────────────────────┘
```

Library and ImportEngine supply `InstalledGame` (JAR path, metadata, hash). They never call FreeJ2ME directly.

---

## Source Layout

```
JavaOne/Features/Emulator/
├── Models/
│   ├── LaunchConfiguration.swift
│   └── EmulatorSession.swift
└── Services/
    ├── EmulatorBridgeProtocol.swift
    └── DefaultEmulatorBridge.swift
```

Registered in `AppDependencyContainer` as:

```swift
private lazy var emulatorBridge: EmulatorBridgeProtocol = DefaultEmulatorBridge()

func makeEmulatorBridge() -> EmulatorBridgeProtocol {
    emulatorBridge
}
```

---

## Core Types

### `LaunchConfiguration`

Input to a launch request.

| Field | Role |
|-------|------|
| `game` | `InstalledGame` to run (`jarURL`, title, hash, …) |

Future fields may include phone profile, screen size, sound options, and save-state restore paths—without changing the bridge entry method signature if possible.

### `EmulatorSession`

Result of a successful `launch(_:)`.

| Field | Role |
|-------|------|
| `id` | Session identity |
| `configuration` | Configuration that produced the session |

Future fields may include lifecycle state (prepared / running / paused), frame callbacks, and teardown handles.

### `EmulatorBridgeProtocol`

```swift
@MainActor
protocol EmulatorBridgeProtocol {
    func launch(_ configuration: LaunchConfiguration) throws -> EmulatorSession
}
```

Additional lifecycle APIs (`pause`, `resume`, `stop`, input injection) should be added to this protocol as Epic 3 progresses—still without exposing FreeJ2ME types to UI.

---

## Boundary Rules

| Allowed | Not allowed |
|---------|-------------|
| ViewModel → `EmulatorBridgeProtocol` | View → FreeJ2ME |
| Bridge → FreeJ2ME adapter (future) | ImportEngine → EmulatorBridge |
| Bridge reads `InstalledGame.jarURL` | ViewModel → SwiftData / FreeJ2ME |
| DI swaps bridge implementations | Copy FreeJ2ME APIs into Library models |

---

## FreeJ2ME Integration Strategy

1. Keep FreeJ2ME sources as intact as practical (vendor / submodule / binary).
2. Add a thin adapter **inside** the Emulator feature (e.g. `FreeJ2MEEmulatorBridge` or a collaborator used by `DefaultEmulatorBridge`).
3. Map CoreJ2 types → FreeJ2ME launch args (`jarURL`, optional profile).
4. Map FreeJ2ME runtime events → `EmulatorSession` / callbacks consumed by UI.
5. Do not leak FreeJ2ME types across the bridge protocol.

Recommended evolution of `DefaultEmulatorBridge`:

```
launch(configuration)
  → validate game.jarURL
  → start FreeJ2ME session (adapter)
  → return EmulatorSession bound to that runtime
```

Until that adapter exists, the placeholder remains safe for Library and Import work.

---

## Roadmap (Epic 3+)

Suggested order after the skeleton:

1. Wire Library UI / ViewModel to `makeEmulatorBridge()` (launch button).
2. Expand `LaunchConfiguration` (display size, audio, phone type).
3. Session lifecycle: pause / resume / stop.
4. FreeJ2ME adapter (frames → renderer surface).
5. Input bridge (touch / virtual keypad → FreeJ2ME keys).
6. Audio bridge.
7. Save states (optional, later).

Import Engine (Epic 2) stays the source of installed JARs and metadata; Emulator Bridge only consumes them.

---

## Testing Guidance

- Unit-test bridge behavior against `EmulatorBridgeProtocol` fakes in ViewModels.
- Keep FreeJ2ME integration tests behind the adapter, not in Library tests.
- Placeholder `DefaultEmulatorBridge` must remain side-effect free (no process launch).

---

## Summary

CoreJ2 owns product UX, library, and import.

The **Emulator Bridge** owns the only path into the runtime.

FreeJ2ME becomes a replaceable backend behind `EmulatorBridgeProtocol`, which is how Epic 3 stays aligned with the long-term goal in `AGENTS.md`.
