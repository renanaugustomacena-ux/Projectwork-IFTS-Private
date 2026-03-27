# Mini Cozy Room — Project Deep Dive

A comprehensive study of the project: its vision, architecture, how every component connects, and the design decisions behind it.

---

## 1. The Vision

### What Is Mini Cozy Room?

Mini Cozy Room is a **desktop companion** — a small, always-running application designed to sit in the corner of your screen while you study or work. Think of it as a digital aquarium, but instead of fish, you have a cozy pixel art room with a character, lo-fi music, and customizable decorations.

### The Desktop Companion Genre

Desktop companions are a niche but beloved genre. Notable examples:
- **Shimeji** — Characters that walk on your desktop
- **Desktop Goose** — A goose that interferes with your work
- **Spirit** (Steam) — A virtual pet on your desktop
- **Lo-fi Girl** (YouTube) — The iconic studying animation that inspired millions

Mini Cozy Room takes the "lo-fi study atmosphere" concept and makes it interactive. Instead of just watching a loop, you customize your own room, choose your character, and play your own music.

### Target Audience

Students, remote workers, and anyone who wants a calming digital presence during focused work sessions. The app is designed to be:
- **Unobtrusive** — Low FPS when not focused (15 FPS background, 60 FPS foreground)
- **Offline-first** — Works completely without internet
- **Lightweight** — Minimal resource usage
- **Customizable** — Your room, your decorations, your music

### Core Pillars

1. **Relaxation** — Everything should feel calm and cozy
2. **Personalization** — The room should feel like YOUR space
3. **Low Friction** — It should "just work" without configuration
4. **Pixel Art Aesthetic** — Consistent, nostalgic visual style

---

## 2. Architecture Overview

### The Big Picture

