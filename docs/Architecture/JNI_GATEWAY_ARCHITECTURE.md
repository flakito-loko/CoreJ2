# JNI Gateway — Architecture

**Estado:** Contrato oficial de componente (diseño)  
**Versión:** 1.0  
**Fecha:** 2026-08-04  
**Epic:** Epic 2 — JNI Gateway Architecture  
**Padre arquitectónico:** `docs/Architecture/EMBEDDED_JVM_ARCHITECTURE.md`  
**Contrato hermano:** `docs/Architecture/EMBEDDED_JVM_MANAGER.md`  
**Roadmap:** Fase 2 — Spike JNI (`docs/Architecture/IMPLEMENTATION_ROADMAP.md`)

**Naturaleza**

Este documento es la **especificación de ingeniería** del rol `JNIGateway`.  
**No es código.** No define Objective-C++. No invoca FreeJ2ME. No modifica `EmbeddedJVMManager`.  
Toda implementación futura del camino iOS embebido debe cumplir este contrato.

---

# 0. Posición en la pila

```
Library / SwiftUI / Views
        │
        ▼
EmulatorBridge
        │
        ▼
RuntimeHost
        │
        ▼
FreeJ2MERuntimeAdapter
        │
        ▼
FreeJ2MEMobilePlatformBootstrapping   (backend iOS)
        │
        ├── EmbeddedJVMManager          ← dueño de la JVM (una por proceso)
        │
        └── JNIGateway                  ← ÚNICO componente autorizado a JNI
                │
                ▼
              JNI API
                │
                ▼
         Embedded JVM (OpenJDK Mobile)
                │
                ▼
              Java heap
```

**Cadena de comunicación (obligatoria):**

```
Swift (Bootstrap iOS)
  → consulta/estado EmbeddedJVMManager   (¿JNI usable?)
  → opera solo vía JNIGateway            (invocaciones / callbacks)
      → JNI (Attach / FindClass / Call* / New* / Delete*)
          → Java
```

`EmbeddedJVMManager` **no** ejecuta Contract C ni FindClass/Call.  
`JNIGateway` **no** crea ni destruye la JVM.  
Ninguna capa por encima de PlatformBootstrap ve `JNIEnv`, `jobject`, `jclass` ni `JavaVM*`.

---

# 1. Responsabilidades de JNIGateway

## 1.1 Qué hace

1. Ser el **único** componente CoreJ2 autorizado a llamar la API JNI.  
2. Traducir operaciones semánticas del **PlatformBootstrap iOS** a invocaciones Java (métodos/campos).  
3. Recibir **callbacks nativos** originados en hilos Java (p. ej. painter futuro) y entregarlos al Bootstrap como datos owned (buffers, códigos), **sin** filtrar `JNIEnv` hacia arriba.  
4. Aplicar disciplina de hilos: attach/detach; **nunca** compartir `JNIEnv` entre hilos.  
5. Gestionar **local refs** (scope de llamada) y **global refs** de infraestructura (cache de clases/métodos de vida larga).  
6. Convertir strings y arrays/buffers en la frontera Swift ↔ Java según políticas de §9–§10.  
7. Capturar excepciones Java pendientes, limpiarlas y mapearlas a errores de dominio del Bootstrap (§5, §8).  
8. Respetar la habilitación del Manager: solo operar cuando el Manager declara borde JNI usable (`Ready` / `Idle` / `Running` / `Paused` según fase); rechazar tras `Shutdown` / `Destroyed` / `Failed`.  
9. Invalidar caches y rechazar callbacks cuando el Manager ordena teardown.

## 1.2 Qué no hace

