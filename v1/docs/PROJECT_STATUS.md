# Relax Room — Project Status

**Aggiornato**: 2026-04-20
**Owner**: Renan Augusto Macena
**Engine**: Godot 4.6.1 / GDScript, GL Compatibility, 1280×720
**Demo**: 2026-04-22

Consolida 7 doc precedenti. Tutti i bug P0/P1 pre-demo risolti (22 originali + sprint 04-17). Questo file contiene SOLO task ancora aperti + invarianti chiave.

---

## 1. Bug ancora aperti (post 2026-04-17)

| ID | Sev | Area | Azione |
|----|-----|------|--------|
| B-004 | P2 | `room_grid.gd` | Grid quadrati giganti in edit mode — investigare viewport scaling / CELL_SIZE runtime |
| B-016 | P1 | `save_manager.gd` + `local_database.gd` | Dual-write completo JSON/SQLite: `upsert_settings`, `upsert_music_state`, `upsert_room`, `replace_placed_decorations` atomico in transaction |
| B-021 | P2 | `supabase_client.gd:254` | Exponential backoff su HTTP 429: `_backoff_until = now + min(2^attempts*1000, 300000)` |
| B-022 | P3 | `supabase_mapper.gd:103-136` | `cloud_to_local` dead code — decidere REMOVE o implementare pull sync al login |
| B-023 | P3 | `v1/addons/virtual_joystick/` + `v1/scenes/ui/virtual_joystick.tscn` | USE/REMOVE decision. Se mobile port rimandato → backup + `git rm` |
| B-024 | P3 | CI | Linter rule: `grep "Button.new()"` senza `focus_mode` → fail. Previene re-intro B-001/B-003 |
| B-029 | P1 sec | `auth_manager.gd` `_hash_password` | PBKDF2 10k → 100k iter + migration on-login con prefix v2→v3 (OWASP 2023 raccomanda ≥600k SHA-256) |
| B-030 | P3 | `pet_controller.gd:57`, `audio_manager.gd:56,136`, `mess_spawner.gd:24` | Debug build: `_rng.seed = Constants.DEBUG_RNG_SEED`. Release: `_rng.randomize()` |
| B-032 | P1 | repo | Estrarre DDL 15 tabelle Supabase → `supabase/migrations/0001_initial.sql`. Senza questo DB cloud non ricostruibile |
| B-033 | P3 | `local_database.gd` 831 righe | Split per tabella: connection+migration / CRUD accounts / CRUD characters / CRUD rooms+deco / sync_queue |

---

## 2. Feature T-R-015 — Profile + Mood Panel HUD (post-demo)

Mini pannello orizzontale top-right da icona profilo in game_hud. Immagine profilo (solo locale, mai cloud), badge, settings, language toggle IT/EN, mood bar slider con effetti visuali.

| # | Sub-task | Tempo | Note |
|---|----------|-------|------|
| a | Icona profilo in `game_hud.gd` + signal `SignalBus.profile_hud_requested` | 30m | — |
| b | Scene `v1/scenes/ui/profile_hud_panel.tscn` + script, PanelContainer top-right 420×120, lifecycle via PanelManager key "profile_hud" | 45m | — |
| c | Profile image da `FileDialog` native → save `user://profile_image.png`, TextureRect circolare. Tooltip privacy esplicito | 1h | **Mai cloud** |
| d | Badge system: catalog `v1/data/badges.json` + SQLite `badges_unlocked(account_id, badge_id, unlocked_at)` + mirror Supabase | 2h | Definire unlock conditions |
| e | Move settings button da HUD dentro ProfileHUDPanel | 15m | `PanelManager.open_panel("settings")` |
| f | Language toggle IT/EN con bandiere PNG 32×24 + signal `language_changed` | 30m | Senza i18n reale — solo toggle |
| g | i18n reale: `v1/locale/{it,en}.po` + refactor `tr("KEY")` su 50+ stringhe UI hardcoded | 3-4h | Dipende da f per trigger |
| h | Mood bar HSlider 0→1 + pallina custom + signal `mood_level_changed` + persist `mood_level` in settings | 30m | — |
| i | `MoodManager` autoload: overlay ColorRect gloomy, rain particle `rain.tscn` se <0.15, pet `WILD` FSM state se <0.10, audio crossfade storm track | 3-5h | Asset: `storm_ambient.ogg`, `rain_drop.png` (8×8) |

