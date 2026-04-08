# Sprint Task List — April 6-11

## Day 1: Character Physics & Interaction (Apr 6-7)
- [x] Delete unused addons (gdterm, py4godot)
- [x] Fix decoration collision shapes (footprint-based, not full sprite)
- [x] Add interaction Area2D to interactable decorations
- [x] Add interaction system to character_controller.gd (E key)
- [x] Add `interaction_type` field to decorations.json (beds=lay, chairs=sit, desks=use)
- [x] Fix BUG-03: profile panel escape key in main_menu.gd
- [x] Fix PERF-02: window_background.gd visibility gate
- [x] Wire female + male character scenes in CHARACTER_SCENES
- [x] Add interaction signals to SignalBus
- [x] Character nudge on decoration overlap placement
- [x] CI validators passing (JSON catalogs + DB schema)
- [x] Add character IDs to constants.gd
- [x] Fix BUG-04: audio crossfade double-advance

## Day 2: Character Selection + Tutorial Start (Apr 8)
- [x] Create character_select.gd and character_select.tscn
- [x] Wire all 3 character .tscn files
- [x] Wire character selection into main menu flow (New Game → Select → Room)
- [x] Create tutorial.gd framework (tutorial_manager.gd with 10-step mission)
- [x] Implement all 10 tutorial steps
- [x] Wire tutorial into main.gd (first-launch detection, completion save)

## Day 3: Animations + Pet + Toast (Apr 9)
- [x] Fix female character animation names (walk_vertical → walk_side)
- [x] Generate cat pet reference sprites (walk, sleep, play)
- [x] Create pet_controller.gd with 5-state machine (idle/wander/follow/sleep/play)
- [x] Update cat_void.tscn with controller script and proper config
- [x] Wire pet spawning into room_base.gd
- [x] Create toast_manager.gd (4 types: info/success/warning/error)
- [x] Add toast_requested signal to SignalBus
- [x] Wire toast manager into main.gd

## Day 4: Compile Fixes + Lint Cleanup (Apr 10)
- [x] Fix sha256_buffer compile error in auth_manager.gd (→ HashingContext)
- [x] Fix sha256_buffer compile error in save_manager.gd (→ HashingContext)
- [x] Delete corrupt reference PNGs (WebP saved as .png)
- [x] Fix UID duplicate warnings (strip UIDs from _reference/ scenes)
- [x] Fix _deco_data private access (→ public deco_data)
- [x] Fix _dismiss_popup private access (→ public dismiss_popup)
- [x] Fix snapped variable shadowing built-in (→ snap_pos)

## Day 5: Final Polish + Validation (Apr 11)
- [x] Settings enhancements (replay tutorial option)
- [x] Keyboard navigation focus system
- [ ] Full smoke test in Godot editor
- [ ] CI green (JSON + DB validators)
- [ ] Export builds verified
