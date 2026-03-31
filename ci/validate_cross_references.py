#!/usr/bin/env python3
"""Validate that CHAR_*, ROOM_*, THEME_* constants in constants.gd reference IDs
that exist in the JSON catalogs.

Usage: python ci/validate_cross_references.py v1/scripts/utils/constants.gd v1/data
"""
import json
import os
import re
import sys

# Regex to extract GDScript string constants: const NAME := "value"
CONST_RE = re.compile(r'^const\s+(\w+)\s*:=\s*"([^"]*)"', re.MULTILINE)

# Mapping: constant prefix -> (catalog filename, path to ID list)
PREFIX_MAP = {
    "CHAR_": ("characters.json", lambda d: {c["id"] for c in d.get("characters", [])}),
    "ROOM_": ("rooms.json", lambda d: {r["id"] for r in d.get("rooms", [])}),
    "THEME_": ("rooms.json", lambda d: {t["id"] for r in d.get("rooms", []) for t in r.get("themes", [])}),
}


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <constants.gd> <data_dir>")
        sys.exit(2)

    constants_path = sys.argv[1]
    data_dir = sys.argv[2]

    # Read constants.gd
    with open(constants_path, encoding="utf-8") as f:
        content = f.read()

    all_consts = CONST_RE.findall(content)

    # Load catalogs and extract valid IDs
    catalog_ids = {}
    for prefix, (filename, extractor) in PREFIX_MAP.items():
        if filename not in catalog_ids:
            path = os.path.join(data_dir, filename)
            try:
                with open(path, encoding="utf-8") as f:
                    catalog_ids[filename] = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"ERROR: Cannot load {filename}: {e}")
                sys.exit(1)

    # Cross-reference
    errors = []
    checked = 0

    for const_name, const_value in all_consts:
        for prefix, (filename, extractor) in PREFIX_MAP.items():
            if const_name.startswith(prefix):
                checked += 1
                valid_ids = extractor(catalog_ids[filename])
                if const_value not in valid_ids:
                    errors.append((const_name, const_value, filename, sorted(valid_ids)))
                break

    if errors:
        for const_name, const_value, filename, valid_ids in errors:
            ids_str = ", ".join(valid_ids) if valid_ids else "(none)"
            print(f"ERROR: constants.gd > {const_name}: value \"{const_value}\" not found in {filename}")
            print(f"  Available IDs: {ids_str}")
            print()
        print(f"FAILED: {len(errors)} orphaned constant(s) out of {checked} checked")
        sys.exit(1)
    else:
        print(f"PASSED: All {checked} cross-references verified")


if __name__ == "__main__":
    main()
