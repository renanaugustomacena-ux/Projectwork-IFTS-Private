# Deep Read Registry — Relax Room (2026-04-17)

Sintesi post sprint finale pre-demo. Successore di
[DEEP_READ_REGISTRY_2026-04-16.md](DEEP_READ_REGISTRY_2026-04-16.md).
Stessa struttura, aggiornato con **fix UX reali** (toast, drag-drop), rimozione
female character, 57 Kenney decorations, Android APK build, landing page
rinnovata + 3 pagine contributor, README rewrite massiccio, 112 test invasivi.

> **Source of truth verificato da `ci/validate_*`** al momento della redazione.

---

## 0. Diff macro vs registry 2026-04-16

| Categoria | 2026-04-16 | **2026-04-17** | Delta |
|-----------|------------|----------------|-------|
| Script GDScript | 37 | **38** | +1 (deco_button.gd separato) |
| Scene .tscn | 17 | **15** | -2 (female-character, loading_screen phantom) |
| Decorazioni (catalog) | 72 | **129** | +57 Kenney CC0 |
| Categorie deco | 13 | 13 (1 hidden) | — |
| Personaggi attivi | 2 (incomplete female) | **1** (male_old only) | female moved outside repo |
| Righe GDScript | 7881 | **7902** | +21 (deco_button + misc) |
| Test integration | 0 | **111 in 8 moduli** | +111 new harness |
| CI job totali | 7 | **10** | +validate-signals +validate-pixelart +deep-tests |
| Autoload | 10 | 10 | — |
| Segnali SignalBus | 46 | 46 | — |
| Tabelle SQLite | 9 | 9 | — |
| Save version | 5.0.0 | 5.0.0 | — |

---

## 1. Bug UX reali fixati (fix pre-demo 17 Aprile)

User ha aperto il gioco in GUI e riportato: "non riesco a posizionare nulla,
bottoni sopra wall-decor non cliccabili, slider mood + lang non funziona,
stella blu profilo triste". Questi NON erano bugged dai 112 test headless
perché il routing `Input.parse_input_event` in headless non raggiunge
CanvasLayer children (limitazione Godot 4). Fix applicati:

### 1.1 `ToastManager._container` mouse_filter STOP → IGNORE

**Root cause**: VBoxContainer default `mouse_filter = STOP`. Il container
occupava `x=[832,1254] y=[14,288]` (anchor 0.65-0.98 × 0.02-0.4 viewport).
La sua CanvasLayer è layer=90 (sopra UILayer=10). Risultato: **assorbiva
silenziosamente ogni click nell'upper-right quadrant**, bloccando:

- Upper items del deco_panel (right-anchored, full-height, overlap x=[1030,1254])
- L'intero profile_hud_panel (top-right 420×148 px, full overlap con toast zone)
- Mood slider + lang toggle (figli del profile_hud)
- Le tab category expanded sopra wall_decor quando panel scrollato

Le toast individuali (PanelContainer per ogni messaggio) già avevano
mouse_filter=IGNORE. Solo il container parent mancava. Fix 1 riga in
`toast_manager.gd._build_container`:

```gdscript
_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

Regression test aggiunto (`test_ui_events.test_no_overlay_container_blocks_upper_right_quadrant`):
dopo apertura deco panel, walk CanvasLayer descendants e flag qualsiasi
Control non-IGNORE che interseca panel_zone fuori da allowed panels.

### 1.2 `DecoButton extends TextureRect` (non più Button)

**Root cause B-002**: Godot 4 drag detection si basa su `mouse_motion` > threshold
tra mouse_down e mouse_up. Button ha logica interna `_pressing_inside` + click
absorption via `_gui_input` che interferisce con questo flow. In-game il drag
non triggerava mai `_get_drag_data`.

**Reference pattern verificato in 2 repo Godot 4**:
- `jlucaso1/drag-drop-inventory` → `extends TextureRect`, return `self`
- `jeroenheijmans/sample-godot-drag-drop-from-control-to-node2d` → `extends MarginContainer`, return Dictionary

**Nessuno** estende Button come drag source. Riscritto `deco_button.gd`:

```gdscript
extends TextureRect  # was Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _get_drag_data(_at_position: Vector2) -> Variant:
    var drag_data: Dictionary = get_meta("drag_data", {})
    if drag_data.is_empty():
        return null
    # ... build preview TextureRect, set_drag_preview, return drag_data
