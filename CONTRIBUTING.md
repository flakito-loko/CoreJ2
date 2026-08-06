# Contributing

Thanks for helping improve CoreJ2.

## Ground rules

- Follow [`AGENTS.md`](AGENTS.md) architecture rules (MVVM, repositories, DI, one file = one responsibility).
- Do **not** modify Vendor FreeJ2ME unless a story explicitly requires a minimal, documented patch.
- Prefer the smallest safe change; do not refactor unrelated code.
- Views talk only to ViewModels; ViewModels never touch SwiftData directly.

## Development setup

1. macOS with Xcode matching the project (currently Xcode 26.x family).
2. Clone with submodules:
   ```bash
   git clone --recurse-submodules <repo-url>
   cd CoreJ2
   ```
3. Open `JavaOne.xcodeproj` and build the `JavaOne` scheme for a connected device or simulator.
4. For embedded runtime scripts, see `scripts/embedded-jvm/README.md` and `scripts/openjdk-mobile/README.md`.

## Documentation

Public docs use **MkDocs Material**.

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

Compatibility data:

- Update `compatibility/compatibility.json` (source of truth)
- Regenerate CSV / site tables with `scripts/docs/sync_compatibility.py`
- Add or revise per-game pages under `compatibility/games/`

## Pull requests

1. Keep PRs focused (one epic story or one docs concern).
2. Include tests for behavioral changes.
3. Update CHANGELOG under `[Unreleased]` when user-visible.
4. Do not commit secrets, provisioning profiles, or local OpenJDK build caches.

## Code style

- Swift 6, SwiftUI, protocol-oriented code
- Document public types
- Avoid force unwraps and TODO comments
- Prefer readable code over clever code

## Conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
