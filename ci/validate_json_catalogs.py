#!/usr/bin/env python3
"""Validate JSON catalog structure and required fields for Mini Cozy Room.

Usage: python ci/validate_json_catalogs.py v1/data
"""
import json
import os
import re
import sys

REQUIRED_DIRECTIONS = [
    "down", "down_side", "down_side_sx", "side", "side_sx", "up", "up_side", "up_side_sx"
]
VALID_PLACEMENT_TYPES = {"floor", "wall", "any"}
HEX_COLOR_RE = re.compile(r"^[0-9a-fA-F]{6}$")


def validate_characters(data, errors):
    if "characters" not in data or not isinstance(data["characters"], list):
        errors.append(("characters.json", "", "missing or invalid 'characters' array"))
        return

    seen_ids = set()
    for i, char in enumerate(data["characters"]):
        prefix = f"characters[{i}]"

        for field in ("id", "name", "gender", "sprite_path", "sprite_type"):
            if field not in char:
                errors.append(("characters.json", prefix, f"missing required field '{field}'"))
            elif not isinstance(char[field], str) or char[field] == "":
                errors.append(("characters.json", f"{prefix}.{field}", "must be a non-empty string"))

        char_id = char.get("id", "")
        if char_id in seen_ids:
            errors.append(("characters.json", f"{prefix}.id", f"duplicate id '{char_id}'"))
        seen_ids.add(char_id)

        if char.get("gender") not in ("male", "female"):
            errors.append(("characters.json", f"{prefix}.gender", f"invalid value '{char.get('gender')}' (expected: male, female)"))

        if char.get("sprite_type") not in ("directional", "simple"):
            errors.append(("characters.json", f"{prefix}.sprite_type", f"invalid value '{char.get('sprite_type')}' (expected: directional, simple)"))

        anims = char.get("animations")
        if not isinstance(anims, dict):
            errors.append(("characters.json", f"{prefix}.animations", "missing or not a dictionary"))
            continue

        for anim_name in ("idle", "walk", "interact"):
            anim = anims.get(anim_name)
            if not isinstance(anim, dict):
                errors.append(("characters.json", f"{prefix}.animations.{anim_name}", "missing or not a dictionary"))
                continue
            for direction in REQUIRED_DIRECTIONS:
                if direction not in anim:
                    errors.append(("characters.json", f"{prefix}.animations.{anim_name}", f"missing direction '{direction}'"))
                elif not isinstance(anim[direction], str) or anim[direction] == "":
                    errors.append(("characters.json", f"{prefix}.animations.{anim_name}.{direction}", "must be a non-empty string"))

        if "rotate" not in anims:
            errors.append(("characters.json", f"{prefix}.animations", "missing 'rotate'"))
        elif not isinstance(anims["rotate"], str) or anims["rotate"] == "":
            errors.append(("characters.json", f"{prefix}.animations.rotate", "must be a non-empty string"))


def validate_decorations(data, errors):
    if "categories" not in data or not isinstance(data["categories"], list):
        errors.append(("decorations.json", "", "missing or invalid 'categories' array"))
        return
    if "decorations" not in data or not isinstance(data["decorations"], list):
        errors.append(("decorations.json", "", "missing or invalid 'decorations' array"))
        return

    category_ids = set()
    for i, cat in enumerate(data["categories"]):
        prefix = f"categories[{i}]"
        for field in ("id", "name"):
            if field not in cat:
                errors.append(("decorations.json", prefix, f"missing required field '{field}'"))
        cat_id = cat.get("id", "")
        if cat_id in category_ids:
            errors.append(("decorations.json", f"{prefix}.id", f"duplicate category id '{cat_id}'"))
        category_ids.add(cat_id)

    seen_ids = set()
    for i, deco in enumerate(data["decorations"]):
        prefix = f"decorations[{i}]"
        for field in ("id", "name", "category", "sprite_path", "placement_type"):
            if field not in deco:
                errors.append(("decorations.json", prefix, f"missing required field '{field}'"))

        deco_id = deco.get("id", "")
        if deco_id in seen_ids:
            errors.append(("decorations.json", f"{prefix}.id", f"duplicate id '{deco_id}'"))
        seen_ids.add(deco_id)

        cat = deco.get("category", "")
        if cat and cat not in category_ids:
            errors.append(("decorations.json", f"{prefix}.category", f"'{cat}' not found in categories"))

        pt = deco.get("placement_type", "")
        if pt and pt not in VALID_PLACEMENT_TYPES:
            errors.append(("decorations.json", f"{prefix}.placement_type", f"invalid value '{pt}' (expected: floor, wall, any)"))

        scale = deco.get("item_scale")
        if "item_scale" in deco:
            if not isinstance(scale, (int, float)) or scale <= 0:
                errors.append(("decorations.json", f"{prefix}.item_scale", f"must be a positive number, got {scale}"))


