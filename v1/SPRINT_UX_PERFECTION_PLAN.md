# Mini Cozy Room — UX Perfection Plan

> **Date:** 2026-04-06
> **Deadline:** 2026-04-11 (5 days)
> **Objective:** Every dimension at ★★★★★ before delivery
> **Rule:** Each item has a concrete fix, estimated effort, and acceptance criteria.

---

## Current State vs Target

| # | Dimension | Current | Target | Gap Analysis | Priority |
|---|-----------|---------|--------|-------------|----------|
| 1 | First Launch Experience | ★★★☆☆ | ★★★★★ | No tutorial mission. Player dropped into room with zero guidance. | P0 |
| 2 | Room Customization | ★★★★☆ | ★★★★★ | Placement type validation missing (wall vs floor). Decorations can be placed in wrong zones. | P1 |
| 3 | Audio Experience | ★★★☆☆ | ★★★★★ | Only 2 tracks, 0 ambience. User will provide more audio assets. | P1 |
| 4 | Settings Depth | ★★★☆☆ | ★★★★★ | No display/resolution controls. No music track info display. | P2 |
| 5 | Account Management | ★★★★☆ | ★★★★★ | Flow is complete. Missing: password change, account recovery info. | P2 |
| 6 | Visual Feedback | ★★★☆☆ | ★★★★★ | No toast/notification system for save success, decoration placed, etc. | P1 |
| 7 | Error Handling (UI) | ★★★★☆ | ★★★★★ | Auth errors work. Missing: save failure notification, DB errors surfaced to user. | P2 |
| 8 | Accessibility | ★★☆☆☆ | ★★★★★ | No keyboard navigation for panels. No focus indicators. | P1 |
| 9 | Mobile Support | ★★☆☆☆ | ★★★★★ | Virtual joystick exists but no responsive layout or touch-adapted panels. | P2 |
| 10 | **Character Interaction** | ★☆☆☆☆ | ★★★★★ | CRITICAL: Character collision with decorations is broken. Can't sit, lay, interact. Walks out of room. | **P0** |
| 11 | **Character Selection** | ☆☆☆☆☆ | ★★★★★ | No character selection screen. Player must choose before entering room. | **P0** |
| 12 | **Pet Behavior** | ☆☆☆☆☆ | ★★★★★ | `cat_void.tscn` has no behavior script. Pet is static. | P1 |
| 13 | **Tutorial Mission** | ☆☆☆☆☆ | ★★★★★ | No first-run guidance at all. Must be a scripted tutorial mission. | **P0** |
| 14 | **Panel Visual Design** | ★★★☆☆ | ★★★★★ | All panels built programmatically. Need `.tscn` scene-based design for visual polish. | P1 |

---

## CRITICAL FIXES (P0) — Days 1-2

### FIX-01: Character Physics & Decoration Interaction (★☆☆☆☆ → ★★★★★)

**Current problems (verified):**
1. Character walks over some decorations instead of colliding
2. Character gets blocked too far from decorations (collision shape too large)
3. Character cannot interact with furniture (sit on chair, lay on bed)
4. Placing decorations causes character movement to bug out
5. Character can walk outside room boundaries

**Root cause analysis:**

