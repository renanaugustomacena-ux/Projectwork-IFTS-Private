# Relax Room — Project Status

**Aggiornato**: 2026-04-21
**Owner**: Renan Augusto Macena
**Engine**: Godot 4.6.1 / GDScript, GL Compatibility, 1280×720
**Demo**: 2026-04-22

Storico consolidamento 7 doc + sprint 04-21. Questo file elenca SOLO task
ancora aperti + invarianti.

---

## 1. Bug chiusi nello sprint 04-21

| ID | Titolo | Fix approach |
|----|--------|--------------|
| B-004 | Grid quadrati giganti | `room_grid.gd` ora legge viewport dinamico + `size_changed` redraw |
| B-016 | JSON/SQLite divergence | Payload `save_to_database_requested` esteso con settings/music_state/room+decorations; `_on_save_requested` chiama tutti gli upsert in transaction atomica |
| B-021 | Rate limit no backoff | `supabase_client.gd` exponential backoff `min(2^attempts*1000, 300000)` ms con reset su 2xx |
| B-022 | cloud_to_local dead code | Rimossi 3 mapper inutilizzati da `supabase_mapper.gd` |
| B-023 | virtual_joystick dead | Mobile-gated in `main.gd`: istanziato solo se `OS.has_feature("mobile"/"web")` |
| B-024 | CI no focus_mode check | `ci/validate_button_focus.py` + CI job. Fix 13 Button.new() esistenti |
| B-029 | PBKDF2 10k iter | Nuovo format `v3:100000:salt:hash`, migration trasparente v1/v2→v3 al login |
| B-030 | RNG non deterministico | `Constants.DEBUG_RNG_SEED`; audio/mess/pet RNG seeded in debug build |

## 2. Feature T-R-015 completate nello sprint 04-21

- **c)** FileDialog immagine profilo → `user://profile_image.png` (privacy-first, mai cloud)
- **d)** Badge system: `badges.json` 6 badges, SQLite `badges_unlocked` table, `BadgeManager` autoload, UI badges row
- **g)** i18n reale: `it.po` + `en.po`, `TranslationServer.set_locale()` su language_changed, refactor core strings in `profile_hud_panel.gd`
- **i)** `MoodManager` autoload: overlay ColorRect gloomy, rain particle scene, pet WILD state, `AudioManager.crossfade_to_mood_track()` con volume scaling

Skeleton a/b/e/f/h erano già implementati nella baseline pre-sprint.

## 3. Task ancora aperti

### Bug
| ID | Sev | Area | Note |
|----|-----|------|------|
| B-032 | P1 | repo | Supabase DDL versioning. `supabase/README.md` stub creato. **BLOCCATO** in attesa `pg_dump --schema-only` dal dashboard user |
| B-033 | P3 | `local_database.gd` | Split 880+ righe in 7 repo modules. **Skipped per sprint demo** (refactor rischioso pre-release). Post-demo |

### Feature backlog
- **63 PNG Kenney** non registrati: `scripts/register_kenney_assets.py` genera suggerimenti JSON. User decide categorie (bathroom/kitchen/tiles nuove). Post-demo
- **i18n resto UI**: ~50 stringhe hardcoded in `settings_panel`, `main_menu`, `auth_screen`, `game_hud`, `tutorial_manager` ancora da wrappare in `tr()`. .po files pronte — drop-in refactor
- **Badge icon PNG custom**: oggi emoji unicode; sostituire con pixel art 24×24 in `v1/assets/badges/`
- **Storm audio track**: `AudioManager.crossfade_to_mood_track` modula solo volume; aggiungere `storm_ambient.ogg` per swap effettivo

### Post-demo roadmap ordinata
1. B-032: estrarre + versionare DDL Supabase (user blocker)
2. B-033: split `local_database.gd` in repo modules
3. i18n refactor completo 50+ stringhe restanti
4. Kenney asset registration 63 PNG con nuove categorie
5. Storm audio track + pixel art badge PNG
6. GUI playtest passes completo prima release (vedi §7 limite headless)

## 4. Invarianti di progetto (non negoziabili)

