# Relax Room

> **Work in Progress**

## Visione

Relax Room nasce da un'idea semplice: non tutti i giochi devono essere una
competizione. Esiste un pubblico — persone che affrontano stress, ansia, o
semplicemente giornate pesanti — che cerca un passatempo che non chieda nulla in
cambio. Niente classifiche, niente pressione, niente corsa contro il tempo.

**La nostra filosofia di design:**

- **Community, non ranking.** Non ci sono punteggi, non c'e' un "migliore" di
  qualcun altro. L'unica cosa che condividi e' la tua stanza e la tua
  creativita'. L'interazione con gli altri e' costruttiva, mai competitiva.
- **Tutto disponibile, niente da sbloccare.** Non ci sono valute di gioco,
  nessun grind, nessun paywall. Ogni decorazione, ogni stanza, ogni
  personalizzazione e' accessibile dal primo momento. Il gioco e' completo
  dal giorno in cui lo apri — non ti chiede di "guadagnarti" i contenuti.
- **Achievement che parlano di te.** Al posto di monete e progressione
  artificiale, ci sono traguardi con un feeling umano: un trofeo della
  community, un riconoscimento per la creativita' della tua stanza, un
  achievement per aver riempito ogni angolo di decorazioni. Non misurano
  quanto hai giocato, ma come hai giocato. Sono ricordi, non ricompense.
- **Rilassante, non banale.** Non e' un gioco vuoto. Puoi personalizzare la tua
  stanza, scegliere le decorazioni, cambiare tema, ascoltare musica lo-fi, potrai ascoltare
  anche la tua musica personale del tuo device, nelle future releases, metteremo 
  una barra di slide cosi tu, utente, se vuoi una mood piu dark, e ascoltarti un po di rock,
  potrai farlo, poi se vuoi solo passare un po di tempo spostando piantine con un mood
  relax e la musica lo-fi potrai fare anche quello.. al momento siamo in fase di pre-demo,
  e creare il tuo angolo digitale. C'e' profondita' nella creativita',
  non nella difficolta'.
- **Presente, non invadente.** Il gioco non ti punisce se non giochi per una
  settimana. Non ci sono notifiche aggressive, timer che scadono, o energie
  da ricaricare. Apri quando vuoi, rilassati, chiudi quando vuoi. Si salva in automatico
  ogni 2 minuti.

Lo scopo e' creare qualcosa dove ci si diverte rilassandosi — senza pressioni,
senza confronti, senza sensi di colpa. Un piccolo rifugio digitale.

## Descrizione

Relax Room e' un desktop companion 2D che combina stanze pixel art
personalizzabili, musica lo-fi e un personaggio interattivo. Pensato per restare
aperto in background come ambiente digitale rilassante.

**Tecnologie**: Godot 4.6, GDScript, GL Compatibility renderer, SQLite (godot-sqlite v4.7)

**Viewport**: 1280x720, stretch mode `canvas_items`, trasparenza per-pixel abilitata

**Texture filter**: Nearest (pixel art)

## Requisiti

- **Godot Engine 4.6** (GL Compatibility renderer)
- **Git** (per clonare il repository)

## Architettura

### Pattern Principali

- **Signal-driven**: tutta la comunicazione tra moduli passa per `SignalBus` (31 segnali)
- **Account locale**: username + password con SHA-256, guest mode disponibile
- **Catalog-driven**: contenuti (stanze, decorazioni, personaggi, tracce) caricati da JSON
- **Desktop companion**: FPS cap dinamico (60 fps in focus, 15 fps in background)

### Autoload (Singleton)

Caricati automaticamente in questo ordine da `project.godot`:

