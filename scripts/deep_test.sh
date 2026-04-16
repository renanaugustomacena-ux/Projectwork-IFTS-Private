#!/usr/bin/env bash
# deep_test.sh — invasive integration test harness.
# Runs the GDScript test runner in Godot headless and reports pass/fail.
#
# Usage: ./scripts/deep_test.sh [--timeout N]
# Exit: 0 all pass, 1 failures, 124 timeout, 2 harness error.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

TIMEOUT=120
while [ $# -gt 0 ]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        *) echo "unknown flag $1"; exit 2 ;;
    esac
done

if ! command -v godot4 >/dev/null; then
    echo "ERROR: godot4 not in PATH" >&2
    exit 2
fi

LOG=/tmp/deep_test_$$.log
rm -f "$LOG"

echo "=== Deep Test Suite ==="
echo "Project: $PROJECT_ROOT"
echo "Timeout: ${TIMEOUT}s"
echo ""

# --quit-after 0 disables auto-quit (we control it from test_runner).
# We run the scene directly instead of using --scene (simpler Godot 4 API).
timeout "$TIMEOUT" godot4 --headless \
    --path v1/ \
    res://tests/test_runner.tscn \
    > "$LOG" 2>&1
RC=$?

cat "$LOG"
echo ""

if [ $RC -eq 124 ]; then
    echo "❌ TIMEOUT after ${TIMEOUT}s"
    exit 124
fi

# The runner exits 0 (all pass) or 1 (failures). Godot's own exit code is what
# we propagate. Parse-level errors bubble up through the runner's push_error.
if [ $RC -eq 0 ]; then
    echo "✅ ALL DEEP TESTS PASSED"
    exit 0
else
    echo "❌ DEEP TESTS FAILED (exit $RC)"
    exit 1
fi