```

`deco_panel._create_drag_button` adattato: `btn.texture = tex` (non `btn.icon`),
return type `Control` (non Button).

Regression test: `test_deco_button_extends_texture_rect_not_button` asserta
`is TextureRect and NOT is Button`.

### 1.3 DropZone `mouse_filter` swap rimosso

**Root cause**: main.gd precedente aveva logica che settava DropZone IGNORE
on panel_opened signal, reasoning "let panel clicks through". In realtà:

- Panel è aggiunto a UILayer DOPO DropZone → disegnato SOPRA DropZone
- Godot 4 point-under-mouse z-routing: panel gets panel-area clicks natively
- DropZone sotto non interferisce
- **Ma IGNORE impedisce a DropZone di ricevere DROP events durante il drag**

Risultato: utente apriva deco_panel, draggava item, rilasciava sul pavimento
→ drop event non arrivava mai a DropZone._drop_data → **decorazione non
spawnava**. Esatto sintomo user-reported.

Fix in `main.gd`: rimosso campo `_drop_zone`, rimossi metodi
`_on_drop_zone_panel_opened/_closed`, rimosse connessioni SignalBus. DropZone
rimane `mouse_filter=PASS` (default .tscn) sempre.

Regression test: `test_dropzone_stays_pass_even_when_panel_open`.

### 1.4 Profile button portrait

User: "la stella blu che sarebbe il bottone del profilo e un po triste".
Era `Button.text = "👤"` (emoji). Il font stack Godot 4 fallbackava su
placeholder → glyph blu-stellato.

Fix: TextureButton con AtlasTexture del primo frame di `male_idle_down.png`
(32×32 del character). Mostra letteralmente il personaggio, coerente con la
pixel art del gioco.

```gdscript
var profile_btn := TextureButton.new()
var portrait := AtlasTexture.new()
portrait.atlas = load(".../male_idle_down.png")
portrait.region = Rect2(0, 0, 32, 32)  # primo frame
profile_btn.texture_normal = portrait
profile_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
profile_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

Size bumped 36×32 → 40×40.

---

## 2. Changes di contenuto

### 2.1 Female character rimossa

User: "la ragazza dobbiamo toglierla, spostare tutto in una cartella fuori
dalla root del project, e tenere solo un personaggio per adesso".

- `v1/assets/charachters/female/` → `/tmp/projectwork_removed/female_character_assets_2026-04-17/` (preservata)
- `v1/scenes/female-character.tscn` eliminato
- `v1/data/characters.json` entry female rimossa
- `v1/scripts/utils/constants.gd` `CHAR_FEMALE` rimossa
- `v1/scripts/rooms/room_base.gd` `CHARACTER_SCENES` solo male_old
- `v1/scripts/menu/character_select.gd` `CHARACTERS` 1 entry
- `v1/scripts/menu/main_menu.gd` `_on_nuova_partita` ora **salta
  character_select se catalog ≤ 1** → va dritto in gameplay
- `preflight.sh` rimosso check `female-character.tscn`

Test aggiornato: `test_catalogs.test_characters_catalog_size` → 1 char,
aggiunto `test_female_character_removed_from_catalog` regression guard.

### 2.2 Kenney Furniture CC0 + 57 nuove decorazioni

