# FAQ

## What is JavaOne?

A native iOS app that runs Java ME (J2ME) MIDlets using an embedded FreeJ2ME runtime on OpenJDK Mobile, wrapped in a SwiftUI shell.

## Is this FreeJ2ME?

FreeJ2ME is the Java ME engine. JavaOne is the iOS product: library, import, UI, bridge, and iOS-specific bootstrap (JNI, AWT bring-up, sandbox RMS).

## Will every JAR work?

No. See [Compatibility](compatibility.md). The public matrix starts with five canary titles validated on a physical iPhone.

## Where are my saves?

Under the app container:

`Documents/JavaOne/Saves/<game-uuid>/rms/…`

## Why is audio missing?

Audio / MMAPI was not part of the Epic 11 validation scope. Status is tracked as Untested until a dedicated pass lands.

## Why does Alea look “stuck”?

Alea accepts input and shows a first frame, but the LCD frame counter can stall during long sessions (P2). Prefer Astroids/Tetris/Ubertris for continuous-animation checks.

## Can I modify FreeJ2ME?

Prefer fixing issues in JavaOne’s bridge/bootstrap. Vendor patches must be minimal and documented.

## How do I build docs?

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

## How do I report a security issue?

See [SECURITY.md](https://github.com/javaonelabs/JavaOne/blob/main/SECURITY.md). Do not file public issues for sensitive reports.
