#!/usr/bin/env bash
# scripts/generate_keystores.sh
# Genera debug + release keystore per Android signing.
# Per il flusso completo vedi .github/workflows/build.yml (job build-android)
# e CHANGELOG.md (sezione Security).
#
# IMPORTANTE:
# - Esegue UNA SOLA VOLTA per computer
# - Output va in $HOME/.relax-room-keys/ (FUORI dal repo)
# - Release keystore = chiave di firma degli APK produzione
#   - Perdere = impossibile aggiornare l'app (utenti devono
#     disinstallare + reinstallare)
#   - Backup in: password manager + cloud cifrato + chiavetta offline
#   - MAI committare in git (gitignore + CI guard)
#
# Dopo la generazione lo script stampa i comandi per caricare i secrets
# su GitHub. L'upload avviene via `gh secret set` oppure dashboard web.
set -euo pipefail

KS_DIR="${KS_DIR:-$HOME/.relax-room-keys}"

_log() { printf '\033[1;36m[keystore-gen]\033[0m %s\n' "$*"; }
_err() { printf '\033[1;31m[keystore-gen]\033[0m %s\n' "$*" >&2; }

if ! command -v keytool &>/dev/null; then
    _err "keytool non trovato. Installa OpenJDK:"
    _err "  Ubuntu/Debian: sudo apt install default-jdk"
    _err "  macOS:         brew install openjdk"
    _err "  Windows:       https://adoptium.net/"
    exit 1
fi

mkdir -p "$KS_DIR"
chmod 700 "$KS_DIR"
_log "Keystore dir: $KS_DIR (permessi 700)"

# ------------------------------------------------------------
# DEBUG KEYSTORE
# ------------------------------------------------------------
# Può stare in repo (password pubblica "android") ma preferiamo fuori
# per evitare abitudini sbagliate su file keystore.
if [[ -f "$KS_DIR/debug.keystore" ]]; then
    _log "Debug keystore gia` esistente, skip."
else
    _log "Genero debug keystore (password pubblica 'android')..."
    keytool -genkey -v \
        -keystore "$KS_DIR/debug.keystore" \
        -alias androiddebugkey \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass android \
        -keypass android \
        -dname "CN=Android Debug,O=Android,C=US"
    chmod 600 "$KS_DIR/debug.keystore"
    _log "Debug keystore: $KS_DIR/debug.keystore"
fi

# ------------------------------------------------------------
# RELEASE KEYSTORE (interattivo)
# ------------------------------------------------------------
if [[ -f "$KS_DIR/release.keystore" ]]; then
    _log "Release keystore gia` esistente in $KS_DIR/release.keystore"
    _log "Se vuoi rigenerarla: rm $KS_DIR/release.keystore poi ri-lancia."
    exit 0
fi

cat <<'EOF'

================================================================
=== RELEASE KEYSTORE — procedura interattiva                ===
================================================================

Userai questo keystore per firmare OGNI APK di produzione.

⚠  PERDERE = utenti devono disinstallare + reinstallare l'app
           per qualunque update futuro (signing mismatch).

Backup necessari (minimo 3 luoghi separati):
  1. Password manager (Bitwarden / 1Password / KeePass)
  2. Cloud storage cifrato (iCloud Encrypted / Proton Drive)
  3. Chiavetta USB offline

Password: usa sempre la STESSA per storePass e keyPass
(semplifica lo script CI; in Android signing non c'e` differenza
pratica fra i due).

================================================================

EOF

read -r -p "Alias chiave (es. 'relaxroom'): " ALIAS
if [[ -z "$ALIAS" ]]; then _err "Alias vuoto"; exit 1; fi

while true; do
    read -r -s -p "Store password (>= 8 char, MEMORIZZA): " STOREPASS; echo
    if [[ ${#STOREPASS} -lt 8 ]]; then
        _err "Password deve essere almeno 8 caratteri"
        continue
    fi
    read -r -s -p "Conferma store password: " STOREPASS2; echo
    if [[ "$STOREPASS" != "$STOREPASS2" ]]; then
        _err "Password non coincidono, riprova"
        continue
    fi
    break
done

read -r -p "CN (Common Name — es. 'Renan Augusto Macena'): " CN
read -r -p "O (Organization — es. 'IFTS'): " ORG
read -r -p "C (Country code 2 lettere — es. 'IT'): " COUNTRY

if [[ -z "$CN" || -z "$ORG" || -z "$COUNTRY" ]]; then
    _err "CN, O, C sono tutti obbligatori"
    exit 1
fi

_log "Genero release keystore..."
keytool -genkey -v \
    -keystore "$KS_DIR/release.keystore" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 \
    -validity 10000 \
    -storepass "$STOREPASS" \
    -keypass "$STOREPASS" \
    -dname "CN=$CN,O=$ORG,C=$COUNTRY"

chmod 600 "$KS_DIR/release.keystore"
_log "Release keystore: $KS_DIR/release.keystore"
_log "Fingerprint:"
keytool -list -v \
    -keystore "$KS_DIR/release.keystore" \
    -alias "$ALIAS" \
    -storepass "$STOREPASS" | grep -E "SHA1:|SHA256:"

# ------------------------------------------------------------
# GitHub Secrets guidance
# ------------------------------------------------------------
cat <<EOF


================================================================
=== NEXT STEPS — GitHub Secrets upload                       ===
================================================================

I secrets vivono nella repo GitHub (anche se pubblica, i secrets
restano privati per definizione). Serve 'gh auth login' prima.

Comandi (esegui manualmente, uno alla volta):

  base64 -w0 $KS_DIR/release.keystore | gh secret set ANDROID_RELEASE_KEYSTORE_B64
  printf '%s' '$STOREPASS' | gh secret set ANDROID_RELEASE_KEYSTORE_PASS
  printf '%s' '$ALIAS' | gh secret set ANDROID_RELEASE_KEY_ALIAS
  printf '%s' '$STOREPASS' | gh secret set ANDROID_RELEASE_KEY_PASS

Oppure via web:
  Settings -> Secrets and variables -> Actions -> New repository secret
  per ciascuno dei 4 secret nel formato sopra.

Verifica dopo upload:
  gh secret list

Output atteso: 4 entries (timestamp recenti).

================================================================

⚠  QUESTO TERMINALE contiene la password in memoria.
   Dopo upload, chiudilo oppure 'clear' la history:
     history -c && clear

================================================================
EOF

_log "Generazione completa."
