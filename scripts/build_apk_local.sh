#!/usr/bin/env bash
# build_apk_local.sh — export locale dell'APK Android (debug) con Godot 4.7.1.
#
# L'APK e` firmato con il keystore di DEBUG: serve per provare il gioco sul
# proprio telefono, non e` distribuibile (nessuna firma di release nel
# progetto, audit G-003). E` lo stesso comando che esegue build.yml.
#
# Prerequisiti (una volta sola, nelle Editor Settings di Godot 4.7.1 o nel
# file editor_settings-4.7.tres):
#   export/android/android_sdk_path  -> Android SDK con platform-tools e
#                                       build-tools 34 (es. ~/android-sdk)
#   export/android/java_sdk_path     -> JDK 17 (es. ~/jdk-17)
#   export/android/debug_keystore    -> ~/.android/debug.keystore
#   template di export 4.7.1.stable installati (Editor > Manage Export Templates)
#
# Usage:
#   GODOT_BIN=/percorso/godot ./scripts/build_apk_local.sh [output.apk]
#   (default output: v1/export/android/RelaxRoom.apk, cartella ignorata da git)
# Exit: 0 OK, 1 export fallito, 2 ambiente non pronto.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

OUT="${1:-export/android/RelaxRoom.apk}"   # relativo a v1/

GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
    if command -v godot4 >/dev/null 2>&1; then GODOT=godot4
    elif command -v godot >/dev/null 2>&1; then GODOT=godot
    else
        echo "ERROR: godot4/godot non in PATH (usa GODOT_BIN=/percorso/godot)" >&2
        exit 2
    fi
fi

echo "=== Build APK (debug) — Relax Room ==="
echo "Godot:  $GODOT"
echo "Output: v1/$OUT"
echo ""

echo "[1/3] Import risorse (due passate: la seconda risolve le dipendenze tra scene)"
"$GODOT" --headless --import --path v1 >/dev/null 2>&1 || true
"$GODOT" --headless --import --path v1 >/dev/null 2>&1 || true

echo "[2/3] Export Android (debug)"
mkdir -p "v1/$(dirname "$OUT")"
LOG="${TMPDIR:-/tmp}/export_apk.log"
"$GODOT" --headless --path v1 --export-debug "Android" "$OUT" >"$LOG" 2>&1
RC=$?
if [ "$RC" -ne 0 ] || [ ! -f "v1/$OUT" ]; then
    echo "ERROR: export fallito (exit $RC). Ultime righe del log:" >&2
    grep -vE "ObjectDB|still in use|object.cpp|resource.cpp" "$LOG" | tail -15 >&2
    exit 1
fi

echo "[3/3] Verifica"
SIZE=$(stat -c%s "v1/$OUT" 2>/dev/null || stat -f%z "v1/$OUT")
echo "  dimensione: $((SIZE / 1048576)) MB"
if [ "$SIZE" -lt 20000000 ]; then
    echo "  WARN: APK sospettosamente piccolo" >&2
fi
echo "  sha256:     $(sha256sum "v1/$OUT" | awk '{print $1}')"
APKSIGNER_JAR="$(ls -d "$HOME"/android-sdk/build-tools/*/lib/apksigner.jar 2>/dev/null | tail -1)"
if [ -n "$APKSIGNER_JAR" ] && command -v java >/dev/null 2>&1; then
    java -jar "$APKSIGNER_JAR" verify --print-certs "v1/$OUT" 2>/dev/null | grep -E "DN:" | head -1 | sed 's/^/  firma:      /'
else
    echo "  (apksigner non trovato: verifica firma saltata)"
fi
echo ""
echo "APK pronto: v1/$OUT"
echo "Installazione: adb install -r v1/$OUT"
exit 0
