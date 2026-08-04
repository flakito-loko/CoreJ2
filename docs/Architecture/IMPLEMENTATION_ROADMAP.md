# Implementation Roadmap — Embedded JVM Runtime

**Estado:** Plan de ejecución oficial  
**Versión:** 1.0  
**Fecha:** 2026-08-04  

**Arquitectura de referencia (no modificar):**

- `docs/Architecture/JVM_FEASIBILITY_STUDY.md`
- `docs/Architecture/EMBEDDED_JVM_ARCHITECTURE.md`
- `docs/Architecture/EMBEDDED_JVM_MANAGER.md`

**Naturaleza**

Este documento traduce la arquitectura oficial en un **plan de implementación por fases**. No redefine capas, no inventa APIs de producto y no contiene código. Cada fase es pequeña, verificable y con criterios de éxito / rollback explícitos.

**Invariante de ejecución**

```
Bridge → Host → Adapter → PlatformBootstrap
                              └─ (iOS) EmbeddedJVMManager + JNI Gateway + Embedded JVM
```

macOS permanece en Process persistente. Este roadmap cubre el **camino iOS embebido** y la integración gradual sin romper la pila existente.

---

# Fase 0 — Preparación

## Objetivo

Dejar listo el entorno de ingeniería para construir y enlazar OpenJDK Mobile (u artefacto estático equivalente aprobado por la arquitectura) sin tocar aún la lógica de emulación.

## Prerrequisitos

- Arquitectura oficial leída y aceptada por el equipo.
- Acceso a macOS + Xcode alineado al proyecto JavaOne.
- Decisión de no alterar Bridge / Host / Adapter públicos.

## Entregables / trabajo

- **Dependencias de host:** Xcode, iOS SDK, autoconf, boot JDK según docs OpenJDK Mobile.
- **Repositorios:** pin o mirror documentado de `openjdk/mobile` (y soporte libffi/cups según estudio de viabilidad).
- **Herramientas:** scripts de build de JDK **fuera** del target app (CI o máquina de release); cache de artefactos.
- **OpenJDK Mobile:** reproducir build `static-libs-image` (Zero / aarch64 device; política simulador documentada).
- **Artefactos necesarios:** `libjvm.a` (y libs estáticas asociadas), layout de resources JDK si aplica, inventario de tamaño aproximado.
- Convención de directorios internos Runtime (solo documentación de paths; sin wiring DI iOS aún).

## Archivos afectados (esperados)

- Ningún Swift de producto obligatorio en esta fase.
- Posibles: scripts bajo `scripts/`, docs de build internos, artefactos binarios versionados o CI cache (fuera de Vendor FreeJ2ME).

## Riesgos

- Build OpenJDK Mobile frágil o no reproducible.
- Tamaño de artefacto incompatible con objetivos de app.
- Divergencia simulador vs device.

## Criterios de éxito

- [ ] Se obtiene de forma repetible una imagen estática Zero para el target iOS acordado.
- [ ] Queda documentado cómo regenerar el artefacto y su hash/versión.
- [ ] Ningún cambio a Bridge / Host / Adapter / Library.

## Criterios de rollback

- Descartar el pin de OpenJDK Mobile; volver a “solo macOS Process” sin dejar restos enlazados en el app target.

## Tiempo estimado

**1–3 semanas** (según experiencia previa con builds OpenJDK).

## Dependencias

- Ninguna fase posterior de runtime embebido.
- Bloquea Fases 1+.

## Resultado esperado

Kit de build + artefacto JVM versionado listo para un spike de proceso, sin FreeJ2ME y sin UI.

---

# Fase 1 — Spike JVM

## Objetivo

Crear una **JVM embebida en proceso iOS** y ejecutar únicamente un **Hello World Java**.  
**No** cargar FreeJ2ME. **No** Contract C. **No** UI.

## Prerrequisitos

- Fase 0 completada (artefacto `libjvm` disponible).

## Entregables

- Target o harness mínimo que enlace el artefacto.
- Arranque de VM vía `EmbeddedJVMManager` (rol arquitectónico; implementación mínima del spike).
- Clase Java trivial ejecutada hasta completar (impresión o retorno de estado).
- Registro de métricas: cold start, RSS aproximado.

## Archivos afectados (esperados)

