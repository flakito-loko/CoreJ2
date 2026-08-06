# E6-S002 — OpenJDK Mobile Zero iOS Build Spike

**Fecha:** 2026-08-05  
**Estado:** DEVICE ZERO BUILD OK · LINK PROBE OK (con stubs W^X)  
**Depende de:** E6-US001  
**Alcance:** Spike técnico — **sin** cambios de comportamiento de runtime de producto, Bridge, Host, Bootstrap/JNIGateway APIs, UI, FreeJ2ME.

## Veredicto

| Pregunta | Respuesta |
|----------|-----------|
| ¿Se puede construir Zero para **device** iOS? | **Sí** — `ios-aarch64-zero-release` + `static-libs-image` |
| ¿`libjvm.a` usable? | **Sí** (arm64, ~26.1 MiB) con libs compañeras + libffi + `libc++` + stubs W^X |
| ¿Puede **reemplazar** el host macOS (`libjvm.dylib`) en CoreJ2? | **Aún no como drop-in** — distinto formato (static Zero vs dylib Server), falta layout `java.home` empaquetado, stubs W^X, y build de **simulator** |
| ¿Simulator? | **No construido** en este spike (política documentada; requiere CONF/sysroot aparte) |

---

## Validation checklist

| Criterio | Resultado |
|----------|-----------|
| Build completed (device) | ✓ ~2.4 min incremental tras configure |
| Produced runtime artifacts | ✓ `libjvm.a` + companion `lib/*.a` + `jdk-exploded/` |
| Size of runtime | ✓ libjvm.a **27 391 968** B; static-libs ~**28 MiB**; jdk-exploded ~**119 MiB** |
| Required bundle layout | ✓ documentado (abajo) |
| Link compatibility with CoreJ2 | ✓ probe iphoneos `LINK_OK` + `JNI_CreateJavaVM` exportado |
| Remaining blockers | ✓ listados |

---

## 1. Build commands

```bash
# Toolchain local (mismo cache que el host Mobile)
export PATH="$PWD/ThirdParty/OpenJDKMobile/cache/autoconf-prefix/bin:$PWD/ThirdParty/OpenJDKMobile/cache/m4-prefix/bin:$PATH"
export BOOT_JDK_HOME="$PWD/ThirdParty/OpenJDKMobile/cache/jdk-26.0.2+10/Contents/Home"
export JAVA_HOME="$BOOT_JDK_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# Orquestador spike (device Zero)
./scripts/openjdk-mobile/build-ios-zero.sh

# Equivalente paso a paso:
./scripts/openjdk-mobile/02-fetch-support.sh
./scripts/openjdk-mobile/03-configure-ios-device.sh
./scripts/openjdk-mobile/04-build-static-libs.sh
./scripts/openjdk-mobile/05-stage-artifacts.sh
./scripts/openjdk-mobile/06-verify-artifacts.sh

# Probe de link (no toca App Target)
./scripts/openjdk-mobile/probe-ios-zero-link.sh
./scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh
```

**Configure efectivo (device):**

- `--openjdk-target=aarch64-macos-ios`
- `--with-sysroot=$(xcrun --sdk iphoneos --show-sdk-path)`
- Gluon `libffi` + `cups` includes
- JVM variant: **zero** (default iOS)
- CONF: `ios-aarch64-zero-release`
- Make: `static-libs-image`

**Pins:** commit `c1ed06aaef34…`, Boot JDK Temurin 26, Gluon support SHA `5793dd87…` (ahora en `versions.env`).

---

## 2. Generated artifacts

| Artefacto | Ubicación |
|-----------|-----------|
| Build tree | `ThirdParty/OpenJDKMobile/src/mobile/build/ios-aarch64-zero-release/` |
| `libjvm.a` | `…/images/static-libs/lib/zero/libjvm.a` |
| Companion static libs | `…/images/static-libs/lib/libjava.a`, `libzip.a`, `libjimage.a`, `libverify.a`, `libjli.a`, `libnio.a`, `libnet.a`, … |
| Exploded modules | `…/jdk/modules` (+ `conf`, `lib`, `include`) |
| Staged | `artifacts/openjdk-mobile/staged/ios-aarch64-zero-release-c1ed06aaef34/` |
| Pointers | `staged/current-ios-device` → label; `current-macos` intacto |
| Manifest | `artifacts/openjdk-mobile/manifests/manifest-ios-aarch64-zero-release-c1ed06aaef34.env` |
| Link probe | `artifacts/e6-s002-ios-zero-link-probe/` (`LINK_OK`) |
| Metrics | `artifacts/e6-s002-ios-zero-link-probe/metrics.json` |

**SHA256 `libjvm.a`:** `30367b1dfd99cafa4f42fe1766ea0e76e2c4bd2df8c4184eaca4ab4d2444896b`

**Host vs Zero (no son intercambiables):**

| | Host macOS (E6-S001) | Device Zero (E6-S002) |
|--|----------------------|------------------------|
| Archivo | `libjvm.dylib` ~20.4 MiB | `libjvm.a` ~26.1 MiB |
| Variante | Server | Zero |
| SDK | macOS | iphoneos 26.5 / arm64 |
| Enlace | dinámico + rpath | estático (`-force_load`) |

---

