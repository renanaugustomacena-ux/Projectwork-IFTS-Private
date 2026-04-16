# Figma → Code Integration Rules (Relax Room)

Rules doc for translating Figma designs into this **Godot 4.6** codebase via the Figma MCP. Godot has **no CSS/React**; the analog is scene tree + `Theme` resource + GDScript. All mappings below respect that.

---

## 0. Critical Ground Truth Before Any Figma Work

- **Engine:** Godot 4.6, GL Compatibility renderer, **pixel art** (nearest filter).
- **Viewport:** fixed `1280×720`, stretch mode `canvas_items`, integer scaling.
- **No React, no CSS, no Tailwind, no TS.** Figma-generated React snippets are REFERENCE only — never paste them into this repo.
- **No custom fonts.** Godot default font used everywhere. Do not introduce `.ttf`/`.otf` unless user approves.
- **Icons are raster PNG**, not SVG. Do not convert Figma SVG exports to SVG assets — export as PNG at pixel-perfect integer scale.
- **Single source of UI truth:** `v1/assets/ui/cozy_theme.tres` — applied globally via `project.godot → gui/theme/custom`.

If Figma design implies a different stack (web, React, continuous scaling, vector icons), STOP and ask the user before proposing changes.

---

## 1. Design Tokens

### Where tokens live
- **Global theme resource:** `v1/assets/ui/cozy_theme.tres` (colors, font sizes, StyleBox textures per Control type).
- **Game constants:** `v1/scripts/utils/constants.gd` — class `Constants` — viewport size, durations, sync intervals.
- **Per-scene overrides:** inside `.tscn` files via `theme_override_*` properties, or via GDScript `add_theme_*_override(...)`.

### Canonical palette (from `cozy_theme.tres`)
| Role                | Color                               |
|---------------------|-------------------------------------|
| Primary warm (text, buttons) | `Color(0.95, 0.9, 0.8, 1)`  |
| Hover accent        | `Color(1, 0.98, 0.9, 1)`            |
| Wall overlay        | `Color(0.165, 0.145, 0.208, 0.6)`   |
| Floor overlay       | `Color(0.239, 0.2, 0.278, 0.6)`     |
| Placeholder (LineEdit) | `Color(0.7, 0.65, 0.55, 0.5)`    |
| Disabled            | `Color(0.6, 0.6, 0.6, 0.7)`         |
| Toast success bg    | `Color(0.1, 0.18, 0.12, 0.92)` / border `Color(0.3, 0.8, 0.4, 0.9)` |
| Toast warning bg    | `Color(0.2, 0.16, 0.08, 0.92)` / border `Color(0.9, 0.7, 0.2, 0.9)` |
| Toast error bg      | `Color(0.2, 0.08, 0.08, 0.92)` / border `Color(0.9, 0.3, 0.3, 0.9)` |
| Toast info bg       | `Color(0.1, 0.1, 0.16, 0.92)` / border `Color(0.4, 0.5, 0.8, 0.9)` |
| Default clear color | `Color(0.12, 0.11, 0.18, 1)`        |

**Rule:** Figma color tokens map to entries in `cozy_theme.tres`. If Figma introduces a new role, add it to the theme — do NOT hardcode `Color(...)` inline in scripts or scenes.

### Typography
- Button font size: **16**
- Toast label: **13**
- Label shadow: offset `(1, 1)`, color `Color(0.1, 0.08, 0.06, 0.3)`
- No font family choice. Figma font choices are ignored — only size maps over.

### Spacing / radii
- Panel margin: **8px**
- Container separation: **6–12px**
- Toast: margin 20px, gap 8px, height 40px, corner radius 8px, border-left 3px
- StyleBoxTexture uses 9-slice with 5px margins, `axis_stretch_{h,v} = 2` (tile)

---

## 2. Component Library (Scenes + Scripts)

Every reusable UI "component" is a **scene + script pair**. No nested scene inheritance for UI; composition is done in `_ready()`.

| Scene | Script | Role |
|---|---|---|
| `v1/scenes/ui/deco_panel.tscn` | `v1/scripts/ui/deco_panel.gd` | Right-side decoration catalog, drag-drop source |
| `v1/scenes/ui/profile_panel.tscn` | `v1/scripts/ui/profile_panel.gd` | Modal profile info |
| `v1/scenes/ui/settings_panel.tscn` | `v1/scripts/ui/settings_panel.gd` | Modal audio sliders + language |
| `v1/scenes/ui/virtual_joystick.tscn` | `addons/virtual_joystick/virtual_joystick.gd` | Bottom-left mobile joystick |
| `v1/scenes/menu/main_menu.tscn` | `v1/scripts/menu/main_menu.gd` | Title → character walk-in → 5 buttons |
| `v1/scenes/menu/loading_screen.tscn` | (data-driven) | Animated bar + title |
| `v1/scenes/menu/auth_screen.tscn` | (auth flow) | Username/password LineEdits |
| `v1/scenes/menu/character_select.tscn` | (char select) | Character choice |
| `v1/scenes/main/main.tscn` | `v1/scripts/main.gd` | Root gameplay node |

