# EmbeddedJVMManager

**Estado:** Contrato oficial de componente  
**Versión:** 1.0  
**Fecha:** 2026-08-04  
**Padre arquitectónico:** `docs/Architecture/EMBEDDED_JVM_ARCHITECTURE.md`  
**Viabilidad:** `docs/Architecture/JVM_FEASIBILITY_STUDY.md`

**Naturaleza**

Este documento es la **especificación de ingeniería** del rol `EmbeddedJVMManager`. No es tutorial, no es guía de implementación y **no contiene código**. Toda implementación futura del camino iOS embebido debe cumplir este contrato.

**Posición en la pila**

```
FreeJ2MERuntimeAdapter
  → FreeJ2MEMobilePlatformBootstrapping   (backend iOS)
       → EmbeddedJVMManager               ← este componente
       → JNI Gateway
       → Embedded JVM (OpenJDK Mobile u otro runtime aprobado)
```

`EmbeddedJVMManager` es **interno** al backend iOS de PlatformBootstrap. No es una capa de producto y no altera Bridge, Host, Adapter público, Library ni Views.

---

# 1. Objetivo

## 1.1 Responsabilidad exclusiva

`EmbeddedJVMManager` administra el **ciclo de vida de la JVM embebida a nivel de proceso de aplicación iOS**:

- existencia de **una** máquina virtual
- transición de estados de esa VM
- coordinación de arranque y apagado ordenado
- exposición de un **estado interno** consumible solo por PlatformBootstrap / JNI Gateway
- habilitación segura del borde JNI una vez la VM está lista

## 1.2 Qué no reemplaza

| Componente | Sigue siendo dueño de… |
|------------|-------------------------|
| **EmulatorBridge / DefaultEmulatorBridge** | API app-facing, validación, `EmulatorSession` |
| **RuntimeHost / FreeJ2MERuntimeHost** | `RuntimeEventPipe`, eventos de lifecycle/frames hacia la app |
| **FreeJ2MERuntimeAdapter** | Contract C, flags de sesión FreeJ2ME, `onFrameCaptured`, stop de sesión orquestado |
| **PlatformBootstrap** | Semántica `bootstrapMobilePlatform` / painter / load / run / `shutdownRuntime` / `frameHandler` |
| **JNI Gateway** | Invocaciones Java y callbacks nativos |
| **Renderer / Library / Import** | UI, catálogo, importación |

`EmbeddedJVMManager` **no** es el Adapter, **no** es el Bootstrap, **no** es el Bridge y **no** es el Host. Solo administra la JVM.

---

# 2. Responsabilidades

## 2.1 Qué hace

1. **Crear** la JVM embebida (como máximo una vez por proceso, salvo recuperación explícita tras Destroyed/Failed terminal).  
2. **Destruir** la JVM en teardown de proceso o política de shutdown global.  
3. **Garantizar unicidad:** rechazar cualquier intento de segunda creación concurrente o solapada.  
4. **Conocer y publicar estado interno** del runtime embebido (máquina de §4).  
5. **Coordinar startup:** secuencia NotInitialized → Starting → Ready → LoadingFreeJ2ME → Idle.  
6. **Coordinar shutdown:** Idle/StoppingSession → Shutdown → Destroyed.  
7. **Coordinar con JNI Gateway:** indicar cuándo el borde JNI es usable; invalidar el borde tras Destroyed.  
8. **Registrar ocupación de sesión** (Idle ↔ Running/Paused/StoppingSession) cuando PlatformBootstrap lo notifica, **sin** poseer `EmulatorSession`.  
9. **Serializar** operaciones de lifecycle de VM frente a callbacks concurrentes.  
10. **Señalar fallos de VM** hacia PlatformBootstrap para normalización a errores de dominio (sin filtrar JNI crudo a UI).

## 2.2 Qué no hace

- No valida `LaunchConfiguration` ni JAR (Bridge).  
- No publica `RuntimeEvent` (Host).  
- No orquesta Contract C completo (Adapter + Bootstrap).  
- No invoca `MobilePlatform.loadJar` / `runJar` por sí mismo (Gateway/Bootstrap).  
- No renderiza frames ni conoce CGImage/SwiftUI.  
- No importa juegos ni toca SwiftData.  
- No conoce `FreeJ2MERuntimeAdapter`, Views, Library ni Import Engine.  
- No destruye la JVM al cerrar un juego (Stop de sesión ≠ Destroy).  
- No expone tipos OpenJDK, `JavaVM*` o `JNIEnv*` fuera del Runtime embebido.  
- No implementa teclado virtual, audio AVFoundation ni persistencia RMS de producto.

