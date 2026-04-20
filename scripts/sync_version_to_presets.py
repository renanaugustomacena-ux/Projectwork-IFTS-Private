#!/usr/bin/env python3
"""Sync v1/VERSION -> export_presets.cfg + project.godot + constants.gd.

Usage: python3 scripts/sync_version_to_presets.py 1.2.3

Non-destructive: riscrive solo i campi target tramite regex. Preserva
l'ordine dei preset e il resto del file. Idempotente.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def bump_presets(presets_path: Path, new_version: str) -> list[str]:
    """Aggiorna application/file_version, application/product_version,
    version/name in export_presets.cfg. Ritorna lista dei campi patchati."""
    text = presets_path.read_text(encoding="utf-8")
    patched: list[str] = []

    # Windows preset fields
    text, n = re.subn(
        r'(application/file_version\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    if n:
        patched.append(f"application/file_version x{n}")

    text, n = re.subn(
        r'(application/product_version\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    if n:
        patched.append(f"application/product_version x{n}")

    # Android preset field
    text, n = re.subn(
        r'(version/name\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    if n:
        patched.append(f"version/name x{n}")

    presets_path.write_text(text, encoding="utf-8")
    return patched


def bump_project_godot(godot_path: Path, new_version: str) -> bool:
    """Aggiorna config/version in project.godot. Crea la key se assente.

    Ritorna True se il file è stato modificato.
    """
    text = godot_path.read_text(encoding="utf-8")
    original = text

    if re.search(r'^config/version\s*=\s*"[^"]*"', text, re.MULTILINE):
        text = re.sub(
            r'(^config/version\s*=\s*)"[^"]*"',
            rf'\1"{new_version}"',
            text,
            flags=re.MULTILINE,
        )
    else:
        # Inserisci dopo config/name
        replacement = (
            f'config/name="Relax Room"\n'
            f'config/version="{new_version}"'
        )
        text = text.replace('config/name="Relax Room"', replacement, 1)

    if text != original:
        godot_path.write_text(text, encoding="utf-8")
        return True
    return False


def bump_constants(constants_path: Path, new_version: str) -> bool:
    """Aggiorna const APP_VERSION := "X.Y.Z" in constants.gd.

    Crea la const se assente (append alla fine). Ritorna True se modificato.
    """
    text = constants_path.read_text(encoding="utf-8")
    original = text

    if re.search(r'^const\s+APP_VERSION\s*:=', text, re.MULTILINE):
        text = re.sub(
            r'(^const\s+APP_VERSION\s*:=\s*)"[^"]*"',
            rf'\1"{new_version}"',
            text,
            flags=re.MULTILINE,
        )
    else:
        # Append nuova const prima dell'ultima riga utile
        # Strategia: append alla fine del file (stile constants.gd esistente)
        if not text.endswith("\n"):
            text += "\n"
        text += (
            "\n# Application version — synced da scripts/bump_version.sh\n"
            f'const APP_VERSION := "{new_version}"\n'
        )

    if text != original:
        constants_path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: sync_version_to_presets.py X.Y.Z", file=sys.stderr)
        return 2
    new_version = sys.argv[1]
    if not VERSION_RE.match(new_version):
        print(
            f"ERROR: version '{new_version}' non e` semver X.Y.Z",
            file=sys.stderr,
        )
        return 2

    repo = Path(__file__).resolve().parent.parent

    presets_path = repo / "v1" / "export_presets.cfg"
    godot_path = repo / "v1" / "project.godot"
    constants_path = repo / "v1" / "scripts" / "utils" / "constants.gd"

    missing = [p for p in [presets_path, godot_path, constants_path] if not p.exists()]
    if missing:
        for p in missing:
            print(f"ERROR: file mancante: {p}", file=sys.stderr)
        return 2

    patched = bump_presets(presets_path, new_version)
    godot_changed = bump_project_godot(godot_path, new_version)
    constants_changed = bump_constants(constants_path, new_version)

    print(f"Synced to version {new_version}:")
    for p in patched:
        print(f"  - export_presets.cfg: {p}")
    if godot_changed:
        print("  - project.godot: config/version")
    if constants_changed:
        print("  - constants.gd: APP_VERSION")

    if not (patched or godot_changed or constants_changed):
        print("  (nothing changed — already at target version)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
