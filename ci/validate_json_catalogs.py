#!/usr/bin/env python3
"""Validate JSON catalog structure and required fields for Relax Room.

Usage: python ci/validate_json_catalogs.py v1/data
"""
import json
import os
import re
import sys

REQUIRED_DIRECTIONS = [
    "down", "down_side", "down_side_sx", "side", "side_sx", "up", "up_side", "up_side_sx"
]
# "any" is retired: every item is either grounded (floor) or wall-mounted.
# The runtime treats unknown values as floor with a warning (Helpers.placement_type_of).
VALID_PLACEMENT_TYPES = {"floor", "wall"}
VALID_ART_SETS = {"individuals", "bongseng", "kenney", "sc", "room", "pets"}
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

        sprite_type = char.get("sprite_type")
        if sprite_type not in ("directional", "simple", "compact"):
            errors.append(("characters.json", f"{prefix}.sprite_type", f"invalid value '{sprite_type}' (expected: directional, simple, compact)"))

        # 'compact' characters only use top-level sprite_path (single idle strip).
        # Skip the full animation-tree check for them.
        if sprite_type != "directional":
            continue

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
            errors.append(("decorations.json", f"{prefix}.placement_type", f"invalid value '{pt}' (expected: floor, wall)"))

        scale = deco.get("item_scale")
        if "item_scale" in deco:
            if not isinstance(scale, (int, float)) or scale <= 0:
                errors.append(("decorations.json", f"{prefix}.item_scale", f"must be a positive number, got {scale}"))

        art = deco.get("art_set", "")
        if not art:
            errors.append(("decorations.json", f"{prefix}.art_set", "missing required field 'art_set' (visual coherence tag)"))
        elif art not in VALID_ART_SETS:
            errors.append(("decorations.json", f"{prefix}.art_set", f"invalid value '{art}' (expected: {', '.join(sorted(VALID_ART_SETS))})"))

        for flag in ("flat", "rotatable", "sittable", "rideable"):
            if flag in deco and not isinstance(deco[flag], bool):
                errors.append(("decorations.json", f"{prefix}.{flag}", f"must be a boolean, got {deco[flag]!r}"))
        if deco.get("flat") and pt != "floor":
            errors.append(("decorations.json", f"{prefix}.flat", "flat items must have placement_type 'floor'"))
        if deco.get("rideable") and not deco.get("sittable"):
            errors.append(("decorations.json", f"{prefix}.rideable", "rideable implies sittable"))

        lo, hi = deco.get("scale_min"), deco.get("scale_max")
        for name, val in (("scale_min", lo), ("scale_max", hi)):
            if val is not None and (not isinstance(val, (int, float)) or val <= 0):
                errors.append(("decorations.json", f"{prefix}.{name}", f"must be a positive number, got {val!r}"))
        if isinstance(lo, (int, float)) and isinstance(hi, (int, float)) and lo > hi:
            errors.append(("decorations.json", f"{prefix}.scale_min", f"scale_min {lo} > scale_max {hi}"))


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



def validate_badges(data, errors):
    """Badges: id univoco, condizione sensata, nomi bilingui, icona esistente."""
    if "badges" not in data or not isinstance(data["badges"], list):
        errors.append(("badges.json", "", "missing or invalid 'badges' array"))
        return

    valid_conditions = {
        "decorations_placed",
        "mood_changes",
        "play_time_seconds",
        "stormy_mood",
    }
    seen_ids = set()
    for i, badge in enumerate(data["badges"]):
        prefix = f"badges[{i}]"
        for field in ("id", "name_it", "name_en", "description_it", "description_en", "icon_path"):
            if field not in badge:
                errors.append(("badges.json", prefix, f"missing required field '{field}'"))

        badge_id = badge.get("id", "")
        if badge_id in seen_ids:
            errors.append(("badges.json", f"{prefix}.id", f"duplicate id '{badge_id}'"))
        seen_ids.add(badge_id)

        condition = badge.get("condition", {})
        if not isinstance(condition, dict):
            errors.append(("badges.json", f"{prefix}.condition", "condition must be an object"))
            continue
        cond_type = condition.get("type", "")
        if cond_type not in valid_conditions:
            errors.append(
                ("badges.json", f"{prefix}.condition.type", f"unknown condition type '{cond_type}'")
            )
        threshold = condition.get("threshold", 0)
        if not isinstance(threshold, int) or threshold < 1:
            errors.append(
                ("badges.json", f"{prefix}.condition.threshold", "threshold must be an int >= 1")
            )

        icon_path = badge.get("icon_path", "")
        if icon_path and not _res_exists(icon_path):
            errors.append(("badges.json", f"{prefix}.icon_path", f"file not found: {icon_path}"))


