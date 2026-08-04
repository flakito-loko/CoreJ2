# Embedded JVM Architecture

**Estado:** Contrato de arquitectura oficial  
**Versión:** 1.0  
**Fecha:** 2026-08-04  
**Alcance:** Integración de una JVM embebida en iOS para FreeJ2ME  
**Dependencias de lectura:**  
`docs/Architecture/JVM_FEASIBILITY_STUDY.md`,  
`docs/FREEJ2ME_RUNTIME_CONTRACT.md`,  
`docs/E5_US003_PERSISTENT_RUNTIME_DESIGN.md`,  
`docs/E5_US005_PERSISTENT_RUNTIME_MIGRATION.md`,  
`AGENTS.md`

**Naturaleza de este documento**

Este archivo es el **plano maestro del Runtime embebido**. No es un tutorial, no es una guía de implementación y no prescribe APIs nuevas fuera de los seams ya existentes. Toda implementación futura del camino iOS debe respetarlo.

**Invariante fundamental**

La pila de producto ya establecida permanece intacta:

```
Library / Emulator UI
  → EmulatorBridgeProtocol
    → RuntimeHostProtocol
      → FreeJ2MERuntimeAdapter
        → FreeJ2MEMobilePlatformBootstrapping
```

La JVM embebida es un **backend de plataforma** detrás de `FreeJ2MEMobilePlatformBootstrapping`, no una capa paralela visible a Bridge, Library, Import Engine o Views.

---

# 1. Objetivo

## 1.1 Propósito

El Embedded JVM Runtime permite ejecutar FreeJ2ME **dentro del proceso de la aplicación iOS**, de forma compatible con distribución App Store, manteniendo el mismo contrato de aplicación que ya usa JavaOne en macOS.

## 1.2 Dualidad de plataformas

| Plataforma | Runtime detrás de PlatformBootstrap | Estado actual |
|------------|-------------------------------------|---------------|
| **macOS** | JVM **persistente fuera de proceso** (`Process` + daemon JavaOne-owned) | Producción |
| **iOS** | JVM **embebida in-process** (hipótesis OpenJDK Mobile / Zero) | Arquitectura objetivo; no implementada |

Ambos caminos exponen la misma semántica Contract C hacia `FreeJ2MERuntimeAdapter`. El Adapter, el Host y el Bridge no deben ramificarse por plataforma en su API pública.

## 1.3 Qué permanece intacto

- `EmulatorBridgeProtocol` y `DefaultEmulatorBridge`
- `RuntimeHostProtocol` y `FreeJ2MERuntimeHost`
- Superficie pública de `FreeJ2MERuntimeAdapter`
- Protocolo `FreeJ2MEMobilePlatformBootstrapping`
- Library, Import Engine, SwiftData, ViewModels y Views
- Vendor FreeJ2ME como código de emulación (sin reescritura de producto)
- Flujo de frames app-facing: `EmulatorFrame` → `RuntimeEvent.frameAvailable` → superficie LCD

## 1.4 Qué introduce este plano

Únicamente la **descomposición interna** del backend iOS de PlatformBootstrap:

- ciclo de vida de una JVM de proceso
- frontera JNI hacia FreeJ2ME
- ownership de memoria y errores en ese borde

No redefine el Emulator Bridge ni el modelo de Library.

---

# 2. Objetivos de diseño

## 2.1 Principios

