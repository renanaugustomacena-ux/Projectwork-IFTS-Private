# Correctness Audit — Relax Room

**Files audited:** 31 GDScript files (v1/scripts/) | **Issues:** 16 | CRITICAL: 2 | HIGH: 6 | MEDIUM: 5 | LOW: 3

> Nota GDScript: non ha `try/except`. Il pattern equivalente a "silent failure" e `return {}`/`return null` senza `AppLogger.error/warn/info` precedente. Ho applicato questo adattamento.

---

## 1. Silent Failure Detection

### `v1/scripts/autoload/local_database.gd`

* **Line 803-805, 807-809** — `_select()` ritorna `[]` su query fail SENZA log
  **Category:** Silent Failure
  **Severity:** CRITICAL — Query SQL fallita e invisibile, `_last_select_error` flag settato ma mai letto da caller
  **Fix:** aggiungere `AppLogger.error("LocalDatabase", "select_failed", {sql: sql.left(80), bindings: bindings})` prima di `return []`. Rimuovere `_last_select_error` dead var (B-014)

* **Line 518-519** — `get_room()` ritorna `{}` su row-not-found
  **Category:** Silent Failure (acceptable case)
  **Severity:** LOW — caso normale "no room", non errore. Caller deve `if result.is_empty(): create_new()`
  **Fix:** nessuno; documentare semantica "empty = not found" in docstring

### `v1/scripts/rooms/room_base.gd`

* **Line 94-96** — `_on_decoration_placed` silent return se item_data empty (**B-002 root cause confermato**)
  **Category:** Silent Failure
  **Severity:** CRITICAL — utente trascina decorazione, sprite sparisce, nessun log, nessun toast
  **Fix:**
  ```gdscript
  if item_data.is_empty():
      AppLogger.warn("RoomBase", "decoration_unknown", {"item_id": item_id})
      SignalBus.toast_requested.emit("Decorazione sconosciuta: %s" % item_id, "error")
      return
  ```

* **Line 141-143** — `_spawn_decoration` silent return
  **Category:** Silent Failure
  **Severity:** HIGH — duplica B-002 pattern nel path restore-from-save
  **Fix:** stesso pattern con log (toast solo se trigger UI, non su restore)

* **Line 144-145** — `sprite_path.is_empty()` silent return
  **Category:** Silent Failure
  **Severity:** HIGH — catalogo corrotto, sprite_path mancante, utente non avvertito
  **Fix:** `AppLogger.error("RoomBase", "sprite_path_empty", {"item_id": item_id})`

* **Line 242-245** — `_get_texture` ritorna null senza log su empty path
  **Category:** Silent Failure
  **Severity:** MEDIUM — duplica sopra, stessa causa
  **Fix:** log + return null OK

### `v1/scripts/autoload/supabase_client.gd`

* **Line 195-197, 305** — multiple `return false` su config mancante / auth failure
  **Category:** Silent Failure
  **Severity:** MEDIUM — alcuni hanno log (gia verificato), altri no; verificare line-by-line post-demo
  **Fix:** audit granulare ogni `return false`

### `v1/scripts/autoload/auth_manager.gd`

* **Line 33, 68, 114** — return `{}`/`false` su validation fail
  **Category:** Silent Failure (partial)
  **Severity:** LOW — AuthManager emette `auth_error` signal con messaggio; OK se UI ascolta
  **Fix:** verificare tutti i path hanno signal emit prima di return

---

## 2. Hidden Side Effects

### `v1/scripts/autoload/signal_bus.gd`

* **Intero file** — solo dichiarazioni signal, nessun `_ready()` con side effect
  **Severity:** — (pass)
  **Status:** Autoload pulito, zero mutazione stato globale

### `v1/scripts/autoload/save_manager.gd`

* **Auto-save timer** — connette a `_on_auto_save` senza disconnect in `_exit_tree` (B-017)
  **Category:** Side Effect / Resource Leak
  **Severity:** LOW — autoload sempre vivo, non pratico rilevante
  **Fix:** aggiungere `_auto_save_timer.timeout.disconnect(_on_auto_save)` per simmetria

### `v1/scripts/autoload/performance_manager.gd`

* **NOTIFICATION_WM_CLOSE_REQUEST** — emette `settings_updated` DOPO save, non bloccante
  **Category:** Side Effect on teardown
  **Severity:** MEDIUM — race: SaveManager potrebbe non flushare window_pos prima del kill
  **Fix:** chiamare `SaveManager.save_game()` sincrono in NOTIFICATION_WM_CLOSE_REQUEST prima di emit

---

## 3. Non-Determinism

### `v1/scripts/rooms/pet_controller.gd`

* **Line 57** — `var roll := randf()` per FSM transitions **SENZA SEED**
  **Category:** Non-Determinism
  **Severity:** HIGH — bug pet state-transition non riproducibili; impossibile scrivere test deterministico
  **Fix:** usare `RandomNumberGenerator` instance con seed persistente; in debug build `_rng.seed = 42`