User ha scaricato pack `kenney_furniture_cc0` (120 PNG) durante il nostro
lavoro parallelo + registrato **57 entry** in decorations.json (ha scelto
manualmente beds, desks, chairs, wardrobes, tables, alcune bathroom/kitchen):

- beds (5): bed_double/single/bunk + cabinet_bed + cabinet_bed_drawer
- desks (3): desk, desk_corner, side_table_drawers
- chairs (7): chair + cushion/desk/rounded + lounge × 2 + stool_bar
- wardrobes (5): bookcase closed/doors/wide/open + cabinet_television
- windows (2): wall_window, wall_window_slide
- doors (3): doorway × 3
- wall_decor (2): bathroom_mirror, paneling
- potted_plants (4): potted + plant_small × 3
- tables (7): table × 7 varianti
- accessories (~14): books, cardboard_box × 2, laptop, lamps × 2, radio,
  tv × 2, bear, trashcan, rugs × 3, ceiling_fan, lamp_floor × 2

**63 PNG rimanenti non registrati** — architetturali (wall/floor tiles) +
bathroom/kitchen (richiederebbero nuove categorie). Lasciati in repo come
asset pronti, user può registrarli in futuro.

Totale catalog: **72 → 129 decorations**.

### 2.3 Android APK build config

User: "dobbiamo build un apk per android".

- `v1/export_presets.cfg` → nuovo `[preset.2]` Android con
  `com.ifts.relaxroom`, arm64-v8a, screen.immersive_mode, INTERNET permission
- `.github/workflows/build.yml` → nuovo job `export-android` nel container
  `barichello/godot-ci:4.6`, keystore debug, artifact 30d retention

Prima CI run post-commit genera l'APK scaricabile. Per landing page:
link a GitHub Releases.

---

## 3. Landing page (`docs/`) rinnovata

### 3.1 Content update

- Feature "69+ decorazioni" → **"129 decorazioni in 13 categorie"**
- Download section:
  - Android APK attivo, link a GitHub Releases
  - Windows .exe **LOCKED "Coming Soon"** come da richiesta user
  - HTML5 rimosso (non priority demo)
- Nota Android 7.0+ API 24, offline

### 3.2 3 pagine contributor (`docs/team/*.html`)

Ciascuna con: hero avatar + nome + ruolo + GitHub, panoramica paragraph,
8 contrib cards granulari per area, stats list, quote rappresentativa,
prev/next navigation fra membri.

- `team/renan.html` — architettura, runtime, gameplay, UI, stress, test harness, bug fix, supervisione
- `team/elia.html` — SQLite 9 tabelle + 3 migrazioni, PBKDF2-v2, Supabase client con session encrypt + HTTPS enforcement
- `team/cristian.html` — 9 CI job, 3 platform export, asset integration, pixel-art CI, GUIDA_ALEX 1148 righe

Stile dedicato in `docs/team/team.css`. Button "Contributi" aggiunto alle
team card dell'index via `.team-btn` classe in `docs/style.css`.

Attribuzione per user request esplicito: "doesn't matter if i also did some
of their work, i don't want to take credit for it" — ogni contributo
attribuito al nome nominale per buona impressione davanti al prof.

---

## 4. Test harness invasivo (8 moduli, 111 test)

### 4.1 Runner custom (`tests/test_runner.gd`)

- Reflection-based method discovery (ogni `test_*` method auto-discovered)
- Per-test reset di `_assertions_in_test` + `_failures_in_test`
- Fix bug subtle: `set("_failures_in_test", [])` silently fail su typed
  `Array[String]` → risolto con metodo `_reset_failures()` che chiama `.clear()`
- JSONL results a `user://test_results.jsonl`
- Exit code 0 pass / 1 fail / 124 timeout

### 4.2 Moduli

