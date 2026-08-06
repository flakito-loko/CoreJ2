# E6-US007 — Gameplay Stability Validation

**Fecha:** 2026-08-05  
**Estado:** VALIDADO (host OpenJDK Mobile, pipeline de producción)  
**Depende de:** E6-US006  

## Veredicto

Tras first frame, el corpus de gameplay (5 MIDlets × **120 s**) permanece vivo en el pipeline

`InstalledGame → Bridge → Host → PlatformBootstrap → EmbeddedJVM → FreeJ2ME`.

| Métrica | Resultado |
|---------|-----------|
| Launch | **5/5** |
| Sesión ≥2 min (sin crash de host) | **5/5** |
| Frames post-launch | **4/5** |
| Input Bridge (key ± pointer) | **5/5** |
| Playable continuo (frames + no freeze de menú) | **4/5** |

Único fallo de continuidad: **Ubertris** se queda en Alert de licencia (sin frames nuevos; freeze >45 s).

Validación solo — **sin fixes** de producto.

---

## Método

- Harness: `Spike/E6US007GameplayStability/` + `scripts/embedded-jvm/run_e6_us007_gameplay_stability.sh`
- Corpus: `Fixtures/MIDlets/gameplay-corpus.json` (subconjunto de E6-US005)
- Aislamiento: **un proceso por MIDlet** (FreeJ2ME `notifyDestroyed()` → `System.exit(0)` tumba el host)
- Estímulo: teclas `fire` / D-pad / numpad (sin softkeys; softLeft mapea a `Command.EXIT` en Tetris y mata el proceso)
- Tick: 2 s · freeze: 45 s sin progreso de frames (solo si `expectsGameLoop`)
- Métricas: `artifacts/e6-us007-gameplay-stability/metrics.json`

```bash
JAVAONE_SPIKE_GAMEPLAY_SECONDS=120 ./scripts/embedded-jvm/run_e6_us007_gameplay_stability.sh
```

---

## 1. Updated compatibility matrix (gameplay)

| MIDlet | Launch | Gameplay | Frames continue | Input works | Exceptions | Notes |
|--------|--------|----------|-----------------|-------------|------------|-------|
| Alea | ✓ | ✓ | ✓ | ✓ (key+ptr) | — | Input-driven; ~0.04 FPS medio |
| Ubertris | ✓ | ✗ | ✗ | ✓ (key Bridge) | — | Alert licencia; stall >45 s; 0 frames post-launch |
| Tetris | ✓ | ✓ | ✓ | ✓ | `UnsatisfiedLinkError` PainterRunnable (hilo juego) | ~3.0 FPS; menú→Canvas vía fire |
| Gryzzles | ✓ | ✓ | ✓ | ✓ (key+ptr) | — | Input-driven; ~0.46 FPS |
| Astroids | ✓ | ✓ | ✓ | ✓ | `UnsatisfiedLinkError` PainterRunnable (hilo juego) | ~21.8 FPS; loop fuerte |

First-frame (E6-US006) sigue en **9/9** en la suite completa; esta story mide estabilidad **después** del primer frame.

---

## 2. Stability metrics

| MIDlet | Runtime (s) | Crashed | Froze | Deadlock | Shutdown OK | Process exit |
|--------|-------------|---------|-------|----------|-------------|--------------|
| Alea | 121.4 | no | no | no | ✓ | 0 |
| Ubertris | 120.8 | no | **sí** (>45 s) | no | ✓ | 0 |
| Tetris | 121.8 | no | no | no | ✓ | 0 |
| Gryzzles | 120.8 | no | no | no | ✓ | 0 |
| Astroids | 120.8 | no | no | no | ✓ | 0 |

`DestroyJavaVM` soft-timeout (~3000 ms) en todos los procesos aislados (esperado en host macOS).

---

## 3. Runtime metrics

| MIDlet | Launch (ms) | Frames @launch | Frames during | Repaints during | Avg FPS | Max frame gap (s) |
|--------|-------------|----------------|---------------|-----------------|---------|-------------------|
| Alea | 327 | 1 | 5 | 5 | 0.04 | 108 |
| Ubertris | 287 | 2 | **0** | **0** | 0 | 119 |
| Tetris | 289 | 3 | 361 | 364 | 2.96 | 8.6 |
| Gryzzles | 115 | 1 | 56 | 56 | 0.46 | 2.2 |
| Astroids | 100 | 1 | 2632 | 2632 | 21.8 | 2.2 |

JVM `ensureStarted` por proceso: ~15–21 ms.

Cadencia: Alea/Gryzzles dependen de input (repaint por tecla/puntero ≈ 1 frame/tick). Astroids tiene game loop nativo. Tetris genera frames tras salir del List.

---

## 4. Memory metrics over time

RSS muestreado cada tick (~2 s) durante la ventana de gameplay:

