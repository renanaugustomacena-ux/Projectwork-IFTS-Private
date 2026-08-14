# Relax Room — Test Harness

Custom headless test harness senza GdUnit4. **234 test invasivi** in 23 moduli,
~8 secondi di esecuzione, exit code 0 (all pass) / 1 (failures). Girano in
preflight locale + CI GitHub Actions su container `barichello/godot-ci:4.6`.

## Esecuzione

```bash
./scripts/deep_test.sh                 # unico modo supportato
./scripts/deep_test.sh --keep          # conserva la sandbox per ispezionarla
GODOT_BIN=/percorso/godot ./scripts/deep_test.sh
```

Exit code **0** = ALL PASS, **1** = ≥ 1 failure, **124** = timeout (120s default),
**2** = errore d'harness (Godot assente, isolamento non attivo).

### Isolamento dal profilo giocatore (G-053)

**Non lanciare `godot4 --headless --path v1/ res://tests/test_runner.tscn` a
mano.** La suite scrive `save_data.json`, `save_data.backup*.json`,
`cozy_room.db` e `integrity.key` dentro `user://`; con
`use_custom_user_dir=true` + `custom_user_dir_name="RelaxRoom"` quella e` la
**stessa** directory che usa il gioco, quindi ogni run distruggeva i dati reali
del giocatore.

Godot 4.7 non ha un flag `--user-data-dir` e ignora i feature-override su
`config/custom_user_dir_name`, quindi l'aggancio e` la variabile d'ambiente da
cui l'engine deriva il data path all'avvio. `deep_test.sh` la imposta su una
directory temporanea creata al momento:

| Piattaforma | Variabile | `user://` diventa |
|-------------|-----------|-------------------|
| Windows | `APPDATA` | `<sandbox>/RelaxRoom` |
| Linux | `XDG_DATA_HOME` | `<sandbox>/RelaxRoom` |
| macOS | `HOME` | `<sandbox>/Library/Application Support/RelaxRoom` |

Conseguenze:

- **Concorrenza**: la sandbox nasce da `mktemp -d`, unica per run. Due suite
  lanciate insieme non si toccano (verificato: 196/196 su entrambe).
- **Test non indeboliti**: `user://` esiste ancora e trasloca in blocco, quindi
  SaveManager e LocalDatabase girano sul codice vero, solo su dati usa-e-getta.
- **Fail-safe**: il wrapper pianta un sentinella `.test_sandbox` nella sandbox e
  `test_runner.gd` rifiuta di eseguire test se non lo trova. Un ambiente mal
  configurato (o un lancio diretto di Godot) **aborta** invece di scrivere nel
  profilo reale.

