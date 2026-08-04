# Fase 1.5 — OpenJDK Mobile reemplaza Temurin (spike)

**Fecha:** 2026-08-04  
**Pregunta:** ¿OpenJDK Mobile puede reemplazar Temurin en nuestra arquitectura **sin modificar ninguna capa**?

## Veredicto

# VALIDADO

Misma arquitectura, mismo `EmbeddedJVMManager`, mismo `HelloWorld.java`, mismo harness de Fase 1. Solo cambió el **proveedor de JVM** (`libjvm` + `java.home` construidos desde `openjdk/mobile`).

---

## Qué se validó

| Requisito | Resultado |
|-----------|-----------|
| Construir OpenJDK Mobile (kit 0A + perfil macOS host) | OK — `macosx-aarch64-server-release` images |
| Enlazar solo en harness Fase 1 (no App Target) | OK |
| Crear JVM con OpenJDK Mobile | OK — `ensureStarted` → `ready` |
| Mismo `HelloWorld.java` | OK — `completed=true` |
| Métricas (startup, RSS, tamaño, destroy, estado) | OK |
| Comparación automática vs Temurin | OK — `artifacts/embedded-jvm-phase1_5/comparison.md` |
| `EmbeddedJVMManager` sin cambios | OK |
| Bridge / Host / Adapter / UI / Library / JNI Gateway | Intactos |

---

## Temurin vs OpenJDK Mobile

| Metric | Temurin | OpenJDK Mobile |
|--------|---------|----------------|
| Startup (ms) | 22.073 | 16.261 |
| RSS Δ create (bytes) | 23019520 | 24199168 |
| RSS after Ready (bytes) | 37240832 | 40370176 |
| libjvm size (bytes) | 16882064 | 20419088 |
| Destroy (ms) | 3005.118 | 0.322 |
| Destroy timed out | True | False |
| Final state | destroyed | destroyed |
| HelloWorld completed | True | True |

Fuente: `artifacts/embedded-jvm-phase1_5/comparison.md`

---

## Alcance del proveedor Mobile en esta fase

- Artefacto usado: imagen **macOS host** construida desde el árbol `openjdk/mobile` (paso que upstream exige antes de iOS).
- Staged en: `artifacts/openjdk-mobile/staged/current-macos/`
- **No** se validó aún el `libjvm.a` Zero de **iOS device** en este harness (no es linkable en macOS). Eso sigue siendo trabajo de cierre Fase 0 iOS / fases posteriores de device.

La pregunta de arquitectura (“¿puede sustituir Temurin sin cambiar capas?”) queda **VALIDADA** en el camino de integración del manager: el contrato JNI de create / HelloWorld / destroy funciona con el `libjvm` de OpenJDK Mobile sin tocar Bridge→Host→Adapter.

---

## Cómo reproducir

```bash
# 1) Build + stage OpenJDK Mobile (macOS host desde openjdk/mobile)
./scripts/openjdk-mobile/build-macos-host.sh

# 2) Comparar Temurin vs Mobile con el mismo harness / HelloWorld / Manager
./scripts/embedded-jvm/run_phase1_5_compare.sh
```

---

## Problemas encontrados (resumen)

1. README Mobile pedía JDK 24; el tip actual exige Boot JDK **26–28** → se usó Temurin 26.
2. Sin Homebrew: se construyeron GNU m4 + autoconf en cache local.
3. Xcode 26: faltaba Metal toolchain → `xcodebuild -downloadComponent MetalToolchain`.
4. Build largo interrumpido una vez → reanudación con `make images` exitosa.
5. Script de stage necesitaba paths absolutos al JDK image.

## Diferencias vs Temurin (observadas)

- Startup Mobile **más rápido** en esta corrida (~16 ms vs ~22 ms).
- RSS / `libjvm` Mobile **algo mayores**.
- Destroy Mobile **completó** (~0.3 ms); Temurin **hizo timeout** (3 s) en Fase 1.
- Versión Mobile: `28-internal` (adhoc build desde `openjdk/mobile`).

## Riesgos abiertos

- Imagen **iOS Zero static-libs** aún no ejercitada en proceso app.
- Tamaño de `libjvm` Mobile (~20 MB) + RSS ~24 MB Δ sin FreeJ2ME.
- Pin de commit / hashes debe congelarse para CI.
- Paridad destroy en device/simulator por confirmar.

## ¿Puede comenzar la Fase 2?

**Sí, condicionalmente:** el gate G1 (JVM embebida + Hello World con proveedor Mobile, sin cambiar capas) está **VALIDADO** en el harness.

Fase 2 (JNI Gateway) puede empezar sobre este manager **sin** cambiar Bridge/Host/Adapter.  
Queda pendiente en paralelo el artefacto iOS Zero para el target de producto, pero **no bloquea** el diseño del Gateway sobre el contrato ya probado.
