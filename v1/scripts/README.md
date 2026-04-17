# Relax Room — Script GDScript

**37 script GDScript** organizzati per dominio + `main.gd` root controller.
Architettura **signal-driven**: tutta la comunicazione cross-modulo passa per
`SignalBus` (46 segnali typed). Nessun sistema conosce gli altri direttamente.

## Convenzioni

- **Linguaggio codice**: inglese (variabili, funzioni, commenti inline)
- **Documentazione**: italiano
- **Stile**: conforme `gdtoolkit` v4 (max-line-length=120, max-function-length=50, max-file-length=500)
- **Pattern**:
  - Signal-driven via SignalBus (`SignalBus.xxx.connect` in `_ready`, `disconnect` in `_exit_tree`)
  - Catalog-driven (contenuto in `data/*.json`, zero hardcoding)
  - Offline-first (JSON primary, SQLite mirror, Supabase opzionale)
  - Focus chain: Button non-keyboard-navigable → `focus_mode = FOCUS_NONE`

## Struttura directory

```
scripts/
├── autoload/                       # 8 singleton caricati da project.godot
│   ├── signal_bus.gd                #   46 segnali typed globali
│   ├── logger.gd                    #   JSON Lines rotating 5MB×5, crypto session ID
│   ├── local_database.gd            #   SQLite WAL, 9 tabelle, 3 migrazioni
│   ├── auth_manager.gd              #   Guest + user/pass PBKDF2 v2, rate limit
│   ├── game_manager.gd              #   Stato di gioco + catalog loading JSON
│   ├── save_manager.gd              #   Save JSON v5 + HMAC + backup atomic
│   ├── supabase_client.gd           #   REST cloud sync HTTPS-only, session encrypt
│   └── audio_manager.gd             #   Dual-player crossfade 2s, mood-driven switch
├── systems/                        # 3 autoload di sistemi + 1 runtime-instanced
│   ├── performance_manager.gd       #   FPS cap 60/15, window pos persistence
│   ├── stress_manager.gd            #   Stress 0..1 con isteresi, 3 livelli, decay 2%/min
│   └── mess_spawner.gd              #   MessSpawner classe istanziata da RoomBase
├── rooms/                          # Logica stanza + runtime gameplay
│   ├── room_base.gd                 #   Spawn decorazioni, character swap, pet, mess container
│   ├── decoration_system.gd         #   Popup R/F/S/X su CanvasLayer 100, drag, snap grid
│   ├── character_controller.gd      #   Movimento WASD 120 px/s + animazioni 8 direzioni
│   ├── pet_controller.gd            #   FSM 5 stati (IDLE/WANDER/FOLLOW/SLEEP/PLAY)
│   ├── window_background.gd         #   Parallasse 8 layer foresta Eder Muniz
│   ├── room_grid.gd                 #   Grid 64px overlay visual (edit mode)
│   └── mess_node.gd                 #   Area2D mess cleanable interagente
├── menu/                           # Menu principale + auth + tutorial
│   ├── main_menu.gd                 #   Loading + 5 bottoni (skip char_select se 1 char)
│   ├── auth_screen.gd               #   Login/register/guest overlay programmatico
│   ├── character_select.gd          #   Preview carousel char (attualmente bypassed)
│   ├── menu_character.gd            #   Walk-in animato male_old al menu
│   └── tutorial_manager.gd          #   9 step scripted signal-driven (422 righe)
├── ui/                             # Pannelli UI + HUD + overlay
│   ├── panel_manager.gd             #   Lifecycle 4 panel (deco/settings/profile/profile_hud)
│   ├── deco_panel.gd                #   Catalog browser con DecoButton drag sources
│   ├── deco_button.gd               #   TextureRect subclass con _get_drag_data override
│   ├── settings_panel.gd            #   Volume sliders + lang selector (nascosto pre-i18n)
│   ├── profile_panel.gd             #   Account info + delete char/account buttons
│   ├── profile_hud_panel.gd         #   Mini panel top-right con mood slider + lang toggle
│   ├── drop_zone.gd                 #   Control full-rect, _drop_data emette decoration_placed
│   ├── game_hud.gd                  #   CanvasLayer 50 con serenity bar + coin + profile btn
│   └── toast_manager.gd             #   CanvasLayer 90 con VBox container (IGNORE!)
├── utils/                          # Utilità condivise
│   ├── constants.gd                 #   class_name Constants: FPS, viewport, auth, lang, crossfade
│   ├── helpers.gd                   #   class_name Helpers: snap_to_grid, clamp_inside_floor, HMAC-related
│   ├── supabase_config.gd           #   load/validate url HTTPS + anon_key da user://config.cfg
│   ├── supabase_http.gd             #   HTTP pool (3 concurrent), queue cap 500
│   └── supabase_mapper.gd           #   local ↔ cloud field mapping bidirectional
└── main.gd                         # Controller scena gameplay, HUD wiring, tutorial launch
```

## Autoload singleton (10, ordine critico)

