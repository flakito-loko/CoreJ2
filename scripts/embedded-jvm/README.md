# Embedded JVM Phase 1 — Hello World spike

Harness aislado (fuera del App Target) para:

`EmbeddedJVMManager → JVM (JNI_CreateJavaVM) → HelloWorld → destroy`

## Qué incluye

- Manager + máquina de estados (subset Fase 1)
- Puente nativo mínimo (`EmbeddedJVMNative.c`) — **no** es JNI Gateway
- `HelloWorld.java` (classpath de directorio, **sin** JAR de producto / FreeJ2ME)
- Métricas: startup, Hello World, destroy, RSS, tamaño `libjvm` / `.class`

## Ejecutar

```bash
export JAVA_HOME=/path/to/jdk   # p. ej. Temurin 17+
chmod +x scripts/embedded-jvm/run_phase1_hello_world.sh
./scripts/embedded-jvm/run_phase1_hello_world.sh
```

Salida: `artifacts/embedded-jvm-phase1/metrics.json`

## OpenJDK Mobile

Si existe `artifacts/openjdk-mobile/staged/current` con `libjvm.dylib` host-linkable, el script lo usa.

Una `libjvm.a` Zero de **iOS device** no se puede enlazar en este harness macOS; hace falta el artefacto de Fase 0 para el target acordado + harness iOS posterior.

## Fase 1.5 — OpenJDK Mobile

```bash
./scripts/openjdk-mobile/build-macos-host.sh
./scripts/embedded-jvm/run_phase1_5_compare.sh
```

Compara Temurin vs OpenJDK Mobile con el mismo `EmbeddedJVMManager` / `HelloWorld`.  
Veredicto: `docs/Architecture/PHASE1_5_OPENJDK_MOBILE_SPIKE.md`
