# Complexity Audit — Relax Room

**Files audited:** 36 GDScript | **Total LOC:** 7.372 | **Issues:** 14 | HIGH: 4 | MEDIUM: 7 | LOW: 3

> Nota: l'utente ha esplicitato "NO over-engineering". Le flag HIGH qui sono candidati **rimozione/inline**, non refactor astratto.

---

## 1. Accidental vs Essential Complexity

### `v1/scripts/autoload/supabase_client.gd` (464 righe)

* **Stato del modulo** — dichiarato nei docs "non operativo" (runtime agent conferma config ritorna false se mancante)
  **Category:** Dead Abstraction / Premature infrastructure
  **Severity:** HIGH — 464 righe di codice per feature NON USATA nella demo. Contraddice principio "no over-engineering"
  **Fix opzione A (pragmatica)**: commentare autoload + stub minimo 20 righe che risponde "offline always". Eliminare `supabase_mapper.gd`, `supabase_http.gd` dalla release demo
  **Fix opzione B (conservativa)**: lasciare ma **escluderlo dalla presentazione** come feature live; presentarlo solo come "pronto per futura attivazione"
  **Justification if intentional:** user vuole mostrare architettura predisposta. OK tenere, **ma togliere dal path attivo**

### `v1/addons/virtual_joystick/` + `v1/scenes/ui/virtual_joystick.tscn`

* **Scena esistente, non instantiata in `main.tscn`**
  **Category:** Dead abstraction
  **Severity:** HIGH — 509 righe addon + scene file per feature NON attiva (desktop app). Rischio concreto: user aggiunge accidentalmente la scena → addon preme `Input.action_press("ui_*")` → interferisce col focus chain → **riproduce B-001**
  **Evidence:** `CONSOLIDATED_PROJECT_REPORT.md` sez 13.2 identifica come "dead code rischioso"
  **Fix pre-demo:** rimuovere addon + scene. Salvare copia in `/media/renan/backup/` se serve in futuro per mobile port

### `v1/scripts/autoload/local_database.gd` (810 righe, 46 funzioni)

* **Violazione esplicita `max file: 500 righe` dichiarato in `CONSOLIDATED_PROJECT_REPORT.md` sez 9.2**
  **Category:** Cognitive Load / Invariant violation
  **Severity:** HIGH — 62% sopra limite
  **Fix pre-demo:** **NO split** (rischio rottura). Accettare come debito.
  **Fix post-demo:** split in `local_database.gd` (connection+migration) + `local_database_crud.gd` (CRUD per tabella)
  **Justification if intentional:** tenere monolitico semplifica debugging; split astratto aggiunge indirection senza valore immediato

### `v1/scripts/autoload/save_manager.gd` (523 righe, 23 funzioni)

* **4.6% sopra limite 500**
  **Category:** Cognitive Load
  **Severity:** MEDIUM
  **Fix:** accettabile; debito dichiarato

### `v1/scripts/systems/stress_manager.gd` + `mess_spawner.gd` + `game_hud.gd`

* **Sistema "stress + mess" aggiunto sprint recente** (commit `0a61d1b`, `177c9f1`, `ccfb370`)
  **Category:** Essential complexity (gameplay feature)
  **Severity:** — (pass)
  **Status:** NECESSARIO — e la feature cozy-plus che differenzia il gioco. Integrato con AudioManager mood → essential, non accidentale

---

## 2. Cognitive Load Assessment

### Funzioni potenzialmente >50 righe

* **`local_database._migrate_schema()`** (righe 242-299, ~57 righe)
  **Severity:** MEDIUM
  **Fix:** ogni migrazione come metodo separato `_migrate_v1_to_v2()`, `_migrate_v2_to_v3()`. Riduce nesting e rende rollback piu chiaro
  **Justification if intentional:** migration logic e raramente modificato post-release; accettabile inline

* **`save_manager._save_internal()`** — da stimare, probabile >50 righe per HMAC + atomic write
  **Severity:** MEDIUM
  **Status:** essential — logica correlata e atomica; split artifact

### Nesting depth

* **`supabase_client._handle_http_response`** — if/switch su status code con 5+ branch
  **Severity:** LOW — flat switch, readable
  **Status:** PASS

### Boolean parameters

* **`audio_manager.play_track(track_id, crossfade_duration, loop, shuffle_mode)`** — 4 parametri including boolean
  **Severity:** MEDIUM — "shuffle_mode" bool + "loop" bool insieme = 4 combinazioni. Nome `AudioPlayParams` Dictionary aiuterebbe
  **Fix:** accettabile se funzione chiamata pochi volte; splittare solo se >4 call sites

---

## 3. Unnecessary Indirection

### SignalBus

