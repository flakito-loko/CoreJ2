# Why CoreJ2?

Technical rationale for the project — factual, not marketing copy.

> Originally developed as **JavaOne**. The public brand is now **CoreJ2**; internal Xcode targets, package paths, and sandbox directories may still use the historical name.

## Project origin

CoreJ2 started as a native iOS app for managing and launching Java ME (J2ME) MIDlets. Early epics delivered a SwiftData library and import pipeline. The hard problem was always the runtime: running FreeJ2ME on iPhone without a jailbreak and without shipping a desktop-style external JVM process.

## Current validated state

CoreJ2 now runs commercial Java ME titles on a **physical iPhone** using an **embedded OpenJDK Mobile** runtime and **FreeJ2ME**, with a **SwiftUI** frontend.

Reference title: **Miami Nights: Singles in the City** — launch, menus, gameplay, save/load, and dialogs validated in a manual play session without crashes. Native MMAPI audio playback remains in progress (silent-audio compatibility path works).

## Vision

Become the best J2ME emulator available for iPhone and iPad, with a first-party Apple feel (SwiftUI, Human Interface Guidelines) while keeping FreeJ2ME changes minimal through a bridge layer.

## Why an embedded JVM

iOS does not allow arbitrary JIT processes with the flexibility of desktop. OpenJDK Mobile’s **Zero** interpreter builds can be linked into the app as static libraries and started with `JNI_CreateJavaVM` in-process. That yields:

- One app process for UI + runtime
- No App Store-hostile helper tool architecture
- Direct JNI control for LCD buffers, input, and lifecycle

## Why FreeJ2ME

FreeJ2ME already implements MIDP/CLDC APIs, LCD painting, and MIDlet lifecycle. Reimplementing that stack would dwarf the product. CoreJ2 vendors FreeJ2ME and talks to it through a Runtime Host + JNI bridge instead of forking aggressively.

## Why SwiftUI

Product UI (library, import, emulator chrome, keypad) should feel native. SwiftUI + MVVM keeps Views free of runtime details; ViewModels only see the bridge protocol.

## Why not an external process

macOS can host a persistent helper process. On iOS, process boundaries, sandboxing, and distribution constraints make an embedded JVM the practical path. Epic 5 documented persistence; Epics 6–11 realized the embedded path on device.

## Long-term goals

- Expand the public compatibility corpus (Epic 12+)
- Ship a native MMAPI audio backend
- Keep FreeJ2ME upstream drift minimal
- Package legally and size-consciously for distribution