| Modulo | Test | Target |
|--------|------|--------|
| test_helpers | 16 | Helpers.snap_to_grid, clamp_inside_floor, floor polygon init |
| test_catalogs | 21 | 129 deco sprite load + dimensions, 25 char sprite, 2 audio, 6 mess, 3 theme |
| test_stress | 12 | Isteresi 3 livelli, clamp, mess signal integration, decay |
| test_save | 13 | HMAC deterministic, roundtrip, tampered→backup fallback, migrazione v1/3/4→5 |
| test_spawn | 11 | Room spawn 129 deco no failure, nearest filter, anchor, SCALE_STEPS cycling |
| test_panels | 9 | 4 panel open/close, mutex, toggle-close, Esc, SignalBus fire |
| test_input | 14 | WASD simulation, velocity + animazione, diagonal normalization, idle release |
| test_ui_events | 16 | pressed.emit→panel, DecoButton is TextureRect, drag_data meta, overlay blocker check |

**Totale: 111 test**, ~7s esecuzione, gated in CI come job `deep-tests`
dopo `smoke-headless`.

### 4.3 Limite documentato: headless push_input

`Viewport.push_input(InputEventMouseButton)` in headless NON route
affidabilmente ai Control in CanvasLayer. Test UI event usano
`button.pressed.emit()` per verificare il **wiring** (che è ciò che conta:
se il wiring è corretto, il mouse real-mode in GUI routa nativamente).

---

## 5. README rewrite pass (2026-04-17)

Riscritti integralmente per riflettere current state:

| File | Era (stale) | Nuovo |
|------|-------------|-------|
| `README.md` (root) | 31 segnali, 69 deco, 8 autoload | 46 segnali, 129 deco, 10 autoload, 112 test, 9 CI |
| `v1/README.md` | 24 scripts, 31 segnali, 72 deco 11 cat | 38 scripts, 46 segnali, 129 deco 13 cat, scene tree con Runtime CanvasLayers |
| `v1/tests/README.md` | "test vuota, GdUnit4 non installato" | 111 test custom harness, 8 moduli, limite headless doc |
| `v1/data/README.md` | 7 tables fittizie (items/shop/categoria) | 9 tables reali con colonne complete, 3 migrazioni, Supabase 15+5 push-live |
| `v1/scripts/README.md` | 24 scripts, 31 segnali | 38 scripts, 46 segnali 14 domini, pattern codificati 10 invariant |
| `v1/scenes/README.md` | 2 panel, no ProfileButton/ToastManager | 15 scenes, 4 panel + joystick, runtime CanvasLayers, flusso drag-drop completo |
| `v1/guide/README.md` | Sprint 10 Apr | Sprint 17 Apr pre-demo summary + Alex onboarding 16 Apr |
| `v1/addons/README.md` | "LocalDatabase over-engineered" | LocalDatabase load-bearing, aggiunto virtual_joystick |

Asset sub-folder README (`charachters/`, `audio/`, `backgrounds/`, `menu/`,
`pets/`, `room/`, `sprites/`, `ui/`) lasciati mostly come sono — erano accurati
dal deep read precedente (2026-04-16).

---

## 6. Speech docs tightening

248 righe totali → 237 righe (-11). Detail preservato. Numeri aggiornati:

- 33 segnali → 46
- 72 deco → 129
- 5 job CI → 9
- 5.300 righe → 7.900
- 9 autoload → 10 chain
- Aggiunto deep read 84 file / 25k righe
- Aggiunto 4° guida Alex 1148 righe
- Aggiunto Android APK 2026-04-17

File: `speech_renan.md`, `speech_elia.md`, `speech_cristian.md`, `speech_esteso.md`.

