# Android Signing — Operational Guide

**Status**: Fase B (plan BUILD_RELEASE_PLAN.md §3)
**Audience**: Renan (repo owner)
**Classification**: Internal — NON pubblico

---

## TL;DR

Per firmare APK Android produzione:

```bash
# Una sola volta, in locale:
./scripts/generate_keystores.sh

# Upload 4 secrets su GitHub (output script ti guida):
gh secret set ANDROID_RELEASE_KEYSTORE_B64 < <(base64 -w0 ~/.relax-room-keys/release.keystore)
gh secret set ANDROID_RELEASE_KEYSTORE_PASS
gh secret set ANDROID_RELEASE_KEY_ALIAS
gh secret set ANDROID_RELEASE_KEY_PASS

# Verifica:
gh secret list
```

CI `build.yml` su tag `v*.*.*` usa i secrets per firmare release APK. Su branch builds usa il debug keystore del container.

---

## 1. Contesto

Android OS rifiuta di installare APK non firmate. Ogni APK deve essere firmata con:
- **Keystore**: file binario contenente una coppia chiave privata + certificato
- **Alias**: nome della chiave dentro il keystore (utile se il keystore ne contiene più di una)
- **Password**: protegge il keystore (store pass) + la chiave singola (key pass)

Convenzione pratica: **store pass = key pass** (semplifica CI + nessuno svantaggio pratico).

### Due keystore distinti

| Keystore | Scope | Password | Dove vive |
|----------|-------|----------|-----------|
| **debug** | dev + CI non-tag build | `android` (publicly known) | CI container `/root/.android/debug.keystore` (preinstalled) |
| **release** | tag builds (`v*.*.*`) → GitHub Release | utente sceglie | Renan locale + GitHub Secrets (mai in repo) |

### Perché non usare lo stesso keystore

- Debug keystore è pubblico — chiunque con source code può firmare APK identiche. OK per sviluppo, inaccettabile per produzione.
- Release keystore è il tuo sigillo: utenti possono verificare il certificato e sapere che l'APK viene da te.
- Perdere il release keystore = perdere la capacità di aggiornare l'app (signing mismatch). Utenti dovranno disinstallare + reinstallare.

---

## 2. Prerequisites

- OpenJDK 11+ installato (per `keytool`):
  ```bash
  # Ubuntu/Debian
  sudo apt install default-jdk
  # macOS
  brew install openjdk
  # Windows
  winget install EclipseAdoptium.Temurin.21.JDK
  ```
- `gh` CLI autenticato su `github.com/renanaugustomacena-ux/Projectwork-IFTS-Private`:
  ```bash
  gh auth login
  gh auth status  # verifica
  ```
- Password manager aperto — ti servirà per salvare la password del keystore.

---

## 3. Generate keystores

```bash
./scripts/generate_keystores.sh
```

Lo script:
1. Crea `~/.relax-room-keys/` (permessi 700 — solo owner)
2. Genera `debug.keystore` se mancante (password pubblica `android`)
3. Chiede interattivamente: alias, store password (>=8 char), CN, O, C
4. Genera `release.keystore` con RSA 2048, validity 10000 giorni (~27 anni)
5. Stampa i comandi `gh secret set` da lanciare

**Output path**: `$HOME/.relax-room-keys/release.keystore` (tutto fuori dal repo per design).

**Non chiudere il terminale** finché non hai caricato i secrets — la password è ancora in memoria.

### Esempio output

```
Alias chiave (es. 'relaxroom'): relaxroom
Store password (>= 8 char, MEMORIZZA): *******
Conferma store password: *******
CN (Common Name — es. 'Renan Augusto Macena'): Renan Augusto Macena
O (Organization — es. 'IFTS'): IFTS
C (Country code 2 lettere — es. 'IT'): IT

Generating keystore...
Fingerprint:
   SHA1: AB:CD:EF:...
   SHA256: 12:34:56:...
```

**Salva immediatamente nel password manager**:
- File `release.keystore` (bytes, ~2-3 KB) come attachment
- Alias: `relaxroom`
- Store password: `********`
- SHA256 fingerprint per verifica

---

## 4. Upload GitHub Secrets

Servono 4 secrets. Il CI li usa automaticamente su tag `v*.*.*`.

### Via `gh` CLI (raccomandato)

