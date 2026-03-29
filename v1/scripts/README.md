# Mini Cozy Room — Script GDScript

Questa cartella contiene **24 script GDScript** attivi (+ 3 in `_reference/`),
organizzati in 7 sottocartelle piu il controller principale `main.gd`.

L'architettura e **signal-driven**: tutta la comunicazione tra moduli passa per
`SignalBus` (31 segnali), evitando accoppiamento diretto tra sistemi.

## Convenzioni

- **Linguaggio codice**: inglese (variabili, funzioni, commenti)
- **Stile**: conforme a `gdtoolkit` (max-line-length=120, max-function-length=50, max-file-length=500)
- **Pattern**: Signal-driven via SignalBus, catalog-driven, account locale (username+password)

## Struttura

```
scripts/
├── autoload/                     # 7 singleton caricati automaticamente
│   ├── signal_bus.gd             # Bus eventi globale (31 segnali)
│   ├── logger.gd                 # Logging strutturato con correlation ID
│   ├── local_database.gd         # Database SQLite (WAL, 9 tabelle, password_hash)
│   ├── auth_manager.gd           # Autenticazione locale: guest, username+password
│   ├── game_manager.gd           # Stato di gioco, caricamento cataloghi JSON
│   ├── save_manager.gd           # Salvataggio JSON v5.0.0 + auto-save 60s
│   └── audio_manager.gd          # Musica lo-fi con crossfade e import esterno
├── menu/                         # Script menu principale
│   ├── main_menu.gd              # Loading screen, bottoni, transizioni scena
│   ├── auth_screen.gd            # Auth overlay: login, registrazione, guest
│   └── menu_character.gd         # Walk-in animato personaggio casuale
├── rooms/                        # Script stanza di gioco
│   ├── room_base.gd              # Gestione stanza, decorazioni, personaggio
│   ├── decoration_system.gd      # Popup interazione (R/F/S/X) su CanvasLayer
│   ├── character_controller.gd   # Movimento top-down (WASD, collision layers)
│   ├── window_background.gd      # Sfondo foresta parallasse (8 layer)
│   └── room_grid.gd              # Griglia visuale per edit mode (64px)
├── systems/                      # Sistemi globali
│   └── performance_manager.gd    # FPS cap dinamico (60/15), posizione finestra
├── ui/                           # Script interfaccia utente
│   ├── panel_manager.gd          # Lifecycle pannelli, mutua esclusione, Escape
│   ├── deco_panel.gd             # Pannello catalogo decorazioni
│   ├── settings_panel.gd         # Pannello impostazioni (volume, lingua, display)
│   ├── profile_panel.gd          # Pannello profilo account
│   └── drop_zone.gd              # Drop zone per posizionamento decorazioni
├── utils/                        # Utilita condivise
│   ├── constants.gd              # Costanti globali (class_name Constants)
│   └── helpers.gd                # Funzioni utility (class_name Helpers)
├── _reference/                   # Script ZroGP (solo riferimento)
│   ├── female_character.gd       # Architettura diversa, non attivo
│   ├── male_character.gd         # Architettura diversa, non attivo
│   └── grid_test.gd              # Griglia isometrica, riferimento
└── main.gd                       # Controller scena principale
```

## Autoload (Singleton)

Caricati automaticamente in ordine da `project.godot`:

| # | Nome | Script | Responsabilita |
|---|------|--------|----------------|
| 1 | `SignalBus` | autoload/signal_bus.gd | Bus eventi globale (31 segnali, disaccoppiamento moduli) |
| 2 | `AppLogger` | autoload/logger.gd | Logging strutturato con correlation ID e rotazione file |
| 3 | `LocalDatabase` | autoload/local_database.gd | Database SQLite locale (WAL mode, foreign keys, 9 tabelle, password_hash) |
| 4 | `AuthManager` | autoload/auth_manager.gd | Autenticazione locale: guest mode, username+password con SHA-256 |
| 5 | `GameManager` | autoload/game_manager.gd | Stato di gioco, caricamento cataloghi JSON (rooms, decorations, characters, tracks) |
| 6 | `SaveManager` | autoload/save_manager.gd | Salvataggio locale JSON v5.0.0 con auto-save ogni 60s, migrazione v1→v5 |
| 7 | `AudioManager` | autoload/audio_manager.gd | Riproduzione musica con crossfade (2s), playlist (sequential/shuffle/repeat), import esterno |
| 8 | `PerformanceManager` | systems/performance_manager.gd | FPS cap dinamico (60 focused / 15 background) |

> **Nota:** PerformanceManager si trova in `systems/`, non in `autoload/`, ma e comunque caricato come singleton.

## SignalBus — Segnali (31)

