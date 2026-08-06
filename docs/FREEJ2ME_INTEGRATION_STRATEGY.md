# FreeJ2ME Integration Strategy

**Task:** E3-R003 — Integration strategy (documentation only)  
**Depends on:** E3-R001 (`docs/FREEJ2ME_ASSESSMENT.md`), E3-R002 (`docs/FREEJ2ME_RUNTIME_CONTRACT.md`)  
**Date:** 2026-08-04  
**Status:** Strategy decision — **does not add FreeJ2ME sources to the repository yet**

This document freezes **how** CoreJ2 will bring FreeJ2ME into the tree, what may be changed, and how updates will flow. It does **not** choose an iOS JVM product (that remains a follow-on spike after this layout is agreed).

---

## 1. Upstream repository

**Primary upstream:** [hex007/freej2me](https://github.com/hex007/freej2me)

**Secondary reference (not the vendor baseline):** [TASEmulators/freej2me-plus](https://github.com/TASEmulators/freej2me-plus)

License (both): **GPL-3.0** — product/legal review remains mandatory before TestFlight / App Store distribution.

---

## 2. Why that repository was selected

| Criterion | hex007/freej2me | freej2me-plus |
|-----------|-----------------|---------------|
| Basis of E3-R001 assessment | Yes (sources reviewed) | Noted only |
| Core APIs CoreJ2 already contracts (`MobilePlatform`, painter, `loadJar` / `runJar`) | Present and documented in assessment | Diverges over time |
| Alignment with AGENTS.md (“modify FreeJ2ME as little as possible”) | Clear, smaller historical surface | More packaging / CLI activity → more drift |
| Best iOS reference path | Libretro/SDL painter → RGB (not AWT) | Similar ideas; not the assessed tree |
| Packaging / active maintenance | Quieter | Often more active |

**Decision:** Vendor and track **hex007/freej2me** as the canonical core.

Use **freej2me-plus** only as a **patch reference** (cherry-pick or re-implement equivalent fixes in a CoreJ2-managed fork when a plus fix is clearly better). Do not switch the vendor baseline to plus without a new written decision, because Contract C and Epic 3 adapters were designed against hex007’s layout and hooks.

---

## 3. Submodule vs vendor copy vs fork

CoreJ2 needs three properties at once:

1. **Pin a known FreeJ2ME revision** (reproducible builds).
2. **Pull upstream fixes** with a clear merge story.
3. **Apply rare iOS/embed patches** without rewriting Library / Bridge.

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Git submodule** | Pin SHA; explicit updates; keeps FreeJ2ME out of app history noise | Requires submodule discipline in CI/clone | **Preferred for bringing sources in** |
| **Vendor copy** (files committed in-tree) | Simple clone for newcomers | Painful upstream merges; blurs “don’t touch FreeJ2ME” | Reject as primary |
| **Fork only** (no submodule) | Easy to patch | Easy to forget upstream; weak pin story unless tags are strict | Incomplete alone |

**Selected model: submodule + optional managed fork**

1. **Phase A (read-only bring-up):** Git submodule at `Vendor/FreeJ2ME` pointing at `hex007/freej2me` on a pinned commit.  
2. **Phase B (when a patch is unavoidable):** Create a **CoreJ2-managed fork** of hex007/freej2me; retarget the submodule URL to that fork; continue rebasing/merging from hex007.

Do **not** commit a full vendor tree into `main` as ordinary project files.

Do **not** start with freej2me-plus as the submodule remote.

---

## 4. Repository layout

Target layout after FreeJ2ME is added (future work — not done in E3-R003):

```text
CoreJ2/                          # this app repository
├── AGENTS.md
├── docs/
│   ├── EMULATOR_ARCHITECTURE.md
│   ├── FREEJ2ME_ASSESSMENT.md
│   ├── FREEJ2ME_RUNTIME_CONTRACT.md
│   └── FREEJ2ME_INTEGRATION_STRATEGY.md   # this file
├── CoreJ2/
│   ├── App/                              # DI, composition root
│   └── Features/
│       ├── Library/                      # never imports FreeJ2ME
│       └── Emulator/
│           ├── Models/                   # LaunchConfiguration, RuntimeEvent, …
│           ├── Services/                 # Bridge, RuntimeHostProtocol, PlaceholderHost
│           └── Runtime/                  # FreeJ2MERuntimeHost, Adapter, Swift seams
├── Vendor/
│   └── FreeJ2ME/                         # GIT SUBMODULE → hex007 or CoreJ2 fork
│       └── (upstream tree: src/, build.xml, …)
├── JavaOne.xcodeproj/
├── JavaOneTests/
└── scripts/                              # optional: sync/build helpers for FreeJ2ME
    └── freej2me/                         # build JAR / package notes (future)
```

**Rules:**

- `Vendor/FreeJ2ME/**` = upstream (or managed fork) only.  
- `JavaOne/Features/Emulator/**` = all Swift integration (bridge, host, events, DI wiring).  
- No FreeJ2ME Java types in `Features/Library/**`, Views, or ViewModels.  
- Xcode must not compile FreeJ2ME `.java` as app sources until a dedicated runtime packaging story exists; the submodule is a **source of truth / research / future build input**, not automatic membership in the iOS target.

---

## 5. Files allowed to change (inside FreeJ2ME)

Prefer **zero** edits. When a CoreJ2-managed fork is required, only these zones are allowed — and each change must be documented in the fork’s commit message / a short `Vendor/FreeJ2ME` CHANGELOG note owned by CoreJ2:

| Zone | Allowed change | Why |
|------|----------------|-----|
| `MobilePlatform` usage of painter / `dataPath` | Init wiring, embed-safe defaults | Contract C; already designed for injection |
| Error paths that call `System.exit` | Guard / throw instead of exiting process | Embedding on iOS |
| `PlatformPlayer` / audio backends | Replace Java Sound behind façades | iOS has no `javax.sound.sampled` |
| Graphics backends that hard-require full AWT SE | Thin abstractions for LCD pixel access | Painter path without desktop Frame |
| Build scripts (`build.xml` / packaging) | Produce artifacts CoreJ2 can consume | Integration packaging only |

Changes must be **minimal**, **upstream-shaped**, and preferably proposed upstream when not iOS-specific.

---

## 6. Files that must never be modified

| Zone | Reason |
|------|--------|
| Player MIDlet JARs (user library content) | Not FreeJ2ME; never rewrite games |
| `org.objectweb.asm/**` | Stability and legal surface |
| Broad rewrites of `javax.microedition.*` semantics | Compatibility; only upstream-style bugfixes if ever |
| `org.recompile.freej2me.FreeJ2ME` AWT UI as iOS path | Desktop only; out of Contract C |
| Libretro C core / RetroArch process protocol | Wrong host model for iOS |
| `Anbu` + SDL native helper as iOS dependency | Desktop IPC |
| Game-specific hacks scattered through core | Fix in adapter or documented fork patches with review |
| ASM / class-loader redesign “for convenience” | High regression risk |

CoreJ2 product code must **never** be placed under `Vendor/FreeJ2ME/`.

---

## 7. How upstream updates will be merged

### 7.1 While submodule tracks hex007 directly

1. `git fetch` inside the submodule.  
2. Review changelog / diff against Contract C hooks (`MobilePlatform`, `Mobile`, loader, painter).  
3. Run CoreJ2 unit tests + any FreeJ2ME smoke corpus.  
4. Advance submodule SHA on a dedicated PR (`chore: bump Vendor/FreeJ2ME to <sha>`).  
5. No silent force-pushes of submodule history.

### 7.2 After a CoreJ2-managed fork exists

1. Keep a remote `upstream` → `hex007/freej2me`.  
2. Periodically `git fetch upstream` and **rebase or merge** `upstream/master` (or pinned branch) into the fork’s `corej2` branch.  
3. Resolve conflicts preferring **upstream behavior** unless an allowlisted CoreJ2 patch must win.  
4. Tag fork releases CoreJ2 actually ships against (`corej2-freej2me-YYYY.MM.DD` or semver).  
5. Bump the app repo submodule to that tag/SHA via PR.

### 7.3 freej2me-plus

Treat plus commits as **candidates**. Port selected fixes onto the managed fork with attribution; do not merge plus wholesale.

---

## 8. Keeping CoreJ2-specific code outside the vendor directory

| Concern | Location |
|---------|----------|
| Validation, session lifecycle, DI | `DefaultEmulatorBridge`, `AppDependencyContainer` |
| Runtime host / events | `Features/Emulator/Runtime/*`, `RuntimeEvent*` |
| Mapping `LaunchConfiguration` → `loadJar` / `runJar` / `dataPath` | `FreeJ2MERuntimeAdapter` (+ future JNI/FFI wrapper **in Emulator/Runtime**, not in Vendor) |
| Painter → Metal / SwiftUI | Future Emulator rendering types |
| Input / audio bridges | Future Emulator services |
| Build orchestration invoking FreeJ2ME tools | `scripts/freej2me/` (app repo), not patched into upstream casually |

**Dependency direction (unchanged from Contract B/C):**

```text
Library / Import ──▶ LaunchConfiguration
                         │
                         ▼
                  EmulatorBridge (Swift)
                         │
                         ▼
               FreeJ2MERuntimeHost / Adapter (Swift)
                         │
                         ▼
               Vendor/FreeJ2ME (Java core)   ← submodule boundary
```

If a JNI/C façade is required, it lives under `JavaOne/Features/Emulator/Runtime/` (or a dedicated Xcode target owned by CoreJ2), calling into classes built from `Vendor/FreeJ2ME` — never the reverse.

---

## 9. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **No App Store–ready JVM / HotSpot+AWT on iOS** | Critical | Gate production on a dedicated runtime spike; keep PlaceholderRuntimeHost as default until then |
| **GPL-3 copyleft** on App Store distribution | High | Legal review before shipping any FreeJ2ME-linked binary; document obligations |
| Submodule forgotten in CI / fresh clones | Medium | Document clone `--recurse-submodules`; fail CI if `Vendor/FreeJ2ME` missing when required |
| Uncontrolled edits inside Vendor | High | CODEOWNERS / PR checklist: Vendor changes require explicit strategy citation |
| freej2me-plus divergence if someone vendors plus by mistake | Medium | This document: hex007 only as baseline |
| `System.exit` / process assumptions | Medium | Allowlisted fork guards only |
| Painter thread vs MainActor | High | Adapter hops (Contract §7); do not fix by rewriting MIDP |
| Assuming submodule alone equals “runs on device” | High | Submodule ≠ embedded runtime; packaging is a separate milestone |

---

## 10. Migration plan

Ordered steps. **E3-R003 stops at documentation**; later stories execute these steps.

| Step | Action | Exit criteria |
|------|--------|---------------|
| **M0** | This strategy approved | Team agrees on hex007 + submodule model |
| **M1** | Add `Vendor/FreeJ2ME` submodule at pinned hex007 SHA | Clone works; no Xcode target link required yet |
| **M2** | Inventory Contract C symbols against the pinned tree | `loadJar` / `runJar` / painter / `dataPath` paths confirmed |
| **M3** | iOS Java/runtime spike (policy + tech) | Written go/no-go; may block M5+ |
| **M4** | Optional CoreJ2 fork if embed patches needed | Fork + submodule URL retarget; patch list documented |
| **M5** | Build pipeline producing consumable FreeJ2ME artifact | JAR/classes/native libs reproducible |
| **M6** | Wire `DefaultFreeJ2MEMobilePlatform` JNI/FFI to real `MobilePlatform` | Startup no longer Swift-only seam |
| **M7** | Painter → `RuntimeEvent.frameAvailable` + renderer | First on-device frame |
| **M8** | Input / audio / RMS sandbox hardening | Playable vertical slice |
| **M9** | Switch DI from `PlaceholderRuntimeHost` → `FreeJ2MERuntimeHost` | Production path; legal sign-off complete |

Until **M3** succeeds, FreeJ2ME remains a **vendored research dependency**, not a shipping iOS runtime (consistent with E3-R001).

---

## Recommended integration strategy

**Use [hex007/freej2me](https://github.com/hex007/freej2me) as the canonical upstream**, brought into CoreJ2 as a **Git submodule at `Vendor/FreeJ2ME`**, pinned by commit SHA.

**Keep all CoreJ2 Swift / JNI façade code outside that directory** under `Features/Emulator`. Prefer **zero upstream edits**; if embed or iOS backend patches become mandatory, **retarget the submodule to a CoreJ2-managed fork** and rebase regularly from hex007. Treat **freej2me-plus** as a patch reference only.

**Do not** commit a blind vendor copy, **do not** make freej2me-plus the baseline, and **do not** treat adding the submodule as “FreeJ2ME runs on iPhone” — the JVM/runtime spike remains the critical gate before production DI switches away from `PlaceholderRuntimeHost`.

---

## Related documents

| Doc | Role |
|-----|------|
| `docs/FREEJ2ME_ASSESSMENT.md` | E3-R001 — how FreeJ2ME works |
| `docs/FREEJ2ME_RUNTIME_CONTRACT.md` | E3-R002 — app / adapter / core hooks |
| `docs/EMULATOR_ARCHITECTURE.md` | CoreJ2 bridge layout |
| `AGENTS.md` | Minimize FreeJ2ME modification; bridge layer |

---

## Out of scope for E3-R003

- Adding the submodule or any FreeJ2ME files  
- Choosing a specific commercial/open JVM for iOS  
- Implementing JNI  
- Changing Swift source or Xcode project settings  
- Commits or App Store legal sign-off
