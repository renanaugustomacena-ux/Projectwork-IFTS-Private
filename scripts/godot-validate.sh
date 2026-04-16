#!/usr/bin/env bash
# godot-validate.sh — runtime validation robusta per Relax Room.
#
# Ciclo completo:
#  1. Re-import asset (assicura .godot/imported/ popolata)
#  2. Headless boot 15s col main_menu
#  3. Grep log per pattern specifici (parse/script errors, autoload init)
#  4. Report pass/fail + log path
#
# Usage:
#   ./scripts/godot-validate.sh            # 15s default
#   ./scripts/godot-validate.sh 30         # 30s custom
#
# Exit codes:
#   0 = PASS (no parse/script errors, tutti autoload caricati)
#   1 = FAIL (parse o script error trovato)
#   2 = DEGRADED (boot OK ma autoload mancanti / warning critici)
#   3 = IMPORT FAIL (godot --import exit != 0)

set -u
TIMEOUT="${1:-15}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG="/tmp/godot_validate_$(date +%s).log"

echo -e "${BLUE}=== Godot Validate — Relax Room ===${NC}"
echo "Project: $PROJECT_ROOT"
echo "Log: $LOG"
echo ""

# Step 1: Re-import asset
echo -e "${BLUE}[1/3] Re-import asset (2-3 min se .godot/ e vuoto)...${NC}"
IMPORT_LOG="/tmp/godot_import_$$.log"
timeout 180 godot4 --headless --import --path v1/ >"$IMPORT_LOG" 2>&1
IMPORT_RC=$?
IMPORT_ERRORS=$(grep -c "ERROR" "$IMPORT_LOG" 2>/dev/null | head -1)
IMPORT_ERRORS=${IMPORT_ERRORS:-0}
if [ "$IMPORT_RC" -ne 0 ]; then
    echo -e "  ${RED}❌ Import fail (exit $IMPORT_RC, $IMPORT_ERRORS errori)${NC}"
    tail -10 "$IMPORT_LOG"
    exit 3
fi
echo -e "  ${GREEN}✅ Import OK${NC} ($IMPORT_ERRORS errori minor)"
echo ""

# Step 2: Boot main_menu per N secondi
echo -e "${BLUE}[2/3] Boot runtime ${TIMEOUT}s...${NC}"
timeout "$TIMEOUT" godot4 --path v1/ --audio-driver Dummy >"$LOG" 2>&1
RUN_RC=$?
echo "  Godot exit: $RUN_RC (124=timeout atteso)"
echo ""

# Step 3: Grep pattern
echo -e "${BLUE}[3/3] Analisi log...${NC}"

PARSE_ERR=$(grep -cE "Parse Error:" "$LOG" 2>/dev/null | head -1)
PARSE_ERR=${PARSE_ERR:-0}
SCRIPT_ERR=$(grep -cE "SCRIPT ERROR" "$LOG" 2>/dev/null | head -1)
SCRIPT_ERR=${SCRIPT_ERR:-0}
AUTOLOAD_FAIL=$(grep -cE "Failed to instantiate an autoload" "$LOG" 2>/dev/null | head -1)
AUTOLOAD_FAIL=${AUTOLOAD_FAIL:-0}
WARNINGS=$(grep -cE "^WARNING:" "$LOG" 2>/dev/null | head -1)
WARNINGS=${WARNINGS:-0}

# Expected autoload init sequence
EXPECTED_AUTOLOADS=("Logger: Session started" "LocalDatabase: Database initialized" "GameManager: Catalogs loaded" "PerformanceManager: Initialized")
MISSING_AUTOLOADS=()
for expected in "${EXPECTED_AUTOLOADS[@]}"; do
    if ! grep -q "$expected" "$LOG"; then
        MISSING_AUTOLOADS+=("$expected")
    fi
done

echo "  Parse errors:    $PARSE_ERR"
echo "  Script errors:   $SCRIPT_ERR"
echo "  Autoload fails:  $AUTOLOAD_FAIL"
echo "  Warnings:        $WARNINGS"
echo "  Missing init:    ${#MISSING_AUTOLOADS[@]}/${#EXPECTED_AUTOLOADS[@]}"
if [ ${#MISSING_AUTOLOADS[@]} -gt 0 ]; then
    for m in "${MISSING_AUTOLOADS[@]}"; do
        echo -e "    ${YELLOW}- mancante: $m${NC}"
    done
fi
echo ""

# Verdict
if [ "$PARSE_ERR" -gt 0 ] || [ "$SCRIPT_ERR" -gt 0 ] || [ "$AUTOLOAD_FAIL" -gt 0 ]; then
    echo -e "${RED}===============================${NC}"
    echo -e "${RED}❌ FAIL${NC}"
    echo ""
    echo "Primi errori script:"
    grep -E "SCRIPT ERROR|Parse Error" "$LOG" | head -5
    echo ""
    echo "Log completo: $LOG"
    exit 1
fi

if [ ${#MISSING_AUTOLOADS[@]} -gt 0 ]; then
    echo -e "${YELLOW}===============================${NC}"
    echo -e "${YELLOW}⚠  DEGRADED${NC}: boot OK ma autoload mancanti"
    echo "Log completo: $LOG"
    exit 2
fi

echo -e "${GREEN}===============================${NC}"
echo -e "${GREEN}✅ PASS${NC}: boot pulito, tutti autoload init OK"
echo "Log completo: $LOG"
exit 0
