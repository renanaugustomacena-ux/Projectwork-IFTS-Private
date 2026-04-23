#!/usr/bin/env bash
# build_apk_local.sh — Build Android APK debug locale usando SDK + templates
# gia` installati da session autopilot 2026-04-22.
#
# Prerequisiti (gia` OK dopo session):
#   - godot4 4.6.stable in PATH
#   - ~/.local/share/godot/export_templates/4.6.stable/ popolata
#   - ~/android-sdk/platforms/android-34, ~/android-sdk/build-tools/34.0.0
#   - JDK 17 via /usr/bin/java
#
# Usage: ./scripts/build_apk_local.sh
# Exit: 0 OK, 1 generic fail, 2 missing prereq.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Build APK Local — Relax Room ===${NC}"

# --- Prereq checks ---
echo -e "${BLUE}[1/6] Prereq check${NC}"
fail=0
command -v godot4 >/dev/null || { echo -e "  ${RED}missing godot4${NC}"; fail=1; }
command -v keytool >/dev/null || { echo -e "  ${RED}missing keytool (JDK)${NC}"; fail=1; }
[ -d "$HOME/.local/share/godot/export_templates/4.6.stable" ] || {
  echo -e "  ${RED}missing export templates 4.6.stable${NC}"; fail=1;
}
[ -d "$HOME/android-sdk/platforms/android-34" ] || {
  echo -e "  ${RED}missing android-sdk platforms/android-34${NC}"; fail=1;
}
[ -d "$HOME/android-sdk/build-tools/34.0.0" ] || {
  echo -e "  ${RED}missing android-sdk build-tools/34.0.0${NC}"; fail=1;
}
[ "$fail" -eq 0 ] || exit 2
echo -e "  ${GREEN}all prereq ok${NC}"

# --- Debug keystore ---
echo -e "${BLUE}[2/6] Debug keystore${NC}"
mkdir -p "$HOME/.android"
KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -keyalg RSA -genkeypair -alias androiddebugkey \
    -keypass android \
    -keystore "$KEYSTORE" \
    -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 \
    -deststoretype pkcs12 >/dev/null 2>&1
  echo -e "  ${GREEN}keystore generated${NC}"
else
  echo -e "  ${GREEN}keystore exists${NC}"
fi

# --- editor_settings Android config ---
echo -e "${BLUE}[3/6] Godot editor_settings Android paths${NC}"
JAVA_BIN=$(readlink -f "$(which java)")
JAVA_DIR=$(dirname "$(dirname "$JAVA_BIN")")
SETTINGS="$HOME/.config/godot/editor_settings-4.6.tres"
mkdir -p "$(dirname "$SETTINGS")"

# Se il file non esiste, crea fresco. Se esiste, rimuovi vecchie chiavi android
# e riappendi quelle corrette. gdscript .tres accetta chiavi ripetute solo
# una volta; ultima vince.
if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
EOF
fi

# Rimuovi righe android esistenti (evita duplicati)
grep -v "^export/android/\(android_sdk_path\|java_sdk_path\|debug_keystore\)" \
  "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# Assicura [resource] header presente
grep -q "^\[resource\]" "$SETTINGS" || echo -e "\n[resource]" >> "$SETTINGS"

# Appendi chiavi Android correnti
cat >> "$SETTINGS" <<EOF
export/android/android_sdk_path = "$HOME/android-sdk"
export/android/java_sdk_path = "$JAVA_DIR"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
echo -e "  ${GREEN}editor_settings updated${NC}"
echo "    Java SDK: $JAVA_DIR"
echo "    Android SDK: $HOME/android-sdk"

# --- Pre-import asset (ETC2 textures) ---
echo -e "${BLUE}[4/6] Pre-import asset (ETC2 textures per Android)${NC}"
cd "$PROJECT_ROOT/v1"
# Due pass di sicurezza: primo import crea .godot/imported/, secondo risolve
# dipendenze circolari tra sprite/scene.
timeout 180 godot4 --headless --import --path . >/tmp/import1.log 2>&1 || true
timeout 180 godot4 --headless --import --path . >/tmp/import2.log 2>&1 || true
IMPORT_ERRORS=$(grep -c "^ERROR" /tmp/import2.log 2>/dev/null | head -1)
IMPORT_ERRORS=${IMPORT_ERRORS:-0}
echo -e "  pass 1+2 done ($IMPORT_ERRORS errors in pass 2)"

# --- Export APK debug ---
echo -e "${BLUE}[5/6] Export APK debug${NC}"
mkdir -p export/android
EXPORT_LOG=/tmp/export_apk.log
timeout 300 godot4 --headless --export-debug "Android" export/android/RelaxRoom.apk >"$EXPORT_LOG" 2>&1
RC=$?
echo "  export exit: $RC"
if [ "$RC" -ne 0 ]; then
  echo -e "  ${RED}export failed${NC}"
  tail -20 "$EXPORT_LOG"
  exit 1
fi

# --- Verify APK ---
echo -e "${BLUE}[6/6] Verify APK${NC}"
APK="export/android/RelaxRoom.apk"
if [ ! -f "$APK" ]; then
  echo -e "  ${RED}APK file not found at $APK${NC}"
  exit 1
fi
SIZE=$(stat -c%s "$APK")
SIZE_MB=$((SIZE / 1048576))
echo "  size: ${SIZE_MB} MB ($SIZE bytes)"
if [ "$SIZE" -lt 20000000 ]; then
  echo -e "  ${YELLOW}WARN: APK unexpectedly small${NC}"
fi
if [ "$SIZE" -gt 300000000 ]; then
  echo -e "  ${YELLOW}WARN: APK unexpectedly big${NC}"
fi

# SHA256
SHA=$(sha256sum "$APK" | awk '{print $1}')
echo "  sha256: $SHA"

# apksigner verify se disponibile
APKSIGNER="$HOME/android-sdk/build-tools/34.0.0/apksigner"
if [ -x "$APKSIGNER" ]; then
  "$APKSIGNER" verify --verbose "$APK" 2>&1 | head -5
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}APK BUILD OK${NC}"
echo -e "${GREEN}================================${NC}"
echo "File: $PROJECT_ROOT/v1/$APK"
echo "Install: adb install -r $PROJECT_ROOT/v1/$APK"
echo "Or copy to device + tap to install"
exit 0