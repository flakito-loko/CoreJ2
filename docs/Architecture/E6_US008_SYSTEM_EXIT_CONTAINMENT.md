# E6-US008 — Contain System.exit() inside Embedded JVM

**Fecha:** 2026-08-05  
**Estado:** RESUELTO (host OpenJDK Mobile)  
**Depende de:** E6-US007  

## Veredicto

`System.exit` / `Runtime.exit` (incl. FreeJ2ME `notifyDestroyed()`) **ya no mata el proceso host**.

La JVM embebida permanece viva y reutilizable; el Host cierra la sesión (`RuntimeEvent.stopped`) y un segundo launch en el mismo proceso tiene éxito.

Sin cambios de arquitectura, Bridge API, RuntimeHost API, PlatformBootstrap API pública, JNIGateway API pública, UI ni renderer. Vendor/FreeJ2ME **sin modificar**.

---

## 1. Root cause

Cadena observada en E6-US007:

```
softLeft → Command.EXIT → MIDlet.notifyDestroyed()
  → System.out.println("MIDlet sent Destroyed Notification")
  → System.exit(0)
  → Runtime.exit → Shutdown.exit
  → beforeHalt() → runHooks() → VM.shutdown() → halt0() → process exit
```

Rutas FreeJ2ME que llaman `System.exit` (Vendor, read-only):

| Origen | Uso |
|--------|-----|
| `javax.microedition.midlet.MIDlet.notifyDestroyed()` | Exit de MIDlet / softkey |
| `org.recompile.mobile.MIDletLoader` | Fallos construct / startApp |
| Frontends Anbu / FreeJ2ME / Config / Libretro | No en path embebido típico |

**Por qué no SecurityManager:** OpenJDK Mobile **28** rechaza `-Djava.security.manager=allow` y `setSecurityManager` → `UnsupportedOperationException`. El bootstrap Process (JDK 17 era) ya no aplica en embebido.

**Dónde interceptar:** borde **JNI / HotSpot** — re-registrar el native `java.lang.Shutdown.beforeHalt()` **antes** de `runHooks()` / `VM.shutdown()`, para que la VM no quede marcada como shut down.

---

## 2. Files modified

| Path | Cambio |
|------|--------|
| `EmbeddedJVM/Native/EmbeddedJVMNative.c` | Install `beforeHalt` containment en `CreateJavaVM`; Throw `SystemExitContainedError`; callback host |
| `EmbeddedJVM/Native/EmbeddedJVMNative.h` | API C de contención |
| `EmbeddedJVM/Native/EmbeddedJVMNativeStub.c` | Stubs |
| `EmbeddedJVM/Bootstrap/SystemExitContainedError.java` | Error CoreJ2 (no se traga con `catch (Exception)`) |
| `EmbeddedJVM/SystemExitContainmentBridge.swift` | Puente callback C → Swift |
| `FreeJ2MERuntimeHost.swift` | Wire callback → `stopSession` + `.stopped`; input tolerante post-exit |
| `DefaultPlatformBootstrap.swift` | `sendKeySync` trata exit contenido como no-fatal |
| `JavaOne.xcodeproj/project.pbxproj` | Añade `SystemExitContainmentBridge.swift` |
| `Spike/E6US008SystemExitContainment/` | Harness validación |
| `scripts/embedded-jvm/run_e6_us008_system_exit_containment.sh` | Runner |

---

## 3. Lifecycle before / after

### Before

```
notifyDestroyed → System.exit → Shutdown.exit → halt → **process dead**
```

### After

```
notifyDestroyed → System.exit → Shutdown.exit → beforeHalt (CoreJ2)
  → flag + host callback
  → throw SystemExitContainedError
  → (no runHooks / no VM.shutdown / no halt0)
  → Host async: stopSession + RuntimeEvent.stopped
  → JVM state .ready, bootstrap .shutdown → initialize() de nuevo
```

---

## 4. Shutdown behavior

| Evento | Comportamiento |
|--------|----------------|
| `System.exit` / `notifyDestroyed` | Contenido; sesión MIDlet/platform liberada; JVM viva |
| `PlatformBootstrap.stopSession` | Igual que antes (handles + gateway invalidate; JVM intacta) |
| `PlatformBootstrap.shutdown` | Destruye JVM (app teardown); `DestroyJavaVM` soft-timeout host sigue existiendo |
| `allow_process_exit=1` | Escape hatch nativo (tests); default contenido |

El callback nativo **no** reentra JNI de forma pesada; el Host agenda teardown en `MainActor`.

---

## 5. Validation results

```bash
./scripts/embedded-jvm/run_e6_us008_system_exit_containment.sh
```

Fixture: `Fixtures/MIDlets/tetris.jar` (Exit softkey).

| Check | Resultado |
|-------|-----------|
| SoftLeft Exit no mata la app | ✓ (`JAVAONE_E6US008: System.exit contained`) |
| Sesión termina limpia | ✓ `sessionEndedCleanly`, `stoppedEvents ≥ 1` |
| JVM ready | ✓ |
| Segundo launch | ✓ `framesLaunch2 = 3` |
| MobilePlatform recreado | ✓ (nuevo handle; sin leak de sesión anterior) |
| Sin recrear proceso | ✓ mismo `EmbeddedJVMManager` |

Métricas: `artifacts/e6-us008-system-exit-containment/metrics.json`

```json
{
  "hostSurvivedExit": true,
  "sessionEndedCleanly": true,
  "jvmRemainedReady": true,
  "secondLaunchSucceeded": true,
  "containedExitObserved": true,
  "platformObjectRecreated": true
}
```

---

## 6. Remaining blockers after this fix

1. **Painter `UnsatisfiedLinkError` en hilos de juego** — ~~fuera de alcance~~ **resuelto en E6-US009**.
2. **Bridge `EmulatorSession` state** — sin cambios de Bridge API; el Host emite `.stopped` pero Bridge no auto-transiciona la sesión (UI / caller debe `stop` o escuchar eventos en una story futura).
3. **Ubertris Alert / softkeys** — ahora es seguro usar softkeys sin matar el host; falta validar dismiss de licencia → Canvas.
4. **`DestroyJavaVM` soft-timeout** en teardown de proceso — preexistente.
5. **Audio** — no tocado.

---

## Relación con E6-US007

El P0 “`notifyDestroyed` → `System.exit` mata el host” queda **cerrado** en embebido. El harness de gameplay ya no necesita softkeys prohibidas por miedo a matar el proceso (sigue siendo útil evitar Exit accidental durante stress de 2–5 min).
