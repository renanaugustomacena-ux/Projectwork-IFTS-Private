# Mini Cozy Room — Sprint Walkthrough

> **Sprint:** April 6–11, 2026
> **Status:** Day 1-2 complete (14/14 items done)
> **Remaining:** Days 3-5 (pet behavior, panel polish, toasts, tests, final polish)

---

## Changes Made

### 1. Addon Cleanup
- **Deleted:** `v1/addons/gdterm/` and `v1/addons/py4godot/` — confirmed zero references in codebase
- **Impact:** Cleaner exports, reduced build size

### 2. Character Collision Physics Overhaul (FIX-01)

**Before:** Collision shapes used full `texture.get_size()` — a 32x32 sprite at 3x scale created a 96x96 solid wall. Character was blocked far from furniture.

**After:** Collision uses a bottom-30% footprint (70% width, 30% height), positioned at the base of the decoration. Character can now walk close to furniture naturally.

**Additionally:**
- Interaction `Area2D` added to beds (lay), chairs (sit), and desks (use)
- Character gets nudged to nearest free position if decoration placed on top of them
- All 3 character scenes wired in `CHARACTER_SCENES` dictionary

### 3. Furniture Interaction System (FIX-01)

- **E key** triggers interaction with nearby furniture
- Prompt label `[E] Sit` / `[E] Lay down` / `[E] Use` appears above character
- 2-second interaction animation plays (uses existing interact_* animations)
- Movement blocked during interaction
- Logged via AppLogger

### 4. Character Selection Screen (FIX-02)

**New files:**
- `character_select.gd` — Full-screen selection with SubViewport character preview
- `character_select.tscn` — Minimal scene wrapper

**Flow change:** New Game → **Character Select** → Room (Load Game skips selection)

**Features:**
- 3 characters: Ragazzo Classico, Ragazza Rossa, Ragazzo Giallo
- Animated idle preview in SubViewport
- Left/Right arrow navigation + keyboard support
- Character name and counter display

### 5. Tutorial Mission (FIX-03)

**New file:** `tutorial_manager.gd`

10-step scripted mission:
1. Welcome message (auto-advance)
2. Movement tutorial (waits for WASD/arrows)
3. Open Decorations panel (waits for panel_opened signal)
4. Place a decoration (waits for decoration_placed signal)
5. Select a decoration (waits for decoration_selected signal)
6. Interact with furniture (waits for interaction_started signal)
7. Open Settings (waits for panel_opened signal)
8. Open Profile (waits for panel_opened signal)
9. Close a panel with Escape (waits for panel_closed signal)
10. Completion message (auto-advance)

**Features:** Skip button, arrow indicators, 30s timeout per step, progress counter, fade animations, BBCode rich text.

### 6. Bug Fixes

| Bug | File | Fix |
|-----|------|-----|
| BUG-03: Profile panel can't close with Escape | `main_menu.gd` | Added `_profile_panel` tracking + `_close_profile()` + Escape handler |
| BUG-04: Audio crossfade double-advance | `audio_manager.gd` | Bound player identity to `_on_track_finished`, only advances if active player finished |
| PERF-02: Parallax running when hidden | `window_background.gd` | Added `if not visible: return` gate |

### 7. Data & Config Updates

| File | Change |
|------|--------|
| `signal_bus.gd` | Added `interaction_available`, `interaction_unavailable`, `interaction_started` signals |
| `constants.gd` | Added `CHAR_FEMALE` and `CHAR_MALE` constants |
| `decorations.json` | Added `interaction_type` field: beds=lay, chairs=sit, desks=use |

---

## Validation

- ✅ JSON catalog validator: PASSED (all 4 catalogs)
- ✅ DB schema validator: PASSED (all 5 tables)
- ✅ No references to deleted addons

## Remaining Work (Days 3-5)

- [ ] Pet behavior system (state machine: idle, wander, follow, sleep, play)
- [ ] Panel visual redesign to .tscn
- [ ] Toast notification system
- [ ] Audio content integration (user providing assets)
- [ ] Placement zone validation (wall vs floor)
- [ ] Keyboard navigation & focus
- [ ] Settings enhancements (display mode, track info, replay tutorial)
- [ ] GdUnit4 setup + CI integration
- [ ] Final smoke test + export verification
