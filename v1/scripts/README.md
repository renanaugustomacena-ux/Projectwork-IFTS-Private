# Relax Room — Script GDScript

**51 script GDScript** (~12.325 LOC) organizzati per dominio + `main.gd` root controller.
Architettura **signal-driven**: tutta la comunicazione cross-modulo passa per
`SignalBus` (**56 segnali typed**). Nessun sistema conosce gli altri direttamente.

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
├── autoload/                       # 11 core singleton caricati da project.godot
│   ├── signal_bus.gd                #   56 segnali typed globali
│   ├── logger.gd                    #   JSONL rotating 5MB×5, crypto session ID
│   ├── local_database.gd            #   SQLite WAL facade, 11 tabelle, delega ai 9 repo
│   ├── auth_manager.gd              #   Guest + user/pass PBKDF2-HMAC-SHA256 v4
│   ├── game_manager.gd              #   Stato di gioco + catalog loading JSON
│   ├── save_manager.gd              #   Save JSON v5 + HMAC + backup atomic
│   ├── supabase_client.gd           #   Backup cloud REST push-only, HTTPS, session encrypt
│   ├── audio_manager.gd             #   Dual-player crossfade 2s, mood-driven switch
│   ├── mood_manager.gd              #   Overlay gloomy + pioggia < 0.50 + pet WILD < 0.10
│   ├── badge_manager.gd             #   Badge catalog + SQLite table badges_unlocked
│   └── dev_bridge.gd                #   API HTTP debug-only (127.0.0.1, --bridge, 8080)
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
├── systems/                        # 2 autoload di sistemi + 2 classi istanziate
│   ├── performance_manager.gd       #   FPS cap 60/15, window pos persistence
│   ├── stress_manager.gd            #   Stress 0..1 con isteresi, 3 livelli, decay 2%/min
│   ├── mess_spawner.gd              #   MessSpawner class istanziata da RoomBase
│   └── ambience_controller.gd       #   AmbienceController istanziato da AudioManager
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
│   └── tutorial_manager.gd          #   8 step scripted signal-driven
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
│   └── supabase_mapper.gd           #   mapping dei campi local → cloud (una direzione sola)
└── main.gd                         # Controller scena gameplay, HUD wiring, tutorial launch
```

## Autoload singleton (13 core, ordine critico)

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
| 13 | `DevBridge` | `autoload/dev_bridge.gd` | SignalBus, AppLogger, StressManager, SaveManager |

**Nota crypto**: dal formato v4 (v1.1.0) AuthManager usa PBKDF2-HMAC-SHA256 vero secondo RFC 8018 §5.2 via `Crypto.hmac_digest` (100 k iterazioni, salt 16 B, chiave derivata 32 B). Il costrutto storico — SHA-256 iterato con salt+password concatenati, etichettato impropriamente "PBKDF2" (audit 4.4.1) — resta solo in verifica per gli hash v1/v2/v3, che vengono ri-hashati a v4 al primo login riuscito. Residuo aperto: nessuna data di taglio oltre la quale i vecchi hash smettono di essere accettati (V-054).

## SignalBus — 56 segnali typed

56 signal confermati via `rg -c "^signal " signal_bus.gd`. Raggruppati per dominio: Room (4) · Character (5) · Audio (4) · Decoration mode (5) · UI (3) · Save/Load (5) · Vocabolario dei fallimenti (7) · Settings update (1) · Music state (1) · Settings (1) · Auth (5) · Cloud (4) · Stress/Mood (3) · Mess (2) · Economy (1) · Profile HUD (3) · Effetti mood (2).

> Il propagation gap segnalato dall'audit 4.3 (un solo segnale d'errore, `auth_error`) e` **chiuso**: il gruppo "vocabolario dei fallimenti" aggiunge `save_failed`, `save_integrity_violation`, `save_integrity_unavailable`, `sync_error`, `sync_payload_corrupted`, `catalog_load_failed`, `db_error`, tutti cablati a toast visibili in `main.gd`.

---

## Dettaglio moduli chiave

### `autoload/signal_bus.gd` (98 L)

Dichiarazioni signal solo, no logic. Commenti raggruppano per dominio.

### `autoload/logger.gd` (~485 L)

JSONL bufferato + rotazione, ring dedicato per gli ERROR, scrub dei path di device. La redazione del context è **una sola** per riga e vale sia per il file sia per la riga stampata a console: erano due percorsi separati e la console partiva dal context grezzo, quindi ogni segreto ripulito nel `.jsonl` usciva comunque su stdout (V-022, ramo console).

### `autoload/game_manager.gd` (241 L)

Stato di gioco + caricamento dei 6 cataloghi JSON. `_load_catalogs()` gira nel `_ready` dell'autoload, cioè prima che esista una scena: la `catalog_load_failed` emessa lì non ha ascoltatori. I fallimenti restano quindi in coda in `_pending_catalog_failures` e `main.gd` li ritira con `drain_pending_catalog_failures()` subito dopo aver collegato i toast — coda a consumo singolo, nessun timer di polling (V-019).

### `autoload/local_database.gd` (388 L)

Facade SQLite. Delega ai 9 repo in `autoload/database/`. `PRAGMA journal_mode=WAL`, `foreign_keys=ON`, `busy_timeout=5000`. Transaction wrapper sincrono in `apply_save` (BEGIN/COMMIT/ROLLBACK con return-check, remediation audit 4.1.4).

`_resolve_save_account_id()` crea l'account con la mail segnaposto `offline@local` **solo** quando l'uid è quello ospite. Con un uid autenticato senza riga corrispondente non inventa nulla: logga ERROR, imposta `_last_account_error = "account_row_missing"` e torna `-1`, così `apply_save` aborta ed emette `db_error` (→ toast). Prima il fallback era incondizionato e un lookup a vuoto riscriveva l'identità di un utente registrato (V-021).

