# Relax Room — Scene Godot

**17 scene** `.tscn` che definiscono le gerarchie di nodi, composizione componenti
e layout UI. Le scene vivono accanto ai loro script in `v1/scripts/*/`.

## Struttura directory

```
scenes/
├── main/
│   └── main.tscn                 # Stanza di gameplay (entry dopo menu)
├── menu/
│   ├── main_menu.tscn            # Scena di avvio (project.godot run/main_scene)
│   ├── auth_screen.tscn          # Overlay auth programmatica
│   └── character_select.tscn     # Preview carousel (bypassed se 1 char)
├── ui/
│   ├── deco_panel.tscn           # Panel drag-drop decorazioni
│   ├── settings_panel.tscn       # Volume sliders + lingua (nascosta)
│   ├── profile_panel.tscn        # Account info + delete char/account
│   ├── profile_hud_panel.tscn    # Mini panel top-right (mood slider + lang)
│   └── virtual_joystick.tscn     # Addon CF Studios touch joystick
├── room/
│   └── windows/
│       ├── window1.tscn          # 32×64 finestra piccola
│       ├── window2.tscn          # 48×64 finestra media
│       └── window3.tscn          # 64×64 finestra grande
├── male-old-character.tscn       # Personaggio attivo (directional 8 dir)
├── cat_void.tscn                 # Pet variant 'simple' (16×16)
└── cat_void_iso.tscn             # Pet variant 'iso' (32×32)
```

**Note**:
- `female-character.tscn` rimossa 2026-04-17 (asset female moved outside repo).
- `loading_screen.tscn` referenziata da `main_menu.gd` ma **non esiste** —
  fallback a Label procedurale (vedi `main_menu._setup_graphical_loading_screen`).

## Scene dettagliate

### `main/main.tscn` — Stanza di gameplay

**Root**: `Main` (Node2D) — Script: `scripts/main.gd`

```
Main (Node2D)
├── RoomBackground (Sprite2D)                 # room.png 180×155, scaled to viewport
├── WallRect (ColorRect anchor_bottom=0.4)    # mouse_filter=IGNORE, overlay alpha 0.6
├── FloorRect (ColorRect anchor_top=0.4)      # mouse_filter=IGNORE, overlay alpha 0.6
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)                  # Container per deco spawned
│   ├── Character (instance male-old-character.tscn, pos=(640, 448))
│   └── RoomBounds (StaticBody2D)
│       └── FloorBounds (CollisionPolygon2D)  # rombo isometrico 4 vertici
├── RoomGrid (Node2D, room_grid.gd)           # visible solo in edit mode
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control full-rect, mouse_filter=PASS)
│   │                                         # riceve _drop_data decorazioni
│   └── HUD (HBoxContainer anchor bottom 44px)
│       ├── MenuButton "Menu"
│       ├── DecoButton "Decora"
│       ├── SettingsButton "Opzioni"
│       └── ProfileButton "Profilo"
└── AudioStreams (Node)                       # (vuoto, runtime populated)

Runtime additions da main.gd._ready:
├── PanelManager (Node, programmatico)
├── ToastManager (CanvasLayer layer=90)       # toast notifications
└── GameHud (CanvasLayer layer=50)            # serenity bar + coin + profile btn
```

Floor polygon reale: `PackedVector2Array(640, 265, 1100, 480, 640, 685, 180, 480)` (rombo).

**Pattern**: I colori wall/floor sono **ColorRect con alpha 0.6** sovrapposti al
`RoomBackground` sprite. I temi modificano solo il colore del rect, non la sprite.

### `menu/main_menu.tscn` — Menu principale

**Root**: `MainMenu` (Node2D) — Script: `scripts/menu/main_menu.gd`

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)  # 8 layer parallasse
├── DimOverlay (ColorRect alpha 0.35)                # oscura la foresta
├── LoadingScreen (ColorRect z_index=100)            # fade in/out al boot
├── MenuCharacter (Node2D, menu_character.gd)        # walk-in animato
└── UILayer (CanvasLayer layer=10)
    └── ButtonContainer (VBoxContainer centrato)
        ├── TitleLabel "Relax Room"
        ├── Spacer (Control 16px)
        ├── NuovaPartitaBtn (200×44)
        ├── CaricaPartitaBtn (200×44)
        ├── OpzioniBtn (200×44)
        ├── ProfiloBtn (200×44)
        └── EsciBtn (200×44)
