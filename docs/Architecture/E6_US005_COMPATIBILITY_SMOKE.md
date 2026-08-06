# E6-US005 — Compatibility Smoke Suite

**Fecha:** 2026-08-05  
**Estado:** VALIDADO (host OpenJDK Mobile, pipeline de producción)  
**Depende de:** E6-US004  

## Veredicto

Suite repetible de **9 MIDlets** (8 reales + 1 control) vía

`InstalledGame → Bridge → Host → PlatformBootstrap → EmbeddedJVM → FreeJ2ME`.

**Estimación de compatibilidad (first frame):** **55.6%** (5/9).  
Sin el control DisplayProbe: **50%** (4/8 reales).

Validación solo — **sin fixes** de producto en esta story.

> **Update E6-US006:** first-frame suite → **100% (9/9)** tras soportar Displayables no-Canvas en `RepaintSupport`. Ver `E6_US006_NON_CANVAS_DISPLAYABLE.md`.

---

## 1. MIDlets tested

| ID | JAR | License | APIs |
|----|-----|---------|------|
| Alea | Alea.jar | MIT | Canvas, Form, JPEG, PNG |
| Ubertris | Ubertris.jar | GPL | Timer, Alert-first |
| Tetris | tetris.jar | GPLv3 | Canvas, Form, List |
| Solitaire | solitaire.jar | GPLv3 | Canvas, PNG |
| Astroids | astroids.jar | GPLv3 | Canvas, Timers |
| Microracers | microracers.jar | GPLv3 | GameCanvas, Sprite, TiledLayer |
| Gryzzles | gryzzles.jar | GPLv3 | Canvas, RMS |
| Minefield | minefield.jar | GPLv3 | Canvas, RMS |
| DisplayProbe | DisplayProbe.jar | fixture (control) | Canvas, Display |

Orígenes: [`Fixtures/MIDlets/README.md`](../../Fixtures/MIDlets/README.md), manifiesto [`corpus.json`](../../Fixtures/MIDlets/corpus.json).

---

## 2. Compatibility matrix

| MIDlet | Launch | Display | First frame | Exceptions | Notes |
|--------|--------|---------|-------------|------------|-------|
| Alea | ✓ | ✓ | ✓ | — | Form + Canvas + JPEG |
| Ubertris | ✗ | ✗ | ✗ | launchFailed | Arranca con **Alert** (licencia), no Canvas → first-paint exige Canvas |
| Tetris | ✗ | ✗ | ✗ | launchFailed | `Create MIDlet` OK; Displayable inicial List/Form → no Canvas repaint |
| Solitaire | ✗ | ✗ | ✗ | launchFailed | Similar (menú / no Canvas en first paint) |
| Astroids | ✓ | ✓ | ✓ | UnsatisfiedLinkError en game thread post-frame | First paint OK; painter nativo falló luego en hilo de juego |
| Microracers | ✓ | ✓ | ✓ | NPE Layer.platformImage post-frame | GameCanvas+Sprite+TiledLayer first paint OK |
| Gryzzles | ✓ | ✓ | ✓ | — | RMS + Canvas first paint OK |
| Minefield | ✗ | ✗ | ✗ | launchFailed | Create MIDlet visto; sin Displayable Canvas en verifyRepaint |
| DisplayProbe | ✓ | ✓ | ✓ | — | Control fixture |

Fuente: [`artifacts/e6-us005-compatibility-smoke/metrics.json`](../../artifacts/e6-us005-compatibility-smoke/metrics.json).

---

## 3. Launch metrics (host)

| Métrica | Valor |
|---------|-------|
| JVM `ensureStarted` (suite) | ~14 ms |
| Alea launch→frame | ~251 ms |
| Astroids | ~7 ms |
| Microracers | ~20 ms |
| Gryzzles | ~11 ms |
| DisplayProbe | ~3 ms |
| Suite `DestroyJavaVM` | ~3010 ms (soft timeout) |

---

## 4. Memory metrics (host)

| Métrica | Valor |
|---------|-------|
| RSS suite before | ~18 MiB |
| RSS suite after | ~125 MiB |
| Δ RSS | ~107 MiB |

---

## 5. Common failures

