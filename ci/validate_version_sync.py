#!/usr/bin/env python3
"""Validate v1/VERSION matches export_presets.cfg + project.godot + constants.gd.

Fallisce se qualunque consumer della versione drift rispetto alla source
of truth `v1/VERSION`. Usato come CI guard dopo ogni push/PR.

Exit codes:
  0 - All in sync
  1 - Mismatch found
  2 - File missing / malformed
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def read_source_of_truth(version_file: Path) -> str | None:
    if not version_file.exists():
        print(f"ERROR: {version_file} non esiste", file=sys.stderr)
        return None
    content = version_file.read_text(encoding="utf-8").strip()
    if not VERSION_RE.match(content):
        print(
            f"ERROR: {version_file} non contiene semver X.Y.Z: '{content}'",
            file=sys.stderr,
        )
        return None
    return content


def check_presets(presets_path: Path, expected: str) -> list[str]:
    """Ritorna lista di mismatch trovati (stringhe errore)."""
    errors: list[str] = []
    if not presets_path.exists():
        return [f"{presets_path} non esiste"]
    text = presets_path.read_text(encoding="utf-8")

    # Ogni campo deve matchare expected
    patterns = {
        "application/file_version": rf'application/file_version\s*=\s*"{re.escape(expected)}"',
        "application/product_version": rf'application/product_version\s*=\s*"{re.escape(expected)}"',
        "version/name": rf'version/name\s*=\s*"{re.escape(expected)}"',
    }

    for field, pattern in patterns.items():
        if not re.search(pattern, text):
            # Catch il valore attuale per diagnostica
            current_match = re.search(
                rf'{re.escape(field)}\s*=\s*"([^"]*)"', text
            )
            current = current_match.group(1) if current_match else "(assente)"
            errors.append(
                f"export_presets.cfg: {field} e' '{current}', atteso '{expected}'"
            )
    return errors


def check_project_godot(godot_path: Path, expected: str) -> list[str]:
    if not godot_path.exists():
        return [f"{godot_path} non esiste"]
    text = godot_path.read_text(encoding="utf-8")
    match = re.search(r'^config/version\s*=\s*"([^"]*)"', text, re.MULTILINE)
    if not match:
        return ["project.godot: config/version non presente"]
    if match.group(1) != expected:
        return [
            f"project.godot: config/version e' '{match.group(1)}', atteso '{expected}'"
        ]
    return []


def check_constants(constants_path: Path, expected: str) -> list[str]:
    if not constants_path.exists():
        return [f"{constants_path} non esiste"]
    text = constants_path.read_text(encoding="utf-8")
    match = re.search(
        r'^const\s+APP_VERSION\s*:=\s*"([^"]*)"', text, re.MULTILINE
    )
    if not match:
        return ["constants.gd: APP_VERSION non presente"]
    if match.group(1) != expected:
        return [
            f"constants.gd: APP_VERSION e' '{match.group(1)}', atteso '{expected}'"
        ]
    return []


def main() -> int:
    repo = Path(__file__).resolve().parent.parent

    expected = read_source_of_truth(repo / "v1" / "VERSION")
    if expected is None:
        return 2

    all_errors: list[str] = []
    all_errors.extend(check_presets(repo / "v1" / "export_presets.cfg", expected))
    all_errors.extend(check_project_godot(repo / "v1" / "project.godot", expected))
    all_errors.extend(
        check_constants(
            repo / "v1" / "scripts" / "utils" / "constants.gd", expected
        )
    )

    if all_errors:
        print(f"FAIL: version sync violations (source of truth: {expected})")
        for err in all_errors:
            print(f"  - {err}")
        print(
            "\nFix: esegui 'python3 scripts/sync_version_to_presets.py "
            f"{expected}' per allineare.",
            file=sys.stderr,
        )
        return 1

    print(f"PASS: version sync OK (all consumers at {expected})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
