#!/usr/bin/env python3
"""Extract shared palette from male/old PNGs into a GIMP .gpl file.

Automates Task 1 of v1/guide/GUIDA_ALEX_PIXEL_ART.md.
Scans every non-transparent pixel in v1/assets/charachters/male/old/**/*.png,
collects unique RGB tuples, writes v1/assets/palette/palette_projectwork.gpl.

Usage: python ci/extract_palette.py [--check]
  --check  exit non-zero if palette file is missing or stale vs sources
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = REPO_ROOT / "v1/assets/charachters/male/old"
OUT_PATH = REPO_ROOT / "v1/assets/palette/palette_projectwork.gpl"
PALETTE_NAME = "Projectwork Shared Palette"


def collect_colors(source_dir: Path) -> list[tuple[int, int, int]]:
    pngs = sorted(p for p in source_dir.rglob("*.png") if not p.name.endswith(".import"))
    if not pngs:
        sys.exit(f"no PNG found under {source_dir}")
    seen: set[tuple[int, int, int]] = set()
    for p in pngs:
        img = Image.open(p).convert("RGBA")
        for r, g, b, a in img.getdata():
            if a == 0:
                continue
            seen.add((r, g, b))
    # sort by perceived luminance (dark first), stable for diff-friendly output
    return sorted(seen, key=lambda c: (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2], c))


def render_gpl(colors: list[tuple[int, int, int]]) -> str:
    lines = [
        "GIMP Palette",
        f"Name: {PALETTE_NAME}",
        "Columns: 8",
        "#",
    ]
    for r, g, b in colors:
        hexcode = f"#{r:02x}{g:02x}{b:02x}"
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{hexcode}")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if output missing or stale")
    args = ap.parse_args()

    colors = collect_colors(SOURCE_DIR)
    content = render_gpl(colors)

    if args.check:
        if not OUT_PATH.exists():
            print(f"FAIL: {OUT_PATH} missing. Run: python ci/extract_palette.py")
            return 1
        existing = OUT_PATH.read_text()
        if existing != content:
            print(f"FAIL: {OUT_PATH} stale vs sources. Run: python ci/extract_palette.py")
            return 1
        print(f"OK: palette up to date ({len(colors)} colors)")
        return 0

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(content)
    print(f"wrote {OUT_PATH} ({len(colors)} colors from {SOURCE_DIR})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
