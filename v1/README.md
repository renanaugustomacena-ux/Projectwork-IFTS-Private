# Mini Cozy Room — Documentazione Tecnica

## Descrizione

Mini Cozy Room e un desktop companion 2D che combina stanze pixel art
personalizzabili, musica lo-fi e un personaggio interattivo. Pensato per restare
aperto in background come ambiente digitale rilassante.

**Tecnologie**: Godot 4.5, GDScript, GL Compatibility renderer, SQLite (godot-sqlite v4.7)

**Viewport**: 1280x720, stretch mode `canvas_items`, trasparenza per-pixel abilitata

**Texture filter**: Nearest (pixel art)

## Requisiti

- **Godot Engine 4.5** (GL Compatibility renderer)
- **Git** (per clonare il repository)

## Architettura

### Pattern Principali

- **Signal-driven**: tutta la comunicazione tra moduli passa per `SignalBus` (20 segnali)
- **Offline-first**: il salvataggio locale (JSON + SQLite) ha priorita; Supabase e opzionale
- **Catalog-driven**: contenuti (stanze, decorazioni, personaggi, tracce) caricati da JSON
- **Desktop companion**: FPS cap dinamico (60 fps in focus, 15 fps in background)

### Autoload (Singleton)

Caricati automaticamente in questo ordine da `project.godot`:

| # | Autoload | Script | Responsabilita |
|---|----------|--------|----------------|
| 1 | `SignalBus` | signal_bus.gd | Bus eventi globale (20 segnali, disaccoppiamento moduli) |
| 2 | `AppLogger` | logger.gd | Logging strutturato con correlation ID |
| 3 | `GameManager` | game_manager.gd | Stato di gioco, caricamento cataloghi JSON |
| 4 | `SaveManager` | save_manager.gd | Salvataggio locale JSON v4.0.0 (auto-save 60s) |
| 5 | `LocalDatabase` | local_database.gd | Database SQLite locale (WAL mode, 7 tabelle) |
| 6 | `AudioManager` | audio_manager.gd | Riproduzione musica lo-fi con crossfade e import esterno |
| 7 | `SupabaseClient` | supabase_client.gd | Client HTTP per Supabase REST API |
| 8 | `PerformanceManager` | performance_manager.gd | FPS cap dinamico (60/15) |

### Scene Tree — Stanza di Gioco

```
Main (Node2D)
├── WallRect (ColorRect, top 40%)
├── FloorRect (ColorRect, bottom 60%)
├── Baseboard (ColorRect, 2px divisore)
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)
│   ├── Character (CharacterBody2D, istanza da male/female-character.tscn)
│   └── RoomBounds (StaticBody2D, CollisionPolygon2D isometrico)
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, full rect)
│   └── HUD (HBoxContainer)
│       ├── MusicButton
│       ├── DecoButton
│       └── SettingsButton
├── PanelManager (Node, creato programmaticamente)
└── AudioStreams (Node)
```

### Scene Tree — Menu Principale

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)
├── MenuCharacter (Node2D, menu_character.gd)
├── LoadingScreen (ColorRect, fade in/out)
└── UILayer (CanvasLayer)
    └── ButtonContainer (VBoxContainer)
        ├── NuovaPartitaBtn
        ├── CaricaPartitaBtn
        ├── OpzioniBtn
        └── EsciBtn
