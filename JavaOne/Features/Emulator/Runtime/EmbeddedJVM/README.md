# EmbeddedJVM (Fase 1 + E2-US001)

Ciclo de vida de **una** JVM embebida + **JNIGateway** (único borde JNI).

- Contrato Manager: `docs/Architecture/EMBEDDED_JVM_MANAGER.md`
- Contrato Gateway: `docs/Architecture/JNI_GATEWAY_ARCHITECTURE.md`
- Spike / métricas: `docs/Architecture/PHASE1_EMBEDDED_JVM_SPIKE.md`

**App Target:** Swift Manager + Gateway + stub nativo (sin `libjvm`).  
**Harness real JNI:** `scripts/embedded-jvm/run_e2_us001_jni_gateway.sh`

No es Bridge, Host, Adapter ni FreeJ2ME.