```
┌──────────────────────────────────────────────────────────────┐
│                    GODOT ENGINE 4.5                          │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  SCENES     │  │  AUTOLOADS   │  │  DATA FILES        │  │
│  │  (.tscn)    │  │  (Singletons)│  │  (.json)           │  │
│  │             │  │              │  │                    │  │
│  │ main_menu   │  │ SignalBus    │  │ rooms.json         │  │
│  │ main (room) │  │ AppLogger    │  │ decorations.json   │  │
│  │ panels (x4) │  │ GameManager  │  │ characters.json    │  │
│  │ characters  │  │ SaveManager  │  │ tracks.json        │  │
│  │             │  │ LocalDatabase│  │ supabase_migration │  │
│  │             │  │ AudioManager │  │                    │  │
│  │             │  │ SupabaseClient│ │                    │  │
│  │             │  │ PerfManager  │  │                    │  │
│  └──────┬──────┘  └──────┬───────┘  └────────┬───────────┘  │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│                  ┌───────▼───────┐                           │
│                  │   SIGNAL BUS  │                           │
│                  │  (21 signals) │                           │
│                  │               │                           │
│                  │ The nervous   │                           │
│                  │ system of the │                           │
│                  │ entire app    │                           │
│                  └───────────────┘                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                    PERSISTENCE                        │    │
│  │  ┌──────────────┐  ┌────────────┐  ┌──────────────┐  │    │
│  │  │ JSON File    │  │  SQLite DB │  │  Supabase    │  │    │
│  │  │ (primary)    │  │  (mirror)  │  │  (optional)  │  │    │
│  │  │ save_data.json│ │ cozy_room.db│ │  cloud sync  │  │    │
│  │  └──────────────┘  └────────────┘  └──────────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Design Philosophy: Signal-Driven Architecture

The most important architectural decision in Mini Cozy Room is that **no component directly calls another component**. Instead, they communicate through signals via the `SignalBus`.

**Why this matters:**

Imagine an office where every employee has to physically walk to another person's desk to ask them something. If someone is on vacation (removed from the scene tree), the person walking over crashes into an empty desk. Now imagine an office with an intercom system: you announce what you need, and whoever is listening handles it. If nobody is listening, nothing bad happens.

The SignalBus is the intercom system. The 21 signals are organized by domain:

| Domain | Signals | Purpose |
|--------|---------|---------|
| Room | `room_changed`, `decoration_placed`, `decoration_removed`, `decoration_moved` | Room state changes |
| Character | `character_changed`, `outfit_changed` | Character selection |
| Audio | `track_changed`, `track_play_pause_toggled`, `ambience_toggled`, `volume_changed` | Music control |
| UI | `panel_opened`, `panel_closed`, `shop_item_selected`, `decoration_mode_changed` | Interface events |
| Persistence | `save_requested`, `save_completed`, `load_completed`, `save_to_database_requested` | Save/load lifecycle |
| Settings | `settings_updated`, `music_state_updated`, `language_changed` | Configuration |
| Auth | `user_authenticated`, `user_signed_out`, `auth_error` | Cloud authentication |

### Autoload Initialization Order

Autoloads are singletons loaded in a specific order at startup. The order matters because later autoloads depend on earlier ones:

```
1. SignalBus      ← First: the communication backbone (no dependencies)
2. AppLogger      ← Second: logging (needs SignalBus for nothing, but everything else needs Logger)
3. GameManager    ← Third: loads catalogs from JSON, sets initial state
4. SaveManager    ← Fourth: loads saved game, updates GameManager state
5. LocalDatabase  ← Fifth: opens SQLite, connects to save_to_database_requested
6. AudioManager   ← Sixth: loads tracks from GameManager, restores state from SaveManager
7. SupabaseClient ← Seventh: optional cloud sync (degrades gracefully if not configured)
8. PerfManager    ← Eighth: FPS management (needs SaveManager for window position)
```

---

## 3. The Data Flow

### How a Game Session Works

```
                    ┌──────────────┐
                    │  APP STARTS  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Autoloads   │
                    │  initialize  │
                    │  in order    │
                    └──────┬───────┘
                           │
                    ┌──────▼──────────────┐
                    │  GameManager loads   │
                    │  JSON catalogs:      │
                    │  rooms, decorations, │
                    │  characters, tracks  │
                    └──────┬──────────────┘
                           │
                    ┌──────▼──────────────┐
                    │  SaveManager loads   │
                    │  save_data.json      │
                    │  (migrates if needed)│
                    │  Updates GameManager │
                    │  state               │
                    └──────┬──────────────┘
                           │
                    ┌──────▼──────────────┐
                    │  Emits               │
                    │  load_completed      │
                    │  signal              │
                    └──────┬──────────────┘
                           │
              ┌────────────┼────────────────┐
              │            │                │
      ┌───────▼──────┐ ┌──▼──────────┐ ┌───▼──────────┐
      │ AudioManager │ │ PerfManager │ │ GameManager   │
      │ restores     │ │ restores    │ │ emits         │
      │ music state  │ │ window pos  │ │ room_changed  │
      │ starts music │ │             │ │ char_changed  │
      └──────────────┘ └─────────────┘ └───────────────┘
                           │
                    ┌──────▼──────────────┐
                    │  main_menu.tscn     │
                    │  (Menu Scene)       │
                    │  Player sees menu   │
                    └──────┬──────────────┘
                           │ Player clicks "Nuova Partita"
                    ┌──────▼──────────────┐
                    │  main.tscn          │
                    │  (Room Scene)       │
                    │  Room + character + │
                    │  HUD appear         │
                    └─────────────────────┘
```

### The Save System: Three Layers of Persistence

```
Layer 1: JSON File (Primary)
├── save_data.json — Human-readable, always works offline
├── Versioned (v4.0.0) with automatic migration chain
├── Auto-saves every 60 seconds (if dirty)
└── Manual save on any state change

Layer 2: SQLite Database (Mirror)
├── cozy_room.db — Structured relational data
├── 7 tables mirroring JSON structure
├── WAL mode for performance
├── Foreign keys for integrity
└── Triggered via save_to_database_requested signal