- Área Runtime / bootstrap iOS de spike (aislado).
- Posible target de prueba o flag de compilación **sin** DI de producción.
- Clase Java hello (JavaOne-owned, no Vendor).

## Riesgos

- Fallo `JNI_CreateJavaVM` / imagen incompleta.
- Crash al link en device.
- MainActor bloqueado durante create (deuda a corregir antes de producción).

## Criterios de éxito

- [ ] Una sola JVM arranca en device o simulador acordado.
- [ ] Hello World Java completa sin crash.
- [ ] Estado del manager alcanza Ready (según contrato EmbeddedJVMManager).
- [ ] No se carga FreeJ2ME.
- [ ] Bridge/Host/Adapter públicos intactos.

## Criterios de fracaso

- Imposible crear VM tras intentos documentados con el artefacto de Fase 0.
- Requisito de JIT / memoria W^X incompatible con App Store.
- Segunda JVM necesaria para un hello world.

## Criterios de rollback

- Eliminar harness de spike; app sigue solo con camino macOS / `runtimeUnavailable` en iOS.

## Tiempo estimado

**1–2 semanas.**

## Dependencias

- Fase 0.
- Bloquea Fases 2+.

---

# Fase 2 — Spike JNI

## Objetivo

Comunicación **Swift ↔ Java** vía JNI Gateway, sin FreeJ2ME. Solo llamadas simples (p. ej. método estático que suma / devuelve string).

## Prerrequisitos

- Fase 1 en éxito (JVM Ready).

## Entregables

- JNI Gateway mínimo: attach, FindClass/Call, liberación de local refs.
- Llamada de ida (Swift/bootstrap → Java) y de vuelta simple (callback nativo opcional o return value).
- Verificación de no compartir `JNIEnv` entre hilos (test de disciplina).

## Archivos afectados (esperados)

- Implementación interna Gateway + manager.
- Tests de spike aislados.
- Sin cambios Library / Views / Bridge API.

## Riesgos

- Local refs filtradas.
- Deadlock con monitor del manager.
- Callbacks desde hilos Java mal attached.

## Criterios de éxito

- [ ] Round-trip documentado Swift→Java→Swift (o return).
- [ ] Gateway inválido tras Destroyed.
- [ ] Sin exposición de JNI a Views/Bridge.
- [ ] Thread rules del EmbeddedJVMManager respetadas en el spike.

## Criterios de fracaso

- Imposible invocar Java de forma estable.
- Filtrado inevitable de `JNIEnv` a capas de producto.

## Criterios de rollback

- Revertir Gateway; conservar Fase 1 solo como evidencia de VM.

## Tiempo estimado

**1 semana.**

## Dependencias

- Fase 1.
- Bloquea Fases 3+.

---

# Fase 3 — Carga de FreeJ2ME

## Objetivo

Conseguir que el runtime Java **cargue / resuelva** FreeJ2ME (classpath/modules Vendor) correctamente.  
**Sin** ejecutar MIDlets. **Sin** `runJar`.

## Prerrequisitos

- Fases 1–2 en éxito.

## Entregables

- LoadingFreeJ2ME → Idle en el manager.
- Verificación de que clases clave Vendor son resolubles (p. ej. existencia de `MobilePlatform` vía reflexión controlada en Gateway/bootstrap — sin Contract C completo).
- Política de `dataPath` sandbox preparada (puede quedar sin RMS aún).

## Archivos afectados (esperados)

- Backend bootstrap iOS (classpath).
- Empaquetado de classes/jar FreeJ2ME en el bundle app (sin modificar fuentes Vendor).
- Tests de resolución de clases.

## Riesgos

- AWT / dependencias SE faltantes al cargar clases.
- Tamaño de bundle.
- Classpath incorrecto en device.

## Criterios de éxito

- [ ] Estado Idle con FreeJ2ME residente.
- [ ] Clases Vendor críticas resolubles.
- [ ] Ningún MIDlet arrancado.
- [ ] Vendor sources no modificados.

## Criterios de fracaso

- FreeJ2ME no carga por lagunas SE/AWT insalvables sin romper arquitectura (gate hacia plan B allowlisted — decisión Go/No-Go).

## Criterios de rollback

- Quitar classpath Vendor del bundle iOS; volver a spike JNI-only.

## Tiempo estimado

**1–2 semanas.**

## Dependencias

