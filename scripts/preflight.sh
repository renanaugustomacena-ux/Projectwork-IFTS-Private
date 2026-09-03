#!/usr/bin/env bash
# preflight.sh — controllo GO/NO-GO prima di una demo o di un tag.
#
# Ripete in locale gli stessi gate della CI (ci.yml), nello stesso ordine:
# validator Python, lint GDScript, boot headless, suite integrazione.
# Non duplica la logica dei validator: li chiama.
#
# Usage: ./scripts/preflight.sh [--quick]
#   --quick   salta la suite integrazione (~1-2 min)
# Env:
#   GODOT_BIN  percorso del binario Godot 4.7.1 (default: godot4, poi godot).
#              Su Windows (Git Bash) tipicamente:
#              GODOT_BIN="$HOME/Downloads/Godot_v4.7.1-stable_win64_console.exe"
# Exit: 0 GO, 1 NO-GO, 2 ambiente non pronto.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

QUICK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --quick) QUICK=1; shift ;;
        *) echo "unknown flag $1" >&2; exit 2 ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
FAIL=0
WARN=0
TMP="${TMPDIR:-/tmp}"

PY="$(command -v python || command -v python3 || true)"
if [ -z "$PY" ]; then
    echo "ERROR: python non trovato in PATH" >&2
    exit 2
fi
# I percorsi possono contenere spazi (es. C:/Users/Nome Cognome/...): i
# comandi Python passano da questa funzione, mai da $PY non quotato in eval.
py() { "$PY" "$@"; }

GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
    if command -v godot4 >/dev/null 2>&1; then GODOT=godot4
    elif command -v godot >/dev/null 2>&1; then GODOT=godot
    else
        echo "ERROR: godot4/godot non in PATH (usa GODOT_BIN=/percorso/godot)" >&2
        exit 2
    fi
fi

check() {
    local name="$1"
    local cmd="$2"
    printf "  %-52s " "$name"
    eval "$cmd" >"$TMP/preflight_last.log" 2>&1
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        printf "${GREEN}OK${NC}\n"
    else
        printf "${RED}FAIL (exit $rc)${NC}\n"
        grep -vE "DeprecationWarning|getdata" "$TMP/preflight_last.log" | tail -4 | sed 's/^/      /'
        FAIL=$((FAIL+1))
    fi
}

warn_check() {
    local name="$1"
    local cmd="$2"
    printf "  %-52s " "$name"
    if eval "$cmd" >"$TMP/preflight_last.log" 2>&1; then
        printf "${GREEN}OK${NC}\n"
    else
        printf "${YELLOW}WARN${NC}\n"
        WARN=$((WARN+1))
    fi
}

echo "=== Relax Room — Pre-flight ==="
echo "Project: $PROJECT_ROOT"
echo "Godot:   $GODOT"
echo "Python:  $PY"
echo ""

echo "[1] Repository"
warn_check "working tree pulito" "test -z \"\$(git status --porcelain)\""
warn_check "remote origin raggiungibile" "timeout 8 git ls-remote origin HEAD >/dev/null"
echo ""

echo "[2] Validator (gli stessi di ci.yml)"
check "cataloghi JSON"            "py ci/validate_json_catalogs.py v1/data"
check "percorsi sprite/audio"     "py ci/validate_sprite_paths.py v1"
check "costanti vs cataloghi"     "py ci/validate_cross_references.py v1/scripts/utils/constants.gd v1/data"
check "schema SQLite"             "py ci/validate_db_schema.py v1/scripts/autoload/database/schema.gd"
check "Button.new() focus_mode"   "py ci/validate_button_focus.py v1/scripts"
check "versione sincronizzata"    "py ci/validate_version_sync.py"
check "nessun keystore tracciato" "py ci/validate_no_keystore.py"
check "conteggio segnali"         "py ci/validate_signal_count.py v1/scripts/autoload/signal_bus.gd --min 45"
check "conteggi nei README"       "py ci/validate_doc_counts.py ."
check "checksum binari godot-sqlite" "(cd v1/addons/godot-sqlite/bin && sha256sum -c ../SHA256SUMS)"
warn_check "palette pixel art aggiornata" "py ci/extract_palette.py --check"
warn_check "consegne pixel art"   "py ci/validate_pixelart_deliverables.py --check-palette"
warn_check "fogli male_rose derivati"  "py ci/recolor_character.py --check"
echo ""

echo "[3] Lint GDScript"
if command -v gdlint >/dev/null 2>&1; then
    check "gdlint v1/scripts v1/tests"   "gdlint v1/scripts/ v1/tests/"
    check "gdformat --check"             "gdformat --check v1/scripts/ v1/tests/"
else
    printf "  %-52s ${YELLOW}WARN${NC} (gdtoolkit non installato: pip install -r ci/requirements.txt)\n" "gdlint/gdformat"
    WARN=$((WARN+1))
fi
echo ""

echo "[4] Boot headless"
rm -f "$TMP/preflight_headless.log"
timeout 60 "$GODOT" --headless --path v1/ --quit >"$TMP/preflight_headless.log" 2>&1
HEADLESS_RC=$?
PARSE=$(grep -c "Parse Error" "$TMP/preflight_headless.log" || true)
SCRIPT=$(grep -c "SCRIPT ERROR" "$TMP/preflight_headless.log" || true)
if [ "$HEADLESS_RC" -eq 0 ] && [ "${PARSE:-0}" -eq 0 ] && [ "${SCRIPT:-0}" -eq 0 ]; then
    printf "  %-52s ${GREEN}OK${NC}\n" "boot headless (0 parse, 0 script error)"
else
    printf "  %-52s ${RED}FAIL (exit $HEADLESS_RC, parse=$PARSE script=$SCRIPT)${NC}\n" "boot headless"
    grep -E "SCRIPT ERROR|Parse Error" "$TMP/preflight_headless.log" | head -5 | sed 's/^/      /'
    FAIL=$((FAIL+1))
fi
echo ""

if [ "$QUICK" -eq 0 ]; then
    echo "[5] Suite integrazione (deep_test.sh, ~1-2 min)"
    rm -f "$TMP/preflight_deep.log"
    GODOT_BIN="$GODOT" bash scripts/deep_test.sh --timeout 300 >"$TMP/preflight_deep.log" 2>&1
    DEEP_RC=$?
    TOTALS=$(grep -E "^  Totals: " "$TMP/preflight_deep.log" | tail -1 | sed 's/^ *//')
    if [ "$DEEP_RC" -eq 0 ]; then
        printf "  %-52s ${GREEN}OK${NC} (%s)\n" "deep_test.sh" "${TOTALS:-?}"
    else
        printf "  %-52s ${RED}FAIL (exit $DEEP_RC, %s)${NC}\n" "deep_test.sh" "${TOTALS:-nessun totale}"
        grep -E "❌|FAILURES:" "$TMP/preflight_deep.log" | head -8 | sed 's/^/      /'
        FAIL=$((FAIL+1))
    fi
    echo ""
else
    echo "[5] Suite integrazione: saltata (--quick)"
    echo ""
fi

echo "==============================="
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}GO${NC}  (failures=0, warnings=$WARN)\n"
    exit 0
fi
printf "${RED}NO-GO${NC}  (failures=$FAIL, warnings=$WARN)\n"
exit 1
