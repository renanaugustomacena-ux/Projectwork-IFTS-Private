# Relax Room — Documentazione Tecnica v1

> Progetto Godot 4.6 · IFTS academic project · Demo 22 Aprile 2026
> Codice sorgente, architettura, contenuti di gioco, flussi di sviluppo.

---

## Visione

Relax Room nasce da un'idea semplice: **non tutti i giochi devono essere una
competizione**. Esiste un pubblico — persone che affrontano stress, ansia, o
semplicemente giornate pesanti — che cerca un passatempo che non chieda nulla
in cambio. Niente classifiche, niente pressione, niente corsa contro il tempo.

**Filosofia di design**:

- **Community, non ranking.** Non ci sono punteggi, non c'è un "migliore". L'unica
  cosa che condividi è la tua stanza e la tua creatività. Interazione costruttiva,
  mai competitiva.
- **Tutto disponibile, niente da sbloccare.** Nessuna valuta, nessun grind, nessun
  paywall. Ogni decorazione e personalizzazione è accessibile dal giorno 1. Il gioco
  è completo dal momento in cui lo apri.
- **Achievement che parlano di te.** I traguardi sono ricordi, non ricompense.
  Riempire ogni angolo di decorazioni, personalizzare con un tema coerente: questi
  pesano. Non il tempo speso.
- **Rilassante, non banale.** Puoi personalizzare la stanza, scegliere decorazioni,
  cambiare tema, ascoltare musica lo-fi. Mood slider permetterà di cambiare l'audio
  dinamicamente (dalle tracce calm alle tense). Profondità nella creatività, non
  nella difficoltà.
- **Presente, non invadente.** Il gioco non punisce se non giochi per una settimana.
  Nessuna notifica aggressiva, nessun timer che scade, nessuna energia da ricaricare.
  Apri quando vuoi, rilassati, chiudi quando vuoi. Salvataggio automatico ogni 60s.

Lo scopo: un piccolo rifugio digitale — senza pressioni, senza confronti, senza
sensi di colpa.

---

## Stack tecnico

| Componente | Versione / Valore |
|------------|-------------------|
| Godot Engine | **4.6 Stable** (standard, NON .NET) |
| Renderer | GL Compatibility |
| Scripting | GDScript (stile `gdtoolkit` v4) |
| Database locale | **SQLite** via godot-sqlite GDExtension v4.7 |
| Cloud sync (opzionale) | **Supabase** REST (off di default) |
| Viewport | 1280 × 720, `stretch_mode = canvas_items` |
| Trasparenza finestra | `window/per_pixel_transparency/allowed = true` |
| Texture filter | **Nearest** (pixel art crisp) |

---

## Architettura

### Principi

- **Signal-driven**: tutta la comunicazione tra moduli passa per `SignalBus` (46 segnali typed). Nessun sistema conosce gli altri.
- **Catalog-driven**: contenuti (stanze, decorazioni, personaggi, tracce, mess) caricati da JSON in `data/`. Aggiungere contenuto = editare JSON, niente codice.
- **Offline-first**: JSON + SQLite sono source-of-truth. Supabase è opzionale e sincronizzato async.
- **Desktop companion**: FPS cap dinamico (60 focused / 15 unfocused) per rispettare la batteria.

### Autoload (10 singleton, ordine critico)

Caricati in ordine da `project.godot`. Ognuno può dipendere solo dai precedenti:

| # | Nome | Script | Responsabilità |
|---|------|--------|----------------|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | 46 segnali globali typed |
| 2 | `AppLogger` | `autoload/logger.gd` | JSON Lines rotating 5MB×5, session ID crypto, redazione credenziali |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SQLite WAL, 9 tabelle, migrazioni con backup pre-DROP |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | Guest + username/password PBKDF2-v2 10k iter, rate limit |
| 5 | `GameManager` | `autoload/game_manager.gd` | Stato di gioco + 5 cataloghi JSON |
| 6 | `SaveManager` | `autoload/save_manager.gd` | Save JSON v5.0.0 + HMAC-SHA256 + backup atomic + migrazioni v1→v5 |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | REST cloud sync, HTTPS-only, session token cifrato |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | Dual-player crossfade 2s, mood-driven track switch |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | FPS cap + window pos persistence |
| 10 | `StressManager` | `systems/stress_manager.gd` | Stress 0..1 con isteresi, 3 livelli, decay 2%/min |