def validate_rooms(data, errors):
    if "rooms" not in data or not isinstance(data["rooms"], list):
        errors.append(("rooms.json", "", "missing or invalid 'rooms' array"))
        return

    seen_ids = set()
    for i, room in enumerate(data["rooms"]):
        prefix = f"rooms[{i}]"
        for field in ("id", "name", "themes"):
            if field not in room:
                errors.append(("rooms.json", prefix, f"missing required field '{field}'"))

        room_id = room.get("id", "")
        if room_id in seen_ids:
            errors.append(("rooms.json", f"{prefix}.id", f"duplicate id '{room_id}'"))
        seen_ids.add(room_id)

        themes = room.get("themes")
        if not isinstance(themes, list):
            errors.append(("rooms.json", f"{prefix}.themes", "must be an array"))
            continue

        theme_ids = set()
        for j, theme in enumerate(themes):
            tprefix = f"{prefix}.themes[{j}]"
            for field in ("id", "name", "wall_color", "floor_color"):
                if field not in theme:
                    errors.append(("rooms.json", tprefix, f"missing required field '{field}'"))

            theme_id = theme.get("id", "")
            if theme_id in theme_ids:
                errors.append(("rooms.json", f"{tprefix}.id", f"duplicate theme id '{theme_id}'"))
            theme_ids.add(theme_id)

            for color_field in ("wall_color", "floor_color"):
                color = theme.get(color_field, "")
                if color and not HEX_COLOR_RE.match(color):
                    errors.append(("rooms.json", f"{tprefix}.{color_field}", f"invalid hex color '{color}' (expected 6 hex digits)"))


def validate_tracks(data, errors):
    if "tracks" not in data or not isinstance(data["tracks"], list):
        errors.append(("tracks.json", "", "missing or invalid 'tracks' array"))
        return
    if "ambience" not in data or not isinstance(data["ambience"], list):
        errors.append(("tracks.json", "", "missing or invalid 'ambience' array"))
        return

    seen_ids = set()
    for i, track in enumerate(data["tracks"]):
        prefix = f"tracks[{i}]"
        for field in ("id", "title", "artist", "path", "genre"):
            if field not in track:
                errors.append(("tracks.json", prefix, f"missing required field '{field}'"))

        track_id = track.get("id", "")
        if track_id in seen_ids:
            errors.append(("tracks.json", f"{prefix}.id", f"duplicate id '{track_id}'"))
        seen_ids.add(track_id)


VALIDATORS = {
    "characters.json": validate_characters,
    "decorations.json": validate_decorations,
    "rooms.json": validate_rooms,
    "tracks.json": validate_tracks,
}


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <data_dir>")
        sys.exit(2)

    data_dir = sys.argv[1]
    errors = []
    counts = {}

    for filename, validator in VALIDATORS.items():
        path = os.path.join(data_dir, filename)
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            errors.append((filename, "", f"invalid JSON: {e}"))
            continue
        except FileNotFoundError:
            errors.append((filename, "", "file not found"))
            continue

        before = len(errors)
        validator(data, errors)

        # Count validated items
        if filename == "characters.json":
            counts[filename] = f"{len(data.get('characters', []))} characters"
        elif filename == "decorations.json":
            counts[filename] = f"{len(data.get('decorations', []))} decorations, {len(data.get('categories', []))} categories"
        elif filename == "rooms.json":
            rooms = data.get("rooms", [])
            themes = sum(len(r.get("themes", [])) for r in rooms)
            counts[filename] = f"{len(rooms)} rooms, {themes} themes"
        elif filename == "tracks.json":
            counts[filename] = f"{len(data.get('tracks', []))} tracks"

        if len(errors) == before:
            print(f"OK: {filename} — {counts.get(filename, 'validated')}")

    if errors:
        print()
        for filename, location, message in errors:
            loc = f" > {location}" if location else ""
            print(f"ERROR: {filename}{loc}: {message}")
        print(f"\nFAILED: {len(errors)} error(s) found")
        sys.exit(1)
    else:
        print(f"\nPASSED: All catalogs validated")


if __name__ == "__main__":
    main()
