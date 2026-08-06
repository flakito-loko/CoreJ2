# Building

## Prerequisites

- macOS with Xcode (project targets the Xcode 26.x toolchain family)
- Git with submodule support
- JDK on the Mac host for classpath compilation scripts (Temurin 17+ recommended)
- Optional: OpenJDK Mobile static libs for device linking (see `scripts/openjdk-mobile/`)

## Clone

```bash
git clone --recurse-submodules <repo-url>
cd JavaOne
open JavaOne.xcodeproj
```

## App target

1. Select the `JavaOne` scheme.
2. Choose a simulator or connected iOS device.
3. Build & run from Xcode.

Signing: use your personal team for device runs. CI docs builds do not require iOS signing.

## Embedded FreeJ2ME classpath

```bash
./scripts/embedded-jvm/compile-freej2me-classpath.sh
```

Staging into the app bundle is handled by OpenJDK Mobile copy scripts (see `scripts/openjdk-mobile/copy-ios-runtime-into-app.sh` and `scripts/embedded-jvm/README.md`).

## OpenJDK Mobile (device)

Follow `scripts/openjdk-mobile/README.md`:

1. Configure iOS device Zero build
2. Build static libs
3. Stage artifacts
4. Generate Xcode link xcconfig when `libjvm.a` is available

These steps are heavy and cached locally — build outputs under `ThirdParty/OpenJDKMobile/` and `artifacts/openjdk-mobile/` are gitignored.

## Documentation site

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

Production docs deploy automatically via GitHub Actions on pushes to `main` that touch documentation paths.

## Tests

- Unit tests: `JavaOneTests`
- Device UI tests: `JavaOneUITests` (require a paired iPhone and seeded fixtures)

Validation helpers live under `scripts/validation/`.