### Scene Tree — Stanza di Gioco (`scenes/main/main.tscn`)

```
Main (Node2D)                                             layer 0
├── RoomBackground (Sprite2D)                              room.png
├── WallRect (ColorRect, anchor bottom 40%)                mouse_filter=IGNORE
├── FloorRect (ColorRect, anchor top 40%)                  mouse_filter=IGNORE
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)                               spawn decorazioni
│   ├── Character (instance male-old-character.tscn)       CharacterBody2D, mask 1|2
│   └── RoomBounds (StaticBody2D)
│       └── FloorBounds (CollisionPolygon2D isometrico)    rhombus 4 vertices
├── RoomGrid (Node2D, room_grid.gd)                        visibile solo in edit mode
├── UILayer (CanvasLayer)                                  layer 10
│   ├── DropZone (Control, full rect, PASS)                riceve drop decorazioni
│   └── HUD (HBoxContainer anchor bottom 44px)
│       ├── MenuButton "Menu"
│       ├── DecoButton "Decora"
│       ├── SettingsButton "Opzioni"
│       └── ProfileButton "Profilo"
└── PanelManager (Node, aggiunto runtime da main.gd)

Layer aggiunti runtime da main.gd:
├── ToastManager (CanvasLayer layer=90)                    notifiche non bloccanti
└── GameHud (CanvasLayer layer=50)                         serenity bar, coin, profilo
```

Le decorazioni piazzate hanno un popup dedicato su `CanvasLayer layer=100`
con pulsanti **R** (rotate 90°), **F** (flip horizontal), **S** (scale 0.25x→3x),
**X** (delete in edit mode).

### Scene Tree — Menu Principale (`scenes/menu/main_menu.tscn`)

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)         8 layer parallasse
├── DimOverlay (ColorRect alpha 0.35)                       oscura la foresta
├── LoadingScreen (ColorRect)                               fade in/out
├── MenuCharacter (Node2D, menu_character.gd)               walk-in animato
└── UILayer (CanvasLayer layer=10)
    └── ButtonContainer (VBoxContainer centrato)
        ├── Nuova Partita
        ├── Carica Partita
        ├── Opzioni
        ├── Profilo
        └── Esci