1. **Una sola JVM por proceso de aplicación iOS.** No se crea una JVM por juego ni por sesión de UI.
2. **La JVM no se reinicia entre juegos.** Las sesiones de MIDlet se abren y cierran sobre la misma VM; solo el estado FreeJ2ME de sesión se resetea.
3. **FreeJ2ME permanece Vendor.** La lógica MIDP / `MobilePlatform` / `MIDletLoader` vive en `Vendor/FreeJ2ME`.
4. **`FreeJ2MERuntimeAdapter` es el único punto Swift autorizado a orquestar FreeJ2ME.** Ninguna otra capa de producto invoca Contract C.
5. **`FreeJ2MEMobilePlatformBootstrapping` es la única capa que conoce el mecanismo de runtime** (Process en macOS, Embedded JVM + JNI en iOS).
6. **Views nunca conocen JNI, OpenJDK ni FreeJ2ME.**
7. **Bridge nunca conoce OpenJDK, JNI ni tipos Vendor.**
8. **El Host publica eventos; no renderiza y no posee la JVM.**
9. **El Renderer (ViewModel de superficie + conversión a imagen) nunca conoce la JVM.** Solo consume `RuntimeEvent` / `EmulatorFrame` ya materializados.
10. **Library e Import Engine son ortogonales al Runtime.** Importan y persisten `InstalledGame`; no arrancan JVM.
11. **Protocol-oriented / inyección de dependencias.** El backend embebido se selecciona por composición (DI), no por `#ifdef` dispersos en Views.
12. **Fallo tipado.** La indisponibilidad del runtime sigue expresándose como errores de dominio de Bridge (`EmulatorBridgeError`), no como excepciones JNI crudas en UI.

## 2.2 Calidad de frontera

- Los píxeles cruzan el borde Java→Swift como **copias** (`EmulatorFrame`), nunca como framebuffer mutable compartido.
- Los eventos de lifecycle y de frame siguen el `RuntimeEventPipe` existente.
- Pause / resume / stop de sesión son responsabilidades del Bridge/Host/Adapter; la JVM embebida solo obedece al bootstrap.

---

# 3. Arquitectura general

## 3.1 Vista lógica (producto + runtime)

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI                               │
│         LibraryView  ·  EmulatorView (LCD)                   │
└────────────────────────────┬────────────────────────────────┘
                             │ ViewModels only
┌────────────────────────────▼────────────────────────────────┐
│                     Library feature                          │
│   LibraryViewModel · Import Engine · Repositories            │
│   (InstalledGame) — no JVM                                   │
└────────────────────────────┬────────────────────────────────┘
                             │ selectGame → LaunchConfiguration
┌────────────────────────────▼────────────────────────────────┐
│                 EmulatorBridgeProtocol                       │
│              DefaultEmulatorBridge                           │
│   validación · EmulatorSession · runtimeEvents               │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                 RuntimeHostProtocol                          │
│               FreeJ2MERuntimeHost                            │
│   RuntimeEventPipe · started/failed/frameAvailable           │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│               FreeJ2MERuntimeAdapter                         │
│   Contract C · onFrameCaptured · stop → shutdownRuntime      │
└────────────────────────────┬────────────────────────────────┘
                             │ FreeJ2MEMobilePlatformBootstrapping
        ┌────────────────────┴────────────────────┐
        │ macOS                                    │ iOS (objetivo)
        ▼                                          ▼
 Persistent Process Bootstrap              Embedded Platform Bootstrap
 (daemon JVM hijo)                         ┌──────────────────────┐
                                           │ EmbeddedJVMManager   │
                                           │ JNI Gateway          │
                                           └──────────┬───────────┘
                                                      │
                                           ┌──────────▼───────────┐
                                           │   Embedded JVM       │
                                           │  (OpenJDK Mobile)    │
                                           └──────────┬───────────┘
                                                      │
                                           ┌──────────▼───────────┐
                                           │ Vendor FreeJ2ME      │
                                           │ MobilePlatform       │
                                           │ MIDletLoader         │
                                           └──────────┬───────────┘
                                                      │
                                                 active MIDlet
