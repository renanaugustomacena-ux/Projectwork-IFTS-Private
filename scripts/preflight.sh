#!/usr/bin/env bash
# preflight.sh — Validazione completa pre-demo. Lancia N controlli e output GO/NO-GO.
# Usage: ./scripts/preflight.sh
# Exit: 0 GO, 1 NO-GO.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAIL=0
WARN=0

check() {
    local name="$1"
    local cmd="$2"
    local expect="${3:-0}"

    printf "  %-50s " "$name"
    eval "$cmd" >/tmp/preflight_last.log 2>&1
    local rc=$?
    if [ "$rc" -eq "$expect" ]; then
        printf "${GREEN}✅${NC}\n"
        return 0
    else
        printf "${RED}❌ (exit $rc)${NC}\n"
        head -4 /tmp/preflight_last.log 2>/dev/null | sed 's/^/      /'
        FAIL=$((FAIL+1))
        return 1
    fi
}

warn_check() {
    local name="$1"
    local cmd="$2"
    printf "  %-50s " "$name"
    eval "$cmd" >/tmp/preflight_last.log 2>&1
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        printf "${GREEN}✅${NC}\n"
    else
        printf "${YELLOW}⚠${NC}\n"
        WARN=$((WARN+1))
    fi
}

echo "=== Relax Room — Pre-flight Demo Check ==="
echo "Project: $PROJECT_ROOT"
echo "Data: $(date)"
echo ""

echo "[1] Toolchain"
check "Godot 4.x in PATH" "command -v godot4 >/dev/null"
check "Git clean working tree" "test -z \"\$(git status --porcelain 2>/dev/null)\""
check "git remote origin reachable" "timeout 5 git ls-remote origin HEAD >/dev/null"
echo ""

echo "[2] File integrity"
check "project.godot esiste" "test -f v1/project.godot"
check "signal_bus.gd esiste" "test -f v1/scripts/autoload/signal_bus.gd"
check "save_manager.gd esiste" "test -f v1/scripts/autoload/save_manager.gd"
check "decorations.json esiste" "test -f v1/data/decorations.json"
check "characters.json esiste" "test -f v1/data/characters.json"
check "room_base.gd esiste" "test -f v1/scripts/rooms/room_base.gd"
check "cat_void.tscn esiste" "test -f v1/scenes/cat_void.tscn"
check "male-old-character.tscn esiste" "test -f v1/scenes/male-old-character.tscn"
echo ""

echo "[3] JSON catalog validity"
check "decorations.json JSON valid" "python3 -c 'import json; json.load(open(\"v1/data/decorations.json\"))'"
check "characters.json JSON valid" "python3 -c 'import json; json.load(open(\"v1/data/characters.json\"))'"
check "rooms.json JSON valid" "python3 -c 'import json; json.load(open(\"v1/data/rooms.json\"))'"
check "tracks.json JSON valid" "python3 -c 'import json; json.load(open(\"v1/data/tracks.json\"))'"
check "mess_catalog.json JSON valid" "python3 -c 'import json; json.load(open(\"v1/data/mess_catalog.json\"))'"
echo ""