```

Flusso: Auth Screen al primo avvio (se logout) → Menu principale → Nuova Partita
(salta character_select se 1 solo char in catalog) → Scena gameplay.

---

## Struttura del progetto

```
v1/
├── addons/                         # Plugin Godot
│   ├── godot-sqlite/                #   SQLite GDExtension v4.7
│   └── virtual_joystick/            #   Addon CF Studios (touch)
├── assets/                         # Asset grafici + audio
│   ├── _placeholder_temp/           #   CC0 puny_characters (scaffolding)
│   ├── audio/music/                 #   2 tracce Mixkit (WAV)
│   ├── backgrounds/                 #   Free Pixel Art Forest (Eder Muniz)
│   ├── charachters/male/old/        #   Personaggio attivo: male_old (directional)
│   ├── menu/                        #   Loading, bottoni, joystick UI
│   ├── palette/                     #   palette_projectwork.gpl
│   ├── pets/                        #   Void Cat (simple + iso)
│   ├── room/                        #   Stanza base, letti, finestre, mess sprites
│   ├── sprites/
│   │   ├── decorations/              #     SoppyCraft Indoor Plants + Kenney Furniture CC0
│   │   └── rooms/                    #     Thurraya Isometric + Bongseng additions
│   └── ui/                          #   Kenney Pixel UI Pack + cozy_theme.tres
├── data/                           # 5 cataloghi JSON
│   ├── characters.json              #   1 personaggio: male_old
│   ├── decorations.json             #   129 decorazioni in 13 categorie (1 hidden)
│   ├── rooms.json                   #   1 stanza: cozy_studio con 3 temi
│   ├── tracks.json                  #   2 tracce + ambience vuoto
│   └── mess_catalog.json            #   6 mess con stress weights
├── docs/                           # Report tecnici + presentazione
│   ├── CONSOLIDATED_PROJECT_REPORT.md
│   ├── DEEP_READ_REGISTRY_2026-04-16.md
│   ├── presentazione_progetto.md
│   └── speech_*.md
├── guide/                          # Guide operative team
│   ├── GUIDA_RENAN_GAMEPLAY_UI.md
│   ├── GUIDA_ELIA_DATABASE.md
│   ├── GUIDA_CRISTIAN_CICD.md
│   ├── GUIDA_ALEX_PIXEL_ART.md
│   └── SETUP_AMBIENTE.md
├── scenes/                         # 17 scene Godot (.tscn)
│   ├── main/main.tscn               #   Stanza di gioco
│   ├── menu/                        #   Main menu + auth_screen + character_select
│   ├── ui/                          #   4 panel scenes + virtual_joystick
│   ├── male-old-character.tscn      #   Scena personaggio attivo
│   ├── cat_void.tscn                #   Pet variant simple (16×16)
│   └── cat_void_iso.tscn            #   Pet variant iso (32×32)
├── scripts/                        # 37 script GDScript
│   ├── autoload/                    #   8 singleton (SignalBus → SupabaseClient)
│   ├── rooms/                       #   Room + decoration + character + pet + mess + window_bg
│   ├── menu/                        #   main_menu + auth + character_select + tutorial
│   ├── systems/                     #   Performance + Stress + MessSpawner
│   ├── ui/                          #   Panel manager + 5 panels + drop_zone + deco_button + toast + HUD
│   ├── utils/                       #   Constants + Helpers + supabase_{config,http,mapper}
│   └── main.gd                      #   Controller scena principale
├── study/                          # 10 doc di studio (Godot, cozy games, DB, rendering)
└── tests/                          # 112 test invasivi + runner headless
    ├── integration/                 #   8 moduli test (helpers, catalogs, stress, save, spawn, panels, input, ui_events)
    ├── test_runner.gd               #   Harness reflection-based
    └── test_runner.tscn             #   Scene autostart runner
