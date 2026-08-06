# E6-S001 — Embedded OpenJDK Mobile Bring-up Spike

**Fecha:** 2026-08-04  
**Estado:** VALIDADO (host macOS)  
**Alcance:** Spike técnico — sin FreeJ2ME, sin cambios de producto / UI / Bridge / Host.

## Veredicto

`EmbeddedJVMManager` → `JNI_CreateJavaVM()` → **OpenJDK Mobile** → clase bootstrap CoreJ2 → `CallStatic*` → retorno a Swift **sin stubs C**.

El App Target de producción **sigue** enlazando `EmbeddedJVMNativeStub.c` / `JNIGatewayNativeStub.c`. Este spike solo cambia el path de linking en un harness aislado.

---

## Criterios de éxito

| Criterio | Resultado |
|----------|-----------|
| JVM creation (`ensureStarted` → `ready`) | ✓ |
| `FindClass` (`E6BringUp`) | ✓ |
| `GetStaticMethodID` | ✓ |
| `CallStaticVoidMethod` (`markReady`) | ✓ |
| Return value (`ping` → `0xE60001`) | ✓ |
| Exception handling (`failOnPurpose` → clear → re-ping) | ✓ |
| Shutdown (`DestroyJavaVM` → `destroyed`) | ✓ |
| Sin stubs en el harness | ✓ |
| Sin FreeJ2ME | ✓ |

---

## Flujo validado

```
EmbeddedJVMManager
        ↓
JNI_CreateJavaVM()   [EmbeddedJVMNative.c + libjvm.dylib OpenJDK Mobile]
        ↓
OpenJDK Mobile
        ↓
FindClass(org/corej2/embedded/spike/E6BringUp)
        ↓
GetStaticMethodID / CallStaticVoidMethod / CallStaticIntMethod
        ↓
Swift (DefaultJNIGateway + ProductionJNIGatewayNativeBackend)
```

---

## Deliverables

### 1. Files created

| Path | Rol |
|------|-----|
| `CoreJ2/.../Spike/E6BringUp.java` | Clase bootstrap CoreJ2 (`markReady`, `ping`, `failOnPurpose`) |
| `Spike/E6S001OpenJDKMobileBringUp/main.swift` | Harness Manager + JNIGateway + métricas |
| `scripts/embedded-jvm/run_e6_s001_openjdk_mobile_bringup.sh` | Build/link/run del spike |
| `artifacts/e6-s001-openjdk-mobile-bringup/metrics.json` | Métricas de la corrida |
| `docs/Architecture/E6_S001_OPENJDK_MOBILE_BRINGUP.md` | Este documento |

### 2. Files modified

| Path | Cambio |
|------|--------|
| `scripts/embedded-jvm/README.md` | Entrada E6-S001 |

**Sin cambios** a: Vendor/FreeJ2ME, EmulatorBridge, RuntimeHost, PlatformBootstrap API, JNIGateway API, ViewModels, SwiftUI, `project.pbxproj` (stubs de App Target intactos).

### 3. Linking strategy

**Spike (este harness):**

- Compila `EmbeddedJVMNative.c` + `JNIGatewayNative.c` (reales)
- Link dinámico: `-L…/lib/server -ljvm` + rpath a OpenJDK Mobile staged
- Classpath: directorio con `E6BringUp.class` (no JAR de producto)

**Producción (App Target, sin cambio):**

- Sigue compilando `EmbeddedJVMNativeStub.c` / `JNIGatewayNativeStub.c`
- DI ya apunta a `JNICreateJavaVMNativeRuntime` + `ProductionJNIGatewayNativeBackend`, pero el enlace C stub hace que `JNI_CreateJavaVM` real no exista en el binario de la app

### 4. Startup metrics (corrida host)

Fuente: `artifacts/e6-s001-openjdk-mobile-bringup/metrics.json`

| Métrica | Valor |
|---------|-------|
| Platform | `macos-host` |
| Startup | **~15.9 ms** |
| RSS before | ~14.5 MiB |
| RSS after create | ~38.6 MiB |
| Δ RSS create | **~24.0 MiB** |
| `libjvm.dylib` | ~19.5 MiB |

### 5. Shutdown metrics

| Métrica | Valor |
|---------|-------|
| Destroy | **~0.26 ms** |
| Destroy timed out | `false` |
| Final state | `destroyed` |

### 6. Device vs simulator

| Entorno | Estado |
|---------|--------|
| **macOS host harness** | VALIDADO (este spike) |
| **iOS Simulator** | No ejercitado — falta `libjvm` linkable para sim + target de spike iOS |
| **iOS Device** | Bloqueado — falta artefacto Zero `libjvm.a` staged + wiring Xcode (fuera de este spike) |

### 7. Remaining blockers before permanent stub replacement / FreeJ2ME

1. **Artefacto iOS Zero** — construir y stagear `libjvm.a` (device; sim si aplica).
2. **Swap de linking en Xcode** — sustituir `*Stub.c` por `EmbeddedJVMNative.c` / `JNIGatewayNative.c` + search paths / frameworks de OpenJDK Mobile **solo** cuando el artefacto iOS exista.
3. **Empaquetado de runtime** — `java.home`, modules, classpath de producto embebidos en el bundle (sandbox, tamaño, codesign).
4. **Ciclo de vida en app** — destroy vs JVM persistente (E4) ya diseñado; validar destroy/recreate con Mobile real en proceso iOS.
5. **FreeJ2ME** — explícitamente **fuera** de E6-S001; requiere classpath JAR + bootstrap FreeJ2ME sobre JVM real (siguiente épica), no solo `E6BringUp`.

---

## Cómo reproducir

```bash
# Requiere stage OpenJDK Mobile macOS (si falta):
./scripts/openjdk-mobile/build-macos-host.sh

./scripts/embedded-jvm/run_e6_s001_openjdk_mobile_bringup.sh
```

---

## Notas

- Reutiliza `EmbeddedJVMManager` y `DefaultJNIGateway` — sin segundo manager ni JNI duplicado.
- `invokeHelloWorldMain` no es el path primario de este spike; se ejercitan las APIs genéricas `resolveClass` / `resolveMethod` / `callStatic`.
- Audio, renderer e input no se tocan.