def validate_shop(data, errors):
    """data/shop.json — fase economia (spec 2026-08-14)."""
    sections = {"food_player", "food_cat", "tools"}
    for section in sections:
        if section not in data or not isinstance(data[section], list):
            errors.append(("shop.json", section, "missing or invalid section array"))
            continue
        seen = set()
        for i, entry in enumerate(data[section]):
            prefix = f"{section}[{i}]"
            for field in ("id", "label_it", "label_en", "price"):
                if field not in entry:
                    errors.append(("shop.json", prefix, f"missing required field '{field}'"))
            eid = entry.get("id", "")
            if eid in seen:
                errors.append(("shop.json", f"{prefix}.id", f"duplicate id '{eid}'"))
            seen.add(eid)
            price = entry.get("price")
            if not isinstance(price, (int, float)) or price < 0:
                errors.append(("shop.json", f"{prefix}.price", f"must be a number >= 0, got {price!r}"))
            if section == "food_player":
                relief = entry.get("stress_relief")
                if not isinstance(relief, (int, float)) or not 0 < relief <= 100:
                    errors.append(("shop.json", f"{prefix}.stress_relief", f"must be in (0, 100], got {relief!r}"))
            if section == "tools":
                mult = entry.get("speed_multiplier")
                if not isinstance(mult, (int, float)) or mult < 1:
                    errors.append(("shop.json", f"{prefix}.speed_multiplier", f"must be >= 1, got {mult!r}"))
    # unique ids ACROSS sections too: the runtime looks items up globally
    all_ids = [e.get("id") for s in sections if isinstance(data.get(s), list) for e in data[s] if isinstance(e, dict)]
    dupes = {i for i in all_ids if all_ids.count(i) > 1}
    for d in sorted(dupes):
        errors.append(("shop.json", "", f"id '{d}' appears in more than one section"))


def validate_mess(data, errors):
    """Mess: id univoco, sprite reale, pesi entro i limiti usati dal codice."""
    if "mess" not in data or not isinstance(data["mess"], list):
        errors.append(("mess_catalog.json", "", "missing or invalid 'mess' array"))
        return

    seen_ids = set()
    for i, entry in enumerate(data["mess"]):
        prefix = f"mess[{i}]"
        for field in ("id", "label_it", "label_en", "stress_weight", "spawn_weight", "sprite_path", "size_px"):
            if field not in entry:
                errors.append(("mess_catalog.json", prefix, f"missing required field '{field}'"))

        mess_id = entry.get("id", "")
        if mess_id in seen_ids:
            errors.append(("mess_catalog.json", f"{prefix}.id", f"duplicate id '{mess_id}'"))
        seen_ids.add(mess_id)

        stress = entry.get("stress_weight", 0)
        if not isinstance(stress, (int, float)) or not 0 < stress <= 1:
            errors.append(
                ("mess_catalog.json", f"{prefix}.stress_weight", "stress_weight must be in (0, 1]")
            )

        size_px = entry.get("size_px", 0)
        # mess_node clamps to 12..96: valori fuori range mentono sul risultato
        if not isinstance(size_px, int) or not 12 <= size_px <= 96:
            errors.append(("mess_catalog.json", f"{prefix}.size_px", "size_px must be an int in 12..96"))

        sprite_path = entry.get("sprite_path", "")
        if not sprite_path:
            errors.append(
                ("mess_catalog.json", f"{prefix}.sprite_path", "sprite_path is empty (runtime placeholder)")
            )
        elif not _res_exists(sprite_path):
            errors.append(("mess_catalog.json", f"{prefix}.sprite_path", f"file not found: {sprite_path}"))

    # Fase economia (spec 2026-08-14): pulizia a tempo obbligatoria per voce.
    for i, entry in enumerate(data.get("mess", [])):
        prefix = f"mess[{i}]"
        dur = entry.get("clean_duration_sec")
        if not isinstance(dur, (int, float)) or dur <= 0:
            errors.append(("mess_catalog.json", f"{prefix}.clean_duration_sec", f"must be a number > 0, got {dur!r}"))
        rew = entry.get("clean_reward")
        if not isinstance(rew, (int, float)) or rew < 0:
            errors.append(("mess_catalog.json", f"{prefix}.clean_reward", f"must be a number >= 0, got {rew!r}"))

def _res_exists(res_path):
    """res:// -> percorso reale, relativo alla cartella data/ passata a main()."""
    if not res_path.startswith("res://"):
        return False
    return os.path.isfile(os.path.join(_PROJECT_ROOT, res_path[len("res://"):]))


VALIDATORS = {
    "characters.json": validate_characters,
    "decorations.json": validate_decorations,
    "rooms.json": validate_rooms,
    "tracks.json": validate_tracks,
    "badges.json": validate_badges,
    "mess_catalog.json": validate_mess,
    "shop.json": validate_shop,
}

# Radice del progetto Godot: i cataloghi vivono in <root>/data/
_PROJECT_ROOT = ""


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <data_dir>")
        sys.exit(2)

    data_dir = sys.argv[1]
    global _PROJECT_ROOT
    _PROJECT_ROOT = os.path.dirname(os.path.abspath(data_dir))
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
            counts[filename] = (
                f"{len(data.get('tracks', []))} tracks, {len(data.get('ambience', []))} ambience"
            )
        elif filename == "badges.json":
            counts[filename] = f"{len(data.get('badges', []))} badges"
        elif filename == "mess_catalog.json":
            counts[filename] = f"{len(data.get('mess', []))} mess types"
        elif filename == "shop.json":
            total = sum(len(data.get(s, [])) for s in ("food_player", "food_cat", "tools"))
            counts[filename] = f"{total} shop items"

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