```

---

## Contenuti di gioco

### Stanza

| Stanza | ID | Temi |
|--------|----|----- |
| Cozy Studio | `cozy_studio` | modern, natural, pink |

Il pavimento della stanza è un **rombo isometrico** (4 vertici, non rettangolo)
gestito come `CollisionPolygon2D` + `Helpers.clamp_inside_floor()` per tutti i
clamping. Riferimento: `v1/scenes/main/main.tscn` → `Room/RoomBounds/FloorBounds`.

### Decorazioni: 129 oggetti in 13 categorie

| Categoria | Oggetti | Scala tipica | Placement |
|-----------|---------|--------------|-----------|
| beds | 11 (bed_1-4 + 4 varianti bongseng + 2 kenney + cabinet_bed + cabinet_bed_drawer) | 0.35-3.0 | floor |
| desks | 7 (desk_1-4 + bongseng + kenney + kenney_corner + side_table_drawers) | 1.5-3.0 | floor |
| chairs | 14 (chair_1-4 + 3 bongseng + kenney_chair + chair_cushion/desk/rounded + lounge 2 + stool_bar) | 1.0-3.0 | floor |
| wardrobes | 9 (wardrobe_1-4 + 2 bongseng + kenney bookcase 3 variants + cabinet_television) | 0.6-3.0 | floor |
| windows | 4 (window_1-2 + bongseng + kenney wall_window 2) | 0.45-3.0 | wall |
| wall_decor | 3 (paintings + kenney bathroom_mirror + kenney paneling) | 3.0 | wall |
| potted_plants | 19 (room_plant + 14 SoppyCraft + kenney_potted + 3 kenney_plant_small) | 3.0-6.0 | floor |
| plants | 14 (plant_0 → plant_13 SoppyCraft) | 6.0 | any |
| accessories | 16 (pot, watering_can, shears, scissors, wooden_table, + kenney: books, box×2, laptop, computer_screen, lamps×2, radio, tv×2, bear, trashcan) | 6.0 | floor |
| room_elements | 3 (window_1/2/3) | 3.0 | wall |
| tables | 13 (4 bongseng + 7 kenney tables variants) | 0.5-1.0 | floor |
| doors | 5 (2 bongseng + 3 kenney doorway variants) | 0.4-1.0 | wall |
| pets (hidden) | 1 (Void Cat icon) | 4.0 | floor |

**Interazione**: click decorazione piazzata → popup su CanvasLayer 100:
- **R** Rotate 90° incrementale
- **F** Flip orizzontale
- **S** Scale cicla tra 7 livelli (0.25x, 0.5x, 0.75x, 1.0x, 1.5x, 2.0x, 3.0x)
- **X** Delete (solo in edit mode, abilitato dal toggle "Modalità Modifica")

Tenuto **Shift** durante il drag → disabilita snap 64px per placement pixel-fine.

### Personaggio

| ID | Nome | Tipo |
|----|------|------|
| `male_old` | Ragazzo Classico | Directional (8 dir × 4 anim) |

Pixel art 32×32 con 4 frame per animazione. Direzioni: `down`, `down_side`,
`side`, `up`, `up_side` + auto-mirror orizzontale per `*_sx`. Rotate strip
256×32 (8 frame) per transizioni angolari.

Controllabile con **WASD / frecce**. Movimento `move_and_slide()` + `motion_mode = FLOATING`.
SPEED=120 px/s, diagonale normalizzato. Collisione con layer 1 (muri) + layer 2
(decorazioni, disabilitata in edit mode).

La female character è stata spostata fuori repo (2026-04-17) in attesa di
aseprite directional completi.

### Pet

Scena selezionabile da setting `pet_variant`:
- `simple` → `cat_void.tscn` (16×16 sprite strip 5 frame)
- `iso` → `cat_void_iso.tscn` (32×32 sprite strip 5 frame)

FSM 5 stati: **IDLE** (default) → **WANDER** (wanders inside floor polygon) →
**FOLLOW** (se char si allontana >120px) → **SLEEP** (dopo 2min idle) → **PLAY**
(se char vicino <60px durante sleep).

### Musica + Ambience

| Traccia | Autore | Moods |
|---------|--------|-------|
| `rain_loop` (Light Rain) | Mixkit | calm, neutral |
| `rain_thunder` (Rain & Thunder) | Mixkit | tense |

Auto-play all'avvio. Dual-player crossfade 2s. Mood-driven: quando StressManager
emette `mood_changed(level)`, AudioManager seleziona random tra tracce con `moods`
contenente il livello e crossfada.

Ambience: array vuoto (pronto per future additions, AudioManager supporta
multi-stream ambience).

### Mess system

6 mess types con `stress_weight` 0.05-0.12. `MessSpawner` istanziato in room,
Timer one_shot randomico 60-180s. Max 5 mess concurrent. Spawn in floor polygon
con `Helpers.clamp_inside_floor()`. Pulitura via interazione character → +coins
reward, `mess_cleaned` signal, `-stress_weight`.

Sprite: attualmente placeholder procedurale (cerchio colorato con outline),
in attesa di pixel art finali.

---

## Salvataggio

### JSON locale (`user://save_data.json`, v5.0.0)

Atomic write: temp → rename. Backup precedente in `save_data.backup.json`.
HMAC-SHA256 con chiave device-local in `user://integrity.key` (32 byte random al primo avvio).

Struttura:

```jsonc
{
  "version": "5.0.0",
  "last_saved": "2026-04-17T10:23:45",
  "account": {"auth_uid": "local", "account_id": 1},
  "settings": {"language": "en", "master_volume": 0.8, "pet_variant": "simple", ...},
  "room": {"current_room_id": "cozy_studio", "current_theme": "modern",
           "decorations": [{"item_id", "position", "item_scale", "rotation", "flip_h"}]},
  "character": {"character_id": "male_old", "outfit_id": "",
                "data": {"nome", "genere", "colore_occhi", "livello_stress", ...}},
  "music": {"current_track_index", "playlist_mode": "shuffle", "active_ambience": []},
  "inventory": {"coins": 0, "capacita": 50, "items": []}
}
```

Migrazione automatica: v1 → v2 → v3 (strip obsolete: tools/therapeutic/xp/streak/currency/unlocks/last_active_timestamp/updated_at, preserve coins) → v4 (add inventory section) → v5 (add account section).

### SQLite mirror (`user://cozy_room.db`)

9 tabelle con foreign keys ON + WAL mode + busy_timeout 5000ms:
`accounts`, `characters`, `rooms`, `inventario`, `sync_queue`, `settings`,
`save_metadata`, `music_state`, `placed_decorations`.

Migrazione 1 (characters legacy no-`character_id`): backup `characters_bak` + `inventario_bak` pre-DROP per rollback.
Migrazione 2: `ALTER TABLE accounts ADD COLUMN` per display_name/updated_at/password_hash/deleted_at/coins/inventario_capacita.
Migrazione 3: `ALTER TABLE inventario ADD COLUMN` per item_type/is_unlocked/acquired_at.

Dettaglio schema: **[data/README.md](data/README.md)**.

---

## CI/CD

`.github/workflows/`:

| Workflow | Trigger | Job |
|----------|---------|-----|
| `ci.yml` | push/PR su `main` paths `v1/**` o `ci/**` | 9 job paralleli/sequenziali |
| `build.yml` | push su `main`, tag `v*` | export Windows + HTML5 via godot-ci:4.6 |
| `pages.yml` | push su `main` paths `docs/**` | Netlify landing page |

### CI jobs (`ci.yml`)

1. **lint** — `gdlint` + `gdformat --check` su scripts + tests
2. **validate-json** — struttura + vincoli 5 catalog JSON
3. **validate-sprites** — 100+ sprite_path esistenza filesystem
4. **validate-crossrefs** — constants.gd CHAR_* / ROOM_* / THEME_* ↔ catalog IDs
5. **validate-db** — sintassi `CREATE TABLE` SQL statements
6. **validate-signals** — SignalBus signal count ≥ 40 + no duplicates
7. **validate-pixelart** — palette sync + deliverable size/naming
8. **smoke-headless** — boot Godot 4.6 headless, 0 parse/script errors
9. **deep-tests** — `test_runner.tscn`, 112 test, gated su smoke-headless

Container build: `barichello/godot-ci:4.6`.

---

## Testing

```bash
./scripts/smoke_test.sh          # boot headless ~2s
./scripts/preflight.sh           # 8 step GO/NO-GO demo readiness
./scripts/godot-validate.sh      # ciclo completo re-import + runtime 15s
./scripts/deep_test.sh           # 112 test invasivi ~7s
```

Dettaglio test: **[tests/README.md](tests/README.md)**.

---

## Sviluppo

### Convenzioni codice

- **Linguaggio codice**: inglese (variabili, funzioni, commenti)
- **Documentazione**: italiano
- **Stile GDScript**: conforme `gdtoolkit` v4 (max-line-length 120, max-function-length 50, max-file-length 500)
- **Texture filter**: NEAREST su ogni sprite/sub-resource
- **Sprite anchor convenzione**: le decorazioni sono `Sprite2D.centered=false`, anchor effettivo = bottom-center (vedi `decoration_system._floor_anchor_offset`)

### Branch + workflow

- Branch unico attivo: **`main`**
- Ogni modifica: branch locale → PR → CI green → merge
- Commit semantici: `feat(area):`, `fix(area):`, `docs:`, `chore:`, `test:`, `ci:`

### Pattern codificati (non violare)