```

## 3.2 Responsabilidades por capa

| Capa | Responsabilidad |
|------|-----------------|
| **SwiftUI** | Presentación; gestos; navegación. Sin lógica de emulación. |
| **Library** | Catálogo, importación JAR, selección de `InstalledGame`. |
| **Bridge** | API app-facing; validación; ownership de `EmulatorSession`; reenvío de eventos. |
| **RuntimeHost** | Publicación de `RuntimeEvent`; delegación de lifecycle al Adapter. |
| **RuntimeAdapter** | Orquestación Contract C; traducción a tipos app-facing; único contacto Swift con FreeJ2ME. |
| **PlatformBootstrap** | Ejecución real del runtime (Process o Embedded). Conoce JNI/OpenJDK **solo aquí**. |
| **Embedded JVM** | Ejecuta bytecode FreeJ2ME y del MIDlet. |
| **JNI Gateway** | Frontera tipada nativa↔Java dentro del bootstrap iOS. |
| **FreeJ2ME** | Emulación MIDP; LCD; loader; hooks de painter/input. |
| **MIDlet** | Aplicación del usuario. |

---

# 4. Componentes

Los nombres de esta sección describen **roles arquitectónicos** del camino embebido. No sustituyen los tipos Swift ya existentes en Bridge/Host/Adapter. `EmbeddedJVMManager` y `JNI Gateway` viven **dentro** del backend iOS de PlatformBootstrap.

## 4.1 EmbeddedJVMManager

| | |
|---|---|
| **Responsabilidad** | Poseer el ciclo de vida de la JVM embebida a nivel de **proceso de aplicación**: creación única, readiness, teardown al terminar la app (o política explícita de destrucción). |
| **Dependencias** | Artefacto OpenJDK Mobile (u otro runtime aprobado); configuración de classpath/modules FreeJ2ME; sandbox iOS. |
| **Puede** | Arrancar una JVM; exponer un handle opaco al JNI Gateway; reportar estado ready/failed; coordinar shutdown ordenado. |
| **Nunca debe** | Conocer SwiftUI, Bridge, Library, Import Engine; crear una JVM por juego; exponer `JNIEnv` a capas superiores; parsear JAR de usuario por sí mismo. |

## 4.2 JNI Gateway

| | |
|---|---|
| **Responsabilidad** | Traducir operaciones Contract C del bootstrap a invocaciones Java (y callbacks nativos desde painter/hilos FreeJ2ME hacia el bootstrap). |
| **Dependencias** | EmbeddedJVMManager; clases FreeJ2ME / fachada JavaOne-owned si aplica; reglas de attach/detach de hilos. |
| **Puede** | Invocar `MobilePlatform` / loader / painter registration; copiar píxeles a buffers owned; propagar fallos como errores de dominio hacia el bootstrap. |
| **Nunca debe** | Ser llamado desde Views o ViewModels; filtrar eventos de UI; renderizar; conocer `EmulatorSession`; filtrar política de App Store. |

## 4.3 PlatformBootstrap (`FreeJ2MEMobilePlatformBootstrapping`)

| | |
|---|---|
| **Responsabilidad** | Única abstracción de ejecución de runtime: platform, painter, load, run, frame streaming, shutdown. |
| **Dependencias** | En iOS: EmbeddedJVMManager + JNI Gateway. En macOS: Process persistente (ya existente). |
| **Puede** | Implementar Contract C; emitir frames vía `frameHandler`; apagar sesión/runtime según `shutdownRuntime()`. |
| **Nunca debe** | Publicar `RuntimeEvent` directamente a UI; validar reglas de Bridge; tocar SwiftData; importar juegos. |

## 4.4 RuntimeAdapter (`FreeJ2MERuntimeAdapter`)

| | |
|---|---|
| **Responsabilidad** | Orquestar Contract C; mantener flags de sesión FreeJ2ME; convertir capturas a `EmulatorFrame`; invocar `onFrameCaptured`; delegar stop al bootstrap. |
| **Dependencias** | `FreeJ2MEMobilePlatformBootstrapping`; modelos `LaunchConfiguration` / `InstalledGame`. |
| **Puede** | Ser el único Swift que “sabe” FreeJ2ME; mapear fallos a `EmulatorBridgeError`. |
| **Nunca debe** | Importar UIKit/SwiftUI de producto; conocer OpenJDK/JNI; renderizar CGImage; acceder a repositorios de Library. |

## 4.5 RuntimeHost (`FreeJ2MERuntimeHost`)

| | |
|---|---|
| **Responsabilidad** | Cumplir `RuntimeHostProtocol`; poseer `RuntimeEventPipe`; cablear frames del Adapter a `.frameAvailable`. |
| **Dependencias** | `FreeJ2MERuntimeAdapter`. |
| **Puede** | Emitir lifecycle + frames. |
| **Nunca debe** | Crear JVM; llamar JNI; validar JAR (eso es Bridge); dibujar. |

## 4.6 EmulatorBridge (`DefaultEmulatorBridge`)

| | |
|---|---|
| **Responsabilidad** | API única hacia ViewModels; validación pre-flight; máquina de estados de `EmulatorSession`. |
| **Dependencias** | `RuntimeHostProtocol`. |
| **Puede** | Rechazar launches inválidos; serializar una sesión activa. |
| **Nunca debe** | Conocer FreeJ2ME, OpenJDK, JNI o PlatformBootstrap concreto. |

## 4.7 FreeJ2ME (Vendor)

| | |
|---|---|
| **Responsabilidad** | Emulación J2ME/MIDP: `MobilePlatform`, painter, `loadJar`/`runJar`, input hooks, LCD. |
| **Dependencias** | Java SE subset proveído por la JVM embebida. |
| **Puede** | Ejecutar MIDlets; invocar painter; usar `dataPath` para RMS. |
| **Nunca debe** | Ser importado por capas de producto Swift; asumir frontend AWT de escritorio como UI de iOS. |

## 4.8 Renderer (superficie LCD)

Incluye `EmulatorViewModel`, `EmulatorFrameCGImageConverter` y `EmulatorView`.

| | |
|---|---|
| **Responsabilidad** | Observar `runtimeEvents`; convertir `EmulatorFrame` a representación visual; gestionar presentación de sesión desde UI. |
| **Dependencias** | `EmulatorBridgeProtocol` únicamente (vía ViewModel). |
| **Puede** | Mostrar LCD; iniciar/detener observación según ciclo de vista. |
| **Nunca debe** | Conocer JVM, JNI, FreeJ2ME, bootstrap o formatos Java internos. |

## 4.9 Library e Import Engine

| | |
|---|---|
| **Responsabilidad** | Importar, hashear, deduplicar y persistir juegos; presentar catálogo; disparar launch por selección. |
| **Dependencias** | Repositorios; pipeline de import; factory de `EmulatorViewModel`. |
| **Puede** | Entregar `InstalledGame` listo para `LaunchConfiguration`. |
| **Nunca debe** | Arrancar JVM; llamar Adapter/Host/Bootstrap; conocer frames. |

---

# 5. Ciclo de vida

## 5.1 Diagrama de estados (proceso app + sesión)

```
                    App Launch
                        │
                        ▼
                 ┌──────────────┐
                 │ JVM Startup  │  (una vez por proceso, iOS)
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │Load FreeJ2ME │  classpath / classes Vendor listas
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
            ┌───►│    Idle      │◄──────────────────┐
            │    └──────┬───────┘                   │
            │           │ Load MIDlet               │
            │           ▼                           │
            │    ┌──────────────┐                   │
            │    │   Running    │◄──── Resume       │
            │    └──────┬───────┘                   │
            │           │ Pause                     │
            │           ▼                           │
            │    ┌──────────────┐                   │
            │    │    Pause     │───────► Running   │
            │    └──────┬───────┘                   │
            │           │ Stop                      │
            │           └───────────────────────────┘
            │
            │    Terminate App
            ▼
     JVM teardown / process end
