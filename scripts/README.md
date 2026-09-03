# Tooling del repository

Script di sviluppo, validator della CI e strumenti di generazione asset.
Tutto gira su Windows (Git Bash), macOS e Linux con `python` (3.12) e, dove
serve, il binario console di Godot 4.7.1 indicato da `GODOT_BIN`.

Regola: nessuno script duplica la logica di un altro. `preflight.sh` chiama i
validator, la CI chiama gli stessi validator, pre-commit anche.

Ultimo allineamento: 2026-09-03 (v1.3.0).

## Prerequisiti locali

```bash
pip install -r ci/requirements.txt       # gdtoolkit 4.5.0 (gdlint/gdformat), Pillow
export GODOT_BIN="$HOME/Downloads/Godot_v4.7.1-stable_win64_console.exe"   # Windows
# Linux/macOS: GODOT_BIN=/percorso/Godot_v4.7.1-stable_linux.x86_64
```

Su Windows non esiste `python3`: tutti gli script usano `python` (con
fallback a `python3` dove il sistema lo offre).

## Script in `scripts/`

| Script | Cosa fa | Come si lancia | Chi lo chiama |
|---|---|---|---|
| `deep_test.sh` | Suite di integrazione headless (24 moduli). Sposta `user://` in una sandbox usa-e-getta via `APPDATA`/`XDG_DATA_HOME`/`HOME`, pianta il sentinella `.test_sandbox` che `test_runner.gd` pretende, e passa solo se il riepilogo dice `ALL PASS` **e** `test_results.jsonl` non contiene `"pass": false`. | `GODOT_BIN=... ./scripts/deep_test.sh --timeout 300 [--keep]` | CI job `deep-tests`, `preflight.sh`, manuale |
| `preflight.sh` | GO/NO-GO locale: gli stessi validator di `ci.yml`, gdlint/gdformat, boot headless, suite. Esce 0 (GO), 1 (NO-GO), 2 (ambiente non pronto). | `GODOT_BIN=... ./scripts/preflight.sh [--quick]` | manuale, prima di un tag |
| `bump_version.sh` | Aggiorna `v1/VERSION` e sincronizza `export_presets.cfg` (3 preset), `project.godot`, `constants.gd APP_VERSION`. Non committa. | `./scripts/bump_version.sh patch\|minor\|major\|X.Y.Z` | manuale, release |
| `sync_version_to_presets.py` | Il sincronizzatore usato da `bump_version.sh`; idempotente, preserva i fine riga. | `python scripts/sync_version_to_presets.py 1.3.0` | `bump_version.sh` |
| `build_apk_local.sh` | Import (2 passate) + `--export-debug "Android"` + verifica dimensione/firma. APK firmato col keystore di **debug**: per provare sul telefono, non per distribuire. | `GODOT_BIN=... ./scripts/build_apk_local.sh [out.apk]` | manuale |
| `ci/extract_changelog.py` | Estrae la sezione di una versione da `CHANGELOG.md` per il corpo della GitHub Release. | `python scripts/ci/extract_changelog.py 1.3.0` | `release.yml` |
| `ci/verify_binary.sh` | Controllo strutturale di un `.exe`/`.apk` scaricato dagli artifact (magic bytes, firma, `adb install` se c'e` un device). | `./scripts/ci/verify_binary.sh RelaxRoom.exe` | manuale |

### Ritirati il 2026-09-03

| Script | Perche` |
|---|---|
| `scripts/smoke_test.sh` | Cercava `godot4` in PATH, nessun chiamante: la CI fa lo smoke inline nel job `smoke-headless` e `preflight.sh` ha lo stesso passo. |
| `scripts/godot-validate.sh` | Nessun chiamante; boot con finestra (`--audio-driver Dummy`) non eseguibile in CI; coperto da smoke + suite. |
| `scripts/generate_keystores.sh` | Generava un keystore di release e insegnava a caricare 4 secret `ANDROID_RELEASE_*` che nessun workflow legge: la firma di release Android e` stata rimossa (audit G-003). |

## Validator in `ci/`

Ognuno e` un job separato di `ci.yml`; tutti girano anche da `preflight.sh`.

| Validator | Argomenti (come in CI) | Controllo |
|---|---|---|
| `validate_json_catalogs.py` | `v1/data` | struttura dei 7 cataloghi JSON |
| `validate_sprite_paths.py` | `v1` | ogni `sprite_path`/percorso audio dei cataloghi esiste |
| `validate_cross_references.py` | `v1/scripts/utils/constants.gd v1/data` | costanti vs id dei cataloghi |
| `validate_db_schema.py` | `v1/scripts/autoload/database/schema.gd` | il DDL SQLite e` eseguibile |
| `validate_button_focus.py` | `v1/scripts` | ogni `Button.new()`, slider, `OptionButton` creato da codice ha `focus_mode` esplicito |
| `validate_version_sync.py` | — | `v1/VERSION` = presets = `project.godot` = `constants.gd` |
| `validate_no_keystore.py` | — | nessun `.keystore/.jks/.p12` tracciato |
| `validate_signal_count.py` | `v1/scripts/autoload/signal_bus.gd --min 45` | numero minimo di segnali, nessun duplicato |
| `validate_doc_counts.py` | `.` | i `**N etichetta**` di `README.md` e `v1/README.md` coincidono con i numeri misurati |
| `extract_palette.py` | `--check` | `palette_projectwork.gpl` aggiornata rispetto a `male/old` (senza flag: la rigenera) |
| `validate_pixelart_deliverables.py` | `--check-palette` | personaggi nel formato reale (`<gender>_idle/walk/interact/` 8 strip 128x32, `<gender>_rotate.png` 256x32, almeno un `.aseprite`), gatto 80x16; palette come warning |
| `recolor_character.py` | `--check` | i fogli `male_rose` sono la ricolorazione esatta di `male/old` (senza flag: li rigenera) |
| `scaffold_character.py` | `--gender female --name maria` | crea la struttura di cartelle di un personaggio nuovo nel formato che il validator controlla |

`ci/requirements.txt` pinna `gdtoolkit==4.5.0` e `Pillow>=10,<12`, le uniche
dipendenze Python dei job.

## `tools/`

| Tool | Cosa fa |
|---|---|
| `gen_sfx.py` | Sintetizza i 29 effetti sonori di `v1/assets/audio/sfx/synth/` (deterministico: stesso seed, stesso WAV byte per byte). `--list` elenca, `--only a,b` rigenera un sottoinsieme, `--out DIR` scrive altrove. |

## Pre-commit

`.pre-commit-config.yaml` (setup: `pip install pre-commit && pre-commit install`):
trailing whitespace, EOF, YAML validi, file grandi; `gdlint`/`gdformat --check`
4.5.0 su `v1/scripts` **e** `v1/tests` (gli stessi percorsi della CI);
`validate_button_focus.py`, `validate_version_sync.py`, `validate_doc_counts.py`.

## Workflow GitHub Actions

| Workflow | Trigger | Cosa fa |
|---|---|---|
| `ci.yml` | push/PR su `main` (path `v1/**`, `ci/**`, `scripts/**`, `tools/**`, workflow) | 14 job: lint, 11 validator, smoke headless, suite integrazione nel container `barichello/godot-ci` 4.7.1 (pinnato per digest) |
| `build.yml` | `workflow_run` dopo CI verde su `main`, tag `v*.*.*`, manuale | export Windows x64 (release) e HTML5, APK Android di debug (sperimentale, non entra in release), smoke sui binari, SHA256SUMS per artifact |
| `release.yml` | tag `v*.*.*` | aspetta i check di `build.yml`, scarica gli artifact Windows + HTML5, corpo della release da `CHANGELOG.md` |
| `pages.yml` | push su `main` in `docs/**` | pubblica `docs/` su GitHub Pages (la stessa cartella e` pubblicata anche da Netlify via `netlify.toml`) |

## Export locale

```bash
G="$HOME/Downloads/Godot_v4.7.1-stable_win64_console.exe"
"$G" --headless --import --path v1                                          # prima volta / asset nuovi
"$G" --headless --path v1 --export-release "Windows Desktop" export/windows/RelaxRoom.exe
"$G" --headless --path v1 --export-debug   "Android"         export/android/RelaxRoom.apk
```

`v1/export/` e` ignorata da git. Prerequisiti: template di export 4.7.1 in
`%APPDATA%/Godot/export_templates/4.7.1.stable/` (Editor > Manage Export
Templates); per Android JDK 17, Android SDK (build-tools 34) e keystore di
debug indicati nelle Editor Settings (`export/android/*`).

## Test e lint locali

```bash
gdformat v1/scripts/ v1/tests/ && gdlint v1/scripts/ v1/tests/
GODOT_BIN="$G" ./scripts/deep_test.sh --timeout 300
GODOT_BIN="$G" ./scripts/preflight.sh          # tutto insieme, GO/NO-GO
```
