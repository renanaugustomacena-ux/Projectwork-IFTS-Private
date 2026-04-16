#!/usr/bin/env python3
"""Validate SignalBus signal declarations and flag obvious mismatches.

Counts `signal <name>` declarations in v1/scripts/autoload/signal_bus.gd and
fails the build if the count drops below an expected floor (configured here)
or if the file becomes unparseable. Emits the actual count so docs can be
kept in sync.

Exit codes:
    0 — OK
    1 — count below floor or file missing
    2 — usage error

Usage:
    python ci/validate_signal_count.py v1/scripts/autoload/signal_bus.gd [--min N]
"""
import re
import sys
from pathlib import Path

SIGNAL_RE = re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.MULTILINE)
DEFAULT_MIN = 40  # Floor: guards against accidental deletions during refactors


def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <signal_bus.gd> [--min N]", file=sys.stderr)
        return 2

    signal_bus_path = Path(sys.argv[1])
    min_signals = DEFAULT_MIN
    if "--min" in sys.argv:
        idx = sys.argv.index("--min")
        if idx + 1 >= len(sys.argv):
            print("--min requires a value", file=sys.stderr)
            return 2
        try:
            min_signals = int(sys.argv[idx + 1])
        except ValueError:
            print(f"--min must be an integer, got {sys.argv[idx + 1]!r}", file=sys.stderr)
            return 2

    if not signal_bus_path.is_file():
        print(f"ERROR: signal_bus.gd not found at {signal_bus_path}", file=sys.stderr)
        return 1

    content = signal_bus_path.read_text(encoding="utf-8")
    signals = SIGNAL_RE.findall(content)
    count = len(signals)

    # Detect duplicates (same name declared twice — compile-time error in Godot but
    # caught earlier here for faster feedback)
    seen: dict[str, int] = {}
    duplicates: list[str] = []
    for name in signals:
        if name in seen:
            duplicates.append(name)
        seen[name] = seen.get(name, 0) + 1

    print(f"SignalBus signals declared: {count}")
    if count <= 30:
        print("Names:", ", ".join(signals))

    if duplicates:
        print(f"ERROR: duplicate signal declarations: {', '.join(duplicates)}", file=sys.stderr)
        return 1

    if count < min_signals:
        print(
            f"FAIL: signal count {count} below floor {min_signals} — "
            "accidental deletion suspected. Bump --min if intentional.",
            file=sys.stderr,
        )
        return 1

    print(f"PASS: {count} signals >= floor {min_signals}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