Layer 3: Supabase (Cloud — Optional)
├── PostgreSQL on the cloud
├── REST API via SupabaseClient
├── Graceful degradation if unavailable
└── Row-Level Security (RLS) for multi-user
```

**Why three layers?** Redundancy and flexibility. The JSON file is the source of truth — it always works, even without SQLite or internet. SQLite provides structured queries (useful for inventory management and statistics). Supabase enables cloud sync across devices (future feature).

### The Catalog-Driven Content System

All game content (rooms, decorations, characters, music) is defined in JSON files, not hardcoded. This is the **catalog-driven** pattern:

```
data/rooms.json ─────► GameManager.rooms_catalog
data/decorations.json ► GameManager.decorations_catalog
data/characters.json ─► GameManager.characters_catalog
data/tracks.json ─────► GameManager.tracks_catalog
```

**Why this matters:** To add a new room, you edit a JSON file — no code changes needed. To add a new decoration, you add an entry to `decorations.json` and drop the sprite in the assets folder. The game dynamically reads these catalogs and builds the UI from them.

Example from `decorations.json`:
```json
{
  "id": "lamp_desk_01",
  "name": "Desk Lamp",
  "category": "accessories",
  "sprite_path": "res://assets/sprites/decorations/...",
  "scale": 6.0,
  "placement": "floor"
}
```

The shop panel reads this catalog, builds buttons dynamically, and when the player drags a decoration, it reads `sprite_path` and `scale` to create the sprite in the room.

---

## 4. Scene Architecture

### Scene Hierarchy: Main Menu

```
MainMenu (Node2D)
│
├── ForestBackground (Node2D, window_background.gd)
│   └── 8 Sprite2D layers with parallax scrolling
│       Each layer moves at a different speed
│       creating the illusion of depth
│
├── MenuCharacter (Node2D, menu_character.gd)
│   └── Sprite2D that plays a walk-in animation
│       randomly selects a character, walks across screen
│       uses Timer for frame animation + Tween for movement
│
├── LoadingScreen (ColorRect)
│   └── Full-screen overlay that fades out on load
│
└── UILayer (CanvasLayer, layer=10)
    └── ButtonContainer (VBoxContainer)
        ├── NuovaPartitaBtn → starts new game
        ├── CaricaPartitaBtn → loads saved game
        ├── OpzioniBtn → opens settings
        └── EsciBtn → quits
```

### Scene Hierarchy: Room (Gameplay)

```
Main (Node2D, main.gd)
│
├── WallRect (ColorRect) ─── top 40% of screen
├── FloorRect (ColorRect) ── bottom 60% of screen
├── Baseboard (ColorRect) ── 2px horizontal divider
│
│   The room is NOT a pre-made image. It's built from
│   two colored rectangles (wall + floor) whose colors
│   come from the theme palette in rooms.json
│
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)
│   │   └── [Dynamically spawned Sprite2D nodes]
│   │       Each decoration is a Sprite2D with
│   │       decoration_system.gd for drag interaction
│   │
│   ├── Character (CharacterBody2D)
│   │   └── Instanced from male/female-character.tscn
│   │       character_controller.gd handles WASD movement
│   │       AnimatedSprite2D for walk/idle animations
│   │
│   └── RoomBounds (StaticBody2D)
│       └── 4 CollisionShape2D forming invisible walls
│           Prevents character from walking off-screen
│
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, full rect)
│   │   └── Handles drag-and-drop of decorations
│   │       Validates placement (wall vs floor zones)
│   │       Prevents overlapping decorations
│   │
│   └── HUD (HBoxContainer)
│       ├── MusicButton → toggles music panel
│       ├── DecoButton → toggles decoration panel
│       ├── SettingsButton → toggles settings panel
│       └── ShopButton → toggles shop panel
│
├── PanelManager (Node, created programmatically)
│   └── Manages panel lifecycle:
│       - Only one panel open at a time
│       - Fade in/out transitions via Tween
│       - Panels are instantiated and destroyed, not hidden
│
└── AudioStreams (Node)
    └── Container for AudioStreamPlayer nodes
```

---

## 5. Key Systems Explained

### The Decoration System

The decoration system is the core gameplay mechanic. Here's how it works:

```
Player opens Shop Panel
         │
         ▼
Shop builds from decorations_catalog
Each item shows: sprite, name, category
         │
         ▼
Player drags item from shop
         │
         ▼
