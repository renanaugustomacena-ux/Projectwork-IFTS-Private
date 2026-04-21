#!/usr/bin/env python3
"""Fail CI se un file keystore e` tracciato in git.

Belt-and-suspenders oltre a .gitignore: se un keystore finisce comunque
in git (es. git add -f esplicito, gitignore rotto, fresh clone pattern
ignorato), questo validator blocca il merge.

Rationale: un keystore release leakato via git = keystore compromesso
= rotazione obbligata + invalidazione updates utenti esistenti. Meglio
prevenire.

Scansiona:
  - Estensioni: .keystore, .jks, .p12, .pfx
  - Nomi sospetti: keystore-credentials, android-release-*, *debug.keystore*
  - Se export_credentials.cfg e` tracciato (deve stare in .gitignore)

Exit:
  0 — nessun file problematico
  1 — almeno un file problematico
  2 — errore runtime
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

FORBIDDEN_EXTENSIONS = {".keystore", ".jks", ".p12", ".pfx"}
FORBIDDEN_NAMES = {
    "keystore-credentials.properties",
    "keystore-credentials.env",
    "export_credentials.cfg",
    "release-keys.properties",
    "android-release-key.json",
}


def _run(cmd: list[str]) -> tuple[int, str]:
    try:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr
    except FileNotFoundError:
        return 2, f"Command not found: {cmd[0]}"


def list_tracked_files() -> list[str]:
    code, out = _run(["git", "ls-files"])
    if code != 0:
        print(f"ERROR: git ls-files failed: {out}", file=sys.stderr)
        sys.exit(2)
    return [line.strip() for line in out.splitlines() if line.strip()]


def find_offenders(files: list[str]) -> list[tuple[str, str]]:
    """Ritorna lista di (file, motivo) per ogni violazione."""
    offenders: list[tuple[str, str]] = []
    for f in files:
        p = Path(f)
        if p.suffix.lower() in FORBIDDEN_EXTENSIONS:
            offenders.append((f, f"forbidden extension {p.suffix}"))
            continue
        if p.name in FORBIDDEN_NAMES:
            offenders.append((f, f"forbidden name {p.name}"))
            continue
    return offenders


def main() -> int:
    files = list_tracked_files()
    offenders = find_offenders(files)
    if not offenders:
        print(f"PASS: no keystore/credential files tracked (scanned {len(files)} files)")
        return 0

    print("FAIL: keystore/credential files tracked in git:")
    for path, reason in offenders:
        print(f"  - {path} ({reason})")
    print()
    print("Remediation:")
    print("  1. git rm --cached <file>")
    print("  2. Verify .gitignore contains pattern for this file type")
    print("  3. Commit the removal")
    print("  4. If keystore file: TREAT AS COMPROMISED — rotate via")
    print("     scripts/generate_keystores.sh + update GitHub Secrets.")
    print("     See docs/ANDROID_SIGNING.md §9 (incident response).")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
