# Relax Room — Script GDScript

**49 script GDScript** (~8,732 LOC) organizzati per dominio + `main.gd` root controller.
Architettura **signal-driven**: tutta la comunicazione cross-modulo passa per
`SignalBus` (**48 segnali typed**). Nessun sistema conosce gli altri direttamente.

## Convenzioni

- **Linguaggio codice**: inglese (variabili, funzioni, commenti inline)
- **Documentazione**: italiano
- **Stile**: `gdtoolkit` v4 (max-line 120, max-function 50, max-file 500)
- **Pattern**:
  - Signal-driven via SignalBus (`SignalBus.xxx.connect` in `_ready`, `disconnect` in `_exit_tree`)
  - Catalog-driven (contenuto in `data/*.json`, zero hardcoding)
  - Offline-first (JSON primary, SQLite mirror, Supabase opzionale)
  - Focus chain: Button non-keyboard-navigable → `focus_mode = FOCUS_NONE`

## Struttura directory

```
scripts/
├── autoload/                       # 10 core singleton caricati da project.godot
│   ├── signal_bus.gd                #   48 segnali typed globali
│   ├── logger.gd                    #   JSONL rotating 5MB×5, crypto session ID
│   ├── local_database.gd            #   SQLite WAL facade, 9 tabelle, delega ai 9 repo
│   ├── auth_manager.gd              #   Guest + user/pass iterated-SHA-256 v3
│   ├── game_manager.gd              #   Stato di gioco + catalog loading JSON
│   ├── save_manager.gd              #   Save JSON v5 + HMAC + backup atomic
│   ├── supabase_client.gd           #   REST cloud sync HTTPS-only, session encrypt
│   ├── audio_manager.gd             #   Dual-player crossfade 2s, mood-driven switch
│   ├── mood_manager.gd              #   Overlay gloomy + rain + pet WILD FSM
│   └── badge_manager.gd             #   Badge catalog + SQLite table badges_unlocked
├── autoload/database/              # 9 repo modulari (B-033 split)
│   ├── schema.gd                    #   CREATE TABLE + migrations
│   ├── db_helpers.gd                #   execute / execute_bound / select wrapper
│   ├── accounts_repo.gd             #   accounts CRUD + soft delete
│   ├── badges_repo.gd               #   badges_unlocked INSERT OR IGNORE
│   ├── characters_repo.gd           #   characters upsert + get
│   ├── inventory_repo.gd            #   inventario DELETE+INSERT (vedi audit 4.1.16)
│   ├── rooms_deco_repo.gd           #   rooms + placed_decorations dual-storage
│   ├── settings_repo.gd             #   key-value settings + music_state
│   └── sync_queue_repo.gd           #   sync_queue enqueue / pending
├── systems/                        # 3 autoload di sistemi
│   ├── performance_manager.gd       #   FPS cap 60/15, window pos persistence
│   ├── stress_manager.gd            #   Stress 0..1 con isteresi, 3 livelli, decay 2%/min
│   └── mess_spawner.gd              #   MessSpawner class istanziata da RoomBase
├── rooms/                          # Logica stanza + runtime gameplay
│   ├── room_base.gd                 #   Spawn decorazioni, character swap, pet, mess container
│   ├── decoration_system.gd         #   Popup R/F/S/X su CanvasLayer 100, drag, snap grid
│   ├── character_controller.gd      #   Movimento WASD 120 px/s + animazioni 8 direzioni
│   ├── pet_controller.gd            #   FSM 6 stati (IDLE/WANDER/FOLLOW/SLEEP/PLAY/WILD)
│   ├── window_background.gd         #   Parallasse 8 layer foresta Eder Muniz
│   ├── room_grid.gd                 #   Grid 64px overlay (edit mode)
│   └── mess_node.gd                 #   Area2D mess cleanable interagente
├── menu/                           # Menu + auth + tutorial
│   ├── main_menu.gd                 #   Loading + 5 bottoni
│   ├── auth_screen.gd               #   Login/register/guest overlay programmatico
│   ├── character_select.gd          #   Preview carousel char
│   ├── menu_character.gd            #   Walk-in animato male_old
│   └── tutorial_manager.gd          #   9 step scripted signal-driven
├── ui/                             # Pannelli UI + HUD + overlay
│   ├── panel_manager.gd             #   Lifecycle 4 panel (deco/settings/profile/profile_hud)
│   ├── deco_panel.gd                #   Catalog browser con DecoButton drag sources
│   ├── deco_button.gd               #   TextureRect subclass con _get_drag_data override
│   ├── settings_panel.gd            #   Volume sliders + lang selector
│   ├── profile_panel.gd             #   Account info + delete char/account buttons
│   ├── profile_hud_panel.gd         #   Mini panel top-right con mood slider + lang toggle
│   ├── drop_zone.gd                 #   Control full-rect, _drop_data emette decoration_placed
│   ├── game_hud.gd                  #   CanvasLayer 50: serenity bar + coin + profile btn
│   └── toast_manager.gd             #   CanvasLayer 90 con VBox container (IGNORE!)
├── utils/                          # Utilità condivise
│   ├── constants.gd                 #   class_name Constants: FPS, viewport, auth, lang
│   ├── helpers.gd                   #   class_name Helpers: snap_to_grid, clamp_inside_floor
│   ├── supabase_config.gd           #   load/validate url HTTPS + anon_key
│   ├── supabase_http.gd             #   HTTP pool (3 concurrent), queue cap 500
│   └── supabase_mapper.gd           #   local ↔ cloud field mapping bidirectional
└── main.gd                         # Controller scena gameplay, HUD wiring, tutorial launch
```