DropZone._can_drop_data() validates:
  - Is it a valid drag data?
  - Is the position in the correct zone? (wall items on wall, floor items on floor)
  - Does it overlap too much with existing decorations?
         │
         ▼
DropZone._drop_data() places the item:
  - Creates a Sprite2D with the decoration's texture
  - Attaches decoration_system.gd for interaction
  - Emits decoration_placed signal
  - SaveManager records the placement
         │
         ▼
In the room, player can:
  - Left-click + drag to move decorations
  - Right-click to remove decorations
  - Both actions trigger save_requested
```

### The Audio System

AudioManager implements a dual-player crossfade system:

```
Player A ────────╲
                  ╲──── Output
Player B ────────╱
                 ╱
         Crossfade Tween

When changing tracks:
1. New track loads into the INACTIVE player
2. Tween fades active player volume DOWN (-80 dB)
3. Simultaneously fades inactive player volume UP
4. After tween completes, swap active/inactive references
```

This ensures seamless transitions between tracks with no audio gap.

The ambience system runs independently — multiple `AudioStreamPlayer` nodes can play simultaneously (rain, thunder, birds), each controlled by toggle buttons in the music panel.

### The Character Movement System

```
Input (WASD / Arrow Keys)
         │
         ▼
CharacterBody2D.velocity = direction * SPEED
         │
         ▼
move_and_slide() handles collision with RoomBounds
         │
         ▼
_update_animation() selects the correct animation:
  - Based on direction vector
  - 8 possible directions mapped to animation names
  - Horizontal flip for left/right symmetry
```

The character uses `CharacterBody2D` (not `RigidBody2D`) because we want direct control over movement, not physics simulation. `move_and_slide()` handles collision detection automatically, bouncing the character off the invisible walls defined by `RoomBounds`.

---

## 6. The Rendering Pipeline

### Why GL Compatibility Renderer?

Godot 4 offers three renderers:
1. **Forward+** (Vulkan) — Full features, high GPU requirements
2. **Mobile** (Vulkan) — Reduced features, moderate GPU
3. **GL Compatibility** (OpenGL 3.3) — Basic features, runs on almost anything

Mini Cozy Room uses **GL Compatibility** because:
- Desktop companion = runs alongside other apps = minimal GPU usage
- Pixel art doesn't need advanced lighting, shadows, or post-processing
- Maximum hardware compatibility (works on integrated GPUs, old laptops)
- Web export (HTML5) only supports GL Compatibility

### Pixel Art Rendering

For pixel art to look crisp (not blurry), specific settings are required:

```
project.godot settings:
  rendering/textures/canvas_textures/default_texture_filter = 0  (Nearest)
  display/window/size/viewport_width = 1280
  display/window/size/viewport_height = 720
  display/window/stretch/mode = "canvas_items"

Per-sprite settings:
  texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

Why Nearest (not Linear)?
  Linear:  pixel → blurred smudge (samples neighboring pixels)
  Nearest: pixel → crisp square (picks closest pixel, no interpolation)
```

### The Dynamic FPS System

```
┌─────────────────┐     ┌──────────────────┐
│ Window focused  │     │ Window unfocused  │
│ Engine.max_fps  │     │ Engine.max_fps    │
│ = 60            │     │ = 15              │
│                 │     │                   │
│ Full interaction│     │ Minimal updates   │
│ Smooth animation│     │ Saves CPU/GPU     │
│                 │     │ Battery friendly   │
└────────┬────────┘     └────────┬──────────┘
         │                       │
         └───────────┬───────────┘
                     │
              focus_entered /
              focus_exited
              viewport signals
```

This is essential for a desktop companion — if the app ran at 60 FPS even in the background, it would drain battery and compete with the user's actual work.

---

## 7. The Panel System

Panels (Music, Decorations, Settings, Shop) share a common lifecycle managed by `PanelManager`:

```
HUD Button Click
       │
       ▼
PanelManager.toggle_panel(name)
       │
       ├── Is another panel open?
       │   YES → close it (fade out + queue_free)
       │
       ├── Is THIS panel already open?
       │   YES → close it (toggle behavior)
       │
       └── Open the panel:
           1. Instantiate the panel scene
           2. Set modulate.a = 0 (transparent)
           3. Add to UILayer
           4. Create tween: fade alpha 0 → 1
           5. Emit panel_opened signal