---

# 3. Principios

1. **Singleton por proceso de aplicación.** Una instancia lógica de manager; una JVM.  
2. **Thread-safe.** Todas las transiciones de estado y la publicación de “JNI usable” están sincronizadas.  
3. **Lazy initialization permitida.** La JVM puede crearse en el primer uso real del bootstrap, no necesariamente en `App.init`, siempre que la unicidad se preserve.  
4. **Eager initialization opcional.** Cold-start controlado está permitido si DI/bootstrap lo solicitan explícitamente.  
5. **Nunca múltiples JVM** en el mismo proceso.  
6. **Nunca reinicio ordinario entre juegos.**  
7. **Nunca conoce FreeJ2MERuntimeAdapter.**  
8. **Nunca conoce SwiftUI, Views ni ViewModels.**  
9. **Nunca conoce Bridge ni Host.**  
10. **Separación Stop vs Terminate:** Stop de MIDlet/sesión deja la JVM viva; Terminate de app destruye la JVM.  
11. **Fail closed:** si el estado no permite una operación, se rechaza; no se “crea otra JVM” como recuperación silenciosa.  
12. **Opacidad:** el resto del proyecto ve, como máximo, estados abstractos vía PlatformBootstrap — nunca handles nativos de OpenJDK.

---

# 4. Máquina de estados

## 4.1 Estados

```
NotInitialized
      │ ensureStarted / start
      ▼
  Starting
      │ éxito                         │ fallo
      ▼                               ▼
   Ready ─────────────────────► Failed (terminal o recuperable según política)
      │ loadFreeJ2ME
      ▼
LoadingFreeJ2ME
      │ éxito
      ▼
    Idle ◄──────────────────────────────────────────────┐
      │ sessionBegin (platform/painter/load/run)          │
      ▼                                                   │
  Running ◄──── resume ──── Paused                        │
      │ pause                    │                        │
      └──────────► Paused        │                        │
      │                          │                        │
      │ sessionStop / stopSession│                        │
      ▼                          ▼                        │
           StoppingSession ──────┴────────────────────────┘
      │
      │ processShutdown (solo desde Idle o tras StoppingSession→Idle)
      ▼
  Shutdown
      │
      ▼
 Destroyed
```

| Estado | Significado |
|--------|-------------|
| **NotInitialized** | No existe JVM. Estado inicial del proceso. |
| **Starting** | Creación de VM en curso. JNI aún no usable para Contract C. |
| **Ready** | JVM viva; FreeJ2ME aún no considerado cargado/resoluble en classpath. |
| **LoadingFreeJ2ME** | Preparación de classpath/modules Vendor / fachada. |
| **Idle** | JVM + FreeJ2ME listos; **ningún** MIDlet/sesión FreeJ2ME activa. |
| **Running** | Sesión FreeJ2ME activa y en ejecución (ocupación). La JVM sigue siendo la misma. |
| **Paused** | Sesión activa suspendida. JVM viva. |
| **StoppingSession** | Teardown de sesión FreeJ2ME en curso; aún no Idle. |
| **Shutdown** | Apagado ordenado de la JVM de proceso en curso. |
| **Destroyed** | JVM inexistente tras shutdown o fallo terminal de destrucción. |
| **Failed** | Fallo de startup o corrupción que impide uso; no se aceptan sesiones hasta política de recuperación explícita. |

## 4.2 Eventos que disparan transición

| Evento | Origen típico | Efecto |
|--------|---------------|--------|
| `ensureStarted` / `start` | PlatformBootstrap | NotInitialized → Starting → Ready |
| `loadFreeJ2ME` | PlatformBootstrap | Ready → LoadingFreeJ2ME → Idle |
| `sessionBegin` | PlatformBootstrap al entrar en Contract C de juego | Idle → Running (vía pasos internos del bootstrap; el manager registra ocupación Running cuando el bootstrap declara sesión activa) |
| `pauseSession` | PlatformBootstrap (derivado de Adapter pause) | Running → Paused |
| `resumeSession` | PlatformBootstrap | Paused → Running |
| `stopSession` | PlatformBootstrap (`shutdownRuntime` de sesión) | Running/Paused → StoppingSession → Idle |
| `processShutdown` | Fin de app / política global | Idle (preferente) → Shutdown → Destroyed |
| `fail` | Cualquier fase | → Failed o Destroyed según severidad |

