# E6-US003 — Embedded FreeJ2ME Bring-up

**Fecha:** 2026-08-05  
**Estado:** VALIDADO (host OpenJDK Mobile + classpath embebido)  
**Depende de:** E6-US002  

## Veredicto

La secuencia de producción `DefaultPlatformBootstrap` completa el bootstrap FreeJ2ME
dentro del runtime OpenJDK Mobile embebido (sin pipeline alterno):

`EmbeddedJVMManager` → `DefaultJNIGateway` → `DefaultPlatformBootstrap` →
`MobilePlatform` → `Mobile.setPlatform` → `PainterRunnable` → `loadJar` →
`runJar` → `verifyDisplay` → `verifyRepaint` → callback painter/LCD en Swift.

El App Target copia FreeJ2ME + clases bootstrap a `OpenJDKMobile/classpath`.  
Device Zero: test de integración preparado (`EmbeddedFreeJ2MEBringUpTests`);
simulator no enlaza `libjvm.a` (XCTSkip).

---

## Validation

| Criterio | Resultado |
|----------|-----------|
| JVM created | ✓ host harness `ensureStarted` (~45 ms) |
| FreeJ2ME classes resolved | ✓ `org.recompile.mobile.*` en classpath |
| MobilePlatform instantiated | ✓ `mobilePlatformObjectId` no nil |
| Painter installed | ✓ `painterObjectId` no nil |
| JAR loaded | ✓ `DisplayProbe` via `loadJar` |
| MIDlet startApp reached | ✓ `START_APP_OK` / `reachedStartApp` |
| Display initialized | ✓ `hasCurrentDisplayable` |
| Repaint callback invoked | ✓ `painterInvoked` |
| Callback reached Swift | ✓ painter delta + `onLCDFrameExtracted` |

---

## Deliverables

### 1. Files created

| Path | Rol |
|------|-----|
| `scripts/embedded-jvm/compile-freej2me-classpath.sh` | Compila Vendor FreeJ2ME + bootstrap + fixture JAR |
| `scripts/embedded-jvm/run_e6_us003_embedded_freej2me_bringup.sh` | Harness host (misma secuencia de producción) |
| `Spike/E6US003EmbeddedFreeJ2MEBringUp/main.swift` | Entry del harness |
| `JavaOneTests/EmbeddedFreeJ2MEBringUpTests.swift` | Bundle classpath + device bring-up |
| `docs/Architecture/E6_US003_EMBEDDED_FREEJ2ME_BRINGUP.md` | Este doc |
| `artifacts/freej2me-embedded-classpath/` | Classes + `DisplayProbeMIDlet.jar` (local) |
| `artifacts/e6-us003-embedded-freej2me-bringup/metrics.json` | Métricas host |

### 2. Files modified

| Path | Cambio |
|------|--------|
| `scripts/openjdk-mobile/copy-ios-runtime-into-app.sh` | Copia classpath FreeJ2ME + fixture JAR al bundle |
| `JavaOne/App/AppDependencyContainer.swift` | Comentario: classpath incluye FreeJ2ME |
| `JavaOne.xcodeproj/project.pbxproj` | Test + outputPaths classpath |
| `scripts/embedded-jvm/README.md` | Instrucciones E6-US003 |

**Sin cambios** a EmulatorBridge, RuntimeHost public API, ViewModels, SwiftUI,
JNIGateway / EmbeddedJVMManager public APIs, Vendor/FreeJ2ME.

### 3. Embedded bootstrap sequence

```
1. EmbeddedJVMManager.ensureStarted()     // JNI_CreateJavaVM + java.home
2. DefaultPlatformBootstrap.initialize()
     gateway.bind()
     NativeCallbackHost.onBootstrapHeartbeat
     NewObject MobilePlatform(240, 320)
     Mobile.setPlatform(platform)
     PainterRunnable → MobilePlatform.setPainter
3. loadJar(DisplayProbeMIDlet.jar)
4. runJar() → MIDletLoader.start() → startApp()
5. verifyDisplay() → DisplaySupport.inspectStatus
6. verifyRepaint() → RepaintSupport.requestRepaint
     → PainterRunnable.run → Swift paintCount / onLCDFrameExtracted
7. stopSession() → shutdown()
```

Classpath bundle layout:

```
JavaOne.app/OpenJDKMobile/
  java.home/          ← OpenJDK Mobile Zero exploded
  classpath/          ← FreeJ2ME + org.javaone.bootstrap.*
  fixtures/
    DisplayProbeMIDlet.jar
```

### 4. Startup timing (host OpenJDK Mobile)

| Métrica | Valor |
|---------|-------|
| `ensureStarted` (JVM) | ~45 ms |
| `initialize` (MobilePlatform + painter) | ~1158 ms |
| `DestroyJavaVM` / shutdown | ~3010 ms (incluye timeout soft) |
| Device Zero | *medir en hardware* (`EmbeddedFreeJ2MEBringUpTests`) |

### 5. Memory usage (host)

| Métrica | Valor |
|---------|-------|
| RSS before | ~17.5 MiB |
| RSS after bring-up | ~71.0 MiB |
| Δ RSS | ~54.4 MiB |
| FreeJ2ME classpath size | ~2.1 MiB (412 classes) |

### 6. Remaining blockers before a commercial MIDlet on iPhone

1. **Device validation** — correr `EmbeddedFreeJ2MEBringUpTests` en iPhone físico (Zero `libjvm.a`).
2. **Commercial JAR import** — Library ya importa JARs; falta smoke de un MIDlet comercial real vía Host/Bridge (no solo DisplayProbe).
3. **Renderer / LCD presentation** — pixels llegan a Swift (`onLCDFrameExtracted`); falta presentar frames en UI (fuera de esta story).
4. **Input / audio** — no ejercitados aquí; audio explícitamente fuera de alcance.
5. **Simulator** — Zero iOS no está linkeado; desarrollo FreeJ2ME en sim sigue limitado.
6. **DestroyJavaVM latency** — shutdown ~3 s en host; revisar timeouts / teardown en device.
7. **Classpath packaging in CI** — `compile-freej2me-classpath.sh` debe ejecutarse antes del build device (artifacts gitignored).
8. **App size** — `java.home` ~119 MiB + classpath; plan de thinning / on-demand aún pendiente.

---

## Cómo reproducir

```bash
./scripts/embedded-jvm/compile-freej2me-classpath.sh
./scripts/embedded-jvm/run_e6_us003_embedded_freej2me_bringup.sh
# metrics → artifacts/e6-us003-embedded-freej2me-bringup/metrics.json
```

Device (tras stage Zero + compile classpath):

```bash
./scripts/openjdk-mobile/build-ios-zero.sh   # si hace falta
xcodebuild test -scheme JavaOne -destination 'platform=iOS,name=<device>' \
  -only-testing:JavaOneTests/EmbeddedFreeJ2MEBringUpTests
```
