#!/usr/bin/env python3
"""Sync root compatibility/ data into docs/ and regenerate the matrix page."""

from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "compatibility"
DST = ROOT / "docs" / "compatibility"


def main() -> None:
    if not (SRC / "compatibility.json").is_file():
        raise SystemExit(f"missing {SRC / 'compatibility.json'}")

    DST.mkdir(parents=True, exist_ok=True)
    (DST / "games").mkdir(parents=True, exist_ok=True)

    shutil.copy2(SRC / "compatibility.json", DST / "compatibility.json")
    shutil.copy2(SRC / "compatibility.csv", DST / "compatibility.csv")

    for game in (SRC / "games").glob("*.md"):
        shutil.copy2(game, DST / "games" / game.name)

    data = json.loads((SRC / "compatibility.json").read_text())
    games = data["games"]
    validation = data["validation"]

    rows: list[str] = []
    for g in games:
        fps = "—" if g.get("fps") is None else f'{g["fps"]:.2f}'
        title = g["title"]
        rows.append(
            f"| [{title}](compatibility/games/{title}.md) | {g['status']} | {fps} | "
            f"{g['rms']} | {g['touch']} | {g['keypad']} | {g['audio']} | {g['notes']} |"
        )

    page = f"""# Compatibility

JavaOne tracks MIDlet compatibility from **device validation reports**, not anecdotal runs.

Machine-readable sources:

- Repo: [`compatibility/compatibility.json`](https://github.com/javaonelabs/JavaOne/blob/main/compatibility/compatibility.json) · [`compatibility.csv`](https://github.com/javaonelabs/JavaOne/blob/main/compatibility/compatibility.csv)
- Site downloads: [JSON](compatibility/compatibility.json) · [CSV](compatibility/compatibility.csv)

**Validation baseline:** {validation['date']} · {validation['device']} · iOS {validation['ios']}  
**Runtime:** {validation['runtime']}  
**Primary reports:** E11-US001 (gameplay), E11-US002 (relaunch), E11-US003 (RMS)

## Corpus matrix

| Game | Status | FPS | RMS | Touch | Keypad | Audio | Notes |
|------|--------|-----|-----|-------|--------|-------|-------|
{chr(10).join(rows)}

## Status legend

| Status | Meaning |
|--------|---------|
| Playable | Launches and sustains interactive gameplay on device |
| Partial | Launches with significant limitations |
| Broken | Fails to launch or is unusable |
| Untested | Not measured in the referenced validation runs |

## How to read FPS

FPS values come from the E11-US001 accessibility LCD frame counter over ~5 minute sessions.

- **Astroids / Ubertris** show strong continuous painter throughput.
- **Tetris** is playable with moderate frame growth.
- **Alea** paints initially but the counter stalls (input-driven / sparse updates) — still marked Playable for interaction, with a P2 note.
- **Gryzzles** has no 5-minute FPS sample from E11-US001 because launch failed before the RMS fix; post-fix launches succeeded in E11-US003 without a timed FPS capture.

## Audio

Audio / MMAPI was **out of scope** for E11 validation. Cells marked Untested are intentional.

## Per-game reports

- [Alea](compatibility/games/Alea.md)
- [Astroids](compatibility/games/Astroids.md)
- [Tetris](compatibility/games/Tetris.md)
- [Gryzzles](compatibility/games/Gryzzles.md)
- [Ubertris](compatibility/games/Ubertris.md)
"""
    (ROOT / "docs" / "compatibility.md").write_text(page)

    # Keep CSV aligned with JSON field order
    with (SRC / "compatibility.csv").open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "title",
                "status",
                "fps",
                "rms",
                "touch",
                "keypad",
                "audio",
                "notes",
                "jar",
                "sources",
            ],
        )
        writer.writeheader()
        for g in games:
            writer.writerow(
                {
                    "title": g["title"],
                    "status": g["status"],
                    "fps": "" if g.get("fps") is None else g["fps"],
                    "rms": g["rms"],
                    "touch": g["touch"],
                    "keypad": g["keypad"],
                    "audio": g["audio"],
                    "notes": g["notes"],
                    "jar": g["jar"],
                    "sources": ";".join(g.get("sources", [])),
                }
            )
    shutil.copy2(SRC / "compatibility.csv", DST / "compatibility.csv")
    print(f"synced {len(games)} games → docs/compatibility/")


if __name__ == "__main__":
    main()