## 3. Runtime layout

### Lo que produce `static-libs-image`

```
static-libs/
  lib/
    zero/libjvm.a
    libjava.a libzip.a libjimage.a libverify.a libjli.a …
jdk-exploded/          # staged desde build/…/jdk (exploded, no product image)
  modules/             # ~119 MiB — candidato a java.home
  conf/
  lib/                 # jvm.cfg, net.properties, …
  include/
```

**No** se generó un `images/jdk` product bundle completo en este spike (`make images` / `jdk-image` queda como trabajo siguiente si hace falta un `java.home` “clásico”).

### Bundle layout recomendado para CoreJ2 (futuro)

```
JavaOne.app/
  Frameworks/…                 # o static link en el binario
  OpenJDKMobile/               # Bundle resource (DI ya busca este path)
    java.home/                 # desde jdk-exploded o jdk-image
      modules/ conf/ lib/ …
    # libjvm NO va como dylib; se enlaza en compile/link time
```

`AppDependencyContainer` ya contempla `Bundle…/OpenJDKMobile` + `libjvm.a` path — **sin cambios** en este spike.

---

## 4. Link strategy

### Probe validado (iphoneos)

```
EmbeddedJVMNative.c
+ Spike/E6S002OpenJDKMobileZeroIOS/wx_stubs.cpp   # W^X no-ops
+ -Wl,-force_load,libjvm.a
+ -ljava -lzip -ljimage -lverify -ljli -lnio -lnet
+ Gluon libffi.a
+ -lc++
+ -framework Foundation
→ LINK_OK, exporta JNI_CreateJavaVM
```

### Xcode (E6-US001)

- App Target sigue con `Config/OpenJDKMobile.link.xcconfig` **vacío** (seguro).
- Flags recomendados: `Config/OpenJDKMobile.link.recommended.xcconfig`.
- Activación experimental: `JAVAONE_ENABLE_IOS_ZERO_LINK=1 ./scripts/openjdk-mobile/generate-xcode-link-xcconfig.sh` **y** compilar `wx_stubs.cpp` — **no** hecho en producción en este spike.

### Por qué hacen falta stubs W^X

En iOS/aarch64, `MACOS_AARCH64_ONLY(...)` sigue activo (`__APPLE__` + `AARCH64`), pero Zero **no** compila `os_bsd_aarch64.cpp` (solo `os_bsd.o` / `os_bsd_zero.o`). Resultado: refs a:

- `DefaultWXWriteMode`
- `os::_jit_exec_enabled` (`__thread`)
- `os::thread_wx_enable_write_impl`

Zero no JIT → no-ops son aceptables para bring-up; lo correcto a medio plazo es fix upstream o incluir el `.o` adecuado.

---

## 5. Build blockers (si aplica)

| Ítem | Severidad | Notas |
|------|-----------|-------|
| Device Zero `static-libs-image` | **Ninguno** | Completado |
| Link solo con `libjvm.a` | Medio | Faltan companion libs, libffi, libc++, stubs W^X |
| `java.home` product image | Medio | Solo exploded modules staged; validar `JNI_CreateJavaVM` + classpath real |
| Simulator build | Alto para dev loop | No automatizado; README sugiere `--with-jvm-variants=server` + sysroot `iphonesimulator` |
| min iOS version mismatch | Bajo | Objetos built for iOS 26.5 vs link `-miphoneos-version-min=17.0` (warnings) |
| Tamaño bundle | Medio | ~28 MiB static + ~119 MiB modules antes de strip/jlink |

---

## 6. Recommendation for integrating into CoreJ2

1. **Mantener host macOS** para harnesses E6-S001 / desarrollo de JNI en Mac.
2. **Adoptar Zero device** como runtime de producto iOS:
   - Enlazar con el fragmento `OpenJDKMobile.link.recommended.xcconfig` + `wx_stubs.cpp` (o fix upstream).
   - Empaquetar `jdk-exploded` (o un `jlink` mínimo) como `OpenJDKMobile` resource.
   - Regenerar xcconfig en CI tras stage.
3. **No** sustituir el host dylib dentro del App Target iOS (ABI/SDK incorrectos).
4. **Siguiente spike/story:** (a) `make images` / jlink mínimo para `java.home`, (b) create/shutdown real en device, (c) simulator CONF, (d) recién entonces FreeJ2ME classpath.

---

## Files created / modified (spike tooling only)

**Created:** `scripts/openjdk-mobile/build-ios-zero.sh`, `probe-ios-zero-link.sh`, `Spike/E6S002OpenJDKMobileZeroIOS/wx_stubs.cpp`, `docs/Architecture/E6_S002_OPENJDK_MOBILE_ZERO_IOS.md`, staged ios artifacts, probe metrics.

**Modified:** `03-configure-ios-device.sh` / `04-build-static-libs.sh` (cache Boot JDK), `05-stage-artifacts.sh` (`current-ios-device` + `jdk-exploded`), `generate-xcode-link-xcconfig.sh` (safe + recommended), `versions.env` (Gluon SHA pin).

**Not modified:** EmulatorBridge, RuntimeHost, PlatformBootstrap/JNIGateway public APIs, ViewModels, SwiftUI, Vendor/FreeJ2ME, production runtime behavior.