Caricati in ordine da `project.godot` `[autoload]`. Ognuno può dipendere solo
dai precedenti:

| # | Nome | Script | Responsabilità | Deps |
|---|------|--------|----------------|------|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | 46 segnali globali typed | — |
| 2 | `AppLogger` | `autoload/logger.gd` | JSONL + session ID crypto | — |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SQLite + migrazioni | SignalBus, AppLogger |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | Auth locale + rate limit | LocalDatabase, SignalBus |
| 5 | `GameManager` | `autoload/game_manager.gd` | Catalog loading + state | SignalBus, AuthManager |
| 6 | `SaveManager` | `autoload/save_manager.gd` | JSON v5 + HMAC | SignalBus, AuthManager, GameManager |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | Cloud sync (off default) | AuthManager, SaveManager |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | Music + mood switch | SignalBus, GameManager, SaveManager |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | FPS cap + window pos | SignalBus, SaveManager |
| 10 | `StressManager` | `systems/stress_manager.gd` | Stress FSM + decay | SignalBus, GameManager, SaveManager |

**Nota**: `PerformanceManager` e `StressManager` sono in `systems/` non
`autoload/` per organizzazione logica, ma sono tutti caricati come autoload
via `project.godot`.

## SignalBus — 46 segnali typed

14 domini. Ogni segnale è **typed** (parametri con type hints). Categorie:

### Room (4)

- `room_changed(room_id: String, theme: String)`
- `decoration_placed(item_id: String, position: Vector2)`
- `decoration_removed(item_id: String)`
- `decoration_moved(item_id: String, new_position: Vector2)`

### Character (5)

- `character_changed(character_id: String)`
- `interaction_available(item_id: String, interaction_type: String)`
- `interaction_unavailable`
- `interaction_started(item_id: String, interaction_type: String)`
- `outfit_changed(outfit_id: String)`

### Audio (4)

- `track_changed(track_index: int)`
- `track_play_pause_toggled(is_playing: bool)`
- `ambience_toggled(ambience_id: String, is_active: bool)`
- `volume_changed(bus_name: String, volume: float)`

### Decoration mode (5)

- `decoration_mode_changed(active: bool)`
- `decoration_selected(item_id: String)`
- `decoration_deselected`
- `decoration_rotated(item_id: String, rotation_deg: float)`
- `decoration_scaled(item_id: String, new_scale: float)`

### UI (3)

- `panel_opened(panel_name: String)`
- `panel_closed(panel_name: String)`
- `toast_requested(message: String, toast_type: String)`

### Save/Load (3)

- `save_requested`
- `save_completed`
- `load_completed`

### Settings (4)

- `settings_updated(key: String, value: Variant)`
- `music_state_updated(state: Dictionary)`
- `save_to_database_requested(data: Dictionary)`
- `language_changed(lang_code: String)`

### Auth (5)

- `auth_state_changed(state: int)`
- `auth_error(message: String)`
- `account_created(account_id: int)`
- `account_deleted`
- `character_deleted`

### Cloud (4)

- `sync_started`
- `sync_completed(success: bool)`
- `cloud_auth_completed(success: bool)`
- `cloud_connection_changed(state: int)`

### Stress / Mood (3)

- `stress_changed(stress_value: float, level: String)`
- `stress_threshold_crossed(level: String)`
- `mood_changed(mood: String)` (listened by AudioManager for track switch)

### Mess (2)

- `mess_spawned(mess_id: String, mess_position: Vector2)`
- `mess_cleaned(mess_id: String)`

### Economy (1)

- `coins_changed(delta: int, total: int)`

### Profile HUD (3, feature T-R-015)

- `profile_hud_requested` (emitted by GameHud profile_btn click)
- `profile_hud_closed` (bridge to settings from profile_hud_panel)
- `mood_level_changed(mood: float)` (0.0=gloomy/stormy, 1.0=cozy)

**Totale: 46 signals**, verificato da `ci/validate_signal_count.py` (floor 40).

---

## Dettaglio moduli chiave

### `autoload/signal_bus.gd` (80 righe)

Dichiarazioni signal solo, no logic. Docstring header + raggruppamento logico
per commenti. Nessun `_ready`/`_exit_tree` — è puro namespace per segnali.

### `autoload/local_database.gd` (831 righe)

SQLite CRUD completo per 9 tabelle. Migrations idempotenti con backup pre-DROP
(fix B-015). `BEGIN TRANSACTION / COMMIT / ROLLBACK` in `_on_save_requested`
per atomicity. Query parametrizzate ovunque (zero SQL injection). WAL mode +
foreign_keys ON + busy_timeout=5000ms (B-026).

### `autoload/save_manager.gd` (523 righe)

JSON v5.0.0 + HMAC-SHA256 integrity. Atomic write: temp → rename. Backup pre-overwrite.
Migrazione chain v1 → v5. Auto-save Timer 60s. Dual-save signal emesso ma SQLite
writer dual-write incompleto (B-016).

### `autoload/auth_manager.gd` (193 righe)