## 4.3 Transiciones prohibidas

- Crear JVM desde **Running**, **Paused**, **StoppingSession**, **Shutdown**.  
- **Running/Paused → Destroyed** sin Passing por StoppingSession e Idle (salvo crash fatal de proceso).  
- **Idle → Destroyed** sin Shutdown ordenado (salvo kill del proceso OS).  
- **Destroyed → Running** sin pasar de nuevo por Starting → Ready → LoadingFreeJ2ME → Idle.  
- **NotInitialized → Idle** saltándose Starting/Ready/LoadingFreeJ2ME.  
- Cualquier transición iniciada desde Views, Bridge o Adapter **directamente** hacia el manager (deben pasar por Bootstrap).  
- Segunda `start` concurrente mientras **Starting**.

## 4.4 Relación con `EmulatorSession`

`EmulatorSession` sigue siendo ownership del **Bridge**.  
Los estados Running/Paused del manager son **ocupación del runtime embebido**, alineados pero no duplicados como API pública de sesión.

---

# 5. Ownership

| Recurso | Poseedor | Quién libera |
|---------|----------|--------------|
| **JVM (instancia de proceso)** | `EmbeddedJVMManager` | Manager en Shutdown → Destroyed |
| **JavaVM handle nativo** | Manager (opaco hacia arriba) | Manager |
| **JNIEnv por hilo** | Hilo que hizo attach; coordinado por JNI Gateway | Detach al fin del uso del hilo; Gateway ejecuta la disciplina |
| **Global JNI references** | JNI Gateway (cache de clases/métodos de vida larga) | Gateway en invalidación; Manager ordena invalidar en Shutdown |
| **Local JNI references** | Scope de cada invocación del Gateway | Fin de scope de llamada; nunca almacenar en el Manager como estado de sesión |
| **ClassLoader / classpath FreeJ2ME** | JVM + configuración aplicada en LoadingFreeJ2ME | GC Java tras soltar refs; Shutdown destruye el heap entero |
| **FreeJ2ME Runtime (MobilePlatform, loader)** | Objetos Java en el heap; orquestados por Bootstrap/Gateway | Stop de sesión debe soltar bindings; no los posee el Manager como objetos tipados |
| **MIDlet activo** | FreeJ2ME / Display | Stop de sesión |
| **Buffers de frame (copia nativa)** | Productor en Gateway → bootstrap `frameHandler` → Adapter | Cadena de ownership hacia `EmulatorFrame`; el Manager no retiene framebuffers |

**Regla:** el Manager posee la **VM**; el Gateway posee la **disciplina JNI**; el Bootstrap posee la **semántica Contract C**; el Adapter posee la **orquestación app-facing FreeJ2ME**.

---

# 6. Thread Model

## 6.1 Preguntas y respuestas arquitectónicas

| Pregunta | Respuesta |
|----------|-----------|
| **¿Qué hilo crea la JVM?** | Un hilo de runtime dedicado (cola “EmbeddedJVM” / runtime executor), **nunca** el MainActor de SwiftUI como único lugar bloqueante indefinido. El Bootstrap puede solicitar `ensureStarted` desde el contexto que use hoy el Adapter; el Manager debe poder ejecutar el create en fondo y publicar Ready de forma sincronizada. |
| **¿Qué hilo usa JNI?** | Solo hilos attached. El JNI Gateway realiza llamadas Contract C en hilos conocidos. Prohibido usar un `JNIEnv*` obtenido en un hilo desde otro hilo. |
| **¿Qué ocurre si un callback viene desde Java?** | El hilo Java se attacha (si aplica), el Gateway copia datos (p. ej. píxeles), entrega al `frameHandler` del Bootstrap, y **no** llama al Manager para mutar estado de sesión salvo eventos de lifecycle explícitos. El Manager solo se toca bajo su candado de estado. |
| **¿Cómo se sincronizan los frames?** | Los frames no atraviesan el Manager. Fluyen Gateway → Bootstrap `frameHandler` → Adapter → Host pipe. El Manager garantiza que durante Destroyed/Shutdown el Gateway deje de aceptar callbacks. |
| **¿Cómo se protege el estado interno?** | Un único monitor/serial queue de estado del Manager. Lecturas de “isReady/isDestroyed” son consistentes; transiciones son atómicas respecto a ese monitor. |

