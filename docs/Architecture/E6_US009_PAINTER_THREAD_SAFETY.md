# E6-US009 — Painter Thread Safety

**Fecha:** 2026-08-05  
**Estado:** RESUELTO (host OpenJDK Mobile)  
**Depende de:** E6-US008  

## Veredicto

Los callbacks del painter son seguros desde **cualquier hilo Java** de FreeJ2ME.

`UnsatisfiedLinkError` en `PainterRunnable.run` (**Tetris / Astroids**) eliminado.

Sin cambios de arquitectura, Bridge / RuntimeHost / PlatformBootstrap / JNIGateway APIs públicas, UI, renderer ni Vendor/FreeJ2ME.

---

## 1. Root cause

### Cadena observada (E6-US007)

```
Game thread (Thread-N)
  → Canvas.repaint / GameCanvas.flushGraphics
  → MobilePlatform.repaint|flushGraphics
  → painter.run()   // PainterRunnable INSTANCE native
  → UnsatisfiedLinkError
```

### Por qué fallaba

1. **`PainterRunnable.run()` era `native`** y solo se enlazaba vía `RegisterNatives` en el hilo de bootstrap.
2. En `stopSession` / `invalidate`, `UnregisterNatives` **borra todos los natives de la clase**.
3. Los MIDlets (Tetris / Astroids) dejan **hilos de juego vivos** tras el stop; el siguiente `painter.run()` encuentra el método nativo **sin link** → `UnsatisfiedLinkError`.
4. El log parecía “durante gameplay” por buffering de stdout; la falla real es **lifetime del registro nativo vs hilos MIDlet**, no `JNIEnv` stale ni falta de `AttachCurrentThread` en el trampoline (el hilo Java ya está attached al entrar al native).

### Qué no era

| Hipótesis | Resultado |
|-----------|-----------|
| `JNIEnv` stale en game thread | Descartada — el fallo es link, no attach |
| Política `AttachCurrentThread` | No aplica al entry native desde Java |
| Callback lifetime en Swift | Secundario; el ULE ocurre antes del trampoline |
| Misuse local/global ref | No causa `UnsatisfiedLinkError` de método |

Bug adicional corregido: `UnregisterNatives` al quitar **un** native de una clase con varios (heartbeat + painter) dejaba huérfanos a los hermanos — ahora se **re-registran** los supervivientes.

---

## 2. Files modified

| Path | Cambio |
|------|--------|
| `Bootstrap/PainterRunnable.java` | `run()` Java → `NativeCallbackHost.onPainterPaint()`; swallow ULE/Throwable |
| `Bootstrap/NativeCallbackHost.java` | Nuevo `onPainterPaint()` static native |
| `Bootstrap/NoOpPainterRunnable.java` | Painter Java-only instalado antes de unregister |
| `DefaultPlatformBootstrap.swift` | Registra `onPainterPaint`; `setPainter(NoOp)` en teardown |
| `JNIGatewayNative.c` | `unregister_native` re-bind de natives hermanos |
| `PainterBootstrapTests.swift` | Conteos create/release con NoOp |
| `scripts/.../run_e6_us009_painter_thread_safety.sh` | Validación Astroids/Tetris/Gryzzles |

---

## 3. Thread model before / after

### Before

```
Bootstrap thread: RegisterNatives(PainterRunnable.run)
Any thread:       painter.run() → native OK
stopSession:      UnregisterNatives(PainterRunnable)
Game thread:      painter.run() → UnsatisfiedLinkError → thread death
```

### After

```
Bootstrap thread: RegisterNatives(NativeCallbackHost.onPainterPaint)
Any Java thread:  PainterRunnable.run() [Java]
                    → onPainterPaint() [native trampoline] → Swift notePaint / LCD
stopSession:      setPainter(NoOpPainterRunnable)   // absorbs late paints
                  then UnregisterNatives (+ rebind siblings)
Game thread:      NoOp.run() or swallowed ULE — host alive, no link errors
```

No polling. No serialización forzada de todos los paints a un solo hilo: el trampoline corre en el hilo Java llamante; `notePaint` ya serializa la extracción LCD con `isExtractingLCDFromPaint`.

---

## 4. Validation results

```bash
JAVAONE_SPIKE_GAMEPLAY_SECONDS=45 ./scripts/embedded-jvm/run_e6_us009_painter_thread_safety.sh
```

| MIDlet | Launch | Frames continue | Avg FPS | ULE | Shutdown |
|--------|--------|-----------------|---------|-----|----------|
| Astroids | ✓ | ✓ (995 frames / 45s) | ~21.2 | **none** | ✓ |
| Tetris | ✓ | ✓ (110 frames) | ~2.4 | **none** | ✓ |
| Gryzzles | ✓ | ✓ (21 frames) | ~0.46 | **none** | ✓ |

`unsatisfiedLinkError: false` — `artifacts/e6-us009-painter-thread-safety/summary.json`

---

## 5. Updated gameplay compatibility

| MIDlet | E6-US007 | E6-US009 |
|--------|----------|----------|
| Astroids | Playable; ULE en log | Playable; **sin ULE** |
| Tetris | Playable; ULE en log | Playable; **sin ULE** |
| Gryzzles | Playable | Playable; sin ULE |
| Ubertris | Alert stall | Sin cambio (fuera de alcance painter) |
| Alea | Input-driven | Sin cambio |

---

## 6. Remaining blockers after this fix

1. **Ubertris Alert / softkey dismiss** → Canvas (ahora seguro post E6-US008).
2. **Bridge `EmulatorSession` auto-sync** en `.stopped` (API Bridge intacta).
3. **Audio / RMS stress / networking / simulator** — fuera de esta story.
4. **Hilos MIDlet huérfanos** tras stop — absorbidos por NoOp; no se join-ean (requeriría Vendor o API destroyApp explícita).

---

## Relación

| Story | Foco |
|-------|------|
| E6-US007 | Detectó ULE painter |
| E6-US008 | Contuvo `System.exit` |
| **E6-US009** | Painter multi-hilo / lifetime de natives |