```

### `menu/auth_screen.tscn` + `menu/character_select.tscn`

Entrambi **scaffold Control** (12-13 righe ciascuno). Tutta la UI è costruita
programmaticamente nei rispettivi script (`auth_screen.gd` 233 righe + 
`character_select.gd` 227 righe) in `_build_ui()`.

### `ui/*.tscn` — Panel UI (4 attivi + virtual_joystick)

I pannelli sono **scaffold PanelContainer** minimali (14-17 righe). La UI è
costruita programmaticamente dai rispettivi script in `_build_ui()`.

| Scena | Script | Anchor / Layout | Funzione |
|-------|--------|-----------------|----------|
| `deco_panel.tscn` | `ui/deco_panel.gd` | Right-anchored, 250w full-height | Catalog 129 deco, drag sources |
| `settings_panel.tscn` | `ui/settings_panel.gd` | Centered 300×260 | Volume + lang (hidden) + replay tutorial |
| `profile_panel.tscn` | `ui/profile_panel.gd` | Centered 300×320 | Account info + delete actions |
| `profile_hud_panel.tscn` | `ui/profile_hud_panel.gd` | Top-right 420×148 | Mood slider + lang toggle + settings bridge |
| `virtual_joystick.tscn` | Addon CF Studios | Bottom-left 145,540 | Touch joystick con custom sprite pad |

Tutti istanziati dinamicamente da `PanelManager` (non pre-spawned in main.tscn).

### `male-old-character.tscn` — Personaggio attivo

**Root**: `CharacterBody2D` — Script: `scripts/rooms/character_controller.gd`

- **CollisionShape2D** con `CapsuleShape2D` radius=16 height=66
- **AnimatedSprite2D** con `SpriteFrames` embedded
  - 25 sprite PNG (4 animazioni × 8 direzioni auto-mirror + rotate strip)
  - `idle_down`, `idle_side`, `idle_up`, `idle_vertical_down`, `idle_vertical_up`
  - `walk_down`, `walk_up`, `walk_side`, `walk_side_down`, `walk_side_up`
- Scale 3.0× (sprite 32×32 base → 96×96 in game)
- **motion_mode = FLOATING** (top-down, no gravità)

### `cat_void.tscn` / `cat_void_iso.tscn` — Pet variants

Selezionato da `SaveManager.get_setting("pet_variant")`:

- `simple` → `cat_void.tscn`: 16×16 sprite (80×16 strip, 5 frame), CircleShape2D r=15
- `iso` → `cat_void_iso.tscn`: 32×32 sprite (160×32 strip, 5 frame), CircleShape2D r=10

Entrambi: `CharacterBody2D` + `pet_controller.gd` + `AnimatedSprite2D` con SpriteFrames embedded. AutoplAY "default".

### `room/windows/window*.tscn` — Decorazioni window

Scaffold semplici: `StaticBody2D` + `Sprite2D` con texture. 8 righe ciascuno.

## Flusso fra scene

```
boot → project.godot run/main_scene = menu/main_menu.tscn
  │
  ├── Auth necessaria? → sovrapponi auth_screen.tscn
  │     └── completa → main_menu apre normale
  │
  ├── Nuova Partita → SaveManager.reset + salta character_select (1 char)
  │     └── transition_to main/main.tscn
  │
  ├── Carica Partita → SaveManager.load_game → main/main.tscn
  │
  ├── Opzioni → overlay settings_panel.tscn
  │
  ├── Profilo → overlay profile_panel.tscn
  │
  └── Esci → get_tree().quit()

In main.tscn:
  ├── Character spawnato da room_base._ready (idempotency guard)
  ├── Pet spawnato da room_base._spawn_pet con null-safe char_pos
  ├── HUD buttons wired in main._wire_hud_buttons → PanelManager.toggle_panel
  │
  ├── User clicca "Decora" → deco_panel.tscn istanziato in UILayer
  │     └── drag da DecoButton → DropZone._drop_data → decoration_placed signal
  │     └── room_base._on_decoration_placed → Sprite2D spawned in Decorations/
  │
  ├── Click decorazione piazzata → popup CanvasLayer layer=100 R/F/S/X
  │
  └── Return to menu → MenuButton → menu/main_menu.tscn
```

## Pattern in-scene

1. **Scene-as-scaffold**: panel scene hanno solo root + script ref. UI building in code.
2. **Character instance**: `main.tscn` istanzia `male-old-character.tscn` direttamente (non via code). Renaming del Character a "Character" in code.
3. **CanvasLayer stacking**: UILayer=10 (panel), GameHud=50 (HUD persistenti), ToastManager=90 (toast), decoration popup=100, tutorial=100, auth_screen z_index=100.
4. **mouse_filter convention**: full-rect Control decorativi (WallRect, FloorRect, tutorial overlay) → IGNORE. DropZone → PASS (serve drop events). Panels → STOP default.
5. **Anchor full-rect panels scaffold**: tutte le panel scene hanno `custom_minimum_size` solo, anchor gestito dal codice runtime.

## Vedi anche

- [README scripts](../scripts/README.md) — 37 script GDScript attaccati alle scene
- [README v1](../README.md) — architettura + autoload + scene tree dettagliato
- [README assets](../assets/README.md) — sprite + audio usati dalle scene
- [docs/DEEP_READ_REGISTRY_2026-04-16.md](../docs/DEEP_READ_REGISTRY_2026-04-16.md) — analisi integrale scene