```

## 5.2 Definición de estados

| Estado | Qué ocurre |
|--------|------------|
| **App Launch** | Proceso iOS inicia. DI construye Bridge/Host/Adapter. La JVM **aún puede** diferirse hasta primer uso, pero la política objetivo es **una JVM de proceso** lista antes del primer juego o en cold-start controlado. |
| **JVM Startup** | `EmbeddedJVMManager` crea la VM. Fallo → runtime unavailable tipado; la app permanece usable (Library). |
| **Load FreeJ2ME** | Classpath/modules de Vendor + fachada JavaOne quedan resolubles. No implica MIDlet cargado. |
| **Idle** | JVM viva; no hay MIDlet activo; Bridge sin sesión running; LCD en espera. |
| **Load MIDlet** | Adapter/Bootstrap ejecutan platform (si hace falta), painter, `loadJar` para el `InstalledGame` seleccionado. |
| **Running** | `runJar` / `startApp` alcanzados; frames e input habilitados según contrato. |
| **Pause** | Sesión Bridge en paused; Adapter solicita suspensión de actividad MIDlet en la medida que FreeJ2ME lo permita. JVM **sigue viva**. |
| **Resume** | Retorno a Running. |
| **Stop** | Adapter `stop` → bootstrap `shutdownRuntime` de **sesión** (teardown FreeJ2ME de juego). Transición a Idle. **No** implica destruir la JVM de proceso. |
| **Idle (post-stop)** | Listo para otro juego sin reiniciar JVM. |
| **Terminate App** | Único momento ordinario para destruir la JVM de proceso junto con el proceso. |

## 5.3 Clarificación Stop vs Terminate

- **Stop (sesión):** libera MIDlet / platform session bindings; Bridge marca sesión detenida.  
- **Terminate (proceso):** fin de `EmbeddedJVMManager`.  
Confundir ambos es un anti-patrón (reiniciar JVM por cada juego).

---

# 6. Flujo de ejecución

```
Usuario selecciona un juego
        │
        ▼