## 6.2 Roles de hilo (conceptual)

| Rol | Uso |
|-----|-----|
| **UI / MainActor** | Solo producto; nunca JNI directo; nunca create JVM bloqueante prolongado sin política explícita |
| **Runtime executor** | Startup/shutdown JVM; posiblemente serialize ensureStarted |
| **JNI call threads** | Contract C sync desde Bootstrap |
| **FreeJ2ME / MIDlet threads** | Callbacks painter/audio; entrán al Gateway |

## 6.3 Prohibiciones de concurrencia

- Compartir `JNIEnv` entre hilos.  
- Mutar la máquina de estados desde callbacks Java sin adquirir el monitor del Manager.  
- Iniciar Shutdown mientras Starting sin cancelación definida.  
- Publicar “JNI usable” antes de Ready (+ Idle tras FreeJ2ME load para Contract C completo).

---

# 7. Memory Model

## 7.1 Vida útil

| Entidad | Nace | Muere |
|---------|------|-------|
| **JVM** | Éxito Starting → Ready | Destroyed |
| **FreeJ2ME (classes resolubles)** | LoadingFreeJ2ME → Idle | Destroyed (o unload solo si una política futura lo define; por defecto vive con la JVM) |
| **MIDlet / sesión** | sessionBegin / Running | StoppingSession → Idle |
| **GC Java** | Continuo dentro de la JVM | N/A; Swift no lo conduce |
| **Frame buffers (copia)** | Cada paint | Tras entrega a `EmulatorFrame` / consumo UI; no retenidos por Manager |
| **JNI Global refs** | Cache Gateway en Ready/Idle | Invalidación en Shutdown |
| **JNI Local refs** | Por llamada | Fin de llamada |

## 7.2 Qué permanece viva entre juegos

- La JVM.  
- Classes FreeJ2ME cargadas.  
- Global refs de infraestructura (si el Gateway las cachea).  
- Configuración de classpath / `dataPath` de proceso (sandbox).

## 7.3 Qué debe liberarse al cerrar un juego

- Bindings de `MobilePlatform` / loader / MIDlet de la sesión.  
- Global refs **de sesión** (si se crearon).  
- Local refs pendientes.  
- Cualquier buffer nativo de captura aún no entregado.  
- **No** la JVM.  
- **No** el ClassLoader bootstrap de FreeJ2ME (salvo diseño futuro de unload, fuera de este contrato).

## 7.4 Low memory

El Manager puede recibir una señal de presión de memoria vía Bootstrap (origen OS). Respuesta arquitectónica:

1. Preferir Stop de sesión y liberación de heap Java de juego.  
2. **No** destruir la JVM como primer recurso (contrario a ADR de unicidad), salvo orden explícita de proceso.  
3. Nunca pedirle al Renderer que hable con JNI.

---

# 8. Session Lifecycle

Cómo responde **EmbeddedJVMManager** (no el Bridge) ante escenarios de producto:

| Escenario | Respuesta del Manager |
|-----------|------------------------|
| **Abrir juego** | Exige Idle (o asegura Starting…Idle). Pasa a Running cuando Bootstrap declara sesión activa. |
| **Cerrar juego** | Running/Paused → StoppingSession → Idle. JVM permanece. |
| **Abrir otro juego** | Desde Idle, nuevo sessionBegin → Running. Sin `start` de JVM. |
| **Cerrar otro** | Igual que cerrar juego. |
| **Background** | No destruye JVM. Puede registrar Paused si Bootstrap propaga pause de sesión; política de throttling es del Adapter/Bootstrap, no del Manager. |
| **Foreground** | Resume de sesión si aplica; Manager solo refleja Running. |
| **Low Memory** | Ver §7.4. |
| **App Termination** | processShutdown: preferible Idle; si hay sesión, StoppingSession primero; luego Shutdown → Destroyed. |

---

# 9. Error Recovery

Comportamiento arquitectónico (sin excepciones Swift concretas):

