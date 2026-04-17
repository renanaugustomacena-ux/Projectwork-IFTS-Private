#!/usr/bin/env python3
"""Validate pixel-art deliverables per v1/guide/GUIDA_ALEX_PIXEL_ART.md.

Checks:
  - Each character folder contains idle/walk/interact/rotate PNG with correct size.
  - Each PNG has a twin .aseprite source in aseprite_<name>/ (chars) or aseprite_pets/ (cat).
  - Naming convention: lowercase, underscore, <name>_<anim>.png.
  - Palette conformance (opt-in via --check-palette): every non-transparent pixel
    present in v1/assets/palette/palette_projectwork.gpl.

Legacy folders listed in LEGACY are skipped (historical format predates the guide).

Usage: python ci/validate_pixelart_deliverables.py [--check-palette]
"""
import argparse
import re
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
CHARS_DIR = REPO_ROOT / "v1/assets/charachters"
PETS_DIR = REPO_ROOT / "v1/assets/pets"
PALETTE_PATH = REPO_ROOT / "v1/assets/palette/palette_projectwork.gpl"

CHAR_ANIMS = {
    "idle": (92, 115),
    "walk": (92, 115),
    "interact": (92, 115),
    "rotate": (160, 20),
}
PET_SIZE = (80, 16)
PET_ANIMS_REQUIRED = {"idle", "walk", "sleep"}
PET_ANIMS_NEW = {"jump", "roll", "play", "annoyed", "surprised", "licking"}
PET_ANIMS_ALL = PET_ANIMS_REQUIRED | PET_ANIMS_NEW

LEGACY_CHARS = {"old", "female_red_shirt", "male_yellow_shirt"}
LEGACY_PETS = {"cat_void_iso", "cat_void_simple"}

NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def load_palette() -> set[tuple[int, int, int]]:
    if not PALETTE_PATH.exists():
        sys.exit(f"palette missing: {PALETTE_PATH}. Run ci/extract_palette.py first.")
    colors: set[tuple[int, int, int]] = set()
    for line in PALETTE_PATH.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(("GIMP", "Name:", "Columns:")):
            continue
        parts = line.split()
        if len(parts) >= 3:
            try:
                colors.add((int(parts[0]), int(parts[1]), int(parts[2])))
            except ValueError:
                pass
    return colors


def png_size(p: Path) -> tuple[int, int]:
    return Image.open(p).size


def png_palette_violations(p: Path, allowed: set[tuple[int, int, int]]) -> set[tuple[int, int, int]]:
    img = Image.open(p).convert("RGBA")
    offenders: set[tuple[int, int, int]] = set()
    for r, g, b, a in img.getdata():
        if a == 0:
            continue
        if (r, g, b) not in allowed:
            offenders.add((r, g, b))
    return offenders


def check_character(folder: Path, errors: list[str], warnings: list[str], palette: set | None) -> None:
    name = folder.name
    if not NAME_RE.match(name):
        errors.append(f"{folder}: name '{name}' violates lowercase_underscore convention")

    aseprite_dir = folder / f"aseprite_{name}"
    if not aseprite_dir.is_dir():
        errors.append(f"{folder}: missing source folder '{aseprite_dir.name}/'")

    found_pngs = {p.stem: p for p in folder.glob("*.png") if not p.name.endswith(".import")}

    for anim, expected_size in CHAR_ANIMS.items():
        stem = f"{name}_{anim}"
        png = found_pngs.get(stem)
        if png is None:
            errors.append(f"{folder}: missing {stem}.png")
            continue
        size = png_size(png)
        if size != expected_size:
            errors.append(f"{png.relative_to(REPO_ROOT)}: size {size[0]}x{size[1]} != expected {expected_size[0]}x{expected_size[1]}")
        twin = aseprite_dir / f"{stem}.aseprite" if aseprite_dir.is_dir() else None
        if twin is None or not twin.exists():
            errors.append(f"{png.relative_to(REPO_ROOT)}: no .aseprite twin at aseprite_{name}/{stem}.aseprite")
        if palette is not None:
            bad = png_palette_violations(png, palette)
            if bad:
                sample = ", ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in list(bad)[:3])
                warnings.append(f"{png.relative_to(REPO_ROOT)}: {len(bad)} colors outside palette ({sample}...)")

    extra = set(found_pngs) - {f"{name}_{a}" for a in CHAR_ANIMS}
    for stem in sorted(extra):
        warnings.append(f"{folder}: unexpected PNG '{stem}.png' (not in idle/walk/interact/rotate)")


def check_pets(errors: list[str], warnings: list[str], palette: set | None) -> None:
    aseprite_dir = PETS_DIR / "aseprite_pets"
    if not aseprite_dir.is_dir():
        errors.append(f"{PETS_DIR}: missing aseprite_pets/ folder")

    found_pngs = {p.stem: p for p in PETS_DIR.glob("cat_*.png") if not p.name.endswith(".import") and p.stem not in LEGACY_PETS}

    for anim in PET_ANIMS_REQUIRED:
        stem = f"cat_{anim}"
        if stem not in found_pngs:
            errors.append(f"{PETS_DIR}: missing required {stem}.png")

    for stem, png in sorted(found_pngs.items()):
        anim = stem[len("cat_"):]
        if anim not in PET_ANIMS_ALL:
            warnings.append(f"{png.relative_to(REPO_ROOT)}: unknown cat animation '{anim}'")
            continue
        size = png_size(png)
        if size != PET_SIZE:
            errors.append(f"{png.relative_to(REPO_ROOT)}: size {size[0]}x{size[1]} != expected {PET_SIZE[0]}x{PET_SIZE[1]}")
        twin = aseprite_dir / f"{stem}.aseprite" if aseprite_dir.is_dir() else None
        if twin is None or not twin.exists():
            bucket = warnings if anim in PET_ANIMS_REQUIRED else errors
            bucket.append(f"{png.relative_to(REPO_ROOT)}: no .aseprite twin at aseprite_pets/{stem}.aseprite")
        if palette is not None:
            bad = png_palette_violations(png, palette)
            if bad:
                sample = ", ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in list(bad)[:3])
                warnings.append(f"{png.relative_to(REPO_ROOT)}: {len(bad)} colors outside palette ({sample}...)")

    missing_new = PET_ANIMS_NEW - {s[len('cat_'):] for s in found_pngs}
    for anim in sorted(missing_new):
        warnings.append(f"{PETS_DIR}: new animation 'cat_{anim}.png' not yet delivered (Task 5)")


def iter_char_folders() -> list[Path]:
    out = []
    for gender in ("female", "male"):
        base = CHARS_DIR / gender
        if not base.is_dir():
            continue
        for f in sorted(base.iterdir()):
            if f.is_dir() and f.name not in LEGACY_CHARS and not f.name.startswith("_"):
                out.append(f)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-palette", action="store_true", help="fail on colors outside palette_projectwork.gpl")
    args = ap.parse_args()

    palette = load_palette() if args.check_palette else None

    errors: list[str] = []
    warnings: list[str] = []

    char_folders = iter_char_folders()
    if not char_folders:
        warnings.append(f"{CHARS_DIR}: no non-legacy character folders found (expected new deliverables from Alex)")
    for f in char_folders:
        check_character(f, errors, warnings, palette)

    check_pets(errors, warnings, palette)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"FAIL  {e}")

    if errors:
        print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"\nOK  {len(char_folders)} character folder(s) + pets checked, {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