**Rules for Figma → component mapping:**
- A Figma "component" → a `.tscn` scene, attached script with same basename.
- Modal panels must be driven by `PanelManager` (`v1/scripts/ui/panel_manager.gd`) — mutual exclusion + Escape-to-close.
- Do not create a new panel without registering it with `PanelManager`.
- Toast variants (success / warning / error / info) go through `toast_manager.gd`, not fresh panels.

---

## 3. Frameworks & Libraries

- **Engine:** Godot 4.6, GL Compatibility.
- **Addons:**
  - `v1/addons/godot-sqlite/` — SQLite 4.7
  - `v1/addons/virtual_joystick/` — mobile joystick
- **Autoloads (singletons):** declared in `v1/project.godot`
  - `SignalBus` → `scripts/autoload/signal_bus.gd`
  - `AppLogger` → `scripts/autoload/logger.gd`
  - `LocalDatabase` → `scripts/autoload/local_database.gd`
  - `AuthManager`, `GameManager`, `SaveManager`, `SupabaseClient`, `AudioManager`
  - `PerformanceManager` → `scripts/systems/performance_manager.gd`
- **`class_name` declarations:** `Constants`, `Helpers`, `SupabaseConfig`, `SupabaseHttp`, `SupabaseMapper`, `PanelManager`.

**Architecture rule:** all UI → system communication flows through **`SignalBus`** (~31 global signals). No direct cross-module node refs. When Figma design implies a new interaction (e.g. new button), add a signal, don't reach into nodes.

---

## 4. Asset Management

### Layout
```
v1/assets/
├── audio/            lo-fi WAV, CROSSFADE_DURATION=2.0s
├── backgrounds/      parallax forest PNG layers
├── charachters/      character sprite sheets (note: existing typo)
├── menu/             buttons, loading, UI sprites
│   ├── loading/
│   ├── buttons_base/
│   ├── buttons_pressed/
│   ├── buttons_static/
│   └── ui/
├── pets/
├── room/             room background sprite
├── sprites/
└── ui/
    ├── cozy_theme.tres   ← GLOBAL THEME
    └── kenney_pixel-ui-pack/9-Slice/Ancient/ (brown, tan, grey, white)
```

### Rules
- Every asset has a sibling `.import` file. Commit both. Never hand-edit `.import`.
- **Texture filter:** nearest (pixel art). No bilinear. No mipmaps for UI.
- **No texture atlases** — sprites load individually; `AtlasTexture` is inline in `.tscn` for animation frames.
- Keep existing directory — including the `charachters/` typo — do not rename without user sign-off.
- Figma image exports → PNG at integer scale, dropped into the correct `assets/{category}/` folder.

---

## 5. Icon System

- All icons are **raster PNG**, not SVG.
- Location: `v1/assets/menu/` for menu/HUD icons (e.g. `sprite_settings.png`, `ui_female.png`, `ui_male.png`, `ui_stress_bar.png`).
- App icon: `v1/icon.svg` (only place SVG is allowed — Godot export uses it).
- **Naming:** `{context}_{variant}.png` (e.g. `ui_female`, `ui_male`, `sprite_settings`).
- **Usage:**
  ```gdscript
  # in .tscn
  texture = ExtResource("id_ref")
  # in .gd
  var tex := load("res://assets/menu/sprite_settings.png")
  ```
- **Rule:** when Figma provides SVG icons, export as PNG at target pixel size (e.g. 16×16, 32×32), avoid non-integer sizes, keep nearest filter.

---

## 6. Styling Approach (Godot analog of CSS)

### Global
- `v1/assets/ui/cozy_theme.tres` wired via `project.godot → gui/theme/custom="res://assets/ui/cozy_theme.tres"`.
- Defines per-control-type: Button, Label, Panel, Slider, LineEdit, OptionButton, PopupMenu, ScrollBar, CheckButton.
- StyleBoxes: `StyleBoxTexture` (9-slice from Kenney pack) + `StyleBoxFlat` (toast bgs).

### Per-scene overrides
```gdscript
add_theme_constant_override("margin_left", 8)    # MarginContainer
add_theme_constant_override("separation", 6)     # VBoxContainer
add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1))
add_theme_font_size_override("font_size", 16)
add_theme_stylebox_override("panel", style)
```

