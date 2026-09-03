#!/usr/bin/env python3
"""Confronta i numeri dichiarati nei README con quelli misurati sul repository.

Regola del repo: "nessun numero copiato dalla revisione precedente, ogni cifra
e` il risultato del comando accanto". Questo script rende la regola eseguibile.

Formato stabile nei README (README.md e v1/README.md): ogni conteggio e` scritto
in grassetto come ``**<numero> <etichetta>**``. Ogni occorrenza dell'etichetta
deve coincidere con il valore misurato; un'etichetta assente in un README non e`
un errore (il README puo` non parlarne), un valore diverso lo e`.

Etichette e misura equivalente da shell:
    segnali          grep -c '^signal ' v1/scripts/autoload/signal_bus.gd
    script           find v1/scripts -name '*.gd' | wc -l
    test             grep -h '^func test_' v1/tests/integration/*.gd | wc -l
    moduli           ls v1/tests/integration/test_*.gd | grep -v test_base | wc -l
    scene            find v1/scenes -name '*.tscn' | wc -l
    cataloghi        ls v1/data/*.json | wc -l
    tabelle          grep -c 'CREATE TABLE IF NOT EXISTS' v1/scripts/autoload/database/schema.gd
    autoload         grep -c '="\\*res://' v1/project.godot
    decorazioni      len(decorations.json["decorations"])
    tipi di sporco   len(mess_catalog.json["mess"])
    personaggi       len(characters.json["characters"])

Exit codes: 0 tutto coerente, 1 almeno una divergenza, 2 file mancante.

Usage: python ci/validate_doc_counts.py [repo_root]
"""
import json
import re
import sys
from pathlib import Path

READMES = ("README.md", "v1/README.md")


def measure(root: Path) -> dict[str, int]:
    v1 = root / "v1"
    signal_bus = (v1 / "scripts/autoload/signal_bus.gd").read_text(encoding="utf-8")
    schema = (v1 / "scripts/autoload/database/schema.gd").read_text(encoding="utf-8")
    project = (v1 / "project.godot").read_text(encoding="utf-8")
    tests = sorted(p for p in (v1 / "tests/integration").glob("test_*.gd") if p.name != "test_base.gd")
    load = lambda name: json.loads((v1 / "data" / name).read_text(encoding="utf-8"))
    return {
        "segnali": len(re.findall(r"^signal\s+\w+", signal_bus, re.MULTILINE)),
        "script": len(list((v1 / "scripts").rglob("*.gd"))),
        "test": sum(len(re.findall(r"^func test_", p.read_text(encoding="utf-8"), re.MULTILINE)) for p in tests),
        "moduli": len(tests),
        "scene": len(list((v1 / "scenes").rglob("*.tscn"))),
        "cataloghi": len(list((v1 / "data").glob("*.json"))),
        "tabelle": schema.count("CREATE TABLE IF NOT EXISTS"),
        "autoload": len(re.findall(r'="\*res://', project)),
        "decorazioni": len(load("decorations.json")["decorations"]),
        "tipi di sporco": len(load("mess_catalog.json")["mess"]),
        "personaggi": len(load("characters.json")["characters"]),
    }


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    try:
        measured = measure(root)
    except (FileNotFoundError, KeyError) as exc:
        print(f"ERROR: impossibile misurare il repository: {exc}", file=sys.stderr)
        return 2
    for label, value in measured.items():
        print(f"  measured {label:15s} = {value}")

    failures = 0
    for rel in READMES:
        path = root / rel
        if not path.is_file():
            print(f"ERROR: {rel} mancante", file=sys.stderr)
            return 2
        text = path.read_text(encoding="utf-8")
        for label, value in measured.items():
            for match in re.finditer(r"\*\*(\d+) " + re.escape(label) + r"\*\*", text):
                declared = int(match.group(1))
                if declared != value:
                    line = text.count("\n", 0, match.start()) + 1
                    print(f"FAIL: {rel}:{line} dichiara **{declared} {label}**, misurato {value}", file=sys.stderr)
                    failures += 1
    if failures:
        print(f"FAIL: {failures} numeri divergono dal repository", file=sys.stderr)
        return 1
    print("PASS: i numeri dichiarati nei README coincidono con quelli misurati")
    return 0


if __name__ == "__main__":
    sys.exit(main())
