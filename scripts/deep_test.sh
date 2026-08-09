#!/usr/bin/env bash
# deep_test.sh — invasive integration test harness.
# Runs the GDScript test runner in Godot headless and reports pass/fail.
#
# ISOLAMENTO DEL PROFILO GIOCATORE (audit G-053)
# ----------------------------------------------
# La suite scrive save_data.json, cozy_room.db, integrity.key e
# test_results.jsonl dentro `user://`. Con `use_custom_user_dir=true` +
# `custom_user_dir_name="RelaxRoom"` quel percorso e` lo STESSO profilo che usa
# il gioco: ogni run mutava i dati reali del giocatore.
#
# Godot 4.7.1 NON espone alcun flag `--user-data-dir` (verificato su `--help`) e
# non onora feature-override su `config/custom_user_dir_name` (probato: un
# override `.headless` viene ignorato). L'unico punto di aggancio e` la
# variabile d'ambiente da cui Godot deriva il data path all'avvio:
#
#   Windows -> APPDATA          macOS -> HOME          Linux -> XDG_DATA_HOME
#
# Impostandola su una directory temporanea appena creata, `user://` trasloca in
# blocco: nessuna modifica al codice di gioco, nessun test indebolito, semantica
# di `user://` intatta (la redazione dei path nel Logger continua a funzionare).
#
# CONCORRENZA: la sandbox nasce da `mktemp -d`, quindi e` unica per run. Due
# suite lanciate insieme non si toccano.
#
# FAIL-SAFE: nella sandbox viene piantato un sentinella `.test_sandbox`.
# `test_runner.gd` si rifiuta di eseguire test se non lo vede, quindi un
# ambiente mal configurato ABORTISCE invece di scrivere nel profilo reale.
#
# Usage: ./scripts/deep_test.sh [--timeout N] [--keep]
#   --keep   non cancella la sandbox a fine run (per ispezionare gli artefatti)
# Env:   GODOT_BIN=/percorso/godot   (default: godot4, poi godot)
# Exit: 0 all pass, 1 failures, 124 timeout, 2 harness error.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

TIMEOUT=120
KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --keep) KEEP=1; shift ;;
        *) echo "unknown flag $1"; exit 2 ;;
    esac
done

GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
    if command -v godot4 >/dev/null 2>&1; then
        GODOT=godot4
    elif command -v godot >/dev/null 2>&1; then
        GODOT=godot
    else
        echo "ERROR: godot4/godot non in PATH (usa GODOT_BIN=/percorso/godot)" >&2
        exit 2
    fi
fi

# Nome della user dir letto dal progetto: se cambia, cambia anche qui.
USER_DIR_NAME="$(sed -n 's/^config\/custom_user_dir_name="\(.*\)"$/\1/p' v1/project.godot | head -1)"
if [ -z "$USER_DIR_NAME" ]; then
    echo "ERROR: config/custom_user_dir_name non trovato in v1/project.godot" >&2
    exit 2
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/relaxroom-test-XXXXXX")" || exit 2

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        ENV_VAR=APPDATA
        ENV_VAL="$(cygpath -w "$SANDBOX")"
        SANDBOX_USER="$SANDBOX/$USER_DIR_NAME"
        ;;
    Darwin)
        ENV_VAR=HOME
        ENV_VAL="$SANDBOX"
        SANDBOX_USER="$SANDBOX/Library/Application Support/$USER_DIR_NAME"
        ;;
    *)
        ENV_VAR=XDG_DATA_HOME
        ENV_VAL="$SANDBOX"
        SANDBOX_USER="$SANDBOX/$USER_DIR_NAME"
        ;;
esac

mkdir -p "$SANDBOX_USER" || exit 2
: > "$SANDBOX_USER/.test_sandbox"

LOG="$SANDBOX/deep_test.log"

echo "=== Deep Test Suite ==="
echo "Project: $PROJECT_ROOT"
echo "Godot:   $GODOT"
echo "Sandbox: $SANDBOX_USER  (via $ENV_VAR)"
echo "Timeout: ${TIMEOUT}s"
echo ""

# --quit-after 0 disabiliterebbe l'auto-quit: lo controlliamo dal test_runner.
# Lanciamo la scena direttamente invece di --scene (API Godot 4 piu` semplice).
env "$ENV_VAR=$ENV_VAL" timeout "$TIMEOUT" "$GODOT" --headless \
    --path v1/ \
    res://tests/test_runner.tscn \
    > "$LOG" 2>&1
RC=$?

cat "$LOG"
echo ""

cleanup_sandbox() {
    if [ "$KEEP" -eq 1 ]; then
        echo "Sandbox conservata: $SANDBOX"
    else
        rm -rf "$SANDBOX"
    fi
}

if [ $RC -eq 124 ]; then
    echo "❌ TIMEOUT after ${TIMEOUT}s"
    echo "Sandbox conservata per debug: $SANDBOX"
    exit 124
fi

# Prova d'isolamento: gli artefatti DEVONO essere atterrati nella sandbox. Se
# non ci sono, la redirezione non ha avuto effetto (o il runner ha abortito sul
# sentinella) e il risultato non e` affidabile: meglio un errore rumoroso che
# una suite che scrive nel profilo vero.
if [ ! -f "$SANDBOX_USER/test_results.jsonl" ]; then
    echo "❌ HARNESS ERROR: nessun test_results.jsonl in $SANDBOX_USER"
    echo "   L'isolamento di user:// non ha funzionato su questa piattaforma."
    echo "   Sandbox conservata per debug: $SANDBOX"
    exit 2
fi

# Il gate e` a livello-assertion, non exit code: a shutdown il runner perde RID
# (CanvasItem/TextServer) e Godot puo` uscire != 0 anche con tutti i test verdi.
if grep -q "✅ ALL PASS" "$LOG" && grep -qE "Totals: [0-9]+ pass, 0 fail" "$LOG"; then
    echo "✅ ALL DEEP TESTS PASSED"
    cleanup_sandbox
    exit 0
else
    echo "❌ DEEP TESTS FAILED (exit $RC)"
    echo "Sandbox conservata per debug: $SANDBOX"
    exit 1
fi
