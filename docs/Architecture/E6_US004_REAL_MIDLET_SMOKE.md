# E6-US004 — Real MIDlet Smoke Test

**Fecha:** 2026-08-05  
**Estado:** VALIDADO (host OpenJDK Mobile + pipeline producción)  
**Depende de:** E6-US003  

## Veredicto

Un MIDlet real unmodified (**Alea**, MIT) completa el pipeline de producción:

`Library import` → `EmulatorViewModel` / `InstalledGame` → `DefaultEmulatorBridge` →
`FreeJ2MERuntimeHost` → `PlatformBootstrapLaunchSequence` → `DefaultPlatformBootstrap` →
Embedded OpenJDK Mobile + FreeJ2ME → primer frame LCD en Swift.

Unblocker: `RunJarSupport` acepta MIDlets reales (`Create MIDlet` sin exigir `START_APP_OK`).

---

## Validation

| Criterio | Resultado |
|----------|-----------|
| MIDlet launched | ✓ Bridge → Host |
| startApp executed | ✓ `reachedStartApp` |
| Display active | ✓ `hasCurrentDisplayable` |
| First frame received | ✓ `publishedFrameCount=1` |
| LCD dimensions | ✓ 240×320 |
| Java exceptions | ✓ ninguna |
| Shutdown result | ✓ `stopSession` + destroy (timeout soft ~3 s) |

---

## Deliverables

### 1. MIDlet used

| Field | Value |
|-------|--------|
| Name | **Alea** |
| Author | Felix Pleșoianu |
| License | MIT |
| Size | ~38 KB |
| Path | [`Fixtures/MIDlets/Alea.jar`](../../Fixtures/MIDlets/Alea.jar) |
| Modified | **No** (no rebuild, no bytecode patch) |
| Source | https://felix.plesoianu.ro/mobile/alea/ |

### 2. Files created

| Path | Rol |
|------|-----|
| `Fixtures/MIDlets/Alea.jar` | MIDlet unmodified |
| `Fixtures/MIDlets/README.md` | Licencia / origen |
| `Spike/E6US004RealMIDletSmoke/main.swift` | Host harness Bridge→Host |
| `scripts/embedded-jvm/run_e6_us004_real_midlet_smoke.sh` | Build + run harness |
| `JavaOneTests/RealMIDletSmokeTests.swift` | Import + ViewModel.startSession |
| `docs/Architecture/E6_US004_REAL_MIDLET_SMOKE.md` | Este doc |
| `artifacts/e6-us004-real-midlet-smoke/metrics.json` | Métricas host |

### 3. Files modified

| Path | Cambio |
|------|--------|
| `CoreJ2/.../Bootstrap/RunJarSupport.java` | Éxito real-MIDlet: `Create MIDlet` + sin errores FreeJ2ME |
| `scripts/openjdk-mobile/copy-ios-runtime-into-app.sh` | Copia `Alea.jar` → `OpenJDKMobile/fixtures/` |
| `JavaOne.xcodeproj/project.pbxproj` | Test target |

**Sin cambios** a Bridge / Host / PlatformBootstrap APIs / JNIGateway / ViewModels / Renderer / Input / Audio / Vendor.

### 4. Startup metrics (host)

| Métrica | Valor |
|---------|-------|
| Launch (Bridge→first frame) | ~285 ms |
| Shutdown / DestroyJavaVM | ~3005 ms (destroyTimedOut soft) |

### 5. Memory metrics (host)

| Métrica | Valor |
|---------|-------|
| RSS before | ~17.1 MiB |
| RSS after | ~108.4 MiB |
| Δ RSS | ~91.3 MiB |

### 6. Compatibility observations

- Alea (Form/Canvas, JPEG assets, MIDP-2.0) arranca y pinta el primer frame vía painter → LCD → Swift.
- `RunJarSupport` ya no depende de marcadores de fixture; fixtures con `START_APP_OK` siguen pasando.
- Cadencia: un frame en el smoke de first-paint (`verifyRepaint`); no hay stream continuo medido aquí.
- Device Zero: test preparado (`RealMIDletSmokeTests`); simulator XCTSkip.

### 7. Remaining blockers before arbitrary commercial MIDlets

1. **Device validation** en iPhone físico (Zero `libjvm.a`).
2. **Corpus** — un MIDlet MIT no prueba juegos comerciales (DRM, obfuscation, M3G, Siemens/Nokia APIs raras).
3. **Audio / media** — no ejercitados; muchos comerciales dependen de `Player`/MIDI/WAV.
4. **Input** — no smoke de teclado/touch con Alea en esta story.
5. **Continuous frames** — solo first paint; juegos con game loop necesitan stream estable.
6. **RMS / RecordStore / networking** — no validados.
7. **App size / classpath CI** — `java.home` ~119 MiB; compile classpath antes del build device.
8. **DestroyJavaVM latency** — ~3 s soft timeout en host.
9. **Simulator** — sin Zero linkeado.

---

## Cómo reproducir

```bash
./scripts/embedded-jvm/run_e6_us004_real_midlet_smoke.sh
# → artifacts/e6-us004-real-midlet-smoke/metrics.json
```

Device:

```bash
xcodebuild test -scheme JavaOne -destination 'platform=iOS,name=<device>' \
  -only-testing:JavaOneTests/RealMIDletSmokeTests
```