### `v1/scripts/autoload/audio_manager.gd`

* **Line 56** — `_mood_rng.randomize()` — seeding time-based
  **Category:** Non-Determinism
  **Severity:** MEDIUM — crossfade mood audio non riproducibile
  **Fix:** accept per gameplay (desiderato), OK mantenere

* **Line 136** — `randi() % tracks.size()` (global RNG)
  **Category:** Non-Determinism
  **Severity:** MEDIUM — shuffle track non riproducibile
  **Fix:** usare `_mood_rng` locale per consistency

### `v1/scripts/systems/mess_spawner.gd`

* **Line 24** — `_rng.randomize()` time-based
  **Category:** Non-Determinism
  **Severity:** MEDIUM — bug mess positioning non riproducibili
  **Fix:** seed configurabile per debug

### Iterazione ordering

* **Catalog JSON iteration** — `GameManager.decorations_catalog.get("decorations", [])` (Array, stabile) ✓
* **Dictionary iteration** — GDScript Dictionary preserva insertion order (Godot 4.x) ✓
  **Status:** Pass su questo front

---

## 4. State Transition Integrity

### `v1/scripts/autoload/auth_manager.gd`

* **Enum AUTH_STATE** — LOGGED_OUT / GUEST / AUTHENTICATED tipizzato
  **Status:** PASS — transizioni esplicite

* **Transizione invalida** — login da AUTHENTICATED verso GUEST?
  **Category:** State Transition
  **Severity:** MEDIUM — non chiaro se `logout()` rejecta da stato non-AUTHENTICATED
  **Fix:** aggiungere guard `if _state != AUTHENTICATED: return false` esplicito

### `v1/scripts/rooms/pet_controller.gd`

* **FSM 5 stati** — IDLE / WANDER / FOLLOW / SLEEP / PLAY con `enum State` tipizzato
  **Status:** PASS — post-fix commit 8ff9613

### `v1/scripts/autoload/supabase_client.gd`

* **Connection state** — ONLINE/OFFLINE/CONNECTING (enum)
  **Category:** State Transition
  **Severity:** LOW — transizioni non documentate in diagramma; deducibili da codice
  **Fix:** documentare in `GUIDE_RENAN_SUPERVISOR.md` state diagram

### Zombie cleanup

* **Sync queue** — entry con retry_count >= 5 rimossa in `supabase_client.gd:338-339` ✓
* **Save backup** — primary corrotto → backup usato; se entrambi corrotti → default ✓
* **Tutorial progress** — reset via `rm save_data.json`; nessun cleanup automatico di tutorial stato-intermedio
  **Severity:** LOW
  **Fix:** accettabile per tutorial breve

---

## 5. Unreachable Error Paths

### `v1/scripts/autoload/local_database.gd`

* **Line 9, 797-809** — `_last_select_error` variable settata in 4 punti, **mai letta** (B-014)
  **Category:** Unreachable (dead var)
  **Severity:** LOW
  **Fix:** rimuovere variabile; sostituire con log immediato (vedi CRITICAL in sez. 1)

### `v1/scripts/rooms/room_base.gd`

* **Line 125-127** — `push_warning` + `continue` su item unknown durante restore save
  **Category:** Correct error path (not unreachable)
  **Severity:** — (pass) — pattern CORRETTO da replicare alle righe 94-96, 141-143

---

## Sintesi top CRITICAL/HIGH pre-demo

| # | File | Line | Severity | Fix time |
|---|---|---|---|---|
| 1 | `local_database.gd` | 803-809 | CRITICAL | 10 min — log query fail |
| 2 | `room_base.gd` | 94-96 | CRITICAL | 5 min — log + toast (B-002 root cause) |
| 3 | `room_base.gd` | 141-143 | HIGH | 5 min — log |
| 4 | `room_base.gd` | 144-145 | HIGH | 3 min — log |
| 5 | `pet_controller.gd` | 57 | HIGH | 15 min — RNG seed (opzionale pre-demo) |
| 6 | `auth_manager.gd` | 33, 68, 114 | HIGH | 15 min — audit path-by-path |

### Post-demo backlog

- Audio RNG consistency (locale vs global)
- FSM guards espliciti su transizioni invalide
- Timer disconnect simmetrici
- Documentare enum transitions in diagramma

### Confronto con `CONSOLIDATED_PROJECT_REPORT.md`

- **Conferma B-002** root cause `_find_item_data` silent return
- **Smentisce B-014** — `_execute()` (righe 776-793) **logga** errori; e `_select()` (796-810) che e silent
- **Nuovo**: Non-determinism random non tracciato nel bug register

**Aggiornamento necessario**: B-014 riclassificato — target corretto e `_select()`, non `_execute()`.
