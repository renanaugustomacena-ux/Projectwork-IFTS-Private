#!/usr/bin/env python3
"""Create empty folder structure for a new character deliverable.

Run once per character (Task 2 / Task 3 of GUIDA_ALEX_PIXEL_ART.md) after Renan
and Alex have agreed on the character name. The validator
(ci/validate_pixelart_deliverables.py) will then check that the expected PNGs
and .aseprite sources land inside this structure.

Usage: python ci/scaffold_character.py --gender female --name maria
"""
import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CHARS_DIR = REPO_ROOT / "v1/assets/charachters"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gender", required=True, choices=["female", "male"])
    ap.add_argument("--name", required=True, help="lowercase, underscore, e.g. 'maria' or 'tom_cook'")
    args = ap.parse_args()

    if not args.name.replace("_", "").isalnum() or not args.name.islower():
        sys.exit(f"name '{args.name}' must be lowercase letters/digits/underscore")

    folder = CHARS_DIR / args.gender / args.name
    source_dir = folder / f"aseprite_{args.name}"

    if folder.exists():
        sys.exit(f"{folder} already exists; aborting to avoid overwrite")

    source_dir.mkdir(parents=True)
    keep = source_dir / ".gitkeep"
    keep.touch()

    print(f"scaffolded:")
    print(f"  {folder.relative_to(REPO_ROOT)}/")
    print(f"  {source_dir.relative_to(REPO_ROOT)}/.gitkeep")
    print()
    print("Alex next: export 4 PNG + 4 .aseprite into these folders:")
    for anim in ("idle", "walk", "interact", "rotate"):
        print(f"  {folder.relative_to(REPO_ROOT)}/{args.name}_{anim}.png")
    print(f"  ({args.name}_rotate.png is 160x20, others 92x115)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
