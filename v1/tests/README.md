# Relax Room — Test Harness

Custom headless test harness senza GdUnit4. **112 test invasivi** in 8 moduli,
~7 secondi di esecuzione, exit code 0 (all pass) / 1 (failures). Girano in
preflight locale + CI GitHub Actions su container `barichello/godot-ci:4.6`.

## Esecuzione

```bash
# Shell wrapper con output formattato
./scripts/deep_test.sh

# Diretto via Godot
godot4 --headless --path v1/ res://tests/test_runner.tscn
```

Exit code **0** = ALL PASS, **1** = ≥ 1 failure, **124** = timeout (90s default).
Ogni run produce `user://test_results.jsonl` con log per-test.

## Moduli

| Modulo | Test | Copertura |
|--------|------|-----------|
| `test_helpers.gd` | 16 | `Helpers.snap_to_grid`, `clamp_inside_floor`, floor polygon init, `format_time`, Vec2 roundtrip |
| `test_catalogs.gd` | 21 | Ogni 129 deco sprite load + dimensions, 25 char sprite (idle/walk/interact/rotate), 2 audio track, 6 mess placeholder color, 3 theme hex, category + ID integrity |
| `test_stress.gd` | 12 | Isteresi 3 livelli (0.35/0.60 up, 0.25/0.50 down), clamp 0..1, mess signal integration (spawn/clean), decay passivo, persist livello_stress int |
| `test_save.gd` | 13 | HMAC-SHA256 deterministic + length, save/load roundtrip, tampered HMAC → backup fallback, migrazione v1/v3/v4 → v5, version compare, reset_all preserve pet_variant |
| `test_spawn.gd` | 11 | Minimal Room instance, spawn ogni 129 deco (no failure), nearest texture filter, non-centered anchor, scale/rotation/flip persist in deco_data, SCALE_STEPS cycling, clamp inside floor |
| `test_panels.gd` | 9 | 4 panel open/close (deco, settings, profile, profile_hud), mutual exclusion, toggle-same chiude, Esc handler, SignalBus panel_opened/closed fire |
| `test_input.gd` | 14 | WASD via `Input.action_press`, velocity direction corretta, diagonal normalizzata a SPEED=120, release azzera velocity, animazione walk/idle direzionale + flip_h |
| `test_ui_events.gd` | 16 | `pressed.emit()` per HUD buttons apre panel corretto, DropZone stays PASS anche con panel aperto, DecoButton is TextureRect (NOT Button), `_get_drag_data` non-null con valid meta, ≥60 DecoButtons con drag_data meta dentro panel, no overlay blockers upper-right quadrant |

**Totale**: 112 test, ~7s.

## Architettura

### Runner (`test_runner.gd`)

Reflection-based. Per ogni modulo in `TEST_MODULES`:

1. Preload + instanzia lo script
2. Aggiungi come figlio dell'albero test
3. 1 frame wait per setup
4. Trova tutti i metodi che iniziano con `test_` tramite `get_method_list()`
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

- **smoke-headless** — boot Godot 4.6 headless, 0 parse/script error
- **deep-tests** — `test_runner.tscn`, 90s timeout, gated su smoke-headless

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
- [GUIDA_CRISTIAN_CICD.md](../guide/GUIDA_CRISTIAN_CICD.md) — CI jobs + test integration
- `scripts/deep_test.sh`, `scripts/preflight.sh`, `scripts/godot-validate.sh` — tooling
