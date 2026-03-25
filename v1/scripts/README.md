# Mini Cozy Room — Script GDScript

> **Nota sulla Semplificazione**: Alcuni script in questa cartella sono **placeholder** o
> **over-engineered** rispetto alle necessita' del gioco. In particolare:
> `supabase_client.gd` (placeholder, il gioco e' offline), `local_database.gd` (over-engineered,
> il JSON basta), `save_manager.gd` (migrazione versioni eccessiva), `logger.gd` (enterprise-grade).
> Questi script funzionano ma sono candidati alla semplificazione. Gli script essenziali sono:
> `signal_bus.gd`, `game_manager.gd`, `audio_manager.gd`, `performance_manager.gd` e tutti gli
> script di gameplay in `rooms/`, `menu/`, `ui/`.

Questa cartella contiene tutti i **26 script GDScript** del progetto, organizzati in
6 sottocartelle piu il controller principale `main.gd`.

L'architettura e **signal-driven**: tutta la comunicazione tra moduli passa per
`SignalBus`, evitando accoppiamento diretto tra sistemi.

## Convenzioni

- **Linguaggio codice**: inglese (variabili, funzioni, commenti)
- **Stile**: conforme a `gdtoolkit` (max-line-length=120, max-function-length=50, max-file-length=500)
- **Pattern**: Signal-driven via SignalBus, catalog-driven, offline-first

## Struttura

```
scripts/
├── autoload/                     # 7 singleton caricati automaticamente
│   ├── signal_bus.gd             # Bus eventi globale (21 segnali)
│   ├── logger.gd                 # Logging strutturato con correlation ID
│   ├── game_manager.gd           # Stato di gioco, caricamento cataloghi JSON
│   ├── save_manager.gd           # Salvataggio JSON v4.0.0 + auto-save 60s
│   ├── local_database.gd         # Database SQLite (WAL, 7 tabelle)
│   ├── audio_manager.gd          # Musica lo-fi con crossfade e import esterno
│   └── supabase_client.gd        # Client HTTP per Supabase REST API
├── menu/                         # Script menu principale
│   ├── main_menu.gd              # Loading screen, bottoni, transizioni scena
│   └── menu_character.gd         # Walk-in animato personaggio casuale
├── rooms/                        # Script stanza di gioco
│   ├── room_base.gd              # Gestione stanza, decorazioni, personaggio
│   ├── decoration_system.gd      # Drag-and-drop e rimozione decorazioni
│   ├── character_controller.gd   # Movimento top-down (WASD, 120 px/s)
│   ├── window_background.gd      # Sfondo foresta parallasse (8 layer)
│   └── room_grid.gd              # Griglia visuale per edit mode (64px)
├── systems/                      # Sistemi globali
│   └── performance_manager.gd    # FPS cap dinamico (60/15), posizione finestra
├── ui/                           # Script interfaccia utente
│   ├── panel_manager.gd          # Lifecycle pannelli, mutua esclusione, Escape
│   ├── deco_panel.gd             # Pannello catalogo decorazioni
│   ├── music_panel.gd            # Pannello player musicale
│   ├── settings_panel.gd         # Pannello impostazioni (volume, lingua, display)
│   ├── shop_panel.gd             # Pannello negozio e inventario
│   └── drop_zone.gd              # Drop zone per posizionamento decorazioni
├── utils/                        # Utilita condivise
│   ├── constants.gd              # Costanti globali (class_name Constants)
│   ├── helpers.gd                # Funzioni utility (class_name Helpers)
│   └── env_loader.gd             # Caricamento config da user://config.cfg
└── main.gd                       # Controller scena principale
```

## Autoload (Singleton)

Caricati automaticamente in ordine da `project.godot`:

