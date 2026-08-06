# Performance

Benchmark placeholders. Replace with measured tables as instrumentation lands.

**Reference device (E11 validation):** iPhone 17 Pro Max · iOS 26.5.2  
**Runtime:** Embedded OpenJDK Mobile + FreeJ2ME

## Startup time

| Metric | Placeholder | Notes |
|--------|-------------|-------|
| Cold app launch → library | _TBD_ | |
| Library → first LCD frame (TTFF) | See per-game TTFF in compatibility JSON | Alea ~3.3 s; others ~1 s in E11-US001 |
| `JNI_CreateJavaVM` | _TBD_ | |

## RSS / memory

| Metric | Placeholder | Notes |
|--------|-------------|-------|
| Baseline RSS | _TBD_ | |
| Peak during gameplay | E11 suite saw physical footprint spikes ~167 MiB | Activity Monitor window |
| Δ over long session | E11 ~+6.6 MiB end−start in sampled window | Not a formal leak test |

## FPS

| Title | Avg FPS (E11-US001) | Continuity |
|-------|--------------------:|------------|
| Alea | 0.00 | Stall after first paints (P2) |
| Tetris | 4.01 | OK |
| Astroids | 13.65 | OK |
| Ubertris | 11.84 | OK (1st session) |
| Gryzzles | — | No 5-min sample pre-RMS fix |

Source: accessibility LCD counter during ~5 minute sessions.

## CPU

| Metric | Placeholder | Notes |
|--------|-------------|-------|
| Avg CPU % during stress | ~95.6% in E11 AM sample | UITest input hammer + Zero interpreter |
| Max CPU % | ~114.7% | |

## Future benchmark tables

Planned once Epic 12+ automation stabilizes:

- Cold vs warm launch histograms
- Per-title FPS percentiles (p50/p95)
- RSS over 30-minute sessions
- Battery / thermal notes (qualitative)

Regenerate gameplay FPS cells from `compatibility.json` via `scripts/docs/sync_compatibility.py`.
