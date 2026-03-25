# Mini Cozy Room — Documentazione Tecnica

> **⚠️ Nota: Semplificazione in Corso**
> Il codebase contiene sistemi avanzati che sono in fase di semplificazione.
> Alcuni moduli sono **placeholder** (SupabaseClient), altri sono **over-engineered**
> rispetto alle necessità del gioco (LocalDatabase, SaveManager migrations, Logger).
> Tutto funziona correttamente, ma l'obiettivo è rendere il codice più accessibile
> senza perdere funzionalità. Vedere la sezione [Stato Semplificazione](#stato-semplificazione)
> per dettagli su cosa è essenziale, cosa è placeholder e cosa è sostituibile.

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

| # | Autoload | Script | Responsabilita | Stato |
|---|----------|--------|----------------|-------|
| 1 | `SignalBus` | signal_bus.gd | Bus eventi globale (20 segnali, disaccoppiamento moduli) | Essenziale |
| 2 | `AppLogger` | logger.gd | Logging strutturato con correlation ID | Opzionale — over-engineered, funziona ma e' piu' del necessario |
| 3 | `GameManager` | game_manager.gd | Stato di gioco, caricamento cataloghi JSON | Essenziale |
| 4 | `SaveManager` | save_manager.gd | Salvataggio locale JSON v4.0.0 (auto-save 60s) | Semplificabile — il sistema di migrazione v1→v4 e' eccessivo |
| 5 | `LocalDatabase` | local_database.gd | Database SQLite locale (WAL mode, 7 tabelle) | Semplificabile — il JSON via SaveManager basta; SQLite e' ridondante |
| 6 | `AudioManager` | audio_manager.gd | Riproduzione musica lo-fi con crossfade e import esterno | Essenziale |
| 7 | `SupabaseClient` | supabase_client.gd | Client HTTP per Supabase REST API | Placeholder — il gioco e' offline, sostituibile con stub |
| 8 | `PerformanceManager` | performance_manager.gd | FPS cap dinamico (60/15) | Essenziale |

### Scene Tree — Stanza di Gioco

```
Main (Node2D)
├── WallRect (ColorRect, top 40%)
├── FloorRect (ColorRect, bottom 60%)
├── Baseboard (ColorRect, 2px divisore)
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)
│   ├── Character (CharacterBody2D, istanza da male-old-character.tscn)
│   └── RoomBounds (StaticBody2D, CollisionPolygon2D isometrico)
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, full rect)
│   └── HUD (HBoxContainer)
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

### Personaggio

| Personaggio | ID | Tipo Animazione |
|-------------|----|-----------------|
| Ragazzo Classico | male_old | Direzionale (8 direzioni, idle + walk + interact + rotate) |

Personaggio unico del gioco. Sprite direzionali 32x32 con 4 frame per direzione.
Controllabile con **WASD / frecce direzionali** nella stanza di gioco,
confinato dai bordi della stanza tramite `RoomBounds` (StaticBody2D con CollisionPolygon2D isometrico).
Il movimento usa `move_and_slide()` con `motion_mode = FLOATING` (top-down).

### Musica (2 tracce, auto-play)

| Traccia | Sorgente | Tipo |
|---------|----------|------|
| Light Rain | Mixkit | Loop ambientale |
| Rain & Thunder | Mixkit | Loop ambientale |

La musica parte automaticamente all'avvio del gioco. Non ci sono controlli utente
per la musica (nessun pulsante Music nel HUD). Le tracce si alternano in shuffle.

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

## Stato Semplificazione

Il progetto contiene sistemi con complessita' superiore a quella necessaria per un gioco cozy room.
Questo e' il risultato di una fase iniziale di sviluppo dove sono state costruite basi solide
pensando a funzionalita' future. L'obiettivo attuale e' **semplificare senza perdere funzionalita'**.

### Sistemi Placeholder (possono essere rimossi/sostituiti)

| Sistema | Perche' e' placeholder | Alternativa |
|---------|----------------------|-------------|
| **SupabaseClient** (515 righe) | Client REST completo con pool HTTP, token refresh, autenticazione. Il gioco e' completamente offline. | Sostituire con uno stub che logga "online features disabled" (~10 righe) |
| **LocalDatabase** (298 righe) | 7 tabelle SQLite che replicano la struttura Supabase. Tutti i dati necessari sono gia' salvati in JSON via SaveManager. | Rimuovere completamente o ridurre a 2-3 tabelle essenziali |

### Sistemi Over-engineered (funzionanti ma semplificabili)

| Sistema | Cosa c'e' di troppo | Semplificazione possibile |
|---------|---------------------|--------------------------|
| **SaveManager** (327 righe) | Catena migrazione v1→v2→v3→v4, backup con error checking, auto-save timer | Usare un singolo formato JSON senza backward compatibility |
| **Logger** (220 righe) | Log strutturati JSON Lines con rotazione file, livello enterprise | Ridurre a un semplice `print()` wrapper o usare il print nativo di Godot |

### Sistemi Essenziali (da mantenere)

| Sistema | Perche' e' essenziale |
|---------|----------------------|
| **SignalBus** | Pattern architetturale fondamentale per il disaccoppiamento moduli |
| **GameManager** | Carica i cataloghi JSON, gestisce lo stato di gioco |
| **AudioManager** | Musica auto-play, crossfade, gestione playlist |
| **PerformanceManager** | FPS cap dinamico, leggero e utile |

> **Per i colleghi:** Se durante il lavoro trovate un sistema troppo complesso o ridondante,
> non preoccupatevi — probabilmente e' gia' nella lista delle semplificazioni.
> Concentratevi sulle vostre task principali e segnalate eventuali dubbi.

## Problemi Noti

| # | Problema | Dettaglio |
|---|---------|-----------|
| 1 | **Confini movimento personaggio** | Il personaggio puo' ancora uscire dai limiti del pavimento isometrico. Il CollisionPolygon2D (build_mode SEGMENTS) necessita di calibrazione/verifica per bloccare correttamente il CharacterBody2D all'interno della forma del pavimento. |
| 2 | **Popup decorazioni piazzate** | Cliccando su una decorazione piazzata nella stanza, non appare nessun popup per eliminare o ruotare l'oggetto. Attualmente il sistema supporta solo right-click per rimuovere. |

## Prossimi Sviluppi

| # | Task | Assegnato a | Priorita | Descrizione |
|---|------|-------------|----------|-------------|
| 1 | Calibrazione confini movimento | Mohamed / Giovanni | Alta | Calibrare i punti del CollisionPolygon2D in Godot Editor per seguire la forma del pavimento isometrico |
| 2 | Popup interazione decorazioni | Mohamed / Giovanni | Media | Click su decorazione piazzata → popup con pulsanti Elimina / Ruota / Ridimensiona |
| 3 | Rotazione decorazioni | Mohamed / Giovanni | Media | Aggiungere rotazione (90 gradi) alle decorazioni piazzate |
| 4 | Ridimensionamento decorazioni | Mohamed / Giovanni | Media | Aggiungere scaling alle decorazioni piazzate |
| 5 | Semplificazione codice | Mohamed / Giovanni | Bassa | Ridurre complessita SupabaseClient, LocalDatabase, SaveManager |

Guida dettagliata per Mohamed e Giovanni: [TASK_MOHAMED_GIOVANNI.md](guide/TASK_MOHAMED_GIOVANNI.md)

## Asset e Licenze

| Asset | Autore | Licenza |
|-------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Commerciale OK, credito richiesto |
| Indoor Plants Pack | SoppyCraft | Commerciale OK, no redistribuzione |
| Isometric Kitchen Sprites | JP Cummins | Commerciale OK, no AI training |
| Isometric Room Builder | Thurraya | Commerciale OK, no redistribuzione |
| Mixkit Rain Sounds | Mixkit | Free license |
| Pixel UI Pack | Kenney | CC0 1.0 Universal |