## Autoload singleton (12 core, ordine critico)

Caricati in ordine da `project.godot` `[autoload]`:

| # | Nome | Script | Deps |
|---|------|--------|------|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | — |
| 2 | `AppLogger` | `autoload/logger.gd` | — |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SignalBus, AppLogger |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | LocalDatabase, SignalBus |
| 5 | `GameManager` | `autoload/game_manager.gd` | SignalBus, AuthManager |
| 6 | `SaveManager` | `autoload/save_manager.gd` | SignalBus, AuthManager, GameManager |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | AuthManager, SaveManager |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | SignalBus, GameManager, SaveManager |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | SignalBus, SaveManager |
| 10 | `StressManager` | `systems/stress_manager.gd` | SignalBus, GameManager, SaveManager |
| 11 | `MoodManager` | `autoload/mood_manager.gd` | SignalBus, StressManager |
| 12 | `BadgeManager` | `autoload/badge_manager.gd` | SignalBus, LocalDatabase |

**Nota crypto** (audit 4.4.1): AuthManager usa un costrutto SHA-256 iterato con salt+password concatenati. L'etichetta "PBKDF2" nei commenti **non** corrisponde a RFC 2898. Migrazione a PBKDF2-HMAC-SHA256 vero pianificata pre-v1.1.

## SignalBus — 48 segnali typed

48 signal confermati via `rg -c "^signal " signal_bus.gd`. Raggruppati per dominio: Room (4) · Character (5) · Audio (4) · Decoration mode (5) · UI (3) · Save/Load (3) · Settings (4) · Auth (5) · Cloud (4) · Stress/Mood (3) · Mess (2) · Economy (1) · Profile HUD (3) · Badges (2).

> **Audit 4.3**: solo 1 signal è di tipo errore (`auth_error`). Nessun `save_failed`, `save_integrity_violation`, `sync_error`, `db_error`. Propagation gap HIGH — vedi `AUDIT_REPORT_2026-04-23.md` § 4.3.

---

## Dettaglio moduli chiave

### `autoload/signal_bus.gd` (~85 L)

Dichiarazioni signal solo, no logic. Commenti raggruppano per dominio.

### `autoload/local_database.gd` (323 L)

Facade SQLite. Delega ai 9 repo in `autoload/database/`. `PRAGMA journal_mode=WAL`, `foreign_keys=ON`, `busy_timeout=5000`. Transaction wrapper in `_on_save_requested` (vedi audit 4.1.4 per BEGIN/COMMIT return-check finding).

### `autoload/save_manager.gd` (535 L)

JSON v5.0.0 + HMAC-SHA256. Atomic write: temp → rename + copy fallback. Backup pre-overwrite. Migrazione chain v1→v5. Auto-save Timer 60 s. Vedi audit 4.1.2 per 4 HIGH finding sul path rename/copy + HMAC loss.

### `autoload/auth_manager.gd` (217 L)

State machine (LOGGED_OUT / GUEST / AUTHENTICATED). Format hash `v3:iter:salt_hex:hash_hex` (100 k iter). Legacy v2/v1 auto-migration on login. Rate limit 5 fail / 300 s lockout (in-memory — audit 4.4.2 HIGH).

### `autoload/supabase_client.gd` (547 L)

