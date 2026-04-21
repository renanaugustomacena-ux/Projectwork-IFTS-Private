#!/usr/bin/env bash
# scripts/ci/verify_binary.sh path/to/relaxroom.exe|apk
#
# Local smoke test helper per Renan: dopo download artifact, verifica che
# il binario sia strutturalmente valido + (se tool disponibili) si avvii
# senza crash immediato. NON parte di CI (CI non puo` lanciare .exe GUI).
#
# Uso:
#   ./scripts/ci/verify_binary.sh ~/Downloads/RelaxRoom-v1.0.0-x64.exe
#   ./scripts/ci/verify_binary.sh ~/Downloads/RelaxRoom-v1.0.0.apk
#
# Exit:
#   0 - Smoke OK
#   1 - Errori trovati (SCRIPT ERROR / FATAL / firma invalida)
#   2 - Ambiente non compatibile o args errato
set -euo pipefail

_err() { printf '\033[1;31m[verify]\033[0m %s\n' "$*" >&2; }
_log() { printf '\033[1;36m[verify]\033[0m %s\n' "$*"; }


verify_exe() {
    local binary="$1"
    # MZ magic bytes check (PE executable signature)
    local magic
    magic=$(head -c 2 "$binary" | xxd -p)
    if [[ "$magic" != "4d5a" ]]; then
        _err "File non e valido PE executable (missing MZ magic)"
        return 1
    fi
    _log "PE magic bytes OK"

    if command -v wine &>/dev/null; then
        _log "wine disponibile, launching binary per 8 secondi..."
        local wlog="/tmp/verify_exe.$$.log"
        timeout 8 wine "$binary" 2>&1 | tee "$wlog" >/dev/null || true
        if grep -iE "SCRIPT ERROR|Parse Error|FATAL" "$wlog"; then
            _err "Errori trovati nel log wine:"
            grep -iE "SCRIPT ERROR|Parse Error|FATAL" "$wlog" | head -10
            rm -f "$wlog"
            return 1
        fi
        rm -f "$wlog"
        _log "Smoke wine OK (no SCRIPT ERROR / FATAL)"
    else
        _log "wine non installato; skip runtime smoke."
        _log "  Ubuntu: sudo apt install wine"
        _log "  macOS:  brew install wine-stable"
    fi
    return 0
}


verify_apk() {
    local binary="$1"
    if ! command -v unzip &>/dev/null; then
        _err "unzip non disponibile, skip struttura check"
        return 2
    fi
    if ! unzip -l "$binary" 2>/dev/null | grep -q "AndroidManifest.xml"; then
        _err "APK non contiene AndroidManifest.xml — file corrotto?"
        return 1
    fi
    _log "AndroidManifest.xml presente"

    if command -v apksigner &>/dev/null; then
        _log "apksigner verify..."
        if apksigner verify --verbose "$binary" >/dev/null 2>&1; then
            _log "Firma APK valida"
        else
            _err "Firma APK non valida"
            return 1
        fi
    else
        _log "apksigner non disponibile; skip firma check"
    fi

    if command -v adb &>/dev/null && adb devices | grep -q "device$"; then
        _log "device Android rilevato, tento install..."
        if adb install -r "$binary"; then
            _log "Install OK. Launch manuale:"
            _log "  adb shell am start -n com.ifts.relaxroom/.RelaxRoomActivity"
        else
            _err "adb install fallito"
            return 1
        fi
    else
        _log "Nessun device adb; skip install live."
        _log "Test manuale: adb install -r $binary"
    fi
    return 0
}


main() {
    local binary="${1:-}"
    if [[ -z "$binary" ]]; then
        _err "Usage: $0 path/to/binary (.exe or .apk)"
        exit 2
    fi
    if [[ ! -f "$binary" ]]; then
        _err "File non trovato: $binary"
        exit 2
    fi
    local size
    size=$(stat -c%s "$binary" 2>/dev/null || stat -f%z "$binary")
    _log "File: $binary ($size bytes)"

    case "$binary" in
        *.exe)
            verify_exe "$binary"
            ;;
        *.apk)
            verify_apk "$binary"
            ;;
        *)
            _err "Estensione non supportata: $binary"
            exit 2
            ;;
    esac
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        _log "Smoke verify PASS"
    fi
    exit "$rc"
}


main "$@"