State machine (LOGGED_OUT / GUEST / AUTHENTICATED). PBKDF2-v2 format
`v2:salt_hex:hash_hex` con 10.000 iterazioni SHA-256. Legacy hash auto-migration
su login. Rate limit 5 fail / 300s lockout.

### `autoload/supabase_client.gd` (499 righe)

REST client con `HTTPRequest` pool (via `supabase_http.gd`). Token JWT+refresh
cifrati via `ConfigFile.save_encrypted_pass` con chiave device-local (B-019).
HTTPS-only validation (B-020). Sync cycle 120s. Graceful degradation su schema
changes cloud (ignores 404 + `relation does not exist`).

### `autoload/audio_manager.gd` (425 righe)

Dual-player crossfade pattern: `_music_player_a/_b`, `_active_player`, tween.
Ascolta `mood_changed` per sceglier track con matching mood array e crossfadare.
MP3 da `user://` manualmente caricato via `AudioStreamMP3.data`. Max 50MB import.

### `systems/stress_manager.gd` (169 righe)

Stress continuo clamp 0..1 + livelli discreti con **isteresi**:

- Up: calm→neutral @ 0.35, neutral→tense @ 0.60
- Down: tense→neutral @ 0.50, neutral→calm @ 0.25

Decay passivo `0.02 / 60.0 * delta` per secondo. Persist a `character_data.livello_stress` int 0-100.

### `rooms/room_base.gd` (325 righe)

Idempotency guard in `_on_character_changed` (previene character duplication
B-001). Null guard + viewport-center fallback in `_spawn_pet`. Telemetry logs
su ogni decoration placed/moved per debug.

### `rooms/pet_controller.gd` (226 righe)

FSM completo:
- IDLE → WANDER (~55% chance dopo timer) / FOLLOW (se char >120px) / SLEEP (dopo 120s idle, 30% chance)
- WANDER → IDLE (se target raggiunto o 6s timeout)
- FOLLOW → IDLE (se <40px char distance) / continues following
- SLEEP → IDLE (15s timeout) / PLAY (se char <60px)
- PLAY → FOLLOW (dopo 3s bounce)

Breathing scale pulse in SLEEP (sin wave 1.5Hz, ±3%). Bounce animation in PLAY.

### `ui/panel_manager.gd` (165 righe)

Scene cache per evitare re-load. Fade-in/out tween 0.3s. `gui_release_focus()`
su close (fix B-001 focus chain blocking movement). Esc handler via
`_unhandled_input`. Mutual exclusion: apri B quando A già aperto → close A
immediate + open B.

### `ui/deco_button.gd` (46 righe)

`extends TextureRect` (NON Button, critical — Button `_pressing_inside`
interferisce con drag detection Godot 4). Override `_get_drag_data` ritorna
drag_data Dict da meta + `set_drag_preview(TextureRect)`.

### `ui/toast_manager.gd` (152 righe)

CanvasLayer layer=90. `_container.mouse_filter = IGNORE` (critical — default
STOP blocca clicks in upper-right quadrant coprendo deco panel + profile_hud
fix 2026-04-17). Toast panels IGNORE + auto-dismiss 3s. Metodi (NO lambda) per
evitare zombie callbacks (B-011).

---

## Pattern codificati (invariants)

1. **Never extend Button as drag source** — usa `TextureRect` o `MarginContainer`.
2. **`_ready` connects → `_exit_tree` disconnects** symmetrically per ogni signal.
3. **`class_name` cache è inaffidabile** — usa `preload("path.gd")` + confronto `get_script()` invece di `is ClassName`.
4. **Decoration anchor = bottom-center** (sprites NOT centered, vedi `decoration_system._floor_anchor_offset`).
5. **Floor polygon è source of truth** per clamping movement/placement. Viewport rect deprecato.
6. **Focus management**: script-created Button senza `focus_mode = FOCUS_NONE` → blocca movement character (ui_* input captured).
7. **CanvasLayer Control input routing**: ogni VBox/HBox/MarginContainer full-rect DEVE avere `mouse_filter = IGNORE` se non deve intercettare clicks.
8. **HMAC key stability**: non cambiare path `user://integrity.key` (tutti i save esistenti diventerebbero invalidi).
9. **Catalog loading order**: GameManager.`_load_catalogs()` prima di ogni accesso. `GameManager._ready()` chiama tutti i 5 loader.
10. **Async test pattern**: `await callable.call()` funziona per sync + async methods in Godot 4.

---

## Vedi anche

- [README v1](../README.md) — architettura + contenuti di gioco
- [README data](../data/README.md) — schema SQLite + cataloghi JSON
- [README scenes](../scenes/README.md) — scene Godot (.tscn)
- [README tests](../tests/README.md) — 112 test harness
- [guide/GUIDA_RENAN_GAMEPLAY_UI.md](../guide/GUIDA_RENAN_GAMEPLAY_UI.md) — guida operativa runtime+UI
- [docs/DEEP_READ_REGISTRY_2026-04-16.md](../docs/DEEP_READ_REGISTRY_2026-04-16.md) — source of truth post-audit