### Layout & responsiveness
- **Anchors** for modal center: `anchor_left=0.5, anchor_right=0.5`.
- **Full-viewport HUD:** anchors `0..1`.
- **Containers:** `VBoxContainer`, `HBoxContainer`, `size_flags_horizontal/vertical` for growth.
- **Fixed viewport 1280×720** + `canvas_items` stretch → responsiveness is scale, not reflow. Don't design breakpoints from Figma.

### Effects
- Panel fade: `Tween`, 0.3s on `modulate.a`.
- Toast: 0.3s fade-in + 3s hold + 0.3s fade-out.
- **CanvasLayer:** `10` = HUD, `90` = toasts.
- **No shaders for UI** currently. Avoid adding `.gdshader` without user approval.

---

## 7. Project Structure

```
v1/
├── scenes/
│   ├── main/         gameplay root
│   ├── menu/         menus + auth + loading
│   ├── ui/           panels, joystick
│   ├── room/         decorations, door, windows
│   └── _reference/   (not prod)
├── scripts/
│   ├── autoload/     singletons
│   ├── menu/
│   ├── ui/           panel_manager, toast_manager, drop_zone, panels
│   ├── rooms/
│   ├── systems/
│   ├── utils/        constants, helpers, supabase_*
│   └── _reference/
├── assets/           (see §4)
├── addons/           godot-sqlite, virtual_joystick
├── data/             JSON catalogs, save files
├── docs/
├── guide/
├── tests/
├── export/
├── project.godot
├── icon.svg
└── README.md
```

### Naming conventions — NON-NEGOTIABLE
- **Files:** `snake_case` (`deco_panel.gd`, `main_menu.tscn`)
- **`class_name`:** `PascalCase` (`PanelManager`)
- **Signals:** `snake_case` (`decoration_placed`)
- **Nodes in scenes:** `PascalCase` (`ButtonContainer`, `UILayer`)
- **Constants:** `UPPER_SNAKE_CASE`

---

## 8. `project.godot` Figma-Relevant Settings

```ini
[application]
config/name="Relax Room"
run/main_scene="res://scenes/menu/main_menu.tscn"
config/features=PackedStringArray("4.6")
config/icon="res://icon.svg"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/per_pixel_transparency/allowed=true

[gui]
theme/custom="res://assets/ui/cozy_theme.tres"

[rendering]
textures/canvas_textures/default_texture_filter=0  # nearest (pixel art)
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.12, 0.11, 0.18, 1)
```

---

## 9. Figma MCP Workflow (this repo)

1. **On Figma URL:** call `get_design_context` with `fileKey` + `nodeId`. Treat the React/Tailwind output as a reference only.
2. **Map tokens → theme:** any color / font-size / spacing/radius from Figma must land in `v1/assets/ui/cozy_theme.tres`, not inline in scripts.
3. **Map component → scene/script pair:**
   - Create `v1/scenes/ui/<snake_name>.tscn` + `v1/scripts/ui/<snake_name>.gd`.
   - If it is a modal, register with `PanelManager`.
   - Wire interactions through `SignalBus` signals — add new signal if needed.
4. **Assets:**
   - Icons → PNG at integer size, nearest filter, `v1/assets/menu/` or matching category.
   - Do NOT import SVG (exception: `icon.svg`).
5. **Layout:**
   - Use anchors + containers. Ignore Figma absolute positioning unless it is a one-off HUD element.
   - Do not design breakpoints; viewport is fixed.
6. **Text:**
   - Font family from Figma is ignored.
   - Font size maps via `add_theme_font_size_override` or theme entry.
7. **Never:**
   - Add Tailwind / CSS / React / Node deps.
   - Add a new font without user approval.
   - Hardcode palette values outside `cozy_theme.tres`.
   - Create a panel that bypasses `PanelManager`.
   - Use bilinear filtering on UI art.
8. **Code Connect mapping:** when registering Figma components against this repo, the "component" field points to a `.tscn` path, not a React component.

---

## 10. Quick Reference — Where to Edit What

| Figma change                   | Edit here                                      |
|--------------------------------|------------------------------------------------|
| New color / font size / radius | `v1/assets/ui/cozy_theme.tres`                 |
| New panel                      | `v1/scenes/ui/`, `v1/scripts/ui/`, register w/ `PanelManager` |
| New toast variant              | `v1/scripts/ui/toast_manager.gd`               |
| New global interaction signal  | `v1/scripts/autoload/signal_bus.gd`            |
| New icon / sprite              | `v1/assets/{category}/`, PNG + `.import`       |
| New menu button                | `v1/scenes/menu/main_menu.tscn` + `v1/scripts/menu/main_menu.gd` |
| Global duration / size constant| `v1/scripts/utils/constants.gd`                |
| Viewport / renderer / stretch  | `v1/project.godot`                             |