**Tempo totale**: scheletro minimo (a/b/e/f/h senza logica) ~2.5h. Completo con mood effects 10-14h + 3h asset custom.

**Additions necessarie**:
- `SignalBus`: `profile_hud_requested`, `profile_hud_closed`, `mood_level_changed(mood: float)`
- `Constants`: `MOOD_GLOOMY_THRESHOLD := 0.15`, `MOOD_STORMY_THRESHOLD := 0.10`, `MOOD_AUDIO_TRACK_STORM`
- Settings keys: `mood_level` (float, default 1.0), `profile_image_path` (String)
- **NO confondere** `StressManager` (gameplay interno) con `MoodManager` (utente volontario)

---

## 3. Roadmap post-demo ordinata

1. **Supabase**: project setup + schema migrations versionate (B-032)
2. **B-016** dual-write JSON/SQLite completo
3. **T-R-015i** mood visual effects (gloomy filter, rain, cat wild mode)
4. **T-R-015d** badge system + catalog SQLite
5. **T-R-015g** i18n reale `.po` files
6. **B-029** PBKDF2 migration on-login
7. **B-033** split `local_database.gd`
8. **B-023** virtual_joystick decision
9. **Kenney asset backlog**: 63 PNG bathroom/kitchen/wall-tiles/floor-tiles rimanenti in `v1/assets/sprites/kenney_furniture_cc0/` — richiedono nuove categorie in `decorations.json` (bathroom, kitchen) o cataloghi separati

---

## 4. Invarianti di progetto (non negoziabili)

- **Signal-driven**: cross-module via `SignalBus` autoload (46 segnali). Chiamate dirette tra autoload bandite
- **Data-driven**: content in `v1/data/*.json` (129 deco in 13 categorie, 1 room, 1 character, 2 tracks, 6 mess)
- **Texture filter NEAREST** esplicito su ogni sprite runtime-created
- **Offline-first**: Supabase graceful-degradable. Mai blocco UI su call rete senza timeout+fallback
- **FPS dinamico**: 60 focused / 15 unfocused (`performance_manager.gd`)
- **Dual-save**: JSON primary + SQLite mirror + Supabase opt-in. `save_version = 5.0.0`
- **Autoload chain** (10): SignalBus → AppLogger → LocalDatabase → AuthManager → GameManager → SaveManager → SupabaseClient → AudioManager → PerformanceManager → StressManager
- **Focus rule**: ogni `Button.new()` non keyboard-navigable → `focus_mode = Control.FOCUS_NONE` esplicito. Ogni `SignalBus.x.connect()` in nodo effimero → `disconnect()` simmetrico in `_exit_tree()` con `is_connected` guard. Zero lambda inline su SignalBus
- **Git**: commit italiano, `--author="Renan Augusto Macena <renanaugustomacena@gmail.com>"`, zero riferimenti AI/Claude/Anthropic

---

## 5. Comandi operativi

```bash
./scripts/smoke_test.sh     # parse + boot check, exit 0/1/2
./scripts/preflight.sh      # full gate: lint + validators + smoke + tests
./scripts/deep_test.sh      # 111 test in 8 moduli (~7s)

gdlint v1/scripts/
gdformat --check v1/scripts/
godot4 --path v1/ --verbose 2>&1 | tee /tmp/playtest.log
```

**CI GitHub Actions**: 10 job (lint + 5 validator + pixel-art + signal-count + smoke + deep-tests). Export Windows .exe + HTML5 + Android APK automatici su push `main`.

**Limite headless noto**: `Viewport.push_input` non instrada affidabilmente a Control in CanvasLayer. Test UI usano `button.pressed.emit()` per verificare wiring, non input routing. Bug UX reali richiedono GUI manual test.

---

## 6. User path file chiave

- `user://save_data.json` + `.backup.json` (primary, HMAC-SHA256)
- `user://cozy_room.db` + `-wal` + `-shm` (SQLite WAL, 9 tabelle FK CASCADE)
- `user://config.cfg` (Supabase url + anon_key, opzionale)
- `user://supabase_session.cfg` (refresh_token — **B-019 post-demo: cifrare**)
- `user://logs/session_*.jsonl` (AppLogger, grep `"level":"ERROR|WARN"`)

Path root per OS:
- Linux: `~/.local/share/godot/app_userdata/Relax Room/`
- Windows: `%APPDATA%\Godot\app_userdata\Relax Room\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Relax Room/`