| # | Autoload | Script | Responsabilita |
|---|----------|--------|----------------|
| 1 | `SignalBus` | signal_bus.gd | Bus eventi globale (31 segnali, disaccoppiamento moduli) |
| 2 | `AppLogger` | logger.gd | Logging strutturato con correlation ID |
| 3 | `LocalDatabase` | local_database.gd | Database SQLite locale (WAL mode, 9 tabelle) |
| 4 | `AuthManager` | auth_manager.gd | Autenticazione locale: guest, username+password |
| 5 | `GameManager` | game_manager.gd | Stato di gioco, caricamento cataloghi JSON |
| 6 | `SaveManager` | save_manager.gd | Salvataggio locale JSON v5.0.0 (auto-save 60s) |
| 7 | `AudioManager` | audio_manager.gd | Riproduzione musica lo-fi con crossfade e import esterno |
| 8 | `PerformanceManager` | performance_manager.gd | FPS cap dinamico (60/15) |

### Scene Tree — Stanza di Gioco

```
Main (Node2D)
├── WallRect (ColorRect, top 40%)
├── FloorRect (ColorRect, bottom 60%)
├── Baseboard (ColorRect, 2px divisore)
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)
│   ├── Character (CharacterBody2D, collision layers 1+2)
│   └── RoomBounds (StaticBody2D, CollisionPolygon2D isometrico)
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, full rect)
│   └── HUD (HBoxContainer)
│       ├── DecoButton
│       ├── SettingsButton
│       └── ProfileButton
├── PanelManager (Node, creato programmaticamente)
└── AudioStreams (Node)
```

Nota: Le decorazioni piazzate hanno un popup su CanvasLayer dedicato (layer 100)
con bottoni R (Rotate), F (Flip), S (Scale), X (Delete). Le collisioni decorazioni
usano layer 2 (separato da room walls su layer 1).

### Scene Tree — Menu Principale

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)
├── MenuCharacter (Node2D, menu_character.gd)
├── LoadingScreen (ColorRect, fade in/out)
├── AuthScreen (Control, overlay z_index=100, auth_screen.gd)
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
│   ├── menu/                  #   Asset menu (sfondo, bottoni, loading, UI)
│   ├── pets/                  #   Animali (Void Cat)
│   ├── room/                  #   Elementi stanza (porte, finestre, letti, mess)
│   ├── sprites/               #   Decorazioni + stanze
│   │   ├── decorations/       #     Indoor Plants Pack (SoppyCraft)
│   │   └── rooms/             #     Isometric Kitchen + Room Builder
│   └── ui/                    #   Kenney Pixel UI Pack + tema cozy
├── data/                      # Cataloghi JSON + schema SQL
│   ├── characters.json        #   1 personaggio giocabile (male_old)
│   ├── decorations.json       #   69 decorazioni in 11 categorie
│   ├── rooms.json             #   1 stanza con 3 temi colore
│   ├── tracks.json            #   2 tracce musicali
│   └── README.md              #   Documentazione schema database
├── scenes/                    # Scene Godot (.tscn)
│   ├── main/                  #   main.tscn (stanza di gioco)
│   ├── menu/                  #   main_menu.tscn (menu principale)
│   ├── ui/                    #   3 pannelli (deco, settings, profile)
│   ├── male-character.tscn    #   Scena personaggio maschile old (CharacterBody2D)
│   ├── female-character.tscn  #   Scena personaggio femminile (non attiva)
│   └── cat_void.tscn          #   Animale domestico
├── scripts/                   # 24 script GDScript (+ 3 reference)
│   ├── autoload/              #   7 singleton (signal_bus, logger, local_database, auth_manager, ...)
│   ├── menu/                  #   Menu principale, auth screen, personaggio walk-in
│   ├── rooms/                 #   Stanza, decorazioni, sfondo, movimento personaggio
│   ├── systems/               #   Performance manager
│   ├── ui/                    #   Panel manager + 3 pannelli + drop zone
│   ├── utils/                 #   Constants, helpers
│   ├── _reference/            #   Script ZroGP (solo riferimento, non attivi)
│   └── main.gd                #   Controller scena principale
└── tests/unit/                # Test unitari (attualmente vuota — GdUnit4 non installato)
```

### Documentazione per Cartella

| Cartella | README | Descrizione |
|----------|--------|-------------|
| `addons/` | [README](addons/README.md) | Plugin godot-sqlite GDExtension v4.7, piattaforme binarie |
| `assets/` | [README](assets/README.md) | 1.422 asset: sprite, audio, sfondi, UI, licenze |
| `data/` | [README](data/README.md) | Schema database JSON/SQLite, 9 tabelle |
| `scenes/` | [README](scenes/README.md) | Scene Godot (.tscn), struttura nodi, flusso |
| `scripts/` | [README](scripts/README.md) | 24 script GDScript, autoload, 31 segnali, moduli |
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

### Decorazioni (69 oggetti, 11 categorie)

| Categoria | Oggetti | Scala | Posizionamento |
|-----------|---------|-------|----------------|
| Beds | 12 | 3x | floor |
| Desks | 4 | 3x | floor |
| Chairs | 4 | 3x | floor |
| Wardrobes | 4 | 3x | floor |
| Windows | 2 | 3x | wall |
| Wall Decor | 1 | 3x | wall |
| Potted Plants | 15 | 6x | floor |
| Plants | 14 | 6x | any |
| Accessories | 8 | 6x | floor |
| Room Elements | 4 | 3x | floor |
| Pets | 1 | 4x | floor |

Interazione decorazioni piazzate: click → popup con Rotate (90 gradi), Flip (specchia),
Scale (7 livelli: 0.25x → 3x), Delete (in edit mode). Le decorazioni sono impilabili.

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

Il file `user://save_data.json` (v5.0.0) contiene:

- `account` — auth_uid, account_id
- `settings` — lingua, volume, modalita display
- `room` — stanza corrente, tema, decorazioni piazzate (con flip_h, rotation, item_scale)
- `character` — ID personaggio, outfit, dati personalizzazione
- `music` — traccia corrente, modalita playlist, ambience attive
- `inventory` — coins, capacita, oggetti posseduti

Migrazione automatica: v1.0.0 → v2.0.0 → v3.0.0 → v4.0.0 → v5.0.0

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

Container di build: `barichello/godot-ci:4.6`

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

## Sistema Account

Il gioco supporta autenticazione locale con username + password (SHA-256 hash con salt).

| Modalita | Descrizione |
|----------|-------------|
| **Guest** | Gioca senza account, dati salvati localmente |
| **Registrato** | Username + password, dati persistenti nel DB locale |

Flusso: Auth Screen all'avvio → Login / Registrazione / Guest → Gameplay.
Il profilo utente e' accessibile dal bottone Profilo nell'HUD (gestione account, elimina personaggio/account).

### Collision Layers

| Layer | Uso |
|-------|-----|
| 1 | Room walls (StaticBody2D confini stanza) |
| 2 | Decorazioni (StaticBody2D, disabilitate in edit mode per il personaggio) |

## Prossimi Sviluppi

| # | Task | Priorita | Descrizione |
|---|------|----------|-------------|
| 1 | Integrazione Supabase (Fase 4) | Alta | Auth online, cloud sync cross-device |
| 2 | Cloud Sync (Fase 5) | Alta | Sincronizzazione bidirezionale con conflict resolution |
| 3 | Calibrazione confini movimento | Media | Calibrare CollisionPolygon2D per il pavimento isometrico |

## Asset e Licenze

| Asset | Autore | Licenza |
|-------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Commerciale OK, credito richiesto |
| Indoor Plants Pack | SoppyCraft | Commerciale OK, no redistribuzione |
| Isometric Kitchen Sprites | JP Cummins | Commerciale OK, no AI training |
| Isometric Room Builder | Thurraya | Commerciale OK, no redistribuzione |
| Mixkit Rain Sounds | Mixkit | Free license |
| Pixel UI Pack | Kenney | CC0 1.0 Universal |
