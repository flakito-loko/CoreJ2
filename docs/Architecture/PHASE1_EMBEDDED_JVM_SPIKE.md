# Fase 1 — Spike Embedded JVM (Hello World)

**Fecha:** 2026-08-04  
**Alcance:** `EmbeddedJVMManager` + JVM embebida + `HelloWorld` + destroy + métricas.  
**Fuera de alcance:** JNI Gateway, FreeJ2ME, PlatformBootstrap completo, RuntimeAdapter, Bridge, Host, UI, App Target.

---

## Resultado

| Criterio | Estado |
|----------|--------|
| Una sola JVM | Cumple (rechazo de segunda create a nivel nativo `-101`) |
| Hello World ejecutado | Cumple (`completed=true`, stdout `Hello World`) |
| Estado `Ready` luego `Destroyed` | Cumple |
| Sin FreeJ2ME / sin JAR producto | Cumple (classpath de directorio `.class`) |
| Sin JNI Gateway | Cumple (solo `JNI_CreateJavaVM` / invoke `main` / `DestroyJavaVM` en `EmbeddedJVMNative.c`) |
| OpenJDK Mobile enlazado | **No** — no hay artefacto Fase 0 staged; ejecución con **host OpenJDK** (Temurin 17) vía la misma API JNI |

---

## Cómo reproducir

```bash
export JAVA_HOME=/path/to/jdk   # requiere libjvm + javac
./scripts/embedded-jvm/run_phase1_hello_world.sh
```

Métricas: `artifacts/embedded-jvm-phase1/metrics.json`

---

## Métricas (corrida de referencia)

Valores de `artifacts/embedded-jvm-phase1/metrics.json` (host Temurin 17.0.20, macOS arm64):

| Métrica | Valor |
|---------|--------|
| Startup (`ensureStarted`) | ~22 ms |
| Hello World | ~1.2 ms |
| Destroy (watchdog) | ~3005 ms (`destroyTimedOut: true`) |
| RSS antes create | ~14.2 MB |
| RSS after Ready | ~37.2 MB (Δ create ~23.0 MB) |
| RSS after Hello | ~38.0 MB |
| `libjvm.dylib` size | ~16.9 MB |
| `HelloWorld.class` | 585 bytes |

---

## Problemas y resoluciones

1. **Sin `libjvm` OpenJDK Mobile** — Fase 0A solo dejó scripts; no hay `artifacts/openjdk-mobile/staged/current`.  
   **Resolución:** harness usa host OpenJDK con el mismo contrato nativo; backend etiquetado `host-jdk`.

2. **Swift 6 `Sendable` en tests de estado** — closures async fallaban al compilar.  
   **Resolución:** tests secuenciales sin pasar closures no-`Sendable`.

3. **`DestroyJavaVM` bloquea en HotSpot** (`Threads::destroy_vm` wait) — observado con `sample`.  
   **Resolución:** destroy en hilo auxiliar + timeout 3s; manager marca `Destroyed` + `destroyTimedOut`; harness hace `_exit` para no colgar el proceso.

---

## Riesgos abiertos

- Artefacto **OpenJDK Mobile Zero** aún no construido → spike iOS device/simulator pendiente.
- `DestroyJavaVM` no es fiable en host HotSpot; hay que revalidar en Mobile/Zero.
- Tamaño RSS ~23 MB solo para Hello World (sin FreeJ2ME).
- Harness **no** está en el App Target (correcto para Fase 1); enlace iOS es Fase posterior.
- Pin Boot JDK 24 + autoconf siguen faltando para cerrar Fase 0 operativa.

---

## ¿Hace falta cambiar la arquitectura?

**No.** El spike confirma el rol de `EmbeddedJVMManager` detrás del futuro backend iOS de PlatformBootstrap.  
No se tocaron Bridge / Host / Adapter / UI.  
El gap es de **artefacto JVM (Fase 0)**, no de capas.

---

## Layout

```
JavaOne/Features/Emulator/Runtime/EmbeddedJVM/   # manager + native (no App Target aún)
Spike/EmbeddedJVMPhase1/                         # mains del harness
scripts/embedded-jvm/run_phase1_hello_world.sh
artifacts/embedded-jvm-phase1/
```
