# Deep Read Registry — Relax Room (2026-04-16)

Sintesi finale dopo lettura **integrale** di: CONSOLIDATED_PROJECT_REPORT.md (3195 righe), 6 guide v1/guide/, 10 study doc + README, 37 GDScript (~7881 LOC), 17 .tscn, 9 asset README, 5 data JSON catalog.

Questo documento consolida tutti gli schemi di task ID usati nel progetto + discrepanze emerse dal cross-check codice vs doc.

---

## 1. Schemi ID in Uso (7 sistemi paralleli)

| Prefisso | Fonte | Significato | Range Attivo |
|---|---|---|---|
| `B-NNN` | CONSOLIDATED_PROJECT_REPORT §2 | Bug tracker unificato | B-001..B-033 |
| `A-NN` | Audit v2.0.0 originale | Problemi audit code review | A1..A29 |
| `C-N` | Audit v2.0.0 critical fixes | Correzioni CRITICAL | C5, C6, C7 |
| `N-XX-N` | GUIDA_CRISTIAN_CICD | Nuovi task build/quick | N-BD1..5, N-Q1..5, N-AR7 |
| `T-R-NNN` | OPEN_TASKS.md | Task assegnati Renan | T-R-001..015 (+ 015a..i) |
| `T-E-NNN` | OPEN_TASKS.md | Task Elia | T-E-001..007 |
| `T-C-NNN` | OPEN_TASKS.md | Task Cristian | T-C-001..003 |
| `T-X-NNN` | OPEN_TASKS.md | Task cross-team | T-X-001..013 |
| `F1..F11` | CONSOLIDATED §15 | Fix plan ordinato | F1..F11 |
| `PR 1..3` | GUIDA_RENAN_GAMEPLAY_UI | PR roadmap | PR 1-3 |

**Mapping principale**: Ogni `B-NNN` ha un `T-R/E/C/X-NNN` corrispondente in OPEN_TASKS.md. I `C-N` + `A-NN` sono stati in gran parte assorbiti dai Task 1-21 delle guide.

---

## 2. Discrepanze Codice vs Documentazione (scoperte deep read)

### 2.1 SignalBus — conteggio segnali

| Fonte | Claim | Reale |
|---|---|---|
| pptx slide "33 segnali" | 33 | ❌ |
| study doc PROJECT_DEEP_DIVE | 21 | ❌ |
| presentazione_progetto.md | 31 | ❌ |
| CONSOLIDATED_REPORT §23 | 41 | ❌ |
| **signal_bus.gd actual** | **46** | ✅ |

**Breakdown reale** (signal_bus.gd:5-80): Room 4 + Character 5 + Audio 4 + Decoration-mode 5 + UI 3 + Save/Load 3 + Settings 4 + Auth 5 + Cloud 4 + Stress/Mood 3 + Mess 2 + Economy 1 + ProfileHUD 3 = **46**.

### 2.2 Save version

- Study doc PROJECT_DEEP_DIVE:482 → "v4.0.0"
- **save_manager.gd:9 → `SAVE_VERSION := "5.0.0"`**
- Migration chain completa: v1→v2→v3→v4→v5 con erase obsolete fields + add account section.

### 2.3 SQLite Tables