REST client via `supabase_http.gd`. Token JWT+refresh cifrati `ConfigFile.save_encrypted_pass`. HTTPS-only validation. Backoff exp su 429, cap 300 s. Schema-changes-tolerant (ignora 404 + "relation does not exist"). Vedi audit 4.1.1 per 3 HIGH + 5 MEDIUM.

### `autoload/audio_manager.gd` (473 L)

Dual-player crossfade: `_music_player_a/_b`, `_active_player`, tween. Ascolta `mood_changed` per track switch. Max 50 MB import OGG/WAV.

### `autoload/mood_manager.gd` (~150 L)

Overlay gloomy (alpha + CanvasModulate) + rain particles scene + pet WILD FSM trigger + audio crossfade coordination.

### `autoload/badge_manager.gd` (~90 L)

Carica `data/badges.json`, ascolta eventi di gioco (decorations_placed, mood_changes, stormy_mood, play_time). Unlocks persistiti in SQLite.

### `systems/stress_manager.gd` (181 L)

Stress continuo 0.0–1.0 + livelli discreti con **isteresi**:

- Up: calm→neutral @ 0.35, neutral→tense @ 0.60
- Down: tense→neutral @ 0.50, neutral→calm @ 0.25

Decay passivo `0.02 / 60.0 * delta` per secondo. Persist a `character_data.livello_stress` int 0-100.

### `rooms/room_base.gd` (303 L)

Idempotency guard in `_on_character_changed` (previene character duplication B-001). Null guard + viewport-center fallback in `_spawn_pet`. Vedi audit 4.1.8 per 1 HIGH + 2 MEDIUM.

### `rooms/pet_controller.gd` (268 L)

FSM 6 stati: IDLE, WANDER, FOLLOW, SLEEP, PLAY, WILD (stormy mood). Breathing scale pulse in SLEEP. Bounce animation in PLAY. Vedi audit 4.1.10 per WILD out-of-bounds finding.

### `ui/panel_manager.gd` (~175 L)

Scene cache per evitare re-load. Fade-in/out tween 0.3 s. `gui_release_focus()` su close (fix B-001 focus chain blocking movement). Esc handler via `_unhandled_input`. Mutual exclusion fra pannelli.

### `ui/deco_button.gd` (~50 L)

`extends TextureRect` (critico: non Button — Button `_pressing_inside` rompe drag detection Godot 4). Override `_get_drag_data` ritorna drag_data Dict da meta + `set_drag_preview`.

### `ui/toast_manager.gd` (~155 L)

CanvasLayer 90. `_container.mouse_filter = IGNORE` (critico: STOP blocca click in upper-right quadrant coprendo deco panel + profile_hud). Toast IGNORE + auto-dismiss 3 s. Metodi (no lambda) per evitare zombie callbacks (B-011).

### `menu/tutorial_manager.gd` (376 L)

9 step scripted. Step state machine con filter su SignalBus. Vedi audit 4.1.6 per connection-accumulation e cap-10 findings.

---

## Pattern codificati (invariants)

1. **Never extend Button as drag source** — usa `TextureRect` o `MarginContainer`.
2. **`_ready` connects → `_exit_tree` disconnects** symmetrically per ogni signal.
3. **`class_name` cache è inaffidabile** — usa `preload("path.gd")` + confronto `get_script()` invece di `is ClassName`.
4. **Decoration anchor = bottom-center** (`decoration_system._floor_anchor_offset`).
5. **Floor polygon = source of truth** per clamping movement/placement.
6. **Focus management**: script-created Button senza `focus_mode = FOCUS_NONE` → blocca movement character.
7. **CanvasLayer Control input routing**: VBox/HBox/MarginContainer full-rect DEVE avere `mouse_filter = IGNORE` se non deve intercettare click.
8. **`user://integrity.key` immutabile**: cambiare path invalida tutti i save esistenti.
9. **Catalog loading order**: `GameManager._load_catalogs()` prima di ogni accesso.
10. **Async test pattern**: `await callable.call()` funziona per sync + async methods in Godot 4.

---

## Vedi anche

- [README v1](../README.md) — architettura + contenuti di gioco
- [README data](../data/README.md) — schema SQLite + cataloghi JSON
- [README scenes](../scenes/README.md) — scene Godot (.tscn)
- [README tests](../tests/README.md) — 112 test harness
- [AUDIT_REPORT 2026-04-23](../../AUDIT_REPORT_2026-04-23.md) — findings integrità + stabilità