### `autoload/save_manager.gd` (1224 L)

JSON v5.0.0 + HMAC-SHA256. Atomic write: temp → rename + copy fallback. Backup pre-overwrite. Migrazione chain v1→v5. Auto-save Timer 60 s. Vedi audit 4.1.2 per 4 HIGH finding sul path rename/copy + HMAC loss.

### `autoload/auth_manager.gd` (414 L)

State machine (LOGGED_OUT / GUEST / AUTHENTICATED). Format hash `v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>` (100 k iter). Legacy v1/v2/v3 verificati con la routine storica e ri-hashati a v4 al primo login riuscito. Rate limit 5 fail / 300 s lockout **persistito** su `accounts.failed_attempts` + `lockout_until_unix`.

### `autoload/supabase_client.gd` (878 L)

REST client via `supabase_http.gd`. Token JWT+refresh cifrati `ConfigFile.save_encrypted_pass`. HTTPS-only validation. Backoff exp su 429, cap 300 s. Schema-changes-tolerant (ignora 404 + "relation does not exist"). Vedi audit 4.1.1 per 3 HIGH + 5 MEDIUM.

### `autoload/audio_manager.gd` (489 L)

Dual-player crossfade: `_music_player_a/_b`, `_active_player`, tween. Ascolta `mood_changed` per track switch. Max 50 MB import OGG/WAV.

`apply_mood_scalar()` deriva **due** bande discrete dal cursore, non una:

- `_music_band_for()` usa `MOOD_TENSE_THRESHOLD` (0.25) → pilota `mood_changed`, quindi la scelta traccia;
- `_ambience_band_for()` usa `MOOD_GLOOMY_THRESHOLD` (0.50) → pilota il tappeto ambientale, che deve restare allineato al visivo.

Il refresh dell'ambience va **dopo** l'emit: `_on_mood_changed` riallinea l'ambience sulla banda musicale, e per il cursore l'autorità è quella visiva. Invertire l'ordine lascerebbe muta la pioggia fra 0.25 e 0.50 (metà di PLR-1).

### `autoload/mood_manager.gd` (157 L)

Overlay gloomy (alpha + CanvasModulate) + rain particles scene + pet WILD FSM trigger + audio crossfade coordination. Soglie: pioggia e scurimento da 0.50 (`MOOD_GLOOMY_THRESHOLD`, stesso numero di proposito — PLR-1), pet WILD sotto 0.10. La musica da temporale ha una soglia sua, vedi `audio_manager.gd`.

### `autoload/badge_manager.gd` (207 L)

Carica `data/badges.json`, ascolta eventi di gioco (decorations_placed, mood_changes, stormy_mood, play_time). Unlocks persistiti in SQLite.

### `systems/stress_manager.gd` (181 L)

Stress continuo 0.0–1.0 + livelli discreti con **isteresi**:

- Up: calm→neutral @ 0.35, neutral→tense @ 0.60
- Down: tense→neutral @ 0.50, neutral→calm @ 0.25

Decay passivo `0.02 / 60.0 * delta` per secondo. Persist a `character_data.livello_stress` int 0-100.

### `rooms/room_base.gd` (388 L)

Idempotency guard in `_on_character_changed` (previene character duplication B-001). Null guard + viewport-center fallback in `_spawn_pet`. Vedi audit 4.1.8 per 1 HIGH + 2 MEDIUM.

### `rooms/pet_controller.gd` (279 L)

FSM 6 stati: IDLE, WANDER, FOLLOW, SLEEP, PLAY, WILD (stormy mood). Breathing scale pulse in SLEEP. Bounce animation in PLAY. Vedi audit 4.1.10 per WILD out-of-bounds finding.

### `ui/panel_manager.gd` (210 L)

Scene cache per evitare re-load. Fade-in/out tween 0.3 s. `gui_release_focus()` su close (fix B-001 focus chain blocking movement). Esc handler via `_unhandled_input`. Mutual exclusion fra pannelli.

### `ui/deco_button.gd` (71 L)

`extends TextureRect` (critico: non Button — Button `_pressing_inside` rompe drag detection Godot 4). Override `_get_drag_data` ritorna drag_data Dict da meta + `set_drag_preview`.

### `ui/toast_manager.gd` (153 L)

CanvasLayer 90. `_container.mouse_filter = IGNORE` (critico: STOP blocca click in upper-right quadrant coprendo deco panel + profile_hud). Toast IGNORE + auto-dismiss 3 s. Metodi (no lambda) per evitare zombie callbacks (B-011).

### `menu/tutorial_manager.gd` (374 L)

8 step scripted (`TUTORIAL_STEP_1`..`TUTORIAL_STEP_8` in `_define_steps`). Step state machine con filter su SignalBus. Vedi audit 4.1.6 per connection-accumulation e cap-10 findings.

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
9. **Catalog loading order**: `GameManager._load_catalogs()` prima di ogni accesso. Un fallimento emesso durante l'autoload non ha ascoltatori: va **anche** messo in coda per la prima UI che si presenta (V-019).
10. **Async test pattern**: `await callable.call()` funziona per sync + async methods in Godot 4.

---

## Vedi anche

- [README v1](../README.md) — architettura + contenuti di gioco
- [README data](../data/README.md) — schema SQLite + cataloghi JSON
- [README scenes](../scenes/README.md) — scene Godot (.tscn)
- [README tests](../tests/README.md) — 196 test harness
- [AUDIT_REPORT 2026-04-23](../../AUDIT_REPORT_2026-04-23.md) — findings integrità + stabilità