```

Each panel is a `PanelContainer` with programmatically built UI. They don't use .tscn files for their contents — everything is created in code (`_build_ui()`). This was a deliberate choice to keep the UI flexible and catalog-driven (the shop panel builds its grid from the decorations catalog dynamically).

---

## 8. Save Data Format

The save file (`user://save_data.json`) at version 4.0.0:

```json
{
  "version": "4.0.0",
  "last_saved": "2026-03-21T15:30:00",
  "settings": {
    "language": "en",
    "display_mode": "windowed",
    "master_volume": 0.8,
    "music_volume": 0.6,
    "ambience_volume": 0.4,
    "window_pos_x": 100,
    "window_pos_y": 200
  },
  "room": {
    "current_room_id": "cozy_studio",
    "current_theme": "modern",
    "decorations": [
      {
        "item_id": "lamp_desk_01",
        "position": {"x": 400, "y": 500},
        "z_index": 5
      }
    ]
  },
  "character": {
    "character_id": "female_red_shirt",
    "outfit_id": "",
    "data": {
      "nome": "My Character",
      "genere": true,
      "livello_stress": 0
    }
  },
  "music": {
    "current_track_index": 0,
    "playlist_mode": "shuffle",
    "active_ambience": ["rain_light"]
  },
  "inventory": {
    "coins": 150,
    "capacita": 50,
    "items": [
      {"item_id": "plant_01", "quantity": 1}
    ]
  }
}
```

### Version Migration Chain

```
v1.0.0 → v2.0.0 → v3.0.0 → v4.0.0 (current)

v3 → v4 migration:
  - Removed: tools, therapeutic, xp, streak, currency, unlocks
  - Added: inventory with coins, capacita, items
  - Preserved: coins from old currency section
```

The migration is **chained** — the code applies each migration in sequence. If someone has a v1.0.0 save, it goes through all three migrations to reach v4.0.0. This ensures backward compatibility regardless of how old the save file is.

---

## 9. Content Inventory

### Current Assets

| Category | Count | Format | Source |
|----------|-------|--------|--------|
| Rooms | 4 (10 themes) | JSON + color palettes | Custom |
| Decorations | 118 (14 categories) | PNG sprites | CC0 / Commercial |
| Characters | 3 playable | Spritesheets (PNG) | CC0 |
| Music | 2 tracks | WAV | Mixkit (Free) |
| Ambience | Configurable | WAV | Mixkit (Free) |
| UI | Full pixel UI kit | PNG | Kenney (CC0) |
| Backgrounds | 8-layer forest | PNG | Eder Muniz |
| Pets | 1 (Void Cat) | PNG | CC0 |

### License Compliance

Every asset has specific license terms documented in `v1/assets/README.md`. The project uses only:
- **CC0** (public domain) — No restrictions
- **Free for commercial use** — With or without credit
- **No redistribution of raw assets** — Must be in a game/product

No GPL or copyleft assets are used, avoiding license contamination.

---

## 10. What Makes This Project Educational

Mini Cozy Room is designed as an **IFTS academic project**, which means it serves dual purposes:

1. **A real product** — It should work, be polished, and be distributable
2. **A learning platform** — It covers a wide range of software engineering topics

### Topics Covered by This Project

| Topic | Where in the Project |
|-------|---------------------|
| Software Architecture | Signal-driven, singleton pattern, separation of concerns |
| Database Design | SQLite schema, foreign keys, migrations |
| API Integration | Supabase REST client, HTTP pooling, auth tokens |
| CI/CD | GitHub Actions, linting, automated testing |
| Version Control | Git, branching, collaborative workflow |
| Testing | GdUnit4, unit tests, test-driven development |
| Security | Secret scanning, .env management, input validation |
| Performance | FPS capping, memory leak prevention, profiling |
| User Experience | Pixel art consistency, audio design, smooth transitions |
| Data Persistence | JSON save files, versioned migrations, backup/restore |
| Team Management | Role assignment, code review, documentation |