- **Signal-driven**: cross-module via `SignalBus` (48 segnali: +2 badge_unlocked, pet_wild_mode_requested). Chiamate dirette tra autoload bandite
- **Data-driven**: content in `v1/data/*.json` (129 deco + 6 badge + 1 room + 1 char + 2 tracks + 6 mess)
- **Texture filter NEAREST** esplicito su ogni sprite runtime
- **Offline-first**: Supabase graceful-degradable. Mai blocco UI su rete senza timeout+fallback
- **FPS dinamico**: 60 focused / 15 unfocused
- **Dual-save atomico**: JSON primary + SQLite mirror completo (post B-016). `save_version = 5.0.0`
- **Autoload chain (12)**: SignalBus → AppLogger → LocalDatabase → AuthManager → GameManager → SaveManager → SupabaseClient → AudioManager → PerformanceManager → StressManager → MoodManager → BadgeManager
- **Focus rule**: ogni `Button.new()` richiede `focus_mode` esplicito (CI enforced via `validate_button_focus.py`). Ogni `SignalBus.x.connect()` in nodo effimero → `disconnect()` simmetrico in `_exit_tree()` con `is_connected` guard. Zero lambda inline su SignalBus
- **PBKDF2 v3**: 100k iter SHA-256 (OWASP trade-off). Migration trasparente al login
- **Privacy**: profile image locale only, mai upload cloud
- **Git**: commit italiano, `--author="Renan Augusto Macena"`, zero riferimenti AI

## 5. Comandi operativi

```bash
./scripts/smoke_test.sh                     # parse + boot check
./scripts/preflight.sh                      # full gate
./scripts/deep_test.sh                      # integration tests
python3 ci/validate_button_focus.py v1/scripts    # Button focus_mode lint
python3 scripts/register_kenney_assets.py   # diff Kenney PNG vs catalog

gdlint v1/scripts/
gdformat --check v1/scripts/
godot4 --path v1/ --verbose 2>&1 | tee /tmp/playtest.log
```

**CI GitHub Actions**: 10+ job (lint + 6 validator + button-focus + pixel-art + signal-count + smoke + deep-tests). Export Windows .exe + HTML5 + Android APK automatici.

**Limite headless**: `Viewport.push_input` non instrada a Control in CanvasLayer. Test UI usano `button.pressed.emit()` per wiring check. Bug UX reali richiedono GUI manual test — **non fidarsi solo di smoke headless prima di release**.

## 6. User path file chiave

- `user://save_data.json` + `.backup.json` (HMAC-SHA256)
- `user://cozy_room.db` + `-wal` + `-shm` (SQLite WAL, 10 tabelle FK CASCADE + badges_unlocked)
- `user://config.cfg` (Supabase, opzionale)
- `user://supabase_session.cfg` (refresh_token — post-demo: cifrare)
- `user://profile_image.png` (T-R-015c, 128×128 PNG locale)
- `user://logs/session_*.jsonl` (AppLogger JSONL)

Path root per OS:
- Linux: `~/.local/share/godot/app_userdata/RelaxRoom/`
- Windows: `%APPDATA%\Godot\app_userdata\RelaxRoom\`
- macOS: `~/Library/Application Support/Godot/app_userdata/RelaxRoom/`

## 7. Note sprint 04-21

- **Git recovery**: `.git/index` + `refs/heads/main` corrotti su NTFS external drive. Working dir originaria `/media/renan/New Volume/PROIECT/projectwork/Projectwork` **abbandonata** — lavorare da `/tmp/Projectwork-IFTS/`. Rimote GitHub intatto
- **Smoke test**: boot headless clean (0 parse/script errors) post-sprint
- **Bug trovato+fixato in sprint**: `BadgeManager.storm_survivor` auto-unlock al boot — fix `_stormy_mood_reached` flag
- **Warnings residui headless**: `ObjectDB instances leaked at exit` + `1 resources still in use at exit`. Presenti anche pre-sprint, non blocker — cleanup di NOTIFICATION_WM_CLOSE_REQUEST su autoload da migliorare post-demo
- **GUI playtest ancora da fare**: headless conferma solo parse/wiring. Prima della demo 22 Apr testare GUI reale (F5 in editor): profile HUD open/close, mood slider gloomy/stormy visibili, rain particles, pet WILD movement, badge unlock toast, lang toggle IT↔EN
