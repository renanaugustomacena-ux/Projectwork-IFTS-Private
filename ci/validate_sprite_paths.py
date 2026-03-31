#!/usr/bin/env python3
"""Validate that all res:// sprite and audio paths in JSON catalogs point to existing files.

Usage: python ci/validate_sprite_paths.py v1
       (where v1 is the Godot project root containing project.godot)
"""
import json
import os
import sys


def collect_paths_characters(data, paths):
    for i, char in enumerate(data.get("characters", [])):
        sp = char.get("sprite_path", "")
        if sp:
            paths.append(("characters.json", f"characters[{i}].sprite_path", sp))

        anims = char.get("animations", {})
        for anim_name in ("idle", "walk", "interact"):
            anim = anims.get(anim_name, {})
            if isinstance(anim, dict):
                for direction, path in anim.items():
                    if isinstance(path, str) and path:
                        paths.append(("characters.json", f"characters[{i}].animations.{anim_name}.{direction}", path))

        rotate = anims.get("rotate", "")
        if isinstance(rotate, str) and rotate:
            paths.append(("characters.json", f"characters[{i}].animations.rotate", rotate))


def collect_paths_decorations(data, paths):
    for i, deco in enumerate(data.get("decorations", [])):
        sp = deco.get("sprite_path", "")
        if sp:
            paths.append(("decorations.json", f"decorations[{i}].sprite_path", sp))


def collect_paths_tracks(data, paths):
    for i, track in enumerate(data.get("tracks", [])):
        p = track.get("path", "")
        if p:
            paths.append(("tracks.json", f"tracks[{i}].path", p))
    for i, amb in enumerate(data.get("ambience", [])):
        p = amb.get("path", "")
        if p:
            paths.append(("tracks.json", f"ambience[{i}].path", p))


def resolve_res_path(res_path, project_root):
    """Convert res://path/to/file to project_root/path/to/file."""
    if res_path.startswith("res://"):
        return os.path.join(project_root, res_path[len("res://"):])
    return os.path.join(project_root, res_path)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <godot_project_root>")
        sys.exit(2)

    project_root = sys.argv[1]
    data_dir = os.path.join(project_root, "data")

    # Collect all res:// paths from catalogs
    all_paths = []

    catalog_collectors = {
        "characters.json": collect_paths_characters,
        "decorations.json": collect_paths_decorations,
        "tracks.json": collect_paths_tracks,
    }

    for filename, collector in catalog_collectors.items():
        path = os.path.join(data_dir, filename)
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            collector(data, all_paths)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"ERROR: {filename}: cannot load — {e}")
            sys.exit(1)

    # Validate each path exists on disk
    errors = []
    checked = 0
    for source_file, location, res_path in all_paths:
        fs_path = resolve_res_path(res_path, project_root)
        checked += 1
        if not os.path.isfile(fs_path):
            errors.append((source_file, location, res_path, fs_path))

    if errors:
        for source_file, location, res_path, fs_path in errors:
            print(f"ERROR: {source_file} > {location}: file not found")
            print(f"  Path: {res_path}")
            print(f"  Expected at: {fs_path}")
            print()
        print(f"FAILED: {len(errors)} missing file(s) out of {checked} checked")
        sys.exit(1)
    else:
        print(f"PASSED: All {checked} sprite/audio paths verified")


if __name__ == "__main__":
    main()