LibraryView / LibraryViewModel
        │  InstalledGame
        ▼
EmulatorView + EmulatorViewModel
        │  LaunchConfiguration
        ▼
EmulatorBridge.launch
        │  validación JAR/config/sesión
        ▼
RuntimeHost.launch
        │
        ▼
FreeJ2MERuntimeAdapter.start
        │  Contract C
        ▼
PlatformBootstrap (Embedded en iOS)
        │
        ▼
Embedded JVM + JNI Gateway
        │
        ▼
FreeJ2ME MobilePlatform / MIDletLoader
        │
        ▼
MIDlet startApp
        │
        ▼
painter / flushGraphics
        │  EmulatorFrame
        ▼
Adapter.onFrameCaptured → Host RuntimeEventPipe
        │  .frameAvailable
        ▼
EmulatorViewModel → Renderer LCD
```

La Library no espera el primer frame. El Bridge no interpreta píxeles. El Renderer no espera a FreeJ2ME: solo eventos.

---

# 7. Flujo de Input

El contrato de producto ya prevé input a través del Bridge hacia el runtime. Con JVM embebida, el camino físico termina en FreeJ2ME sin filtrar capas.

```
Touch / teclado virtual (SwiftUI)
        │
        ▼
Emulator View / ViewModel (solo intención de input)
        │
        ▼
EmulatorBridge (API de input cuando exista en el contrato de app)
        │
        ▼
RuntimeHost
        │
        ▼
FreeJ2MERuntimeAdapter
        │
        ▼
PlatformBootstrap
        │
        ▼
JNI Gateway
        │
        ▼
FreeJ2ME MobilePlatform.key* / pointer*
        │
        ▼
Display / Canvas del MIDlet  (p. ej. keyPressed)
```

**Reglas**

- El input **nunca** salta Adapter ni Bootstrap.  
- Las coordenadas se expresan en espacio LCD FreeJ2ME (contrato runtime existente), no en puntos SwiftUI crudos sin transformación en la capa de emulación.  
- JNI Gateway no interpreta gestos de sistema iOS; solo recibe eventos ya normalizados.

---

# 8. Flujo de Render

```
FreeJ2ME PlatformGraphics / repaint
        │
        ▼
MobilePlatform.painter.run()
        │
        ▼
Lectura getLCD() / buffer ARGB  (copia)
        │
        ▼
JNI Gateway → FreeJ2MEFrameCapture / EmulatorFrame
        │
        ▼
PlatformBootstrap.frameHandler
        │
        ▼
FreeJ2MERuntimeAdapter.onFrameCaptured
        │
        ▼
FreeJ2MERuntimeHost → RuntimeEvent.frameAvailable
        │
        ▼
DefaultEmulatorBridge.runtimeEvents
        │
        ▼
EmulatorViewModel.applyFrame
        │
        ▼
EmulatorFrameCGImageConverter → CGImage
        │
        ▼
