#!/usr/bin/env python3
"""Kenney asset backlog helper (T-R-015 addendum).

Scansiona v1/assets/sprites/decorations/kenney_furniture_cc0/ per trovare PNG
non ancora registrati in v1/data/decorations.json. Per ogni PNG non-registrato
stampa una proposta JSON entry con category suggerita dal filename:

Pattern filename -> category:
  bed_*            -> beds
  desk_*, chair_*  -> desks / chairs
  wardrobe_*, bookcase_* -> wardrobes
  window_*         -> windows
  door_*           -> doors
  wall_*           -> wall_decor
  plant_*, potted_*-> potted_plants
  bathroom_*       -> bathroom (NEW category)
  kitchen_*        -> kitchen (NEW category)
  wall_tile_*, floor_tile_* -> tiles (NEW category)
  altro            -> accessories

Output STDOUT: JSON snippet pronto per paste in decorations.json.
Non scrive automaticamente — user decide quali accettare.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

CATEGORY_PATTERNS = [
    (re.compile(r"^bed_?"), "beds"),
    (re.compile(r"^(desk|side_table_drawers)"), "desks"),
    (re.compile(r"^(chair|stool|cushion)"), "chairs"),
    (re.compile(r"^(wardrobe|bookcase|cabinet)"), "wardrobes"),
    (re.compile(r"^window"), "windows"),
    (re.compile(r"^(door|doorway)"), "doors"),
    (re.compile(r"^(plant|potted|cactus|flower)"), "potted_plants"),
    (re.compile(r"^(bathroom|bathtub|toilet|sink|shower)"), "bathroom"),
    (re.compile(r"^(kitchen|stove|fridge|oven|refrigerator|microwave)"), "kitchen"),
    (re.compile(r"^(wall_tile|floor_tile|tile)"), "tiles"),
    (re.compile(r"^wall"), "wall_decor"),
    (re.compile(r"^table_?"), "tables"),
]


def classify(name: str) -> str:
    lower = name.lower()
    for pattern, category in CATEGORY_PATTERNS:
        if pattern.match(lower):
            return category
    return "accessories"


def pretty_name(filename_stem: str) -> str:
    words = filename_stem.replace("_", " ").strip()
    return words.title()


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    kenney_dir = repo / "v1/assets/sprites/decorations/kenney_furniture_cc0"
    catalog_path = repo / "v1/data/decorations.json"

    if not kenney_dir.exists():
        print(f"ERROR: Kenney dir not found: {kenney_dir}")
        return 2
    if not catalog_path.exists():
        print(f"ERROR: catalog not found: {catalog_path}")
        return 2

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    registered_paths: set[str] = set()
    for entry in catalog.get("decorations", []):
        sprite_path = entry.get("sprite_path", "")
        if sprite_path:
            registered_paths.add(sprite_path)

    unregistered: list[Path] = []
    for png in sorted(kenney_dir.rglob("*.png")):
        rel = png.relative_to(repo / "v1")
        res_path = f"res://{rel.as_posix()}"
        if res_path in registered_paths:
            continue
        unregistered.append(png)

    print(f"Found {len(unregistered)} unregistered Kenney PNG")
    print()

    suggestions: list[dict] = []
    for png in unregistered:
        stem = png.stem
        category = classify(stem)
        rel = png.relative_to(repo / "v1").as_posix()
        suggestions.append(
            {
                "id": f"kenney_{stem}",
                "name": pretty_name(stem),
                "category": category,
                "sprite_path": f"res://{rel}",
                "placement_type": "floor" if category != "wall_decor" else "wall",
                "item_scale": 1.0,
                "_origin": "kenney_furniture_cc0",
            }
        )

    # Group by category for easier review
    by_cat: dict[str, list[dict]] = {}
    for s in suggestions:
        by_cat.setdefault(s["category"], []).append(s)

    print("// Paste under 'decorations' array, review categories before accepting:")
    for cat in sorted(by_cat):
        items = by_cat[cat]
        print(f"\n// --- {cat} ({len(items)} items) ---")
        for it in items:
            print(json.dumps(it, ensure_ascii=False, indent=2) + ",")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