- Fase 2.
- Bloquea Fases 4+.

---

# Fase 4 — Carga de un archivo JAR

## Objetivo

Validar que el runtime puede **localizar** un JAR instalado (ruta `file://` / sandbox Library) desde el borde bootstrap.  
**Sin** ejecutar el MIDlet (`runJar` / `startApp` no requeridos).  
Puede incluir validación de existencia/legibilidad alineada a Bridge, y opcionalmente `loadJar` **sin** run si el spike lo permite de forma segura.

## Prerrequisitos

- Fase 3 en éxito.
- Pipeline Library/Import capaz de producir un JAR en sandbox (ya existente en producto).

## Entregables

- Prueba con un `InstalledGame` / JAR de fixture en el container.
- Confirmación de path visible para el runtime embebido.
- Error tipado si el archivo falta (sin crash nativo).

## Archivos afectados (esperados)

- Bootstrap iOS (resolución de path).
- Tests con fixture JAR.
- Sin cambios de API Bridge.

## Riesgos

- Sandbox / security scoped URLs.
- Paths distintos a macOS Process daemon.

## Criterios de éxito

- [ ] JAR instalado localizable desde el runtime embebido.
- [ ] Ausencia de archivo → fallo controlado.
- [ ] Sin `startApp`.

## Criterios de rollback

- Limitar iOS a “FreeJ2ME cargado” sin acceso a JARs de usuario hasta replantear paths.

## Tiempo estimado

**3–5 días.**

## Dependencias

- Fase 3; Library/Import existentes.
- Bloquea Fase 5.

---

# Fase 5 — Primer MIDlet

## Objetivo

Ejecutar un **MIDlet mínimo** (p. ej. ProbeMIDlet / equivalente JavaOne-owned) hasta `startApp`.  
**Sin** render UI. **Sin** audio. Frames pueden ignorarse.

## Prerrequisitos

- Fase 4 en éxito.
- `defineClass` / ASM viables (hipótesis del estudio).

## Entregables

- Contract C parcial: platform + load + run vía bootstrap embebido.
- Evidencia de `startApp` (señal ya usada en host macOS).
- Stop de sesión → Idle **sin** destruir JVM.

## Archivos afectados (esperados)

- Bootstrap embebido + Gateway.
- Adapter ya orquesta Contract C (wiring DI iOS opcional aún detrás de flag).
- Tests de sesión / unicidad JVM.

## Riesgos

- Fallo ASM/`defineClass`.
- `System.exit` mata el proceso.
- Leak de sesión al Idle.

## Criterios de éxito

- [ ] Probe MIDlet alcanza startApp.
- [ ] JVM launch count = 1 tras stop y segundo launch (si se prueba doble sesión).
- [ ] Sin SwiftUI render.
- [ ] Sin audio.

## Criterios de fracaso

- Imposible `defineClass` / loader.
- Exit inevitable del proceso app.

## Criterios de rollback

- Feature flag off; iOS vuelve a `runtimeUnavailable`; macOS intacto.

## Tiempo estimado

**1–2 semanas.**

## Dependencias

- Fase 4.
- Bloquea Fase 6.

---

# Fase 6 — Primer Frame

## Objetivo

Recibir al menos un **frame** desde FreeJ2ME (painter / captura) hasta `EmulatorFrame` / evento de runtime.  
**Sin** mostrarlo en SwiftUI (validación de pipeline solamente; puede assertarse en test).

## Prerrequisitos

- Fase 5 en éxito.

## Entregables

- Painter registrado; copia ARGB; `frameHandler` → Adapter `onFrameCaptured` → Host `.frameAvailable`.
- Test que cuenta ≥ 1 frame sin UI.

## Archivos afectados (esperados)

- Gateway painter callback.
- Bootstrap `frameHandler`.
- Tests Host/Adapter existentes como modelo.

## Riesgos

- AWT/`getLCD` no disponible.
- Callbacks en hilo Java sin attach.
- Frames tras Shutdown.

## Criterios de éxito

- [ ] ≥ 1 `EmulatorFrame` / `.frameAvailable` observado en test.
- [ ] Copia de píxeles (no buffer compartido mutable).
- [ ] Renderer de producto no obligatorio en esta fase.

## Criterios de rollback

- Mantener MIDlet sin frames; documentar bloqueo AWT (plan B gráfico allowlisted según arquitectura).

