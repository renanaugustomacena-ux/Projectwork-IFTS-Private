#!/usr/bin/env python3
"""Estrae la sezione della versione richiesta da CHANGELOG.md.

Usage: extract_changelog.py v1.0.0
       extract_changelog.py 1.0.0  (with/without v prefix)

Output su stdout: markdown della sezione, pronto per GitHub Release body.

Fase E del piano BUILD_RELEASE_PLAN §6.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def extract(changelog: str, version: str) -> str:
    """Ritorna markdown della sezione [version] da changelog.

    Match robusto: accetta con o senza 'v' prefix nel tag. Cerca
    '## [X.Y.Z]' fino al prossimo '## [' (strip incluso).
    """
    v = version.lstrip("v")
    # Accept both [1.0.0] and [1.0.0-rc1] format
    pattern = rf"^##\s*\[{re.escape(v)}\][^\n]*\n(.*?)(?=^##\s*\[|\Z)"
    match = re.search(pattern, changelog, re.MULTILINE | re.DOTALL)
    if not match:
        return (
            f"## Relax Room {version}\n\n"
            f"Release notes for {version} non presenti in CHANGELOG.md.\n\n"
            "Scarica gli asset qui sotto."
        )
    body = match.group(1).strip()
    return (
        f"## Relax Room {version}\n\n"
        f"{body}\n\n"
        "---\n\n"
        "### Download & verify\n\n"
        "Scarica l'asset per la tua piattaforma. Verifica integrita con:\n\n"
        "```bash\n"
        "sha256sum -c SHA256SUMS.txt\n"
        "```\n\n"
        "**Piattaforme**:\n"
        "- **Windows**: `RelaxRoom-*-x64.exe` — standalone, nessuna install\n"
        "- **Android**: `RelaxRoom-*.apk` — API 24+ (Android 7.0), sideload\n"
        "- **Web**: `RelaxRoom-*-html5.zip` — estrai + apri `index.html` in\n"
        "  browser moderno (Chrome/Firefox/Safari recenti)\n"
    )


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract_changelog.py vX.Y.Z", file=sys.stderr)
        return 2
    version = sys.argv[1]
    repo = Path(__file__).resolve().parent.parent.parent
    changelog_path = repo / "CHANGELOG.md"
    if not changelog_path.exists():
        print(f"ERROR: CHANGELOG.md non trovato in {repo}", file=sys.stderr)
        return 2
    changelog = changelog_path.read_text(encoding="utf-8")
    print(extract(changelog, version))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
