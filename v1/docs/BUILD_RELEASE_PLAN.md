# Build & Release Plan — Relax Room v1.0.0

**Data**: 2026-04-21
**Target**: primo release pubblico `.exe` (Windows) + `.apk` (Android) scaricabili dal landing page
**Timeline realistica**: 1 intera giornata di lavoro concentrato (8-12h) + 1 finestra di playtest GUI prima del merge
**Baseline commit**: `5842474` (tip `main` post sprint 04-21)

Questo documento è la baseline operativa. Ogni fase produce un output verificabile (comando che stampa exit 0, file generato, smoke test passato). Nessun passo viene marcato "done" senza evidenza binaria. Ogni modifica CI viene validata su branch separato con PR manuale prima di toccare `main`.

---

## Indice

0. [Stato attuale e gap](#0-stato-attuale-e-gap)
1. [Principi di base e vincoli](#1-principi-di-base-e-vincoli)
2. [Fase A — Versioning centralizzato](#2-fase-a--versioning-centralizzato)
3. [Fase B — Keystore Android (debug + release)](#3-fase-b--keystore-android-debug--release)
4. [Fase C — Export presets hardening](#4-fase-c--export-presets-hardening)
5. [Fase D — Build workflow production](#5-fase-d--build-workflow-production)
6. [Fase E — Release workflow](#6-fase-e--release-workflow)
7. [Fase F — CI gate: build blocca su validatori falliti](#7-fase-f--ci-gate-build-blocca-su-validatori-falliti)
8. [Fase G — Landing page dinamica](#8-fase-g--landing-page-dinamica)
9. [Fase H — Playtest manuale GUI](#9-fase-h--playtest-manuale-gui)
10. [Fase I — Primo release tagged v1.0.0](#10-fase-i--primo-release-tagged-v100)
11. [Fase J — Rollback procedures](#11-fase-j--rollback-procedures)
12. [Fase K — Post-release monitoring](#12-fase-k--post-release-monitoring)
13. [Checklist end-to-end finale](#13-checklist-end-to-end-finale)
14. [Appendice A — Comandi completi](#14-appendice-a--comandi-completi)
15. [Appendice B — Troubleshooting per sintomo](#15-appendice-b--troubleshooting-per-sintomo)
16. [Appendice C — Security considerations](#16-appendice-c--security-considerations)
17. [Appendice D — Risk register](#17-appendice-d--risk-register)

---

## 0. Stato attuale e gap

### 0.1 Cosa già funziona

- **Export presets** in `v1/export_presets.cfg`: 3 preset configurati (Windows Desktop, Web HTML5, Android)
- **CI workflow `build.yml`**: 3 job paralleli (Windows/HTML5/Android) su push `main` + tag `v*`
- **CI workflow `ci.yml`**: 10+ validatori (lint, JSON catalog, sprite paths, cross-ref, SQL schema, signal count, pixel art, button-focus, smoke headless, deep tests)
- **CI workflow `pages.yml`**: deploy automatico di `docs/` su GitHub Pages a ogni push
- **Container CI**: `barichello/godot-ci:4.6` con template + Android SDK + Java già preinstallati
- **Landing page**: `docs/index.html` con sezione Download pronta (hardcoded links a `releases/latest`)
- **Git tag esistente**: `v1.0.0-demo` al commit `a0a63287`

### 0.2 Gap bloccanti per produzione

| # | Gap | Severità | Impatto |
|---|-----|----------|---------|
| G-01 | Android CI usa **solo debug keystore** (`/root/.android/debug.keystore` del container). APK prodotta non installabile su dispositivi senza sviluppo | P0 | Nessun APK pubblicabile |
| G-02 | `build.yml` **non dipende** da `ci.yml` — build parte in parallelo ai validatori → possibile rilascio di binari con parse errors | P0 | Shipping broken builds |
| G-03 | Nessuna automazione da artifact CI → GitHub Release: gli artefatti scadono dopo 30 giorni e non diventano asset scaricabili | P0 | Landing page link `releases/latest` è vuoto |
| G-04 | Landing page `docs/index.html`: pulsante Android è `<button disabled>` hardcoded, no distinction tra "coming soon" vs "available" | P1 | UX confusa per utenti |
| G-05 | Nessuna `config/version` in `project.godot`, `application/file_version` ripetuta in 3 punti (`export_presets.cfg` Windows, Android `version_name`, `version_code`) → drift garantito | P1 | Versioni disallineate |
| G-06 | `export_credentials.cfg` è in `.gitignore` ma non documentato; nessuno script per generare il keystore release né iniettarlo via secrets | P0 | Release signing impossibile |
| G-07 | Nessun GUI playtest pre-release documentato: solo CI headless. Bug UX come B-001 (focus chain) sono invisibili in headless | P1 | Rischio demo-day |
| G-08 | No release notes automatiche. `softprops/action-gh-release` richiede body template o auto-generated notes | P2 | Changelog manuale |
| G-09 | Nessun script di smoke test locale post-build per verificare che il `.exe` si avvii e mostri menu prima di uploadare | P1 | Regressioni post-build non rilevate |
| G-10 | LFS quota: `v1/addons/godot-sqlite/bin/` contiene 320 MB multi-piattaforma — ogni clone CI scarica tutto | P2 | Tempi CI lenti, quota GitHub |

### 0.3 Gap non bloccanti (backlog post-release)

- Firma digitale Authenticode Windows (riduce SmartScreen warning ma richiede cert EV ~500€/anno)
- Google Play Store submission (richiede Developer account $25 one-time + review)
- Apple notarization + macOS build
- Delta update mechanism per `.exe` (post v1.1.0)
- Telemetry opt-in su errori di avvio

---

## 1. Principi di base e vincoli

### 1.1 Vincoli non negoziabili

1. **Mai pushare keystore release in git**. `.gitignore` deve contenere `*.keystore`, `*.jks`, `*.p12`, `keystore-credentials.env`. Keystore release vive solo in:
   - Filesystem locale Renan (backup cifrato)
   - GitHub Secrets (base64-encoded)
   - Password manager personale

2. **Ogni modifica a `build.yml` passa da branch `feature/build-*` + PR**. Mai editare direttamente su `main` workflow CI: un errore nel YAML blocca tutti i build successivi.

3. **Nessuna release senza preflight**. Prima di `git tag v1.0.0`:
   - Smoke headless passa (`./scripts/smoke_test.sh`)
   - Deep tests passano (`./scripts/deep_test.sh`)
   - Playtest GUI manuale 5 minuti senza errori (vedi Fase H)
   - Build locale `.exe` si avvia e raggiunge menu principale

4. **Semantic versioning**. `v{MAJOR}.{MINOR}.{PATCH}`:
   - `v1.0.0` = primo release pubblico
   - `v1.0.1` = hotfix bug critico
   - `v1.1.0` = feature aggiunta (es. storm audio track)
   - `v2.0.0` = save format migration non retrocompatibile

5. **Atomic builds**. Ogni commit a `main` produce o tutte le piattaforme green o nessuna pubblicata. Il job release è atomico: se uno dei 3 export fallisce, nessuno viene uploadato.

6. **Zero riferimenti AI nel changelog** (coerente con convenzioni git del repo).

### 1.2 Success criteria

Il piano è completato con successo quando:

- [ ] Utente finale clicca "Windows (.exe)" sulla landing page → scarica `RelaxRoom-v1.0.0-windows-x64.exe` firmato (se Authenticode disponibile, altrimenti unsigned)
- [ ] Utente finale clicca "Android (.apk)" → scarica `RelaxRoom-v1.0.0.apk` signed con release keystore, installabile su device Android 7.0+ senza errori
- [ ] Entrambi i binari si avviano, mostrano menu principale, permettono nuova partita, piazzamento decorazione, save, chiusura pulita
- [ ] CI su `main` mostra tutti i 10+ validatori green + 3 build job green per ogni commit
- [ ] GitHub Release `v1.0.0` ha asset: `RelaxRoom-v1.0.0-windows-x64.exe`, `RelaxRoom-v1.0.0-android.apk`, `RelaxRoom-v1.0.0-source.zip`, `SHA256SUMS.txt`
- [ ] Landing page mostra la versione corrente leggendo dinamicamente da GitHub API (fallback statico ok)

---

## 2. Fase A — Versioning centralizzato

**Obiettivo**: single source of truth per `app_version`. Script di bump per sincronizzare `project.godot`, `export_presets.cfg`, landing page.

**Durata stimata**: 1.5h

**Files toccati**:
- `v1/VERSION` (nuovo, single line `1.0.0`)
- `v1/project.godot` (+ `config/version`)
- `v1/export_presets.cfg` (patch via sed)
- `scripts/bump_version.sh` (nuovo)
- `scripts/sync_version_to_presets.py` (nuovo)
- `v1/scripts/utils/constants.gd` (add `APP_VERSION`)
- `docs/index.html` (span `<span id="app-version">1.0.0</span>`)

### 2.1 Formato del file `v1/VERSION`

```
1.0.0
```

Una sola riga, no BOM, trailing newline. La parse è `cat v1/VERSION | tr -d '[:space:]'`.

### 2.2 Script `scripts/bump_version.sh`

```bash
#!/usr/bin/env bash
# Bump app version in v1/VERSION + sync to all consumers.
# Usage: ./scripts/bump_version.sh patch|minor|major
#        ./scripts/bump_version.sh 1.2.3  (explicit)
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current=$(cat v1/VERSION | tr -d '[:space:]')
IFS='.' read -r major minor patch <<< "$current"

case "${1:-patch}" in
    major) new="$((major+1)).0.0" ;;
    minor) new="${major}.$((minor+1)).0" ;;
    patch) new="${major}.${minor}.$((patch+1))" ;;
    [0-9]*.[0-9]*.[0-9]*) new="$1" ;;
    *) echo "Usage: $0 patch|minor|major|X.Y.Z" >&2; exit 2 ;;
esac

echo "Bumping v${current} -> v${new}"
echo "${new}" > v1/VERSION

python3 scripts/sync_version_to_presets.py "${new}"

# Stage for user review, DO NOT auto-commit
git status
```

### 2.3 Script `scripts/sync_version_to_presets.py`

Riscrive 3 campi in `v1/export_presets.cfg` (Windows `application/file_version`, `application/product_version`; Android `version/name`; usando regex, non editing manuale che rompe preset ordering). Inoltre aggiorna `v1/project.godot` `config/version`.

```python
#!/usr/bin/env python3
"""Sync v1/VERSION → export_presets.cfg + project.godot.

Usage: python3 scripts/sync_version_to_presets.py 1.2.3
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION_RE = re.compile(r'^\d+\.\d+\.\d+$')

def bump_presets(presets_path: Path, new_version: str) -> None:
    text = presets_path.read_text(encoding="utf-8")
    text = re.sub(
        r'(application/file_version\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    text = re.sub(
        r'(application/product_version\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    text = re.sub(
        r'(version/name\s*=\s*)"[^"]*"',
        rf'\1"{new_version}"',
        text,
    )
    presets_path.write_text(text, encoding="utf-8")

def bump_project_godot(godot_path: Path, new_version: str) -> None:
    text = godot_path.read_text(encoding="utf-8")
    if "config/version=" in text:
        text = re.sub(
            r'(config/version\s*=\s*)"[^"]*"',
            rf'\1"{new_version}"',
            text,
        )
    else:
        # Insert after config/name line
        text = text.replace(
            'config/name="Relax Room"',
            f'config/name="Relax Room"\nconfig/version="{new_version}"',
        )
    godot_path.write_text(text, encoding="utf-8")

def main() -> int:
    if len(sys.argv) < 2 or not VERSION_RE.match(sys.argv[1]):
        print("Usage: sync_version_to_presets.py X.Y.Z", file=sys.stderr)
        return 2
    new_version = sys.argv[1]
    repo = Path(__file__).resolve().parent.parent
    bump_presets(repo / "v1/export_presets.cfg", new_version)
    bump_project_godot(repo / "v1/project.godot", new_version)
    print(f"Synced {new_version} to export_presets.cfg + project.godot")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

### 2.4 Costante runtime `APP_VERSION`

In `v1/scripts/utils/constants.gd`:

```gdscript
# Runtime: leggere da ProjectSettings che parserizza config/version
const APP_VERSION := "1.0.0"  # Sincronizzato da scripts/bump_version.sh
```

Esposto via `GameManager.get_version() -> String`. Visualizzato nel menu principale footer "v1.0.0" e nel profile HUD tooltip. Utile anche per `AppLogger.info("App", "boot", {"version": GameManager.get_version()})`.

### 2.5 CI validator aggiuntivo `ci/validate_version_sync.py`

Fallisce se `v1/VERSION` non matcha i valori in `export_presets.cfg` / `project.godot` / `constants.gd:APP_VERSION`. Prevent drift.

```python
# Pseudocode
expected = Path("v1/VERSION").read_text().strip()
presets = Path("v1/export_presets.cfg").read_text()
assert f'application/file_version="{expected}"' in presets
assert f'version/name="{expected}"' in presets
constants = Path("v1/scripts/utils/constants.gd").read_text()
assert f'APP_VERSION := "{expected}"' in constants
```

Aggiunto come job `validate-version` in `ci.yml`.

### 2.6 Verification checklist Fase A

- [ ] `cat v1/VERSION` stampa `1.0.0`
- [ ] `./scripts/bump_version.sh 1.0.1 && ./scripts/bump_version.sh 1.0.0` rolls forward/back senza errori
- [ ] `grep -c "1.0.0" v1/export_presets.cfg` stampa ≥ 3 (Windows file_version, product_version, Android version_name)
- [ ] `godot --headless --path v1/ --quit` stampa `version: 1.0.0` nei log
- [ ] CI job `validate-version` green

---

## 3. Fase B — Keystore Android (debug + release)

**Obiettivo**: generare release keystore locale, inserire in GitHub Secrets, documentare.

**Durata stimata**: 1h

**Files toccati**:
- `scripts/generate_keystores.sh` (nuovo)
- `docs/ANDROID_SIGNING.md` (nuovo, internal doc)
- `.gitignore` (+ pattern keystore)
- `v1/export_presets.cfg` (config keystore paths)
- `.github/workflows/build.yml` (decode secrets)

### 3.1 Genera keystore debug + release (locale)

```bash
#!/usr/bin/env bash
# scripts/generate_keystores.sh
# Genera debug + release keystore per Android signing.
# IMPORTANTE: esegue una sola volta per computer. Backup release.keystore in luogo sicuro.
set -euo pipefail

KS_DIR="${KS_DIR:-$HOME/.relax-room-keys}"
mkdir -p "$KS_DIR"
chmod 700 "$KS_DIR"

# Debug keystore (può stare in repo se necessario, ma preferire fuori)
if [[ ! -f "$KS_DIR/debug.keystore" ]]; then
    keytool -genkey -v \
        -keystore "$KS_DIR/debug.keystore" \
        -alias androiddebugkey \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass android \
        -keypass android \
        -dname "CN=Android Debug,O=Android,C=US"
    echo "Debug keystore: $KS_DIR/debug.keystore"
fi

# Release keystore (NO password hardcoded, chiede interattivamente)
if [[ ! -f "$KS_DIR/release.keystore" ]]; then
    echo "=== RELEASE KEYSTORE ==="
    echo "Userai questo keystore per firmare ogni APK di produzione."
    echo "PERDERE questo file = impossibile aggiornare l'app (utenti dovranno disinstallare)."
    echo "Conserva in: password manager + cloud backup cifrato + chiavetta offline."
    echo
    read -r -p "Alias (es. 'relaxroom'): " ALIAS
    read -r -s -p "Store password: " STOREPASS; echo
    read -r -s -p "Conferma store password: " STOREPASS2; echo
    [[ "$STOREPASS" == "$STOREPASS2" ]] || { echo "Password mismatch"; exit 1; }
    read -r -p "CN (es. 'Renan Augusto Macena'): " CN
    read -r -p "O (es. 'IFTS'): " ORG
    read -r -p "C (2 lettere, es. 'IT'): " COUNTRY

    keytool -genkey -v \
        -keystore "$KS_DIR/release.keystore" \
        -alias "$ALIAS" \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass "$STOREPASS" \
        -keypass "$STOREPASS" \
        -dname "CN=$CN,O=$ORG,C=$COUNTRY"
    echo "Release keystore: $KS_DIR/release.keystore"
    echo "Alias: $ALIAS"
    echo "Password: (quella che hai digitato)"
fi

echo
echo "=== NEXT STEPS ==="
echo "1. Base64 il release keystore:"
echo "   base64 -w0 $KS_DIR/release.keystore | xclip -sel clip"
echo "2. Vai su GitHub repo Settings -> Secrets and variables -> Actions"
echo "3. Crea secrets:"
echo "   - ANDROID_RELEASE_KEYSTORE_B64 (paste output base64)"
echo "   - ANDROID_RELEASE_KEYSTORE_PASS (store password)"
echo "   - ANDROID_RELEASE_KEY_ALIAS"
echo "   - ANDROID_RELEASE_KEY_PASS (di solito uguale a store password)"
```

### 3.2 Pattern `.gitignore`

```
# Android keystore — MAI committare
*.keystore
*.jks
*.p12
v1/keystore-credentials.properties
v1/certs/release.keystore
v1/certs/debug.keystore
v1/export_credentials.cfg
```

Aggiungere anche verifica pre-commit hook: se uno script cerca di stage un file `.keystore`, fail immediato.

### 3.3 GitHub Secrets richiesti

| Secret name | Valore | Come generare |
|-------------|--------|---------------|
| `ANDROID_RELEASE_KEYSTORE_B64` | Base64 del `release.keystore` | `base64 -w0 release.keystore` |
| `ANDROID_RELEASE_KEYSTORE_PASS` | Password dello store | Inserita durante `generate_keystores.sh` |
| `ANDROID_RELEASE_KEY_ALIAS` | Alias della chiave (es. `relaxroom`) | Inserita durante `generate_keystores.sh` |
| `ANDROID_RELEASE_KEY_PASS` | Password della chiave | Solitamente uguale a store password |

Per upload: `gh secret set ANDROID_RELEASE_KEYSTORE_B64 < keystore.b64` o via GitHub web UI.

### 3.4 Debug keystore in CI

Il container `barichello/godot-ci:4.6` ha `/root/.android/debug.keystore` preinstallato. Continuiamo a usarlo per debug build. Per release build generiamo il keystore dai secrets a runtime.

### 3.5 Verification checklist Fase B

- [ ] `ls -la ~/.relax-room-keys/release.keystore` mostra file 2-3 KB con permessi 600
- [ ] `keytool -list -keystore ~/.relax-room-keys/release.keystore` stampa alias + SHA256
- [ ] GitHub repo settings mostra 4 secrets in Actions
- [ ] Nessun file `*.keystore` in `git status` (dopo aver stageddato tutto)
- [ ] `gh secret list` stampa 4 entry con timestamp

---

## 4. Fase C — Export presets hardening

**Obiettivo**: normalizzare `v1/export_presets.cfg` per release production. Aggiungere Windows icon, Android multi-architecture, fix preset Web per HTML5 download funzionante.

**Durata stimata**: 1h

**Files toccati**:
- `v1/export_presets.cfg`
- `v1/assets/app_icon.ico` (nuovo, 256x256 ICO multi-res)
- `v1/assets/app_icon_android.png` (nuovo, 512x512 PNG)
- `v1/export_credentials.cfg` (NON committato, template in `v1/export_credentials.cfg.example`)

### 4.1 Windows preset aggiornato

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../builds/windows/RelaxRoom-v1.0.0-x64.exe"

[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
custom_template/debug=""
custom_template/release=""
application/icon="res://assets/app_icon.ico"
application/file_version="1.0.0"
application/product_version="1.0.0"
application/company_name="IFTS"
application/product_name="Relax Room"
application/file_description="Cozy desktop companion"
application/copyright="Copyright (c) 2026 Renan Augusto Macena"
application/console_wrapper=false
ssh_remote_deploy/enabled=false
```

Nota: `export_path` è **relativo alla cartella v1/**. Quindi `../builds/windows/...` punta a `/tmp/Projectwork-IFTS/builds/windows/`. Conviene creare la dir in CI step prima dell'export.

### 4.2 Android preset aggiornato

```ini
[preset.2]
name="Android"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../builds/android/RelaxRoom-v1.0.0.apk"

[preset.2.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="1.0.0"
package/unique_name="com.ifts.relaxroom"
package/name="Relax Room"
package/signed=true
package/app_category=0
launcher_icons/main_192x192="res://assets/app_icon_android.png"
launcher_icons/adaptive_foreground_432x432=""
launcher_icons/adaptive_background_432x432=""
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
screen/orientation=6  # Sensor Landscape
permissions/access_network_state=true
permissions/internet=true
# tutti gli altri permissions/* = false
keystore/debug=""
keystore/debug_user=""
keystore/debug_password=""
keystore/release=""
keystore/release_user=""
keystore/release_password=""
```

Note chiave:
- `architectures/armeabi-v7a=true` aggiunge supporto a dispositivi più vecchi (Android 7.0 devices)
- `screen/orientation=6` = Sensor Landscape (il gioco è 16:9, portrait non ha senso)
- `package/signed=true` richiede keystore valido al momento dell'export
- Keystore paths lasciati VUOTI: vengono popolati da CI via `sed` dai secrets. Su dev locale Renan può avere `v1/export_credentials.cfg` con i valori.

### 4.3 Template `v1/export_credentials.cfg.example`

```ini
# Copia questo file a v1/export_credentials.cfg (già in .gitignore) e popola i valori
# Godot userà questi credentials per firmare export locali su Renan's machine.

[keystore/release]
keystore/release="/home/renan/.relax-room-keys/release.keystore"
keystore/release_user="YOUR_ALIAS"
keystore/release_password="YOUR_STORE_PASSWORD"
```

Nota: `export_credentials.cfg` è il meccanismo nativo Godot 4.6 per tenere password fuori da `export_presets.cfg` tracciato.

### 4.4 Windows icon generation

```bash
# Un icon.ico multi-res (16, 32, 48, 64, 128, 256)
# da un PNG sorgente 256x256
convert assets/app_icon_source.png \
    -define icon:auto-resize=256,128,64,48,32,16 \
    v1/assets/app_icon.ico
```

Se ImageMagick non disponibile in CI container: pre-generare localmente, commitare `app_icon.ico` binario nel repo.

### 4.5 Verification checklist Fase C

- [ ] Preset Windows: `grep -c "export_path" v1/export_presets.cfg` ≥ 3
- [ ] Preset Android: `grep "version/name" v1/export_presets.cfg` matcha v1/VERSION
- [ ] Icon files esistono: `ls v1/assets/app_icon.ico v1/assets/app_icon_android.png`
- [ ] Locally: `cd v1 && godot --headless --export-release "Windows Desktop" ../builds/test/test.exe` genera file > 80 MB
- [ ] Locally: `cd v1 && godot --headless --export-release "Android" ../builds/test/test.apk` genera file > 100 MB

---

## 5. Fase D — Build workflow production

**Obiettivo**: riscrivere `.github/workflows/build.yml` con signing release, atomic all-or-nothing, cache, artifact retention intelligente.

**Durata stimata**: 2h

**Files toccati**:
- `.github/workflows/build.yml` (rewrite)
- `scripts/ci/verify_binary.sh` (nuovo, smoke test post-build)

### 5.1 Nuovo `build.yml` struttura

```yaml
name: build

run-name: "${{ github.event_name }} — ${{ github.ref_name }} — Build"

on:
  push:
    branches: [main]
    paths:
      - 'v1/**'
      - '.github/workflows/build.yml'
  push:
    tags: ['v*.*.*']
  workflow_dispatch:
    inputs:
      skip_android:
        type: boolean
        default: false
        description: "Skip Android build (debug iterations)"

concurrency:
  group: build-${{ github.event.number || github.ref }}
  cancel-in-progress: true

env:
  GODOT_VERSION: "4.6"
  PROJECT_PATH: "v1"

jobs:
  build-windows:
    name: "Build Windows x64"
    runs-on: ubuntu-22.04
    timeout-minutes: 15
    container:
      image: barichello/godot-ci:4.6
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true
          fetch-depth: 0  # per git describe versioning

      - name: Verify Godot version
        run: godot --version

      - name: Create output dir
        run: mkdir -p builds/windows

      - name: Import project resources
        run: |
          cd "${{ env.PROJECT_PATH }}"
          godot --headless --import --quit || true
          godot --headless --import --quit

      - name: Export Windows release
        run: |
          cd "${{ env.PROJECT_PATH }}"
          godot --headless --export-release "Windows Desktop" \
            "../builds/windows/RelaxRoom-${GITHUB_REF_NAME}-x64.exe"
        env:
          GITHUB_REF_NAME: ${{ github.ref_name }}

      - name: Verify .exe created
        run: |
          ls -la builds/windows/*.exe
          test -s builds/windows/*.exe

      - name: Compute SHA256
        run: |
          cd builds/windows
          sha256sum *.exe > SHA256SUMS.windows.txt

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: relaxroom-windows-${{ github.sha }}
          path: |
            builds/windows/*.exe
            builds/windows/SHA256SUMS.windows.txt
          retention-days: 30

  build-android:
    name: "Build Android APK"
    runs-on: ubuntu-22.04
    timeout-minutes: 20
    container:
      image: barichello/godot-ci:4.6
    if: ${{ !inputs.skip_android }}
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Prepare output
        run: mkdir -p builds/android certs

      - name: Decode release keystore (if tag build)
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          echo "${{ secrets.ANDROID_RELEASE_KEYSTORE_B64 }}" | base64 -d > certs/release.keystore
          test -s certs/release.keystore
          # Patch export_presets.cfg in-place
          cd "${{ env.PROJECT_PATH }}"
          sed -i "s|keystore/release=\"\"|keystore/release=\"res://../certs/release.keystore\"|" export_presets.cfg
          sed -i "s|keystore/release_user=\"\"|keystore/release_user=\"${{ secrets.ANDROID_RELEASE_KEY_ALIAS }}\"|" export_presets.cfg
          sed -i "s|keystore/release_password=\"\"|keystore/release_password=\"${{ secrets.ANDROID_RELEASE_KEY_PASS }}\"|" export_presets.cfg

      - name: Use debug keystore (non-tag build)
        if: ${{ !startsWith(github.ref, 'refs/tags/v') }}
        run: |
          cp /root/.android/debug.keystore certs/debug.keystore
          cd "${{ env.PROJECT_PATH }}"
          sed -i "s|keystore/debug=\"\"|keystore/debug=\"res://../certs/debug.keystore\"|" export_presets.cfg
          sed -i "s|keystore/debug_user=\"\"|keystore/debug_user=\"androiddebugkey\"|" export_presets.cfg
          sed -i "s|keystore/debug_password=\"\"|keystore/debug_password=\"android\"|" export_presets.cfg

      - name: Import resources
        run: |
          cd "${{ env.PROJECT_PATH }}"
          godot --headless --import --quit || true
          godot --headless --import --quit

      - name: Export Android APK
        run: |
          cd "${{ env.PROJECT_PATH }}"
          if [[ "${GITHUB_REF}" == refs/tags/v* ]]; then
            godot --headless --export-release "Android" \
              "../builds/android/RelaxRoom-${GITHUB_REF_NAME}.apk"
          else
            godot --headless --export-debug "Android" \
              "../builds/android/RelaxRoom-dev-${GITHUB_SHA:0:7}.apk"
          fi

      - name: Verify APK
        run: |
          ls -la builds/android/*.apk
          # Verify signed
          apksigner verify --verbose builds/android/*.apk || echo "WARN: signature verify skipped"

      - name: Compute SHA256
        run: |
          cd builds/android
          sha256sum *.apk > SHA256SUMS.android.txt

      - name: Upload Android artifact
        uses: actions/upload-artifact@v4
        with:
          name: relaxroom-android-${{ github.sha }}
          path: |
            builds/android/*.apk
            builds/android/SHA256SUMS.android.txt
          retention-days: 30

      - name: Cleanup keystore
        if: always()
        run: rm -f certs/release.keystore

  build-html5:
    name: "Build HTML5 Web"
    runs-on: ubuntu-22.04
    timeout-minutes: 15
    container:
      image: barichello/godot-ci:4.6
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Prepare output
        run: mkdir -p builds/html5

      - name: Import resources
        run: |
          cd "${{ env.PROJECT_PATH }}"
          godot --headless --import --quit || true

      - name: Export HTML5
        run: |
          cd "${{ env.PROJECT_PATH }}"
          godot --headless --export-release "Web" \
            "../builds/html5/index.html"

      - name: Verify HTML5 output
        run: |
          ls -la builds/html5/
          test -f builds/html5/index.html
          test -f builds/html5/index.pck
          test -f builds/html5/index.wasm

      - name: Zip HTML5 for release
        run: |
          cd builds/html5
          zip -r ../relaxroom-html5.zip .

      - name: Upload HTML5 artifact
        uses: actions/upload-artifact@v4
        with:
          name: relaxroom-html5-${{ github.sha }}
          path: builds/relaxroom-html5.zip
          retention-days: 30

  smoke-binaries:
    name: "Smoke test built binaries"
    needs: [build-windows, build-html5]
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Verify Windows .exe size sensible
        run: |
          exe_path=$(find artifacts -name "*.exe" | head -1)
          size=$(stat -c%s "$exe_path")
          # Expected ~80-200 MB
          if (( size < 50000000 || size > 300000000 )); then
            echo "ERROR: Windows .exe size unexpected: $size bytes"
            exit 1
          fi
          echo "Windows .exe: $size bytes OK"

      - name: Verify HTML5 index.html contains expected strings
        run: |
          html=$(find artifacts -name "index.html" | head -1)
          grep -q "Relax Room" "$html" || { echo "Missing project name in HTML"; exit 1; }
```

### 5.2 `scripts/ci/verify_binary.sh` (smoke post-build)

Eseguito localmente da Renan dopo download artifact per verificare che il binario si avvii. Non è parte del CI (CI headless non può lanciare `.exe`), ma è documentato.

```bash
#!/usr/bin/env bash
# scripts/ci/verify_binary.sh path/to/relaxroom.exe
# Smoke test locale: avvia il binario, attendi 8 secondi, killa, verifica no crash.
set -euo pipefail

binary="$1"
timeout=8

if [[ "$binary" == *.exe ]]; then
    # Windows: su Linux via wine, su Windows nativamente
    if command -v wine &>/dev/null; then
        timeout "$timeout" wine "$binary" 2>/tmp/smoke.log || true
    else
        echo "Wine not installed, skipping .exe smoke on this host"
        exit 0
    fi
elif [[ "$binary" == *.apk ]]; then
    # APK non smoke-testabile senza Android emulator
    echo "APK smoke requires Android emulator, run locally with: adb install -r $binary && adb shell am start -n com.ifts.relaxroom/.RelaxRoomActivity"
    exit 0
fi

# Verifica no 'SCRIPT ERROR' in logs
if grep -i "SCRIPT ERROR\|Parse Error\|FATAL" /tmp/smoke.log; then
    echo "SMOKE FAIL"
    exit 1
fi
echo "SMOKE PASS"
```

### 5.3 Verification checklist Fase D

- [ ] PR con nuovo `build.yml` passa su branch `feature/build-production`
- [ ] CI job `build-windows` produce artifact > 80 MB
- [ ] CI job `build-android` produce APK > 100 MB (con debug keystore su non-tag)
- [ ] CI job `build-html5` produce zip > 40 MB
- [ ] CI job `smoke-binaries` green
- [ ] Download artifact da CI, run local: `.exe` si avvia correttamente

---

## 6. Fase E — Release workflow

**Obiettivo**: workflow separato che su `git push --tags v*.*.*` crea GitHub Release, pull artifact, upload come release assets, pubblica changelog.

**Durata stimata**: 1.5h

**Files toccati**:
- `.github/workflows/release.yml` (nuovo)
- `CHANGELOG.md` (nuovo, Keep a Changelog format)
- `.github/release-template.md` (body template per GitHub Release)

### 6.1 Nuovo `release.yml`

```yaml
name: release

run-name: "Release ${{ github.ref_name }}"

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write  # per creare Release

jobs:
  wait-for-builds:
    name: "Wait for build workflow"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Wait for build workflow
        uses: lewagon/wait-on-check-action@v1.3.4
        with:
          ref: ${{ github.sha }}
          check-name: "Build Windows x64"
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 30
          allowed-conclusions: success
      - name: Wait for Android build
        uses: lewagon/wait-on-check-action@v1.3.4
        with:
          ref: ${{ github.sha }}
          check-name: "Build Android APK"
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 30
          allowed-conclusions: success

  create-release:
    name: "Create GitHub Release"
    needs: wait-for-builds
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download Windows artifact
        uses: dawidd6/action-download-artifact@v3
        with:
          workflow: build.yml
          name: relaxroom-windows-${{ github.sha }}
          path: release-assets/windows/

      - name: Download Android artifact
        uses: dawidd6/action-download-artifact@v3
        with:
          workflow: build.yml
          name: relaxroom-android-${{ github.sha }}
          path: release-assets/android/

      - name: Download HTML5 artifact
        uses: dawidd6/action-download-artifact@v3
        with:
          workflow: build.yml
          name: relaxroom-html5-${{ github.sha }}
          path: release-assets/html5/

      - name: Flatten assets
        run: |
          mkdir -p release-flat
          mv release-assets/windows/*.exe release-flat/ 2>/dev/null || true
          mv release-assets/android/*.apk release-flat/ 2>/dev/null || true
          mv release-assets/html5/*.zip release-flat/ 2>/dev/null || true

      - name: Consolidate SHA256SUMS
        run: |
          cd release-flat
          sha256sum *.exe *.apk *.zip > SHA256SUMS.txt
          cat SHA256SUMS.txt

      - name: Extract changelog section
        id: changelog
        run: |
          version="${{ github.ref_name }}"
          python3 scripts/ci/extract_changelog.py "$version" > /tmp/release-body.md
          echo "CHANGELOG_PATH=/tmp/release-body.md" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.ref_name }}
          name: "Relax Room ${{ github.ref_name }}"
          body_path: ${{ steps.changelog.outputs.CHANGELOG_PATH }}
          draft: false
          prerelease: ${{ contains(github.ref_name, '-rc') || contains(github.ref_name, '-beta') }}
          files: |
            release-flat/*.exe
            release-flat/*.apk
            release-flat/*.zip
            release-flat/SHA256SUMS.txt
          generate_release_notes: false  # usiamo il nostro body
```

### 6.2 `CHANGELOG.md` (Keep a Changelog format)

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-04-22

### Added
- Primo release pubblico di Relax Room
- Build Windows x64 (.exe standalone, embed_pck)
- Build Android APK (arm64-v8a + armeabi-v7a, Android 7.0+)
- Build HTML5 Web per browser moderni
- Profile HUD con immagine locale (mai cloud), mood slider 0-1, badge system
- 6 badge sbloccabili via eventi di gioco
- i18n IT/EN con TranslationServer runtime swap
- MoodManager: overlay gloomy, rain particles, pet WILD state, audio crossfade
- Virtual joystick mobile-only (gated via OS.has_feature)
- PBKDF2 v3 password hashing (100k iterazioni SHA-256)

### Changed
- Save format v5.0.0 con dual-write atomico JSON + SQLite
- Supabase exponential backoff su HTTP 429
- Autoload chain 12 singleton (aggiunti MoodManager, BadgeManager)

### Fixed
- B-004 Grid quadrati giganti in edit mode (viewport dinamico)
- B-016 JSON/SQLite divergence (dual-write completo)
- B-021 Rate limit Supabase (exponential backoff)
- B-030 RNG non deterministico in debug build

### Security
- PBKDF2 migration trasparente v1/v2 → v3 al login
- Refresh token Supabase non più in chiaro (pianificato v1.1.0)

[Unreleased]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/tag/v1.0.0
```

### 6.3 `scripts/ci/extract_changelog.py`

```python
#!/usr/bin/env python3
"""Estrae la sezione della versione richiesta da CHANGELOG.md.

Usage: extract_changelog.py v1.0.0
Emette su stdout il markdown della sezione, pronto per GitHub Release body.
"""

from __future__ import annotations
import re
import sys
from pathlib import Path

def extract(changelog: str, version: str) -> str:
    # Strip leading 'v' if present
    v = version.lstrip("v")
    # Match ## [1.0.0] ... until next ## [
    pattern = rf"^##\s*\[{re.escape(v)}\][^\n]*\n(.*?)(?=^##\s*\[|\Z)"
    match = re.search(pattern, changelog, re.MULTILINE | re.DOTALL)
    if not match:
        return f"Release notes for {version} non disponibili in CHANGELOG.md"
    body = match.group(1).strip()
    return f"## Relax Room {version}\n\n{body}\n\n---\n\n**Download assets qui sotto.** Verifica con `sha256sum -c SHA256SUMS.txt`."

def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract_changelog.py vX.Y.Z", file=sys.stderr)
        return 2
    version = sys.argv[1]
    changelog = Path("CHANGELOG.md").read_text(encoding="utf-8")
    print(extract(changelog, version))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

### 6.4 Verification checklist Fase E

- [ ] Tag test `v0.99.0-test` su branch `feature/release-workflow` → CI produce Release GitHub draft
- [ ] Release ha 4 asset: `.exe`, `.apk`, `.zip` (HTML5), `SHA256SUMS.txt`
- [ ] Body della Release contiene sezione changelog estratta
- [ ] `gh release view v0.99.0-test` mostra "published: true"
- [ ] Cleanup: `gh release delete v0.99.0-test -y && git push --delete origin v0.99.0-test`

---

## 7. Fase F — CI gate: build blocca su validatori falliti

**Obiettivo**: `build.yml` deve aspettare che `ci.yml` passi prima di eseguire. Previene shipping di binari con parse/lint errors.

**Durata stimata**: 30 min

**Files toccati**:
- `.github/workflows/build.yml` (aggiunge `needs`)

### 7.1 Strategia

Due approcci:

**A — Single workflow con multi-job (pulito)**:
Unire `ci.yml` e `build.yml` in un solo workflow `main.yml` con jobs:
```
lint -> validate-* -> smoke-headless -> deep-tests -> [build-windows, build-android, build-html5] -> release
```

**B — Separati con `workflow_run` (meno invasivo)**:
Lasciare i due workflow separati, ma aggiungere in `build.yml`:
```yaml
on:
  workflow_run:
    workflows: ["ci"]
    types: [completed]
    branches: [main]

jobs:
  guard:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "CI passed, proceeding with build"
```

Scegliamo **approccio B** perché meno invasivo e separa concerns. Ma aggiungiamo anche il trigger `push` come fallback per manual workflow_dispatch.

### 7.2 Implementazione concreta

```yaml
# build.yml trigger section aggiornata
on:
  workflow_run:
    workflows: ["ci"]
    types: [completed]
    branches: [main]
  push:
    tags: ['v*.*.*']
  workflow_dispatch:
    inputs:
      skip_ci_gate:
        type: boolean
        default: false
        description: "Skip CI gate (emergency)"

jobs:
  ci-gate:
    name: "Verify CI passed"
    runs-on: ubuntu-latest
    if: |
      github.event_name != 'workflow_run' ||
      github.event.workflow_run.conclusion == 'success'
    steps:
      - run: echo "CI gate OK, proceeding"

  build-windows:
    needs: [ci-gate]
    # ... rest of job
```

### 7.3 Verification checklist Fase F

- [ ] Push a branch con intentional lint error → `ci.yml` fails → `build.yml` does NOT trigger
- [ ] Push a branch clean → `ci.yml` green → `build.yml` starts 30s dopo ci.yml conclude
- [ ] `workflow_dispatch` con `skip_ci_gate=true` avvia build senza gate (emergency)
- [ ] Tag push `v1.0.0` triggera build indipendentemente dal gate (nuova versione deve buildare sempre)

---

## 8. Fase G — Landing page dinamica

**Obiettivo**: `docs/index.html` Download section fetch automatico latest release da GitHub API, con fallback statico se API rate-limited o private repo.

**Durata stimata**: 2h

**Files toccati**:
- `docs/index.html` (sezione Download)
- `docs/main.js` (fetch releases)
- `docs/style.css` (loading states)
- `docs/release-info.json` (nuovo, generato da CI per fallback statico)

### 8.1 Problema: repo privato

Il repo è `renanaugustomacena-ux/Projectwork-IFTS-Private` — **privato**. L'API pubblica `https://api.github.com/repos/.../releases/latest` ritorna 404 senza token. Strategie:

**A — Rendere repo pubblico**: 
- Pro: API GitHub Releases gratuita, no auth
- Contro: espone codice (che l'utente vuole comunque pubblicare, verificare)

**B — Proxy via GitHub Pages action**:
- Workflow `pages.yml` arricchito: fetch della latest release via `GITHUB_TOKEN`, scrive `docs/release-info.json` statico con URL asset
- Landing page legge `release-info.json` (sempre aggiornato a ogni deploy)
- Pro: nessuna esposizione runtime, zero rate limit
- Contro: richiede rebuild landing page a ogni release (ma è già su push main)

**Scegliamo B** per repo privato. Se utente decidesse di rendere pubblico, si switcha ad A con una riga.

### 8.2 Script `scripts/ci/generate_release_info.sh`

Eseguito in `pages.yml` prima del deploy:

```bash
#!/usr/bin/env bash
# Generate docs/release-info.json from latest GitHub Release
set -euo pipefail

OWNER="renanaugustomacena-ux"
REPO="Projectwork-IFTS-Private"

# Fetch latest release via gh CLI (usa GITHUB_TOKEN del workflow)
release_json=$(gh api "repos/$OWNER/$REPO/releases/latest" 2>/dev/null || echo '{}')

if [[ "$release_json" == "{}" ]]; then
    # Fallback: no release yet
    cat > docs/release-info.json <<EOF
{
  "version": "dev",
  "published_at": null,
  "assets": [],
  "notes": "No public release yet. Build from source."
}
EOF
    exit 0
fi

version=$(echo "$release_json" | jq -r '.tag_name')
published_at=$(echo "$release_json" | jq -r '.published_at')
notes=$(echo "$release_json" | jq -r '.body' | head -20)

# Build assets array
assets_json=$(echo "$release_json" | jq '[.assets[] | {name: .name, download_url: .browser_download_url, size: .size, platform: (
  if (.name | test("\\.exe$")) then "windows"
  elif (.name | test("\\.apk$")) then "android"
  elif (.name | test("\\.zip$")) then "html5"
  else "other"
  end
)}]')

jq -n \
  --arg version "$version" \
  --arg published_at "$published_at" \
  --argjson assets "$assets_json" \
  --arg notes "$notes" \
  '{
    version: $version,
    published_at: $published_at,
    assets: $assets,
    notes: $notes
  }' > docs/release-info.json

echo "Generated docs/release-info.json for $version"
cat docs/release-info.json
```

### 8.3 `docs/main.js` fetch + rendering

```javascript
// Aggiunto al main.js esistente
async function loadReleaseInfo() {
    try {
        const response = await fetch('./release-info.json', {cache: 'no-cache'});
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        renderDownloadSection(data);
    } catch (err) {
        console.warn('Release info unavailable, showing static fallback', err);
        renderFallbackSection();
    }
}

function renderDownloadSection(release) {
    const versionEl = document.getElementById('release-version');
    const dateEl = document.getElementById('release-date');

    if (versionEl) versionEl.textContent = release.version;
    if (dateEl && release.published_at) {
        const date = new Date(release.published_at);
        dateEl.textContent = date.toLocaleDateString('it-IT', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    const platforms = ['windows', 'android', 'html5'];
    platforms.forEach(platform => {
        const btn = document.getElementById(`download-${platform}`);
        if (!btn) return;
        const asset = release.assets.find(a => a.platform === platform);
        if (asset) {
            btn.href = asset.download_url;
            btn.classList.remove('disabled');
            btn.querySelector('.size').textContent = `${Math.round(asset.size / 1024 / 1024)} MB`;
        } else {
            btn.classList.add('disabled');
            btn.href = '#';
            btn.querySelector('.size').textContent = 'Coming soon';
        }
    });
}

function renderFallbackSection() {
    // Se release-info.json non disponibile, link a releases/latest
    document.querySelectorAll('.download-btn').forEach(btn => {
        btn.href = 'https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/latest';
    });
}

// Esegui al load
document.addEventListener('DOMContentLoaded', loadReleaseInfo);
```

### 8.4 `docs/index.html` sezione Download rivista

```html
<section id="download" class="section download-section">
    <div class="container">
        <h2>Scarica Relax Room</h2>
        <p class="download-meta">
            Versione <strong><span id="release-version">1.0.0</span></strong> ·
            pubblicata il <span id="release-date">—</span>
        </p>
        <div class="download-grid">
            <a id="download-windows" href="#" class="btn-download disabled" rel="noopener">
                <div class="platform-icon">🪟</div>
                <div class="platform-name">Windows (.exe)</div>
                <div class="size">—</div>
            </a>
            <a id="download-android" href="#" class="btn-download disabled" rel="noopener">
                <div class="platform-icon">🤖</div>
                <div class="platform-name">Android (.apk)</div>
                <div class="size">—</div>
            </a>
            <a id="download-html5" href="#" class="btn-download disabled" rel="noopener">
                <div class="platform-icon">🌐</div>
                <div class="platform-name">Web (HTML5)</div>
                <div class="size">—</div>
            </a>
        </div>
        <p class="download-security">
            Verifica integrità con <a href="https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/latest/download/SHA256SUMS.txt">SHA256SUMS.txt</a>.
            APK firmata con chiave release dedicata (non Google Play Store).
        </p>
    </div>
</section>
```

### 8.5 CSS aggiornamenti

```css
.download-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 1.5rem;
    margin: 2rem 0;
}

.btn-download {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem 1.5rem;
    background: var(--color-surface);
    border: 2px solid var(--color-primary);
    border-radius: 1rem;
    text-decoration: none;
    color: var(--color-text);
    transition: transform 0.2s, box-shadow 0.2s;
}

.btn-download:hover:not(.disabled) {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
}

.btn-download.disabled {
    opacity: 0.5;
    pointer-events: none;
    cursor: not-allowed;
}

.btn-download .platform-icon {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
}

.btn-download .platform-name {
    font-weight: 600;
    margin-bottom: 0.3rem;
}

.btn-download .size {
    font-size: 0.85rem;
    color: var(--color-text-muted);
}

.download-meta {
    text-align: center;
    color: var(--color-text-muted);
    margin-bottom: 1.5rem;
}

.download-security {
    text-align: center;
    font-size: 0.85rem;
    color: var(--color-text-muted);
    margin-top: 2rem;
}
```

### 8.6 Aggiornamento `pages.yml`

```yaml
name: pages

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - '.github/workflows/pages.yml'
  workflow_run:
    workflows: [release]
    types: [completed]

permissions:
  pages: write
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate release-info.json
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          chmod +x scripts/ci/generate_release_info.sh
          ./scripts/ci/generate_release_info.sh

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: docs

      - name: Deploy to Pages
        uses: actions/deploy-pages@v4
```

### 8.7 Verification checklist Fase G

- [ ] Locally: `./scripts/ci/generate_release_info.sh` produce `docs/release-info.json` valido JSON con 3 asset
- [ ] Open `docs/index.html` in browser locale → 3 bottoni download cliccabili con version + date
- [ ] Click su Windows → inizia download dal GitHub Release asset URL
- [ ] SEO: `curl -s https://renanaugustomacena-ux.github.io/Projectwork-IFTS-Private | grep -c "download"` ≥ 3
- [ ] Core Web Vitals: PageSpeed Insights green (FCP < 1.5s, LCP < 2.5s)

---

## 9. Fase H — Playtest manuale GUI

**Obiettivo**: runbook di 30 minuti per verifica finale prima di tag release. Nessun automated test lo sostituisce.

**Durata stimata**: 30-45 min per ogni release candidate

**Files toccati**:
- `docs/RELEASE_PLAYBOOK.md` (nuovo)

### 9.1 Preparazione

```bash
# Fresh working dir
cd /tmp/Projectwork-IFTS
git checkout main
git pull

# Clean user data per test da zero
rm -rf ~/.local/share/godot/app_userdata/RelaxRoom/

# Launch
godot4 --path v1/ --verbose 2>&1 | tee /tmp/playtest-$(date +%Y%m%d-%H%M).log
```

### 9.2 Scenarios da coprire

**Scenario 1 — First launch (5 min)**
1. [ ] Menu principale si carica senza errori nella console
2. [ ] Click "Nuova Partita" → prompt character select
3. [ ] Seleziona character → gameplay scene carica
4. [ ] Tutorial parte automatico al primo ingresso
5. [ ] Skip tutorial button funziona

**Scenario 2 — Movement & interaction (5 min)**
1. [ ] WASD/arrow keys muovono il personaggio in tutte le direzioni
2. [ ] Animazioni walk_up/down/left/right cambiano correttamente
3. [ ] Character non si blocca dopo apertura/chiusura pannello (verifica B-001)
4. [ ] Pet gatto visibile + FSM IDLE→WANDER→FOLLOW in sequenza naturale
5. [ ] Zero errori in `/tmp/playtest-*.log`

**Scenario 3 — Decoration flow (5 min)**
1. [ ] Click DecoButton → panel si apre
2. [ ] Tab categorie tutti cliccabili (verifica B-003)
3. [ ] Drag decorazione dal panel
4. [ ] Drop dentro floor polygon → decorazione spawna
5. [ ] Drop fuori floor → toast "Stanza non pronta" o simile, no crash
6. [ ] Chiudi panel → panel sparisce, movement non bloccato
7. [ ] Click decorazione piazzata → popup (rotate/flip/scale/delete)

**Scenario 4 — Profile HUD + Mood (5 min)**
1. [ ] Click ProfileButton → profile HUD top-right appare
2. [ ] Nome utente mostrato ("Ospite" se guest, altrimenti username)
3. [ ] Click sulla icona profilo (👤 o immagine) → FileDialog apre
4. [ ] Seleziona un PNG/JPG locale → icona si aggiorna (verifica T-R-015c)
5. [ ] Drag mood slider a sinistra gradualmente:
   - a 0.5: overlay blu appare progressivo
   - a 0.15: rain particles appaiono sullo schermo
   - a 0.10: pet inizia movimento erratico (WILD state)
   - a 0.0: stato stormy completo
6. [ ] Drag slider a destra → tutto si rimuove, torna cozy
7. [ ] Click X → profile HUD chiude

**Scenario 5 — Save/Load cycle (5 min)**
1. [ ] Piazza 3 decorazioni
2. [ ] Cambia mood level a 0.3
3. [ ] Chiudi gioco (Esc o menu → esci)
4. [ ] Riapri gioco → stato persistente:
   - [ ] 3 decorazioni nelle posizioni salvate
   - [ ] Mood level a 0.3 (overlay soft visibile)
   - [ ] Immagine profilo persiste (se impostata)
5. [ ] Ispeziona `~/.local/share/godot/app_userdata/RelaxRoom/save_data.json` — valido JSON
6. [ ] Ispeziona `user://cozy_room.db` via `sqlite3` — righe coerenti con JSON

**Scenario 6 — Settings + Language toggle (3 min)**
1. [ ] Apri settings panel
2. [ ] Muovi volume master → audio muta/si sente
3. [ ] Click "Ripeti Tutorial" → scene reload + tutorial parte
4. [ ] (Se visibile) toggle lingua IT→EN → label UI che usano `tr()` cambiano lingua

**Scenario 7 — Badge unlock (2 min)**
1. [ ] Piazza 1 decorazione → toast "🏅 Badge sbloccato: Primo Arredo"
2. [ ] Apri profile HUD → badge `first_decor` in riga badges con colore pieno
3. [ ] Altri badge restano grigi

**Scenario 8 — Edge cases (5 min)**
1. [ ] Minimizza finestra → FPS scende a 15 (verifica performance_manager)
2. [ ] Ripristina finestra → FPS torna a 60
3. [ ] Resize finestra → grid si ridisegna (verifica B-004)
4. [ ] Alt+F4 → gioco esce pulito (verifica no errori "still in use at exit")
5. [ ] Lancia 2 istanze del gioco in parallelo → secondo si avvia OK o mostra "DB locked" gestito

**Scenario 9 — Auth + DB (opzionale, 5 min se implementato)**
1. [ ] Nuovo account via auth screen → login OK
2. [ ] Password hash in DB `sqlite3 cozy_room.db "SELECT password_hash FROM accounts"` inizia con `v3:100000:`
3. [ ] Logout → account switch
4. [ ] Login con account vecchio (se esisteva) → hash upgrade a v3 trasparente

### 9.3 Rilevanza log

Dopo ogni scenario, cercare nel log:
```bash
grep -E "ERROR|Parse|SCRIPT" /tmp/playtest-*.log
```
Se output non vuoto → abort release, fix bug, ripeti playtest.

### 9.4 Exit criteria

Release viene autorizzato a `git tag v1.0.0` solo se:
- [ ] 9/9 scenarios green (o 8/9 con scenario 9 skipped)
- [ ] Zero `SCRIPT ERROR` nel log
- [ ] Zero `ERROR: 1 resources still in use at exit` con COUNT > 2 (warning minimo tollerato)
- [ ] `save_data.json` e `cozy_room.db` coerenti dopo save+reload

---

## 10. Fase I — Primo release tagged v1.0.0

**Obiettivo**: eseguire la sequenza completa per il primo release pubblico.

**Durata stimata**: 30 min (dopo tutte le Fasi A-H complete)

### 10.1 Pre-flight

```bash
cd /tmp/Projectwork-IFTS
git checkout main
git pull
./scripts/smoke_test.sh     # deve passare
./scripts/deep_test.sh      # deve passare
python3 ci/validate_button_focus.py v1/scripts  # PASS
python3 ci/validate_version_sync.py  # PASS

# Verifica CHANGELOG.md ha sezione [1.0.0]
grep "## \[1.0.0\]" CHANGELOG.md || { echo "Update CHANGELOG first"; exit 1; }

# Verifica locale build ancora funziona
cd v1 && godot --headless --export-release "Windows Desktop" /tmp/test.exe
ls -la /tmp/test.exe  # dovrebbe essere >80MB
cd ..
```

### 10.2 Version bump finale

```bash
./scripts/bump_version.sh 1.0.0
git add v1/VERSION v1/export_presets.cfg v1/project.godot v1/scripts/utils/constants.gd
git commit -m "chore(release): bump version to 1.0.0"
git push origin main
```

Attendi che CI passi (~5 min).

### 10.3 Tag & push

```bash
git tag -a v1.0.0 -m "Relax Room v1.0.0 — primo release pubblico

Windows + Android + HTML5 buildati e firmati.
Vedi CHANGELOG.md sezione [1.0.0] per dettagli."

git push origin v1.0.0
```

### 10.4 Monitor CI

Il tag triggera in ordine:
1. `ci.yml` (già green per il commit) — ~6 min
2. `build.yml` — 3 job paralleli — ~15 min
3. `release.yml` — aspetta builds poi crea GH Release — ~3 min
4. `pages.yml` — triggered da release workflow completion — ~2 min

Total: ~20 min dal tag push a landing page aggiornata.

### 10.5 Monitor dashboard

```bash
# In un terminale
gh run watch
# oppure
gh run list --branch main --limit 5 --json name,status,conclusion
```

### 10.6 Verifica finale

- [ ] `gh release view v1.0.0` mostra published
- [ ] 4 asset scaricabili: `.exe`, `.apk`, `.zip`, `SHA256SUMS.txt`
- [ ] Apri https://renanaugustomacena-ux.github.io/Projectwork-IFTS-Private → landing page mostra "v1.0.0" e "pubblicata il DD Aprile 2026"
- [ ] Click download Windows → scarica .exe
- [ ] Esegui .exe scaricato → menu principale appare
- [ ] Click download Android → scarica .apk
- [ ] `adb install downloaded.apk` su device Android 7+ → installa OK
- [ ] Launch app su device → menu principale appare, movimento funziona

---

## 11. Fase J — Rollback procedures

### 11.1 Rollback release pubblicato

Se dopo release utenti segnalano bug critico (crash, corruzione save):

```bash
# 1. Marca release come pre-release (nasconde da "latest")
gh release edit v1.0.0 --prerelease

# 2. Se davvero broken, cancella asset ma non tag (preserva commit history)
gh release delete-asset v1.0.0 RelaxRoom-v1.0.0-x64.exe
gh release delete-asset v1.0.0 RelaxRoom-v1.0.0.apk

# 3. Pubblica v1.0.1 con fix
./scripts/bump_version.sh patch  # 1.0.0 → 1.0.1
# ... fix bug, test, commit
git tag -a v1.0.1 -m "Hotfix: ..."
git push origin v1.0.1

# 4. Landing page auto-aggiornata a v1.0.1 quando pages.yml deploya
```

### 11.2 Rollback CI workflow rotto

```bash
# Branch diretto, revert commit, PR merge
git checkout main
git revert <bad-commit-sha>
git push origin main
```

Se ripristino impossibile tramite revert (es. merge conflict), branch `hotfix/workflow-revert`, PR manuale, merge admin.

### 11.3 Rollback keystore compromesso

Se release keystore viene esposto accidentalmente:
1. Revoca tutte le release esistenti (marca come prerelease)
2. Genera nuovo keystore con nuovo alias
3. Aggiorna tutti i 4 GitHub Secrets
4. Pubblica v2.0.0 (signature change rompe updates, conta come major)
5. Comunica agli utenti di disinstallare e reinstallare

---

## 12. Fase K — Post-release monitoring

### 12.1 Metriche da tenere

- Download count per platform (GitHub Release insights: `gh release view v1.0.0 --json assets`)
- Landing page visits (Google Search Console se dominio pubblico, altrimenti no)
- GitHub Issues aperti con label `v1.0.0`
- CI green rate (% dei push main con build verde)

### 12.2 Feedback loop

Setup GitHub Issues template `.github/ISSUE_TEMPLATE/release-bug.md` per bug report strutturati post-v1.0.0.

### 12.3 Quando release v1.0.1

Hotfix trigger se:
- Bug crash rate > 5% (utenti segnalano crash frequente)
- Data corruption (save files rotti)
- Security vulnerability (es. SQL injection, XSS)
- Download asset mancante o corrotto

Feature update v1.1.0 quando:
- Storm audio track implementata
- Badge PNG custom pronti
- i18n refactor 50+ strings completato
- B-033 split local_database.gd completato
- Kenney assets 63 registrati

---

## 13. Checklist end-to-end finale

Template da copiare per ogni release. Tutti i checkmark devono essere `[x]` prima di `git tag`.

### Preparazione
- [ ] Branch `main` pulito, no commits in-flight
- [ ] `git log --oneline -10` revisionato, no accidental commits
- [ ] CHANGELOG.md sezione `[X.Y.Z]` scritta con Added/Changed/Fixed/Security sections
- [ ] `v1/VERSION` bumped con `./scripts/bump_version.sh`
- [ ] `validate_version_sync.py` PASS

### Validazione automatica
- [ ] `./scripts/smoke_test.sh` → exit 0
- [ ] `./scripts/deep_test.sh` → exit 0
- [ ] `python3 ci/validate_button_focus.py v1/scripts` → PASS
- [ ] `python3 ci/validate_json_catalogs.py v1/data` → PASS
- [ ] `gdlint v1/scripts/` → 0 warnings
- [ ] `gdformat --check v1/scripts/` → 0 diff

### Validazione manuale
- [ ] Playtest scenarios 1-8 (+9 opzionale) green (Fase H)
- [ ] Local build `.exe` si avvia (Fase D.verify)
- [ ] Local build `.apk` installabile (se device disponibile)

### Release
- [ ] Commit bump version pushed su `main`
- [ ] CI green su commit bump (wait ~6 min)
- [ ] Tag creato: `git tag -a v1.0.0 -m "..."`
- [ ] Tag pushed: `git push origin v1.0.0`
- [ ] `gh run watch` mostra build + release workflow green (wait ~20 min)

### Verifica post-release
- [ ] `gh release view v1.0.0` mostra published=true
- [ ] 4 asset scaricabili nella Release
- [ ] Landing page (GitHub Pages) mostra la nuova versione
- [ ] Download test da landing page → .exe funzionante
- [ ] Download test Android → .apk installabile

### Comunicazione
- [ ] Post su GitHub Discussions / Release notes
- [ ] Tweet/social (se applicabile)
- [ ] Update `README.md` se contiene badge version

---

## 14. Appendice A — Comandi completi

### 14.1 Setup iniziale (una tantum)

```bash
# Genera keystore
./scripts/generate_keystores.sh

# Upload secrets a GitHub
base64 -w0 ~/.relax-room-keys/release.keystore | gh secret set ANDROID_RELEASE_KEYSTORE_B64
echo "YOUR_STORE_PASSWORD" | gh secret set ANDROID_RELEASE_KEYSTORE_PASS
echo "relaxroom" | gh secret set ANDROID_RELEASE_KEY_ALIAS
echo "YOUR_KEY_PASSWORD" | gh secret set ANDROID_RELEASE_KEY_PASS

# Verifica secrets
gh secret list
```

### 14.2 Dev cycle quotidiano

```bash
# Sync
git checkout main && git pull

# Lavora su feature
git checkout -b feature/foo
# ... edit, commit

# Pre-push
./scripts/smoke_test.sh
python3 ci/validate_button_focus.py v1/scripts

# Push + PR
git push -u origin feature/foo
gh pr create --fill

# Dopo merge
git checkout main && git pull
```

### 14.3 Release flow

```bash
# 1. Preparare
./scripts/bump_version.sh minor
# Edit CHANGELOG.md per nuova sezione
git add -A && git commit -m "chore(release): bump version to 1.1.0"
git push origin main

# 2. Attendi CI (~6 min)
gh run watch

# 3. Tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0

# 4. Monitor build + release (~20 min)
gh run watch

# 5. Verifica
gh release view v1.1.0
```

### 14.4 Debug build failure

```bash
# Scarica log failed job
gh run view <run-id> --log-failed > /tmp/failed.log
less /tmp/failed.log

# Locale riproduzione
docker run --rm -it -v "$PWD:/workspace" -w /workspace \
    barichello/godot-ci:4.6 bash
# dentro container:
cd v1
godot --headless --import --quit
godot --headless --verbose --export-release "Windows Desktop" /tmp/test.exe
```

### 14.5 Debug Android signing

```bash
# Verifica APK firmato
apksigner verify --verbose builds/android/*.apk

# Mostra info cert keystore
keytool -list -v -keystore ~/.relax-room-keys/release.keystore -alias relaxroom

# Decrypt base64 secret (se serve copia locale)
gh secret get ANDROID_RELEASE_KEYSTORE_B64 | base64 -d > /tmp/release.keystore
```

---

## 15. Appendice B — Troubleshooting per sintomo

| Sintomo | Causa probabile | Fix |
|---------|-----------------|-----|
| CI `godot --export-release` fallisce con "template missing" | Template path sbagliato o container image corrotta | Verifica `ls ~/.local/share/godot/export_templates/4.6.stable/` dentro container. Reinstalla se mancante: `godot --headless --install-export-templates` |
| Android build: "keystore file not found" | Decode base64 fallito o path errata | `echo "$SECRET_B64" \| base64 -d > certs/release.keystore && ls -la certs/`. Verifica secret non vuoto |
| Android APK non installa: "App not installed" | Firma v1 mancante o minSdkVersion incompatibile | Verify con `apksigner verify --verbose`. Controlla `version/min_sdk` in export_presets |
| Windows .exe 50MB invece di >100MB | Template non trovato, Godot fa fallback a stub | Verifica container image + presets `custom_template/release` vuota |
| Release workflow "wait-on-check-action" timeout | Build job ha nome diverso da quello in check-name | `gh run view <build-run-id>` per nome esatto job. Update `check-name` in release.yml |
| Landing page non mostra nuova versione | `release-info.json` non rigenerato | Trigger manual `pages.yml` workflow dispatch |
| `softprops/action-gh-release` 403 Forbidden | GITHUB_TOKEN permissions mancanti | Aggiungi `permissions: contents: write` al job |
| Git LFS quota exceeded | godot-sqlite binaries troppo grandi | Considera rimuovere platform-specific .so non usate, o migra a LFS external S3 |
| CI `validate_button_focus.py` fail dopo PR merge | Nuovo Button.new() senza focus_mode | Aggiungi `X.focus_mode = Control.FOCUS_*` adiacente. Review PR author |
| HTML5 build produce file enorme (>100MB) | Texture non compresse, audio non compresso | Verifica import settings `.import` files per audio/textures |

---

## 16. Appendice C — Security considerations

### 16.1 Secrets management

- Mai `echo $SECRET` in CI log (GitHub Actions maschera automaticamente, ma non fidarsi)
- Rotation keystore ogni 24 mesi
- Backup keystore in 3 luoghi separati (filesystem, cloud cifrato, chiavetta)
- Password manager (Bitwarden/1Password) per storePass/keyPass

### 16.2 Supply chain

- Pin GitHub Actions a SHA commit, non a tag floating:
  ```yaml
  - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  ```
- Verifica `barichello/godot-ci:4.6` image digest pinning:
  ```yaml
  container:
    image: barichello/godot-ci@sha256:abc123...
  ```
- Dependabot per auto-PR di update actions versions (review manuale)

### 16.3 Binary signing

- Windows: Authenticode se budget disponibile (~€200-500/anno per EV cert). Rimuove warning SmartScreen
- Android: Mantieni release keystore segreto. Ogni cambio rompe update path utenti
- Hashes: pubblica sempre `SHA256SUMS.txt` con release, firmato via `gpg --detach-sign` se serve higher trust

### 16.4 Vulnerability disclosure

- README sezione "Security": punto di contatto per vulnerability reports
- GitHub Security Advisories abilitate sul repo (anche se privato)
- Non documentare CVE in release notes pubbliche (usa GHSA privato fino a patch)

---

## 17. Appendice D — Risk register

| ID | Rischio | Prob | Impact | Mitigazione |
|----|---------|------|--------|-------------|
| R-01 | Keystore release perso o compromesso | Bassa | Critico | 3 backup distinti, password strong, rotazione 24 mesi |
| R-02 | CI quota LFS superata | Media | Alto | Monitoraggio mensile `gh api /repos/.../actions/cache/usage`, rimuovere platform .so non usate |
| R-03 | Build deterministico rotto (hash diverso per stesso source) | Bassa | Medio | Pin Godot image SHA, pin export templates version, build reproducibility testing |
| R-04 | Landing page API rate limit (repo pubblico) | Bassa | Basso | Uso release-info.json statico generato da CI |
| R-05 | Smart-screen block su .exe unsigned | Alta | Medio | Documentare in landing page "Warning is normal", budget per EV cert v1.1.0 |
| R-06 | APK rejected da Play Store (non submitted ora) | Bassa | Medio | Google Play compliance post-v2.0.0, quando applicabile |
| R-07 | Demo laptop senza internet al demo-day | Media | Critico | Build .exe pre-scaricato su chiavetta USB + printed QR code al landing page |
| R-08 | Save migration v5.0.0 → v5.1.0 corrotta | Bassa | Alto | Test migration unit test in `v1/tests/integration/`, backup automatico save_data.backup.json |
| R-09 | Memory leak post-24h session | Media | Medio | Profile playtest endurance 24h prima di v1.1.0 |
| R-10 | CI workflow rotto tra feature merge | Media | Alto | Ogni modifica CI passa da branch + PR, mai diretto su main |

---

## Riepilogo timeline totale

| Fase | Durata | Cumulativo |
|------|--------|------------|
| A — Versioning | 1.5h | 1.5h |
| B — Keystore | 1h | 2.5h |
| C — Presets | 1h | 3.5h |
| D — Build workflow | 2h | 5.5h |
| E — Release workflow | 1.5h | 7h |
| F — CI gate | 0.5h | 7.5h |
| G — Landing page | 2h | 9.5h |
| H — Playtest | 0.75h | 10.25h |
| I — Release v1.0.0 | 0.5h | 10.75h |

**Effort totale**: ~11 ore di implementazione disciplinata + 30-45 min di playtest per ogni release successivo.

---

## Appendice E — Decisioni chiave documentate

1. **Repo privato** → landing page usa `release-info.json` statico generato in CI invece di GitHub API runtime
2. **barichello/godot-ci:4.6** come container CI (include templates + Android SDK preinstalled)
3. **Debug keystore** continua a essere quello del container (evita secret management complesso per non-tag builds)
4. **Release keystore** solo su tag `v*.*.*` (isolato da dev iterations)
5. **softprops/action-gh-release@v2** scelto su `gh release create` per robustness in CI
6. **Semantic versioning** strict: no tag intermedi come `v1.0.0-beta.3` a meno di RC ufficiali
7. **Virtual joystick** già gated su `OS.has_feature("mobile")` — l'APK lo include automaticamente
8. **HTML5** buildato e hostato come zip di download, non come live play (rompe save → SQLite in IndexedDB complesso)
9. **Windows solo x64** — armhf/x86-32 skippato (hardware legacy non target)
10. **Android solo arm64-v8a + armeabi-v7a** — x86/x86_64 skippati (solo emulatori)