## Tiempo estimado

**1 semana.**

## Dependencias

- Fase 5.
- Bloquea Fase 7.

---

# Fase 7 — Render

## Objetivo

Mostrar el primer frame en **SwiftUI** usando el Renderer existente (`EmulatorViewModel` / `EmulatorView` / convertidor CGImage), sin nuevas APIs de Bridge.

## Prerrequisitos

- Fase 6 en éxito.
- Flujo Library → EmulatorView ya existente.

## Entregables

- DI iOS selecciona bootstrap embebido (flag).
- Launch desde Library muestra LCD con imagen real.
- Stop/onDisappear limpia sesión; JVM permanece.

## Archivos afectados (esperados)

- `AppDependencyContainer` (solo elección de bootstrap).
- Posible flag de feature.
- **No** cambios de contrato Bridge/Host/Adapter públicos.

## Riesgos

- MainActor / jank al primer frame.
- Regresiones macOS al tocar DI.

## Criterios de éxito

- [ ] Frame visible en EmulatorView en device/simulador acordado.
- [ ] Pipeline sigue Bridge → Host → Adapter.
- [ ] Tests de Renderer previos siguen pasando.

## Criterios de rollback

- Revertir DI a bootstrap que reporta `runtimeUnavailable` en iOS.

## Tiempo estimado

**3–5 días.**

## Dependencias

- Fase 6; UI Library/Emulator existente.
- Bloquea Fases 8–10 de producto jugable.

---

# Fase 8 — Input

## Objetivo

Enviar teclas / pointer normalizados hasta FreeJ2ME (`key*` / `pointer*`) por la cadena Bridge → Adapter → Bootstrap → JNI.

## Prerrequisitos

- Fase 7 en éxito (o al menos Fase 5+6 si se prueba input headless).
- Contrato de input de producto alineado a `FREEJ2ME_RUNTIME_CONTRACT` (sin inventar capas nuevas).

## Entregables

- Puente de input en Adapter/Bootstrap/Gateway.
- Teclado virtual o controles mínimos en UI **solo** hablando con Bridge/ViewModel.
- Test de que una tecla llega al Display/Canvas (o probe instrumentado).

## Archivos afectados (esperados)

- Bridge (si la API de input del contrato aún no estaba cableada — extensión de contrato **ya prevista**, no arquitectura nueva).
- Adapter, Bootstrap, Gateway.
- Vista de keypad (UI).

## Riesgos

- Coordenadas mal escaladas.
- Atajos UI→JNI (anti-pattern).

## Criterios de éxito

- [ ] Evento de input observable en FreeJ2ME / probe.
- [ ] Ningún JNI desde Views.
- [ ] Pause/Stop no dejan teclas colgadas de forma indefinida.

## Criterios de rollback

- Deshabilitar keypad; emulación solo visual.

## Tiempo estimado

**1–2 semanas.**

## Dependencias

- Fase 7 (recomendado); contrato input.
- No bloquea Audio/RMS de forma dura, pero sí “jugable”.

---

# Fase 9 — Audio

## Objetivo

Definir e integrar el **borde de responsabilidades** de audio (FreeJ2ME → bootstrap/native), con mute en pause/stop. Implementación nativa mínima aceptable (stub silencioso → backend real).

## Prerrequisitos

- Fase 5+ (runtime con MIDlet).
- Arquitectura de audio del plano embebido respetada.

## Entregables

- Punto único de puente en Bootstrap/Gateway.
- Silence on pause/stop/session end.
- Criterios de no acoplar Views al motor de audio Java.

## Archivos afectados (esperados)

- Bootstrap / Gateway / posible backend AVAudio*.
- Sin Library.

## Riesgos

- Java Sound ausente en mobile JDK.
- Latencia / glitches.
- Threads audio vs JNI.

## Criterios de éxito

- [ ] Política de mute de sesión verificada.
- [ ] Ningún audio desde Views vía JNI.
- [ ] Fallo de audio no tumba la JVM.

## Criterios de rollback

- Audio stub/off; resto del emulador intacto.

## Tiempo estimado

**1–3 semanas.**

## Dependencias

- Fase 5+.
- Paralelo posible con Fase 8/10 tras Fase 7.

---

# Fase 10 — RMS

## Objetivo