EmulatorView (SwiftUI Image)
```

**Reglas**

- Una sola dirección de verdad de píxeles: FreeJ2ME → copia → evento → UI.  
- Backpressure: política de buffer newest en el pipe de eventos (ya establecida); frames viejos pueden descartarse bajo carga.  
- Metal no es requisito de este contrato; la superficie actual basada en CGImage permanece válida.

---

# 9. Flujo de Audio

Sin diseño de implementación. Solo ownership.

| Capa | Responsabilidad de audio |
|------|---------------------------|
| MIDlet / FreeJ2ME (`PlatformPlayer`, etc.) | Genera o solicita audio según MMAPI. |
| JVM embebida | Ejecuta ese bytecode. |
| PlatformBootstrap / JNI Gateway | Único lugar permitido para puentear hacia un backend de audio nativo iOS, si se introduce. |
| RuntimeAdapter | Puede exponer lifecycle (pause/resume/stop) que implique silenciar; no mezcla buffers. |
| Bridge / Host | Señales de sesión; no decodifican audio. |
| Views / Library | No tocan audio del emulador. |

Hasta que exista un backend nativo, el audio puede estar ausente o stubbed **dentro** del borde FreeJ2ME/bootstrap, sin filtrar Bridge.

---

# 10. RMS

| Capa | Responsabilidad |
|------|-----------------|
| FreeJ2ME / MIDP RMS | Persistencia Record Store según API J2ME. |
| `MobilePlatform.dataPath` | Debe apuntar a un directorio del **sandbox** de la app. |
| PlatformBootstrap (Embedded) | Configura `dataPath` al crear/bind de platform para la sesión o el proceso. |
| Library / Import Engine | No almacenan RMS; solo el JAR instalado. |
| Bridge | No interpreta records RMS. |

La JVM no elige rutas de producto iOS; el bootstrap embebido es quien fija el path sandbox-compliant.

---

# 11. Gestión de memoria

## 11.1 Quién crea la JVM

`EmbeddedJVMManager`, invocado exclusivamente desde el backend iOS de PlatformBootstrap (directa o indirectamente en el primer `bootstrapMobilePlatform` / inicialización de runtime).

## 11.2 Quién la destruye

`EmbeddedJVMManager` en el teardown de proceso (terminación de app) o política explícita de shutdown global. **Stop de sesión no destruye la JVM.**

## 11.3 Cuándo vive

Desde el éxito de JVM Startup hasta Terminate App. Sobrevive a N ciclos Idle → Running → Stop.

## 11.4 GC

El recolector de basura es **interno a la JVM embebida**. Las capas Swift no invocan GC de forma rutinaria. Tras Stop de sesión, el bootstrap debe soltar referencias Java de sesión para permitir recolección del estado del MIDlet.

## 11.5 Referencias JNI

- Local refs: liberadas en el scope de cada llamada del JNI Gateway.  
- Global/new global refs: solo para objetos de vida larga justificados (p. ej. clases cacheadas); ownership documentado en el Gateway.  
- Hilos nativos FreeJ2ME que llamen nativo deben estar attached; detach al terminar el hilo según reglas JNI.  
- Prohibido almacenar `JNIEnv*` en ViewModels o singletons de UI.

## 11.6 `System.exit`

En proceso hijo macOS, un exit mata el daemon (recuperable).  
**En JVM embebida, `System.exit` puede terminar el proceso de la app.**

Política arquitectónica:

1. El borde JavaOne debe **impedir o atrapar** salidas no autorizadas en la medida que el runtime lo permita.  
2. FreeJ2ME Vendor no se modifica salvo fork allowlisted explícito.  
3. Un exit no atrapado se trata como fallo fatal de proceso; no como “stop de sesión” limpio.

---

# 12. Manejo de errores

## 12.1 Flujo arquitectónico

```
Fallo en JVM / JNI / FreeJ2ME / validación
        │
        ▼
Normalización en PlatformBootstrap o Adapter
        │  → EmulatorBridgeError (dominio app)
        ▼
Host puede emitir .failed
        │
        ▼
Bridge propaga throw / estado de sesión failed|stopped
        │
        ▼
ViewModel expone mensaje de usuario
        │
        ▼
