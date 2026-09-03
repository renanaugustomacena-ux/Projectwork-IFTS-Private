#!/usr/bin/env python3
"""Validate pixel-art deliverables for the Relax Room character pipeline.

Formato REALE dei personaggi (quello che il gioco carica via
v1/data/characters.json, verificato sulle PNG del repo il 2026-09-03):

  v1/assets/charachters/<gender>/<name>/
    <gender>_idle/<gender>_idle_<dir>.png          128x32  (4 frame 32x32)
    <gender>_walk/<gender>_walk_<dir>.png          128x32
    <gender>_interact/<gender>_interact_<dir>.png  128x32
    <gender>_rotate/<gender>_rotate.png            256x32  (8 frame 32x32)
    *.aseprite                                     almeno una sorgente
  <dir> in DIRECTIONS (8 direzioni; il gioco carica 5 e specchia le *_sx).

Checks:
  - ogni cartella personaggio non legacy ha le 25 PNG con le dimensioni giuste;
  - ha almeno un .aseprite (le cartelle derivate, marcate da DERIVED.md, no:
    sono ricolorazioni generate da ci/recolor_character.py);
  - nomi lowercase_underscore;
  - palette (opt-in --check-palette): ogni pixel opaco e` in
    v1/assets/palette/palette_projectwork.gpl (warning, non errore);
  - gatto: cat_idle/walk/sleep.png 80x16 (5 frame 16x16).

LEGACY_CHARS: cartelle con il formato pre-guida (92x115) che il gioco non
carica; vengono saltate. VARIANT_DIRS: sottocartelle di prova dentro un
personaggio (non sono animazioni).

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

DIRECTIONS = ("down", "down_side", "down_side_sx", "side", "side_sx", "up", "up_side", "up_side_sx")
CHAR_ANIMS = ("idle", "walk", "interact")
CHAR_STRIP_SIZE = (128, 32)
CHAR_ROTATE_SIZE = (256, 32)
PET_SIZE = (80, 16)
PET_ANIMS_REQUIRED = {"idle", "walk", "sleep"}
# Animazioni che la FSM del gatto oggi surroga (PLAY=idle+bob, EAT=idle,
# POTTY=sleep schiacciato...). Se arrivano, il validator le controlla.
PET_ANIMS_OPTIONAL = {"jump", "roll", "play", "annoyed", "surprised", "licking", "eat", "potty"}
PET_ANIMS_ALL = PET_ANIMS_REQUIRED | PET_ANIMS_OPTIONAL

LEGACY_CHARS = {"female_red_shirt", "male_yellow_shirt"}
LEGACY_PETS = {"cat_void_iso", "cat_void_simple"}
VARIANT_DIRS = {"male_black_shirt"}

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


def rel(p: Path) -> str:
    return str(p.relative_to(REPO_ROOT)).replace("\\", "/")


def check_palette(png: Path, palette: set | None, warnings: list[str]) -> None:
    if palette is None:
        return
    bad = png_palette_violations(png, palette)
    if bad:
        sample = ", ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in list(bad)[:3])
        warnings.append(f"{rel(png)}: {len(bad)} colors outside palette ({sample}...)")


def check_character(folder: Path, gender: str, errors: list[str], warnings: list[str], palette: set | None) -> None:
    name = folder.name
    if not NAME_RE.match(name):
        errors.append(f"{rel(folder)}: name '{name}' violates lowercase_underscore convention")

    derived = (folder / "DERIVED.md").is_file()
    if not derived and not list(folder.glob("*.aseprite")):
        errors.append(f"{rel(folder)}: no .aseprite source in the character folder")

    prefix = gender
    expected: dict[Path, tuple[int, int]] = {}
    for anim in CHAR_ANIMS:
        for d in DIRECTIONS:
            expected[folder / f"{prefix}_{anim}" / f"{prefix}_{anim}_{d}.png"] = CHAR_STRIP_SIZE
    expected[folder / f"{prefix}_rotate" / f"{prefix}_rotate.png"] = CHAR_ROTATE_SIZE

    for png, size_expected in expected.items():
        if not png.is_file():
            errors.append(f"{rel(folder)}: missing {rel(png)[len(rel(folder)) + 1:]}")
            continue
        size = png_size(png)
        if size != size_expected:
            errors.append(
                f"{rel(png)}: size {size[0]}x{size[1]} != expected {size_expected[0]}x{size_expected[1]}"
            )
        check_palette(png, palette, warnings)

    known_dirs = {f"{prefix}_{a}" for a in CHAR_ANIMS} | {f"{prefix}_rotate"} | VARIANT_DIRS
    for sub in sorted(p for p in folder.iterdir() if p.is_dir()):
        if sub.name not in known_dirs and not sub.name.startswith(("aseprite", ".")):
            warnings.append(f"{rel(sub)}: unexpected folder (not an animation of '{prefix}')")
    for png in sorted(folder.glob("*.png")):
        warnings.append(f"{rel(png)}: PNG outside the animation folders")


def check_pets(errors: list[str], warnings: list[str], palette: set | None) -> None:
    aseprite_dir = PETS_DIR / "aseprite_pets"
    if not aseprite_dir.is_dir():
        errors.append(f"{rel(PETS_DIR)}: missing aseprite_pets/ folder")

    found_pngs = {
        p.stem: p for p in PETS_DIR.glob("cat_*.png") if not p.name.endswith(".import") and p.stem not in LEGACY_PETS
    }

    for anim in sorted(PET_ANIMS_REQUIRED):
        if f"cat_{anim}" not in found_pngs:
            errors.append(f"{rel(PETS_DIR)}: missing required cat_{anim}.png")

    for stem, png in sorted(found_pngs.items()):
        anim = stem[len("cat_"):]
        if anim not in PET_ANIMS_ALL:
            warnings.append(f"{rel(png)}: unknown cat animation '{anim}'")
            continue
        size = png_size(png)
        if size != PET_SIZE:
            errors.append(f"{rel(png)}: size {size[0]}x{size[1]} != expected {PET_SIZE[0]}x{PET_SIZE[1]}")
        twin = aseprite_dir / f"{stem}.aseprite"
        if not twin.exists():
            warnings.append(f"{rel(png)}: no .aseprite twin at aseprite_pets/{stem}.aseprite")
        check_palette(png, palette, warnings)


def iter_char_folders() -> list[tuple[Path, str]]:
    out: list[tuple[Path, str]] = []
    for gender in ("female", "male"):
        base = CHARS_DIR / gender
        if not base.is_dir():
            continue
        for f in sorted(base.iterdir()):
            if f.is_dir() and f.name not in LEGACY_CHARS and not f.name.startswith(("_", ".")):
                out.append((f, gender))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-palette", action="store_true", help="warn on colors outside palette_projectwork.gpl")
    args = ap.parse_args()

    palette = load_palette() if args.check_palette else None

    errors: list[str] = []
    warnings: list[str] = []

    char_folders = iter_char_folders()
    if not char_folders:
        errors.append(f"{rel(CHARS_DIR)}: no character folders found")
    for folder, gender in char_folders:
        check_character(folder, gender, errors, warnings, palette)

    check_pets(errors, warnings, palette)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"FAIL  {e}")

    if errors:
        print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    names = ", ".join(rel(f) for f, _ in char_folders)
    print(f"\nOK  {len(char_folders)} character folder(s) [{names}] + pets checked, {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