Ogni run produce `test_results.jsonl` **dentro la sandbox** — il runner ne
stampa il percorso assoluto nella riga `Results:`. Senza `--keep` la sandbox
viene rimossa a fine run se tutto e` verde, e conservata se qualcosa fallisce.

## Moduli

| Modulo | Test | Copertura |
|--------|------|-----------|
| `test_helpers.gd` | 16 | `Helpers.snap_to_grid`, `clamp_inside_floor`, floor polygon init, `format_time`, Vec2 roundtrip |
| `test_catalogs.gd` | 22 | Ogni 129 deco sprite load + dimensions, 25 char sprite (idle/walk/interact/rotate), 2 audio track, 6 mess placeholder color, 3 theme hex, category + ID integrity, un catalogo mancante resta in coda per la UI invece di sparire (V-019) |
| `test_stress.gd` | 12 | Isteresi 3 livelli (0.35/0.60 up, 0.25/0.50 down), clamp 0..1, mess signal integration (spawn/clean), decay passivo, persist livello_stress int |
| `test_save.gd` | 13 | HMAC-SHA256 deterministic + length, save/load roundtrip, tampered HMAC → backup fallback, migrazione v1/v3/v4 → v5, version compare, reset_all preserve pet_variant |
| `test_spawn.gd` | 11 | Minimal Room instance, spawn ogni 129 deco (no failure), nearest texture filter, non-centered anchor, scale/rotation/flip persist in deco_data, SCALE_STEPS cycling, clamp inside floor |
| `test_panels.gd` | 9 | 4 panel open/close (deco, settings, profile, profile_hud), mutual exclusion, toggle-same chiude, Esc handler, SignalBus panel_opened/closed fire |
| `test_input.gd` | 14 | WASD via `Input.action_press`, velocity direction corretta, diagonal normalizzata a SPEED=120, release azzera velocity, animazione walk/idle direzionale + flip_h |
| `test_ui_events.gd` | 15 | `pressed.emit()` per HUD buttons apre panel corretto, DropZone stays PASS anche con panel aperto, DecoButton is TextureRect (NOT Button), `_get_drag_data` non-null con valid meta, ≥60 DecoButtons con drag_data meta dentro panel, no overlay blockers upper-right quadrant |
| `test_crypto.gd` | 5 | PBKDF2-HMAC-SHA256 vs vettori RFC 8018, password vuota fail-closed, roundtrip hash v4, hash v4 malformato rifiutato subito, salt unico per account |
| `test_save_failures.gd` | 10 | Segnali di errore con arity attesa, save riuscito emette solo `success`, save manomesso messo in quarantena (non scartato in silenzio), ring backup conserva le generazioni precedenti, save da versione futura parcheggiato invece che applicato, uid autenticato senza riga non conia un account ospite mentre l'ospite continua ad averlo (V-021) |
| `test_i18n_assets.gd` | 16 | Entrambe le locale caricate + key set identico IT/EN che differiscono davvero, sprite reali per mess e badge, badge con icone e testo nelle due lingue, catalogo ambience punta a file reali, ogni mood band ha musica, texture del joystick presenti |
| `test_phase_f.gd` | 12 | Default e reset di ogni chiave persistita, `ambience_enabled` roundtrip save/load, save rifiutato prima del load e riabilitato dopo, play_time non doppio-contato al reload, reset profilo azzera i contatori a vita, loop ambience copre l'intero file + gestione id/risorse, character swap mantiene il nodo `Character` |
| `test_bridge.gd` | 21 | Lifecycle e triplo gate, parser HTTP (400/404/405/413), /status schema+valori, dispatch /command (mood/stress/save/language/panel), ring /events cap 200, /tree, /logs/tail, teardown stop() |
| `test_logger.gd` | 4 | Chiusura del file a teardown, redazione dei segreti anche dentro gli Array, normalizzazione dei path assoluti a `user://`, riga di console redatta come quella su file (V-022, ramo console) |
| `test_mood.gd` | 16 | Soglie dello slider umore: pioggia e scurimento sullo stesso numero (PLR-1), intensita` della pioggia che cresce col buio, banda musicale a 0.25 separata dalla banda ambience a 0.50, ambience per mood dal catalogo, ripristino delle ambience salvate |

**Totale**: 234 test, ~8s.

`test_bridge.gd` non usa una porta fissa: la risolve a runtime partendo dal PID
e sondando finche' non ne trova una libera, cosi` due run in parallelo non si
contendono lo stesso socket.

## Architettura

### Runner (`test_runner.gd`)

Reflection-based. Per ogni modulo in `TEST_MODULES`:

1. Preload + instanzia lo script
2. Aggiungi come figlio dell'albero test
3. 1 frame wait per setup
4. Trova tutti i metodi che iniziano con `test_` tramite `get_method_list()` e li **ordina alfabeticamente** (i prefissi `aa`/`zz` fissano quindi il primo/ultimo test nel modulo)
5. Per ogni test:
   - Reset contatori per-test (`_assertions_in_test`, `_failures_in_test`)
   - `await callable.call()` — supporta sia sync che async via `await` nativo Godot 4
   - Cattura failures + timing ms
   - Aggrega in totale + per-module stats
