# Relax Room — Script GDScript

**57 script GDScript** (~15.5k righe: `find v1/scripts -name '*.gd' -exec cat {} + | wc -l`)
organizzati per dominio + `main.gd` root controller.
Architettura **signal-driven**: tutta la comunicazione cross-modulo passa per
`SignalBus` (**48 segnali** typed, `grep -c '^signal ' signal_bus.gd`).
Nessun sistema conosce gli altri direttamente.

## Convenzioni

- **Linguaggio codice**: inglese (variabili, funzioni, commenti inline)
- **Documentazione**: italiano
- **Stile**: `gdtoolkit` v4 (max-line 120, max-function 50, max-file 500)
- **Pattern**:
  - Signal-driven via SignalBus (`SignalBus.xxx.connect` in `_ready`, `disconnect` in `_exit_tree`)
  - Catalog-driven (contenuto in `data/*.json`, zero hardcoding)
  - Offline-first (JSON primary, SQLite mirror, Supabase dormiente)
  - Focus chain: Button non-keyboard-navigable → `focus_mode = FOCUS_NONE`

## Struttura directory

```
scripts/
├── autoload/                       # 11 core singleton caricati da project.godot
│   ├── signal_bus.gd                #   48 segnali typed globali
│   ├── logger.gd                    #   JSONL rotating 5MB×5, crypto session ID, redazione (username incluso)
│   ├── local_database.gd            #   SQLite WAL facade, 11 tabelle, delega ai 9 repo; FK fail-closed
│   ├── auth_manager.gd              #   Guest + user/pass PBKDF2-HMAC-SHA256 v4; username case-insensitive
│   ├── game_manager.gd              #   Stato di gioco + 7 cataloghi JSON + acquisti (purchase_item)
│   ├── save_manager.gd              #   Save JSON v5.1.0 + HMAC + ring 3 backup + 10 slot + "solo settings"
│   ├── supabase_client.gd           #   Backup cloud REST push-only, dormiente
│   ├── audio_manager.gd             #   Dual-player crossfade 2s, mood-driven; figli Ambience + SfxController
│   ├── mood_manager.gd              #   Overlay gloomy + pioggia < 0.50 + pet WILD < 0.10, riapplicato in stanza
│   ├── badge_manager.gd             #   Badge catalog; sblocchi per slot nel save + tabella badges_unlocked
│   └── dev_bridge.gd                #   API HTTP debug-only (127.0.0.1, --bridge, 8080)
├── autoload/database/              # 9 repo modulari
│   ├── schema.gd                    #   CREATE TABLE + 4 indici su FK non-UNIQUE + migrations
│   ├── db_helpers.gd                #   execute / execute_bound / select wrapper
│   ├── accounts_repo.gd             #   accounts CRUD, hard delete con CASCADE
│   ├── badges_repo.gd               #   badges_unlocked INSERT OR IGNORE
│   ├── characters_repo.gd           #   characters upsert + get
│   ├── inventory_repo.gd            #   inventario DELETE+INSERT (chiavi id/qty del save)
│   ├── rooms_deco_repo.gd           #   rooms + placed_decorations dual-storage
│   ├── settings_repo.gd             #   settings + music_state + save_metadata (slot, versione)
│   └── sync_queue_repo.gd           #   sync_queue enqueue / pending
├── systems/                        # 2 autoload di sistemi + 3 classi istanziate
│   ├── performance_manager.gd       #   FPS cap 60/15, window pos persistence
│   ├── stress_manager.gd            #   Stress 0..1 con isteresi, 3 livelli, decay 2%/min
│   ├── mess_spawner.gd              #   MessSpawner istanziato da RoomBase (60-180 s, max 5)
│   ├── ambience_controller.gd       #   AmbienceController istanziato da AudioManager
│   └── sfx_controller.gd            #   SfxController istanziato da AudioManager: pool 6 player, click automatico su ogni Button
├── rooms/                          # Logica stanza + runtime gameplay
│   ├── room_base.gd                 #   Spawn decorazioni (+ SeatArea), character swap, pet, mess, ciotola, zone giardino
│   ├── decoration_system.gd         #   Popup R/F/S/X su CanvasLayer 100 (solo edit mode, clampato), drag, snap grid
│   ├── character_controller.gd      #   Movimento WASD 120 px/s, 8 direzioni, E = interagisci, sit_on()/guida sedie
│   ├── pet_controller.gd            #   FSM 12 stati, fiducia, bisogni in giardino, timeout attraversamenti
│   ├── food_bowl.gd                 #   Ciotola transitoria posata su pet_feed_requested (placeholder da codice)
│   ├── seat_area.gd                 #   Area2D sotto le decorazioni sittable: prompt "Premi E", delega a sit_on()
│   ├── foot_shadow.gd               #   Ombra ovale procedurale sotto personaggio e gatto (_draw, nessuna arte)
│   ├── window_background.gd         #   Parallasse 8 layer foresta Eder Muniz + layer luce
│   ├── room_grid.gd                 #   Grid 64px overlay (edit mode)
│   └── mess_node.gd                 #   Area2D sporco: pulizia a tempo, barra + tempo residuo, completamento offline
├── menu/                           # Menu + auth + slot + tutorial
│   ├── main_menu.gd                 #   5 bottoni; salvataggio "solo settings"; adozione lingua di sistema
│   ├── auth_screen.gd               #   Login/register/guest overlay programmatico
│   ├── slot_select.gd               #   Schermata 10 slot: anteprima, Nuova/Carica/Elimina (conferma a tempo), ESC
│   ├── character_select.gd          #   Preview carousel (solo se piu` di 1 personaggio)
│   ├── menu_character.gd            #   Walk-in animato
│   └── tutorial_manager.gd          #   10 step scripted signal-driven, avviso al timeout
├── ui/                             # Pannelli UI + HUD + overlay
│   ├── panel_manager.gd             #   Lifecycle pannelli (deco/settings/profile/profile_hud/shop), blocco movimento = "pannello aperto"
│   ├── deco_panel.gd                #   Catalog browser: griglie pigre, ordinamento per stile, ultima categoria, nomi IT/EN
│   ├── deco_button.gd               #   TextureRect subclass con _get_drag_data override, anteprima drag 1:1
│   ├── settings_panel.gd            #   Slider musica/ambience/effetti + lingua + replay tutorial
│   ├── profile_panel.gd             #   Account info, "Accedi / Registrati" per l'ospite, delete char/account
│   ├── profile_hud_panel.gd         #   Mini panel top-right: cursore atmosfera + lang toggle + opzioni
│   ├── shop_panel.gd                #   Negozio data-driven da shop.json: Compra/Mangia/Dai da mangiare
│   ├── drop_zone.gd                 #   Control full-rect, _drop_data emette decoration_placed
│   ├── game_hud.gd                  #   CanvasLayer 50: serenity bar + monete + prompt E + barra pulizia
│   └── toast_manager.gd             #   CanvasLayer 90, 3 toast max, mai sopra i pannelli
├── utils/                          # Utilita` condivise
│   ├── constants.gd                 #   class_name Constants: FPS, viewport, auth, lang, soglie mood
│   ├── helpers.gd                   #   class_name Helpers: snap_to_grid, clamp_inside_floor, format_time
│   ├── supabase_config.gd           #   load/validate url HTTPS + anon_key
│   ├── supabase_http.gd             #   HTTP pool (3 concurrent), queue cap 500
│   └── supabase_mapper.gd           #   mapping dei campi local → cloud (una direzione sola)
└── main.gd                         # Controller scena gameplay, HUD 5 bottoni, toast, tutorial launch
```

## Autoload singleton (**13 autoload**, ordine critico)

Caricati in ordine da `project.godot` `[autoload]` (`grep -c '="\*res://' project.godot`):

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
| 12 | `BadgeManager` | `autoload/badge_manager.gd` | SignalBus, LocalDatabase, SaveManager |
| 13 | `DevBridge` | `autoload/dev_bridge.gd` | SignalBus, AppLogger, StressManager, SaveManager |

**Nota crypto**: dal formato v4 (v1.1.0) AuthManager usa PBKDF2-HMAC-SHA256 vero secondo RFC 8018 §5.2 via `Crypto.hmac_digest` (100 k iterazioni, salt 16 B, chiave derivata 32 B). Il costrutto storico (SHA-256 iterato) resta solo in verifica per gli hash v1/v2/v3, ri-hashati a v4 al primo login riuscito. Residuo aperto: nessuna data di taglio oltre la quale i vecchi hash smettono di essere accettati (V-054).

## SignalBus — 48 segnali typed

Nella 1.3.0 sono stati rimossi 16 segnali senza controparte (dichiarati ma mai
emessi o mai ascoltati: fra questi `ambience_toggled`, `save_to_database_requested`,
`interaction_type` legacy). Il CI (`validate-signals`) pretende almeno 45 segnali e
nessun duplicato; `test_polish.test_dead_signals_are_gone` verifica che i segnali
morti non tornino.

Gruppi per dominio (commenti in `signal_bus.gd`): Room · Character · Music/Audio ·
Decoration mode · UI (incl. `toast_requested`) · Save/Load (incl. `final_save_pending`,
`profile_reset`) · Vocabolario dei fallimenti (`save_failed`, `save_integrity_violation`,
`save_integrity_unavailable`, `sync_error`, `sync_payload_corrupted`,
`catalog_load_failed`, `db_error`) · Settings · Music state · Auth · Cloud ·
Stress/Mood · Mess · Economy (`coins_changed`, `player_ate`, `inventory_updated`,
`pet_feed_requested`) · Bisogni (`pet_pottied`) · Profile HUD · Effetti mood
(`pet_wild_mode_requested`, `badge_unlocked`).

---

## Dettaglio moduli chiave

### `autoload/signal_bus.gd`

Dichiarazioni signal solo, no logic. Commenti raggruppano per dominio.

### `autoload/logger.gd`

JSONL bufferato + rotazione, ring dedicato per gli ERROR, scrub dei path di device. La redazione del context e` **una sola** per riga e vale sia per il file sia per la console (V-022). Dalla 1.3.0 anche lo username e` fuori dai log.

### `autoload/game_manager.gd`

Stato di gioco + caricamento dei 7 cataloghi JSON. I fallimenti al boot restano in coda in `_pending_catalog_failures` e `main.gd` li ritira con `drain_pending_catalog_failures()` dopo aver collegato i toast (V-019). `purchase_item()` e` l'unico punto che tocca le monete.