| Fallo | Comportamiento |
|-------|----------------|
| **Fallo al crear la JVM** | Starting → Failed. JNI no usable. Bootstrap informa indisponibilidad de runtime. No reintentar en bucle infinito; reintento solo por política explícita → NotInitialized/Failed → Starting. |
| **Fallo al cargar FreeJ2ME** | LoadingFreeJ2ME → Failed (o Ready si se permite reintentar load). Contract C bloqueado. |
| **Fallo al cargar un MIDlet** | No destruye JVM. Sesión no alcanza Running estable; StoppingSession/Idle. Error sube por Bootstrap → Adapter → Bridge. |
| **Excepción Java en sesión** | Gateway la captura/normaliza; Bootstrap decide stop de sesión. Manager permanece en Running hasta stopSession o pasa a StoppingSession. |
| **Crash JNI** | Severidad alta: Failed o Destroyed. Proceso puede estar comprometido; no continuar Contract C. |
| **OOM** | Intentar stopSession y liberar; si la VM queda inutilizable → Failed. |
| **Thread perdido / deadlock** | No crear segunda JVM. Marcar Failed si el runtime no puede garantizar thread-safety. Recuperación = reinicio de **proceso app**, no de “JVM fantasma”. |

---

# 10. Performance

## 10.1 Objetivos

1. **No reiniciar JVM** entre juegos.  
2. **Minimizar cruces JNI** por frame (idealmente un cruce por paint con copia compacta).  
3. **Evitar copias innecesarias** más allá de la copia de frontera framebuffer ya exigida por arquitectura.  
4. **Mantener FreeJ2ME residente** tras LoadingFreeJ2ME.  
5. **Reutilizar** global refs de clases/métodos calientes en el Gateway.  
6. **No bloquear MainActor** con startup JVM ni con paints.  
7. **Lazy vs eager:** elegir por métrica de cold-start; ambos cumplen unicidad.

## 10.2 Anti-objetivos

- Optimizar saltándose Adapter/Host.  
- Compartir memoria Java con SwiftUI.  
- Multiplexar varias JVM para “aislamiento” de juegos.

---

# 11. Integración

## 11.1 Con PlatformBootstrap

- Único cliente autorizado del Manager en la pila de producto runtime.  
- Solicita `ensureStarted`, `loadFreeJ2ME`, notifica `sessionBegin` / pause / resume / `stopSession`, y `processShutdown`.  
- Traduce estados del Manager a éxito/fallo de métodos del protocolo `FreeJ2MEMobilePlatformBootstrapping`.

## 11.2 Con JNI Gateway

- El Manager habilita/inhabilita el Gateway según Ready/Idle/Running/Paused vs Shutdown/Destroyed/Failed.  
- El Gateway **no** crea la JVM.  
- En Shutdown, el Manager ordena al Gateway invalidar global refs y rechazar callbacks.

## 11.3 Con Embedded JVM

- El Manager es el único dueño del create/destroy.  
- Parámetros de VM (classpath, opciones headless, etc.) se aplican en Starting/LoadingFreeJ2ME bajo dirección del Bootstrap, no de la UI.

## 11.4 Integraciones prohibidas

- Views / SwiftUI  
- Library / Import Engine  
- Bridge / Host / Adapter (contacto directo)  
- Renderer  

Cualquier necesidad de esos mundos asciende/desciende solo por la cadena oficial Bridge → Host → Adapter → Bootstrap.

---

# 12. Restricciones

## Anti-patterns

Queda **prohibido**:

1. Crear más de una JVM en el proceso.  
2. Destruir la JVM al cerrar un juego (Stop de sesión).  
3. Acceder a JNI desde cualquier capa fuera de JNI Gateway (+ disciplina ordenada por Manager/Bootstrap).  
4. Compartir `JNIEnv` entre hilos.  
5. Almacenar referencias locales JNI más allá del scope de una llamada.  
6. Exponer detalles OpenJDK (`JavaVM`, opciones nativas, classpaths crudos) al resto del proyecto.  
7. Hacer que el Manager conozca SwiftUI, Library o `FreeJ2MERuntimeAdapter`.  
8. Publicar frames desde el Manager.  
9. Usar Failed como licencia para spawnear una segunda VM en paralelo a una primera a medias.  
10. Tratar `System.exit` del heap Java como Stop de sesión limpio sin política de contención (ver arquitectura padre).

---

# 13. ADR