6. Scrive JSONL in `user://test_results.jsonl`
7. Print report + exit con code appropriato

### Base class (`integration/test_base.gd`)

Fornisce asserzioni standard:

- `assert_true(bool, msg)` / `assert_false(bool, msg)`
- `assert_eq(a, b, msg)` / `assert_ne(a, b, msg)`
- `assert_approx(float, float, epsilon=0.001, msg)` — per floating-point
- `assert_non_null(value, msg)` / `assert_null(value, msg)`
- `assert_in_range(value, low, high, msg)`
- `assert_array_size(arr, n, msg)`
- `assert_has(dict, key, msg)`
- `fail(msg)` — explicit failure
- `wait_frames(n)` / `wait_seconds(s)` — async helpers

Ogni asserzione incrementa `_assertions_in_test`; fallimenti appendono a
`_failures_in_test` (Array[String]). Runner legge questi dopo ogni test.

### Async patterns

Usa `await get_tree().process_frame` (1 frame) o `wait_frames(n)` per attendere
propagation scene-tree. Usa `Input.action_press` + `Input.action_release` per
simulare keyboard. Simulazione mouse via `Viewport.push_input` documentata come
**limitata in headless** (routing CanvasLayer inconsistente) — fallback a
`button.pressed.emit()` per testare il wiring.

## Note su limiti headless

`Viewport.push_input(InputEventMouseButton)` NON route affidabilmente ai Control
in `CanvasLayer` in headless. Godot community issue noto. I test `test_ui_events`
usano `pressed.emit()` per verificare il **wiring** (che è ciò che conta: se
questo funziona, in GUI i click reali routano correttamente attraverso la
CanvasLayer stack).

## CI integration

`.github/workflows/ci.yml` jobs:

- **smoke-headless** — boot Godot 4.7 headless, 0 parse/script error
- **deep-tests** — `bash scripts/deep_test.sh --timeout 90`, gated su
  smoke-headless. Il job **non** invoca mai Godot direttamente sul
  `test_runner.tscn`, e a fine run verifica che la user dir reale del runner
  (`$XDG_DATA_HOME/RelaxRoom`) non esista nemmeno: e` una prova d'isolamento
  eseguita ad ogni build, non una promessa

Artifact `/tmp/deep_ci.log` uploaded 14d retention per audit.

## Scrivere un nuovo test

1. Aggiungi file `integration/test_NOME.gd`:

   ```gdscript
   extends "res://tests/integration/test_base.gd"

   func test_my_case() -> void:
       assert_true(true, "sanity")

   func test_async_case() -> void:
       await wait_frames(2)
       assert_eq(1 + 1, 2)
   ```

2. Aggiungi il path in `TEST_MODULES` di `test_runner.gd`.

3. Non servono import/class_name — il runner usa preload + reflection.

4. Verifica locale:

   ```bash
   ./scripts/deep_test.sh | grep test_my_case
   ```

## Archivio: precedente iterazione con GdUnit4

Il progetto aveva originariamente 5 test suite (48 test) basati su GdUnit4 (suite
`test_helpers`, `test_logger`, `test_save_manager`, `test_save_manager_state`,
`test_shop_panel`). Rimosse il 29 Marzo 2026 durante semplificazione build.
La nuova harness custom (aprile 2026) è più invasiva — **129 sprite caricati,
scene full spawn, isteresi edge cases** — e non richiede dipendenze esterne.

## Vedi anche

- [README scripts](../scripts/README.md) — moduli testati
- `.github/workflows/ci.yml` — job `smoke-headless` + `deep-tests`
- `scripts/deep_test.sh`, `scripts/preflight.sh`, `scripts/godot-validate.sh` — tooling
- [AUDIT_REPORT 2026-04-23](../../AUDIT_REPORT_2026-04-23.md) — findings integrità + stabilità