In [room_base.gd](file:///media/renan/New%20Volume/PROIECT/projectwork/Projectwork/v1/scripts/rooms/room_base.gd#L112-L123), each decoration gets a `StaticBody2D` with a `RectangleShape2D` sized to the full texture. Problems:
- Collision shape uses raw `texture.get_size()` but the sprite is scaled by `item_scale` (often 3x–6x) — the collision box doesn't match the visual
- No offset adjustment for non-centered sprites (`sprite.centered = false`)
- No interaction system exists — only collision blocking

In [character_controller.gd](file:///media/renan/New%20Volume/PROIECT/projectwork/Projectwork/v1/scripts/rooms/character_controller.gd#L14-L15), the character collides with layer 1 (walls) and layer 2 (decorations), but:
- `move_and_slide()` with mismatched collision shapes causes tunneling or excessive pushback
- No room boundary enforcement beyond wall collisions
- No interaction prompt system

**Prescribed fixes:**

```
1. Fix collision shape sizing:
   - Multiply rect.size by item_scale to match visual
   - Add offset for non-centered sprites: shape.position = (texture.get_size() * item_scale) / 2.0
   - Use smaller collision shapes (60-80% of visual) so character can get close

2. Add room boundary enforcement:
   - Add invisible StaticBody2D walls at room edges in main.tscn
   - Or clamp character position in _physics_process to room bounds

3. Add interaction system:
   - Create Area2D on each interactable decoration (beds, chairs, desks)
   - When character enters Area2D + presses interact key → play interaction animation
   - Define "interactable" flag in decorations.json catalog
   - Interaction types: "sit" (chairs), "lay" (beds), "use" (desks)

4. Fix decoration placement character displacement:
   - When a decoration is placed, check if it overlaps with character position
   - If overlap, nudge character to nearest free position
   - Or temporarily pause character collision during placement
```

**Acceptance criteria:**
- [ ] Character walks close to (but not through) all decorations
- [ ] Character cannot leave the room boundaries under any circumstances
- [ ] Character can sit in chairs, lay in beds (interaction animation plays)
- [ ] Placing a decoration never causes character to teleport or bug out
- [ ] Collision shapes visually match decoration sprites at all scales

**Effort:** 6-8 hours

---

### FIX-02: Character Selection Screen (☆☆☆☆☆ → ★★★★★)

**Current state:** Only `male_old` is wired. `female-character.tscn` and `male-character.tscn` exist but are unreachable.

**Prescribed fix:**

Create a character selection screen that appears BEFORE entering the room:

```
Flow: Auth Screen → Character Selection → Room

Scene: scenes/menu/character_select.tscn
Script: scripts/menu/character_select.gd

UI Layout:
┌──────────────────────────────────────┐
│         Choose Your Character         │
│                                      │
│   [← ]  🧑 Character Preview  [ →]  │
│          "Ragazzo Classico"           │
│                                      │
│        [ Start Playing ]             │
└──────────────────────────────────────┘

Requirements:
- Display animated character preview (idle animation)
- Left/Right arrows to cycle through available characters
- Character name displayed below preview
- "Start Playing" button transitions to room
- Selection saved to SaveManager.character_data
- Wire all 3 character .tscn files in CHARACTER_SCENES
```

**Acceptance criteria:**
- [ ] Player can browse all available characters before entering room
- [ ] Selected character appears in room with correct animations
- [ ] Selection persists across sessions (saved to JSON + SQLite)
- [ ] New Game always shows character selection
- [ ] Load Game skips selection and uses saved character

**Effort:** 4-5 hours

---

### FIX-03: Tutorial Mission (☆☆☆☆☆ → ★★★★★)

**Current state:** No guidance at all. Player is dropped into an empty room.

**Prescribed fix — Scripted Tutorial Mission:**

```
Scene: scenes/menu/tutorial.tscn
Script: scripts/menu/tutorial.gd

Tutorial flow (scripted mission, not text dump):

MISSION 1: "Welcome Home"
  Step 1: "This is your cozy room! Let's make it yours."
          → Highlight room, brief pause
  Step 2: "First, let's add some furniture. Open the Decorations panel."
          → Arrow pointing to DecoButton, wait for click
  Step 3: "Great! Choose a bed from the catalog."
          → Highlight "Beds" category, wait for category open
  Step 4: "Now drag a bed into your room!"
          → Wait for decoration_placed signal with category="beds"
  Step 5: "Perfect! Now add a desk for studying."
          → Wait for desk placement
  Step 6: "You can rotate, flip, or resize any decoration. Try clicking on your bed."
          → Wait for decoration_selected signal
  Step 7: "Try pressing R to rotate it!"
          → Wait for decoration_rotated signal
  Step 8: "Excellent! Your character can walk around with WASD or arrow keys. Try it!"
          → Wait for character movement input
  Step 9: "You can interact with furniture by walking up to it and pressing E."
          → Wait for interaction
  Step 10: "Your room is starting to look cozy! Everything saves automatically."
           → Show save indicator
           → "Mission Complete! Enjoy your Mini Cozy Room! 🏠"

UI Components:
- Semi-transparent overlay
- Speech bubble/dialog box at bottom (pixel art style)
- Mascot character or icon for the tutorial narrator
- Arrow indicators pointing to relevant UI elements
- Progress dots showing current step
- "Skip Tutorial" button (always visible)

Technical:
- Tutorial state saved to SaveManager (tutorial_completed: bool)
- Only triggers on first New Game
- Can be replayed from Settings panel
- Each step waits for the specific signal/input before advancing
- Steps have timeout fallback (auto-advance after 30s with "Need help?" prompt)
```

**Acceptance criteria:**
- [ ] Tutorial triggers automatically on first New Game
- [ ] Each step waits for the player's action before advancing
- [ ] Arrow indicators correctly point to the right UI elements
- [ ] Tutorial can be skipped at any time
- [ ] Tutorial completion state persists (never shows again unless requested)
- [ ] Tutorial can be replayed from Settings
- [ ] Tutorial feels like a mission, not a text wall

**Effort:** 8-10 hours

---

## HIGH PRIORITY FIXES (P1) — Days 3-4

### FIX-04: Pet Behavior System (☆☆☆☆☆ → ★★★★★)

**Prescribed fix:**

```
Script: scripts/rooms/pet_controller.gd

Behavior state machine:
- IDLE: Random idle animation, occasional look-around
- WANDER: Walk to random position within room bounds (slow speed)
- FOLLOW: Follow character at distance when character moves
- SLEEP: Curl up and play sleep animation (triggers after 2 min idle)
- PLAY: React to character proximity (bounce, purr particles)

Requirements:
- Pet stays within room boundaries
- Pet avoids decorations (uses same collision system)
- Pet has at least 3 animations (idle, walk, sleep)
- Pet randomly transitions between states
- Pet follows character if character gets far enough away
```

**Effort:** 4-5 hours

### FIX-05: Panel Visual Design — Scene-Based (.tscn)

**Current problem:** All panels are built programmatically in GDScript. For a video game, the visual design needs to be artist-accessible and polished.

**Prescribed fix:**
- Redesign `deco_panel.tscn`, `settings_panel.tscn`, `profile_panel.tscn` with proper scene trees in the Godot editor
- Use the existing `cozy_theme.tres` for consistent styling
- Add proper margins, padding, icons, and visual hierarchy
- Keep scripts for logic, but move layout to `.tscn`
- Add hover effects and focus indicators to all buttons

**Effort:** 4-6 hours

### FIX-06: Toast/Notification System

**Prescribed fix:**

```
Script: scripts/ui/toast_manager.gd (Autoload)

Features:
- show_toast(message: String, duration: float = 3.0, type: String = "info")
- Types: "info" (blue), "success" (green), "warning" (yellow), "error" (red)
- Slide-in from top-right, auto-dismiss
- Queue multiple toasts (stack vertically)

Trigger points:
- Save completed → "Game saved ✓"
- Decoration placed → "Decoration added"
- Character selected → "Character changed"
- Auth success → "Welcome back!"
- Error → red toast with message
```

**Effort:** 2-3 hours

### FIX-07: Audio Content Integration

**User will provide audio assets.** Once downloaded:
- Add tracks to `data/tracks.json`
- Add ambience entries to `tracks.json` ambience array
- Place audio files in `res://assets/audio/music/` and `res://assets/audio/ambience/`
- Verify paths pass CI sprite validator

**Effort:** 1-2 hours (after assets received)

### FIX-08: Placement Zone Validation

**Prescribed fix:**
- In `room_base.gd._on_decoration_placed()`, check `placement_type` from catalog
- Floor items: only below wall zone (40% viewport height)
- Wall items: only in wall zone
- Visual feedback: green/red highlight on valid/invalid zones during drag

**Effort:** 1-2 hours

### FIX-09: Keyboard Navigation & Focus

**Prescribed fix:**
- Set `focus_mode = FOCUS_ALL` on all interactive controls
- Define tab order for each panel
- Add visible focus ring (outline style in `cozy_theme.tres`)
- Handle Enter key on focused buttons
- Arrow key navigation within panel grids

**Effort:** 2-3 hours

---

## STANDARD PRIORITY FIXES (P2) — Day 5

### FIX-10: Settings Enhancement

- Add display mode toggle (Windowed / Fullscreen / Borderless)
- Add current track name display
- Add "Replay Tutorial" button
- Add version number display

**Effort:** 2-3 hours

### FIX-11: Mobile/Touch Adaptation

- Responsive panel sizing based on viewport
- Touch-friendly button sizes (min 44px)
- Virtual joystick visibility toggle
- Pinch-to-zoom for decoration placement

**Effort:** 3-4 hours (can defer post-deadline if needed)

### FIX-12: Error Surface & Account Polish

- Save failure → toast notification
- DB error → non-blocking toast (not crash)
- Add "Change Password" to profile panel
- Show account creation date in profile

**Effort:** 2-3 hours

---

## 5-Day Sprint Schedule

| Day | Date | Focus | Deliverables |
|-----|------|-------|-------------|
| **Day 1** | Apr 7 | **Character Physics & Interaction** | FIX-01: Collision fixes, room boundaries, interaction system skeleton |
| **Day 2** | Apr 8 | **Character Selection + Tutorial Start** | FIX-02: Character select screen. FIX-03: Tutorial framework and first 5 steps |
| **Day 3** | Apr 9 | **Tutorial Completion + Pet + Panels** | FIX-03: Tutorial complete. FIX-04: Pet behavior. FIX-05: Panel redesign start |
| **Day 4** | Apr 10 | **Polish + Audio + Tests** | FIX-06: Toasts. FIX-07: Audio. FIX-08: Placement. FIX-09: Keyboard nav. Tests + CI integration |
| **Day 5** | Apr 11 | **Final Polish + Validation** | FIX-10: Settings. FIX-12: Error handling. Full smoke test. CI green. Export builds verified |

---

## Test Integration Plan

> **Answer to your question: Yes, tests will be part of the unified CI.**

```yaml
# Addition to .github/workflows/ci.yml

  test:
    name: "GdUnit4 Tests"
    runs-on: ubuntu-22.04
    timeout-minutes: 10
    container:
      image: barichello/godot-ci:4.6
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Run GdUnit4 tests
        run: |
          cd v1
          godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests
```

Test files will live in `v1/tests/unit/` and follow GdUnit4 naming convention (`test_*.gd`).

Priority test targets:
1. `test_helpers.gd` — Pure function tests (vec2 serialization, clamping, grid snap)
2. `test_save_migration.gd` — Save data migration chain v1→v5
3. `test_auth_validation.gd` — Input validation, rate limiting logic
4. `test_constants.gd` — Verify constants match catalog IDs

---

## Acceptance Matrix — All ★★★★★

| Dimension | Acceptance Criteria for ★★★★★ |
|-----------|-------------------------------|
| First Launch | Tutorial mission guides player through all mechanics step-by-step |
| Room Customization | Placement validates wall/floor zones, visual feedback on valid/invalid |
| Audio | 5+ music tracks, 3+ ambience tracks, crossfade working |
| Settings | Volume + language + display mode + track info + replay tutorial |
| Account Management | Login/register/guest/delete/logout/change password all work |
| Visual Feedback | Toast notifications for save, placement, errors, auth |
| Error Handling | All errors surfaced via toasts, never silent failures |
| Accessibility | Full keyboard navigation, focus indicators, tab order |
| Mobile Support | Responsive panels, touch-friendly buttons, joystick integration |
| Character Interaction | Walk near furniture, sit/lay/use interactions, no physics bugs |
| Character Selection | Choose character before room, preview with animation |
| Pet Behavior | Wander, follow, sleep, play — autonomous behavior |
| Tutorial | Scripted mission with 10 steps, skip option, replay option |
| Panel Design | Scene-based `.tscn` layouts, themed, polished, accessible |

---

## Addon Cleanup

**Decision: Delete `gdterm` and `py4godot`.**

Neither addon is referenced in any script. They add unnecessary weight to exports. Removal steps:
1. Delete `v1/addons/gdterm/`
2. Delete `v1/addons/py4godot/`
3. Verify no `preload()` or `load()` references exist
4. Push and verify CI passes

---

## Corrections to Audit Report

| Original Claim | Correction |
|----------------|------------|
| "v1.0 Target: 3+ rooms" | **1 room only.** This is the intended scope. |
| "BUG-02: Randomize menu character" | **Not a bug.** The menu walk-in uses the single default character. If character selection is added, the menu can show the player's selected character instead. |
| "ARCH-03: Remove .uid files" | **Do not remove.** Supabase integration is planned for this week. Leave `.uid` files in place. |
| "6-month roadmap" | **Invalid.** Deadline is April 11, 2026. 5-day sprint only. |
| "Multiple rooms in roadmap" | **Invalid.** Single room is the product scope. |

---

*This document is the execution contract for the 5-day sprint to April 11.*
