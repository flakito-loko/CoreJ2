# Scripts OpenJDK Mobile — Fase 0A

Preparación reproducible del build de **OpenJDK Mobile** (`static-libs-image` / Zero / device).  
**Fuera** del App Target. No JNI, no FreeJ2ME, no Bridge/Host/Adapter.

## Requisitos

Documentados en `docs/Architecture/OPENJDK_MOBILE_BUILD.md`.

Resumen: Xcode + iPhoneOS SDK, `autoconf`, Boot **JDK 24**, `git`, `make`, red para el primer fetch.

## Uso

Desde la raíz del repo:

```bash
chmod +x scripts/openjdk-mobile/*.sh

# Solo comprobar host (sin red obligatoria salvo java_home)
./scripts/openjdk-mobile/00-check-host-tools.sh

# Pipeline completo (largo)
./scripts/openjdk-mobile/build-all.sh
```

Pasos individuales:

| Script | Acción |
|--------|--------|
| `00-check-host-tools.sh` | Verifica Xcode, SDK, autoconf, Boot JDK 24 |
| `01-fetch-sources.sh` | Clone/update `openjdk/mobile` → `ThirdParty/OpenJDKMobile/src/mobile` |
| `02-fetch-support.sh` | Descarga/cache zip Gluon + extract |
| `03-configure-ios-device.sh` | `configure` device aarch64 + Zero |
| `04-build-static-libs.sh` | `make CONF=ios-aarch64-zero-release static-libs-image` |
| `05-stage-artifacts.sh` | Copia a `artifacts/openjdk-mobile/staged/` + manifest |
| `06-verify-artifacts.sh` | Comprueba SHA256 del `libjvm.a` staged |

Pins: `ThirdParty/OpenJDKMobile/versions.env`.

## Fuera de alcance (Fase 0A)

- Enlazar `libjvm` al target iOS / App
- JNI, EmbeddedJVMManager, RuntimeAdapter, PlatformBootstrap
- FreeJ2ME, Bridge, Host, Library, UI
- Build automático de simulador (solo documentado)