| Prohibido | Motivo |
|-----------|--------|
| Crear / destruir la JVM | Ownership de `EmbeddedJVMManager` |
| Conocer Bridge, Host, Adapter público, Library, Views, SwiftUI | Anti-acoplamiento |
| Poseer `EmulatorSession` o publicar `RuntimeEvent` | Ownership Bridge / Host |
| Renderizar frames o conocer CGImage/SwiftUI | Renderer |
| Importar / hashear juegos | Library / Import |
| Orquestar Contract C completo (CREATE/PAINTER/LOAD/RUN/STOP) | PlatformBootstrap |
| Exponer `JNIEnv*` / `jobject` fuera del Runtime embebido | Opacidad |
| Cargar FreeJ2ME por sí mismo como política de producto | Bootstrap + Manager (`LoadingFreeJ2ME`) |
| Sustituir el spike Phase-1 `HelloWorld` como API de producto | Spike ≠ Gateway |

## 1.3 Relación con el spike Phase 1

La invocación puntual de `HelloWorld.main` embebida en nativo de Fase 1 fue un **harness de prueba**, no el Gateway.  
Al implementar este contrato, **toda** invocación JNI de producto (incluida la de spikes posteriores) debe pasar por `JNIGateway`. El Manager permanece dueño solo de create/destroy VM.

---

# 2. Public API (contrato conceptual)

La API es **interna** al backend iOS de PlatformBootstrap. No es superficie Bridge/Host/Adapter.

Los nombres siguientes son **roles**; la implementación puede usar Swift protocols + backend nativo opaco, sin filtrar tipos JNI.

## 2.1 Ciclo de borde

| Operación | Semántica | Precondiciones |
|-----------|-----------|----------------|
| `bind(to manager readiness)` | Asociar Gateway al proceso JVM ya creado; construir caches iniciales si aplica | Manager ≥ `Ready` |
| `invalidate()` | Soltar global refs; marcar Gateway no usable | Ordenado por Manager en `Shutdown` / `Failed` / `Destroyed` |
| `isUsable() → Bool` | Consulta consistente con el Manager | — |

## 2.2 Invocación síncrona (Bootstrap → Java)

| Operación | Semántica |
|-----------|-----------|
| `callStatic(classId, methodId, args) → Result` | Llamada estática tipada vía IDs opacos cacheados |
| `callInstance(objectId, methodId, args) → Result` | Llamada de instancia |
| `get/setStaticField` / `get/setField` | Acceso a campos cuando el Bootstrap lo necesite |
| `resolveClass(binaryName) → ClassId` | Resolución controlada (p. ej. spike Fase 2: clase hello / utilitaria CoreJ2-owned) |
| `resolveMethod` / `resolveField` | Obtención de IDs; preferible cachear como Global |

Los `ClassId` / `MethodId` / `ObjectId` son **handles opacos** del Gateway.  
El Bootstrap no recibe `jclass`/`jmethodID` crudos.

## 2.3 Callbacks (Java → Bootstrap)

| Operación | Semántica |
|-----------|-----------|
| `registerNative(classId, methodName, signature, trampoline)` | Registra implementación nativa **dentro** del Gateway |
| Entrega a Bootstrap | El trampoline copia datos a tipos owned (`Data`, structs) y llama un closure/`frameHandler`-like del Bootstrap en cola de runtime — **nunca** MainActor de forma bloqueante indefinida |

En Epic 2 / Fase 2 el callback puede limitarse a return values síncronos; el registro de natives para painter queda especificado aquí para no romper el diseño al llegar Contract C.

## 2.4 Quién puede llamar

| Cliente | ¿Permitido? |
|---------|-------------|
| Backend iOS de `FreeJ2MEMobilePlatformBootstrapping` | **Sí** (único cliente de producto) |
| `EmbeddedJVMManager` | Solo para señalizar usable/invalidar — **no** para FindClass/Call de negocio |
| Adapter / Host / Bridge / Views / Library | **No** |
| Tests de spike aislados | Sí, detrás del mismo protocolo, sin App Target wiring |

---

# 3. Ownership rules