| ID | Estado | Motivación | Consecuencia |
|----|--------|------------|--------------|
| **EJM-001** | Aceptada | Una JVM por proceso | Manager singleton lógico; Stop ≠ Destroy |
| **EJM-002** | Aceptada | Manager interno al bootstrap iOS | Invisible a Bridge/Host/Adapter público |
| **EJM-003** | Aceptada | Lazy init permitido | Primer juego puede pagar cold start; unicidad intacta |
| **EJM-004** | Aceptada | Estados de ocupación Running/Paused en el Manager | Permite políticas de recurso sin poseer `EmulatorSession` |
| **EJM-005** | Aceptada | JNI solo vía Gateway | Manager no es un “JNI kitchen sink” |
| **EJM-006** | Aceptada | Startup/shutdown en runtime executor | Protege MainActor |
| **EJM-007** | Aceptada | Fail closed ante corrupción | Preferir Failed + reinicio de proceso a VM múltiple |
| **EJM-008** | Aceptada | FreeJ2ME residente entre juegos | LoadingFreeJ2ME no se repite por MIDlet |
| **EJM-009** | Propuesta | Señal low-memory → stopSession antes que Destroy | Preserva ADR de unicidad bajo presión |
| **EJM-010** | Aceptada | Sin APIs públicas nuevas hacia producto | Cumple restricción de no inventar superficie Bridge/Host/Adapter |

---

# 14. Riesgos

## 14.1 Riesgos técnicos

- Fallo de `JNI_CreateJavaVM` / imagen estática incompleta.  
- Orden incorrecto Ready vs LoadingFreeJ2ME.  
- Callbacks Java tras Shutdown.  
- Divergencia de estados Manager vs flags del Adapter.

## 14.2 Riesgos de memoria

- Global refs filtradas entre sesiones.  
- OOM en Zero interpreter con FreeJ2ME + MIDlet.  
- Retener framebuffers en el Manager por error de diseño.

## 14.3 Riesgos de concurrencia

- Doble `ensureStarted`.  
- `JNIEnv` cruzado entre hilos.  
- Deadlock entre monitor del Manager y locks del Gateway.  
- Pause/Stop concurrentes con painter callbacks.

## 14.4 Riesgos de compatibilidad

- Classpath FreeJ2ME incompatible con la imagen mobile.  
- Necesidad de reiniciar VM ante classloader leaks de Vendor (presión contra EJM-001).  
- Diferencias simulador vs device.

## 14.5 Riesgos App Store

- Empaquetado de runtime nativo.  
- Tamaño y estabilidad en review.  
- Percepción de código interpretado (contenido de usuario vs lógica app).  
- Cumplimiento GPL-3 de FreeJ2ME (gate legal paralelo).

---

# 15. Checklist de validación

Toda implementación futura de `EmbeddedJVMManager` deberá demostrar:

- [ ] Existe **una sola** JVM por proceso de aplicación.  
- [ ] La JVM **nunca** se reinicia como parte del cierre normal de un juego.  
- [ ] Las transiciones respetan la máquina de estados de §4 (incluidas las prohibidas).  
- [ ] El componente es **thread-safe** bajo startup, sesión y shutdown concurrentes.  
- [ ] **No** rompe ni sustituye `FreeJ2MERuntimeAdapter`.  
- [ ] **No** rompe ni sustituye `FreeJ2MEMobilePlatformBootstrapping` (solo lo sirve por debajo).  
- [ ] **No** expone JNI/OpenJDK a Bridge, Host, Library, Views ni Renderer.  
- [ ] JNIEnv no se comparte entre hilos; local refs no se almacenan.  
- [ ] Stop de sesión → Idle; Terminate app → Shutdown → Destroyed.  
- [ ] Frames no fluyen a través del Manager.  
- [ ] Fallos de creación/carga se degradan sin spawnear JVM adicionales.  
- [ ] Compatible con `docs/Architecture/EMBEDDED_JVM_ARCHITECTURE.md` y anti-patterns allí definidos.  
- [ ] Compatible con el estudio de viabilidad OpenJDK Mobile como hipótesis de runtime.  
- [ ] No introduce APIs públicas nuevas en Bridge / Host / Adapter.  
- [ ] Verificable con tests de estado (unicidad, stop≠destroy, shutdown) sin acoplar SwiftUI.

---

## Cierre

`EmbeddedJVMManager` es el **dueño exclusivo del ciclo de vida de la JVM embebida** en iOS.

Cualquier PR que cree múltiples VM, destruya la VM al cambiar de juego, filtre JNI hacia producto, o bypass PlatformBootstrap **viola este contrato** y debe rechazarse en revisión de arquitectura.

---

*Referencia oficial · EmbeddedJVMManager v1.0 · JavaOne*