1. **First paint requiere Canvas** — MIDlets que abren con `Alert` / `List` / `Form` fallan `verifyRepaint` (`NOT_CANVAS` / no painter path).
2. **Bytecode moderno** — classfiles > Java 8 rompen el adaptador ASM de FreeJ2ME (`Error Adapting Class` / `ClassFormatError`). Corpus GPL reempaquetado con `--release 8`.
3. **Painter desde hilos de juego** — `UnsatisfiedLinkError` en `PainterRunnable.run` cuando el flush ocurre fuera del hilo que registró el native (Astroids post-frame).
4. **Game API incompleta / frágil** — NPE en `Layer.render` cuando `image` es null (Microracers post-frame).
5. **launchFailed opaco** — Bridge mapea errores de bootstrap a `launchFailed` sin detalle de Displayable type.

---

## 6. Unsupported / weak APIs encountered

| API / patrón | Observación |
|--------------|-------------|
| Alert / List as `setCurrent` at start | First-paint path no cubre non-Canvas |
| GameCanvas + LayerManager + Sprite | First frame a veces OK; crashes en loop |
| TiledLayer | Carga; painting frágil |
| RMS | Gryzzles first paint OK (no stress test) |
| Sound / MIDI / Player | No ejercitado en este corpus |
| M3G / Nokia FullCanvas | No en corpus |
| Classfile > 52 (Java 8) | ASM FreeJ2ME falla |

---

## 7. Estimated compatibility percentage

| Scope | First-frame success |
|-------|---------------------|
| Full suite (9) | **55.6%** |
| Real MIDlets only (8) | **50.0%** |
| Launch+Display+Frame aligned | 5/9 |

Estimación = tasa de **primer frame LCD** en el pipeline de producción (métrica de producto más estricta).

---

## 8. Prioritized compatibility gaps

1. **Soportar first paint / Displayable no-Canvas** (Alert, List, Form) o avanzar automáticamente al Canvas del juego — bloquea menús/licencias (Ubertris, Tetris, …).
2. **Estabilidad del painter nativo multi-hilo** — UnsatisfiedLinkError cuando FreeJ2ME flushea desde threads de juego.
3. **Robustez lcdui.game (Sprite / TiledLayer / LayerManager)** — NPEs en paint loops comerciales.
4. **ASM / classfile range** — documentar y/o ampliar versiones soportadas; fallos silenciosos en JARs modernos.
5. **Diagnósticos de launch** — superficie `NOT_CANVAS` / display class en errores Bridge (hoy `launchFailed`).
6. **Audio / media / RMS stress / networking** — fuera de este corpus; necesarios para comerciales.
7. **Validación en device Zero** — suite host only en esta story.

---

## Files

### Created

| Path | Rol |
|------|-----|
| `Fixtures/MIDlets/corpus.json` | Manifiesto del corpus |
| `Fixtures/MIDlets/{tetris,solitaire,astroids,microracers,gryzzles,minefield,Ubertris,DisplayProbe}.jar` | Corpus |
| `Spike/E6US005CompatibilitySmokeSuite/main.swift` | Harness Bridge→Host |
| `scripts/embedded-jvm/run_e6_us005_compatibility_smoke.sh` | Ejecución |
| `scripts/embedded-jvm/package-compatibility-corpus.sh` | Reempaquetado GPL → Java 8 |
| `docs/Architecture/E6_US005_COMPATIBILITY_SMOKE.md` | Este doc |
| `artifacts/e6-us005-compatibility-smoke/metrics.json` | Resultados |

### Modified

| Path | Cambio |
|------|--------|
| `Fixtures/MIDlets/README.md` | Corpus E6-US005 |
| `scripts/embedded-jvm/README.md` | Instrucciones suite |

**Sin cambios** a Bridge / Host / PlatformBootstrap APIs / Vendor / renderer.

---

## Reproducir

```bash
# Opcional: reempaquetar games GPL (requiere fuentes rpmcruz)
# RPMCRUZ_SRC=/path/to/j2me-master ./scripts/embedded-jvm/package-compatibility-corpus.sh

./scripts/embedded-jvm/run_e6_us005_compatibility_smoke.sh
# → artifacts/e6-us005-compatibility-smoke/metrics.json
```
