# Technical Milestones

Engineering timeline from idea to device-validated MIDlets.

```mermaid
timeline
    title JavaOne embedded runtime path
    section Foundations
        Idea : Native iOS J2ME product
        Library and Import : SwiftData + Import Engine
        Emulator Bridge : Protocol boundary to FreeJ2ME
    section Embedded JVM
        Embedded JVM : OpenJDK Mobile Zero linked in-process
        JNI_CreateJavaVM : Device-capable VM bring-up
    section Graphics stack
        AWT : BufferedImage / graphics natives
        ImageIO : Sandbox-safe image codecs
        JPEG : Decode path for MIDlet assets
        FontManager : Fontconfig / CFontManager
        First LCD : FreeJ2ME PlatformImage → SwiftUI surface
    section Product validation
        First Commercial MIDlet : Real JAR smoke on device
        Persistent JVM : Reuse VM across sessions
        RMS : Sandboxed dataPath RecordStores
        Miami Nights gameplay : Commercial title playable on iPhone
        Compatibility Program : Public matrix and corpus expansion
```

## Narrative

| Milestone | Meaning |
|-----------|---------|
| Idea | Ship J2ME on iPhone with first-party UX |
| Embedded JVM | In-process OpenJDK Mobile instead of external process |
| `JNI_CreateJavaVM` | Correct `java.home` / boot path on device |
| AWT | Enough desktop graphics natives for FreeJ2ME buffers |
| ImageIO / JPEG | Asset decode without desktop filesystem assumptions |
| FontManager | Text rendering dependencies for LCD |
| First LCD | Pixels from FreeJ2ME into EmulatorView |
| First commercial MIDlet | Unmodified JARs beyond hello-world |
| Persistent JVM | Launch/stop cycles without destroying the VM every time |
| RMS | Writable RecordStore paths under Documents |
| Miami Nights gameplay | Commercial title: launch, menus, gameplay, save/load on device |
| Compatibility Program | Public, data-driven title matrix |

See also: [Architecture](architecture.md) · [Roadmap](roadmap.md) · [Technical Reports](technical-reports.md)
