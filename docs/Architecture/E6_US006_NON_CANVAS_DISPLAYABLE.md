# E6-US006 — Non-Canvas Displayable Compatibility

**Fecha:** 2026-08-05  
**Estado:** RESUELTO (host OpenJDK Mobile)  
**Depende de:** E6-US005  

## Veredicto

Los MIDlets cuyo primer `Displayable` no es `Canvas` (Alert / List / Form) fallaban en
`verifyRepaint` porque `RepaintSupport` exigía `Canvas.repaint()`.

Tras el fix genérico en CoreJ2 `RepaintSupport` (sin tocar Vendor / APIs públicas / renderer):

- **Ubertris, Tetris, Solitaire** alcanzan first frame.
- Suite E6-US005: **9/9 first frame (100%)** (antes ~55%).

---

## Investigation

| Pregunta | Hallazgo |
|----------|----------|
| 1. ¿`startApp()` ejecuta? | Sí (`Create MIDlet`; Ubertris imprime Alert) |
| 2. ¿Primer Displayable? | Ubertris → **Alert**; Tetris/Solitaire → **List/Form** |
| 3. ¿`Display.setCurrent` OK? | Sí (`verifyDisplay` → `OK:Alert` / List / Form) |
| 4. ¿Painter callback? | Parcial: `setCurrent` hace `flushGraphics` (incluso con `platformImage==null` en Alert, el NPE se traga y `painter.run()` puede dispararse una vez). `verifyRepaint` pedía Canvas y devolvía `NOT_CANVAS` / `NO_IMAGE`. |
| 5. ¿Dónde se corta? | `PlatformBootstrapLaunchSequence` → `verifyRepaint` → `RepaintSupport.requestRepaint` rechazaba non-Canvas; FreeJ2ME **Alert no asigna `platformImage`**. |

Cadena de fallo (antes):

```
runJar / startApp → setCurrent(Alert|List|Form)
  → verifyDisplay OK
  → verifyRepaint → NOT_CANVAS / NO_IMAGE
  → Host mapLaunchError → launchFailed
  → sin first frame
```

---

## 1. Root cause

Dos capas:

1. **CoreJ2:** `RepaintSupport` solo llamaba `Canvas.repaint()`; cualquier otro Displayable → `NOT_CANVAS`.
2. **FreeJ2ME (read-only):** `Alert` no crea `platformImage` (sí lo hacen Canvas/List/Form). Sin buffer no hay píxeles que flushear en first paint.

---

## 2. Files modified

| Path | Cambio |
|------|--------|
| `CoreJ2/.../Bootstrap/RepaintSupport.java` | Non-Canvas: `ensurePlatformImage` + `notifySetCurrent` + `render()` (reflect) + `flushGraphics` |
| `DefaultPlatformBootstrap.swift` | Comentarios + mapeo `NO_IMAGE` → `lcdNotPresent` |
| `PlatformBootstrap.swift` | Doc de `verifyRepaint` (Canvas u otro Displayable) |

**Sin cambios** a Bridge / Host / ViewModels / Vendor / renderer / APIs públicas.

---

## 3. Compatibility impact

| Ámbito | Antes (E6-US005) | Después (E6-US006) |
|--------|------------------|--------------------|
| First-frame suite (9) | 55.6% (5/9) | **100% (9/9)** |
| Ubertris / Tetris / Solitaire | ✗ | **✓** |
| Minefield (bonus) | ✗ → ya ✓ con flush List/Form | **✓** |

Post-frame issues (Sprite NPE, painter UnsatisfiedLinkError en game threads) **siguen** — fuera de alcance.

---

## 4. Updated compatibility matrix

| MIDlet | Launch | Display | First frame | Notes |
|--------|--------|---------|-------------|-------|
| Alea | ✓ | ✓ | ✓ | Canvas |
| Ubertris | ✓ | ✓ | ✓ | Alert-first (E6-US006) |
| Tetris | ✓ | ✓ | ✓ | List/Form-first (E6-US006) |
| Solitaire | ✓ | ✓ | ✓ | non-Canvas first (E6-US006) |
| Astroids | ✓ | ✓ | ✓ | post-frame ULE en game thread |
| Microracers | ✓ | ✓ | ✓ | post-frame Layer NPE |
| Gryzzles | ✓ | ✓ | ✓ | RMS |
| Minefield | ✓ | ✓ | ✓ | E6-US006 |
| DisplayProbe | ✓ | ✓ | ✓ | control |

Métricas: `artifacts/e6-us006-non-canvas-displayable/metrics.json`

---

## 5. Additional MIDlets now reaching first frame

Sí: **Ubertris, Tetris, Solitaire** (objetivo) y **Minefield** (mismo fix genérico).

---

## Fix (comportamiento)

`RepaintSupport.requestRepaint()`:

- `Canvas` → `repaint()` (igual que antes)
- Otro `Displayable` → asegurar `platformImage`, `notifySetCurrent()`, `Displayable.render()` (protegido, vía reflexión), `MobilePlatform.flushGraphics(...)` — mismo mecanismo que `Display.setCurrent`, sin pipeline alterno.

---

## Reproducir

```bash
./scripts/embedded-jvm/compile-freej2me-classpath.sh
./scripts/embedded-jvm/run_e6_us005_compatibility_smoke.sh
# o métricas US006: artifacts/e6-us006-non-canvas-displayable/metrics.json
```

> **E6-US007:** estabilidad post-frame (2–5 min) en `E6_US007_GAMEPLAY_STABILITY.md`.