### `autoload/local_database.gd`

Facade SQLite. Delega ai 9 repo in `autoload/database/`. `PRAGMA journal_mode=WAL`, `foreign_keys=ON`, `busy_timeout=5000`. Transaction wrapper sincrono in `apply_save`. Il DB e` unico per i 10 slot: specchio dello slot attivo. Nessuna scrittura in stato LOGGED_OUT.

`_resolve_save_account_id()` crea l'account con la mail segnaposto `offline@local` **solo** per l'uid ospite; con un uid autenticato senza riga logga ERROR e torna `-1`, cosi` `apply_save` aborta ed emette `db_error` (V-021).

### `autoload/save_manager.gd`

JSON v5.1.0 + HMAC-SHA256. Atomic write: temp → rename + copy fallback. Ring di 3 backup. Migrazione chain v1→v5.1. Auto-save Timer 60 s silenzioso. 10 slot (`slot_path()`, `set_active_slot()`, `peek_slot()`, `delete_slot_files()`); `save_settings_only()` per il menu principale; `pet_data` (fiducia, bisogni, pasti) e `room.messes` nel save; badge per slot.

### `autoload/auth_manager.gd`

State machine (LOGGED_OUT / GUEST / AUTHENTICATED). Format hash `v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>`. Username case-insensitive (chiudeva un bypass del lockout), password con tetto 128. Rate limit 5 fail / 300 s lockout **persistito**.