| Recurso | Poseedor | Quién libera |
|---------|----------|--------------|
| **JavaVM\*** | `EmbeddedJVMManager` | Manager en Destroy |
| **JNIEnv\* (por hilo)** | Hilo attached; coordinado por Gateway | Detach al fin del uso del hilo (o política de hilo dedicado) |
| **Global JNI refs** (clases/métodos/infra) | Gateway | `invalidate()` en Shutdown / Failed |
| **Global refs de sesión** (objetos FreeJ2ME de un juego) | Gateway bajo dirección del Bootstrap | Stop de sesión → liberar; **no** Destroy JVM |
| **Local refs** | Scope de una invocación Gateway | Fin de scope (`PopLocalFrame` / delete explícito) |
| **Buffers de frame (copia nativa)** | Productor Gateway → `frameHandler` Bootstrap → Adapter | Cadena hacia `EmulatorFrame`; Gateway no retiene tras entrega |
| **Handles opacos Swift** | Bootstrap / Gateway | Invalidación al soltar global ref subyacente |
| **EmulatorSession / RuntimeEvent** | Bridge / Host | Fuera del Gateway |

**Reglas:**

1. Stop de sesión **no** invalida el Gateway completo; solo refs de sesión.  
2. Destroy de JVM **sí** invalida el Gateway completo.  
3. El Gateway nunca almacena `JNIEnv` en propiedades de larga vida.  
4. El Manager nunca almacena global refs JNI.

---

# 4. Threading model

## 4.1 Principios

1. **Un `JNIEnv` por hilo attached.** Prohibido usar un env obtenido en el hilo A desde el hilo B.  
2. **Hilos de llamada Bootstrap → Java:** cola/serial executor de runtime (“JNI call threads” / mismo pool que el Manager permite para no bloquear MainActor).  
3. **Hilos Java → nativo:** el trampoline hace `GetEnv` / `AttachCurrentThread` según estado; copia datos; **no** reentra al Manager sin su monitor; entrega al Bootstrap de forma asíncrona segura.  
4. **MainActor / UI:** nunca JNI directo; nunca attach bloqueante prolongado en MainActor.  
5. **Serialización:** operaciones que mutan caches de global refs se serializan en un monitor interno del Gateway compatible con el monitor del Manager (evitar deadlock: orden de locks documentado — preferir **no** retener lock del Manager mientras se ejecuta JNI largo).

## 4.2 Attach / Detach

| Situación | Política |
|-----------|----------|
| Hilo creado por Gateway/Bootstrap para Call* | Attach al inicio del batch; Detach al fin del batch (o hilo dedicado permanente attached mientras `isUsable`) |
| Callback desde hilo Java ya managed por la VM | `GetEnv`; si detached, Attach; no Detach el hilo de la VM si es hilo Java permanente — solo hilos nativos “visitantes” |
| Tras `invalidate()` | Ningún attach nuevo; callbacks rechazados |

## 4.3 Relación con estados del Manager

| Estado Manager | Gateway |
|----------------|---------|
| `NotInitialized` / `Starting` | No usable |
| `Ready` | Usable para spike / resolución de clases (sin FreeJ2ME) |
| `LoadingFreeJ2ME` | Usable solo para operaciones de carga ordenadas por Bootstrap |
| `Idle` / `Running` / `Paused` / `StoppingSession` | Usable según semántica Bootstrap |
| `Shutdown` / `Destroyed` / `Failed` | `invalidate()`; rechazar |

## 4.4 Prohibiciones

- Compartir `JNIEnv` entre hilos.  
- Llamar JNI desde Views.  
- Registrar trampolines que llamen Bridge/Host.  
- Hacer `ensureStarted` del Manager desde un callback Java sin pasar por Bootstrap.

---

# 5. Error mapping

