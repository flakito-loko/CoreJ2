# Estudio de viabilidad: JVM embebida en iOS para FreeJ2ME

**Tipo:** Investigación / arquitectura (sin implementación)  
**Fecha:** 2026-08-04  
**Audiencia:** Ingeniería CoreJ2  
**Alcance:** Ejecutar FreeJ2ME dentro de una app iOS distribuible por App Store, **sin alterar** la arquitectura existente (Bridge → Host → Adapter → PlatformBootstrap).

**Contexto CoreJ2:**

- macOS ya tiene JVM persistente vía `PersistentProcessFreeJ2MEMobilePlatformBootstrap` + `PersistentMobilePlatformDaemon`.
- iOS hoy falla de forma tipada con `EmulatorBridgeError.runtimeUnavailable` (sin `Process` / sin JDK host).
- FreeJ2ME asume Java SE (AWT `BufferedImage`, ASM/`defineClass`, Java Sound, `System.exit`, etc.). Ver `docs/FREEJ2ME_ASSESSMENT.md` y `docs/E5_US003_PERSISTENT_RUNTIME_DESIGN.md`.

---

## Resumen ejecutivo

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Hay JVM real en iOS App Store? | **Sí, con matices:** OpenJDK Mobile (Zero interpreter, builds estáticos) es la vía oficial más creíble en 2025–2026; no es HotSpot JIT. |
| ¿OpenJDK Mobile es viable para CoreJ2? | **Viable como spike técnico**, no como “enchufar y listo”. Cubre bytecode + JNI; **no garantiza** AWT headless completo ni el perfil SE que FreeJ2ME necesita. |
| ¿`libjvm` estática? | **Sí:** el árbol `openjdk/mobile` documenta `make … static-libs-image` → `libjvm.a` (variante Zero en device). |
| ¿Compatible con “no JIT”? | **Sí, por diseño:** Zero interpreta bytecode; no genera código nativo en runtime. Rendimiento limitado; Leyden/AOT es la evolución esperada. |
| ¿Encaje con PlatformBootstrap? | **Sí, sin romper capas:** nuevo backend iOS de `FreeJ2MEMobilePlatformBootstrapping` (JNI/FFI in-process) paralelo al Process persistente de macOS. |
| ¿Recomendación? | **Adoptar OpenJDK Mobile (Zero + static) como hipótesis principal** y ejecutar un spike M9 acotado (hello JNI → headless AWT/`BufferedImage` → `defineClass` → Contract C). En paralelo, plan B: fork allowlisted de backends gráficos/audio si AWT no cierra. |

**Veredicto:** Embebido in-process es la única topología alineada con App Store y con la arquitectura CoreJ2. No hay camino serio con `Process`/`java` hijo en iOS. El riesgo dominante **no** es “¿existe libjvm?”, sino **¿FreeJ2ME corre sobre el subconjunto SE + AWT que ese JVM ofrece?**

---

## 1. Opciones reales para ejecutar una JVM (o Java) en iOS

### 1.1 Matriz de opciones (2026)

| Opción | Qué es | App Store | Encaje FreeJ2ME | Madurez |
|--------|--------|-----------|-----------------|---------|
| **A. OpenJDK Mobile (Zero + static/`libjvm`)** | Downstream oficial OpenJDK con parches iOS; intérprete Zero en device; builds estáticos documentados | Históricamente hay apps que empaquetaron OpenJDK (p. ej. editores/IDE); requiere packaging cuidadoso (frameworks, rutas, bitcode legacy) | Mejor candidato a “JVM real” + JNI hacia Vendor | **Activa** (Gluon/OpenJDK Mobile 2025+); aún infraestructura, no producto plug-and-play |
| **B. Gluon Mobile / GraalVM Native Image (AOT)** | Compila Java → binario nativo; a menudo JavaFX | Producto comercial/orientado a apps Java UI | FreeJ2ME + ASM dinámico + `defineClass` en runtime **chocan** con AOT cerrado; MIDlets son JARs desconocidos en build time | Maduro para *apps* Java propias; **malo** para emular JARs arbitrarios |
| **C. Intérprete / runtime propietario o legacy (RoboVM-era, forks)** | AOT parcial + runtime | Variable; muchos abandonados | Misma tensión AOT vs carga dinámica de MIDlets | **Legacy / alto riesgo de mantenimiento** |
| **D. Multi-OS Engine (Intel ART-like)** | Runtime estilo ART para iOS desde Android Studio | Histórico; ecosistema en declive | No es HotSpot SE; portabilidad FreeJ2ME dudosa | **No recomendable** como base nueva |
| **E. Proceso hijo `java` (como macOS)** | `Foundation.Process` + JDK | **No viable** en iOS app sandbox / APIs | Igual que macOS host | **Descartado** para device |
| **F. Reescritura nativa / sin JVM** | Portar MIDP a Swift/C++ | Compatible | Abandona FreeJ2ME Vendor “casi intacto”; contradice la estrategia actual | Solo si el spike JVM falla |
| **G. Codificar FreeJ2ME a WASM / otro VM** | Capas de traducción | Posible pero experimental | Doble emulación + coste enorme | **Fuera de alcance razonable** |

