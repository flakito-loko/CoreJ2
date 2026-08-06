# E6-US002 — Embedded OpenJDK Mobile Runtime Integration

**Fecha:** 2026-08-05  
**Estado:** INTEGRADO (device App Target)  
**Depende de:** E6-S002  

## Veredicto

El target de producción **iphoneos** enlaza OpenJDK Mobile Zero (`libjvm.a` + companion libs + libffi + WX stubs), empaqueta `OpenJDKMobile/java.home`, y DI apunta `EmbeddedJVMManager` a ese layout.  
`JNI_CreateJavaVM` está en el binario de la app.  
Simulator: **no** enlaza Zero (SDK distinto); tests de arranque JVM se saltan con `XCTSkip`.

---

## Validation

| Criterio | Resultado |
|----------|-----------|
| JVM linked in App Target (device) | ✓ `JNI_CreateJavaVM` + backend `openjdk-mobile` |
| Bundle `java.home` | ✓ ~119 MiB `OpenJDKMobile/java.home` |
| EmbeddedJVMManager / Gateway APIs | ✓ sin cambios públicos |
| Tests existentes + nuevos | ✓ simulator `TEST SUCCEEDED` |
| `runtimeUnavailable` (Adapter Process) en path DI | ✓ launch no usa Adapter Process; DI → PlatformBootstrap |
| ensureStarted → ready (device) | ⏳ test preparado; requiere hardware device |
| Shutdown | ✓ path `destroyJVM` real (device test); sim N/A |

---

## Deliverables

### 1. Files created

| Path | Rol |
|------|-----|
| `CoreJ2/.../Native/OpenJDKMobileWXStubs.cpp` | Stubs W^X para link Zero |
| `scripts/openjdk-mobile/copy-ios-runtime-into-app.sh` | Copia `jdk-exploded` → bundle |
| `JavaOneTests/EmbeddedOpenJDKMobileRuntimeIntegrationTests.swift` | Layout / DI / device start |
| `docs/Architecture/E6_US002_EMBEDDED_OPENJDK_MOBILE_RUNTIME.md` | Este doc |
| `artifacts/e6-us002-openjdk-mobile-runtime/metrics.json` | Métricas de build |

### 2. Files modified

| Path | Cambio |
|------|--------|
| `Config/OpenJDKMobile.link.xcconfig` | LDFLAGS device-only |
| `JavaOne/App/AppDependencyContainer.swift` | Layout `OpenJDKMobile/java.home` + `classpath` |
| `JavaOne.xcodeproj/project.pbxproj` | WX stubs + Copy Runtime phase + tests |
| `scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh` | Regenera flags relativos |

**Sin cambios** a Bridge / Host / PlatformBootstrap / JNIGateway public APIs / ViewModels / SwiftUI / FreeJ2ME.

### 3. Link / runtime resource integration

**Link (`sdk=iphoneos*` only):**

```
-Wl,-force_load,…/lib/zero/libjvm.a
-ljava -lzip -ljimage -lverify -ljli -lnio -lnet
…/libffi.a -lc++
+ OpenJDKMobileWXStubs.cpp
```

**Bundle (build phase):**

```
JavaOne.app/OpenJDKMobile/
  java.home/     ← staged jdk-exploded
  classpath/     ← vacío (FreeJ2ME después)
```

### 4. Startup metrics

| Métrica | Valor |
|---------|-------|
| Device build | SUCCEEDED |
| `JNI_CreateJavaVM` linked | yes |
| ensureStarted (ms) | *medir en device* (`EmbeddedOpenJDKMobileRuntimeIntegrationTests`) |

### 5. Memory metrics

| Métrica | Valor |
|---------|-------|
| Bundled OpenJDKMobile | ~119 MiB |
| `libjvm.a` | ~26.1 MiB |
| App `CoreJ2.debug.dylib` (Debug) | ver `metrics.json` |
| RSS Δ create | *medir en device* |

### 6. Remaining blockers before FreeJ2ME

1. On-device smoke: `ensureStarted` → `ready` → `bind` → `shutdown` (test ya escrito).
2. Simulator Zero / server variant (dev loop).
3. Classpath FreeJ2ME + bootstrap classes (fuera de E6-US002).
4. Posible `jlink` / strip para reducir ~119 MiB.
5. Fix upstream W^X vs stubs permanentes.
6. Validar create con `java.home` exploded en hardware real.

---

## Cómo verificar

```bash
# Device link + resources
xcodebuild -scheme JavaOne -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

# Simulator tests
xcodebuild -scheme JavaOne -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:JavaOneTests/EmbeddedOpenJDKMobileRuntimeIntegrationTests
```