| MIDlet | RSS start | RSS end | Δ RSS | Muestras |
|--------|-----------|---------|-------|----------|
| Alea | 110.2 MiB | 112.3 MiB | +2.1 MiB | 56 |
| Ubertris | 107.8 MiB | 108.1 MiB | +0.3 MiB | 57 |
| Tetris | 108.3 MiB | 118.8 MiB | +10.5 MiB | 57 |
| Gryzzles | 71.2 MiB | 74.4 MiB | +3.2 MiB | 56 |
| Astroids | 71.1 MiB | 79.4 MiB | +8.2 MiB | 57 |

Sin fuga explosiva en 2 min. Tetris/Astroids crecen más (buffers/loop). Series completas en `rssSamples` de cada `per-midlet/*.json`.

---

## 5. Common runtime failures

1. **Alert / menú sin avance** — Ubertris permanece en Alert de licencia; fire/D-pad no la descartan; sin softkeys el harness no puede aceptar la licencia sin riesgo de `Command.EXIT`.
2. **`notifyDestroyed()` → `System.exit(0)`** — FreeJ2ME (`javax.microedition.midlet.MIDlet`) mata el **proceso host**. SoftLeft en Tetris (Exit) abortó corridas tempranas. El suite usa aislamiento por proceso.
3. **`UnsatisfiedLinkError` en `PainterRunnable.run`** — en hilos de juego (Tetris, Astroids). El painter nativo no es válido fuera del hilo que lo registró. First frame y muchos frames posteriores siguen llegando por otros caminos; el error ensucia el log y puede perder paints.
4. **FPS bajo en MIDlets input-driven** — Alea/Gryzzles no tienen loop autónomo; cadencia ≈ estímulo del harness.
5. **`DestroyJavaVM` soft timeout** — shutdown de JVM embebida ~3 s timeout en todos los runs (no bloquea gameplay).

---

## 6. APIs / paths that still fail during gameplay

| API / patrón | Durante gameplay |
|--------------|------------------|
| Soft key → `Command.EXIT` → `notifyDestroyed` | Mata el proceso (FreeJ2ME `System.exit(0)`) |
| Alert dismiss sin softkey fiable | Ubertris no avanza a Canvas |
| Painter nativo desde game thread | `UnsatisfiedLinkError` (Tetris, Astroids) |
| Game loop + flush multi-thread | Frames OK a veces; excepciones Java en paralelo |
| Sound / MIDI / RMS stress / M3G | No ejercitados en esta story |

---

## 7. Prioritized compatibility work (post-validation)

1. **P0 — `notifyDestroyed` no debe `System.exit` el host**  
   ~~Sustituir por señal al Bridge/Host (sesión `.stopped`) sin matar el proceso.~~  
   **Hecho en E6-US008** (`E6_US008_SYSTEM_EXIT_CONTAINMENT.md`).

2. **P0 — Painter JNI thread-safe / attached**  
   ~~Eliminar `UnsatisfiedLinkError` cuando el game thread llama `PainterRunnable`.~~  
   **Hecho en E6-US009** (`E6_US009_PAINTER_THREAD_SAFETY.md`).

3. **P1 — Softkey → Command mapping verificable**  
   Permitir dismiss de Alert/licencia y selección de List sin disparar EXIT accidental; tests de mapeo NOKIA_SOFT1/2.

4. **P1 — Ubertris (y Alert-first) path a Canvas**  
   Tras dismiss de licencia, confirmar game loop + frames continuos ≥2 min.

5. **P2 — Cadencia / vsync host**  
   Alea/Gryzzles: decidir si el host debe solicitar repaint periódico o solo input-driven.

6. **P2 — Métricas in-app**  
   Exponer FPS / paint count / exception counters al UI de diagnóstico (hoy solo spike).

---

## Artefactos

| Path | Contenido |
|------|-----------|
| `Fixtures/MIDlets/gameplay-corpus.json` | Corpus E6-US007 |
| `Spike/E6US007GameplayStability/main.swift` | Harness Bridge→Host |
| `scripts/embedded-jvm/run_e6_us007_gameplay_stability.sh` | Runner aislado |
| `artifacts/e6-us007-gameplay-stability/metrics.json` | Agregado |
| `artifacts/e6-us007-gameplay-stability/per-midlet/*.json` | Por MIDlet + `rssSamples` |
| `artifacts/e6-us007-gameplay-stability/suite.log` | Log completo |

---

## Relación con stories previas

| Story | Foco | Resultado |
|-------|------|-----------|
| E6-US005 | First-frame suite | 55.6% → baseline |
| E6-US006 | Non-Canvas Displayable | First-frame **9/9** |
| **E6-US007** | Estabilidad 2–5 min | **4/5** playable continuo; P0 exit/painter |