### 1.2 Conclusión de opciones

Para CoreJ2 (emular **JARs MIDlet arbitrarios** con FreeJ2ME):

1. **Prioridad 1:** OpenJDK Mobile in-process (opción A).  
2. **Prioridad 2 (si AWT/`defineClass` fallan):** mismo JVM + **fork allowlisted** de backends FreeJ2ME (gráficos/audio), sin cambiar Bridge/Host.  
3. **No priorizar:** Gluon AOT como runtime de MIDlets dinámicos; Process hijo; Multi-OS Engine.

---

## 2. ¿OpenJDK Mobile es una opción viable?

### 2.1 Qué es hoy

- Repositorio downstream oficial: [`openjdk/mobile`](https://github.com/openjdk/mobile).  
- Sitio de coordinación: [openjdk-mobile.github.io](https://openjdk-mobile.github.io/).  
- Objetivo: parches mínimos para JVM + class libraries en iOS/Android, con intención de upstream.  
- Gluon ha invertido en pipelines, docs y builds estáticos (InfoQ, nov 2025).

### 2.2 Fortalezas para CoreJ2

- **JVM real** (HotSpot familia) con variante **Zero** en device → cumple la restricción de no generar código en runtime.  
- Documentación explícita de **imagen de librerías estáticas** (`libjvm.a`).  
- Camino natural a **JNI**: el Adapter/Bootstrap pueden llamar a un façade C/JNI que invoque las mismas clases FreeJ2ME que el daemon macOS.  
- Alineado con “no cambiar la arquitectura”: solo cambia la **implementación** de `FreeJ2MEMobilePlatformBootstrapping` en iOS.

### 2.3 Debilidades / gaps

| Gap | Impacto en FreeJ2ME |
|-----|---------------------|
| Zero = interpretación | FPS/CPU peores que desktop HotSpot; emulación jugable incierta |
| Headless / AWT | FreeJ2ME usa `BufferedImage` / `Graphics2D`. Hay que **probar** `--enable-headless-only` y el subset AWT disponible |
| `SecurityManager` | Deprecado/eliminado en JDKs modernos; `System.exit` in-process puede matar la **app** |
| ASM + `defineClass` | MIDletLoader reescribe bytecode; el runtime debe permitir definición dinámica de clases |
| Java Sound / MIDI | Audio FreeJ2ME no es AVAudioEngine |
| Tamaño del bundle | JDK estático + FreeJ2ME + resources → decenas–centenas de MB |
| Madurez de tooling | “Infraestructura en construcción”, no SDK de producto con soporte SLA |

### 2.4 Veredicto OpenJDK Mobile

**Sí es la mejor opción realista de JVM embebida App Store-oriented en 2026**, condicionada a un **spike de compatibilidad FreeJ2ME** (no solo “hello world” JNI).  
No se debe tratar como decisión cerrada de producto hasta que el spike demuestre: platform + painter + `loadJar` + `runJar` + al menos un frame LCD.

---

## 3. ¿Puede compilarse como biblioteca estática (`libjvm`)?

**Sí.** El propio `openjdk/mobile` documenta el flujo:

1. Configurar target `aarch64-macos-ios` (device) o simulador.  
2. Variante JVM por defecto en iOS device: **Zero**.  
3. Dependencias de soporte (p. ej. **libffi**, cups headers en los zips de soporte Gluon).  
4. `make CONF=ios-aarch64-zero-release static-libs-image`  
5. Salida típica: `build/.../images/static-libs/lib/zero/libjvm.a` (más otras libs estáticas del JDK según el layout de imagen).

**Implicaciones de packaging App Store:**

- Enlazar estáticamente reduce fricción de `dylib` sueltas, pero el JDK también puede producir/necesitar otras libs y recursos (`lib/` modules, configs).  
- Experiencias pasadas (p. ej. empaquetado OpenJDK 8 en App Store) muestran que **rutas de carga**, `Frameworks/`, y `dlopen` desde extensiones son puntos de rechazo frecuentes si se hace mal.  
- Plan de integración CoreJ2: un **Xcode target / xcframework** “CoreJ2JVM” owned por el equipo, consumido solo desde `Features/Emulator/Runtime/` — nunca desde Views.

---

## 4. ¿Qué dependencias requiere?

### 4.1 Build-time (host macOS)

| Dependencia | Rol |
|-------------|-----|
| Xcode + iOS SDK | sysroot, clang, codesign |
| Boot JDK (versión alineada al árbol mobile, p. ej. JDK 21–24 según docs del repo) | Bootstrap del build OpenJDK |
| `autoconf` / toolchain OpenJDK | `configure` + `make` |
| **libffi** (build iOS) | Zero necesita FFI para calls nativos |
| Soporte cups/headers (según zip Gluon / docs mobile) | Configure del JDK |
| Espacio disco + tiempo CI | Builds JDK son pesados; cachear artefactos |

### 4.2 Runtime (dentro de la app)

| Dependencia | Rol |
|-------------|-----|
| `libjvm` (+ libs JDK estáticas/dinámicas permitidas) | Ejecutar bytecode |
| Classpath / modules FreeJ2ME + bootstrap CoreJ2 | Contract C |
| Recursos JDK (si la imagen los exige) | Locales, configs, security |
| JNI façade CoreJ2 | CREATE/PAINTER/LOAD/RUN/STOP hacia clases Java |
| (Opcional) libffi enlazada | Si Zero la requiere en link final |

### 4.3 Dependencias “de producto” FreeJ2ME (no son del JVM, pero bloquean)

- AWT headless / `BufferedImage`  
- Capacidad de **class loading dinámico** para JARs de usuario  
- Estrategia para **audio** y **RMS (`dataPath`)**  
- Trampa de **`System.exit`**

---

## 5. ¿Es compatible con las restricciones de Apple (sin JIT)?

### 5.1 Regla relevante

En **iOS device**, Apple no permite el modelo clásico de JIT (memoria escribible y ejecutable para código generado en runtime) del modo en que HotSpot lo necesita. El template interpreter de HotSpot también implica generación dinámica de stubs.

### 5.2 Cómo OpenJDK Mobile responde

- **Device:** JVM variant **Zero** — intérprete en C/C++, **sin** emitir código máquina en runtime.  
- **Simulator (x64/arm64 macOS):** a menudo se puede usar otras variantes (p. ej. server) para desarrollo; **no** es la configuración de App Store.  
- Estrategia a medio plazo citada por el ecosistema (Gluon/Leyden): Zero + **AOT/Leyden** para métodos calientes, sin JIT clásico.

### 5.3 Implicación para CoreJ2

| Aspecto | Evaluación |
|---------|------------|
| Cumplimiento “no JIT” con Zero | **Compatible en principio** |
| Rendimiento emulación | **Riesgo alto** (intérprete + FreeJ2ME + ASM) |
| Entitlement `allow-jit` (Hardened Runtime) | Es historia de **Mac**, no una licencia para JIT libre en iOS App Store apps |
| Código interpretado / JARs de usuario | Revisar guideline de **código descargado/interpretado** (juegos emulados suelen argumentar “contenido del usuario”, no app logic remota) — riesgo de review, no solo técnico |

---

## 6. Integración con `PlatformBootstrap` sin romper la arquitectura

### 6.1 Invariantes a preservar

```
Library / SwiftUI
  → EmulatorBridgeProtocol
    → RuntimeHostProtocol (FreeJ2MERuntimeHost)
      → FreeJ2MERuntimeAdapter   // único que “conoce” FreeJ2ME
        → FreeJ2MEMobilePlatformBootstrapping
             ├─ macOS: PersistentProcess… (ya existe)
             └─ iOS:   EmbeddedOpenJDK… (nuevo, futuro)
```

**No cambiar:**

- `EmulatorBridgeProtocol`  
- `RuntimeHostProtocol`  
- Superficie pública del Adapter  
- Library / Import Engine  
- Vendor FreeJ2ME (salvo fork allowlisted explícito más adelante)

### 6.2 Diseño del backend iOS (solo conceptual)

Nuevo tipo, p. ej. `EmbeddedOpenJDKMobilePlatformBootstrap`, que:

1. En `bootstrapMobilePlatform`: asegura JVM arrancada **una vez por proceso app** (o por sesión) vía JNI `JNI_CreateJavaVM` / API equivalente del build static.  
2. Implementa los mismos comandos semánticos que el daemon persistente (CREATE / PAINTER / LOAD / RUN / STOP), pero **in-process** (invocación directa de clases `org.recompile.mobile.*` + fachada CoreJ2).  
3. Publica frames por el mismo `frameHandler` ya existente en el protocolo.  
4. `shutdownRuntime()` destruye sesión Java; la JVM puede quedarse viva (reuso) o destruirse (más simple al inicio).

Selección en DI (sin cambiar contratos):

```text
#if os(iOS)
  Persistent/Embedded bootstrap
#else
  Persistent Process bootstrap (actual)
#endif
```

o factory en `AppDependencyContainer` que elija la implementación concreta de `FreeJ2MEMobilePlatformBootstrapping`.

### 6.3 Threading (alineado a E5-US003)

- Hilos Java FreeJ2ME ≠ MainActor.  
- Callbacks JNI → cola “FreeJ2MERuntime” → hop a MainActor solo para `RuntimeEventPipe` / UI.  
- Nunca bloquear MainActor con `AttachCurrentThread` + trabajo largo.

### 6.4 Qué NO hacer

- No acoplar SwiftUI al JNI.  
- No hacer que el Host conozca `JNIEnv`.  
- No spawn de `Process` en iOS “por si acaso”.  
- No meter OpenJFX solo para FreeJ2ME (superficie incorrecta).

---

## 7. Riesgos técnicos

| ID | Riesgo | Severidad | Mitigación |
|----|--------|-----------|------------|
| T1 | AWT/`BufferedImage` incompleto en build mobile headless | **Crítica** | Spike dedicado; si falla → fork gráfico allowlisted (painter lee buffer propio) |
| T2 | `defineClass` / ASM bloqueado o frágil | **Crítica** | Spike con ProbeMIDlet + JAR real; validar MIDletLoader |
| T3 | Rendimiento Zero insuficiente para juegos | **Alta** | Medir FPS en device; evaluar Leyden/AOT parcial más tarde |
| T4 | `System.exit` mata el proceso app | **Alta** | Trampa nativa / wrapper de `Runtime.exit` / parche allowlisted en loader |
| T5 | Tamaño binario y tiempo de arranque JVM | **Alta** | Strip modules; lazy init; métricas de cold start |
| T6 | Complejidad de build/CI OpenJDK Mobile | **Alta** | Artefacto precompilado versionado; no compilar JDK en cada PR de app |
| T7 | Fugas JNI / hilos / classloaders entre sesiones | **Media** | Una VM por proceso; reset de sesión estricto en STOP |
| T8 | Audio / MIDI no portables | **Media** | Stub inicial; backend iOS después |
| T9 | Divergencia macOS Process vs iOS embedded | **Media** | Misma fachada de comandos Contract C; tests compartidos de Adapter |
| T10 | GPL-3 FreeJ2ME vs modelo App Store | **Alta (legal/tech)** | Asesoría legal; compliance de fuentes/binarios |

---

## 8. Riesgos para App Store Review

| ID | Riesgo | Notas |
|----|--------|------|
| R1 | **Emulación / consola** | Apple ha tolerado y rechazado emuladores según época y categoría; J2ME no es consola “cerrada”, pero el precedente es volátil. Preparar narrativa: “reproductor de software Java ME del usuario”. |
| R2 | **Código interpretado** | Guideline sobre código no embebido en el binario. Argumento: el intérprete va en el binario; los JARs son **contenido del usuario** (como documentos), no lógica remota de la app. |
| R3 | **No JIT / no unsigned executable memory** | Zero ayuda; evitar cualquier JIT propio o trampolines W^X ilegales. |
| R4 | **Frameworks / dylib layout** | Empaquetado incorrecto → rechazo binario. Preferir static link + resources auditados. |
| R5 | **Tamaño / performance** | Rechazos raros, pero reviews humanas notan apps lentas/inestables. |
| R6 | **Privacidad / sandbox** | RMS y file I/O solo en container; no escape sandbox. |
| R7 | **Licencias (GPL-3)** | No es guideline técnico, pero puede bloquear distribución comercial o imponer obligaciones de fuente. Tratar como gate de producto paralelo al spike técnico. |
| R8 | **Private API** | Cualquier patch JDK que toque APIs privadas iOS → rechazo. Mantener syscalls/POSIX documentados. |

**Postura de review recomendada:** presentar CoreJ2 como app nativa SwiftUI cuya capacidad de emulación es un **motor local** empaquetado; el usuario importa sus propios JARs; sin store de ROMs integrado si eso eleva el riesgo.

---

## 9. Recomendación final

### 9.1 Decisión arquitectónica

1. **Mantener** la arquitectura desacoplada actual.  
2. **Tratar OpenJDK Mobile (Zero + static libs)** como la **única hipótesis de JVM embebida** digna de un spike de ingeniería en iOS.  
3. **No** apostar el producto a Gluon AOT / Native Image como runtime de MIDlets dinámicos.  
4. **No** intentar `Process` en iOS.  
5. **Implementar** (cuando se autorice código) un bootstrap iOS paralelo al persistente de macOS, detrás de `FreeJ2MEMobilePlatformBootstrapping`.

### 9.2 Orden de spikes (go / no-go)

| Fase | Criterio de éxito | Si falla |
|------|-------------------|----------|
| **M9a** | Enlazar `libjvm`, `JNI_CreateJavaVM`, ejecutar clase hello | Abandonar JVM embebida; reconsiderar F |
| **M9b** | `BufferedImage` headless 240×320 + getRGB | Plan B: fork gráfico FreeJ2ME |
| **M9c** | `defineClass` / cargar ProbeMIDlet | Plan B profundo o no-go FreeJ2ME en iOS |
| **M9d** | Contract C + 1 frame vía painter → `frameHandler` | No conectar UI aún |
| **M9e** | STOP sin matar la app; sin leak obvio tras N sesiones | Hardening antes de DI production iOS |

### 9.3 Recomendación de producto

- **Corto plazo:** seguir validando emulación en **macOS** (JVM persistente ya migrada).  
- **Medio plazo:** spike OpenJDK Mobile **fuera** del critical path de features de UI.  
- **Solo entonces:** activar bootstrap embebido en DI iOS.  
- Comunicar a stakeholders: **“JVM en iOS es factible en papel; FreeJ2ME-on-that-JVM es la incertidumbre real.”**

### 9.4 Qué no recomendar ahora

- Reescribir FreeJ2ME a Swift.  
- Cambiar Bridge/Host/Adapter “por si la JVM cambia”.  
- Mezclar OpenJFX en el pipeline de emulación.  
- Declarar App Store “garantizado” antes de M9b–M9d y revisión legal GPL.

---

## Referencias

- OpenJDK Mobile: https://github.com/openjdk/mobile  
- Java on Mobile: https://openjdk-mobile.github.io/  
- OpenJDK iOS notes (histórico Zero + libffi): https://openjdk.org/projects/mobile/ios.html  
- InfoQ (2025): *Running Java on iOS: Gluon Introduces OpenJDK Mobile Resources…*  
- CoreJ2: `docs/FREEJ2ME_ASSESSMENT.md`, `docs/E5_US003_PERSISTENT_RUNTIME_DESIGN.md`, `docs/E5_US005_PERSISTENT_RUNTIME_MIGRATION.md`

---

*Fin del estudio de viabilidad. Documento de arquitectura únicamente; sin cambios de código asociados.*