---

## 11. FAQ — Domande Frequenti sull'Architettura

Domande che potreste ricevere in sede d'esame o che aiutano a capire le scelte del progetto.

### Perche' SQLite e non un database server (MySQL, PostgreSQL)?

SQLite e' un database **embedded**: vive in un singolo file dentro la cartella dell'utente, non richiede un server separato. Per un desktop companion che deve funzionare offline e avviarsi in pochi secondi, e' la scelta ideale. Un database server richiederebbe installazione, configurazione e un processo sempre attivo — complessita' non giustificata per un'app che salva dati di un singolo utente locale.

**Quando SQLite NON basta**: se il gioco dovesse supportare multiplayer in tempo reale con migliaia di utenti simultanei, servirebbe un database server. Per questo esiste Supabase (PostgreSQL) come layer opzionale.

### Perche' JSON + SQLite insieme (doppia persistenza)?

Il salvataggio JSON (`user://save_data.json`) e' **veloce da leggere e scrivere**, e il formato e' leggibile da un umano con un editor di testo. Ma JSON non supporta query complesse, relazioni tra dati, o transazioni atomiche.

SQLite gestisce dati relazionali (personaggi che appartengono ad account, oggetti nell'inventario con foreign key) con garanzie di integrita'. Il JSON e' il "salvataggio rapido", SQLite e' il "database strutturato". Entrambi vengono scritti in `save_game()` per ridondanza.

### Perche' GL Compatibility e non Vulkan?

Il renderer GL Compatibility usa OpenGL ES 3.0, supportato da praticamente qualsiasi hardware degli ultimi 15 anni, incluse schede video integrate Intel. Vulkan offre prestazioni superiori ma richiede hardware piu' recente e driver aggiornati. Per un'app pixel art 2D a basso consumo, GL Compatibility e' la scelta corretta: massima compatibilita', zero overhead grafico non necessario.

### Perche' i segnali invece di chiamate dirette?

I segnali implementano il **pattern Observer**: il produttore non conosce i consumatori. Se AudioManager emette `track_changed`, non deve sapere se SaveManager, un pannello UI, o nessuno e' in ascolto. Questo permette di:
- Aggiungere/rimuovere funzionalita' senza toccare il codice esistente
- Testare ogni sistema in isolamento (mock dei segnali)
- Evitare dipendenze circolari tra autoload

Il costo e' una leggera indirezione: per capire "chi reagisce a questo segnale" dovete cercare `connect` nel progetto.

---

## 12. Flusso Completo: "Dal Click alla Decorazione Salvata"

Traccia completa di cosa succede quando l'utente posiziona una decorazione nella stanza.

```text
UTENTE: trascina un oggetto dal pannello inventario alla stanza

1. InventoryPanel._on_item_drag_started(item_data)
   └── Crea un drag preview (TextureRect con lo sprite dell'oggetto)
       └── Il nodo drag preview viene aggiunto alla scena temporaneamente

2. DropZone._can_drop_data(position, data) → true
   └── Verifica che il dato trascinato sia valido (ha item_id, sprite_path)
   └── Verifica che la posizione sia all'interno della griglia della stanza

3. DropZone._drop_data(position, data)
   └── Calcola posizione snap: Helpers.snap_to_grid(position)  → griglia 64px
   └── Emette: SignalBus.decoration_placed.emit(item_data, snapped_pos)

4. SignalBus.decoration_placed  →  ascoltatori reagiscono:

   4a. DecorationSystem._on_decoration_placed(item_data, pos)
       └── Crea un nodo Sprite2D per la decorazione
       └── Imposta posizione, scala, texture
       └── Aggiunge il nodo alla scena (come figlio del container decorazioni)
       └── Aggiorna l'array interno _placed_decorations

   4b. SaveManager._on_decoration_placed(item_data, pos)
       └── Imposta _is_dirty = true  (flag "ci sono modifiche non salvate")

5. Auto-save timer (ogni 60 secondi) controlla _is_dirty
   └── _is_dirty e' true → chiama save_game()

6. SaveManager.save_game()
   └── Serializza TUTTI i dati di gioco in un Dictionary
   └── Scrive JSON su user://save_data.json (con backup atomico)
   └── Scrive su SQLite via LocalDatabase.save_room_state()
   └── Imposta _is_dirty = false
   └── Emette: SignalBus.save_completed.emit()
```

**Punti critici** (dove i bug del report si manifestano):
- **Passo 3**: Se `Helpers.snap_to_grid()` non arrotonda correttamente → decorazione fuori griglia
- **Passo 4a**: Se `_exit_tree()` manca in DecorationSystem → memory leak alla chiusura
- **Passo 6**: Se il salvataggio JSON fallisce ma SQLite riesce (o viceversa) → dati inconsistenti

---

## 13. Errori Architetturali da Evitare

Anti-pattern specifici di questo progetto. Se li riconoscete nel vostro codice, correggete subito.

### Usare `_init()` per inizializzare autoload

```gdscript
# SBAGLIATO — gli altri autoload potrebbero non essere pronti
func _init() -> void:
    SignalBus.room_changed.connect(_on_room)  # SignalBus potrebbe non esistere!

# CORRETTO — _ready() garantisce che tutti gli autoload precedenti siano pronti
func _ready() -> void:
    SignalBus.room_changed.connect(_on_room)
```

### Gestire pannelli fuori da PanelManager

```gdscript
# SBAGLIATO — crea un pannello "selvaggio" che PanelManager non conosce
var panel = preload("res://scenes/ui/settings.tscn").instantiate()
add_child(panel)

# CORRETTO — solo PanelManager gestisce i pannelli
SignalBus.panel_opened.emit("settings")
# PanelManager reagisce al segnale e crea il pannello
```

### Hardcodare contenuti invece di usare i cataloghi

```gdscript
# SBAGLIATO — se il personaggio viene rinominato, questo codice si rompe
if character_name == "male_brown_hair":
    speed = 120

# CORRETTO — leggi dal catalogo
var char_data: Dictionary = GameManager.character_catalog.get(character_id, {})
var speed: int = char_data.get("speed", Constants.DEFAULT_SPEED)
```

### Modificare variabili di altri autoload direttamente

```gdscript
# SBAGLIATO — coupling diretto, viola l'architettura a segnali
SaveManager.game_data["settings"]["volume"] = 0.5

# CORRETTO — emetti un segnale, lascia che SaveManager reagisca
SignalBus.settings_updated.emit({"volume": 0.5})
```

---

## 14. Domande di Auto-Studio

Provate a rispondere senza guardare il codice. Poi verificate la vostra risposta leggendo i file indicati.

1. **Quanti segnali ha il SignalBus?** Elencatene almeno 10 con il loro scopo. *(Verifica: `scripts/autoload/signal_bus.gd`)*

2. **In che ordine vengono caricati gli autoload?** Perche' l'ordine e' importante? *(Verifica: `project.godot`, sezione [autoload])*

3. **Cosa succede se chiudete il gioco senza salvare manualmente?** I dati vengono persi? *(Verifica: `scripts/autoload/save_manager.gd`, funzione `_notification()`)*

4. **Perche' le decorazioni hanno un campo `placement_type`?** Cosa succederebbe se un oggetto "wall" venisse posizionato sul pavimento? *(Verifica: `data/decorations.json`, `scripts/rooms/decoration_system.gd`)*

5. **Quante tabelle ha il database SQLite?** Per ognuna, qual e' la PRIMARY KEY? *(Verifica: `scripts/autoload/local_database.gd`, funzione `_create_tables()`)*

6. **Come fa il gioco a sapere quale personaggio mostrare all'avvio?** Traccia il flusso dal salvataggio al rendering. *(Verifica: `save_manager.gd` → `game_manager.gd` → `room_base.gd`)*

7. **Cosa succederebbe se rimuoveste SignalBus dal progetto?** Quali sistemi si romperebbero e perche'? *(Ragionamento: pensate a tutti i `SignalBus.*.connect()` nel codebase)*

---

*Study document for Mini Cozy Room — IFTS Projectwork 2026*
*Author: Renan Augusto Macena (System Architect & Project Supervisor)*