```

## Struttura del Progetto

```
v1/
├── addons/                    # Plugin Godot
│   └── godot-sqlite/          #   SQLite GDExtension v4.7
├── assets/                    # Asset grafici e audio (1400+ file)
│   ├── audio/music/           #   2 tracce Mixkit (WAV)
│   ├── backgrounds/           #   Sfondi foresta (Free Pixel Art Forest)
│   ├── charachters/           #   3 personaggi (female, male, old)
│   ├── menu/                  #   Asset menu (sfondo, sprite pad)
│   ├── pets/                  #   Animali (Void Cat)
│   ├── room/                  #   Elementi stanza (porte, finestre)
│   ├── sprites/               #   Decorazioni + stanze
│   │   ├── decorations/       #     Indoor Plants Pack (SoppyCraft)
│   │   └── rooms/             #     Isometric Kitchen + Room Builder
│   └── ui/                    #   Kenney Pixel UI Pack + tema cozy
├── data/                      # Cataloghi JSON + schema SQL
│   ├── characters.json        #   3 personaggi giocabili
│   ├── decorations.json       #   118 decorazioni in 14 categorie
│   ├── rooms.json             #   1 stanza con 3 temi colore
│   ├── tracks.json            #   2 tracce musicali
│   └── supabase_migration.sql #   Schema DB Supabase (7 tabelle + RLS)
├── scenes/                    # 8 scene Godot (.tscn)
│   ├── main/                  #   main.tscn (stanza di gioco)
│   ├── menu/                  #   main_menu.tscn (menu principale)
│   ├── ui/                    #   3 pannelli (music, deco, settings)
│   ├── male-character.tscn    #   Scena personaggio maschile (CharacterBody2D)
│   ├── female-character.tscn  #   Scena personaggio femminile (CharacterBody2D)
│   └── cat_void.tscn          #   Animale domestico
├── scripts/                   # 25 script GDScript
│   ├── autoload/              #   7 singleton (signal_bus, logger, game_manager, ...)
│   ├── menu/                  #   Menu principale + personaggio walk-in
│   ├── rooms/                 #   Stanza, decorazioni, sfondo, movimento personaggio
│   ├── systems/               #   Performance manager
│   ├── ui/                    #   Panel manager + 3 pannelli + drop zone
│   ├── utils/                 #   Constants, helpers, env_loader
│   └── main.gd                #   Controller scena principale
└── tests/unit/                # 4 test unitari (GdUnit4)
    ├── test_helpers.gd
    ├── test_logger.gd
    ├── test_save_manager.gd
    └── test_save_manager_state.gd
```

### Documentazione per Cartella

| Cartella | README | Descrizione |
|----------|--------|-------------|
| `addons/` | [README](addons/README.md) | Plugin godot-sqlite GDExtension v4.7, piattaforme binarie |
| `assets/` | [README](assets/README.md) | 1.422 asset: sprite, audio, sfondi, UI, licenze |
| `data/` | [README](data/README.md) | Schema database JSON/SQLite/Supabase, 7 tabelle, RLS |
| `scenes/` | [README](scenes/README.md) | 8 scene Godot (.tscn), struttura nodi, flusso |
| `scripts/` | [README](scripts/README.md) | 25 script GDScript, autoload, 20 segnali, moduli |
| `tests/` | [README](tests/README.md) | 4 test unitari GdUnit4, copertura moduli |

## Contenuti di Gioco

### Stanza

| Stanza | ID | Temi Disponibili |
|--------|----|-----------------|
| Cozy Studio | cozy_studio | modern, natural, pink |

La stanza non usa sfondi pre-fatti: e composta da due zone colorate (muro + pavimento)
definite come palette nei temi. L'utente puo' scegliere tra 3 temi colore per
personalizzare l'ambiente. Gli oggetti vengono piazzati tramite drag-and-drop
dal pannello Decorazioni in modalita' creativa libera.

### Decorazioni (118 oggetti, 14 categorie)

| Categoria | Oggetti | Scala | Posizionamento |
|-----------|---------|-------|----------------|
| Beds | 4 | 3x | floor |
| Desks | 4 | 3x | floor |
| Chairs | 4 | 3x | floor |
| Wardrobes | 4 | 3x | floor |
| Windows | 2 | 3x | wall |
| Wall Decor | 1 | 3x | wall |
| Potted Plants | 14 | 6x | floor |
| Plants | 14 | 6x | any |
| Accessories | 5 | 6x | floor |
| Room Elements | 4 | 3x | floor |
| Pets | 1 | 4x | floor |
| Kitchen Appliances | 11 | 3x | floor |
| Kitchen Furniture | varies | 3x | floor |
| Kitchen Accessories | varies | 3x | floor |

### Personaggi (3)

| Personaggio | ID | Tipo Animazione |
|-------------|----|-----------------|
| Ragazza Camicia Rossa | female_red_shirt | Spritesheet (idle, walk, interact, rotate) |
| Ragazzo Camicia Gialla | male_yellow_shirt | Spritesheet (idle, walk, interact, rotate) |
| Ragazzo Classico | male_old | Direzionale (8 direzioni, idle + walk) |

Il personaggio e controllabile con **WASD / frecce direzionali** nella stanza di gioco,
confinato dai bordi della stanza tramite `RoomBounds` (StaticBody2D con CollisionPolygon2D isometrico).
Il movimento usa `move_and_slide()` con `motion_mode = FLOATING` (top-down).

### Musica (2 tracce)

| Traccia | Sorgente | Tipo |
|---------|----------|------|
| Light Rain | Mixkit | Loop ambientale |
| Rain & Thunder | Mixkit | Loop ambientale |

## Salvataggio

### Schema Locale (JSON)

Il file `user://save_data.json` (v4.0.0) contiene:

- `settings` — lingua, volume, modalita display
- `room` — stanza corrente, tema, decorazioni piazzate
- `character` — ID personaggio, outfit, dati personalizzazione
- `music` — traccia corrente, modalita playlist, ambience attive
- `inventory` — coins, capacita, oggetti posseduti

Migrazione automatica: v1.0.0 → v2.0.0 → v3.0.0 → v4.0.0

### Database Locale (SQLite)

Il sistema usa **SQLite** (via godot-sqlite GDExtension v4.7) come mirror del salvataggio.
Il file `user://cozy_room.db` viene creato automaticamente al primo avvio (WAL mode, foreign keys).
SaveManager scrive contemporaneamente su JSON e SQLite.

Per lo schema dettagliato, consulta il **[README Database](data/README.md)**.

## CI/CD

La pipeline GitHub Actions e definita in `.github/workflows/`:

| Workflow | Trigger | Job |
|----------|---------|-----|
| `ci.yml` | Push su `Renan`, PR su `main` | Lint (gdlint + gdformat), Test (GdUnit4), Security Scan |
| `build.yml` | Push su `main`, tag `v*` | Export Windows (.exe), Export HTML5 |

Container di build: `barichello/godot-ci:4.5`

### Security Scan

- Rilevamento segreti (API key, password)
- Validazione `.env` (solo variabili sintetiche)
- Marcatori dati sintetici

## Sviluppo

### Convenzioni Codice

- **Linguaggio codice**: inglese (variabili, funzioni, commenti)
- **Documentazione**: italiano
- **Stile GDScript**: conforme a `gdtoolkit` (max-line-length=120, max-function-length=50, max-file-length=500)
- **Viewport**: 1280x720, scaling responsivo (canvas_items + fractional)

### Branch

| Branch | Descrizione |
|--------|-------------|
| `main` | Branch protetto, solo PR reviewate |
| `Renan` | Branch di sviluppo attivo |

### Workflow Sviluppo

1. Modifica script in VS Code (con estensione GDScript)
2. Salva (Ctrl+S)
3. Vai su Godot Engine e premi F5 per testare
4. Per scene e nodi: usa Godot Editor (obbligatorio per editing visuale)

## Fasi di Sviluppo

| Fase | Descrizione | Stato |
|------|-------------|-------|
| 0 | Infrastruttura (CI/CD, linting, test) | Completata |
| 1 | Backend Supabase (auth, schema DB, RLS) | Completata |
| 2 | Asset e Pixel Art (stanze, personaggi, UI) | Completata |
| 3 | Stanza modulare, drag-and-drop, placement rules | Completata |
| 4 | Core Game Loop, Audio, Desktop Polish | Completata |
| 5 | Catalogo Decorazioni e Polish UI | In Corso |
| 6 | Polish e Rilascio | Pianificata |

## Problemi Noti

| # | Problema | Dettaglio |
|---|---------|-----------|
| 1 | **Confini movimento personaggio** | Il personaggio puo' ancora uscire dai limiti del pavimento isometrico. Il CollisionPolygon2D (build_mode SEGMENTS) necessita di calibrazione/verifica per bloccare correttamente il CharacterBody2D all'interno della forma del pavimento. |
| 2 | **Popup decorazioni piazzate** | Cliccando su una decorazione piazzata nella stanza, non appare nessun popup per eliminare o ruotare l'oggetto. Attualmente il sistema supporta solo right-click per rimuovere. |

## Prossimi Sviluppi

| # | Task | Priorita | Descrizione |
|---|------|----------|-------------|
| 1 | Risolvere confini movimento | Alta | Calibrare il CollisionPolygon2D isometrico oppure usare un approccio alternativo (muri ruotati, NavigationRegion2D) per confinare il personaggio nell'area pavimento |
| 2 | Rotazione decorazioni | Media | Aggiungere la possibilita' di ruotare le decorazioni piazzate (popup o shortcut) |
| 3 | Ridimensionamento decorazioni | Media | Aggiungere la possibilita' di scalare le decorazioni piazzate |
| 4 | Popup interazione decorazioni | Media | Click su decorazione piazzata → popup con pulsanti Elimina / Ruota / Ridimensiona |

## Asset e Licenze

| Asset | Autore | Licenza |
|-------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Commerciale OK, credito richiesto |
| Indoor Plants Pack | SoppyCraft | Commerciale OK, no redistribuzione |
| Isometric Kitchen Sprites | JP Cummins | Commerciale OK, no AI training |
| Isometric Room Builder | Thurraya | Commerciale OK, no redistribuzione |
| Mixkit Rain Sounds | Mixkit | Free license |
| Pixel UI Pack | Kenney | CC0 1.0 Universal |
