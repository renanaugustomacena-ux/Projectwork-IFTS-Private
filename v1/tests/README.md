# Relax Room — Test Harness

Custom headless test harness senza GdUnit4. **242 test** invasivi in **24 moduli**
(`grep -h '^func test_' v1/tests/integration/*.gd | wc -l` ·
`ls v1/tests/integration/test_*.gd | grep -v test_base | wc -l`),
~1-2 minuti di esecuzione, exit code 0 (all pass) / 1 (failures). Girano in
preflight locale + CI GitHub Actions su container `barichello/godot-ci` 4.7.1.

## Esecuzione

```bash
./scripts/deep_test.sh                 # unico modo supportato
./scripts/deep_test.sh --keep          # conserva la sandbox per ispezionarla
GODOT_BIN=/percorso/godot ./scripts/deep_test.sh
```

Exit code **0** = ALL PASS, **1** = ≥ 1 failure, **124** = timeout (120 s default),
**2** = errore d'harness (Godot assente, isolamento non attivo).

### Isolamento dal profilo giocatore (G-053)

**Non lanciare `godot4 --headless --path v1/ res://tests/test_runner.tscn` a
mano.** La suite scrive `save_data.json`, `save_data.backup*.json`,
`cozy_room.db` e `integrity.key` dentro `user://`; con
`use_custom_user_dir=true` + `custom_user_dir_name="RelaxRoom"` quella e` la
**stessa** directory che usa il gioco, quindi ogni run distruggerebbe i dati
reali del giocatore.

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
  lanciate insieme non si toccano.
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

Conteggio per file: `grep -c '^func test_' v1/tests/integration/test_<nome>.gd`.
Ordine = `TEST_MODULES` in `test_runner.gd`.

| Modulo | Test | Copertura |
|--------|------|-----------|
| `test_helpers.gd` | 16 | `Helpers.snap_to_grid`, `clamp_inside_floor`, floor polygon init, `format_time`, Vec2 roundtrip |
| `test_placement.gd` | 6 | Fascia muro derivata dal poligono, clamp dell'ancora a muro, normalizzazione `placement_type` (`any` ritirato), flag e limiti di scala, bande z_order, teardown |
| `test_catalogs.gd` | 22 | Ogni 129 deco sprite load + dimensions, sprite dei personaggi, tracce audio, sprite dei mess, temi, integrita` categorie + ID, un catalogo mancante resta in coda per la UI (V-019) |
| `test_stress.gd` | 12 | Isteresi 3 livelli (0.35/0.60 up, 0.25/0.50 down), clamp 0..1, integrazione mess spawn/clean, decay passivo, persist livello_stress int |
| `test_shop.gd` | 5 | Catalogo negozio caricato, acquisto scala le monete e da` l'oggetto, rifiuto senza monete, ciclo di consumo, progressione del moltiplicatore attrezzi |
| `test_cleaning.gd` | 5 | Ciclo completo paga al completamento, deadline passata al reload completa subito, deadline assurda clampata, attrezzo accorcia la pulizia, cap dei mess |
| `test_trust.gd` | 5 | Fasce di fiducia, guadagno a pasto solo con fame, persistenza + clamp, gatto diffidente scappa, gatto fidato no |
| `test_needs.gd` | 5 | Accumulo bisogni offline, registro zone giardino, clamp sull'unione pavimento+giardino, punto casuale dentro la zona, teardown |
| `test_slots.gd` | 4 | Mappatura `slot_path`, cambio slot isola lo stato, primo slot libero / qualsiasi slot, `peek` su slot vuoto |
| `test_seats.gd` | 3 | Sedersi aggancia all'ancora della sedia, muoversi su una sedia fissa fa alzare, guidare una sedia a rotelle la trascina |
| `test_save.gd` | 14 | HMAC-SHA256 deterministico, save/load roundtrip, HMAC manomesso → backup, migrazione v1/v3/v4 → v5, version compare, reset_all preserva pet_variant |
| `test_spawn.gd` | 11 | Room minimale, spawn di ogni 129 deco, nearest filter, anchor non centrato, scale/rotation/flip persistiti, SCALE_STEPS, clamp inside floor |
| `test_panels.gd` | 9 | Pannelli open/close, mutua esclusione, toggle-same chiude, Esc handler, `panel_opened/closed` |
| `test_input.gd` | 14 | WASD via `Input.action_press`, direzione della velocita`, diagonale normalizzata a 120, release azzera, animazione walk/idle + flip_h |
| `test_movement_bounds.gd` | 4 | Il personaggio raggiunge la parete di fondo e il bordo davanti senza uscire, scivola lungo la diagonale, teardown |
| `test_ui_events.gd` | 15 | `pressed.emit()` sui bottoni HUD apre il pannello giusto, DropZone resta PASS, DecoButton e` TextureRect, `_get_drag_data`, DecoButton con meta, nessun overlay che blocca |
| `test_crypto.gd` | 5 | PBKDF2-HMAC-SHA256 vs vettori RFC 8018, password vuota fail-closed, roundtrip v4, hash malformato rifiutato, salt unico |
| `test_save_failures.gd` | 10 | Segnali di errore con arity attesa, save riuscito emette solo success, save manomesso in quarantena, ring backup conserva le generazioni, versione futura parcheggiata, uid senza riga non conia un ospite (V-021) |
| `test_i18n_assets.gd` | 16 | Locale caricate + key set identico IT/EN, sprite reali per mess e badge, testi badge nelle due lingue, ambience su file reali, musica per ogni banda, texture del joystick |
| `test_phase_f.gd` | 12 | Default e reset di ogni chiave persistita, `ambience_enabled` roundtrip, save rifiutato prima del load, play_time non doppio-contato, reset profilo azzera i contatori, loop ambience, character swap mantiene `Character` |
| `test_bridge.gd` | 21 | Lifecycle e triplo gate, parser HTTP (400/404/405/413), /status, /command, ring /events cap 200, /tree, /logs/tail, teardown |
| `test_logger.gd` | 4 | Chiusura file a teardown, redazione dentro gli Array, path normalizzati a `user://`, console redatta come il file |
| `test_mood.gd` | 16 | Soglie del cursore: pioggia e scurimento sullo stesso numero (PLR-1), intensita` crescente, banda musica 0.25 separata da ambience 0.50, ambience dal catalogo, ripristino ambience salvate |
| `test_polish.gd` | 8 | Regressioni 1.3.0: lingua di sistema adottata come scelta esplicita, save "solo settings" non tocca la stanza, badge nel save dello slot, tetto password, prompt della SeatArea, formato tempo residuo, primo bisogno demo-friendly, segnali morti assenti |

**Totale**: 242 test in 24 moduli, ~1-2 min (il tempo dipende da quanti frame
attendono i test di movimento e pulizia, non dal numero di assert).

`test_bridge.gd` non usa una porta fissa: la risolve a runtime partendo dal PID
e sondando finche` non ne trova una libera, cosi` due run in parallelo non si
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
usano `pressed.emit()` per verificare il **wiring** (che e` cio` che conta: se
questo funziona, in GUI i click reali routano correttamente attraverso la
CanvasLayer stack).

## CI integration

`.github/workflows/ci.yml` jobs:

- **smoke-headless** — boot Godot 4.7.1 headless, 0 parse/script error
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

5. Aggiorna la tabella qui sopra e i conteggi nei README: `ci/validate_doc_counts.py`
   fallisce se i numeri dichiarati divergono da quelli misurati.

## Archivio: precedente iterazione con GdUnit4

Il progetto aveva originariamente 5 test suite (48 test) basati su GdUnit4.
Rimosse il 29 Marzo 2026 durante semplificazione build. La harness custom
(aprile 2026) e` piu` invasiva — **129 sprite caricati, scene full spawn,
isteresi edge cases, input simulato** — e non richiede dipendenze esterne.

## Vedi anche

- [README scripts](../scripts/README.md) — moduli testati
- `.github/workflows/ci.yml` — job `smoke-headless` + `deep-tests`
- `scripts/deep_test.sh`, `scripts/preflight.sh`, `scripts/godot-validate.sh` — tooling
- [CHANGELOG 1.3.0](../../CHANGELOG.md) — stato corrente e limiti noti