| Origen | Comportamiento Gateway | Hacia Bootstrap |
|--------|------------------------|-----------------|
| Manager no usable | No llamar JNI | Error tipado `runtimeUnavailable` / `gatewayInvalidated` (nombre interno) |
| `FindClass` / `GetMethodID` null + excepción | `ExceptionDescribe` opcional en debug; `ExceptionClear`; liberar locals | `classNotFound` / `methodNotFound` |
| `Call*` con excepción Java pendiente | Clear + capturar nombre/mensaje vía APIs JNI de Exception | `javaException(type, message)` normalizado — **sin** filtrar stack traces crudos a UI |
| Attach fallido | Fallo inmediato | `threadAttachFailed` |
| OOM / `PushLocalFrame` fail | Abortar operación; clear | `resourceExhausted` |
| Crash / abort nativo | Fuera de mapeo; proceso comprometido | Manager → `Failed` |

**Regla:** el Gateway **nunca** propaga tipos JNI ni `jthrowable` al Adapter/Host/Bridge. Solo errores de dominio del Bootstrap, que el Adapter ya sabe mapear a `EmulatorBridgeError` cuando exista wiring.

---

# 6. Object lifetime

```
CreateJavaVM (Manager)
      │
      ▼
Gateway.bind → caches Global (clases/métodos infra)
      │
      ▼
[Sesión] Global/session refs + locals por llamada
      │  stopSession
      ▼
Liberar session globals; locals ya liberados
      │  processShutdown
      ▼
Gateway.invalidate → DeleteGlobalRef all
      │
      ▼
DestroyJavaVM (Manager)
```

- Objetos Java de sesión (p. ej. futuros `MobilePlatform`) viven en el heap; el Gateway solo retiene **refs** mientras Bootstrap las necesite.  
- Tras Stop, el heap puede conservar clases FreeJ2ME (política Manager); las **refs de sesión** del Gateway deben caer.  
- No usar local refs como “cache” entre llamadas.

---

# 7. Global / local JNI references

## 7.1 Local refs

- Creadas implícitamente por casi toda API JNI que retorna `jobject`/`jclass`/`jarray`.  
- **Scope máximo:** una invocación pública del Gateway (o un `PushLocalFrame`/`PopLocalFrame` anidado).  
- Prohibido almacenar en propiedades Swift/ivar del Gateway.  
- Preferir `PushLocalFrame` al inicio de Call\* batch y `PopLocalFrame` al salir (éxito o error).

## 7.2 Global refs

| Uso | ¿Global? | Vida |
|-----|----------|------|
| `jclass` de clases calientes | Sí | Hasta `invalidate` |
| `jmethodID` / `jfieldID` | No son refs; cacheables una vez resueltos con clase global viva | Hasta invalidate / unload |
| Objeto sesión (platform instance) | Sí, si se retiene entre llamadas | Hasta stopSession |
| Framebuffer Java | No retener; copiar a nativo y soltar locals | Por paint |

## 7.3 Weak global refs

Opcionales para caches especulativos; **no** requeridos en Fase 2. Si se usan, fallar cerrado si la resolución weak es null.

---

# 8. Exception handling

1. Tras cada Call\*/New\* relevante: `ExceptionCheck`.  
2. Si hay excepción: leer tipo/mensaje mínimos necesarios para mapeo; **siempre** `ExceptionClear` antes de retornar al Bootstrap.  
3. No dejar excepciones pendientes al cruzar hacia Swift.  
4. No invocar más JNI (salvo APIs seguras de excepción) con excepción pendiente.  
5. En callbacks nativos: igual disciplina; si falla el mapeo, notificar Bootstrap y no re-lanzar a Java sin política explícita (`ThrowNew` solo si el contrato Java lo exige).

---

# 9. String conversion strategy

| Dirección | Estrategia |
|-----------|------------|
| Swift `String` → Java | Modificar UTF-16 / `NewString` (UTF-16) preferente para fidelidad Unicode; evitar asumir UTF-8 modificado salvo APIs que lo requieran |
| Java `String` → Swift | `GetStringChars` o `GetStringUTFChars` según API elegida; copiar a `String` Swift; **Release\*** siempre |
| Paths sandbox / file URLs | Normalizar a path absoluto string en Bootstrap; Gateway solo transporta string |