Configurar `MobilePlatform.dataPath` (o equivalente Contract C) al **sandbox** iOS y verificar persistencia Record Store entre Idle→Running→Stop→Running del mismo juego.

## Prerrequisitos

- Fase 5+.
- ADR de sandbox del plano embebido.

## Entregables

- Path por app / política por juego documentada.
- Test de escritura/lectura RMS con MIDlet de fixture.
- Sin que Library almacene RMS.

## Archivos afectados (esperados)

- Bootstrap embebido (dataPath).
- Fixtures de prueba.
- Posible limpieza en stopSession.

## Riesgos

- Paths incorrectos / pérdida de datos.
- Contaminación entre juegos.

## Criterios de éxito

- [ ] RMS sobrevive stop/relaunch de sesión en misma JVM.
- [ ] Datos bajo sandbox.
- [ ] Bridge no interpreta records.

## Criterios de rollback

- RMS deshabilitado / efímero; documentar limitación.

## Tiempo estimado

**3–7 días.**

## Dependencias

- Fase 5+.
- Paralelo con 8/9 tras 7.

---

# Fase 11 — Optimización

## Objetivo

Cumplir objetivos de performance del EmbeddedJVMManager / arquitectura: off MainActor, menos JNI por frame, telemetría, estabilidad multi-sesión.

## Prerrequisitos

- Fases 7+ (y preferible 8).

## Entregables

- Presupuesto de frame time medido en device.
- Startup JVM / launch latency dashboards o logs.
- Eliminación de bloqueos UI conocidos.
- Pass del checklist EmbeddedJVMManager (§15).

## Archivos afectados (esperados)

- Manager, Gateway, Bootstrap, posiblemente Host hop de eventos.
- Sin rediseño Bridge.

## Riesgos

- Regresiones de correctness al mover hilos.
- Over-copy o under-copy de frames.

## Criterios de éxito

- [ ] Checklist EmbeddedJVMManager completo.
- [ ] Sin regresiones de Fases 5–7.
- [ ] Métricas de cold start y RSS aceptadas por el equipo.

## Criterios de rollback

- Revertir optimizaciones de threading; mantener correctness.

## Tiempo estimado

**2–4 semanas** (iterativo).

## Dependencias

- Fase 7+.
- Bloquea parcialmente Fase 12 (calidad).

---

# Fase 12 — App Store Readiness

## Objetivo

Dejar el binario iOS listo para distribución: packaging runtime, tamaño, estabilidad, feature flags, compliance GPL-3, narrativa de review, pruebas en device de producción.

## Prerrequisitos

- Fases críticas 1–7 en éxito; 8–11 según alcance de release.
- Gates Go/No-Go técnicos cerrados en verde.

## Entregables

- Inventario de binarios nativos y licenses.
- Plan de fuentes GPL si aplica.
- Hardening `System.exit` / Failed states.
- TestFlight / checklist review.
- DI producción iOS habilitada solo tras sign-off.

## Archivos afectados (esperados)

- Build settings, scripts de empaquetado, docs legales internos, flags DI.
- Mínimo impacto en Architecture docs (este roadmap solo se marca “done”).

## Riesgos

- Rechazo App Store (emulación / interpreted code).
- Tamaño excesivo.
- Regresión de privacidad/sandbox.

## Criterios de éxito

- [ ] Build App Store reproducible.
- [ ] Sign-off legal + ingeniería.
- [ ] Escenarios Idle/Running/Stop/Terminate estables en device.
- [ ] macOS Process path no regredido.

## Criterios de rollback

- Deshabilitar embebido iOS en release; mantener catálogo + macOS host.

## Tiempo estimado

**2–4 semanas** (incluye cola de review).

## Dependencias

- Critical path 0→7; recomendable 8–11 según promesa de producto.

---

# Implementation Order

| Orden | Fase | Nombre | Estimación |
|------:|------|--------|------------|
| 0 | Fase 0 | Preparación | 1–3 sem |
| 1 | Fase 1 | Spike JVM | 1–2 sem |
| 2 | Fase 2 | Spike JNI | 1 sem |
| 3 | Fase 3 | Carga FreeJ2ME | 1–2 sem |
| 4 | Fase 4 | Localizar JAR | 3–5 días |
| 5 | Fase 5 | Primer MIDlet | 1–2 sem |
| 6 | Fase 6 | Primer Frame | 1 sem |
| 7 | Fase 7 | Render | 3–5 días |
| 8 | Fase 8 | Input | 1–2 sem |
| 9 | Fase 9 | Audio | 1–3 sem |
| 10 | Fase 10 | RMS | 3–7 días |
| 11 | Fase 11 | Optimización | 2–4 sem |
| 12 | Fase 12 | App Store Readiness | 2–4 sem |