| Categoria | Segnale | Parametri |
|-----------|---------|-----------|
| Room | `room_changed` | room_id: String, theme: String |
| Room | `decoration_placed` | item_id: String, position: Vector2 |
| Room | `decoration_removed` | item_id: String |
| Room | `decoration_moved` | item_id: String, new_position: Vector2 |
| Character | `character_changed` | character_id: String |
| Character | `outfit_changed` | outfit_id: String |
| Audio | `track_changed` | track_index: int |
| Audio | `track_play_pause_toggled` | is_playing: bool |
| Audio | `ambience_toggled` | ambience_id: String, is_active: bool |
| Audio | `volume_changed` | bus_name: String, volume: float |
| Decoration | `decoration_mode_changed` | active: bool |
| Decoration | `decoration_selected` | item_id: String |
| Decoration | `decoration_deselected` | — |
| Decoration | `decoration_rotated` | item_id: String, rotation_deg: float |
| Decoration | `decoration_scaled` | item_id: String, new_scale: float |
| UI | `panel_opened` | panel_name: String |
| UI | `panel_closed` | panel_name: String |
| Save | `save_requested` | — |
| Save | `save_completed` | — |
| Save | `load_completed` | — |
| Save | `save_to_database_requested` | data: Dictionary |
| Settings | `settings_updated` | key: String, value: Variant |
| Settings | `music_state_updated` | state: Dictionary |
| Settings | `language_changed` | lang_code: String |
| Auth | `auth_state_changed` | state: int |
| Auth | `auth_error` | message: String |
| Auth | `account_created` | account_id: int |
| Auth | `account_deleted` | — |
| Auth | `character_deleted` | — |
| Sync | `sync_started` | — |
| Sync | `sync_completed` | success: bool |

## Dettaglio Moduli

### autoload/

I 7 singleton in `autoload/` (+ PerformanceManager in `systems/`) vengono inizializzati nell'ordine definito in `project.godot`.
Per dettagli sull'architettura e le responsabilita di ciascuno, consulta il
[README tecnico](../README.md#autoload-singleton).

- **auth_manager.gd** — Autenticazione locale con guest mode e username+password (SHA-256).
  Gestisce registrazione, login, eliminazione account/personaggio. Stub per Supabase (Fase 4).

### menu/

- **main_menu.gd** — Gestisce la schermata iniziale: loading screen con fade, wiring dei 4 bottoni
  (Nuova Partita, Carica Partita, Opzioni, Esci), transizione alla scena di gioco.
  Nuova Partita resetta i dati personaggio prima della transizione.
- **auth_screen.gd** — Overlay di autenticazione all'avvio: form login (username+password),
  form registrazione (username+password+conferma), bottone Guest. Errori mostrati in-line.
- **menu_character.gd** — Seleziona un personaggio casuale e riproduce un'animazione walk-in
  dal bordo dello schermo al centro del menu.

### rooms/

- **room_base.gd** — Gestione stanza modulare: spawna decorazioni dal salvataggio (con flip_h,
  rotation, item_scale), istanzia la scena personaggio. Collisioni decorazioni su layer 2.
- **decoration_system.gd** — Script attaccato a ogni Sprite2D decorazione: click → popup su
  CanvasLayer dedicato (layer 100) con bottoni Rotate/Flip/Scale/Delete. Drag in edit mode.
  Scale 7 livelli (0.25x → 3x).
- **character_controller.gd** — Movimento CharacterBody2D top-down (WASD/frecce, 120 px/s),
  animazioni 8 direzioni. Collision mask dinamico: 3 (walls+deco) normale, 1 (walls only) in edit mode.
- **window_background.gd** — Sfondo foresta parallasse con 8 layer, effetto profondita
  reattivo al mouse.
- **room_grid.gd** — Overlay griglia visuale (celle 64px) attivabile in decoration edit mode.

### systems/

- **performance_manager.gd** — FPS cap dinamico (60 fps in focus, 15 fps in background),
  persistenza posizione finestra tra sessioni.

### ui/

- **panel_manager.gd** — Creazione/distruzione dinamica pannelli UI, caching scene,
  mutua esclusione (un solo pannello aperto), animazioni tween (0.3s), chiusura con Escape.
- **deco_panel.gd** — Browser catalogo decorazioni con filtro per categoria.
- **settings_panel.gd** — Impostazioni: volume master/music/sfx, lingua, display mode.
- **profile_panel.gd** — Pannello profilo account: info utente, elimina personaggio/account.
- **drop_zone.gd** — Control full-rect che rileva il drop di decorazioni sulla stanza.
  Decorazioni impilabili (nessun controllo overlap).

### utils/

- **constants.gd** — Costanti globali (`class_name Constants`): ID stanze, temi, personaggi,
  modalita playlist, valori FPS, dimensioni viewport, durate animazioni, costanti auth.
- **helpers.gd** — Funzioni utility (`class_name Helpers`): serializzazione Vector2,
  clamping viewport, formattazione tempo, grid snapping, stringhe data.

## Vedi Anche

- [README Tecnico](../README.md) — Architettura, scene tree, contenuti di gioco
- [README Scene](../scenes/README.md) — Le scene .tscn che utilizzano questi script
- [README Test](../tests/README.md) — Test unitari (attualmente vuota)
- [README Database](../data/README.md) — Schema dati usato da LocalDatabase e SaveManager