echo "[4] Asset references (sprite_path integrity)"
check "All decorations sprite_path exist" "python3 -c '
import json, os
d = json.load(open(\"v1/data/decorations.json\"))
missing = [item[\"sprite_path\"] for item in d[\"decorations\"] if not os.path.exists(item[\"sprite_path\"].replace(\"res://\", \"v1/\"))]
import sys
sys.exit(0 if not missing else 1)
'"
echo ""

echo "[5] Godot headless boot"
rm -f /tmp/preflight_headless.log
timeout 10 godot4 --headless --path v1/ --quit >/tmp/preflight_headless.log 2>&1
HEADLESS_RC=$?
if [ $HEADLESS_RC -eq 0 ]; then
    PARSE=$(grep -c "Parse Error" /tmp/preflight_headless.log | head -1)
    SCRIPT=$(grep -c "SCRIPT ERROR" /tmp/preflight_headless.log | head -1)
    PARSE=${PARSE:-0}
    SCRIPT=${SCRIPT:-0}
    if [ "$PARSE" -eq 0 ] && [ "$SCRIPT" -eq 0 ]; then
        printf "  %-50s ${GREEN}✅${NC}\n" "Headless boot (exit 0, 0 parse, 0 script)"
    else
        printf "  %-50s ${RED}❌ (parse=$PARSE script=$SCRIPT)${NC}\n" "Headless boot"
        FAIL=$((FAIL+1))
    fi
else
    printf "  %-50s ${RED}❌ (exit $HEADLESS_RC)${NC}\n" "Headless boot"
    head -5 /tmp/preflight_headless.log | sed 's/^/      /'
    FAIL=$((FAIL+1))
fi
echo ""

echo "[6] Runtime extended (main_menu 6s)"
rm -f /tmp/preflight_runtime.log
timeout 6 godot4 --path v1/ --audio-driver Dummy >/tmp/preflight_runtime.log 2>&1
RUN_RC=$?
# Expected: 124 (timeout) because we didn't pass --quit
RUN_PARSE=$(grep -c "Parse Error" /tmp/preflight_runtime.log | head -1)
RUN_SCRIPT=$(grep -c "SCRIPT ERROR" /tmp/preflight_runtime.log | head -1)
RUN_PARSE=${RUN_PARSE:-0}
RUN_SCRIPT=${RUN_SCRIPT:-0}
if [ "$RUN_PARSE" -eq 0 ] && [ "$RUN_SCRIPT" -eq 0 ]; then
    printf "  %-50s ${GREEN}✅${NC}\n" "Runtime 6s (0 parse, 0 script)"
else
    printf "  %-50s ${RED}❌ (parse=$RUN_PARSE script=$RUN_SCRIPT)${NC}\n" "Runtime 6s"
    grep -E "(SCRIPT|Parse)" /tmp/preflight_runtime.log | head -3 | sed 's/^/      /'
    FAIL=$((FAIL+1))
fi
echo ""

echo "[7] Deep integration tests (~7s)"
rm -f /tmp/preflight_deep.log
timeout 90 godot4 --headless --path v1/ res://tests/test_runner.tscn \
    >/tmp/preflight_deep.log 2>&1
DEEP_RC=$?
DEEP_FAILS=$(grep -E "^  Totals: " /tmp/preflight_deep.log | sed -E 's/.* ([0-9]+) fail.*/\1/')
DEEP_PASS=$(grep -E "^  Totals: " /tmp/preflight_deep.log | sed -E 's/.* ([0-9]+) pass.*/\1/')
DEEP_FAILS=${DEEP_FAILS:-999}
DEEP_PASS=${DEEP_PASS:-0}
if [ "$DEEP_RC" -eq 0 ] && [ "$DEEP_FAILS" -eq 0 ]; then
    printf "  %-50s ${GREEN}✅${NC} ($DEEP_PASS tests pass)\n" "Deep test suite"
else
    printf "  %-50s ${RED}❌ (exit $DEEP_RC, $DEEP_FAILS fail)${NC}\n" "Deep test suite"
    grep -E "^\s+✗|FAILURES:" /tmp/preflight_deep.log | head -8 | sed 's/^/      /'
    FAIL=$((FAIL+1))
fi
echo ""

echo "[8] Presentation artifacts"
check "pptx presentazione presente" "test -f Mini-Cozy-Room-Presentazione-Progetto.pptx"
check "speech_renan presente" "test -f v1/docs/speech_renan.md"
check "speech_elia presente" "test -f v1/docs/speech_elia.md"
check "speech_cristian presente" "test -f v1/docs/speech_cristian.md"
check "speech_esteso presente" "test -f v1/docs/speech_esteso.md"
echo ""

echo "==============================="
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}GO PER DEMO${NC}  (failures=0, warnings=$WARN)\n"
    echo ""
    echo "Prossimi step consigliati:"
    echo "  1. godot4 --path v1/  — test manuale GUI per validazione finale"
    echo "  2. Rileggi FIX_SUMMARY_2026-04-16.md"
    echo "  3. Apri Mini-Cozy-Room-Presentazione-Progetto.pptx per verifica slide"
    exit 0
else
    printf "${RED}NO-GO${NC}  (failures=$FAIL, warnings=$WARN)\n"
    echo ""
    echo "Controlla gli ❌ sopra e risolvi prima della demo."
    exit 1
fi
