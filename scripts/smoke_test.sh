#!/usr/bin/env bash
# smoke_test.sh — validazione runtime Relax Room via headless Godot
# Usage: ./scripts/smoke_test.sh [timeout_seconds]
# Exit 0 = pass (nessun error/parse), 1 = fail con errore critico, 2 = timeout

set -u
TIMEOUT="${1:-12}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/smoke_test_$(date +%s).log"

cd "$PROJECT_ROOT" || exit 1

echo "=== Smoke Test — Relax Room ==="
echo "Project: $PROJECT_ROOT"
echo "Timeout: ${TIMEOUT}s"
echo "Log: $LOG"
echo ""

timeout "$TIMEOUT" godot4 --headless --path v1/ --quit >"$LOG" 2>&1
EXIT=$?

echo "Godot exit code: $EXIT"
echo ""

PARSE_ERRORS=$(grep -c "SCRIPT ERROR: Parse Error" "$LOG" 2>/dev/null | head -1 || echo 0)
SCRIPT_ERRORS=$(grep -c "SCRIPT ERROR:" "$LOG" 2>/dev/null | head -1 || echo 0)
RES_ERRORS=$(grep -cE "^ERROR: " "$LOG" 2>/dev/null | head -1 || echo 0)
WARNINGS=$(grep -c "WARNING:" "$LOG" 2>/dev/null | head -1 || echo 0)
PARSE_ERRORS=${PARSE_ERRORS:-0}
SCRIPT_ERRORS=${SCRIPT_ERRORS:-0}
RES_ERRORS=${RES_ERRORS:-0}
WARNINGS=${WARNINGS:-0}

echo "Parse errors: $PARSE_ERRORS"
echo "Script errors: $SCRIPT_ERRORS"
echo "Resource/misc errors: $RES_ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ "$PARSE_ERRORS" -gt 0 ]; then
  echo "❌ FAIL: parse errors"
  grep -A 3 "SCRIPT ERROR: Parse Error" "$LOG"
  exit 1
fi

if [ "$SCRIPT_ERRORS" -gt 0 ]; then
  echo "❌ FAIL: script errors"
  grep -A 3 "SCRIPT ERROR:" "$LOG"
  exit 1
fi

if [ "$EXIT" -eq 124 ]; then
  echo "⏱  TIMEOUT: il gioco non ha chiuso in ${TIMEOUT}s (normale se lanciato senza --quit)"
  exit 2
fi

echo "✅ PASS: headless boot OK"
echo ""
echo "Log tail:"
tail -20 "$LOG"
exit 0