* **43 signal dichiarati ma solo 3 domini effettivamente distinti dal flow**
  **Category:** Indirection (event-driven architecture)
  **Severity:** — (pass)
  **Status:** PASS — e il pattern centrale dell'architettura, essenziale. Alternativa (direct calls) produrrebbe 43 dipendenze dirette invece che 1 bus

### `v1/scripts/utils/helpers.gd` (171 righe)

* **"Grab-bag" utility**
  **Category:** Balance
  **Severity:** MEDIUM
  **Evidence:** `snap_to_grid`, `clamp_inside_floor`, altre utility
  **Fix:** accettabile; split solo se cresce >300 righe

### `v1/scripts/utils/supabase_mapper.gd`

* **Mapper locale↔cloud**
  **Category:** Indirection
  **Severity:** HIGH — se SupabaseClient disattivato, mapper e dead code
  **Fix:** eliminare insieme a SupabaseClient (vedi sez. 1 opzione A)

---

## 4. Dead Abstractions

* **`local_database.gd:9` — `_last_select_error`** flag
  **Category:** Dead abstraction (dead variable)
  **Severity:** LOW — B-014 gia tracciato
  **Fix:** rimuovere variabile, sostituire con AppLogger.error immediato

* **`supabase_mapper.gd:103-136` — `cloud_to_local`** dead code (B-022)
  **Category:** Dead abstraction
  **Severity:** LOW
  **Fix:** eliminare

* **Constants dead**: `PLAYLIST_*`, `DISPLAY_*`, `LANGUAGES`
  **Evidence:** `CONSOLIDATED_PROJECT_REPORT.md` sez 11 debiti
  **Severity:** LOW
  **Fix:** grep usage → rimuovere unused

* **`settings` language UI** disabilitata
  **Severity:** LOW
  **Fix:** rimuovere codice UI di gestione language se non usato

---

## 5. Copy-Paste vs Abstraction Balance

### `room_base.gd` — 3 occorrenze `_find_item_data(item_id).is_empty(): return/continue`

* **Line 94-96, 125-127, 141-143** — pattern ripetuto 3 volte
  **Category:** Balance
  **Severity:** LOW — 3 istanze e soglia; MA se una (94-96) logga e altra (141-143) non logga, **divergenza** pericolosa (root cause B-002)
  **Fix:** estrai `_validate_item(item_id) -> Dictionary` che logga se empty e ritorna stesso dict. Caller fa `if data.is_empty(): return`. Riduce 3 punti a 1

### `supabase_client.gd` — pattern auth header building

* **`_auth_headers()`, `_bearer_headers()`, `_base_url()`** helper duplicati ma ok (ognuno 3-5 righe)
  **Severity:** — (pass)
  **Status:** OK, piccole helper dedicate, leggibili

---

## 6. Dependency Complexity

### Autoload god-module

* **`SignalBus`** — ogni altro autoload lo usa (tutti 9 importano)
  **Category:** God module by design
  **Severity:** — (pass)
  **Status:** PATTERN accettato e dichiarato come architettura centrale

### Circular dependencies

* **Nessuna rilevata** in lettura superficiale (explore agent). Autoload caricati in ordine stretto.

### SupabaseClient dependencies

* **SupabaseClient → AuthManager + SaveManager + LocalDatabase + Constants**
  **Category:** High coupling
  **Severity:** MEDIUM — se disabilitato (sez. 1), coupling ininfluente; se attivo, OK perche mapper layer unisce
  **Fix:** non agire pre-demo

---

## Sintesi top HIGH pre-demo

| # | Target | Fix | Tempo |
|---|---|---|---|
| 1 | `virtual_joystick` addon + scene | Rimuovere completamente (dead + rischio B-001) | 5 min |
| 2 | SupabaseClient se non attivo in demo | Disabilitare autoload o stub 20 righe | 20 min |
| 3 | `supabase_mapper.gd` se sopra | Eliminare | 5 min |
| 4 | `room_base._find_item_data` pattern | Extract helper con log | 10 min |

**Totale quick-win complessita pre-demo: ~40 min, riduce ~500+ righe dead code.**

### Post-demo backlog

- Split `local_database.gd` 810 → 2 file
- Rimuovere dead constants
- AudioPlayParams struct se call sites crescono

### Confronto con `CONSOLIDATED_PROJECT_REPORT.md`

- **Conferma** B-022, B-014, dead constants, settings language dead
- **Nuovo warning**: SupabaseClient non attivo ma 464 righe in tree = rischio mental-overhead + falsi-positivi nel debug
- **Nuovo warning**: virtual_joystick e **rischio attivo** per B-001 (puo essere accidentalmente aggiunto)
- **Smentisce implicit**: non serve rifare SignalBus con 43 signal — e architettura centrale giustificata

**Aggiornamento necessario**: SupabaseClient activate/disable flag esplicito + .tscn virtual_joystick eliminato dal repo.
