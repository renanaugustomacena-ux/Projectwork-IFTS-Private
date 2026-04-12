# Mini Cozy Room — Technical Guide

> A comprehensive, exhaustive technical guide for building a 2D pixel art desktop companion game with Godot Engine 4.6. Written for developers with zero prior Godot experience.

---

## Table of Contents

1. [What is Godot Engine](#1-what-is-godot-engine)
2. [Installation and First Launch](#2-installation-and-first-launch)
3. [Core Concepts: Nodes, Scenes, and the Scene Tree](#3-core-concepts-nodes-scenes-and-the-scene-tree)
4. [GDScript Fundamentals](#4-gdscript-fundamentals)
5. [Project Configuration for 2D Pixel Art](#5-project-configuration-for-2d-pixel-art)
6. [Directory Structure and Organization](#6-directory-structure-and-organization)
7. [Asset Pipeline: Importing and Managing Pixel Art](#7-asset-pipeline-importing-and-managing-pixel-art)
8. [The Signal System: Decoupled Communication](#8-the-signal-system-decoupled-communication)
9. [Autoload Singletons: Global Managers](#9-autoload-singletons-global-managers)
10. [Save/Load System: JSON-Based Persistence](#10-saveload-system-json-based-persistence)
11. [Audio System: Music and Ambience](#11-audio-system-music-and-ambience)
12. [UI System: Control Nodes and Layouts](#12-ui-system-control-nodes-and-layouts)
13. [Desktop Integration: Window Management and Mini Mode](#13-desktop-integration-window-management-and-mini-mode)
14. [Scene Architecture for Mini Cozy Room](#14-scene-architecture-for-mini-cozy-room)
15. [Building and Exporting to .exe](#15-building-and-exporting-to-exe)
16. [Python Integration via py4godot](#16-python-integration-via-py4godot)
17. [Version Control with Git](#17-version-control-with-git)
18. [Development Workflow and Best Practices](#18-development-workflow-and-best-practices)
19. [Troubleshooting Common Issues](#19-troubleshooting-common-issues)
20. [Reference: Mini Cozy Room Feature Specification](#20-reference-mini-cozy-room-feature-specification)

---

## 1. What is Godot Engine

Godot is a free, open-source, cross-platform game engine. Unlike Unity or Unreal, Godot uses a unique **scene-based architecture** where everything — from a single button to an entire game level — is a **scene** composed of **nodes**.

**Key characteristics:**
- **Completely free** — no royalties, no subscription, MIT license
- **Lightweight** — the editor is ~40 MB, no installer needed
- **Native 2D engine** — not a 3D engine with 2D bolted on; Godot's 2D is first-class
- **GDScript** — a Python-like language designed specifically for game development
- **Scene system** — modular, reusable, composable scenes (like components in web dev)
- **Built-in editor** — code editor, animation editor, tilemap editor, audio mixer, all in one

**Why Godot for this project:**
- Excellent 2D support with pixel-perfect rendering
- Built-in window management APIs (borderless, always-on-top, transparency)
- Lightweight runtime suitable for a desktop companion app
- JSON support built into the engine
- Export to Windows .exe with a single click

---

## 2. Installation and First Launch

### Installing Godot 4.6

1. Go to https://godotengine.org/download
2. Download "Godot Engine - Standard" for Windows (64-bit)
3. Extract the zip — you get a single `Godot_v4.6-stable_win64.exe`
4. No installation needed. Just run the .exe

### Opening the v1 Project

1. Launch Godot
2. In the Project Manager, click **"Import"**
3. Navigate to `E:\projectwork\Projectwork\v1\`
4. Select `project.godot`
5. Click **"Import & Edit"**

The editor opens with the project. You should see:
- **Scene panel** (left) — shows the node tree of the current scene
- **Viewport** (center) — visual editor where you see/arrange nodes
- **Inspector** (right) — properties of the selected node
- **FileSystem** (bottom-left) — your project's file browser
- **Output** (bottom) — console log and error messages

### First Run

Press **F5** (or the Play button ▶) to run the project. Since `main.tscn` is set as the main scene in `project.godot`, it will load automatically.

---

## 3. Core Concepts: Nodes, Scenes, and the Scene Tree

This is the single most important concept to understand in Godot.

### Nodes

A **node** is the atomic building block of Godot. Every object in your game is a node. There are ~100+ node types, each with a specific purpose:

| Node Type | Purpose | Example Use |
|-----------|---------|-------------|
| `Node2D` | Base for all 2D objects | Container, position parent |
| `Sprite2D` | Displays a 2D texture/image | Room background, character, decoration |
| `AnimatedSprite2D` | Sprite with frame-by-frame animation | Character with idle/walk animations |
| `TextureRect` | UI rectangle that shows a texture | Background image, button icon |
| `Control` | Base for all UI elements | Panels, containers, buttons |
| `Button` | Clickable button | HUD buttons |
| `Label` | Text display | Timer display, to-do item text |
| `TextEdit` | Multi-line text input | Memo pad |
| `LineEdit` | Single-line text input | To-do item entry |
| `AudioStreamPlayer` | Plays audio (non-positional) | Music, ambience |
| `CanvasLayer` | Separate rendering layer | UI that stays fixed regardless of camera |
| `Timer` | Counts down and emits signal | Pomodoro timer, auto-save |
| `HBoxContainer` | Arranges children horizontally | Button bar |
| `VBoxContainer` | Arranges children vertically | To-do list items |
| `PanelContainer` | Visual panel with background | Settings panel, music player |

### Scenes

A **scene** is a saved tree of nodes (a `.tscn` file). Scenes are:
- **Reusable** — instantiate the same scene multiple times
- **Composable** — a scene can contain instances of other scenes
- **Inheritable** — a scene can extend another (like class inheritance)

Example: `decoration_item.tscn` is a scene with a `Sprite2D` + collision detection. You instantiate it 12 times for 12 different decorations, just changing the texture.

### The Scene Tree

When your game runs, all active nodes form a **tree** (like DOM in web development). The tree has a root, and every node has exactly one parent and zero or more children.

```
Root (Viewport)
└── Main (Node2D)         ← your main scene
    ├── Background
    ├── Room
    │   ├── RoomBackground
    │   ├── Decorations
    │   └── Character
    ├── UILayer
    │   └── HUD
    └── AudioStreams
```

**Key operations on the tree:**
```gdscript
# Get a child node by path
var bg = $Room/RoomBackground           # Relative path from current node
var bg = get_node("Room/RoomBackground") # Same thing, explicit

# Add a node dynamically
var sprite = Sprite2D.new()
add_child(sprite)

# Remove a node
sprite.queue_free()  # Safely removes at end of frame

# Get parent
var parent = get_parent()

# Get the tree root
var root = get_tree().root
```

---

## 4. GDScript Fundamentals

GDScript is Godot's primary scripting language. It's similar to Python but has key differences.

### Basic Syntax

```gdscript
# Variables
var health: int = 100
var player_name: String = "Mini"
var position: Vector2 = Vector2(100, 200)
var items: Array = ["book", "lamp", "plant"]
var config: Dictionary = {"volume": 0.8, "lang": "en"}

# Constants
const MAX_DECORATIONS := 20
const SAVE_PATH := "user://save_data.json"

# Exported variables (visible in the Godot Inspector panel)
@export var speed: float = 200.0
@export var room_name: String = "Cozy Studio"

# Functions
func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

# No explicit main() — lifecycle is event-driven via callbacks
```

### Script Lifecycle Callbacks

Every script attached to a node can override these built-in callbacks:

```gdscript
extends Node2D  # Always starts with extends <NodeType>

# Called once when the node enters the scene tree
func _ready() -> void:
    print("Node is ready!")

# Called every visual frame (~60 times/sec at 60fps)
func _process(delta: float) -> void:
    # delta = time since last frame in seconds
    position.x += speed * delta

# Called every physics frame (fixed timestep, default 60/sec)
func _physics_process(delta: float) -> void:
    # Use for physics-related movement
    pass

# Called on any input event (keyboard, mouse, touch)
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            print("Left click at: ", event.position)

# Called when the node is about to be removed
func _exit_tree() -> void:
    print("Node is leaving the tree")
```

### Type System

GDScript supports optional static typing (recommended for code safety):

```gdscript
# Untyped (works but no compile-time checks)
var x = 42

# Typed (recommended — catches errors early)
var x: int = 42
var name: String = "Room"
var pos: Vector2 = Vector2.ZERO
var items: Array[String] = ["a", "b"]

# Function signatures with types
func get_room_name(room_id: String) -> String:
    return rooms[room_id].name
```

### Key Differences from Python

| Feature | Python | GDScript |
|---------|--------|----------|
| Typing | `x: int = 5` | `var x: int = 5` |
| Constants | `X = 5` (convention) | `const X := 5` |
| Null | `None` | `null` |
| Self reference | `self.x` | `self.x` or just `x` |
| Boolean | `True` / `False` | `true` / `false` |
| Printing | `print()` | `print()` (same!) |
| String format | `f"{x}"` | `"%s" % x` or `str(x)` |
| Inheritance | `class Foo(Bar):` | `extends Bar` (one per file) |
| Constructor | `def __init__(self):` | `func _init():` |
| For loop | `for i in range(10):` | `for i in range(10):` (same!) |
| Dictionary | `{"key": "val"}` | `{"key": "val"}` (same!) |
| Lambda | `lambda x: x + 1` | `func(x): return x + 1` |

### Common Patterns

```gdscript
# Null-safe access
var texture = load(path) as Texture2D
if texture:
    sprite.texture = texture

# Array iteration
for item in items:
    print(item)

# Dictionary iteration
for key in config:
    print(key, ": ", config[key])

# match (like switch/case)
match playlist_mode:
    "shuffle":
        pick_random_track()
    "sequential":
        play_next()
    "repeat_one":
        replay_current()

# Ternary
var label = "Playing" if is_playing else "Paused"

# String formatting
var msg = "Room: %s, Theme: %s" % [room_id, theme]

# Loading resources
var texture: Texture2D = load("res://assets/sprites/rooms/cozy_studio.png")
var scene: PackedScene = load("res://scenes/ui/todo_list.tscn")
var instance = scene.instantiate()  # Create a node from the scene
add_child(instance)                 # Add to tree
```

---

## 5. Project Configuration for 2D Pixel Art

The `project.godot` file is the heart of your Godot project. Here's what each setting in our configuration does:

### Display Settings

```ini
[display]
window/size/viewport_width=640       # Internal render resolution width
window/size/viewport_height=360      # Internal render resolution height
window/size/window_width_override=1280  # Actual window width on screen
window/size/window_height_override=720  # Actual window height on screen
window/stretch/mode="viewport"       # How content scales with window
window/stretch/scale_mode="integer"  # Only scale by whole numbers (2x, 3x)
window/per_pixel_transparency/allowed=true  # Enable transparent window regions
```

**Why 640x360?**
- It's exactly 16:9 (modern monitor ratio)
- Scales perfectly to 1280x720 (2x), 1920x1080 (3x), 2560x1440 (4x)
- Integer scaling means no sub-pixel artifacts — every game pixel maps to exactly 4 screen pixels at 2x

**Stretch modes explained:**
- `"viewport"` — renders at 640x360, then scales the result. This gives pixel-perfect rendering.
- `"canvas_items"` — would re-render UI at full resolution (good for text, bad for pixel art)

### Rendering Settings

```ini
[rendering]
textures/canvas_textures/default_texture_filter=0  # 0 = Nearest, 1 = Linear
renderer/rendering_method="gl_compatibility"        # OpenGL backend
```

**Texture Filter = Nearest (CRITICAL):**
- `Nearest` (value 0) = each pixel stays sharp and blocky → **pixel art looks correct**
- `Linear` (value 1) = pixels get blurred/smoothed → **pixel art looks smeared and wrong**
- This is the single most important setting for pixel art games

**Renderer = gl_compatibility:**
- Most compatible across hardware (uses OpenGL ES 3.0)
- Perfect for 2D games — we don't need Forward+ or Mobile renderer
- Supports transparency, shaders, and all 2D features

### Autoload Configuration

```ini
[autoload]
SignalBus="*res://scripts/autoload/signal_bus.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
SaveManager="*res://scripts/autoload/save_manager.gd"
AudioManager="*res://scripts/autoload/audio_manager.gd"
```

The `*` prefix means the script is loaded as a **singleton** — a single global instance accessible from anywhere by name. More on this in Section 9.

---

## 6. Directory Structure and Organization

```
v1/
├── project.godot              # Godot reads this to identify the project root
├── .gitignore                 # Git exclusions
├── icon.svg                   # Project icon (shown in Godot Project Manager)
├── TECHNICAL_GUIDE.md         # This document
│
├── addons/                    # Third-party plugins
│   └── py4godot/              # Python integration plugin
│
├── assets/                    # All non-code resources
│   ├── sprites/               # 2D images
│   │   ├── characters/        # Character sprite sheets
│   │   ├── decorations/       # Furniture and item sprites
│   │   ├── rooms/             # Room background images
│   │   └── ui/                # UI element graphics
│   ├── backgrounds/           # Ambient/parallax backgrounds
│   ├── audio/
│   │   ├── music/             # Lo-fi tracks (.ogg format recommended)
│   │   └── ambience/          # Ambient sounds (.ogg or .wav)
│   ├── fonts/                 # Pixel art fonts (.ttf or .fnt)
│   ├── icons/                 # App icons at various sizes
│   └── themes/                # Godot UI theme resources (.tres)
│
├── scenes/                    # Scene files (.tscn)
│   ├── main/                  # Entry point scene
│   ├── rooms/                 # Room scenes (one per room type)
│   ├── ui/                    # UI panel scenes
│   ├── character/             # Character scene
│   └── decoration/            # Reusable decoration item scene
│
├── scripts/                   # GDScript source files (.gd)
│   ├── autoload/              # Global singleton scripts
│   ├── rooms/                 # Room-related scripts
│   ├── ui/                    # UI controller scripts
│   ├── character/             # Character logic
│   └── utils/                 # Shared utilities and constants
│
├── data/                      # Static JSON data catalogs
│   ├── rooms.json             # Room definitions
│   ├── decorations.json       # Decoration catalog
│   ├── characters.json        # Character catalog
│   └── tracks.json            # Music track list
│
└── export/                    # Build output (gitignored)
    └── windows/               # Windows .exe exports
```

### Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| Folders | `snake_case` | `assets/sprites/characters/` |
| Scene files | `snake_case.tscn` | `cozy_studio.tscn` |
| Script files | `snake_case.gd` | `game_manager.gd` |
| Node names in editor | `PascalCase` | `RoomBackground`, `MusicPlayer` |
| GDScript variables | `snake_case` | `current_room_id` |
| GDScript constants | `UPPER_SNAKE` | `SAVE_PATH` |
| GDScript functions | `snake_case` | `load_game()` |
| GDScript classes | `PascalCase` | `class_name Constants` |
| Signal names | `snake_case` | `room_changed` |

### The `res://` and `user://` Paths

Godot uses two special path prefixes:

- **`res://`** = project root (where `project.godot` lives). Read-only in exported builds.
  - `res://scripts/autoload/game_manager.gd` → `v1/scripts/autoload/game_manager.gd`
  - `res://assets/sprites/rooms/cozy_studio.png` → `v1/assets/sprites/rooms/cozy_studio.png`

- **`user://`** = user data directory. Writable in both editor and exported builds.
  - On Windows: `%APPDATA%\Godot\app_userdata\Mini Cozy Room\`
  - This is where save files go: `user://save_data.json`

---

## 7. Asset Pipeline: Importing and Managing Pixel Art

### How Godot Imports Assets

When you place an image file (e.g., `cozy_studio.png`) in your project folder, Godot **automatically imports** it. The import process:

1. Godot detects the new file
2. Generates an `.import` file next to it (e.g., `cozy_studio.png.import`)
3. Creates a cached version in `.godot/imported/`
4. The `.import` file contains import settings (filter mode, compression, etc.)

### Configuring Import Settings for Pixel Art

**For every sprite/image in the project:**

1. Select the image in the FileSystem panel
2. Go to the **Import** tab (next to the Scene tab at the top)
3. Set **Filter** to `Nearest` (not Linear)
4. If it's a sprite: set **Compress Mode** to `Lossless`
5. Click **Reimport**

**Or set it globally** (already done in our `project.godot`):
```ini
textures/canvas_textures/default_texture_filter=0  # Nearest for all textures
```

### Audio Format Recommendations

| Format | Use For | Why |
|--------|---------|-----|
| `.ogg` (Vorbis) | Music tracks | Good compression, perfect for looping, small file size |
| `.wav` | Short sound effects | No compression artifacts, instant playback |
| `.mp3` | Not recommended | Licensing concerns, use .ogg instead |

### Copying Reference Assets

The reference assets in `E:\projectwork\REFERENCES-IMPORTANT\` need to be copied into the project:

```
REFERENCES-IMPORTANT\Character\*.png  →  v1\assets\sprites\characters\
REFERENCES-IMPORTANT\Rooms\*.png      →  v1\assets\sprites\rooms\
REFERENCES-IMPORTANT\Decorations\*.png →  v1\assets\sprites\decorations\
REFERENCES-IMPORTANT\Background\*.png →  v1\assets\backgrounds\
REFERENCES-IMPORTANT\App Icon\*.png   →  v1\assets\icons\
```

**Important:** Rename files to match the IDs in your JSON catalogs. For example:
- `Cozy Studio Modern.png` → `cozy_studio_modern.png`
- `Boy_Blonde_Hoodie.png` → `boy_blonde_hoodie.png`

Godot reimports automatically when files appear in the project folder.

---

## 8. The Signal System: Decoupled Communication

Signals are Godot's observer pattern implementation. They allow nodes to communicate without direct references — essential for clean architecture.

### How Signals Work

```
[Button pressed] --signal--> [Controller handles it] --signal--> [UI updates]
```

Instead of:
```gdscript
# BAD: tight coupling
func _on_button_pressed():
    get_node("../../UILayer/MusicPlayer").toggle_play()
```

Use signals:
```gdscript
# GOOD: decoupled via SignalBus
func _on_button_pressed():
    SignalBus.track_play_pause_toggled.emit(true)

# In MusicPlayer script:
func _ready():
    SignalBus.track_play_pause_toggled.connect(_on_play_toggled)

func _on_play_toggled(is_playing: bool):
    if is_playing:
        play()
    else:
        pause()
```

### Defining Custom Signals

In `signal_bus.gd`:
```gdscript
signal room_changed(room_id: String, theme: String)
signal todo_item_added(text: String)
signal volume_changed(bus_name: String, volume: float)
```

### Emitting Signals

```gdscript
SignalBus.room_changed.emit("cozy_studio", "modern")
SignalBus.todo_item_added.emit("Study GDScript")
SignalBus.volume_changed.emit("music", 0.7)
```

### Connecting to Signals

```gdscript
# In _ready()
SignalBus.room_changed.connect(_on_room_changed)

# Handler function
func _on_room_changed(room_id: String, theme: String) -> void:
    load_room(room_id, theme)
```

### Why We Use a SignalBus

Instead of each node declaring its own signals, we centralize them in a global `SignalBus` singleton. This means:
- Any script can emit any signal without knowing who listens
- Any script can listen to any signal without knowing who emits
- Adding new features doesn't require modifying existing code
- Easy to trace all game events in one file

---

## 9. Autoload Singletons: Global Managers

Autoloads are scripts that Godot loads automatically when the game starts, before any scene. They persist across scene changes and are accessible globally by name.

### Our Autoloads

| Singleton | Purpose |
|-----------|---------|
| `SignalBus` | Central hub for all cross-system signals |
| `GameManager` | Game state (current room, character, mode), data catalogs, lifecycle |
| `SaveManager` | JSON serialization/deserialization, auto-save timer, tool data |
| `AudioManager` | Music playback, playlist management, ambience mixing |

### How to Access Them

From **any** script in the project:
```gdscript
# These are globally available by the names in project.godot [autoload]
GameManager.current_room_id
SaveManager.save_game()
AudioManager.play()
SignalBus.room_changed.emit("nest_room", "pink")
```

### Load Order

Autoloads are loaded in the order listed in `project.godot`:
1. `SignalBus` — first, because everything else connects to it
2. `GameManager` — second, loads data catalogs
3. `SaveManager` — third, loads save data and populates GameManager
4. `AudioManager` — fourth, depends on GameManager's track catalog

---

## 10. Save/Load System: JSON-Based Persistence

### Save File Location

The save file is stored at `user://save_data.json`, which maps to:
```
Windows: %APPDATA%\Godot\app_userdata\Mini Cozy Room\save_data.json
```

### Save File Schema

```json
{
    "version": "1.0.0",
    "last_saved": "2026-02-28T15:30:00",
    "settings": {
        "language": "en",
        "display_mode": "windowed",
        "mini_mode_position": "bottom_right",
        "master_volume": 0.8,
        "music_volume": 0.6,
        "ambience_volume": 0.4
    },
    "room": {
        "current_room_id": "cozy_studio",
        "current_theme": "modern",
        "decorations": [
            {
                "item_id": "bookshelf_wooden",
                "position": [120, 80],
                "layer": 2,
                "flipped": false
            }
        ]
    },
    "character": {
        "character_id": "girl_pink_hair",
        "outfit_id": "blouse_default"
    },
    "music": {
        "current_track_index": 0,
        "playlist_mode": "shuffle",
        "active_ambience": ["rain", "typing"]
    },
    "tools": {
        "todo_items": [
            {"text": "Study GDScript", "done": false, "created": "2026-02-28"}
        ],
        "memos": [
            {"title": "Notes", "content": "...", "created": "2026-02-28"}
        ],
        "pomodoro": {
            "work_minutes": 25,
            "break_minutes": 5,
            "long_break_minutes": 15,
            "sessions_before_long_break": 4
        }
    }
}
```

### How Saving Works (Step by Step)

1. Something changes (decoration moved, todo item added, etc.)
2. The relevant script emits `SignalBus.save_requested`
3. `SaveManager` marks itself as "dirty"
4. Every 60 seconds, `SaveManager` checks if dirty → if yes, calls `save_game()`
5. `save_game()` builds a Dictionary from all current state
6. `JSON.stringify(data, "\t")` converts to formatted JSON string
7. `FileAccess.open("user://save_data.json", WRITE)` opens the file
8. `file.store_string(json_string)` writes it
9. On app close (`NOTIFICATION_WM_CLOSE_REQUEST`), a final save is forced

### How Loading Works

1. `SaveManager._ready()` calls `load_game()` on startup
2. Check if `user://save_data.json` exists
3. Read file contents → parse JSON → validate it's a Dictionary
4. Apply each section to the corresponding manager/data store
5. Emit `SignalBus.load_completed` so other systems refresh their state

### JSON Gotchas in Godot

- **Vector2 cannot be stored directly in JSON.** Convert: `[v.x, v.y]` on save, `Vector2(arr[0], arr[1])` on load.
- **Color cannot be stored directly.** Use hex string: `color.to_html()` on save, `Color.html(str)` on load.
- **JSON.parse()` returns an error code**, not the data directly. Always check the result.
- **All JSON numbers are float.** Use `int()` cast when you need integers.

---

## 11. Audio System: Music and Ambience

### AudioStreamPlayer Node

Godot's `AudioStreamPlayer` is the node for non-positional audio (perfect for music and ambience):

```gdscript
var player = AudioStreamPlayer.new()
player.stream = load("res://assets/audio/music/track_01.ogg")
player.volume_db = -6.0   # Volume in decibels (0 = full, -80 = silent)
player.play()
player.stop()
player.stream_paused = true  # Pause without resetting position
```

### Volume: Linear vs Decibels

Godot uses decibels (dB) for volume. Humans perceive volume logarithmically, so:

```gdscript
# Convert 0.0-1.0 slider value to dB
player.volume_db = linear_to_db(slider_value)

# Convert dB back to 0.0-1.0 for UI
slider.value = db_to_linear(player.volume_db)
```

| Linear | dB | Perceived |
|--------|-----|-----------|
| 1.0 | 0 dB | Full volume |
| 0.5 | -6 dB | Half perceived |
| 0.25 | -12 dB | Quarter |
| 0.0 | -80 dB | Silent |

### Simultaneous Playback

Our design plays music + multiple ambience tracks simultaneously:
- 1x `AudioStreamPlayer` for the current lo-fi track
- Nx `AudioStreamPlayer` for each active ambience (rain, wind, typing, etc.)
- Each has independent volume control
- Master volume multiplies all

### Audio Format Notes

- Use `.ogg` for music — good quality, small size, supports seamless looping
- Set the **Loop** property in the Import tab for tracks that should loop
- Ambience sounds should always loop

---

## 12. UI System: Control Nodes and Layouts

### Control Node Hierarchy

In Godot, all UI elements inherit from `Control`. The layout system works with **anchors** and **containers**:

```
Control (base for all UI)
├── Button, Label, LineEdit, TextEdit (interactive elements)
├── TextureRect, ColorRect (visual elements)
├── HBoxContainer, VBoxContainer, GridContainer (layout containers)
├── PanelContainer, ScrollContainer (structural containers)
└── TabContainer, MarginContainer (organizational)
```

### Anchors and Margins

Every Control node has **anchors** (0.0 to 1.0) that define where it's positioned relative to its parent:

```
Anchor (0,0) ─────── Anchor (1,0)
│                          │
│       Control            │
│                          │
Anchor (0,1) ─────── Anchor (1,1)
```

Common presets:
- **Full Rect** — anchors at all corners (fills parent)
- **Center** — anchored to center of parent
- **Bottom Wide** — spans the bottom edge (good for HUD)

### Container Nodes

Containers automatically arrange their children:

```gdscript
# HBoxContainer — arranges children left-to-right
# VBoxContainer — arranges children top-to-bottom
# GridContainer — arranges in a grid (set columns)
# MarginContainer — adds padding around a single child
```

### Building the HUD

Our HUD uses an `HBoxContainer` anchored to the bottom of the screen:

```
UILayer (CanvasLayer, layer=10)
└── HUD (HBoxContainer, anchored bottom-wide)
    ├── MusicButton
    ├── TodoButton
    ├── MemoButton
    ├── TimerButton
    ├── DecoButton
    └── SettingsButton
```

### UI Theming

Godot supports themes (`.tres` files) that style all UI elements consistently:

```gdscript
# Create a theme in the editor:
# 1. Right-click in assets/themes/ → New Resource → Theme
# 2. Set fonts, colors, margins for Button, Panel, Label, etc.
# 3. Assign the theme to the root Control node of your UI
```

For pixel art games, use a pixel art font and small, clean UI elements.

---

## 13. Desktop Integration: Window Management and Mini Mode

### Godot's DisplayServer API

Godot 4.x provides the `DisplayServer` singleton for window management:

```gdscript
# Borderless window (no title bar, no frame)
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

# Always on top
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

# Transparent background
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

# Resize window
get_window().size = Vector2i(320, 180)

# Move window to specific position
get_window().position = Vector2i(100, 100)

# Get screen size
var screen_size = DisplayServer.screen_get_size()

# Dock to bottom-right corner
var win_size = get_window().size
get_window().position = Vector2i(
    screen_size.x - win_size.x,
    screen_size.y - win_size.y - 40  # Above taskbar
)
```

### Mini Mode Implementation Strategy

1. **Normal Mode:** 1280x720 window, with decorations (title bar), centered
2. **Mini Mode:** 320x180 borderless, always-on-top, docked to screen edge
3. **Transition:** Animated resize with tween, switch flags, reposition

```gdscript
func enter_mini_mode():
    # Store normal position for restoration
    _saved_position = get_window().position
    _saved_size = get_window().size

    # Apply mini mode flags
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

    # Resize and reposition
    get_window().size = Vector2i(320, 180)
    _dock_to_edge()

func exit_mini_mode():
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
    get_window().size = _saved_size
    get_window().position = _saved_position
```

### Per-Pixel Transparency

For the mini mode overlay effect, you need:
1. `window/per_pixel_transparency/allowed=true` in project settings
2. `DisplayServer.WINDOW_FLAG_TRANSPARENT` set to true
3. Clear color alpha set to 0 (or use a shader)

---

## 14. Scene Architecture for Mini Cozy Room

### Complete Node Tree

```
Main (Node2D)
│
├── Background (TextureRect)
│   └── Shows the ambient background (gradient, sky, etc.)
│
├── Room (Node2D) [room_base.gd]
│   ├── RoomBackground (Sprite2D)
│   │   └── The room image (Cozy Studio, Moonlight Study, etc.)
│   ├── Decorations (Node2D)
│   │   ├── [DecoItem] (Sprite2D) [decoration_system.gd] — dynamic
│   │   ├── [DecoItem] (Sprite2D) [decoration_system.gd] — dynamic
│   │   └── ... (spawned from save data)
│   └── Character (Sprite2D)
│       └── The selected character sprite
│
├── UILayer (CanvasLayer, layer=10)
│   ├── HUD (HBoxContainer) [anchored bottom]
│   │   ├── MusicButton (Button)
│   │   ├── TodoButton (Button)
│   │   ├── MemoButton (Button)
│   │   ├── TimerButton (Button)
│   │   ├── DecoButton (Button)
│   │   └── SettingsButton (Button)
│   │
│   ├── MusicPlayerPanel (PanelContainer) [music_controller.gd]
│   │   ├── VBox
│   │   │   ├── TrackLabel (Label)
│   │   │   ├── PlaybackControls (HBox)
│   │   │   │   ├── PrevButton, PlayPauseButton, NextButton
│   │   │   │   └── ShuffleButton
│   │   │   ├── VolumeSlider (HSlider)
│   │   │   └── AmbienceMixer
│   │   │       ├── RainToggle (CheckButton)
│   │   │       ├── WindToggle (CheckButton)
│   │   │       └── TypingToggle (CheckButton)
│   │
│   ├── TodoPanel (PanelContainer) [todo_controller.gd]
│   │   ├── VBox
│   │   │   ├── InputRow (HBox)
│   │   │   │   ├── TodoInput (LineEdit)
│   │   │   │   └── AddButton (Button)
│   │   │   └── TodoList (VBoxContainer)
│   │   │       └── [TodoItem] (HBox) — dynamic
│   │
│   ├── MemoPanel (PanelContainer) [memo_controller.gd]
│   │   ├── VBox
│   │   │   ├── TitleInput (LineEdit)
│   │   │   ├── ContentEdit (TextEdit)
│   │   │   └── ButtonRow (HBox)
│   │   │       ├── SaveButton, DeleteButton
│   │
│   ├── PomodoroPanel (PanelContainer) [pomodoro_controller.gd]
│   │   ├── VBox
│   │   │   ├── TimerDisplay (Label) — "25:00"
│   │   │   ├── ModeLabel (Label) — "Work" / "Break"
│   │   │   ├── Controls (HBox)
│   │   │   │   ├── StartButton, PauseButton, ResetButton
│   │   │   └── SessionCounter (Label) — "Session 2/4"
│   │
│   └── SettingsPanel (PanelContainer) [settings_controller.gd]
│       ├── VBox
│       │   ├── RoomSelector (OptionButton)
│       │   ├── ThemeSelector (OptionButton)
│       │   ├── CharacterSelector (OptionButton)
│       │   ├── LanguageSelector (OptionButton)
│       │   └── MiniModeButton (Button)
│
└── AudioStreams (Node)
    └── Managed by AudioManager autoload (creates players dynamically)
```

### Scene File Breakdown

| Scene File | Root Node | Purpose |
|------------|-----------|---------|
| `main.tscn` | Node2D | Entry point, contains everything |
| `room_base.tscn` | Node2D | Room display + decorations + character |
| `hud.tscn` | HBoxContainer | Bottom toolbar buttons |
| `todo_list.tscn` | PanelContainer | To-do list panel |
| `memo_pad.tscn` | PanelContainer | Memo/note editor |
| `pomodoro.tscn` | PanelContainer | Timer with Pomodoro logic |
| `music_player.tscn` | PanelContainer | Music controls + ambience mixer |
| `settings.tscn` | PanelContainer | Room/character/language selection |
| `decoration_item.tscn` | Sprite2D | Single draggable decoration |
| `character.tscn` | Sprite2D | Character display |

---

## 15. Building and Exporting to .exe

### Step 1: Download Export Templates

Export templates are pre-compiled Godot engine binaries for each target platform.

1. In Godot Editor: `Editor → Manage Export Templates`
2. Click **"Download and Install"**
3. Wait for download (~500 MB for all platforms)
4. This is a one-time setup

### Step 2: Configure Export Preset

1. Go to `Project → Export`
2. Click **"Add..."** → **"Windows Desktop"**
3. Configure:
   - **Export Path:** `res://export/windows/MiniCozyRoom.exe`
   - **Embed Pck:** `ON` (bundles all assets into the .exe, single file distribution)
   - **64-bit:** `ON`
   - **Custom icon:** Set to your `.ico` file (convert PNG to ICO first)
   - **Company Name:** Your studio name
   - **Product Name:** "Mini Cozy Room"
   - **File Version:** "1.0.0.0"
   - **Product Version:** "1.0.0.0"

### Step 3: Export

1. Click **"Export Project..."**
2. Choose save location
3. Click **"Save"**
4. Godot compiles and packages everything

### Output

With "Embed Pck" ON:
- `MiniCozyRoom.exe` — single file, contains everything, ready to distribute

With "Embed Pck" OFF:
- `MiniCozyRoom.exe` — the engine executable
- `MiniCozyRoom.pck` — all game assets and scripts (must be in same directory)

### Common Export Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "No export template found" | Templates not downloaded | Editor → Manage Export Templates → Download |
| Black screen on launch | Main scene not set | Project Settings → Application → Run → Main Scene |
| Assets not found | Path case sensitivity | Ensure paths match exactly (Linux exports are case-sensitive) |
| Large file size | Uncompressed assets | Use .ogg for audio, optimize PNG with tools like pngquant |

---

## 16. Python Integration via py4godot

The project includes the `py4godot` addon, which allows writing game logic in Python alongside GDScript.

### When to Use Python vs GDScript

| Use GDScript for | Use Python for |
|------------------|----------------|
| Scene logic, node behavior | Data processing, analysis |
| Input handling, UI | External API calls |
| Animation, visual effects | Complex algorithms |
| Signal connections | File format parsing |
| Physics, movement | Machine learning inference |
| Anything real-time | Batch operations |

### py4godot Basics

Python scripts in py4godot extend `GDClass`:

```python
# signal_script.py (example from the addon)
from py4godot.classes import GDClass

class SignalScript(GDClass):
    def _ready(self):
        print("Python node is ready!")

    def _process(self, delta):
        pass
```

### Adding Python Dependencies

1. Edit `addons/py4godot/dependencies.txt`
2. Add package names (one per line, like `requirements.txt`)
3. Run `install_dependencies.py`

### Export with Python

The `export_py4godot.gd` plugin automatically copies Python files and the CPython runtime to the export directory. No manual steps needed.

---

## 17. Version Control with Git

### .gitignore Essentials

```
.godot/          # Editor cache, import cache, UID cache
.import/         # Legacy import directory (Godot 3.x)
.fscache         # File system cache
export/          # Build artifacts
*.exe            # Compiled executables
*.pck            # Packed resource files
export_credentials.cfg  # Contains signing keys
__pycache__/     # Python bytecode
```

### What TO Track in Git

- `project.godot` — project configuration
- All `.tscn` files — scene definitions (text-based, diff-friendly)
- All `.gd` files — scripts
- All `.tres` files — Godot resources (themes, materials)
- All asset files (`.png`, `.ogg`, `.wav`, `.ttf`)
- All `.json` data files
- `.gitignore` and `.gitattributes`
- `addons/` directory (including py4godot)

### Git LFS Consideration

For large binary assets (audio files, large sprite sheets), consider using Git LFS:
```bash
git lfs install
git lfs track "*.ogg"
git lfs track "*.wav"
git lfs track "*.png"
```

### Branch Strategy

- `main` — stable, production-ready
- `proto` — current development branch (prototyping)
- Feature branches from `proto` for specific features

---

## 18. Development Workflow and Best Practices

### Daily Workflow

1. Open Godot → load the v1 project
2. Make changes in the editor (scenes, scripts)
3. Press F5 to test
4. Check the Output panel for errors
5. Iterate

### Scene Editing Workflow

1. Open a `.tscn` file by double-clicking in FileSystem
2. Add nodes via the "+" button in the Scene panel
3. Configure properties in the Inspector
4. Attach scripts via right-click → "Attach Script"
5. Save with Ctrl+S

### Script Editing Workflow

1. Click on a node that has a script → script opens in the built-in editor
2. Or double-click a `.gd` file in FileSystem
3. GDScript has autocompletion, inline docs, and error highlighting
4. Changes are hot-reloaded when you save (for most things)

### Debugging

```gdscript
# Print to Output panel
print("Debug: room_id = ", room_id)

# Warning (yellow in Output)
push_warning("This shouldn't happen but isn't fatal")

# Error (red in Output)
push_error("Critical failure: save file corrupted")

# Breakpoints: Click the left margin in the script editor to set a breakpoint
# The debugger panel shows variables, call stack, etc.
```

### Performance Tips for 2D

- **Don't use `_process()` if you don't need per-frame updates.** Use signals and timers instead.
- **Object pooling:** For decorations that are frequently added/removed, reuse nodes instead of creating/destroying.
- **Texture atlases:** Combine small sprites into sprite sheets to reduce draw calls.
- **Avoid `load()` in `_process()`.** Load resources in `_ready()` or cache them.

### Common Mistakes to Avoid

1. **Forgetting `queue_free()`** — removing a node with `remove_child()` doesn't free memory. Always use `queue_free()`.
2. **Accessing nodes before `_ready()`** — child nodes aren't initialized in `_init()`. Use `_ready()`.
3. **Circular dependencies** — if A references B and B references A, use signals instead.
4. **Not using `@onready`** — use `@onready var sprite: Sprite2D = $Sprite2D` instead of `get_node()` in `_ready()`.
5. **String paths for nodes** — fragile. If you rename a node, all `$OldName` references break. Use signals.

---

## 19. Troubleshooting Common Issues

### "Can't open file 'res://...' "
- Check the file actually exists at that path
- Check capitalization (some exports are case-sensitive)
- Ensure the file is inside the project folder (below `project.godot`)

### Pixel art looks blurry
- Check `Project Settings → Rendering → Textures → Default Texture Filter` = `Nearest`
- Check individual import settings: select the image → Import tab → Filter = `Nearest` → Reimport
- Ensure stretch mode is `viewport` and scale mode is `integer`

### No sound playing
- Check the `.ogg`/`.wav` file exists at the path
- Check volume is not 0 (remember: `linear_to_db(0.0)` = -80 dB = silent)
- Check the `AudioStreamPlayer` is added to the scene tree (`add_child()`)
- Check the Output panel for error messages

### Window won't go borderless / always-on-top
- These flags require the window to be focused
- `per_pixel_transparency/allowed` must be `true` in project settings
- Some Windows settings (like focus assist) can interfere

### Save file not persisting
- Check `user://` path is writable
- Check for JSON serialization errors in Output
- Verify `Vector2` values are converted to arrays before saving

### Godot Editor crashes on open
- Delete `.godot/` folder and reopen — it will regenerate
- Check for invalid `.tscn` or `.tres` files (manual editing can break them)

### Export fails
- Ensure export templates are installed (Editor → Manage Export Templates)
- Ensure the export path directory exists
- Check the Output panel for detailed error messages

---

## 20. Reference: Mini Cozy Room Feature Specification

Based on the reference game "Mini Cozy Room: Lo-Fi" by Tesseract Studio:

### Core Features

1. **Room Decoration**
   - 3 base room styles: Cozy Studio, Moonlight Study, Nest Room
   - Each room has 2-3 themes (Modern, Natural, Pink, Magic)
   - Free placement of furniture and decorations via drag-and-drop
   - 12+ decoration items across categories (seating, storage, lighting, plants, music, wall)

2. **Character Customization**
   - 5 character options with different appearances
   - Character sits/stands in the room
   - Different outfits available (casual, formal, themed)

3. **Music Player**
   - Lo-fi track library (add royalty-free tracks)
   - Playback controls: play, pause, skip, previous
   - Playlist modes: sequential, shuffle, repeat one
   - Volume control with slider

4. **Ambient Sound Mixer**
   - 7+ ambient sounds: rain, wind, typing, fireplace, birds, cafe, white noise
   - Mix multiple sounds simultaneously
   - Independent volume per sound type
   - Master volume, music volume, ambience volume controls

5. **To-Do List**
   - Add tasks with text
   - Mark tasks as complete (checkbox toggle)
   - Delete completed tasks
   - Persists across sessions

6. **Memo Pad**
   - Create, edit, save text notes
   - Multiple memos with titles
   - Delete memos
   - Persists across sessions

7. **Pomodoro Timer**
   - Configurable work/break/long break durations
   - Default: 25 min work, 5 min break, 15 min long break
   - Session counter (4 sessions before long break)
   - Gentle notification on completion
   - Start, pause, reset controls

8. **Mini Mode**
   - Small window (320x180) docked to screen edge
   - Borderless, always-on-top
   - Access to music controls and timer in compact layout
   - Toggle with Ctrl+M keyboard shortcut

9. **Settings**
   - Room and theme selection
   - Character selection
   - Language selection (future: EN, JA, KO, RU, ZH)
   - Display mode (windowed / mini)

### Unique Twist: Organizational Mindfulness

Our version adds a meditation/mindfulness layer:
- The cozy room serves as a visual anchor for focused work sessions
- The Pomodoro timer guides work/break cycles
- The to-do list helps externalize tasks (reducing cognitive load)
- The ambient sounds create a consistent "focus environment"
- The decoration system provides a creative, relaxing break activity

The goal is not just a pretty desktop widget, but a tool that helps users **develop organized thinking habits** through gentle, gamified routines.
