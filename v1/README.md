# Mini Cozy Room — Documentazione Tecnica

> **⚠️ Nota: Semplificazione Completata (Marzo 2026)**
> Il codebase e' stato semplificato: SupabaseClient rimosso (codice morto, zero chiamanti),
> CI/CD ridotta a un solo job lint. Il gioco funziona esclusivamente offline con JSON + SQLite.
> Alcuni sistemi restano piu' complessi del necessario (Logger, SaveManager migrations) ma
> funzionano e non richiedono modifiche.

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
- **Offline-only**: il salvataggio locale (JSON + SQLite) gestisce tutti i dati
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
| 7 | `PerformanceManager` | performance_manager.gd | FPS cap dinamico (60/15) |

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
│   ├── charachters/           #   3 set sprite (female, male, old) — solo old attivo
│   ├── menu/                  #   Asset menu (sfondo, sprite pad)
│   ├── pets/                  #   Animali (Void Cat)
│   ├── room/                  #   Elementi stanza (porte, finestre)
│   ├── sprites/               #   Decorazioni + stanze
│   │   ├── decorations/       #     Indoor Plants Pack (SoppyCraft)
│   │   └── rooms/             #     Isometric Kitchen + Room Builder
│   └── ui/                    #   Kenney Pixel UI Pack + tema cozy
├── data/                      # Cataloghi JSON + schema SQL
│   ├── characters.json        #   1 personaggio giocabile (male_old)
│   ├── decorations.json       #   58 decorazioni in 11 categorie
│   ├── rooms.json             #   1 stanza con 3 temi colore
│   ├── tracks.json            #   2 tracce musicali
│   └── README.md              #   Documentazione schema database
├── scenes/                    # 8 scene Godot (.tscn)
│   ├── main/                  #   main.tscn (stanza di gioco)
│   ├── menu/                  #   main_menu.tscn (menu principale)
│   ├── ui/                    #   2 pannelli (deco, settings)
│   ├── male-character.tscn    #   Scena personaggio maschile old (CharacterBody2D)
│   ├── female-character.tscn  #   Scena personaggio femminile (non attiva)
│   └── cat_void.tscn          #   Animale domestico
├── scripts/                   # 21 script GDScript
│   ├── autoload/              #   6 singleton (signal_bus, logger, game_manager, audio_manager, ...)
│   ├── menu/                  #   Menu principale + personaggio walk-in
│   ├── rooms/                 #   Stanza, decorazioni, sfondo, movimento personaggio
│   ├── systems/               #   Performance manager
│   ├── ui/                    #   Panel manager + 2 pannelli + drop zone
│   ├── utils/                 #   Constants, helpers
│   └── main.gd                #   Controller scena principale
└── tests/unit/                # Test unitari (attualmente vuota — GdUnit4 non installato)
```

### Documentazione per Cartella

| Cartella | README | Descrizione |
|----------|--------|-------------|
| `addons/` | [README](addons/README.md) | Plugin godot-sqlite GDExtension v4.7, piattaforme binarie |
| `assets/` | [README](assets/README.md) | 1.422 asset: sprite, audio, sfondi, UI, licenze |
| `data/` | [README](data/README.md) | Schema database JSON/SQLite, 7 tabelle |
| `scenes/` | [README](scenes/README.md) | 8 scene Godot (.tscn), struttura nodi, flusso |
| `scripts/` | [README](scripts/README.md) | 21 script GDScript, autoload, 20 segnali, moduli |
| `tests/` | [README](tests/README.md) | Attualmente vuota (test rimossi, GdUnit4 non installato) |

## Contenuti di Gioco

### Stanza

| Stanza | ID | Temi Disponibili |
|--------|----|-----------------|
| Cozy Studio | cozy_studio | modern, natural, pink |

La stanza non usa sfondi pre-fatti: e composta da due zone colorate (muro + pavimento)
definite come palette nei temi. L'utente puo' scegliere tra 3 temi colore per
personalizzare l'ambiente. Gli oggetti vengono piazzati tramite drag-and-drop
dal pannello Decorazioni in modalita' creativa libera.

### Decorazioni (58 oggetti, 11 categorie)

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
| `ci.yml` | Push su `Renan`, PR su `main` | Lint (gdlint + gdformat) |
| `build.yml` | Push su `main`, tag `v*` | Export Windows (.exe), Export HTML5 |

Container di build: `barichello/godot-ci:4.5`

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
| 1 | Backend dati (schema DB, persistenza locale) | Completata |
| 2 | Asset e Pixel Art (stanze, personaggi, UI) | Completata |
| 3 | Stanza modulare, drag-and-drop, placement rules | Completata |
| 4 | Core Game Loop, Audio, Desktop Polish | Completata |
| 5 | Catalogo Decorazioni e Polish UI | In Corso |
| 6 | Polish e Rilascio | Pianificata |

## Stato Semplificazione (aggiornato 29 Marzo 2026)

Il progetto e' stato semplificato rimuovendo il codice non necessario:

- **SupabaseClient rimosso** — 515 righe di codice morto (zero chiamanti nel codebase)
- **CI/CD semplificata** — da 3 pipeline (lint + test + security + database) a 1 solo job lint
- **EnvLoader rimosso** — usato solo da SupabaseClient
- **Segnali auth rimossi** — 3 segnali orfani eliminati da SignalBus (restano 20)
- **shop_panel e music_panel rimossi** — funzionalita' non necessarie
- **Test rimossi** — dipendevano da GdUnit4 (non installato)
- **Asset cucina rimossi** — kitchen_appliances, kitchen_furniture, kitchen_accessories eliminati
- **male_black_shirt rimosso** — dal catalogo characters.json (personaggio incompleto)
- **Schema DB corretto** — C3 (PK characters) e C4 (normalizzazione inventario) completati

### Sistemi ancora piu' complessi del necessario (ma funzionanti)

| Sistema | Nota |
|---------|------|
| **Logger** (220 righe) | Log strutturati JSONL con rotazione file. Funziona, non richiede modifiche. |
| **SaveManager** (327 righe) | Catena migrazione v1→v4. Funziona, non richiede modifiche. |

> **Per i colleghi:** Concentratevi sulle vostre task principali.
> I sistemi complessi funzionano e non vanno toccati.

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

Guida dettagliata per Mohamed e Giovanni: [GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md](guide/GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md)

## Asset e Licenze

| Asset | Autore | Licenza |
|-------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Commerciale OK, credito richiesto |
| Indoor Plants Pack | SoppyCraft | Commerciale OK, no redistribuzione |
| Isometric Kitchen Sprites | JP Cummins | Commerciale OK, no AI training |
| Isometric Room Builder | Thurraya | Commerciale OK, no redistribuzione |
| Mixkit Rain Sounds | Mixkit | Free license |
| Pixel UI Pack | Kenney | CC0 1.0 Universal |
