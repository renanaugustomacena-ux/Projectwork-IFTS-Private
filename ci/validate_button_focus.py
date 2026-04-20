#!/usr/bin/env python3
"""Validate every runtime-created Button has an explicit focus_mode.

Pattern enforced to prevent regression of B-001 / B-003:
  Godot 4.5+ Button.new() default focus_mode = FOCUS_ALL, che intercetta
  ui_left/right/up/down come navigation e blocca character_controller.
  Ogni nuovo Button runtime DEVE avere focus_mode esplicito (di solito
  FOCUS_NONE per bottoni click-only, oppure FOCUS_ALL intenzionale).

Heuristics:
- Finds every "Button.new()" occurrence in .gd files under v1/scripts/.
- For each, requires "focus_mode" assignment on the same variable within
  the next 10 lines of the same function block.
- Exit 0 on pass; prints offenders + exit 1 on fail.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

BUTTON_NEW_RE = re.compile(
    r"^\s*(?:var\s+)?(\w+)\s*(?::\s*\w+)?\s*:?=\s*Button\.new\(\)"
)
FOCUS_MODE_RE = re.compile(r"\.focus_mode\s*=")
LOOKAHEAD = 12  # lines


def scan(root: Path) -> list[tuple[Path, int, str]]:
    offenders: list[tuple[Path, int, str]] = []
    for gd in sorted(root.rglob("*.gd")):
        # Skip addons (third-party, out of scope)
        if "addons" in gd.parts:
            continue
        lines = gd.read_text(encoding="utf-8").splitlines()
        for idx, line in enumerate(lines):
            m = BUTTON_NEW_RE.match(line)
            if not m:
                continue
            varname = m.group(1)
            # Scan ahead for varname.focus_mode = ... within LOOKAHEAD lines
            found = False
            for ahead in lines[idx + 1 : idx + 1 + LOOKAHEAD]:
                if FOCUS_MODE_RE.search(ahead) and varname in ahead:
                    found = True
                    break
                # Also accept a set_focus_mode() call style
                if f"{varname}.set_focus_mode(" in ahead:
                    found = True
                    break
            if not found:
                offenders.append((gd, idx + 1, line.strip()))
    return offenders


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "v1/scripts")
    if not root.exists():
        print(f"ERROR: root not found: {root}", file=sys.stderr)
        return 2
    offenders = scan(root)
    if not offenders:
        print(f"PASS: all Button.new() have explicit focus_mode under {root}")
        return 0
    print(f"FAIL: {len(offenders)} Button.new() senza focus_mode adiacente:")
    for path, lineno, snippet in offenders:
        print(f"  {path}:{lineno}  {snippet}")
    print(
        "\nFix: aggiungi <var>.focus_mode = Control.FOCUS_NONE entro"
        " 12 righe dal Button.new() (FOCUS_ALL ok se intenzionale).",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
