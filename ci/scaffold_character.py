#!/usr/bin/env python3
"""Create the folder structure for a new character deliverable.

The structure mirrors the one the game loads today (see
v1/data/characters.json and v1/assets/charachters/male/old/):

  v1/assets/charachters/<gender>/<name>/
    <gender>_idle/<gender>_idle_<dir>.png        8 strips, 128x32 (4 frames 32x32)
    <gender>_walk/<gender>_walk_<dir>.png        8 strips, 128x32
    <gender>_interact/<gender>_interact_<dir>.png  8 strips, 128x32
    <gender>_rotate/<gender>_rotate.png          1 strip, 256x32 (8 frames)
    *.aseprite                                   sorgenti (almeno uno)

  <dir> in: down, down_side, down_side_sx, side, side_sx, up, up_side, up_side_sx

ci/validate_pixelart_deliverables.py checks that the PNGs land with the right
sizes and that every opaque pixel is in v1/assets/palette/palette_projectwork.gpl.

Usage: python ci/scaffold_character.py --gender female --name maria
"""
import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CHARS_DIR = REPO_ROOT / "v1/assets/charachters"
ANIMS = ("idle", "walk", "interact")
DIRECTIONS = ("down", "down_side", "down_side_sx", "side", "side_sx", "up", "up_side", "up_side_sx")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gender", required=True, choices=["female", "male"])
    ap.add_argument("--name", required=True, help="lowercase, underscore, e.g. 'maria' or 'tom_cook'")
    args = ap.parse_args()

    if not args.name.replace("_", "").isalnum() or not args.name.islower():
        sys.exit(f"name '{args.name}' must be lowercase letters/digits/underscore")

    folder = CHARS_DIR / args.gender / args.name
    if folder.exists():
        sys.exit(f"{folder} already exists; aborting to avoid overwrite")

    prefix = args.gender
    expected: list[Path] = []
    for anim in ANIMS:
        sub = folder / f"{prefix}_{anim}"
        sub.mkdir(parents=True)
        (sub / ".gitkeep").touch()
        expected += [sub / f"{prefix}_{anim}_{d}.png" for d in DIRECTIONS]
    rot = folder / f"{prefix}_rotate"
    rot.mkdir(parents=True)
    (rot / ".gitkeep").touch()
    expected.append(rot / f"{prefix}_rotate.png")

    print("scaffolded:")
    print(f"  {folder.relative_to(REPO_ROOT)}/")
    print()
    print(f"File attesi ({len(expected)} PNG + almeno un .aseprite nella cartella):")
    for p in expected:
        size = "256x32" if p.parent.name.endswith("_rotate") else "128x32"
        print(f"  {p.relative_to(REPO_ROOT)}  ({size})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