1. **Godot 4.6 obbligatorio** — project.godot dichiara features "4.6"
2. **Floor polygon è source of truth** per tutti i clamping. Viewport rect è deprecato
3. **Focus chain**: Button default FOCUS_ALL intercetta `ui_*` → blocca movement. Tutti i Button creati via script devono avere `focus_mode = FOCUS_NONE` (se non richiedono keyboard nav)
4. **Drag sorgenti NON extend Button** — usare `TextureRect` o `MarginContainer`. `DecoButton extends TextureRect` perché Button.`_pressing_inside` interferisce con Godot 4 drag detection
5. **CanvasLayer input routing**: ogni VBoxContainer/HBoxContainer/MarginContainer con rect full-screen o in zona panel DEVE avere `mouse_filter = IGNORE` se non deve intercettare clicks
6. **HMAC save integrity**: non cambiare path `user://integrity.key` altrimenti tutti i save esistenti diventano non-validi
7. **Pattern SignalBus**: tutti i listener disconnettono in `_exit_tree()`. Lambda con capture ON autoload = zombie al reload

---

## Sistema account

| Modalità | Descrizione |
|----------|-------------|
| **Guest** | Gioca senza account, dati solo locali, auth_uid="local" |
| **Registrato** | Username + password PBKDF2-v2, dati locali + Supabase (se configurato) |

Flusso: Auth Screen al primo avvio → Login / Registrazione / Guest → Gameplay.
Profile panel (HUD Profilo button) → elimina personaggio / elimina account / logout.

Anti-brute-force: **5 tentativi** falliti → lockout **300s** per username.

### Supabase integration (off di default)

- `user://config.cfg` deve contenere `url` HTTPS + `anon_key` per attivare
- Session JWT+refresh_token cifrati con chiave derivata da `OS.get_user_data_dir() + salt`
- Sync 5 tabelle cloud: `profiles`, `user_currency`, `user_settings`, `music_preferences`, `room_decorations`
- Retry exp backoff, queue cap 500 in-memory + SQLite sync_queue persistente

---

## Roadmap post-demo

| # | Task | Priorità |
|---|------|----------|
| 1 | Supabase project setup + schema migrations versionate | Alta |
| 2 | Dual-write completo (B-016): SaveManager scrive TUTTE le 9 tabelle | Alta |
| 3 | Mood visual effects (filter gloomy, rain particles, cat wild mode) | Media |
| 4 | Badge system + catalog SQLite | Media |
| 5 | i18n reale .po files (refactor tr() su 50+ stringhe) | Media |
| 6 | PBKDF2 10k → 100k iter migration on login | Bassa |
| 7 | Split `local_database.gd` 831 righe per tabella | Bassa (debito) |
| 8 | virtual_joystick USE/REMOVE decision (desktop-only?) | Bassa |

---

## Asset + licenze

Riassunto. Dettagli per pack: `assets/*/README.md`.

| Pack | Autore | Licenza | Uso commerciale | Restrizioni |
|------|--------|---------|-----------------|-------------|
| Free Pixel Art Forest | Eder Muniz | Custom | ✅ con credito | No redistribuzione |
| Indoor Plants Pack | SoppyCraft | Custom | ✅ | No redistribuzione, no AI training |
| Isometric Room Builder | Thurraya | Custom | ✅ | No redistribuzione, no AI/NFT |
| Kenney Furniture Kit CC0 | Kenney | CC0 1.0 | ✅ | Nessuna (dominio pubblico) |
| Kenney Pixel UI Pack | Kenney | CC0 1.0 | ✅ | Nessuna |
| Mixkit Rain Sounds | Mixkit | Free License | ✅ | Nessuna |
| Puny Characters (scaffolding) | Unknown CC0 | CC0 | ✅ | Nessuna (solo per scaffolding Alex) |
| Personaggi/Menu/Room/Pet | Ex-membro team | Progetto IFTS | Uso interno | Accademico |

---

*Ultimo aggiornamento: 2026-04-17 — post deep-read + fix toast/dropzone/decobutton.*