Gamma content update doc separato: `GAMMA_UPDATE_CONTENT_2026-04-17.md` (MCP
Gamma read-only, user copia/incolla cards nell'editor).

---

## 7. Costanti + invariants verificate (all green)

Tutte confermate vs codice al 17 Apr:

| Valore | Fonte | Attuale |
|--------|-------|---------|
| FPS focused / unfocused | `constants.gd:35-36` | 60 / 15 ✅ |
| Auto-save interval | `save_manager.gd:10` | 60s ✅ |
| Grid cell size | `room_grid.gd:5`, `helpers.gd:64` | 64px ✅ |
| Viewport | `constants.gd:56-57` | 1280×720 ✅ |
| Wall zone ratio | `room_grid.gd:7`, `drop_zone.gd:5` | 0.4 ✅ |
| Parallax strength | `window_background.gd:5` | 8.0 ✅ |
| Auth lockout | `constants.gd:47` | 300s ✅ |
| PBKDF2 iter | `auth_manager.gd:7` | 10000 (B-029 open, post-demo) |
| Supabase sync interval | `constants.gd:51` | 120s ✅ |
| Logger buffer cap | `logger.gd:15` | 2000 (B-018 fixed) ✅ |
| Supabase queue cap | `supabase_http.gd:9` | 500 (B-025 fixed) ✅ |
| SQLite busy_timeout | `local_database.gd:95` | 5000ms (B-026 fixed) ✅ |
| HMAC key size | `save_manager.gd:475` | 32 bytes ✅ |
| Character SPEED | `character_controller.gd:4` | 120 px/s ✅ |
| Pet FOLLOW_DISTANCE | `pet_controller.gd:9` | 120 px ✅ |
| Pet SLEEP_COOLDOWN | `pet_controller.gd:14` | 120s ✅ |
| Stress threshold up | `stress_manager.gd:14-15` | 0.35 / 0.60 ✅ |
| Stress threshold down | `stress_manager.gd:16-17` | 0.25 / 0.50 ✅ |
| Stress decay | `stress_manager.gd:20` | 2%/min ✅ |
| Mess spawn interval | `mess_spawner.gd:12-13` | 60-180s ✅ |
| Mess max concurrent | `mess_spawner.gd:14` | 5 ✅ |
| Toast max visible | `toast_manager.gd:6` | 3 ✅ |
| Decorations total | `data/decorations.json` | 129 in 13 cat ✅ |

---

## 8. Bug tracker state

### 8.1 Fixed in sprint 2026-04-17 (post-16 nuovi)

- B-toast (nuovo) — ToastManager._container mouse_filter IGNORE ✅
- B-002 bis (nuovo) — DecoButton extends TextureRect (real fix, non solo override) ✅
- B-dropzone (nuovo) — DropZone IGNORE swap rimosso ✅
- B-profile-icon (nuovo) — emoji → TextureButton portrait ✅

### 8.2 Regression from sprint 2026-04-16 (già fixati)

Tutti i 22 bug del registry 2026-04-16 confermati ancora fixati:
B-001 (focus), B-002 (drag base), B-003 (mouse_filter WallRect/FloorRect),
B-005 (shift snap), B-006 (pet wander), B-007 (tutorial replay), B-008
(volume persist), B-009/B-010/B-011 (profile disconnect/signal/lambda),
B-012/B-013 (mess disconnect/timer), B-014, B-015 (migration backup),
B-018/B-019/B-020/B-025/B-026/B-027/B-028/B-031.

### 8.3 Still open (post-demo)

- B-004 P2 — grid investigation GUI
- B-016 P1 — dual-write JSON/SQLite completo (settings/music/rooms/placed_deco)
- B-021 P2 — Supabase rate-limit exp backoff (parziale)
- B-022 P3 — cloud_to_local dead code decision
- B-023 P3 — virtual_joystick USE/REMOVE
- B-024 P3 — CI linter `Button.new()` focus_mode check
- B-029 P1 — PBKDF2 10k→100k migration
- B-030 P3 — RNG determinism debug seed
- B-032 P1 — Supabase DDL in `supabase/migrations/`
- B-033 P3 — split `local_database.gd` 831 righe

---

## 9. Commit storico sprint 17 Apr (dal ultimo registry)

14 commit pushed su `main`:

```
a2e2f59 docs: Gamma update content (card-by-card text for manual Gamma edit)
848036c docs(speech): tighten + refresh numbers to current state
0cd159a docs: update guide + addons README with current state
7e6a4a6 docs: rewrite tests/data/scripts/scenes README
64c8938 docs(landing): update content + 3 contributor pages + Android download
ba307f0 build(android): add Android APK export preset + CI job
172860b docs: rewrite root + v1 README to reflect current state
dec9fee fix(ui): remove DropZone IGNORE swap — it was breaking drag-drop
7e05cce ui(game_hud): profile button uses character portrait, not 👤 emoji
36bd7fe assets: kenney furniture CC0 (57 new deco items) + Godot import metadata
8232743 fix(ui): toast container mouse_filter STOP→IGNORE + regression test
f373422 remove: female character + assets moved outside project
73060cf fix(drag-drop): DecoButton extends TextureRect, not Button
424ad0b chore(pixelart): commit external workflow assets + CI scripts
```

---

## 10. File letti integralmente (audit 17 Apr)

Deep read 17 Apr come follow-up 16 Apr:

| File esaminato | Note |
|----------------|------|
| `v1/scripts/ui/toast_manager.gd` | Trovato mouse_filter STOP blocker root cause |
| `v1/scripts/ui/deco_button.gd` | Riscritto extends TextureRect |
| `v1/scripts/ui/deco_panel.gd` | Adattato `btn.texture` (non icon) |
| `v1/scripts/main.gd` | Rimosso drop_zone swap logic |
| `v1/scripts/ui/game_hud.gd` | Profile button portrait |
| `docs/index.html` | Landing page content update |
| `docs/style.css` | Team button styles |
| Reference repos: `jlucaso1/drag-drop-inventory`, `jeroenheijmans/sample-godot-drag-drop-from-control-to-node2d`, `phanstudio/Desktop-Pet`, `ObsidianBlk/CozyWinterJam2023` | Conferma TextureRect pattern |

**Scoperta metodologica**: 112 test headless green = non sufficient.
`Viewport.push_input` in headless NON simula fedelmente il GUI mode per
CanvasLayer children. I bug UX reali richiedono GUI manual testing. Tests
servono a catturare **wiring bugs** (che le mie precedenti passing), non
**input-routing bugs** (che solo in GUI emergono).

---

## 11. Roadmap post-demo aggiornata

1. Supabase project setup + schema migrations versionate in `supabase/migrations/`
2. B-016 dual-write completo (`upsert_settings` + `upsert_music_state` + `upsert_room` attivi)
3. Mood visual effects (filter gloomy, rain particles, cat wild mode)
4. Badge system + catalog SQLite
5. i18n reale .po files + refactor `tr()` su 50+ stringhe
6. PBKDF2 10k → 100k migration on login
7. Split `local_database.gd` 831 righe per tabella
8. virtual_joystick USE/REMOVE decision (B-023)
9. Registra 63 kenney PNG rimanenti (bathroom + kitchen + wall/floor tiles)

---

## 12. Verifica finale demo-ready

```bash
./scripts/smoke_test.sh       # ✅ 0 parse 0 script errors
./scripts/preflight.sh        # ✅ GO, 0 failures 0 warnings, 111 test pass
./scripts/deep_test.sh        # ✅ 111 test in 8 moduli, ~7s
```

CI GitHub Actions su `main`: tutti i 10 job green (lint, 5 validator, pixel-art,
signal-count, smoke, deep-tests). Export Windows .exe + HTML5 + Android APK
generati automaticamente su push.

**User GUI test pending**: drag-drop decorazioni in room + click panel items
ora funzionano (toast fix + DecoButton TextureRect + DropZone PASS-always).
Se ancora issues → nuove task → iterazione.

---

*Generato 2026-04-17 post final-sprint autopilot session.*
*Scadenza demo: **22 Aprile 2026**.*