### `autoload/supabase_client.gd`

REST client via `supabase_http.gd`. Token JWT+refresh cifrati (`supabase_session.cfg` scritto solo se esiste una configurazione). HTTPS-only. Backoff exp su 429. **Dormiente**: nessun percorso di gioco lo attiva; e` un backup progettato, non una sync.

### `autoload/audio_manager.gd`

Dual-player crossfade. `apply_mood_scalar()` deriva **due** bande discrete dal cursore: musica (`MOOD_TENSE_THRESHOLD` 0.25) e ambience (`MOOD_GLOOMY_THRESHOLD` 0.50). Dalla 1.3.0 la musica segue **solo** il cursore atmosfera: lo stress di gioco non cambia piu` la traccia. Figli: `AmbienceController` e `SfxController` (`play_sfx(name)`, `sfx_volume`).

### `systems/sfx_controller.gd`

Pool di 6 `AudioStreamPlayer`, cache degli stream da `assets/audio/sfx/synth/`, pitch jitter 6 %, loop nominati (`play_loop`/`stop_loop` per scopa e aspirapolvere). Ogni `Button` aggiunto all'albero fa click da solo (aggancio su `node_added`). Un effetto assente e` silenzio, mai un errore.

### `autoload/mood_manager.gd`

Overlay gloomy + pioggia (davanti ai mobili) + WILD del gatto. Lo stato viene riapplicato all'ingresso in stanza: prima la pioggia moriva tornando dal menu.

### `autoload/badge_manager.gd`

Carica `data/badges.json`, ascolta gli eventi di gioco. Gli sblocchi vivono nel save dello slot (una partita nuova non eredita i badge della vecchia) e vengono specchiati in `badges_unlocked`.

### `systems/stress_manager.gd`

Stress continuo 0.0–1.0 + livelli discreti con **isteresi** (up 0.35/0.60, down 0.50/0.25). Decay passivo `0.02 / 60.0 * delta`. Ledger per tipo di sporco con conteggio.

### `rooms/room_base.gd`

Spawn decorazioni con `SeatArea` sotto le sedie `sittable`, character swap con guard idempotente, spawn del gatto, ciotola su `pet_feed_requested`, registro delle zone giardino (sovrapposte al pavimento). Ricostruisce la stanza dopo "Elimina personaggio".

### `rooms/pet_controller.gd`