| # | Nome | Script | Responsabilita |
|---|------|--------|----------------|
| 1 | `SignalBus` | autoload/signal_bus.gd | Bus eventi globale (21 segnali, disaccoppiamento moduli) |
| 2 | `AppLogger` | autoload/logger.gd | Logging strutturato con correlation ID e rotazione file |
| 3 | `GameManager` | autoload/game_manager.gd | Stato di gioco, caricamento cataloghi JSON (rooms, decorations, characters, tracks) |
| 4 | `SaveManager` | autoload/save_manager.gd | Salvataggio locale JSON v4.0.0 con auto-save ogni 60s, migrazione automatica |
| 5 | `LocalDatabase` | autoload/local_database.gd | Database SQLite locale (WAL mode, foreign keys, 7 tabelle, query parametrizzate) |
| 6 | `AudioManager` | autoload/audio_manager.gd | Riproduzione musica con crossfade (2s), playlist (sequential/shuffle/repeat), import esterno |
| 7 | `SupabaseClient` | autoload/supabase_client.gd | Client HTTP per Supabase REST API (auth, CRUD), config via EnvLoader |
| 8 | `PerformanceManager` | systems/performance_manager.gd | FPS cap dinamico (60 focused / 15 background) |

> **Nota:** PerformanceManager si trova in `systems/`, non in `autoload/`, ma e comunque caricato come singleton.

## SignalBus — Segnali (21)

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
| UI | `panel_opened` | panel_name: String |
| UI | `panel_closed` | panel_name: String |
| UI | `shop_item_selected` | item_id: String |
| Save | `save_requested` | — |
| Save | `save_completed` | — |
| Save | `load_completed` | — |
| Settings | `language_changed` | lang_code: String |
| Auth | `user_authenticated` | user_id: String |
| Auth | `user_signed_out` | — |
| Auth | `auth_error` | message: String |

## Dettaglio Moduli

### autoload/

I 7 singleton in `autoload/` vengono inizializzati nell'ordine definito in `project.godot`.
Per dettagli sull'architettura e le responsabilita di ciascuno, consulta il
[README tecnico](../README.md#autoload-singleton).

### menu/

- **main_menu.gd** — Gestisce la schermata iniziale: loading screen con fade, wiring dei 4 bottoni
  (Nuova Partita, Carica Partita, Opzioni, Esci), transizione alla scena di gioco.
- **menu_character.gd** — Seleziona un personaggio casuale e riproduce un'animazione walk-in
  dal bordo dello schermo al centro del menu.

### rooms/

- **room_base.gd** — Gestione stanza modulare: applica colori muro/pavimento dal tema,
  spawna decorazioni dal salvataggio, istanzia la scena personaggio.
- **decoration_system.gd** — Script attaccato a ogni Sprite2D decorazione: abilita drag
  per riposizionamento e click destro per rimozione in edit mode.
- **character_controller.gd** — Movimento CharacterBody2D top-down (WASD/frecce, 120 px/s),
  animazioni 8 direzioni via spritesheet.
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
- **music_panel.gd** — Player musicale: selezione traccia, controllo volume, playlist mode.
- **settings_panel.gd** — Impostazioni: volume master/music/sfx, lingua, display mode.
- **shop_panel.gd** — Browser negozio, acquisto oggetti, gestione coins e inventario.
- **drop_zone.gd** — Control full-rect che rileva il drop di decorazioni sulla stanza.

### utils/

- **constants.gd** — Costanti globali (`class_name Constants`): ID stanze, temi, personaggi,
  modalita playlist, valori FPS, dimensioni viewport, durate animazioni.
- **helpers.gd** — Funzioni utility (`class_name Helpers`): serializzazione Vector2,
  clamping viewport, formattazione tempo, grid snapping, stringhe data.
- **env_loader.gd** — Carica configurazione chiave=valore da `user://config.cfg`
  per dati sensibili (Supabase URL, API key).

## Vedi Anche

- [README Tecnico](../README.md) — Architettura, scene tree, contenuti di gioco
- [README Scene](../scenes/README.md) — Le 9 scene .tscn che utilizzano questi script
- [README Test](../tests/README.md) — I 5 test unitari che verificano questi moduli
- [README Database](../data/README.md) — Schema dati usato da LocalDatabase e SaveManager