**Reglas:**  
- Nunca retener punteros de `GetString*Chars` más allá del scope.  
- Fallo de conversión → error de dominio, no crash.  
- Para Fase 2 (suma / echo string): suficiente round-trip UTF-16 o UTF-8 modificado documentado en el spike.

---

# 10. Array / buffer transfer strategy

| Caso | Estrategia |
|------|------------|
| Arrays primitivos pequeños (spike) | `New*Array` + `Set*ArrayRegion` / `Get*ArrayRegion` (copia explícita) |
| Framebuffer futuro (Contract C) | Preferir **una** copia compacta Java→nativo por paint (`GetIntArrayRegion` o critical section de corta duración); **prohibido** compartir puntero Java con SwiftUI |
| Critical (`GetPrimitiveArrayCritical`) | Solo si se mide beneficio; duración mínima; sin JNI anidado / sin blocking |
| Direct `ByteBuffer` | Opcional más adelante; no requerido en Fase 2 |
| Ownership post-copia | Buffer nativo owned por Bootstrap/`frameHandler`; Java array no se pinnea |

**Anti-patrón:** cero-copia hacia Views; mmap compartido UI↔heap Java.

---

# 11. Performance considerations

1. **Minimizar cruces JNI** por operación de producto (objetivo arquitectura: ~1 cruce/paint con copia compacta).  
2. **Cachear** `jclass`/`jmethodID` en globals; no `FindClass` por frame.  
3. **No** reiniciar JVM entre juegos (Manager).  
4. **No** bloquear MainActor.  
5. Serializar Calls en cola dedicada para predecibilidad bajo Zero interpreter.  
6. Medir en spikes: latencia Call\* round-trip, RSS, local-ref pressure.  
7. Invalidación completa solo en Shutdown — no “reiniciar Gateway” por Stop de sesión.

---

# 12. Testing strategy

## 12.1 Sin FreeJ2ME (Fase 2)

| Test | Verifica |
|------|----------|
| Round-trip estático (p. ej. `add(int,int)` / echo `String`) | Call\* + conversión |
| Gateway usable solo tras Ready | Precondiciones Manager |
| `invalidate` tras Destroy | Rechazo post-teardown |
| Stress attach en 2+ hilos | No compartir `JNIEnv` (TSan / asserts) |
| Exception Java → error dominio | Clear + mapeo |
| Local frame leak test | Contador/diagnóstico en debug builds |

## 12.2 Concurrencia

- Dos Calls concurrentes en hilos distintos → cada uno su env.  
- Callback simulado desde hilo secundario → entrega ordenada al Bootstrap sin deadlock con Manager.

## 12.3 No-tests

- No tests de UI/Bridge.  
- No carga FreeJ2ME en Epic 2.  
- No App Target wiring obligatorio: harness aislado aceptable (como Fase 1/1.5).

## 12.4 Criterio de salida Fase 2

- Round-trip documentado.  
- Gateway inválido tras Destroyed.  
- Sin exposición JNI a Views/Bridge.  
- Thread rules del Manager respetadas.

---

# 13. Flujo detallado Swift → Java

## 13.1 Ida (Bootstrap → Java)

```
1. Bootstrap necesita una operación semántica (spike: "invoke hello util").
2. Bootstrap consulta Manager / Gateway.isUsable().
3. Si no usable → error tipado; fin.
4. Bootstrap llama JNIGateway.callStatic(... handles opacos / args Swift).
5. Gateway (en hilo runtime):
   a. Attach/GetEnv
   b. PushLocalFrame
   c. Resolve desde cache Global (o populate cache)
   d. Convertir args (strings/arrays)
   e. CallStatic*
   f. ExceptionCheck → mapear o continuar
   g. Convertir valor de retorno a tipo owned Swift
   h. PopLocalFrame / Release strings
6. Retorno al Bootstrap sin tipos JNI.
```

