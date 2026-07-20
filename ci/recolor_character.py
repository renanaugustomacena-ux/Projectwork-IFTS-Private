#!/usr/bin/env python3
"""Genera il set di fogli `male_rose` ricolorando `male/old`.

La rimappatura e` una tabella colore-per-colore sulla palette di progetto
(assets/palette/palette_projectwork.gpl): niente filtri o conversioni HSV,
cosi` la nitidezza pixel resta identica alla sorgente e ogni colore prodotto
e` gia` in palette.

La banda verticale limita la sostituzione alla maglia: gli stessi tre toni
scuri compongono anche pantaloni e capelli, che devono restare invariati.

Uso: python3 ci/recolor_character.py [--check]
  --check  non scrive nulla, verifica solo che i file generati siano
           allineati alla sorgente (utile in CI).
"""
import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - dipendenza opzionale in locale
    print("ERROR: Pillow non installato (pip install 'Pillow>=10,<12')")
    sys.exit(2)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO_ROOT, "v1/assets/charachters/male/old")
DST = os.path.join(REPO_ROOT, "v1/assets/charachters/male/male_rose")

# tono sorgente (maglia scura) -> tono palette rosa
COLOR_MAP = {
    (38, 32, 38): (210, 140, 140),
    (35, 30, 38): (175, 110, 110),
    (30, 25, 30): (175, 110, 110),
}
# righe del frame (32x32) occupate dalla maglia
SHIRT_BAND = (12, 20)
FRAME_HEIGHT = 32
SKIP_DIRS = {"male_black_shirt"}


def recolor(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        if not SHIRT_BAND[0] <= (y % FRAME_HEIGHT) <= SHIRT_BAND[1]:
            continue
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) in COLOR_MAP:
                px[x, y] = COLOR_MAP[(r, g, b)] + (a,)
    return out


def iter_sources():
    for root, _, files in os.walk(SRC):
        rel_dir = os.path.relpath(root, SRC)
        if any(part in SKIP_DIRS for part in rel_dir.split(os.sep)):
            continue
        for name in sorted(files):
            if name.endswith(".png"):
                yield rel_dir, name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verifica senza scrivere")
    args = parser.parse_args()

    written, mismatched, missing = 0, [], []
    for rel_dir, name in iter_sources():
        src_path = os.path.join(SRC, rel_dir, name)
        out_dir = os.path.join(DST, rel_dir) if rel_dir != "." else DST
        dst_path = os.path.join(out_dir, name)
        expected = recolor(Image.open(src_path))

        if args.check:
            if not os.path.isfile(dst_path):
                missing.append(os.path.relpath(dst_path, REPO_ROOT))
                continue
            current = Image.open(dst_path).convert("RGBA")
            if list(current.getdata()) != list(expected.getdata()):
                mismatched.append(os.path.relpath(dst_path, REPO_ROOT))
            continue

        os.makedirs(out_dir, exist_ok=True)
        expected.save(dst_path)
        written += 1

    if args.check:
        for path in missing:
            print(f"MISSING  {path}")
        for path in mismatched:
            print(f"STALE    {path}")
        if missing or mismatched:
            print(f"\nFAILED: {len(missing)} missing, {len(mismatched)} stale")
            return 1
        print("PASSED: fogli derivati allineati alla sorgente")
        return 0

    print(f"PASSED: {written} fogli rigenerati in {os.path.relpath(DST, REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
