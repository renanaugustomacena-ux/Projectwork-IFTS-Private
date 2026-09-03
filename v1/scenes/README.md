# Relax Room — Scene Godot

**18 scene** `.tscn` + **1 theme resource** `.tres` (`assets/ui/cozy_theme.tres`).
Conteggio verificato: `find v1/scenes -name "*.tscn" | wc -l` (il
`tests/test_runner.tscn` vive fuori da questa cartella e non e` contato).
Le scene definiscono le gerarchie di nodi, composizione componenti e layout UI.
Vivono accanto ai loro script in `v1/scripts/*/`.

## Struttura directory

```
scenes/
├── main/
│   └── main.tscn                 # Stanza di gameplay (entry dopo menu e slot)
├── menu/
│   ├── main_menu.tscn            # Scena di avvio (project.godot run/main_scene)
│   ├── auth_screen.tscn          # Overlay auth programmatica
│   └── character_select.tscn     # Preview carousel (2 personaggi in catalogo)
├── ui/
│   ├── deco_panel.tscn           # Panel drag-drop decorazioni
│   ├── shop_panel.tscn           # Negozio (right-anchored 300w)
│   ├── settings_panel.tscn       # Slider musica/ambience/effetti + lingua
│   ├── profile_panel.tscn        # Account info + delete char/account
│   ├── profile_hud_panel.tscn    # Mini panel top-right (cursore atmosfera + lang)
│   └── virtual_joystick.tscn     # Nodo nativo VirtualJoystick di Godot 4.7 (nessun addon)
├── room/
│   └── windows/
│       ├── window1.tscn          # 32×64 finestra piccola
│       ├── window2.tscn          # 48×64 finestra media
│       └── window3.tscn          # 64×64 finestra grande
├── effects/
│   └── rain.tscn                 # Particelle pioggia (istanziate da MoodManager, davanti ai mobili)
├── male-old-character.tscn       # Personaggio male_old (directional 8 dir)
├── male-rose-character.tscn      # Personaggio male_rose (directional 8 dir)
├── cat_void.tscn                 # Pet variant 'simple' (16×16)
└── cat_void_iso.tscn             # Pet variant 'iso' (32×32)
```

**Note**:
- `female-character.tscn` rimossa 2026-04-17: gli asset del set femminile non
  sono nel repository (G-042).
- Le scene `room/windows/window*.tscn` **non** sono istanziate da
  `main.tscn`: le finestre entrano in stanza come decorazioni dal catalogo
  (`room_window_1..3` in `data/decorations.json`).
- Non esiste una scena di loading: `main_menu.gd` usa il `LoadingScreen`
  (ColorRect) della scena menu con fade in/out.
- La schermata dei 10 slot (`slot_select.gd`) e` costruita interamente in
  codice, come GameHud: nessuna `.tscn`.

## Scene dettagliate

### `main/main.tscn` — Stanza di gameplay

**Root**: `Main` (Node2D) — Script: `scripts/main.gd`

```
Main (Node2D)
├── RoomBackground (Sprite2D)                 # room.png 1280×720 nativa (nessuno scaling a runtime)
├── WallRect (ColorRect anchor_bottom=0.4)    # mouse_filter=IGNORE, overlay tema
├── FloorRect (ColorRect anchor_top=0.4)      # mouse_filter=IGNORE, copre davvero il pavimento
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)                  # Container per deco spawned (+ SeatArea sotto le sedie)
│   ├── Character (instance male-old-character.tscn)
│   ├── RoomBounds (StaticBody2D)
│   │   └── FloorBounds (CollisionPolygon2D)  # rombo isometrico 4 vertici
│   └── GardenZones (Node2D)                  # GardenLeft / GardenRight / GardenFront (data-only)
├── RoomGrid (Node2D, room_grid.gd)           # visible solo in edit mode
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control full-rect, mouse_filter=PASS)
│   │                                         # riceve _drop_data decorazioni
│   └── HUD (HBoxContainer anchor bottom)
│       ├── MenuButton "Menu"                 # salva e torna al menu
│       ├── SaveButton "Salva"                # unico punto che mostra "Partita salvata"
│       ├── DecoButton "Decora"
│       ├── ShopButton "Negozio"
│       └── ProfileButton "Profilo"           # le Opzioni stanno dentro il profilo
└── AudioStreams (Node)                       # (vuoto, runtime populated)

Runtime additions da main.gd._ready:
├── PanelManager (Node, programmatico)
├── ToastManager (CanvasLayer layer=90)       # toast, mai sopra i pannelli
└── GameHud (CanvasLayer layer=50)            # serenity bar + monete + prompt "Premi E" + barra pulizia
```

Floor polygon reale (misurato dall'arte):
`PackedVector2Array(646, 263, 974, 434, 646, 606, 319, 434)`.
Le tre zone giardino si **sovrappongono** al pavimento (prima erano disgiunte e
il gatto restava bloccato sul bordo): il clamp del gatto usa l'unione.

**Pattern**: I colori wall/floor sono **ColorRect** sovrapposti al
`RoomBackground`. I temi modificano solo il colore del rect, non la sprite.

### `menu/main_menu.tscn` — Menu principale

**Root**: `MainMenu` (Node2D) — Script: `scripts/menu/main_menu.gd`

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)  # 8 layer parallasse + layer luce
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

Entrambi **scaffold Control**. Tutta la UI e` costruita programmaticamente nei
rispettivi script in `_build_ui()`. `character_select` compare solo se il
catalogo ha piu` di un personaggio (oggi 2: `male_old`, `male_rose`).

### `ui/*.tscn` — Panel UI (5 pannelli + virtual_joystick)

I pannelli sono **scaffold PanelContainer** minimali. La UI e` costruita
programmaticamente dai rispettivi script in `_build_ui()`.

| Scena | Script | Anchor / Layout | Funzione |
|-------|--------|-----------------|----------|
| `deco_panel.tscn` | `ui/deco_panel.gd` | Right-anchored, full-height | Catalog 129 deco con griglie pigre, drag sources, nomi IT/EN |
| `shop_panel.tscn` | `ui/shop_panel.gd` | Right-anchored 300w, full-height | Negozio data-driven da `shop.json` |
| `settings_panel.tscn` | `ui/settings_panel.gd` | Centered | Slider musica/ambience/effetti + lingua + replay tutorial |
| `profile_panel.tscn` | `ui/profile_panel.gd` | Centered | Account info, "Accedi / Registrati" per l'ospite, delete actions |
| `profile_hud_panel.tscn` | `ui/profile_hud_panel.gd` | Top-right | Cursore atmosfera + lang toggle + opzioni |
| `virtual_joystick.tscn` | nodo nativo `VirtualJoystick` (Godot 4.7) | Bottom-left 55,450 (180×180) | Pad 128×128 + leva 64×64 da `assets/menu/ui/`, deadzone 0.2 |

Tutti i pannelli sono istanziati dinamicamente da `PanelManager` (non pre-spawned
in main.tscn). Il joystick e` gated `OS.has_feature("mobile")`.

### `male-old-character.tscn` / `male-rose-character.tscn`

**Root**: `CharacterBody2D` — Script: `scripts/rooms/character_controller.gd`

- Collider ancorato ai piedi (non capsula a corpo intero: il personaggio raggiunge la parete di fondo)
- **AnimatedSprite2D** con `SpriteFrames` embedded (idle/walk/interact/rotate, 8 direzioni auto-mirror)
- Scale 3.0× (sprite 32×32 base → 96×96 in game)
- **motion_mode = FLOATING** (top-down, no gravita`)
- Ombra procedurale (`foot_shadow.gd`) aggiunta a runtime

### `cat_void.tscn` / `cat_void_iso.tscn` — Pet variants

Selezionato da `SaveManager.get_setting("pet_variant")`:

- `simple` → `cat_void.tscn`: 16×16 sprite (80×16 strip, 5 frame)
- `iso` → `cat_void_iso.tscn`: 32×32 sprite (160×32 strip, 5 frame)

Entrambi: `CharacterBody2D` + `pet_controller.gd` + `AnimatedSprite2D`.

### `room/windows/window*.tscn` — Decorazioni window

Scaffold semplici: `StaticBody2D` + `Sprite2D` con texture.

## Flusso fra scene

```
boot → project.godot run/main_scene = menu/main_menu.tscn
  │
  ├── Auth necessaria? → sovrapponi auth_screen.tscn
  │     └── completa → main_menu apre normale
  │
  ├── Nuova Partita / Carica Partita → schermata slot (slot_select.gd, in codice)
  │     ├── slot vuoto  → Nuova → SaveManager.reset (+ character_select se >1 personaggio)
  │     └── slot pieno  → Carica → SaveManager.load_game
  │           └── transition_to main/main.tscn
  │
  ├── Opzioni → overlay settings_panel.tscn (salvataggio "solo settings" alla chiusura)
  │
  ├── Profilo → overlay profile_panel.tscn
  │
  └── Esci → salvataggio finale → get_tree().quit()

In main.tscn:
  ├── Character spawnato da room_base._ready (idempotency guard)
  ├── Pet spawnato da room_base._spawn_pet con null-safe char_pos
  ├── HUD buttons wired in main._wire_hud_buttons → PanelManager.toggle_panel
  │
  ├── "Decora" → deco_panel.tscn in UILayer
  │     └── drag da DecoButton → DropZone._drop_data → decoration_placed signal
  │     └── room_base._on_decoration_placed → Sprite2D (+ SeatArea) in Decorations/
  │
  ├── "Negozio" → shop_panel.tscn → GameManager.purchase_item
  │
  ├── Click decorazione piazzata (edit mode) → popup CanvasLayer layer=100 R/F/S/X
  │
  ├── E vicino a sporco/sedia → mess_node / seat_area
  │
  └── "Menu" → salvataggio → menu/main_menu.tscn
```

## Pattern in-scene

1. **Scene-as-scaffold**: panel scene hanno solo root + script ref. UI building in code.
2. **Character instance**: `main.tscn` istanzia `male-old-character.tscn` direttamente; `room_base` fa lo swap se il save chiede `male_rose`.
3. **CanvasLayer stacking**: UILayer=10 (panel), GameHud=50 (HUD persistenti), ToastManager=90 (toast), decoration popup=100, tutorial=100, auth_screen z_index=100.
4. **mouse_filter convention**: full-rect Control decorativi (WallRect, FloorRect, tutorial overlay) → IGNORE. DropZone → PASS (serve drop events). Panels → STOP default.
5. **Nodi nativi prima degli addon**: il joystick usa il nodo `VirtualJoystick` introdotto in Godot 4.7; l'addon omonimo confliggeva con la classe nativa ed e` stato rimosso.

## Vedi anche

- [README scripts](../scripts/README.md) — 57 script GDScript attaccati alle scene
- [README v1](../README.md) — architettura + autoload + scene tree dettagliato
- [README assets](../assets/README.md) — sprite + audio usati dalle scene
- [CHANGELOG 1.3.0](../../CHANGELOG.md) — stato corrente e limiti noti
