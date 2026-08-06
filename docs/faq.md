# FAQ

## What is JavaOne?

A native iOS application that runs Java ME (J2ME) MIDlets using an **embedded** FreeJ2ME runtime on OpenJDK Mobile, with a SwiftUI library and emulator UI.

## How does it differ from FreeJ2ME?

FreeJ2ME is the Java ME engine. JavaOne is the iOS product: import/library, SwiftUI, bridge, PlatformBootstrap, JNI gateway, AWT/ImageIO bring-up, and sandbox RMS wiring.

## Does it use an embedded JVM?

Yes. On iOS, OpenJDK Mobile (Zero) is linked into the app process and started with `JNI_CreateJavaVM`.

## Does it require a jailbreak?

No. Development and validation target stock iOS devices with standard signing.

## Can it run commercial games?

Yes — commercial MIDlets have been exercised on physical iPhone. Public compatibility is tracked in the [Compatibility](compatibility.md) matrix (canary corpus today; expanding in Epic 12).

## Why OpenJDK Mobile?

It provides a buildable OpenJDK path for mobile/Zero that can be statically linked under iOS constraints, avoiding a desktop HotSpot/JIT process model.

## Why not the Android Runtime?

JavaOne targets Apple platforms with a MIDP stack (FreeJ2ME), not Android APKs. ART would not provide MIDP APIs or match the FreeJ2ME integration strategy.

## Where are saves stored?

Under `Documents/JavaOne/Saves/<game-uuid>/rms/…` after Epic 11 RMS wiring.

## Is audio supported?

Audio / MMAPI is not yet validated in the public matrix (marked Untested).

## How do I build the docs site?

```bash
pip install -r requirements-docs.txt
mkdocs serve
```
