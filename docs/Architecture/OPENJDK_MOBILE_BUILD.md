# OpenJDK Mobile — build reproducible (Fase 0A)

**Fase:** 0A (preparación de toolchain) dentro de **Fase 0 — Preparación** del  
[`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md).

**Fecha:** 2026-08-04  
**Alcance:** scripts, documentación, directorios, pins, cache y stage de artefactos.  
**Fuera de alcance:** enlace al App Target, JNI, FreeJ2ME, Bridge, Host, Adapter, Library, UI.

---

## Objetivo de 0A

Dejar el repositorio listo para construir **OpenJDK Mobile** de forma **repetible** en una máquina macOS de ingeniería / CI, sin integrar todavía la JVM en JavaOne.

El criterio de éxito completo de la Fase 0 del roadmap (“imagen estática Zero obtenida”) se cumple cuando alguien ejecuta el pipeline y genera `libjvm.a` + manifest. **0A entrega el kit**; el primer build verde en host es el cierre operativo de Fase 0.

---

## Arquitectura de directorios

```
ThirdParty/OpenJDKMobile/
  versions.env          # pins (URL, ref, hashes)
  cache/                # zip Gluon (gitignored)
  src/mobile/           # clone openjdk/mobile (gitignored)
  support/              # libffi + cups extraídos (gitignored)
  out/                  # logs locales (gitignored)

artifacts/openjdk-mobile/
  staged/<label>/       # static-libs copiados (gitignored)
  staged/current → …    # symlink al último stage
  manifests/            # manifest-*.env (texto; versionables tras build verde)

scripts/openjdk-mobile/ # toolchain — fuera del App Target
```

**Ninguna** de estas rutas se añade a `JavaOne.xcodeproj` en esta fase.

---

## Prerrequisitos de host

| Herramienta | Notas |
|-------------|--------|
| macOS + Xcode | Mismo entorno alineado al proyecto JavaOne |
| iPhoneOS SDK | `xcrun --sdk iphoneos --show-sdk-path` |
| autoconf | `brew install autoconf` |
| Boot JDK **24** | Requisito documentado por OpenJDK Mobile; `export BOOT_JDK_HOME=…` si hace falta |
| git, make, curl/wget, unzip | Estándar |

Comprobación:

```bash
./scripts/openjdk-mobile/00-check-host-tools.sh
```

Upstream también recomienda poder construir el JDK para macOS antes de iOS  
(ver README de `openjdk/mobile`).

---

## Pins (reproducibilidad)

Archivo: `ThirdParty/OpenJDKMobile/versions.env`

| Variable | Valor inicial / política |
|----------|---------------------------|
| `OPENJDK_MOBILE_GIT_URL` | `https://github.com/openjdk/mobile.git` |
| `OPENJDK_MOBILE_REF` | Empieza en `master`; **sustituir por commit SHA** tras el primer clone verde |
| `GLUON_MOBILE_SUPPORT_URL` | `https://download2.gluonhq.com/mobile/mobile-support-20250106.zip` |
| `GLUON_MOBILE_SUPPORT_SHA256` | Vacío hasta el primer `02-fetch-support.sh`; entonces fijar el hash impreso |
| `BOOT_JDK_MAJOR` | `24` |
| `OPENJDK_CONF_NAME` | `ios-aarch64-zero-release` |
| `OPENJDK_MAKE_TARGET` | `static-libs-image` |

Artefacto esperado tras el build (relativo al clone):

```text
build/ios-aarch64-zero-release/images/static-libs/lib/zero/libjvm.a
```

---

## Pipeline

```bash
chmod +x scripts/openjdk-mobile/*.sh
./scripts/openjdk-mobile/build-all.sh
```

Equivalente paso a paso:

1. `00-check-host-tools.sh`
2. `01-fetch-sources.sh`
3. `02-fetch-support.sh` — cache en `ThirdParty/OpenJDKMobile/cache/`
4. `03-configure-ios-device.sh` — equivalente documentado:

```bash
bash ./configure \
  --disable-warnings-as-errors \
  --openjdk-target=aarch64-macos-ios \
  --with-boot-jdk="$BOOT_JDK_HOME" \
  --with-libffi-include=<support>/libffi/include \
  --with-libffi-lib=<support>/libffi/libs \
  --with-cups-include=<support>/cups-2.3.6 \
  --with-sysroot="$(xcrun --sdk iphoneos --show-sdk-path)"
```

5. `04-build-static-libs.sh` → `make CONF=ios-aarch64-zero-release static-libs-image`
6. `05-stage-artifacts.sh` → `artifacts/openjdk-mobile/staged/…` + manifest
7. `06-verify-artifacts.sh` → comprueba SHA256

Regeneración: mismo `versions.env` + mismos scripts + mismo Xcode/SDK/Boot JDK → mismo hash de `libjvm.a` (salvo divergencias de toolchain documentadas en el manifest).

---

## Política simulador vs device

| Target | Variante JVM | Estado en 0A |
|--------|--------------|--------------|
| **Device** `aarch64-macos-ios` | **Zero** (default iOS; W^X) | Path primario automatizado |
| **Simulator** | A menudo `server` u otra variante (`--with-jvm-variants=…`) | Solo documentado; sin script de configure dedicado en 0A |

No mezclar artefactos device/simulator en el mismo `staged/current` sin etiquetar.

---

## Convención de paths Runtime (solo documentación)

Para fases posteriores (sin wiring en 0A):

| Concepto | Ubicación candidata |
|----------|---------------------|
| Artefacto staged | `artifacts/openjdk-mobile/staged/<label>/static-libs/` |
| `libjvm.a` | `…/lib/zero/libjvm.a` |
| Manifest | `artifacts/openjdk-mobile/manifests/manifest-<label>.env` |
| Fuentes / cache build | `ThirdParty/OpenJDKMobile/` (nunca en el bundle de app vía Fase 0A) |

El enlace al proceso iOS y `EmbeddedJVMManager` comienzan en **Fase 1**, no aquí.

---

## Qué no hacer en 0A

- No añadir search paths / `libjvm.a` al target `JavaOne` en Xcode.
- No implementar JNI ni Hello World embebido.
- No tocar FreeJ2ME, Bridge, Host, Adapter, PlatformBootstrap, Library, UI.
- No versionar binarios enormes en git (usar cache CI + manifests).

---

## Criterios de éxito 0A (kit)

- [x] Estructura de directorios y cache
- [x] Pins + scripts fuera del App Target
- [x] Instrucciones reproducibles
- [ ] *(operativo, cierra Fase 0)* Primer `libjvm.a` verde + SHA en manifest + `OPENJDK_MOBILE_REF` y `GLUON_MOBILE_SUPPORT_SHA256` fijados

## Rollback

Borrar `ThirdParty/OpenJDKMobile/{cache,src,support,out}` y `artifacts/openjdk-mobile/staged`.  
No hay restos en el App Target si no se enlazó nada (correcto para 0A).

---

## Referencias

- Roadmap: `docs/Architecture/IMPLEMENTATION_ROADMAP.md` (Fase 0)
- Viabilidad: `docs/Architecture/JVM_FEASIBILITY_STUDY.md`
- Upstream: [openjdk/mobile](https://github.com/openjdk/mobile) README — *Build static image for iOS*
- Support zip: https://download2.gluonhq.com/mobile/mobile-support-20250106.zip
