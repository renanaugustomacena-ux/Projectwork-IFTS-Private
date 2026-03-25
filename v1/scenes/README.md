# Mini Cozy Room — Scene Godot

Questa cartella contiene tutte le **9 scene Godot** (.tscn) del progetto. Le scene
definiscono le gerarchie di nodi, la composizione dei componenti e il layout dell'interfaccia.

## Struttura

```
scenes/
├── main/
│   └── main.tscn              # Stanza di gioco principale
├── menu/
│   └── main_menu.tscn         # Menu principale (scena di avvio)
├── ui/
│   ├── deco_panel.tscn        # Pannello decorazioni (drag-and-drop)
│   ├── settings_panel.tscn    # Pannello impostazioni
│   └── shop_panel.tscn        # Pannello negozio
├── male-character.tscn        # Personaggio maschile (CharacterBody2D)
├── female-character.tscn      # Personaggio femminile (CharacterBody2D)
└── cat_void.tscn              # Animale domestico (Void Cat)
```

## Dettaglio Scene

### main/main.tscn — Stanza di Gioco

La scena principale del gameplay, caricata dopo la transizione dal menu.

- **Root**: `Main` (Node2D) — Script: `scripts/main.gd`
- **Struttura nodi**:

```
Main (Node2D)
├── WallRect (ColorRect, top 40%)
├── FloorRect (ColorRect, bottom 60%)
├── Baseboard (ColorRect, 2px divisore)
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)
│   ├── Character (CharacterBody2D, istanza da male/female-character.tscn)
│   └── RoomBounds (StaticBody2D, 4 CollisionShape2D)
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, full rect)
│   └── HUD (HBoxContainer)
│       ├── DecoButton
│       ├── SettingsButton
│       └── ShopButton
├── PanelManager (Node, creato programmaticamente)
└── AudioStreams (Node)
```

I colori di muro e pavimento sono definiti come palette nei temi delle stanze (catalogo `data/rooms.json`).

### menu/main_menu.tscn — Menu Principale

Scena di avvio configurata in `project.godot` (`run/main_scene`).

- **Root**: `MainMenu` (Node2D) — Script: `scripts/menu/main_menu.gd`
- **Struttura nodi**:

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

### ui/*.tscn — Pannelli UI

I 3 pannelli sono `PanelContainer` istanziati dinamicamente da `PanelManager`.
Funzionano in mutua esclusione (un solo pannello aperto alla volta),
con animazione fade-in/fade-out (0.3s tween) e chiusura con Escape.

| Scena | Script | Funzione |
|-------|--------|----------|
| `deco_panel.tscn` | `scripts/ui/deco_panel.gd` | Catalogo decorazioni per categoria, drag-and-drop |
| `settings_panel.tscn` | `scripts/ui/settings_panel.gd` | Volume, lingua, display mode |
| `shop_panel.tscn` | `scripts/ui/shop_panel.gd` | Browser negozio, acquisti, coins |

### male-character.tscn / female-character.tscn — Personaggi

Scene prefab per i personaggi giocabili.

- **Root**: `CharacterBody2D` — Script: `scripts/rooms/character_controller.gd`
- **Componenti**: Sprite2D, AnimationPlayer (idle/walk/interact/rotate), CollisionShape2D
- **Movimento**: top-down WASD/frecce, 120 px/s
- **Confinamento**: `RoomBounds` (StaticBody2D con 4 collision shape)
- Istanziati da `room_base.gd` in base alla selezione del personaggio

### cat_void.tscn — Animale Domestico

Scena del Void Cat, posizionabile come decorazione nella stanza.

## Flusso tra Scene

1. Il gioco parte da `menu/main_menu.tscn` (configurato in `project.godot`)
2. "Nuova Partita" o "Carica Partita" transiziona a `main/main.tscn`
3. Le scene personaggio vengono istanziate nel nodo `Room` di main.tscn
4. I pannelli UI vengono istanziati nel `UILayer` da PanelManager

## Vedi Anche

- [README Script](../scripts/README.md) — I 26 script GDScript attaccati alle scene
- [README Tecnico](../README.md) — Architettura completa e scene tree dettagliati
- [README Asset](../assets/README.md) — Sprite e risorse grafiche usate dalle scene