View muestra alerta / estado vacío
```

## 12.2 Reglas

- **Ninguna** excepción JNI/`Throwable` Java cruza hacia SwiftUI.  
- Library e Import Engine no consumen errores de runtime de emulación salvo que el usuario reintente launch.  
- Fallo de JVM Startup deja la app en modo catálogo (degradación elegante).  
- Fallo a mitad de Running debe conducir a Stop de sesión y vuelta a Idle cuando sea posible; si la VM queda corrupta, solo Terminate App es seguro — ese caso es fallo severo y debe instrumentarse.

---

# 13. Extensibilidad

## 13.1 Sustituir OpenJDK Mobile

El contrato estable es `FreeJ2MEMobilePlatformBootstrapping`.

Para adoptar otra JVM embebida aprobada:

1. Implementar un nuevo backend que cumpla el mismo protocolo.  
2. Proveer su propio `EmbeddedJVMManager` + JNI Gateway (o equivalente).  
3. Registrar la implementación en el composition root.  
4. **No** cambiar Bridge, Host, Adapter público, Library ni Renderer.

## 13.2 macOS vs iOS

La dualidad Process persistente / Embedded es una decisión de **bootstrap**, no de producto. Los tests de Adapter con stubs permanecen válidos con cualquier backend.

## 13.3 Evolución FreeJ2ME

Actualizaciones Vendor se absorben detrás del Adapter/Bootstrap. Los seams Contract C (`MobilePlatform`, painter, load/run, input, `dataPath`) son la API de integración preferente (ver contrato FreeJ2ME existente).

---

# 14. Restricciones arquitectónicas

## Anti-patterns

Queda **expresamente prohibido**:

1. Crear más de una JVM embebida por proceso de aplicación.  
2. Reiniciar la JVM entre juegos como estrategia normal de Stop.  
3. Llamar JNI desde Views, ViewModels, Library o Import Engine.  
4. Acceder a tipos FreeJ2ME (`org.recompile.*`, `javax.microedition.*`) desde SwiftUI o Bridge.  
5. Usar OpenJDK / `libjvm` fuera del feature Runtime (bootstrap embebido).  
6. Saltar `FreeJ2MERuntimeAdapter` hacia el bootstrap o la JVM.  
7. Acoplar el Renderer a Java, JNI o buffers FreeJ2ME.  
8. Acoplar Library a la JVM o al Host.  
9. Publicar `RuntimeEvent` desde el JNI Gateway saltándose Host.  
10. Compartir framebuffer mutable entre Java y Swift.  
11. Filtrar `System.exit` dejando que termine la app como si fuera Stop de sesión.  
12. Introducir un segundo Bridge “especial iOS”.

---

# 15. Decisiones arquitectónicas (ADR)

| ID | Estado | Motivación | Impacto |
|----|--------|------------|---------|
| **ADR-001** | Aceptada | Mantener Bridge → Host → Adapter → Bootstrap como única pila de producto | iOS no introduce capas paralelas de app |
| **ADR-002** | Aceptada | macOS = Process persistente; iOS = JVM embebida | Dos backends, un protocolo de bootstrap |
| **ADR-003** | Aceptada | Una JVM por proceso; no reinicio entre juegos | Menor latencia de relaunch; exige Stop de sesión robusto |
| **ADR-004** | Aceptada | OpenJDK Mobile (Zero) como hipótesis de JVM (estudio de viabilidad) | Spike M9; Zero implica coste de CPU |
| **ADR-005** | Aceptada | `FreeJ2MERuntimeAdapter` único contacto Swift–FreeJ2ME | Contención de Vendor y de errores |
| **ADR-006** | Aceptada | Frames como `EmulatorFrame` copiados + `RuntimeEvent` | Renderer desacoplado; sin Metal obligatorio |
| **ADR-007** | Aceptada | Library/Import ortogonales al Runtime | Import no arranca JVM |
| **ADR-008** | Aceptada | FreeJ2ME permanece Vendor; forks solo allowlisted | Minimiza drift; cambios gráficos/audio controlados |
| **ADR-009** | Aceptada | Errores de runtime normalizados a dominio Bridge | UI estable; sin leak de JNI |
| **ADR-010** | Propuesta | `dataPath` RMS siempre bajo sandbox iOS | Cumplimiento y aislamiento por juego/sesión |
| **ADR-011** | Propuesta | Input/audio solo vía Adapter/Bootstrap | Evita atajos UI→JNI |
| **ADR-012** | Aceptada | Sustitución de JVM solo detrás del protocolo bootstrap | Extensibilidad sin reescritura de producto |

---

# 16. Riesgos

## 16.1 Riesgos técnicos

- AWT / `BufferedImage` incompletos en el build mobile headless.  
- `defineClass` / ASM insuficientes para `MIDletLoader`.  
- `System.exit` in-process.  
- Complejidad de packaging estático de OpenJDK + classpath FreeJ2ME.  
- Fugas JNI / classloader entre sesiones.  
- Divergencia sutil entre backend Process (macOS) y Embedded (iOS).

## 16.2 Riesgos de rendimiento

- Intérprete Zero frente a HotSpot JIT de escritorio.  
- Coste de copia de frames ARGB a 60 Hz potenciales.  
- Contención MainActor si el bootstrap/JNI bloquea el hilo UI.  
- Cold start de JVM en dispositivos antiguos.

## 16.3 Riesgos de compatibilidad

- MIDlets que asumen Java Sound, filesystem libre o resolución fija.  
- Diferencias de endianness/formato de píxeles si el path AWT cambia.  
- Juegos que dependen de timing de desktop FreeJ2ME.  
- Actualizaciones Vendor que rompan la fachada Contract C.

## 16.4 Riesgos App Store

- Políticas de emulación / software de terceros.  
- Código interpretado y contenido de usuario (JARs).  
- Tamaño de binario y estabilidad en review devices.  
- Obligaciones **GPL-3** de FreeJ2ME en distribución.  
- Rechazo por APIs privadas o layout incorrecto de frameworks nativos.

---

# 17. Roadmap arquitectónico

Las épicas siguientes ordenan el trabajo **sin** alterar el contrato Bridge/Host/Adapter. Cada épica debe ser verificable de forma independiente.

### EPIC 1 — Embedded JVM

Arranque de una JVM embebida en proceso iOS; readiness; teardown de proceso; métricas de startup. Sin FreeJ2ME aún.

### EPIC 2 — FreeJ2ME Runtime

Classpath Vendor + fachada; `MobilePlatform` creable vía JNI Gateway; sin MIDlet de usuario.

### EPIC 3 — Load MIDlet

`loadJar` / `MIDletLoader` sobre JAR instalado por Library; errores tipados; sin UI de frames obligatoria.

### EPIC 4 — First Frame

Painter registrado; al menos un `EmulatorFrame` publicado por el Host; Renderer muestra LCD.

### EPIC 5 — Input

Puente Bridge→Adapter→Bootstrap→JNI→`key*`/`pointer*`; teclado virtual de producto puede llegar después del puente.

### EPIC 6 — Audio

Responsabilidad de backend nativo detrás del bootstrap; mute en pause/stop; sin acoplar Views.

### EPIC 7 — RMS

`dataPath` sandbox; persistencia entre sesiones Idle; aislamiento por juego según política de producto.

### EPIC 8 — Performance

Presupuesto de frame time; reducción de copias si se justifica; mover JNI off MainActor; telemetría.

### EPIC 9 — App Store

Packaging, tamaño, compliance GPL, narrativa de review, pruebas en device de producción, feature flag de DI iOS.

---

## Cierre

Este documento fija el **contrato de arquitectura** del Embedded JVM Runtime para JavaOne.

- macOS sigue en Process persistente.  
- iOS adopta JVM embebida detrás de PlatformBootstrap.  
- El resto del sistema — Library, Import, Bridge, Host, Adapter público, Renderer — **no se rediseña**.

Cualquier PR que viole la sección Anti-patterns o los ADR aceptados debe rechazarse en revisión de arquitectura.

---

*Referencia oficial · Embedded JVM Architecture v1.0 · JavaOne*