**Paralelismo permitido tras Fase 7:** Fases 8, 9 y 10 pueden avanzar en paralelo si hay capacidad. Fase 11 puede solaparse parcialmente con 8–10. Fase 12 al final.

---

# Critical Path

```
F0 → F1 → F2 → F3 → F4 → F5 → F6 → F7 → (F8 ∥ F9 ∥ F10) → F11 → F12
```

| Fase | Bloquea |
|------|---------|
| **0** | Todo el camino embebido |
| **1** | JNI y cualquier FreeJ2ME in-process |
| **2** | Carga Vendor y Contract C embebido |
| **3** | JAR de usuario y MIDlets |
| **4** | Primer MIDlet real de Library |
| **5** | Frames, input útil, audio, RMS con MIDlet |
| **6** | Render de producto |
| **7** | Experiencia visual end-to-end; habilita trabajo paralelo 8–10 |
| **8** | Jugabilidad (no bloquea Audio/RMS técnicos) |
| **9** | Completitud “playable” con sonido |
| **10** | Saves J2ME |
| **11** | Calidad release / gate de performance |
| **12** | Distribución |

**Camino crítico mínimo para “primer LCD en iOS”:** Fases **0 → 7**.  
**Camino crítico para “jugable básico”:** **0 → 8** (+ 10 recomendable).  
**Camino crítico para store:** **0 → 12** con gates verdes.

---

# Go / No-Go Decision Gates

El proyecto **debe detenerse o pivotar** (sin seguir gastando en fases posteriores) si falla el gate indicado.

| Gate | Momento | Hipótesis bajo prueba | No-Go si… | Acción |
|------|---------|------------------------|-----------|--------|
| **G0** | Fin Fase 0 | OpenJDK Mobile produce artefacto estático usable | No hay `libjvm` reproducible para el target | Abortar embebido iOS; permanecer en macOS Process + `runtimeUnavailable` |
| **G1** | Fin Fase 1 | JVM embebida arranca en proceso app | Hello World imposible / violación W^X-JIT | Abortar embebido; reevaluar solo si aparece runtime alternativo **sin** cambiar arquitectura de capas |
| **G2** | Fin Fase 2 | JNI estable y contenido al Gateway | Filtrado inevitable a producto / inestable | Abortar embebido |
| **G3** | Fin Fase 3 | FreeJ2ME carga sobre la VM | SE/AWT/classpath insalvable | **Stop:** no F4–F7 sobre esta VM; activar decisión de fork gráfico allowlisted **o** abandonar iOS embebido |
| **G4** | Fin Fase 5 | `defineClass` + Probe MIDlet | Loader/ASM/`System.exit` matan el enfoque | Stop iOS embebido o fork allowlisted explícito; no fingir progreso en F6–F12 |
| **G5** | Fin Fase 6 | Primer frame por painter | Sin framebuffer legible | Stop render path; no F7 hasta plan B gráfico |
| **G6** | Pre Fase 12 | Performance + estabilidad multi-sesión | No cumple checklist EmbeddedJVMManager / UX mínima | No enviar a App Store; iterar F11 o reducir scope |
| **G7** | Fase 12 | Legal GPL + review policy | Bloqueo legal o rechazo estructural de categoría | No release iOS embebido; documentar decisión de producto |

**Regla de oro:** un No-Go en G0–G5 **congela** el critical path. No se “compensa” saltando a Input/Audio/Store. macOS y la arquitectura Bridge→Host→Adapter **siguen válidos** independientemente del No-Go iOS.

---

## Cierre

Este roadmap es el **plan de ejecución** del Embedded JVM Runtime.  
La arquitectura oficial permanece en los tres documentos padre. Cualquier fase que requiera romper Bridge, Host, Adapter públicos o los anti-patterns de EmbeddedJVMManager está **fuera de alcance** y debe rechazarse.

---

*Implementation Roadmap v1.0 · JavaOne*
