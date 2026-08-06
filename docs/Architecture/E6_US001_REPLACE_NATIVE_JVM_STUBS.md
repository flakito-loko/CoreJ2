# E6-US001 — Replace Native JVM Stubs

**Fecha:** 2026-08-04  
**Estado:** IMPLEMENTADO (App Target)  
**Depende de:** E6-S001 (VALIDATED)

## Veredicto

El target de producción `CoreJ2` compila y enlaza:

- `EmbeddedJVMNative.c`
- `JNIGatewayNative.c`

Los stubs `*Stub.c` permanecen en el árbol **solo como referencia test-only** y **ya no** forman parte de Sources del App Target.

`EmbeddedJVMManager` / `DefaultJNIGateway` / `PlatformBootstrap` APIs públicas: sin cambios.

---

## Validación

| Criterio | Resultado |
|----------|-----------|
| Production target usa real native `.c` | ✓ (pbxproj Sources) |
| Backend identity `openjdk-mobile` (no `stub`) | ✓ `ReplaceNativeJVMStubsTests` |
| JNIGateway backend de producción | ✓ `ProductionJNIGatewayNativeBackend` (DI sin cambio) |
| Sin `*Stub.c` en Sources del App Target | ✓ |
| Tests existentes | ✓ (xcodebuild test) |
| Shutdown path | ✓ (mismo `destroyJVM` real; sin timeout en harness E6-S001) |
| JVM real en proceso iOS | ⏳ requiere `libjvm.a` Zero staged |

Corrida host (sin cambio de arquitectura): `./scripts/embedded-jvm/run_e6_s001_openjdk_mobile_bringup.sh` sigue validando Manager + Gateway + OpenJDK Mobile.

---

## Deliverables

### 1. Files created

| Path | Rol |
|------|-----|
| `Config/OpenJDKMobile.xcconfig` | HEADER_SEARCH_PATHS + LDFLAGS hooks |
| `Config/OpenJDKMobile.link.xcconfig` | Flags generados (vacío hasta iOS `libjvm.a`) |
| `scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh` | Genera link xcconfig desde stage iOS |
| `ThirdParty/OpenJDKMobile/jni-include/**` | Headers JNI vendored para compilar `.c` |
| `JavaOneTests/ReplaceNativeJVMStubsTests.swift` | Verifica backend ≠ stub |
| `docs/Architecture/E6_US001_REPLACE_NATIVE_JVM_STUBS.md` | Este documento |

### 2. Files modified

| Path | Cambio |
|------|--------|
| `JavaOne.xcodeproj/project.pbxproj` | Sources reales + xcconfig base |
| `EmbeddedJVMNative.c` | `dlsym(JNI_CreateJavaVM)` + backend id |
| `EmbeddedJVMNative.h` | `<<<JAVAONE_UNDERSCORE>>>embedded_jvm_native_backend` |
| `EmbeddedJVMNativeStub.c` / `JNIGatewayNativeStub.c` | Comentario test-only + backend `"stub"` |

### 3. Linker changes

- App Target `baseConfigurationReference` → `Config/OpenJDKMobile.xcconfig`
- Headers: `ThirdParty/OpenJDKMobile/jni-include` (+ `darwin/`)
- `JAVAONE_OPENJDK_MOBILE_LDFLAGS` / `LIBRARY_SEARCH_PATHS` vía `OpenJDKMobile.link.xcconfig`
- Hoy: **sin** `-ljvm` (no hay `libjvm.a` iOS staged). `JNI_CreateJavaVM` se resuelve en runtime con `dlsym`; si no hay lib, create → `-8`.
- Cuando exista Zero: `./scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh` emite `-Wl,-force_load,…/libjvm.a`

### 4. Removed stub paths (from production Sources)

- ~~`EmbeddedJVMNativeStub.c in Sources`~~
- ~~`JNIGatewayNativeStub.c in Sources`~~

Archivos stub **conservados** en disco para harness/tests aislados; no enlazados al app.

### 5. Remaining blockers before FreeJ2ME on real JVM

1. Construir y stagear **iOS Zero** `libjvm.a` (+ deps estáticas necesarias).
2. Regenerar `OpenJDKMobile.link.xcconfig` y verificar link del App Target.
3. Empaquetar `java.home` / modules en el bundle (`OpenJDKMobile` resource path ya contemplado en DI).
4. Classpath de producto (bootstrap CoreJ2 + FreeJ2ME JAR) — **fuera de E6-US001**.
5. Validar create/shutdown en device/simulator con artefacto real.

---

## Cómo verificar

```bash
./scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh
xcodebuild -scheme JavaOne -destination 'platform=iOS Simulator,name=iPhone 16' test
./scripts/embedded-jvm/run_e6_s001_openjdk_mobile_bringup.sh
```