Study doc afferma "7-8 tabelle". **local_database.gd create_tables() definisce 9**:
1. `accounts` (account_id, auth_uid UNIQUE, display_name, password_hash, data_di_nascita, mail, coins, inventario_capacita, updated_at, deleted_at post-migration)
2. `inventario` (item_id, quantita, item_type, is_unlocked, acquired_at post-migration)
3. `characters` (nome, genere, colore_occhi/capelli/pelle, livello_stress)
4. `rooms` (room_type, theme, decorations JSON string)
5. `sync_queue` (table_name, operation, payload, retry_count)
6. `settings` (master/music/**sfx**_volume, display_mode, language, ui_scale)
7. `save_metadata` (save_version, save_slot, play_time_sec)
8. `music_state` (current_track_id, track_position_sec, playlist_mode, ambience_enabled, active_ambiences)
9. `placed_decorations` (room_id FK, catalog_id, pos_x/y, rotation_deg, flip_h, item_scale, z_order, placement_zone)

+ 7 indices su FK.

### 2.4 Settings schema incoerente (save_manager.gd vs local_database.gd)

| Chiave | SaveManager default | SQLite default | Note |
|---|---|---|---|
| `language` | `"en"` | `"it"` | ⚠️ divergenza default |
| `master_volume` | 0.8 | 1.0 | ⚠️ |
| `music_volume` | 0.6 | 0.8 | ⚠️ |
| `ambience_volume` | 0.4 | **non esiste** | ❌ |
| `sfx_volume` | **non esiste** | 0.8 | ❌ |
| `pet_variant` | `"simple"` | **non esiste** | ⚠️ |
| `ui_scale` | **non esiste** | 1.0 | ⚠️ |
| `display_mode` | `"windowed"` | `"windowed"` | ✅ |
| `mini_mode_position` | `"bottom_right"` | **non esiste** | ⚠️ |

**Conseguenza**: dual-write JSON→SQLite perdera' `ambience_volume`, `pet_variant`, `mini_mode_position`.

### 2.5 Bug latente — reset_all() perde pet_variant

`save_manager.gd:447-454` resetta `_settings` a 7 chiavi ma omette `"pet_variant"` (presente nel default iniziale riga 30). Dopo Delete Account il pet torna "simple" silenziosamente anche se utente aveva scelto "iso".

### 2.6 Dual-save incompleto (B-016 confermato)

`save_manager.gd:_save_to_sqlite` emette `save_to_database_requested` SOLO con `character` + `inventory`. Non persiste a SQLite: room_decorations, settings, music_state, placed_decorations. Solo JSON e source of truth.

### 2.7 Scene mancante — loading_screen.tscn

`main_menu.gd:8 LOADING_SCREEN_SCENE := "res://scenes/menu/loading_screen.tscn"` ma il file non esiste tra i 17 .tscn del progetto. `ResourceLoader.exists()` ritorna false → **fallback sempre al Label "Caricamento..." procedurale** (righe 72-81). Asset `assets/menu/loading/*.png` (background, title, bars, people) mai mostrati.

### 2.8 Character catalog — 2 personaggi effettivi

- `data/characters.json` → `male_old` + `female`
- `constants.gd:14-15` → ha `CHAR_MALE := "male"` e `CHAR_FEMALE := "female"` — **`CHAR_MALE` orfano** (nessun personaggio in catalog)
- `character_select.gd:10-21` → solo 2 entry
- `room_base.gd:13 CHARACTER_SCENES` → solo 2 scene
- `menu_character.gd:14 WALKABLE_CHARACTERS` → 1 sola hardcoded (male_old), nonostante comment dica "random pick"

### 2.9 Audio catalog — 2 tracce totali

`data/tracks.json` ha solo `rain_loop` + `rain_thunder`. `ambience: []` vuoto. Il playlist shuffle con 2 tracce alterna solo queste due. Tutti riferimenti a "catalog musicale ampio" nelle slide sono overstated.

### 2.10 Dead UI — Tree widget in main.tscn

`scenes/main/main.tscn:67` definisce un `Tree` type="Tree" dentro `UILayer/DropZone`. Nessuno script lo referenzia. Residuo dead UI.

### 2.11 Duplicati menu assets

`assets/menu/` README sez 56-62 conferma 6 file PNG root-level duplicati di quelli in `ui/` con dimensioni diverse (es. `sprite_pad_base.png` 52x52 vs 42x41). Scene puntano ai root; i `ui/` sono alternative senza .import.

### 2.12 Mess sprites non usati

`assets/room/mess/floor_mess1-3.png` esistono ma `mess_catalog.json` usa `sprite_path: ""` per tutte le 6 entry → runtime fallback a `_make_placeholder_texture` (cerchi colorati procedurali). Sprite reali mai caricati.

### 2.13 Settings language — nascosto in UI

`settings_panel.gd:58 lang_row.visible = false` — selettore lingua **nascosto intenzionalmente** finche' .po files non pronti (T-R-015g). Solo il toggle in profile_hud_panel e' visibile all'utente.

### 2.14 Supabase sync — coverage parziale

`supabase_client.gd:_push_local_state` copre 5 tabelle cloud:
- `profiles` ✅
- `user_currency` ✅
- `user_settings` ✅
- `music_preferences` ✅
- `room_decorations` ✅ (delete+upsert)

Non coperte: inventory items (mapper esiste ma non chiamato), characters_cloud, audit_log, journal_entries, pomodoro_sessions, mood_entries, memos, notifications (8 tabelle Elia predisposte ma dormienti per demo).

### 2.15 Costanti numeriche cross-check

Tutti verificati integralmente vs codice:

| Valore | Fonte | Codice |
|---|---|---|
| FPS focused | 60 | `constants.gd:35` ✅ |
| FPS unfocused | 15 | `constants.gd:36` ✅ |
| Auto-save interval | 60s | `save_manager.gd:10` ✅ |
| Grid cell | 64px | `room_grid.gd:5`, `helpers.gd:64` ✅ |
| Viewport | 1280x720 | `constants.gd:56-57` ✅ |
| Wall zone ratio | 0.4 | `room_grid.gd:7`, `drop_zone.gd:5` ✅ |
| Parallax strength | 8.0 | `window_background.gd:5` ✅ |
| Auth lockout | 300s | `constants.gd:47` ✅ |
| PBKDF2 iter | 10000 | `auth_manager.gd:7` ⚠️ (B-029 open) |
| Supabase sync interval | 120s | `constants.gd:51` ✅ |
| Logger buffer max | 2000 | `logger.gd:15` ✅ (B-018 fixed) |
| Supabase queue max | 500 | `supabase_http.gd:9` ✅ (B-025 fixed) |
| SQLite busy_timeout | 5000ms | `local_database.gd:95` ✅ (B-026 fixed) |
| HMAC key size | 32 bytes | `save_manager.gd:475` ✅ |
| Character SPEED | 120 | `character_controller.gd:4` ✅ |
| Pet follow dist | 120 | `pet_controller.gd:9` ✅ |
| Pet sleep cooldown | 120s | `pet_controller.gd:14` ✅ |
| Stress thresholds up | 0.35/0.60 | `stress_manager.gd:14-15` ✅ |
| Stress decay | 2%/min | `stress_manager.gd:20` ✅ |
| Mess spawn interval | 60-180s | `mess_spawner.gd:12-13` ✅ |
| Mess max concurrent | 5 | `mess_spawner.gd:14` ✅ |
| Toast max visible | 3 | `toast_manager.gd:6` ✅ |
| Decorations total | 69 | `data/decorations.json` ✅ (13 cat, 1 hidden) |

---

## 3. Patch critiche da applicare pre/post demo

### PRE-DEMO (P0, 22 Apr 2026)

1. **Allineare `settings_panel.gd._load_settings` vs `local_database.gd upsert_settings`** — oggi divergono su chiavi (ambience vs sfx). Decidere: SaveManager canonical, DB mirror.
2. **Fixare reset_all() per preservare pet_variant** (2 min — aggiungere chiave al dict di reset).
3. **Creare o eliminare `loading_screen.tscn`** — attualmente il path e' fantasma. Scelta: (a) creare scena vera con assets menu/loading/*, (b) rimuovere costante LOADING_SCREEN_SCENE + fallback explicit.
4. **Allineare signal count documentazione → 46** in: pptx (31→46), presentazione_progetto.md (31), CONSOLIDATED §23 (41).

### POST-DEMO (debito raccolto)

5. **B-016 dual-write completo** — aggiungere upsert per rooms, settings, music_state, placed_decorations (T-E-001 + T-R-003).
6. **Rimuovere `CHAR_MALE` orfano** o aggiungere 3° personaggio.
7. **Rimuovere Tree widget dead** in main.tscn DropZone.
8. **Popolare sprite_path nel mess_catalog.json** invece di placeholder runtime (o riconoscere scelta intenzionale in un commit msg).
9. **Consolidare duplicati assets/menu root vs ui/**.
10. **Aggiungere 2+ tracce al catalog musicale** per giustificare playlist shuffle.
11. **Refactor save_manager→local_database settings schema** con source of truth unica.

---

## 4. Bug tracker status (post deep read)

### Fixed in sprint 2026-04-16/17 (confermato dal codice)

- B-001 ✅ (focus_mode=FOCUS_NONE su Button + ProgressBar; gui_release_focus; idempotency guard in `_on_character_changed`)
- B-002 ✅ (DecoButton subclass con `_get_drag_data` override)
- B-003 ✅ (WallRect+FloorRect mouse_filter=IGNORE)
- B-005 ✅ (Shift disable snap in deco + drop_zone)
- B-006 ✅ (pet FSM WANDER transition fixed)
- B-007 ✅ (tutorial replay via reload_current_scene)
- B-008 ✅ (volume slider persist via settings_updated)
- B-009 ✅ (profile panel disconnect in _exit_tree)
- B-010 ✅ (profile coins via signal, no polling)
- B-011 ✅ (toast methods, not lambdas)
- B-012 ✅ (MessNode _exit_tree disconnect)
- B-013 ✅ (MessSpawner timer stop + disconnect)
- B-014 ✅ (_last_select_error removed)
- B-015 ✅ (migration 1 backup characters_bak+inventario_bak pre-DROP)
- B-018 ✅ (MAX_BUFFER_ENTRIES=2000 in logger, fallback 100 retained)
- B-019 ✅ (ConfigFile.save_encrypted_pass with device-derived key)
- B-020 ✅ (HTTPS enforcement in supabase_config.gd)
- B-025 ✅ (MAX_QUEUE_SIZE=500 con drop oldest)
- B-026 ✅ (PRAGMA busy_timeout=5000)
- B-027 ✅ (AppLogger.error in `_select`)
- B-028 ✅ (REDACT_KEYS + `_redact_context`)
- B-031 ✅ (.pre-commit-config stub + linter focus_mode)

### Still open (post-demo)

- B-004 P2 — grid investigation GUI
- B-016 P1 — dual-write JSON/SQLite completo (parzialmente fixato)
- B-021 P2 — Supabase rate-limit exp backoff
- B-022 P3 — cloud_to_local dead code decision
- B-023 P3 — virtual_joystick USE/REMOVE
- B-024 P3 — CI linter `Button.new()` focus_mode check
- B-029 P1 — PBKDF2 10000→100000 migration
- B-030 P3 — RNG determinism debug seed
- B-032 P1 — Supabase DDL in `supabase/migrations/`
- B-033 P3 — split `local_database.gd` 831 righe

### T-R-015 Profile+Mood HUD cluster

- a ✅ icona HUD scaffold
- b ✅ mini panel scene+script scaffold
- c ⏸ profile image FileDialog
- d ⏸ badge system + catalog SQLite
- e ✅ settings button inside panel
- f ✅ lang toggle visual
- g ⏸ i18n .po files
- h ✅ mood slider signal emit
- i ⏸ MoodManager + visual/audio effects

---

## 5. Invariants codificati (non violare)

1. **Godot 4.6 obbligatorio**. project.godot dichiara features "4.6". Runtime 4.5.2 fallira' import.
2. **Floor polygon e' source of truth della stanza**. Clampare contro viewport e' deprecato (`helpers.gd:39-53`).
3. **Decorazioni sono Sprite2D NON centrato**. Anchor e' bottom-center per floor logic (`decoration_system.gd:77-82`).
4. **Collision footprint 70% width × 30% height**, bottom-center (`room_base.gd:8-9`).
5. **SaveManager e' source of truth settings**. SQLite e' mirror cloud-push-friendly (non leggere da SQLite per runtime).
6. **HMAC-SHA256 con chiave device-local in `user://integrity.key`**. Cambiare path rompe save integrity.
7. **Focus chain**: Button default FOCUS_ALL intercetta `ui_*` → blocca movement. Tutti i Button creati via script devono avere `focus_mode = FOCUS_NONE`.
8. **`class_name` cache di Godot e' inaffidabile al reload**. Usare `preload("path.gd")` + confronto `get_script()`, non `is ClassName`.
9. **Pattern drag Button in Godot 4.5+**: sottoclassare con override `_get_drag_data` virtuale. `set_drag_forwarding` NON funziona su Button.
10. **Signal listener reset su scene reload**: lambda con capture diventano zombie se SignalBus e' autoload. Usare metodi membri.

---

## 6. Scope finale demo 22 Apr 2026

**Features attive e stabili**:
- Room cozy studio con 3 temi colore + drag-drop decorazioni (69 catalog + snap 64px + shift fine placement)
- 2 personaggi (male_old + female) selectable + walk animation 8 direzioni
- Pet FSM 5 stati con wander/follow/sleep/play
- Mess system stress 0..1 → mood calm/neutral/tense con isteresi + audio crossfade
- Audio 2 tracce crossfade 2s, ambience-ready (vuoto)
- Save HMAC + atomic write + backup, migration chain v1..v5
- Auth locale v2 PBKDF2 10k + guest mode + lockout 5 attempts/5min
- Tutorial 9 steps scriptato
- Toast notifications 3 visible max
- Profile HUD mini-panel (scaffold visuale)
- Logger JSONL rotating 5MB×5

**Features scaffold/placeholder**:
- Supabase sync (config missing by default → offline-only)
- Badge system (UI placeholder)
- i18n (hidden language selector)
- Mood visual effects (signal emitted, no visual processing yet)

**Features tagliate pre-demo**:
- Shop / negozio monete
- Pomodoro / journal / memo
- Second character walk-in animation (menu hardcoded 1)
- Mess real sprites (placeholder cerchi)
- Loading screen grafica (Label fallback)

---

## 7. File letti integralmente (audit completato)

| Categoria | File | Righe |
|---|---|---|
| Report | CONSOLIDATED_PROJECT_REPORT.md | 3195 |
| Guide | 6 file v1/guide/ | ~5000 |
| Study | 10 doc + README | ~5900 |
| Script | 37 gd (autoload + rooms + ui + menu + utils + systems) | 7881 |
| Scenes | 17 .tscn | 1794 |
| Data | 5 catalog JSON | 257 |
| Asset README | 9 README | ~1200 |
| **Totale** | **~84 file** | **~25227 righe** |

---

*Generato 2026-04-16 come deep read finale pre-demo 22 Apr 2026.*