## 13.2 Vuelta (Java → Bootstrap) — diseño futuro painter

```
1. Hilo Java invoca native method registrado por Gateway.
2. Trampoline Gateway:
   a. GetEnv
   b. Copiar píxeles/payload a buffer owned
   c. ExceptionClear si aplica
   d. Encolar entrega a frameHandler/closure del Bootstrap (off MainActor)
3. Bootstrap → Adapter → Host pipe (fuera del Gateway).
4. Gateway no retiene el buffer tras handoff.
```

## 13.3 Shutdown

```
1. Manager entra en Shutdown.
2. Manager ordena Gateway.invalidate().
3. Gateway: rechaza Calls; DeleteGlobalRef; marca unusable.
4. Manager DestroyJavaVM.
```

---

# 14. ADR (Gateway)

| ID | Estado | Motivación | Consecuencia |
|----|--------|------------|--------------|
| **JGW-001** | Aceptada | JNI solo en Gateway | Manager ≠ kitchen-sink JNI; capas producto opacas |
| **JGW-002** | Aceptada | Handles opacos | Sin `jobject` en Bootstrap API pública interna tipada como JNI |
| **JGW-003** | Aceptada | Local refs por scope | Push/PopLocalFrame por Call batch |
| **JGW-004** | Aceptada | Global refs para infra | Cache FindClass/GetMethodID |
| **JGW-005** | Aceptada | Copia en frontera de frames | No memoria compartida UI↔Java |
| **JGW-006** | Aceptada | Errores de dominio | No `jthrowable` hacia Adapter |
| **JGW-007** | Aceptada | Cliente único = Bootstrap iOS | Adapter no conoce Gateway |
| **JGW-008** | Aceptada | Fase 2 sin FreeJ2ME | Spike de disciplina antes de Vendor |
| **JGW-009** | Aceptada | Stop ≠ invalidate total | Solo session refs en Stop |
| **JGW-010** | Aceptada | Off MainActor | Alineado a EJM-006 |

---

# 15. Riesgos residuales

| ID | Riesgo | Mitigación |
|----|--------|------------|
| R1 | Deadlock Manager↔Gateway | Orden de locks; no JNI largo bajo monitor Manager |
| R2 | Local ref table overflow | PushLocalFrame; tests de leak |
| R3 | Callback tras invalidate | Flag usable atómico; drop |
| R4 | Critical array mal usado | Preferir Get\*ArrayRegion en v1 |
| R5 | Filtrado accidental de JNI a Adapter | Review + API opaca; tests de compilación |
| R6 | Divergencia macOS Process vs iOS Gateway | Mismo Contract C en Bootstrap; Gateway solo iOS |

Ninguno de estos riesgos requiere un spike **previo** distinto de la propia **Fase 2** ya planificada: Fase 1/1.5 ya demostró `JNI_CreateJavaVM` + invoke Java + destroy con OpenJDK Mobile.

---

# 16. Fuera de alcance de este documento

- Implementación Objective-C++ / Swift.  
- Registro real de painter FreeJ2ME.  
- Cambios a `EmbeddedJVMManager`, Bridge, Host, Adapter, UI, Library.  
- Empaquetado App Target.  
- JNI Gateway en macOS Process (macOS sigue Process persistente).

---

# Cierre

`JNIGateway` es el **único borde JNI** del runtime embebido iOS.  
`EmbeddedJVMManager` posee la VM; el Gateway posee la disciplina de invocación y referencias; el Bootstrap posee Contract C; el Adapter/Host/Bridge permanecen ajenos a JNI.

## Approved for implementation

*Referencia oficial · JNI Gateway Architecture v1.0 · CoreJ2 · Epic 2*