```bash
# 1. Encode keystore in base64 single-line (no newline)
base64 -w0 ~/.relax-room-keys/release.keystore | gh secret set ANDROID_RELEASE_KEYSTORE_B64

# 2. Store password
printf '%s' 'YOUR_PASSWORD_HERE' | gh secret set ANDROID_RELEASE_KEYSTORE_PASS

# 3. Alias
printf '%s' 'relaxroom' | gh secret set ANDROID_RELEASE_KEY_ALIAS

# 4. Key password (stessa della store)
printf '%s' 'YOUR_PASSWORD_HERE' | gh secret set ANDROID_RELEASE_KEY_PASS

# Verifica
gh secret list
```

Output atteso:
```
NAME                              UPDATED
ANDROID_RELEASE_KEYSTORE_B64      less than a minute ago
ANDROID_RELEASE_KEYSTORE_PASS     less than a minute ago
ANDROID_RELEASE_KEY_ALIAS         less than a minute ago
ANDROID_RELEASE_KEY_PASS          less than a minute ago
```

### Via dashboard GitHub (alternativo)

1. Repo → Settings → Secrets and variables → Actions
2. "New repository secret" per ciascuno dei 4
3. Per `ANDROID_RELEASE_KEYSTORE_B64`: encoda base64 localmente (`base64 -w0 file | xclip -sel clip` su Linux, `base64 file | pbcopy` su macOS), poi incolla nel valore

---

## 5. CI usage (già scriptato, vedi `build.yml`)

Il workflow `build-android` job (pianificato in BUILD_RELEASE_PLAN §5.1):

```yaml
- name: Decode release keystore (if tag build)
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    echo "${{ secrets.ANDROID_RELEASE_KEYSTORE_B64 }}" | base64 -d > certs/release.keystore
    test -s certs/release.keystore
    cd v1
    sed -i "s|keystore/release=\"\"|keystore/release=\"res://../certs/release.keystore\"|" export_presets.cfg
    sed -i "s|keystore/release_user=\"\"|keystore/release_user=\"${{ secrets.ANDROID_RELEASE_KEY_ALIAS }}\"|" export_presets.cfg
    sed -i "s|keystore/release_password=\"\"|keystore/release_password=\"${{ secrets.ANDROID_RELEASE_KEY_PASS }}\"|" export_presets.cfg
```

Su **non-tag builds** il job usa il debug keystore preinstallato nel container `barichello/godot-ci:4.6` (`/root/.android/debug.keystore`).

Su **tag build** (`git push origin v1.0.0`):
1. Decode keystore base64 → `certs/release.keystore`
2. Patch inline `export_presets.cfg` con paths + credentials
3. `godot --headless --export-release "Android" ...`
4. `apksigner verify --verbose *.apk` → PASS
5. Cleanup `certs/release.keystore` a fine job (sempre, anche se fail)

---

## 6. Dev locale (Renan machine)

Per firmare APK in locale senza dover patcher export_presets.cfg ogni volta:

```bash
cp v1/export_credentials.cfg.example v1/export_credentials.cfg
```

Edita `v1/export_credentials.cfg` con i path reali:

```ini
[keystore/release]
keystore/release="/home/renan/.relax-room-keys/release.keystore"
keystore/release_user="relaxroom"
keystore/release_password="your-real-password"

[keystore/debug]
keystore/debug="/home/renan/.relax-room-keys/debug.keystore"
keystore/debug_user="androiddebugkey"
keystore/debug_password="android"
```

Godot 4.6 legge `export_credentials.cfg` automaticamente durante export (file in `.gitignore`, mai committato).

**Verifica pre-commit**: sempre `git status` prima di commit. Se `export_credentials.cfg` compare → STOP, è un bug `.gitignore`.

---

## 7. Rotazione keystore

Quando rotare:
- Password compromessa (sospetto leak, grep accidentale in log pubblico, screen condiviso)
- Standard di sicurezza: ogni 24 mesi a prescindere
- Major version bump dell'app con nuovo branding (optional)

**Procedura rotazione**:

```bash
# 1. Backup vecchio keystore (per accedere vecchie version firmate)
mv ~/.relax-room-keys/release.keystore ~/.relax-room-keys/release.keystore.v1-$(date +%Y%m%d)

# 2. Rigenera
./scripts/generate_keystores.sh
# (nuovo alias? nuova password? decidi)

# 3. Update GitHub Secrets (sovrascrivi)
base64 -w0 ~/.relax-room-keys/release.keystore | gh secret set ANDROID_RELEASE_KEYSTORE_B64
# ... altri 3 secrets

# 4. Prossima release avra` nuova signature
# 5. ATTENZIONE: utenti esistenti NON potranno aggiornare l'APK
#    tramite normal update (signing mismatch). Devono:
#      - Disinstallare vecchia versione
#      - Installare nuova (no save loss se usano cloud sync Supabase)
```

Comunicare agli utenti via release notes.

---

## 8. Backup strategy

Minimo 3 luoghi separati, mai sulla stessa macchina:

| # | Dove | Cosa | Frequenza |
|---|------|------|-----------|
| 1 | Password manager (Bitwarden/1Password) | `release.keystore` come attachment + password | One-shot at generation |
| 2 | Cloud cifrato (iCloud End-to-End / Proton Drive) | `release.keystore` file | One-shot at generation |
| 3 | Chiavetta USB offline | `release.keystore` file + password in file `.txt` cifrato con GPG | One-shot at generation |

**Test recovery**: prova di decriptare 1 backup dopo 1 mese. Se fallisce, ri-esegui backup.

---

## 9. Incident response — keystore perso/compromesso

### Caso A — perso (hai i backup)

1. Restore da backup
2. Continua normale
3. Aggiorna password se non la ricordi più (serve: genera nuovo keystore — vai a caso **Rotazione** sopra)

### Caso B — perso (no backup)

1. Nessuna modo di recuperare — il keystore non è deducibile da APK firmate
2. Se NON hai ancora rilasciato v1.0.0 pubblicamente: rigenera keystore, nuovo secret, nessun impatto
3. Se HAI già rilasciato: v2.0.0 con nuovo keystore, utenti devono reinstallare
4. Comunicazione: email agli utenti + release notes chiare

### Caso C — compromesso (keystore leakato in log/screen/public repo)

1. **STOP**: ogni APK esistente è ora untrustworthy — attaccanti possono firmare APK malevole che pretendono di essere updates
2. Rigenera IMMEDIATAMENTE keystore + secrets
3. Revoca tutti i release pubblicati: `gh release edit v1.X.Y --prerelease` (nasconde da "latest")
4. Pubblica v2.0.0 con nuova signature + annuncio pubblico chiaro
5. Audit cronologia git per capire come è leakato (force-push cleanup se il keystore è in cronologia tree — rimane in pack files, serve `git filter-repo`)

---

## 10. Validation checklist

Dopo aver eseguito Fase B completa:

- [ ] `ls -la ~/.relax-room-keys/release.keystore` → file 2-3 KB, permessi 600
- [ ] `keytool -list -keystore ~/.relax-room-keys/release.keystore` → stampa alias + SHA1 + SHA256 senza chiedere password (store pass corretto?)
- [ ] `gh secret list` → 4 entries (ANDROID_RELEASE_*) con timestamp recenti
- [ ] `grep -r '\.keystore' .git --include=*.gitignore` → nessun match (gitignore non ha file .keystore, solo patterns)
- [ ] `git ls-files | grep -E '\.(keystore|jks|p12)$'` → vuoto (nessun keystore in repo)
- [ ] `git status` → `export_credentials.cfg` NON compare come untracked
- [ ] `ci/validate_no_keystore.py` → PASS (vedi §11)

---

## 11. CI guard: prevent keystore commit

Script `ci/validate_no_keystore.py` scansiona file tracciati e fallisce CI se trova keystore. Viene eseguito come job `validate-no-keystore` in `ci.yml`.

Se domani qualcuno (tu futuro, collega) accidentalmente `git add release.keystore`:
1. CI fallisce immediatamente, commit non può essere mergiato su main
2. Errore chiaro: "Keystore file tracked: path/to/file.keystore. Remove and rotate."

Come reagire se scatta:
1. `git rm --cached <file>` (rimuovi da index ma lascia su disco)
2. Verifica `.gitignore` include pattern appropriato
3. Commit cleanup
4. **Se il keystore compare già nel tree del remote**: anche se rimossi dal tip, il dato è in pack. Considerare compromesso (§9 caso C) e rotare.

---

## 12. Reference

- Plan: `v1/docs/BUILD_RELEASE_PLAN.md` §3
- Script: `scripts/generate_keystores.sh`
- Template: `v1/export_credentials.cfg.example`
- CI guard: `ci/validate_no_keystore.py`
- GitHub Secrets docs: https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions
- Android Signing docs: https://developer.android.com/studio/publish/app-signing
- Godot 4.6 export: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html