FSM 12 stati: IDLE/WANDER/FOLLOW/SLEEP/PLAY, WILD (tempesta), EAT (ciotola, con timeout se irraggiungibile), AVOID (fiducia < 20), GO_POTTY → POTTY → ROAM_GARDEN → RETURN_HOME (timeout 20 s per tratta). Fiducia 0-100 (iniziale 35; +8 a pasto se ha fame, +1/10 s vicino al player in tempesta); PLAY non porta a FOLLOW un gatto diffidente. Bisogni: primo dopo 3-6 min, cap offline 3, orologio all'indietro gestito. Clamp al pavimento unico per tutti gli stati.

### `rooms/mess_node.gd`

Pulizia a tempo: E avvia (prompt "Premi E per pulire"), barra + tempo residuo nel HUD, completamento anche a gioco chiuso (deadline nel save, clampata se assurda), monete e toast al completamento. E su una pulizia gia` avviata non fa nulla.

### `rooms/character_controller.gd`

Movimento WASD + 8 direzioni; E = interazione per capacita` (mess, sedie); `sit_on()` sulle sedie `sittable`, guida delle sedie `rideable` (posizione salvata allo smontaggio). Il movimento e` bloccato quando un pannello e` aperto, non da chi ha il focus.

### `ui/panel_manager.gd`

Scene cache, fade tween 0.3 s, mutua esclusione, Esc handler. Aprire un pannello non ruba il focus (Invio/Spazio non comprano piu` per sbaglio).

### `ui/shop_panel.gd`

Motore di rendering generico su `data/shop.json`: sezioni cibo/croccantini/attrezzi, sottotitoli ("Pulisci ×2 piu` in fretta", velocita` attuale), "Compra" grigio senza monete, "Mangia" disabilitato a stress zero, "Dai da mangiare" → `pet_feed_requested`.

### `menu/slot_select.gd`

Schermata dei 10 slot costruita in codice: anteprima non distruttiva via `SaveManager.peek_slot` (nome personaggio, monete, data), Carica/Elimina con conferma a tempo, Nuova partita sugli slot vuoti, ESC per chiudere. Emette solo segnali: e` il menu a cambiare slot.

### `ui/toast_manager.gd`

CanvasLayer 90, 3 toast max, auto-dismiss 3 s, posizionati dove non coprono i pannelli. Metodi (no lambda) per evitare zombie callbacks (B-011).

### `menu/tutorial_manager.gd`

10 step scripted signal-driven (movimento, Decora, drop, popup, pulizia con E con filtro sul tipo `clean`, Negozio, Profilo, chiusura). Step 5 riscritto nella 1.3.0 (R/F/S/X sono bottoni del popup, non tasti); il dialogo e i suoi figli hanno `mouse_filter` IGNORE (solo Salta resta cliccabile), cosi` il drop dello step 4 arriva al pavimento; avviso al timeout.

---

## Pattern codificati (invariants)

1. **Never extend Button as drag source** — usa `TextureRect` o `MarginContainer`.
2. **`_ready` connects → `_exit_tree` disconnects** symmetrically per ogni signal.
3. **`class_name` solo se serve** — la cache e` inaffidabile e un nome puo` collidere con una classe nativa introdotta da una versione nuova del motore (caso `VirtualJoystick` in Godot 4.7). Usa `preload("path.gd")` + confronto `get_script()` invece di `is ClassName`.
4. **Decoration anchor = bottom-center** (`decoration_system._floor_anchor_offset`).
5. **Floor polygon = source of truth** per clamping movement/placement, per ogni stato del gatto.
6. **Focus management**: script-created Button senza `focus_mode = FOCUS_NONE` → blocca movement character; il blocco del movimento dipende da "pannello aperto", non dal focus.
7. **CanvasLayer Control input routing**: VBox/HBox/MarginContainer full-rect DEVE avere `mouse_filter = IGNORE` se non deve intercettare click.
8. **`user://integrity.key` immutabile**: cambiare path invalida tutti i save esistenti.
9. **Catalog loading order**: `GameManager._load_catalogs()` prima di ogni accesso; un fallimento emesso durante l'autoload va **anche** messo in coda per la prima UI (V-019).
10. **SFX via `AudioManager.play_sfx(name)`** — niente player audio sparsi; assenza = silenzio.
11. **Badge per slot** — la sorgente e` il save dello slot, SQLite e` uno specchio.
12. **Async test pattern**: `await callable.call()` funziona per sync + async methods in Godot 4.

---

## Vedi anche

- [README v1](../README.md) — architettura + contenuti di gioco
- [README data](../data/README.md) — schema SQLite + cataloghi JSON
- [README scenes](../scenes/README.md) — scene Godot (.tscn)
- [README tests](../tests/README.md) — 250 test in 25 moduli
- [CHANGELOG 1.3.0](../../CHANGELOG.md) — stato corrente e limiti noti
