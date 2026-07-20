# MASTER COMPLETION PLAN — Relax Room v1.1.0
**Date**: 2026-07-20
**Author**: Renan Augusto Macena
**Baseline commit**: `ac9d49f` (branch `main`)
**Target**: /data/Projectwork — Godot 4.6, GDScript, GL Compatibility, 1280×720 pixel art
**Goal**: bring the project from shipped-demo state (v1.0.0, 2026-04-22) to **total completion**: every audit finding remediated or formally accepted, every broken logic fixed, every missing feature implemented, every missing asset created, full test suite green, CI green, clean git tree, release-ready v1.1.0.

---

# PART I — SITUATION, STRATEGY, EXECUTION MODEL

## 1. Where the project stands (verified 2026-07-20)

### 1.1 What works
- Headless boot: clean (0 parse errors, 0 script errors) on all four probed scenes (main_menu, main, auth_screen, character_select).
- Test harness: 111 tests, 108 pass. Custom reflection-based headless runner.
- All 10 CI Python validators pass locally; gdlint clean; version sync (v1/VERSION ↔ export_presets ↔ project.godot) verified.
- Decoration system: 129/129 catalog sprites exist, place/rotate/flip/scale/delete verified end-to-end, persistence roundtrip works.
- Core loops: mess spawn/clean with coins, stress hysteresis, pet FSM, save/load with HMAC, auth guest+registered, SQLite mirror, tutorial 8 steps completable.
- Landing page: mostly remediated post-audit (Lucide pinned on index, images self-hosted on index).

### 1.2 What is broken (functional defects a player can hit)
1. **Panel toggle regression** — commit `58a61b5` deferred `panel_closed` + state clearing to the end of a 0.3 s fade tween (`v1/scripts/ui/panel_manager.gd:109-115`). Toggle-close semantics broke: 3 tests fail, `panel_closed` listeners fire late, second HUD press during fade is swallowed.
2. **Cloud sync permanently wedges** — `_pending_requests` is keyed with `sync_*` rids but the wire layer generates its own `upsert_*`/`delete_*` rids; responses can never clear pending entries → `_is_syncing` stuck true forever after first push (`supabase_client.gd:501` + call sites). Worse than the 2026-04-23 audit understood.
3. **Mood slider never changes the music** — the mood-driven track swap is a structural no-op due to a self-emit guard (`audio_manager.gd:402`), and mood `stormy` has **zero** matching tracks in `tracks.json` → storm music can never play even if the swap worked.
4. **Language switch does nothing** — `language_changed` has zero subscribers, no key-based auto-translate in any scene, saved language never applied at boot (`settings_panel.gd:167`, `save_manager.gd:45`). 27 of 34 .po keys are dead.
5. **virtual_joystick.tscn references two nonexistent textures** (dead uids) — mobile/web joystick silently fails to render.
6. **Save integrity failure paths are invisible** — `save_completed` fires even on total write failure; HMAC mismatch lands the player on defaults with no notification; integrity-key persist failure orphans every save on next boot.

### 1.3 What is missing (content/features)
- Mess visuals: all 6 `mess_catalog.json` entries have empty `sprite_path` → runtime placeholder circles.
- Ambience subsystem: zero assets, empty catalog array, no UI trigger; `MOOD_AUDIO_TRACK_STORM` constant points at a nonexistent file.
- Storm/tense music track for mood `stormy`/`tense` coverage.
- Character roster: 1 of 3–4 documented; `character_select.gd` functional but unreachable dead code with a 1-entry catalog; `characters.json` ~95 % dead data.
- Badge icons are emoji strings (font-dependent rendering); night_owl badge only unlocks if an unrelated event fires; cumulative badge counters are session-proxied, not lifetime.
- Project icon is the stock Godot robot; Android launcher icons unset.
- No in-game credits/attribution despite Eder Muniz forest pack requiring credit.
- Error-signal vocabulary: 48 SignalBus signals, only `auth_error` carries failures. No `save_failed`, `sync_error`, `db_error`, `catalog_load_failed` — architecturally open-loop failure propagation.
- Cloud pull sync absent (push-only) while README claims cross-device.

### 1.4 Uncommitted working-tree state (triaged)
| Path | Verdict | Rationale |
|---|---|---|
| `v1/scenes/main/main.tscn` | **REVERT** | Accidental editor drags: FloorBounds got position (257.2, −714.4) + scale (0.878, 2.270) + rewritten polygon → floor collision and room alignment broken. `unique_id` churn is harmless but rides the same file. |
| `v1/project.godot` | **KEEP** | Pure Godot 4.6 resave normalization (section reorder, dropped default `per_pixel_transparency`). |
| `v1/assets/ui/cozy_theme.tres` | **KEEP** | Resave restructure; no stylebox lost; only comments gone. |
| `v1/addons/godot-sqlite/bin/*` "modified" | **GIT-ATTR FIX** | Files on disk are the real 4 MB binaries; `.gitattributes` declares `*.so/dll/wasm/a` as LFS but HEAD holds normal blobs → permanent phantom diff. Remove the LFS filter lines (repo has no LFS objects; binaries ≤ 4 MB are fine as normal blobs). |
| `_render/`, `_render_orig/`, `finale.original.pptx` | **IGNORE/CLEAN** | Deck-render leftovers, not game content. Add to `.gitignore` or delete. |

### 1.5 Register scale
- **PART II**: 127 re-verified audit findings — 110 actionable (5 CRITICAL, 42 HIGH, 44 MEDIUM, 13 LOW, 6 INFO), 17 closed/accepted kept for traceability. Every entry: current line anchor, current-code evidence, concrete remediation, acceptance criterion.
- **PART III**: 70 fresh gaps from the 2026-07-20 eight-dimension hunt (tests, assets, i18n, scenes, features, CI/export, catalogs, runtime).
- **PART IV**: phase playbooks (C→J) with ordered work items, design decisions, and file-level blueprints.
- **PART V**: asset production specifications (pixel-art recipes, palette, audio synthesis).
- **PART VI**: i18n completion plan (key map, wiring architecture).
- **PART VII**: verification matrix + release checklist + commit plan.

## 2. Execution model

Phases execute strictly in order; each ends with the full test suite + lint + validators green before the next begins. Fixes land as small thematic commits (conventional format, author Renan Augusto Macena, no co-author trailers).

| Phase | Theme | Primary content |
|---|---|---|
| C | Data-integrity criticals + error-signal vocabulary | 5 CRITICALs; new SignalBus failure signals wired to ToastManager; save/DB atomicity |
| D | HIGH defects | Sync engine repair, panel toggle, audio mood swap, logger, auth rate-limit persistence, HTTP pool leak, tutorial signal hygiene, room/pet bounds |
| E | MEDIUM + LOW defects | Coercions, defaults unification, backup ring, orphan-temp recovery, username charset, log retention, misc |
| F | Features + i18n + catalog hygiene | Full i18n wiring (IT/EN), badge logic completion, character roster + reachable character_select, catalog cleanups, credits screen, cloud-claim honesty |
| G | Asset production | 6 mess sprites, joystick textures, storm+ambience audio, badge icons, project icon, second character sheet (palette-swap), placeholder purge |
| H | Test repair + new regression tests | 3 failing tests + coverage for every C/D fix touching testable logic |
| I | Full verification | gdlint, gdformat, 10 validators, smoke, deep tests, preflight GO |
| J | Git hygiene + release prep | main.tscn revert, LFS attr fix, .gitignore, chmod scripts, version bump v1.1.0, CHANGELOG, structured commits |

## 3. Non-negotiable constraints

1. Godot **4.6** — no engine downgrade/upgrade.
2. Floor polygon is the clamping source of truth; never reintroduce viewport-rect clamping.
3. `user://integrity.key` path immutable.
4. Every SignalBus listener disconnects in `_exit_tree()`.
5. Buttons created via script get `focus_mode = FOCUS_NONE` unless keyboard nav needed (CI guard).
6. Drag sources stay non-Button (`DecoButton extends TextureRect`).
7. gdtoolkit v4 style: max-line 120, max-function 50, max-file 500 (B-033 files keep their existing waiver).
8. Code identifiers/comments English; user-facing docs Italian; commits conventional; author fixed.
9. No new third-party dependencies without license + maintenance review; prefer stdlib/engine primitives (real PBKDF2 via `Crypto.hmac_digest`, not a GDExtension).
10. Asset licenses respected: SoppyCraft/Thurraya/Eder Muniz packs — no redistribution outside the game, credit Eder Muniz in-game; new art follows `assets/palette/palette_projectwork.gpl`.

---

# PART II — VERIFIED FINDINGS REGISTER (from AUDIT_REPORT_2026-04-23, re-verified 2026-07-20)

Actionable (OPEN+PARTIAL): CRITICAL 5 · HIGH 42 · MEDIUM 44 · LOW 13 · INFO 6. Total register entries: 127 (incl. FIXED/ACCEPTED/DEFERRED/OBSOLETE for traceability).

### V-001 [CRITICAL] [OPEN] Custom iterated-SHA256 still labeled/advertised as PBKDF2

- **Audit ref**: 4.4.1
- **Location**: `v1/scripts/autoload/auth_manager.gd:198`
- **Execution phase**: C
- **Current evidence**: Lines 198-209 identical to audit: `_hash_with_salt_iter` comment at 203 says "PBKDF2-style iterated SHA-256"; body is `result = _sha256(result + data)` chain over `(salt_hex + password)` — no HMAC, no XOR accumulator, not RFC 2898. CHANGELOG.md:34 (`**PBKDF2 v3** password hashing 100k iter SHA-256`), :62, :67 still advertise PBKDF2. Only remediation since audit: v1/README.md:68 added a disclosure note admitting the label is inaccurate — code, helper name, code comment, and CHANGELOG untouched.
- **Remediation**: Godot 4 exposes `Crypto.hmac_digest(HashingContext.HASH_SHA256, key, msg)` — implement real RFC 8018 PBKDF2-HMAC-SHA256 (U_1=HMAC(pw, salt||INT(1)); U_i=HMAC(pw,U_{i-1}); T=XOR U_i) in a new `_pbkdf2_hmac_sha256()`. Emit `v4:pbkdf2:iter:salt:hash` from _hash_password (line 188) and add a `begins_with("v4:")` branch in login(); reuse the existing needs_upgrade flow (lines 115-123) to migrate v3→v4 on successful login. Rename `_hash_with_salt_iter` to `_salted_sha256_loop` (kept only for v2/v3 verify) and correct CHANGELOG.md:34/62/67 plus the comment at line 203 before v1.1.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-002 [CRITICAL] [OPEN] save_inventory DELETE+INSERT loop has no own transactional guarantee

- **Audit ref**: 4.1.16-L58
- **Location**: `v1/scripts/autoload/database/inventory_repo.gd:58`
- **Execution phase**: C
- **Current evidence**: L58: `if not DBHelpers.execute_bound(db, "DELETE FROM inventario WHERE account_id = ?;", [account_id]): return false` then L60-70 INSERT loop with early `return false` on failure — no SAVEPOINT; when called outside _on_save_requested's outer BEGIN (whose own return is unchecked, local_database.gd:113), a mid-loop failure leaves the inventory deleted with only partial re-inserts committed in autocommit mode.
- **Remediation**: Wrap the DELETE+INSERT body in `SAVEPOINT save_inv;` / `RELEASE save_inv;` with `ROLLBACK TO save_inv;` on any failure (SAVEPOINTs nest safely inside the outer BEGIN). Check each execute return as now, but roll back to the savepoint before returning false.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-003 [CRITICAL] [OPEN] Migration 1 DROPs source tables without transaction or verified backup

- **Audit ref**: 4.1.11-L195
- **Location**: `v1/scripts/autoload/database/schema.gd:197`
- **Execution phase**: C
- **Current evidence**: L195-204: `DBHelpers.execute(db, "DROP TABLE IF EXISTS characters_bak;")` ... `DBHelpers.execute(db, "CREATE TABLE characters_bak AS SELECT * FROM characters;")` (return unchecked) ... backup count is only logged at L199-201 (`AppLogger.info(..., {"characters_backed_up": bak_cnt})`), never compared to source count and never gates L202-203 `DROP TABLE IF EXISTS characters; DROP TABLE IF EXISTS inventario;`. If the CREATE ... AS SELECT fails, both DROPs still execute and user data is destroyed. No BEGIN/COMMIT around the sequence.
- **Remediation**: Wrap L195-204 in a checked BEGIN/COMMIT (returns verified). Capture ok of each CREATE ...AS SELECT; count source rows BEFORE backup, compare with bak_cnt at L200, and abort (ROLLBACK + AppLogger.error) if unequal or any execute returned false, leaving the DROPs unexecuted.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-004 [CRITICAL] [OPEN] BEGIN/COMMIT/ROLLBACK return values unchecked in _on_save_requested

- **Audit ref**: 4.1.4-L113
- **Location**: `v1/scripts/autoload/local_database.gd:113`
- **Execution phase**: C
- **Current evidence**: L113: `DBHelpers.execute(_db, "BEGIN TRANSACTION;")` — return discarded. L137: `DBHelpers.execute(_db, "COMMIT;")` — return discarded. L139: `DBHelpers.execute(_db, "ROLLBACK;")` — return discarded. No failure signal emitted; SignalBus only declares `save_completed` (signal_bus.gd:37), no save_failed exists. If BEGIN fails, upserts run in autocommit and partial writes are reported as implicit success.
- **Remediation**: Capture `var began := DBHelpers.execute(_db, "BEGIN TRANSACTION;")`; if false, log error and return early. Capture COMMIT return at L137; on false, execute ROLLBACK, log via AppLogger.error, and emit a new `SignalBus.save_failed` signal (add to signal_bus.gd next to save_completed at line 37) so SaveManager/UI can react.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-005 [CRITICAL] [OPEN] save_completed emits unconditionally even if rename AND copy fallback both fail

- **Audit ref**: 4.1.2-L169
- **Location**: `v1/scripts/autoload/save_manager.gd:180`
- **Execution phase**: C
- **Current evidence**: L172-174: `if rename_err != OK:` -> `AppLogger.error(...)` -> `DirAccess.copy_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))` — copy return value discarded. Execution falls through to L179 `_is_saving = false` and L180 `SignalBus.save_completed.emit()` on every path past the temp-write. Grep confirms SignalBus has no save_failed signal.
- **Remediation**: Capture `var copy_err := DirAccess.copy_absolute(...)` at L174; if rename_err != OK and copy_err != OK, log error, add a `save_failed(err)` signal to signal_bus.gd and emit it instead of save_completed at L180. Keep `_is_saving = true` until the write is verified on disk.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-006 [HIGH] [PARTIAL] emergentagent.com CDN images: <img> self-hosted, 3 CSS backgrounds still remote

- **Audit ref**: 4.11.4b
- **Location**: `docs/style.css:352`
- **Execution phase**: D
- **Current evidence**: <img> layer remediated: docs/index.html:125 `<img src="assets/hero.png" ...>` and :181 `assets/mascot.png`, plus footer mascots :380-381; files exist in docs/assets/ (hero.png 1.2MB, mascot.png 1.0MB, cat.png, character.png). BUT docs/style.css still loads three third-party backgrounds actively used by index.html (.hero-bg used at index.html:93, .features-bg at :193, .download-bg at :328): style.css:352 `.hero-bg { background-image: url('https://static.prod-images.emergentagent.com/jobs/65fd861e-.../c2bce342...png')`, style.css:732 `.features-bg { background-image: url('https://static.prod-images.emergentagent.com/...4ea9dc3e...png')`, style.css:980 `.download-bg` same 4ea9dc3e URL. If that ephemeral jobs/ path 404s, hero/features/download section backgrounds vanish.
- **Remediation**: Download the two remaining PNGs (c2bce342..., 4ea9dc3e...) into docs/assets/ (e.g. hero-bg.png, section-bg.png) and rewrite style.css:352/732/980 to `url('assets/hero-bg.png')` / `url('assets/section-bg.png')`. Then repo-wide grep for emergentagent to confirm zero refs remain (also check docs/team/team.css and docs/css/style.css).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-007 [HIGH] [PARTIAL] Lucide @latest: fixed on index.html, still shipped on 3 team subpages

- **Audit ref**: 4.11.4a
- **Location**: `docs/team/renan.html:13`
- **Execution phase**: D
- **Current evidence**: Main page remediated: docs/index.html:15 now `<script src="https://unpkg.com/lucide@0.453.0/dist/umd/lucide.min.js" crossorigin="anonymous"></script>` (concrete version, min build). But all three team subpages still ship the unpinned tag: docs/team/renan.html:13, docs/team/cristian.html:13, docs/team/elia.html:13 each contain `<script src="https://unpkg.com/lucide@latest"></script>` — any upstream Lucide release instantly changes (or breaks) those live pages.
- **Remediation**: In renan.html, cristian.html, elia.html replace line 13 with the same pinned URL used by index.html: `https://unpkg.com/lucide@0.453.0/dist/umd/lucide.min.js` (+ SRI per 4.11.4c). Keep the version in one place mentally — all four pages should reference the identical pinned build.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-008 [HIGH] [PARTIAL] Supabase cloud schema still not reproducible from repo (stub README only)

- **Audit ref**: 4.7.3
- **Location**: `supabase/README.md:3`
- **Execution phase**: D
- **Current evidence**: supabase/ now exists (created 2026-04-23, same day as audit) but contains ONLY README.md: '> **Stato**: stub. Awaiting user-provided `pg_dump --schema-only` dal Supabase dashboard (15 tabelle cloud).' It documents the dump procedure, connection info, and the 15 expected tables, but no migrations/ dir, no 0001_initial.sql, no RLS policies are committed.
- **Remediation**: Execute the README's own Option A: `supabase db dump --schema-only > supabase/migrations/0001_initial.sql`, include RLS policies, commit, then extend ci/validate_db_schema.py per the README's CI-validation section. Until the dump lands, the ops risk in the original finding stands.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-009 [HIGH] [OPEN] No save-failed user journey: zero translation keys or toast paths for save failures

- **Audit ref**: 4.3-save-failed-ux
- **Location**: `v1/locale/en.po:58`
- **Execution phase**: D
- **Current evidence**: grep for save_failed/SAVE_FAILED/"errore salvataggio"/"salva fallit"/"save failed" across v1/locale/ and v1/scripts/ returns only the unrelated profile-image toast (profile_hud_panel.gd:214) and the audit note in scripts/README.md:105. The only SAVE-adjacent locale key is `msgid "TOAST_IMAGE_SAVED"` (en.po:58). Game-save failure still has no user-visible channel; save_completed remains the sole outcome signal (signal_bus.gd:37).
- **Remediation**: Add msgids SAVE_FAILED, SAVE_INTEGRITY_VIOLATION, CLOUD_SYNC_ERROR to both v1/locale/it.po and en.po; emit the new SignalBus.save_failed from SaveManager's write-failure branches and connect it to `SignalBus.toast_requested.emit(tr("SAVE_FAILED"), "error")` in the toast wiring.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-010 [HIGH] [OPEN] Tracks catalog ingested unvalidated; malformed entries detected only in hot-path play()

- **Audit ref**: 4.1.5-L96
- **Location**: `v1/scripts/autoload/audio_manager.gd:96`
- **Execution phase**: D
- **Current evidence**: _load_tracks() (L64-66) still assigns raw catalog: `if GameManager.tracks_catalog.has("tracks"):\n  tracks = GameManager.tracks_catalog["tracks"]` with no schema validation. Detection stays in play() L96-104: `var raw = tracks[current_track_index]` / `if raw is not Dictionary:` push_error+return, then empty-path push_warning+return. _on_mood_changed (L208-216) duplicates the same per-use `is Dictionary` defensive checks, confirming the load-time gap was never closed.
- **Remediation**: In _load_tracks() (L64-66) build a filtered array: keep only entries where `entry is Dictionary and not String(entry.get("path", "")).is_empty()`; push_warning with the rejected index/content for each drop. Keep the L96-104 checks as defense-in-depth. This also lets _on_mood_changed drop its duplicated type checks.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-011 [HIGH] [OPEN] Shuffle next_track uses bare randi() instead of seeded _mood_rng

- **Audit ref**: 4.1.5-L137
- **Location**: `v1/scripts/autoload/audio_manager.gd:139`
- **Execution phase**: D
- **Current evidence**: Lines 136-140 unchanged: `"shuffle":\n  var new_index := current_track_index\n  while new_index == current_track_index and tracks.size() > 1:\n    new_index = randi() % tracks.size()`. Meanwhile _ready() (L56-57) seeds `_mood_rng.seed = Constants.DEBUG_RNG_SEED` in debug builds, and _on_mood_changed (L231) correctly uses `_mood_rng.randi_range(...)`. Shuffle remains the sole non-deterministic RNG consumer.
- **Remediation**: Replace L139 with `new_index = _mood_rng.randi_range(0, tracks.size() - 1)` to match the style already used at L231 (or `_mood_rng.randi() % tracks.size()` for minimal diff).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-012 [HIGH] [OPEN] Rate-limit state in-memory only — reset by process restart

- **Audit ref**: 4.4.2
- **Location**: `v1/scripts/autoload/auth_manager.gd:23`
- **Execution phase**: D
- **Current evidence**: Lines 23-24: `var _failed_attempts: int = 0` / `var _lockout_until: float = 0.0` — plain instance vars on the autoload. Check at 72-78, increment at 130-134. No DB persistence anywhere (grep confirms no accounts-table column or rate_limit table write). Constants.AUTH_MAX_FAILED_ATTEMPTS=5, AUTH_LOCKOUT_SECONDS=300. Quit+relaunch still resets to 0; also the counter is global, not per-username.
- **Remediation**: Add `failed_attempts INTEGER DEFAULT 0` and `lockout_until REAL DEFAULT 0` columns to accounts (schema migration in database/schema.gd), plus AccountsRepo getters/setters. In login(): load per-username row before the check at line 73; increment via DB in _record_failed_attempt(); reset in DB at line 125 on success. Also rate-limit the unknown-username path (line 82) with a keyed-by-name row or a global fallback row so enumeration attempts are throttled too.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-013 [HIGH] [OPEN] upsert_account UPDATE return discarded; stale account_id returned on failure

- **Audit ref**: 4.1.13-L28
- **Location**: `v1/scripts/autoload/database/accounts_repo.gd:28`
- **Execution phase**: D
- **Current evidence**: L28-36: `DBHelpers.execute_bound(db, "UPDATE accounts SET mail = ?, data_di_nascita = ? WHERE auth_uid = ?;", [...])` — result not captured; function unconditionally falls through to `return existing.get("account_id", -1)` so callers cannot distinguish updated from failed.
- **Remediation**: Capture `var ok := DBHelpers.execute_bound(...)`; `if not ok: return -1` before returning existing account_id. Callers (local_database.gd:108 fallback path) already treat `account_id < 0` as abort.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-014 [HIGH] [OPEN] create_account INSERT unchecked; last_insert_rowid() stale on UNIQUE violation

- **Audit ref**: 4.1.13-L66
- **Location**: `v1/scripts/autoload/database/accounts_repo.gd:68`
- **Execution phase**: D
- **Current evidence**: L66-79: INSERT `"INSERT INTO accounts (auth_uid, display_name, password_hash) VALUES (?, ?, ?);"` return discarded, then `var rows := DBHelpers.select(db, "SELECT last_insert_rowid() as id;", [])` — on a UNIQUE violation of `auth_uid` (schema.gd:16 `auth_uid TEXT UNIQUE`) the INSERT fails silently and last_insert_rowid() returns the id of a previous insert in the session, so duplicate registration appears to succeed pointing at the wrong account.
- **Remediation**: Capture `var ok := DBHelpers.execute_bound(...)`; `if not ok: return -1` before the last_insert_rowid select. Optionally pre-check `get_account_by_username(db, username)` and return a distinct error for the conflict.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-015 [HIGH] [OPEN] select() failure dumps raw bindings array (password_hash, auth_uid, mail) into logs

- **Audit ref**: 4.1.12-L44
- **Location**: `v1/scripts/autoload/database/db_helpers.gd:44`
- **Execution phase**: D
- **Current evidence**: L38-47: on `query_with_bindings` failure, `AppLogger.error("LocalDatabase", "select_bound_failed", {"sql": sql.left(80), "bindings": bindings})` — L44 still logs the full positional array. Logger's `_redact_context` (logger.gd:82-98) redacts by key name and recurses only into Dictionary values (L94-95); the Array value falls through `out[k] = value` (L97), and "bindings" is not in REDACT_KEYS anyway.
- **Remediation**: Replace L44 context with `{"sql": sql.left(80), "bindings_count": bindings.size(), "binding_types": bindings.map(func(b): return type_string(typeof(b)))}`. Never log raw values. (execute_bound at L24 already omits bindings — mirror that discipline.)
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-016 [HIGH] [OPEN] Raw bindings array dumped to log on bound-select failure

- **Audit ref**: 4.4.8-L44
- **Location**: `v1/scripts/autoload/database/db_helpers.gd:44`
- **Execution phase**: D
- **Current evidence**: Lines 38-46 in DBHelpers.select: on query_with_bindings failure, `AppLogger.error("LocalDatabase", "select_bound_failed", {"sql": sql.left(80), "bindings": bindings})` — line 44 logs the raw array, bypassing the logger's keyed-dict redaction. Nuance vs audit wording: current select callers (accounts_repo.gd:12,19,46,52-58) bind account_id/auth_uid/username — password_hash and mail flow only through execute_bound (lines 19-26), which does NOT log bindings. So usernames/auth_uids (PII) still land in plaintext JSONL under user://logs/, but password hashes do not on the current call graph. Sweep positives from 4.4.8 still hold: ci/validate_no_keystore.py exists; .gitignore:48-59 covers .env, *.cfg.local, *.keystore, keystore-credentials.*.
- **Remediation**: Replace `"bindings": bindings` at line 44 with `"bindings_count": bindings.size()` (optionally plus per-element type names). Keeps the finding closed even if a future select binds secrets. Also consider adding `db.error_message` here per audit 4.1.12-L13.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-017 [HIGH] [OPEN] Migration-applied check uses substring match on raw DDL

- **Audit ref**: 4.1.11-L188
- **Location**: `v1/scripts/autoload/database/schema.gd:188`
- **Execution phase**: D
- **Current evidence**: L187-189: `var schema: String = rows[0].get("sql", "")\nif "character_id" in schema:\n\treturn` — bare substring on the CREATE TABLE text from sqlite_master; any future column or comment containing 'character_id' (e.g. foo_character_id) short-circuits the migration.
- **Remediation**: Replace with `var cols := DBHelpers.select(db, "PRAGMA table_info('characters');", [])` and check `cols.any(func(c): return c.get("name", "") == "character_id")` for an exact column-name match.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-018 [HIGH] [OPEN] sync_queue: unbounded payload, retry_count never incremented, no ORDER BY tiebreaker

- **Audit ref**: 4.1.19-L10
- **Location**: `v1/scripts/autoload/database/sync_queue_repo.gd:10`
- **Execution phase**: D
- **Current evidence**: L10-18 enqueue_sync: `JSON.stringify(payload)` inserted with no size cap. L22: `ORDER BY created_at ASC` — second-resolution timestamp, no queue_id tiebreaker. retry_count (schema.gd:80) is READ at supabase_client.gd:426-429 (`var retry: int = item.get("retry_count", 0); if retry > Constants.SUPABASE_MAX_RETRY: clear`) but grep shows NO code ever increments it — the value is permanently 0, so the max-retry drop is dead logic and there is still no back-off/retry semantics.
- **Remediation**: In enqueue_sync, reject payloads where `JSON.stringify(payload).length() > 65536` with AppLogger.warn. Add `static func increment_retry(db, queue_id) -> bool` executing `UPDATE sync_queue SET retry_count = retry_count + 1 WHERE queue_id = ?;` and call it from supabase_client.gd's failure path so the existing L427 guard becomes live. Change L22 to `ORDER BY created_at ASC, queue_id ASC`. Note: the audit's 'never read anywhere' claim is now half-true — it is read but never written.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-019 [HIGH] [OPEN] Catalog JSON loader returns {} on every failure mode; game proceeds silently empty

- **Audit ref**: 4.2-gamemanager-catalog
- **Location**: `v1/scripts/autoload/game_manager.gd:70`
- **Execution phase**: D
- **Current evidence**: Current `_load_json` (L70-93; report called it `_load_catalog` at L75-93, same function — file unchanged since pre-audit commit e444034) returns `{}` for all four failure modes: file-not-found (L71-73, push_warning), open-failure (L75-77, push_error), parse-error (L81-88, push_error), wrong-root-type (L90-93, push_error). Callers in `_load_catalogs` (L44-50) cannot distinguish missing/corrupt/legitimately-empty. `_validate_catalogs` (L53-67) existed at audit time and only push_warns for empty rooms/decorations — characters, tracks, mess, badges get no warning, and nothing is user-facing. SignalBus has no `catalog_load_failed` signal (grep confirms).
- **Remediation**: Change `_load_json` to return `Variant` with `null` on each error path (keep `{}` only for a genuinely empty Dictionary); in `_load_catalogs` treat `null` as fatal: add `signal catalog_load_failed(path: String, reason: String)` to SignalBus, emit it, and have main scene show a blocking error dialog. Extend `_validate_catalogs` to warn on all six counts, not just rooms/decorations.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-020 [HIGH] [OPEN] LocalDatabase/DBHelpers errors never signalled to higher layers

- **Audit ref**: 4.3-db-error-propagation
- **Location**: `v1/scripts/autoload/local_database.gd:42`
- **Execution phase**: D
- **Current evidence**: local_database.gd's only SignalBus interaction is inbound: L42 `SignalBus.save_to_database_requested.connect(_on_save_requested)` (plus the L46-47 disconnect). No outward emit of any error signal exists in the file, `db_error` does not exist on the bus, and wrapper methods still return defaults ({} / false) on failure, so SaveManager's save_completed masks SQLite-half failures.
- **Remediation**: After adding `signal db_error(context: String, reason: String)` to signal_bus.gd, emit it from every DBHelpers.execute error branch (pass calling context) and from LocalDatabase wrappers when a query returns failure; subscribe in main.gd to surface a toast and let SaveManager suppress save_completed when the DB write half failed.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-021 [HIGH] [OPEN] Unconditional guest-account fallback when auth_uid row missing

- **Audit ref**: 4.1.4-L108
- **Location**: `v1/scripts/autoload/local_database.gd:108`
- **Execution phase**: D
- **Current evidence**: L107-108: `if account.is_empty():\n\taccount_id = AccountsRepo.upsert_account(_db, auth_uid, Constants.AUTH_GUEST_EMAIL, "")` — any auth_uid not yet persisted (first-login race) gets a row created with guest email `offline@local` (constants.gd:43) and empty birthdate; game state lands on that improvised row, diverging from the account AuthManager later creates/uses.
- **Remediation**: Before the fallback upsert, branch: if `auth_uid != Constants.AUTH_GUEST_UID` (i.e. a real authenticated uid with no row yet), log an error and abort the save (or route through AuthManager to create the canonical account row) instead of upserting with AUTH_GUEST_EMAIL. Only fall through to the guest upsert when auth_uid == "local".
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-022 [HIGH] [OPEN] Redaction filter skips Arrays — positional values bypass REDACT_KEYS entirely

- **Audit ref**: 4.9.3-HIGH
- **Location**: `v1/scripts/autoload/logger.gd:97`
- **Execution phase**: D
- **Current evidence**: `_redact_context` (L82-98) branches: sensitive key -> REDACTED (L92-93), `elif value is Dictionary: out[k] = _redact_context(value)` (L94-95), `else: out[k] = value` (L97). Arrays (and dicts nested inside arrays) pass through verbatim — this is the mechanism behind the 4.1.12-L44 bindings leak. REDACT_KEYS (L16-18) is key-based only.
- **Remediation**: Add an `elif value is Array:` branch that maps elements: recurse `_redact_context` for Dictionary elements, recurse the array handler for nested Arrays, pass scalars through. Combine with the db_helpers.gd:44 call-site fix (stop logging raw bindings) for defense in depth.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-023 [HIGH] [OPEN] Buffer cap hit drops oldest entries silently — no warning, no dropped_count

- **Audit ref**: 4.1.3-L133
- **Location**: `v1/scripts/autoload/logger.gd:133`
- **Execution phase**: D
- **Current evidence**: L133-135: `if _log_buffer.size() >= MAX_BUFFER_ENTRIES:\n\t_log_buffer.pop_front()\n_log_buffer.append(json_line)`. No counter, no push_warning on steady-state drops. The only `push_warning` (L166-168) fires solely on the flush-failure retain-100 path (L160-168), exactly as the audit described.
- **Remediation**: Add `var _dropped_count := 0`; increment it in the L133 branch and emit one rate-limited `push_warning` on the first drop. In `_flush_buffer()` after a successful flush, if `_dropped_count > 0` store a synthetic WARN JSONL line `{"message":"entries_dropped","context":{"dropped":N}}` and reset the counter.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-024 [HIGH] [OPEN] Log file opened with FileAccess.WRITE truncates prior content on same-second re-open

- **Audit ref**: 4.1.3-L253
- **Location**: `v1/scripts/autoload/logger.gd:253`
- **Execution phase**: D
- **Current evidence**: L253: `_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)`. `_open_log_file()` is still re-invoked from `_flush_buffer()` (L158) and `_check_rotation()` (L187); filename is second-resolution (`session_%04d%02d%02d_%02d%02d%02d.jsonl`, L240-251), so two opens in the same second collide and WRITE wipes earlier lines. L254 also resets `_current_file_size = 0` unconditionally.
- **Remediation**: In `_open_log_file()`: if `FileAccess.file_exists(_log_file_path)` open with `FileAccess.READ_WRITE` + `seek_end()` and set `_current_file_size = _log_file.get_length()`; else keep WRITE. Alternatively append a monotonic counter suffix (`session_..._%d.jsonl`) when the target filename already exists so rotation/retry never reuses a live filename.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-025 [HIGH] [OPEN] Backup copy failure is logged but save still overwrites the primary

- **Audit ref**: 4.1.2-L161
- **Location**: `v1/scripts/autoload/save_manager.gd:165`
- **Execution phase**: D
- **Current evidence**: L164-166: `var err := DirAccess.copy_absolute(src, dst); if err != OK: AppLogger.error("SaveManager", "Backup fallito", ...)` — execution continues straight to the rename at L169, overwriting the only previous good save with no durable backup.
- **Remediation**: When the L164 copy fails and SAVE_PATH exists, abort the save: log the error, remove TEMP_PATH, set `_is_saving = false`, emit save_failed, and return before reaching L169. Never overwrite the primary without a verified backup.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-026 [HIGH] [OPEN] copy_absolute fallback is non-atomic, contradicting the 'Atomic write' contract

- **Audit ref**: 4.1.2-L174
- **Location**: `v1/scripts/autoload/save_manager.gd:174`
- **Execution phase**: D
- **Current evidence**: L148 comment still promises `# Atomic write: write to temp file first, then rename` but L174 falls back to a plain `DirAccess.copy_absolute(TEMP, SAVE)` which can partial-write the primary save if the process dies mid-copy. No retry, no post-copy verification.
- **Remediation**: Retry `rename_absolute` up to 3 times (short backoff) before degrading to copy. If copy is used, re-read SAVE_PATH, parse the wrapper, and compare its `hmac` field to the `hmac` computed at L150; on mismatch delete the partial file, restore from BACKUP_PATH, and emit save_failed.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-027 [HIGH] [OPEN] SQLite dual-write is fire-and-forget; save_completed emits before DB write is confirmed

- **Audit ref**: 4.1.2-L177
- **Location**: `v1/scripts/autoload/save_manager.gd:177`
- **Execution phase**: D
- **Current evidence**: L177 calls `_save_to_sqlite()` which (L192-204) only does `SignalBus.save_to_database_requested.emit({...})` — no return value, no completion callback. L180 `SignalBus.save_completed.emit()` fires immediately after, so a failed SQLite write leaves JSON and SQLite divergent while listeners see success.
- **Remediation**: Either call LocalDatabase synchronously (add e.g. `LocalDatabase.apply_save(payload) -> bool` and gate the L180 emit on both writes succeeding), or emit the request with a correlation id and only emit save_completed from a `save_to_database_completed(id, ok)` handler.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-028 [HIGH] [OPEN] HMAC mismatch silently falls through to backup/defaults

- **Audit ref**: 4.4.7-L257
- **Location**: `v1/scripts/autoload/save_manager.gd:261`
- **Execution phase**: D
- **Current evidence**: Lines 257-263 `_extract_hmac_inner`: `if stored_hmac != expected: AppLogger.warn("SaveManager", "HMAC mismatch — save file may be tampered", {"path": path}); return null`. Caller load_game() (207-212) then falls back to BACKUP_PATH and, failing that, defaults — no signal, no toast; SignalBus still has no save_integrity_violation signal. Unchanged.
- **Remediation**: Before `return null` at line 263, emit a new `SignalBus.save_integrity_violation(path)` (part of the planned error-signal vocabulary) wired to a toast, and quarantine the tampered file (rename to `*.tampered`) instead of leaving it to be overwritten by the next save.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-029 [HIGH] [OPEN] HMAC mismatch only warns and returns null; player silently lands on defaults

- **Audit ref**: 4.1.2-L257
- **Location**: `v1/scripts/autoload/save_manager.gd:262`
- **Execution phase**: D
- **Current evidence**: L261-263 (now inside `_extract_hmac_inner`, refactored from the audited inline form but behaviorally identical): `if stored_hmac != expected: AppLogger.warn("SaveManager", "HMAC mismatch — save file may be tampered", {"path": path}); return null`. Caller `load_game` L210-217 falls through to backup then `push_warning("no valid save file found, using defaults")`. No SignalBus integrity signal, no quarantine copy, no UI notification (grep for save_integrity/quarantine: zero hits).
- **Remediation**: In `_extract_hmac_inner` before `return null` at L263: copy the offending file to `user://save_data.quarantine.<unix_ts>.json`, add and emit `SignalBus.save_integrity_violation(path)`, and have a UI listener show a toast so tamper/corruption is visible instead of presenting a pristine new-account state.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-030 [HIGH] [OPEN] Integrity key silently regenerated when persist fails

- **Audit ref**: 4.4.7-L477
- **Location**: `v1/scripts/autoload/save_manager.gd:488`
- **Execution phase**: D
- **Current evidence**: Lines 477-492 `_get_integrity_key`: on any read failure (open fail at 479-480, bad length at 483) it falls through to regenerate; if `FileAccess.open(SECRET_PATH, FileAccess.WRITE)` at 488 returns null, the new key is returned WITHOUT being persisted and without any error log — next boot generates yet another key, invalidating every HMAC and making all saves look tampered (which then silently defaults per 4.4.7-L257). Unchanged.
- **Remediation**: At line 489, if `f == null`: AppLogger.error + emit db/save error signal, and either abort HMAC-protected saving for this session or retry. After store_string (490), read the file back and verify it round-trips to the same key before returning. Distinguish 'first run' (file absent) from 'read failed' (file present but unreadable) — only the former should regenerate silently.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-031 [HIGH] [OPEN] Integrity key persist failure is silent; next launch regenerates key and orphans all HMACs

- **Audit ref**: 4.1.2-L477
- **Location**: `v1/scripts/autoload/save_manager.gd:490`
- **Execution phase**: D
- **Current evidence**: L488-492: `var f := FileAccess.open(SECRET_PATH, FileAccess.WRITE); if f != null: f.store_string(key.hex_encode()); f.close(); return key` — an open failure (f == null) is not even logged, and `store_string` success is never checked. The in-memory key still signs this session's saves; on next boot a new key is generated and every existing save+backup fails HMAC, presenting as total save loss.
- **Remediation**: If `f == null` or `f.get_error() != OK` after store_string: AppLogger.error, and make the failure fatal for HMAC-signed saving (e.g. return empty PackedByteArray and have save_game abort with save_failed when the key cannot be persisted). Verify by re-opening SECRET_PATH READ and comparing content to `key.hex_encode()`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-032 [HIGH] [OPEN] Single-error-signal architecture: 48 signals, only auth_error carries failures

- **Audit ref**: 4.3-signal-vocabulary
- **Location**: `v1/scripts/autoload/signal_bus.gd:54`
- **Execution phase**: D
- **Current evidence**: Current signal_bus.gd still declares exactly 48 `^signal` lines (grep -c confirms 48); the only error channel remains `signal auth_error(message: String)` at L54. No save_failed, save_integrity_violation, sync_error, sync_payload_corrupted, catalog_load_failed, or db_error anywhere in v1/scripts/ (grep returns only the audit cross-reference in scripts/README.md:105). Error propagation is still log-and-stop.
- **Remediation**: Add the error-signal block to signal_bus.gd (save_failed(reason, last_good_save_path), save_integrity_violation(path, hmac_expected, hmac_actual), sync_error(operation, reason), sync_payload_corrupted(queue_id, preview), catalog_load_failed(path, reason), db_error(context, reason)); emit from SaveManager/SupabaseClient/GameManager/DBHelpers failure sites and route each to toast_requested with "error" severity in main.gd.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-033 [HIGH] [OPEN] _save_session() plaintext fallback return unchecked; silent plaintext token downgrade

- **Audit ref**: 4.1.1-L161
- **Location**: `v1/scripts/autoload/supabase_client.gd:174`
- **Execution phase**: D
- **Current evidence**: L171-174: `var err := cfg.save_encrypted_pass(SESSION_PATH, pass_key)` / `if err != OK:` / `AppLogger.error(..., {"err": err, "fallback": "plaintext"})` / `cfg.save(SESSION_PATH)` — fallback return value still not checked; refresh_token written plaintext on encrypted-save failure.
- **Remediation**: Capture `var err2 := cfg.save(SESSION_PATH)`; on `err2 != OK` log `AppLogger.error("SupabaseClient", "session_persist_double_failure", {"err": err2})` and keep in-memory state. Reconsider whether the plaintext fallback should write refresh_token at all (defeats B-019).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-034 [HIGH] [OPEN] Plaintext session fallback when encrypted save fails

- **Audit ref**: 4.4.6-L161
- **Location**: `v1/scripts/autoload/supabase_client.gd:174`
- **Execution phase**: D
- **Current evidence**: Lines 171-174 in _save_session(): `var err := cfg.save_encrypted_pass(SESSION_PATH, pass_key); if err != OK: AppLogger.error(..., {"err": err, "fallback": "plaintext"}); cfg.save(SESSION_PATH)` — JWT + refresh token written unencrypted to user:// on any encryption failure. Unchanged from audit.
- **Remediation**: Delete the `cfg.save(SESSION_PATH)` fallback at line 174. Fail closed: log ERROR, skip persistence (user re-authenticates next boot), and emit a SignalBus error signal so the UI can say "session not saved". Never write tokens plaintext.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-035 [HIGH] [OPEN] 401 handler refreshes JWT but drops the original request (no replay)

- **Audit ref**: 4.1.1-L297
- **Location**: `v1/scripts/autoload/supabase_client.gd:297`
- **Execution phase**: D
- **Current evidence**: L297-299: `elif status == 401:` / `AppLogger.warn("SupabaseClient", "JWT expired, refreshing", {"rid": rid})` / `refresh_jwt()` — the request that got 401 is never re-queued; its rid is never cleared, so a sync push hitting 401 contributes to permanent pending state.
- **Remediation**: Buffer {url, method, headers, body, rid} for 401'd requests in a `_retry_buffer: Array[Dictionary]`; replay them via _http.request after _apply_auth_response reaches ONLINE (L185-188); on refresh failure, erase their rids from _pending_requests and fail the sync.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-036 [HIGH] [OPEN] 404/relation-error swallowed as 'table not found, skip' with no kill-switch

- **Audit ref**: 4.1.1-L300
- **Location**: `v1/scripts/autoload/supabase_client.gd:300`
- **Execution phase**: D
- **Current evidence**: L300-311: `elif status == 404 or (status == 400 and _is_relation_error(body)):` → WARN "Table not found, skipping". No `SUPABASE_ALLOW_MISSING_TABLES` flag exists — constants.gd:49-51 only defines SUPABASE_SYNC_INTERVAL/REQUEST_TIMEOUT/MAX_RETRY. A table-name typo in _push_local_state would still be masked as graceful skip.
- **Remediation**: Add `const SUPABASE_ALLOW_MISSING_TABLES := true` to v1/scripts/utils/constants.gd; at L300 branch on it — when false, `AppLogger.error` + `SignalBus.sync_error.emit(...)` instead of WARN-and-continue. Flip default to false once schema is frozen.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-037 [HIGH] [OPEN] _process_sync_queue() deletes corrupt payloads silently (data loss, no DLQ)

- **Audit ref**: 4.1.1-L422
- **Location**: `v1/scripts/autoload/supabase_client.gd:434`
- **Execution phase**: D
- **Current evidence**: L433-436: `var json := JSON.new()` / `if json.parse(payload_str) != OK:` / `LocalDatabase.clear_sync_item(queue_id)` / `continue` — no log, no notification, no dead-letter. Same silent drop for retry-exhausted items at L427-429.
- **Remediation**: Before clear_sync_item, log WARN with {queue_id, table_name, payload_len, payload_str.left(32)}; move the row to a sync_dead_letter table (new repo method) instead of deleting; emit `SignalBus.sync_payload_corrupted`. Apply the same treatment to the retry>MAX branch at L427-429.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-038 [HIGH] [OPEN] Permanent stuck-sync: _pending_requests rids never match response rids

- **Audit ref**: 4.1.1-L501
- **Location**: `v1/scripts/autoload/supabase_client.gd:501`
- **Execution phase**: D
- **Current evidence**: Worse than audited. L438-439/L455-457 etc. register `sync_queue_%d`/`sync_push_*` rids in _pending_requests, but the wire request goes through upsert_to_table/delete_from_table which generate their OWN rids (`upsert_<table>_N` at L226, `delete_<table>_N` at L235). Responses therefore never begin with `sync_` → _handle_sync_response (L363-387) never erases entries, `_get_queue_id_from_rid` never clears queue rows, `_is_syncing` stays true forever after the first push (settings+music pushes at L476-485 are unconditional, so L501 `if _pending_requests.is_empty(): _finish_sync(true)` never fires). Every later `start_sync` returns at L410-411. Audit's pre-send-rejection scenario is secondary: supabase_http.gd:71-84 does emit a status-0 response, but with the mismatched rid.
- **Remediation**: Use the rid returned by upsert_to_table/delete_from_table as the tracking key everywhere: e.g. L455-457 → `var rid := upsert_to_table("profiles", profile); if not rid.is_empty(): _pending_requests[rid] = true`. For queue items, map returned-rid → queue_id in a Dictionary instead of encoding queue_id in the rid, and extend _handle_sync_response routing to `upsert_`/`delete_`/`fetch_` prefixes. Add a sync watchdog timeout that force-calls _finish_sync(false).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-039 [HIGH] [OPEN] Hardcoded "male_old" fallback masks empty/corrupt character catalog

- **Audit ref**: 4.1.9-L101
- **Location**: `v1/scripts/menu/main_menu.gd:102`
- **Execution phase**: D
- **Current evidence**: Unchanged (now L100-102): `var characters: Array = GameManager.characters_catalog.get("characters", [])` / `if characters.size() <= 1:` / `var char_id: String = characters[0].get("id", "male_old") if not characters.is_empty() else "male_old"`. Empty catalog still proceeds into gameplay with an invented id; "male_old" also appears as .get default.
- **Remediation**: When `characters.is_empty()`: emit `SignalBus.toast_requested.emit(tr("CATALOG_LOAD_FAILED"), "error")`, log via AppLogger.error, and return without transitioning. Keep the id only when read from the catalog; validate it against room_base's CHARACTER_SCENES (or a shared constant) before `_transition_to_scene`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-040 [HIGH] [OPEN] 5s fallback timer unconditionally releases _transitioning regardless of scene-change outcome

- **Audit ref**: 4.1.9-L286
- **Location**: `v1/scripts/menu/main_menu.gd:288`
- **Execution phase**: D
- **Current evidence**: Unchanged (now L287-288): `# Safety: reset _transitioning after 5s in case scene change fails silently` / `get_tree().create_timer(5.0).timeout.connect(func() -> void: _transitioning = false, CONNECT_ONE_SHOT)`. change_scene_to_file is bound via tween_callback (L286) with its Error return ignored; the timer cannot distinguish slow success from failure, so a slow load re-enables double-click of Nuova Partita (re-runs reset_character_data L91).
- **Remediation**: Replace the tween_callback bind at L286 with a lambda that captures the return: `var err := get_tree().change_scene_to_file(scene_path); if err != OK: _transitioning = false; SignalBus.toast_requested.emit(...)`. On success keep _transitioning true — the node is freed with the scene, so no timer is needed; delete L287-288.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-041 [HIGH] [OPEN] Arbitrary <10 connection cap silently no-ops the tutorial step

- **Audit ref**: 4.1.6-L237
- **Location**: `v1/scripts/menu/tutorial_manager.gd:237`
- **Execution phase**: D
- **Current evidence**: L235-238 unchanged: `if not sig_name.is_empty() and SignalBus.has_signal(sig_name):\n  var sig: Signal = SignalBus.get(sig_name)\n  if sig.get_connections().size() < 10:\n    sig.connect(_on_signal_received.bind(sig_name), CONNECT_ONE_SHOT)`. There is no else branch: when the bus signal already has 10+ listeners the step never connects, emits no warning, and hangs until STEP_TIMEOUT (30.0, L8) force-advances via _process L295-296.
- **Remediation**: Delete the `< 10` guard (tutorial connections are ephemeral and cleaned by _disconnect_all_signals L358-368), or if a cap must stay, add `else: AppLogger.warn("Tutorial", "connection refused, step will rely on timeout", {"signal": sig_name, "connections": sig.get_connections().size()})`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-042 [HIGH] [OPEN] Filter reject re-subscribes one-shot and silently swallows event, no log/metric

- **Audit ref**: 4.1.6-L264
- **Location**: `v1/scripts/menu/tutorial_manager.gd:266`
- **Execution phase**: D
- **Current evidence**: L262-271 unchanged: `if filter not in received:\n  var sig_name: String = step.get("signal_name", "")\n  if SignalBus.has_signal(sig_name):\n    var sig: Signal = SignalBus.get(sig_name)\n    sig.connect(_on_signal_received.bind(sig_name), CONNECT_ONE_SHOT)\n  return`. No AppLogger call, no rejection counter, no tracked connection handle. Note: the audit's 'unbounded accumulation' sub-claim is overstated — CONNECT_ONE_SHOT auto-disconnects on fire, so each rejecting emission consumes the old connection before one new connection is added (steady-state stays at 1). The silent-swallow half of the finding is fully accurate and unremediated.
- **Remediation**: Connect once per step WITHOUT one-shot in _advance_step, do the filter check statefully inside _on_signal_received, and disconnect only on accept/step-change (already handled by _disconnect_all_signals at L212). Add `AppLogger.debug("Tutorial", "filter miss", {"step": _current_step, "got": received, "want": filter})` on the reject path so stuck-tutorial repros are diagnosable.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-043 [HIGH] [OPEN] WILD state moves at 140 px/s with no floor-polygon bounds check

- **Audit ref**: 4.1.10-L77
- **Location**: `v1/scripts/rooms/pet_controller.gd:84`
- **Execution phase**: D
- **Current evidence**: Unchanged: _process_wild (L77-88) does `velocity = _wild_direction * WILD_SPEED` / `move_and_slide()` with no clamp or reflection. `Helpers.clamp_inside_floor` is applied in WANDER target selection (L212) but nothing constrains WILD. If pet_wild_mode_requested(false) never arrives, pet stays off-grid.
- **Remediation**: After move_and_slide() at L85 add: `var clamped := Helpers.clamp_inside_floor(position); if clamped != position: position = clamped; _wild_direction = -_wild_direction` (or `_wild_direction = _wild_direction.bounce((position - clamped).normalized())`) so the pet reflects off the floor boundary.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-044 [HIGH] [OPEN] Character swap dereferences character_node with no null/freed guard on the swap path

- **Audit ref**: 4.1.8-L80
- **Location**: `v1/scripts/rooms/room_base.gd:80`
- **Execution phase**: D
- **Current evidence**: Unchanged: idempotency guard at L74 `if character_node != null and is_instance_valid(character_node) and character_node.scene_file_path == scene_path: return` only short-circuits the same-scene case. A real swap with a null/freed character_node falls through to L80 `var old_pos := character_node.position` and L81 `character_node.queue_free()` — hard fault on freed reference.
- **Remediation**: After the scene-load check (L76-79) add: `if character_node == null or not is_instance_valid(character_node): AppLogger.warn(...); return` (or fall back to a default spawn position) before dereferencing at L80.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-045 [HIGH] [OPEN] Profile image loaded from arbitrary path with no size bound

- **Audit ref**: 4.4.9-profile
- **Location**: `v1/scripts/ui/profile_hud_panel.gd:207`
- **Execution phase**: D
- **Current evidence**: Lines 204-212 `_on_profile_image_selected`: `var img := Image.load_from_file(path)` at 207 with only a null/empty check at 208, then resize at 211. No file-size cap, no dimension cap, no extension/magic validation beyond the FileDialog filter (line 197) which the OS dialog does not strictly enforce — a multi-hundred-megapixel PNG still decodes fully into RAM before the resize. Unchanged.
- **Remediation**: Before line 207: open with FileAccess and reject if `get_length()` > e.g. 10 MB; after load, reject if `img.get_width() > 8192 or img.get_height() > 8192` before the LANCZOS resize; validate extension against ["png","jpg","jpeg"] with `path.get_extension().to_lower()`. Reuse the existing toast_requested error path (line 209) for each rejection.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-046 [HIGH] [OPEN] Profile image load: no size cap or magic-byte validation before Image.load_from_file

- **Audit ref**: 4.1.7-L207
- **Location**: `v1/scripts/ui/profile_hud_panel.gd:207`
- **Execution phase**: D
- **Current evidence**: L207-212 unchanged: `var img := Image.load_from_file(path)` -> `if img == null or img.is_empty(): ... return` -> `img.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)` -> `var err := img.save_png(PROFILE_IMAGE_PATH)`. Arbitrary user path decoded with no byte-size guard and no PNG/JPG magic check; FileDialog filter (L197) is advisory only. Error path (L213-215) toasts but never removes a partial user://profile_image.png.
- **Remediation**: In _on_profile_image_selected, before Image.load_from_file: `var bytes := FileAccess.get_file_as_bytes(path)`; reject if `bytes.size() > 10 * 1024 * 1024` or if first bytes are neither PNG magic (89 50 4E 47) nor JPEG magic (FF D8 FF); use Image.load_png_from_buffer/load_jpg_from_buffer on the validated buffer instead of load_from_file. On save_png failure, DirAccess.remove_absolute(PROFILE_IMAGE_PATH) to clean partial output.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-047 [HIGH] [OPEN] Unmatched disconnect leaks bound callable on HTTPRequest pool node

- **Audit ref**: 4.5.1-L71-84
- **Location**: `v1/scripts/utils/supabase_http.gd:72`
- **Execution phase**: D
- **Current evidence**: L61: `http.request_completed.connect(_on_http_done.bind(http, rid), CONNECT_ONE_SHOT)`; L71-73: `if err != OK:\n\thttp.request_completed.disconnect(_on_http_done)\n\t_return_to_pool(http)`. The disconnect argument lacks `.bind(http, rid)` so it does not match the bound Callable; the node returns to `_pool` with the stale one-shot connection still attached. Next `_send` on the same node stacks a second bound callable; on emit both fire, producing a phantom `request_completed` for the previously-failed rid. Code identical to audit time.
- **Remediation**: In `_send`, store the bound callable in a local: `var cb := _on_http_done.bind(http, rid); http.request_completed.connect(cb, CONNECT_ONE_SHOT)` and on the err path call `http.request_completed.disconnect(cb)`. (Do NOT just delete line 72 as the report's option 3 suggests: the synthetic emit at L74-84 is on SupabaseHttp's own `request_completed` signal, not on `http.request_completed`, so it never triggers the node's ONE_SHOT auto-disconnect.)
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-048 [MEDIUM] [OPEN] Third-party action + CI container not SHA-pinned

- **Audit ref**: 4.11.3
- **Location**: `.github/workflows/release.yml:138`
- **Execution phase**: E
- **Current evidence**: release.yml:138 `uses: softprops/action-gh-release@v2` (still major-pinned). Container tag unchanged in 5 places: ci.yml:203 & 240, build.yml:79, 152, 327 all `image: barichello/godot-ci:4.6` (mutable tag, no @sha256 digest). Scope has WIDENED since the audit: release.yml:87, 94, 101 now use third-party `dawidd6/action-download-artifact@v3`, also major-pinned — same risk class, not in the original audit table. lewagon/wait-on-check-action@v1.3.4 (release.yml:36,45,54,63) remains patch-pinned as before.
- **Remediation**: Pin third-party actions to full commit SHAs: `softprops/action-gh-release@<40-char-sha> # v2.x.y` and likewise for the three dawidd6/action-download-artifact@v3 refs. Digest-pin the container in all 5 jobs: `image: barichello/godot-ci@sha256:<digest> # 4.6`. Add a Dependabot github-actions ecosystem config so pinned SHAs still get upgrade PRs.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-049 [MEDIUM] [OPEN] No Subresource Integrity hashes on any CDN script/style

- **Audit ref**: 4.11.4c
- **Location**: `docs/index.html:15`
- **Execution phase**: E
- **Current evidence**: grep -rn 'integrity' across docs/**/*.html returns zero matches. index.html:15 (lucide@0.453.0), :18 (cdn.jsdelivr.net/particles.js/2.0.0/particles.min.js), :21 (aos@2.3.1 css), :22 (aos@2.3.1 js) all gained `crossorigin="anonymous"` but carry no `integrity=` attribute — crossorigin without the hash provides no integrity protection. Team pages (docs/team/*.html:13-15) have neither crossorigin nor integrity.
- **Remediation**: Compute sha384 for each pinned asset (e.g. `curl -s <url> | openssl dgst -sha384 -binary | openssl base64 -A`) and add `integrity="sha384-..."` alongside the existing crossorigin on index.html:15,18,21,22. Do the same on the three team pages after pinning Lucide there (4.11.4a). Note SRI is only possible on pinned URLs — @latest can never carry a valid hash.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-050 [MEDIUM] [OPEN] godot-sqlite binaries committed without checksums / no CI verification

- **Audit ref**: 4.11.1
- **Location**: `v1/addons/godot-sqlite/bin/binaries_here.txt:2`
- **Execution phase**: E
- **Current evidence**: No SHA256SUMS file exists anywhere under v1/addons/ (ls confirms only bin/, gdsqlite.gdextension, godot-sqlite.gd, plugin.cfg). binaries_here.txt:1-2 still reads: 'Download binaries and place them in this folder. / Latest binaries: https://github.com/2shady4u/godot-sqlite/releases' — manual drop-in with zero verification. No workflow greps match sha256/checksum for addon binaries (release.yml SHA256SUMS covers built .exe/.apk/.zip artifacts only). Aggravating: git status shows ALL 20 addon binaries as uncommitted-modified; .gitattributes tracks '*.so/*.dll/*.a/*.wasm filter=lfs' but `git lfs ls-files` returns only 1 file (libgodot-cpp.ios.template_release.universal.simulator.a), so HEAD stores most binaries raw while the working tree filter now converts them to 133-byte LFS pointers — an inconsistent state where a swapped binary is exactly as invisible in diff as the audit warned.
- **Remediation**: 1) Add v1/addons/godot-sqlite/SHA256SUMS listing upstream-release sha256 of every .so/.dll/.a/.wasm in bin/. 2) Add a CI step (e.g. in ci.yml validators job): `cd v1/addons/godot-sqlite && sha256sum -c SHA256SUMS`. 3) Resolve the LFS half-migration: either commit the pointer conversion for all binaries (git add --renormalize) or drop the *.a/*.so LFS attributes — do not leave 20 binaries perpetually dirty.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-051 [MEDIUM] [OPEN] crossfade_to_mood_track name misnomer — function only scales volume and emits mood signals

- **Audit ref**: 4.1.5-L392
- **Location**: `v1/scripts/autoload/audio_manager.gd:392`
- **Execution phase**: E
- **Current evidence**: L392 unchanged: `func crossfade_to_mood_track(mood: float) -> void:`. Body (L393-412) computes `volume_scale: float = 0.5 + 0.5 * clamped`, sets `_active_player.volume_db`, and emits `SignalBus.mood_changed` on threshold crossings. No track swap or crossfade occurs here; the real crossfade lives in _on_mood_changed (L201-246). The T-R-015i comment (L387-391) documents the strategy but the misleading name stands.
- **Remediation**: Rename to `apply_mood_scalar`. Two call-site touches in v1/scripts/autoload/mood_manager.gd: the string literal in `AudioManager.has_method("crossfade_to_mood_track")` at L68 and the call at L69 — both must be updated or the has_method guard will silently skip the call.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-052 [MEDIUM] [OPEN] Username validation is length-only, no charset whitelist

- **Audit ref**: 4.4.3
- **Location**: `v1/scripts/autoload/auth_manager.gd:49`
- **Execution phase**: E
- **Current evidence**: Lines 49-53 in register(): `var clean_name := username.strip_edges()` then only `clean_name.length() < 3` and `> Constants.AUTH_MAX_USERNAME_LENGTH` (=50 in constants.gd:46). No RegEx, no NFC normalization anywhere in the file — RTL overrides, zero-width chars, NULs, and interior whitespace all still accepted.
- **Remediation**: After strip_edges at line 49, validate with `var re := RegEx.new(); re.compile("^[A-Za-z0-9_.-]{3,50}$")` and return an error dict on no-match (reuse the existing error-dict pattern of lines 51-56). Apply the same whitelist to the login() lookup input at line 80 for symmetry.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-053 [MEDIUM] [OPEN] Wall-clock time in rate-limit expiry evaluation

- **Audit ref**: 4.2-L72
- **Location**: `v1/scripts/autoload/auth_manager.gd:72`
- **Execution phase**: E
- **Current evidence**: Line 72 (login()): `var now := Time.get_unix_time_from_system()` then line 74 `var remaining := int(_lockout_until - now)`. Identical to audit; no time-injection seam exists, so lockout expiry is still wall-clock-denominated and untestable without real waits.
- **Remediation**: Extract `func _now_sec() -> float: return Time.get_unix_time_from_system()` and call it at line 72; better, switch both the check and _lockout_until to `Time.get_ticks_msec()` (monotonic). In tests, override _now_sec via a settable var or subclass.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-054 [MEDIUM] [OPEN] Pre-v2 fixed-salt legacy hash still accepted indefinitely

- **Audit ref**: 4.4.4
- **Location**: `v1/scripts/autoload/auth_manager.gd:106`
- **Execution phase**: E
- **Current evidence**: Line 15: `const _LEGACY_SALT := "MiniCozyRoom2026"`; lines 104-109: else-branch computes `var legacy := (_LEGACY_SALT + password).sha256_text()` and accepts it (`pw_ok = (stored_hash == legacy)`). Migration only fires on successful login (118-123); dormant pre-v2 accounts remain rainbow-tableable forever. No deprecation counter, no cutoff.
- **Remediation**: In the legacy branch (line 108), add `AppLogger.warn("AuthManager", "legacy_v1_verify", {"account_id": ...})` to count survivors; add a `const _LEGACY_CUTOFF_UNIX` (e.g. 60 days post-v1.0) after which the else-branch returns {"error": "Password reset required"} and emits a SignalBus password-reset signal instead of verifying.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-055 [MEDIUM] [OPEN] Lockout deadline set from rewindable system clock

- **Audit ref**: 4.2-L133
- **Location**: `v1/scripts/autoload/auth_manager.gd:133`
- **Execution phase**: E
- **Current evidence**: Line 133 (_record_failed_attempt()): `_lockout_until = Time.get_unix_time_from_system() + Constants.AUTH_LOCKOUT_SECONDS`. Unchanged. Setting the system clock backwards extends the lockout; forwards clears it instantly.
- **Remediation**: Store lockout as `_lockout_until_ms = Time.get_ticks_msec() + Constants.AUTH_LOCKOUT_SECONDS * 1000` and compare against ticks in login() line 72-76. Monotonic ticks cannot be rewound by clock edits. Coordinate with the 4.4.2 persistence fix (persisted deadline must then be wall-clock or attempt-count based).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-056 [MEDIUM] [OPEN] genere bool-to-int truthy coercion corrupts non-bool inputs

- **Audit ref**: 4.1.15-L31
- **Location**: `v1/scripts/autoload/database/characters_repo.gd:31`
- **Execution phase**: E
- **Current evidence**: L31 (UPDATE branch) and L53 (INSERT branch): `1 if data.get("genere", true) else 0` — a string value like "female" is truthy and becomes 1; int 0 stays 0; no type validation against `genere INTEGER DEFAULT 1` (schema.gd:48).
- **Remediation**: Replace both occurrences (L31 and L53) with an explicit coercion helper: accept bool -> 1/0, int -> clamp to 0/1, anything else -> AppLogger.warn + default 1. Simplest: `int(bool(data.get("genere", true)))` only if inputs are guaranteed bool; otherwise validate type explicitly.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-057 [MEDIUM] [OPEN] sql.left(80) truncation hides WHERE clause; db.error_message never logged

- **Audit ref**: 4.1.12-L13
- **Location**: `v1/scripts/autoload/database/db_helpers.gd:14`
- **Execution phase**: E
- **Current evidence**: All seven log sites (L11, 14, 21, 24, 31, 35, 44) still use `sql.left(80)`; `db.error_message` (exposed by godot-sqlite) appears nowhere in the file, so engine-level failure detail (constraint name, lock state) is lost. L13-14: `if not db.query(sql):\n\tAppLogger.error("LocalDatabase", "Query failed", {"sql": sql.left(80)})`.
- **Remediation**: Add `"error": db.error_message` to every failure context in execute/execute_bound/select, and raise the preview cap to `sql.left(400)` (or log `sql.sha256_text().left(8)` plus a 120-char preview) so WHERE context survives.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-058 [MEDIUM] [OPEN] Decorations stored twice (rooms.decorations JSON blob + placed_decorations rows) with no sync contract

- **Audit ref**: 4.1.17-L16
- **Location**: `v1/scripts/autoload/database/rooms_deco_repo.gd:16`
- **Execution phase**: E
- **Current evidence**: L16: `var decorations_json: String = JSON.stringify(data.get("decorations", []))` written into `rooms.decorations` (schema.gd:65 `decorations TEXT DEFAULT '[]'`), while L54-89 maintain the normalized `placed_decorations` table (schema.gd:136-148). No code or comment defines which is authoritative or the write-through order.
- **Remediation**: Pick the normalized `placed_decorations` table as the single source of truth and drop the JSON blob writes from upsert_room (L16, L23-24, L44), or add an explicit doc comment + reconciliation rule (blob rebuilt from rows on every save) and enforce it in _on_save_requested.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-059 [MEDIUM] [OPEN] remove_placed_decoration returns true for non-existent placement_id

- **Audit ref**: 4.1.17-L85
- **Location**: `v1/scripts/autoload/database/rooms_deco_repo.gd:85`
- **Execution phase**: E
- **Current evidence**: L84-85: `static func remove_placed_decoration(db: SQLite, placement_id: int) -> bool:\n\treturn DBHelpers.execute_bound(db, "DELETE FROM placed_decorations WHERE placement_id = ?;", [placement_id])` — execute_bound only reports statement success, not rows affected; deleting a missing id returns true.
- **Remediation**: After the DELETE, run `var rows := DBHelpers.select(db, "SELECT changes() AS n;", [])`; if `rows[0].get("n", 0) == 0`, AppLogger.warn with placement_id and return false (or a distinct signal) so callers can detect the no-op.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-060 [MEDIUM] [OPEN] playlist_mode default diverges across stack: DB 'sequential' vs AudioManager 'shuffle'

- **Audit ref**: 4.1.18-L139
- **Location**: `v1/scripts/autoload/database/settings_repo.gd:142`
- **Execution phase**: E
- **Current evidence**: settings_repo.gd:142 and :163 `data.get("playlist_mode", "sequential")`; schema.gd:125 `playlist_mode TEXT NOT NULL DEFAULT 'sequential'`; audio_manager.gd:12 `var playlist_mode: String = "shuffle"` and :72 `playlist_mode = state.get("playlist_mode", "shuffle")`. No `DEFAULT_PLAYLIST` constant exists in v1/scripts/utils/constants.gd (grep empty).
- **Remediation**: Add `const DEFAULT_PLAYLIST_MODE := "shuffle"` (matching gameplay behavior) to constants.gd and reference it at settings_repo.gd:142/:163, audio_manager.gd:12/:72; align schema.gd:125 DDL default in a migration or accept DB-side divergence explicitly documented.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-061 [MEDIUM] [OPEN] ambience_enabled bool-to-int truthy coercion

- **Audit ref**: 4.1.18-L143
- **Location**: `v1/scripts/autoload/database/settings_repo.gd:143`
- **Execution phase**: E
- **Current evidence**: L143 (UPDATE branch) and L164 (INSERT branch): `1 if data.get("ambience_enabled", true) else 0` — same truthy-coercion pattern as characters_repo genere; non-bool inputs (string "false" is truthy) silently coerce wrong.
- **Remediation**: At both L143 and L164 validate type first: `var amb: bool = bool(data.get("ambience_enabled", true))` only after asserting the value is bool/int; warn and default to true for unexpected types.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-062 [MEDIUM] [OPEN] PRAGMA foreign_keys disabled is warn-only, not fail-closed

- **Audit ref**: 4.1.4-L94
- **Location**: `v1/scripts/autoload/local_database.gd:94`
- **Execution phase**: E
- **Current evidence**: L94-96: `var fk_check := DBHelpers.select(_db, "PRAGMA foreign_keys;", [])\nif fk_check.is_empty() or fk_check[0].get("foreign_keys", 0) != 1:\n\tAppLogger.warn("LocalDatabase", "Foreign keys not enabled")` — init continues with `_is_open = true` (set at L88) even when FKs are off, so every ON DELETE CASCADE in schema.gd silently stops working.
- **Remediation**: On failed check, retry `DBHelpers.execute(_db, "PRAGMA foreign_keys=ON;")` once and re-select; if still not 1, treat as hard init failure: AppLogger.error, `_db.close_db()`, `_is_open = false`, return — matching the fail path of _open_database at L70-87.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-063 [MEDIUM] [OPEN] Error-storm overflow still evicts incident-start entries — no dedicated ERROR retention

- **Audit ref**: 4.9.5
- **Location**: `v1/scripts/autoload/logger.gd:133`
- **Execution phase**: E
- **Current evidence**: Single `_log_buffer` (L25) with drop-oldest at cap 2000 (L133-134); no separate WARN/ERROR buffer anywhere in the file. Under a 429/HMAC storm the earliest INFO lines (incident start) are evicted first, exactly as described. Note: the 2 s flush timer (L14, L259-264) empties the buffer frequently, so loss requires the flush-unavailable path (L159-169) or >1000 lines/s — severity MEDIUM remains fair.
- **Remediation**: Add `var _error_buffer: Array[String]` (cap ~500, own drop-oldest): in `_log()` also append WARN/ERROR lines to it; on the flush-failure path (L159-169) retain `_error_buffer` in full instead of only the last 100 mixed entries, and drain it first when the file becomes available. Solves both this and part of 4.1.3-L133.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-064 [MEDIUM] [OPEN] Session-id keeps only 16 of 32 generated crypto-random bits, contradicting comment

- **Audit ref**: 4.1.3-L219
- **Location**: `v1/scripts/autoload/logger.gd:227`
- **Execution phase**: E
- **Current evidence**: L216 comment still claims "Numeri casuali crittograficamente sicuri"; L220-221 builds a full 32-bit `random_int` from `crypto.generate_random_bytes(4)`, but L227 masks it to `random_int & 0xFFFF` inside the `"%08x-%04x-%04x"` format (L223), discarding 16 bits. Collision space is 2^16 per second, unchanged.
- **Remediation**: Change the format to `"%08x-%04x-%08x"` and use `random_int & 0xFFFFFFFF` at L227 (keeps all 4 random bytes); or read only 2 bytes and fix the comment. One-line change plus any test asserting session-id shape.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-065 [MEDIUM] [OPEN] No startup recovery for orphaned save_data.tmp.json after a crash

- **Audit ref**: 4.8.3-orphan-temp
- **Location**: `v1/scripts/autoload/save_manager.gd:85`
- **Execution phase**: E
- **Current evidence**: `_ready()` at L85-93 only creates the autosave Timer and connects three SignalBus signals. TEMP_PATH (`user://save_data.tmp.json`, L10) is referenced only at L152 (write), L170 (rename src), L174 (copy src) — nothing inspects or cleans it at boot, so a crash between temp-write and rename leaves a newer, HMAC-valid save ignored forever.
- **Remediation**: In `_ready()`: if `FileAccess.file_exists(TEMP_PATH)` — when SAVE_PATH is missing and the temp's wrapper HMAC verifies via `_extract_hmac_inner`, rename temp -> SAVE_PATH (adopt it); otherwise `DirAccess.remove_absolute` the stale temp so it cannot shadow future saves.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-066 [MEDIUM] [OPEN] No recovery of orphan save_data.tmp.json after crash between write and rename

- **Audit ref**: 4.8.3-orphan-temp-save
- **Location**: `v1/scripts/autoload/save_manager.gd:85`
- **Execution phase**: E
- **Current evidence**: `_ready()` L85-93 only creates the auto-save timer and connects three SignalBus signals — no reference to `TEMP_PATH` (`user://save_data.tmp.json`, const at L10). Grep shows TEMP_PATH used only in `save_game` (L152, L170, L174). A crash between the temp write (L157-158) and rename (L169-171) still leaves an orphan ignored on next boot.
- **Remediation**: In `_ready()`: `if FileAccess.file_exists(TEMP_PATH):` — if `SAVE_PATH` is missing, or the temp file's HMAC verifies (reuse `_compute_hmac` against the wrapper's `data`/`hmac` fields) and it is newer than the primary, rename temp→primary; otherwise delete the stale temp.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-067 [MEDIUM] [OPEN] Temp-file store_string and close have no error check (silent truncation on full disk)

- **Audit ref**: 4.1.2-L152
- **Location**: `v1/scripts/autoload/save_manager.gd:157`
- **Execution phase**: E
- **Current evidence**: L157-158: `file.store_string(JSON.stringify(wrapper, "\t"))` / `file.close()` — no `file.get_error()` check after either call. Only the open (L153-156) is checked.
- **Remediation**: After L157 add `var werr := file.get_error(); if werr != OK: file.close(); DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); AppLogger.error(...); _is_saving = false; return`. Call `file.flush()` before close for durability.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-068 [MEDIUM] [OPEN] Only one backup file; no versioned backup ring

- **Audit ref**: 4.13.2-single-backup
- **Location**: `v1/scripts/autoload/save_manager.gd:164`
- **Execution phase**: E
- **Current evidence**: L11: single `const BACKUP_PATH := "user://save_data.backup.json"`; L161-166 does one `DirAccess.copy_absolute(src, dst)` overwriting the sole backup on every save; `load_game` L210-212 tries only that one BACKUP_PATH. If primary and backup are both corrupt, everything is lost.
- **Remediation**: Replace the single copy at L164 with a 3-deep ring: shift `save_data.backup.2.json` -> `.3`, `.1` -> `.2`, then copy primary -> `save_data.backup.1.json`; extend the load_game fallback loop to try each ring slot in order before defaulting.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-069 [MEDIUM] [OPEN] B-016 comment still promises dual-write completeness the code does not deliver

- **Audit ref**: 4.1.2-L186
- **Location**: `v1/scripts/autoload/save_manager.gd:184`
- **Execution phase**: E
- **Current evidence**: L184-186: `# B-016: payload completo dual-write JSON+SQLite. Prima solo character + inventory andavano al mirror; ... causando divergenza silente fra i due storage.` — but the function body is a single unverified `save_to_database_requested.emit(...)`, so divergence on a transient SQLite failure is still possible.
- **Remediation**: Either rewrite the comment to state this is an async fire-and-forget signal with no delivery guarantee, or implement the confirmed request/response pattern from the 4.1.2-L177 fix so the comment becomes true.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-070 [MEDIUM] [OPEN] Save from a newer app version is applied unchanged after a WARN

- **Audit ref**: 4.13.3-newer-save
- **Location**: `v1/scripts/autoload/save_manager.gd:338`
- **Execution phase**: E
- **Current evidence**: L338-340: `if _compare_versions(version, SAVE_VERSION) > 0: AppLogger.warn("SaveManager", "Save from newer version", {"save": version, "app": SAVE_VERSION}); return data` — load_game then feeds it to `_apply_save_data`. Crash risk is partially mitigated by `_apply_save_data`'s type-checked key whitelist (L272-329), but the newer file gets re-saved in the old schema on next autosave, destructively downgrading it.
- **Remediation**: On a newer-version save, refuse to load-and-overwrite: keep the file untouched, load defaults in memory with autosave disabled (or copy the file to `save_data.newer.json` first), and emit a signal so the UI can tell the user to update the app.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-071 [MEDIUM] [OPEN] v3->v4 migration silently resets inventory items with only a WARN, no preservation

- **Audit ref**: 4.1.2-L381
- **Location**: `v1/scripts/autoload/save_manager.gd:383`
- **Execution phase**: E
- **Current evidence**: L383-393: `if not inv.has("coins") or not inv.has("items"): AppLogger.warn(..., "Inventario corrotto durante migrazione v3->v4, reset", ...)` then `data["inventory"] = {"coins": inv.get("coins", old_coins), "capacita": inv.get("capacita", 50), "items": []}`. Coins/capacita are salvaged but `items` is dropped to `[]` with no backup of the original payload and no user notification. L394-395 also silently empties non-Array items.
- **Remediation**: Before the L389 overwrite, serialize the original `inv` dict to `user://save_data.v3_preserved.json` for recovery, and emit a user-visible warning (toast on next load) that inventory items were reset during migration.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-072 [MEDIUM] [OPEN] v3->v4 inventory silent reset (cross-ref of 4.1.2-L381, same code)

- **Audit ref**: 4.13.3-inv-crossref
- **Location**: `v1/scripts/autoload/save_manager.gd:383`
- **Execution phase**: E
- **Current evidence**: Same code as 4.1.2-L381: L383-393 resets `items` to `[]` with only `AppLogger.warn`, no preservation file (`grep v3_preserved` across v1/scripts/: zero hits). Listed separately in 4.13.3 as a lifecycle gap; not an independent defect.
- **Remediation**: Single fix shared with 4.1.2-L381: preserve the original inventory payload to `user://save_data.v3_preserved.json` before the reset and surface a user-visible notice.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-073 [MEDIUM] [OPEN] Silent early-return from _ready() on invalid config, no state signal

- **Audit ref**: 4.1.1-L45
- **Location**: `v1/scripts/autoload/supabase_client.gd:45`
- **Execution phase**: E
- **Current evidence**: L45-47: `if not _config.get("valid", false):` / `AppLogger.info("SupabaseClient", "No valid Supabase config, cloud sync disabled")` / `return` — still INFO-only, no SignalBus emission; _http stays null with no observer notification.
- **Remediation**: Before the `return` at line 47, add `SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)` so observers get a consistent state-change event when cloud is disabled.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-074 [MEDIUM] [OPEN] refresh_jwt() returns silently when refresh token is empty

- **Audit ref**: 4.1.1-L107
- **Location**: `v1/scripts/autoload/supabase_client.gd:108`
- **Execution phase**: E
- **Current evidence**: L107-109: `func refresh_jwt() -> void:` / `if _refresh_token.is_empty():` / `return` — no signal, no state transition. _ensure_jwt() at L240-248 still calls it near expiry, so expired sessions loop through 401s with no caller-visible failure.
- **Remediation**: In the empty-token branch set `_jwt_token = ""`, `connection_state = ConnectionState.OFFLINE`, and emit `SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)` before returning.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-075 [MEDIUM] [OPEN] connection_state mutated directly at 5 call sites, no central setter

- **Audit ref**: 4.8.2-supabase-connstate-setter
- **Location**: `v1/scripts/autoload/supabase_client.gd:121`
- **Execution phase**: E
- **Current evidence**: Direct writes remain at L121 (`sign_out_cloud`), L185 and L200 (`_apply_auth_response`), L295 (network-failure branch of `_on_request_completed`), L356 (refresh-failure branch) — grep confirms no `_set_connection_state` funnel exists. Each site manually pairs the write with its own `SignalBus.cloud_connection_changed.emit(...)` (L123, L188, L202, L296, L357), so write/emit drift is possible. (Report counted 6 sites; L202 is actually the emit paired with the L200 write — 5 assignment sites in current code. Finding substance unchanged.)
- **Remediation**: Add `func _set_connection_state(new_state: int) -> void: assert(new_state in ConnectionState.values()); if connection_state == new_state: return; connection_state = new_state; SignalBus.cloud_connection_changed.emit(new_state)` and route L121, L185, L200, L295, L356 through it, deleting the five manual emit lines.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-076 [MEDIUM] [OPEN] fetch/upsert/delete return empty-string sentinel; all call sites ignore it

- **Audit ref**: 4.1.1-L208
- **Location**: `v1/scripts/autoload/supabase_client.gd:208`
- **Execution phase**: E
- **Current evidence**: L208-237: all three return `""` after `if not _ensure_jwt(): return ""`, undocumented. Aggravated: sync call sites (L441, L443, L457, L464, L478, L485, L494, L498) discard the returned rid entirely and instead register a separately generated `sync_*` rid in _pending_requests, so the sentinel is never even observable.
- **Remediation**: Make callers use the returned rid as the tracking key: `var rid := upsert_to_table(t, data); if rid.is_empty(): <handle rejected>; else: _pending_requests[rid] = true`. Change return to `Variant` with null sentinel or emit a `cloud_request_rejected` signal on not-ready.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-077 [MEDIUM] [OPEN] Synchronous error emit re-enters response handling inside _process_sync_queue

- **Audit ref**: 4.8.4-sync-reentrancy
- **Location**: `v1/scripts/autoload/supabase_client.gd:422`
- **Execution phase**: E
- **Current evidence**: Unchanged and confirmed worse than described: `supabase_http.gd:71-84` emits `request_completed` synchronously when `http.request()` errors; `_process_sync_queue` (L422-443) sets `_pending_requests[rid] = true` (L439) then calls `upsert_to_table`/`delete_from_table`, so `_handle_sync_response` can run mid-loop, erase the rid (L369), and — because `_pending_requests.is_empty() and _is_syncing` (L386) — call `_finish_sync(true)` (L387) before `start_sync` (L409-419) has even invoked `_push_local_state()`, leaving `_is_syncing=false` so the later completion check never fires a second `sync_completed`.
- **Remediation**: Make the error path in `supabase_http.gd::_send` asynchronous: replace the direct emit at L74-84 with `request_completed.emit.call_deferred({...})` (Godot 4.6 supports Callable.call_deferred on signal emit; alternatively `call_deferred("_emit_error", rid, err)` helper). Optionally also pre-register all rids in `start_sync` before dispatching any HTTP work so the empty-check at supabase_client.gd:386 cannot trip early.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-078 [MEDIUM] [OPEN] Queue DELETE builds 'id=eq.' with empty id when payload malformed

- **Audit ref**: 4.1.1-L440
- **Location**: `v1/scripts/autoload/supabase_client.gd:441`
- **Execution phase**: E
- **Current evidence**: L440-441: `if operation == "DELETE":` / `delete_from_table(table_name, "id=eq." + str(payload.get("id", "")))` — no assertion that payload is a Dictionary with a non-empty id; malformed payload yields `?id=eq.`.
- **Remediation**: Guard before L441: `if not (payload is Dictionary) or str(payload.get("id", "")).is_empty(): AppLogger.warn("SupabaseClient", "sync_delete_missing_id", {"queue_id": queue_id}); continue`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-079 [MEDIUM] [OPEN] Sync-queue DELETE builds id-only filter, empty-id degenerate

- **Audit ref**: 4.4.9-delete
- **Location**: `v1/scripts/autoload/supabase_client.gd:441`
- **Execution phase**: E
- **Current evidence**: Lines 440-443: `if operation == "DELETE": delete_from_table(table_name, "id=eq." + str(payload.get("id", "")))`. Unchanged — if payload lacks id the filter becomes `id=eq.` (malformed PostgREST filter), and the delete is scoped only by id, relying entirely on RLS for tenant isolation.
- **Remediation**: Guard before line 441: if `str(payload.get("id", "")).is_empty()` → log + clear_sync_item and continue. Append `&user_id=eq.%s` % supabase_user_id to the filter so a mis-configured RLS policy cannot make cross-tenant deletes possible.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-080 [MEDIUM] [OPEN] room_decorations delete-all-by-user relies on a single upstream guard

- **Audit ref**: 4.1.1-L494
- **Location**: `v1/scripts/autoload/supabase_client.gd:494`
- **Execution phase**: E
- **Current evidence**: L494: `delete_from_table("room_decorations", "user_id=eq." + supabase_user_id)` — only defense is the `if supabase_user_id.is_empty(): _finish_sync(false); return` guard at L447-449; delete_from_table (L231-237) has no defense-in-depth check for empty eq. values.
- **Remediation**: Inside delete_from_table at L231-234 add: `if query.ends_with("=eq."): AppLogger.error("SupabaseClient", "refusing_unscoped_delete", {"table": table}); return ""`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-081 [MEDIUM] [OPEN] Carica Partita enablement checks JSON save file only, ignores SQLite account state

- **Audit ref**: 4.1.9-L40
- **Location**: `v1/scripts/menu/main_menu.gd:40`
- **Execution phase**: E
- **Current evidence**: Unchanged: L40-42 `if not FileAccess.file_exists(SaveManager.SAVE_PATH): _carica_btn.disabled = true; _carica_btn.modulate.a = 0.5`. No LocalDatabase consultation — users whose authoritative state lives in the DB see a disabled load button.
- **Remediation**: Extend the condition: `var has_json := FileAccess.file_exists(SaveManager.SAVE_PATH)`; `var has_db := AuthManager.current_account_id > 0 and not LocalDatabase.get_account_by_auth_uid(AuthManager.current_auth_uid).is_empty()` (adapt to the actual LocalDatabase accessor); disable only when both are false.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-082 [MEDIUM] [OPEN] Arrow target resolved by first-match name walk over entire scene tree

- **Audit ref**: 4.1.6-L305
- **Location**: `v1/scripts/menu/tutorial_manager.gd:305`
- **Execution phase**: E
- **Current evidence**: L305 unchanged: `var target := _find_node_by_name(get_tree().root, target_name)` inside _show_arrow. _find_node_by_name (L312-319) is a depth-first recursion returning the FIRST node whose `name` matches — Godot does not enforce name uniqueness across branches, so a hidden/duplicate `DecoButton`/`ProfileButton` (step targets at L70, L98) silently routes the arrow to the wrong control. Additionally L307-308 uses `target.global_position` to set `_arrow.position` — a CanvasLayer-local write mixing coordinate spaces.
- **Remediation**: Register target buttons in named groups (e.g. `add_to_group("tutorial_deco_button")`) and resolve via `get_tree().get_first_node_in_group(...)`, or store explicit NodePaths in the step dictionaries; log a warning when the target is not found (currently a silent no-arrow no-op since `null is Control` is false).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-083 [MEDIUM] [OPEN] has_signal("pet_wild_mode_requested") string-literal guard hides signal rename breakage

- **Audit ref**: 4.1.10-L46
- **Location**: `v1/scripts/rooms/pet_controller.gd:46`
- **Execution phase**: E
- **Current evidence**: Unchanged: L46-47 `if SignalBus.has_signal("pet_wild_mode_requested"): SignalBus.pet_wild_mode_requested.connect(_on_wild_mode_requested)`; mirrored guard in _exit_tree (L264-268). The signal exists on the bus (signal_bus.gd:83), so the guard is dead defensive code that would silently disable WILD if the bus-side name ever changed.
- **Remediation**: Delete the has_signal wrappers at L46 and L264-265; connect/disconnect `SignalBus.pet_wild_mode_requested` directly so a rename fails loudly at parse time.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-084 [MEDIUM] [OPEN] Character nudge position not clamped inside floor polygon

- **Audit ref**: 4.1.8-L110
- **Location**: `v1/scripts/rooms/room_base.gd:116`
- **Execution phase**: E
- **Current evidence**: Unchanged: L116-117 `var nudge_pos := _find_nearest_free_position(char_pos, deco_rect); character_node.position = nudge_pos`. _find_nearest_free_position (L232-246) returns edge +/- 20.0 px with no floor-polygon verification (e.g. L241 `return Vector2(blocked.position.x - 20.0, char_pos.y)`). Helpers.clamp_inside_floor exists (helpers.gd:125) and is used elsewhere (drop_zone.gd:54, pet_controller.gd:212, mess_spawner.gd:122) but not here.
- **Remediation**: Wrap the result at L116: `var nudge_pos := Helpers.clamp_inside_floor(_find_nearest_free_position(char_pos, deco_rect))`; if the clamped point is still inside deco_rect, iterate the other three edge candidates and pick the first clamped point outside the rect.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-085 [MEDIUM] [OPEN] Vector2.ZERO sentinel in _spawn_pet conflates unset position with legal (0,0) spawn

- **Audit ref**: 4.1.8-L280
- **Location**: `v1/scripts/rooms/room_base.gd:282`
- **Execution phase**: E
- **Current evidence**: Unchanged (now L280-284): `var char_pos: Vector2 = Vector2(640, 360)` then `if character_node != null and is_instance_valid(character_node): if character_node.position != Vector2.ZERO: char_pos = character_node.position`. A character legitimately placed at origin still silently redirects the pet to viewport centre (640,360).
- **Remediation**: Drop the `!= Vector2.ZERO` test at L282 and instead gate on readiness: trust character_node.position whenever the node is valid (the sync _on_character_changed call at L43-44 already runs before _spawn_pet), or add a `_character_pos_ready: bool` set in _on_character_changed and check that flag.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-086 [MEDIUM] [OPEN] No structured metrics for save/sync/error counters — operational blindness unchanged

- **Audit ref**: 4.9.4
- **Location**: `v1/scripts/systems/performance_manager.gd:11`
- **Execution phase**: E
- **Current evidence**: grep for `perf.metric`, `metrics`, `save_attempts`, `sync_cycles` across v1/scripts returns nothing. performance_manager.gd emits only an init INFO (L11 `AppLogger.info("PerformanceManager", "Initialized", {"fps": Engine.max_fps})`) and threshold warns (~L31); no counter cadence, no metrics.jsonl. Save/sync/HMAC/timeout counts remain grep-only.
- **Remediation**: Add a minimal counter registry (dict of String->int, `Metrics.incr("save_failed")`) either inside AppLogger or PerformanceManager, and a periodic (e.g. 60 s) `AppLogger.info("Metrics", "snapshot", counters)` flush. Instrument SaveManager (attempt/fail), SupabaseClient (cycle/backoff/timeout/HMAC), DBHelpers (query_failed). Report scheduled this for v1.1.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-087 [MEDIUM] [OPEN] Mood slider set via .value relies on fragile _loading latch instead of set_value_no_signal

- **Audit ref**: 4.1.7-L160
- **Location**: `v1/scripts/ui/profile_hud_panel.gd:160`
- **Execution phase**: E
- **Current evidence**: L160 unchanged: `_mood_slider.value = clampf(saved_mood, 0.0, 1.0)` inside _load_state(), guarded only by `_loading = true` (L149) / `_loading = false` (L165) and the early-return in _on_mood_changed (L258). Setting .value still fires value_changed; the latch is the only protection.
- **Remediation**: Replace L160 with `_mood_slider.set_value_no_signal(clampf(saved_mood, 0.0, 1.0))` (Godot 4.2+ Range API); the _loading latch can then be dropped or kept as belt-and-braces.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-088 [MEDIUM] [OPEN] _refresh_badges/BadgeManager.get_unlocked_badges called in _build_ui before _load_state

- **Audit ref**: 4.1.7-L271
- **Location**: `v1/scripts/ui/profile_hud_panel.gd:271`
- **Execution phase**: E
- **Current evidence**: Unchanged: _ready() (L32-35) calls `_build_ui()` then `_load_state()`; _build_ui() calls `_refresh_badges()` at L92 before account state is loaded; L271 `var unlocked_rows: Array = BadgeManager.get_unlocked_badges()` can return empty/guest data. Only badge_unlocked (L93) triggers later refresh; no load_completed hook.
- **Remediation**: Move the `_refresh_badges()` call from _build_ui() (L92) into _load_state() after account data is available, and additionally connect `SignalBus.load_completed` to `_refresh_badges` (with matching disconnect in _exit_tree).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-089 [MEDIUM] [OPEN] Queue drop-oldest silently relies on sync_queue backup that itself drops

- **Audit ref**: 4.5.2-L42-51
- **Location**: `v1/scripts/utils/supabase_http.gd:45`
- **Execution phase**: E
- **Current evidence**: L42-52 unchanged: `if _queue.size() >= MAX_QUEUE_SIZE:` → comment L43-44 "L'utente avra` comunque il SQLite sync_queue come backup persistente per retry" → `var dropped: Dictionary = _queue.pop_front()` + `push_warning(...)`. No signal is emitted on drop; SignalBus still has no `sync_payload_dropped`/`payload_dropped` signal (grep confirms), and `supabase_client.gd:434-436` still does `if json.parse(payload_str) != OK: LocalDatabase.clear_sync_item(queue_id); continue` — the backup path still silently discards corrupt payloads, and `retry_count` remains read-only (L426-428 only reads it).
- **Remediation**: Add `signal sync_payload_dropped(request_id: String)` to SignalBus and emit it next to the `push_warning` at L46-51; before dropping, verify the payload's rid corresponds to a persisted sync_queue row (or re-enqueue it via LocalDatabase.queue_sync). Separately wire increment of `retry_count` on failure in `_handle_sync_response` so the claimed backup/retry actually exists.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-090 [MEDIUM] [OPEN] JSON parse failure returns raw text as body, breaking Dictionary contract

- **Audit ref**: 4.5.3-L109-116
- **Location**: `v1/scripts/utils/supabase_http.gd:116`
- **Execution phase**: E
- **Current evidence**: L110-116 unchanged: `var parsed: Variant = null` … `if json.parse(body_text) == OK:\n\tparsed = json.data\nelse:\n\tparsed = body_text`. A String body still flows into `supabase_client.gd:390-394` `_is_relation_error(body)` (`if body is Dictionary` → false) and into `_handle_auth_response` L338-341, which then reports only generic "Auth failed (HTTP %d)".
- **Remediation**: In the else branch set `parsed = null` and enrich the emitted dict's `error` field, e.g. `"error": "non-JSON body: %s" % body_text.left(100)` (merge with the existing HTTP-status error at L123). Keep the empty-body/204 path as `null`. Downstream code already handles `body == null`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-091 [MEDIUM] [OPEN] Pure push model — no cloud-to-local pull sync; README still claims cross-device

- **Audit ref**: 4.13.5
- **Location**: `v1/scripts/utils/supabase_mapper.gd:115`
- **Execution phase**: E
- **Current evidence**: Aggravated since audit framing: cloud→local mappers were deleted outright — supabase_mapper.gd:115-118: `# Cloud -> Local mappers rimossi (B-022): la pull sync non è mai stata / # implementata...` (commit 1f46188). `fetch_table` has zero call sites (grep: only its definition at supabase_client.gd:208). _push_local_state (supabase_client.gd:446-502) pushes profiles/user_currency/user_settings/music_preferences/room_decorations only. Root README.md:5 still claims: `Account Supabase opzionale per sync cross-device.`
- **Remediation**: Either (a) implement pull-on-start_sync: call fetch_table for the 5 pushed tables scoped `user_id=eq.<uid>`, reintroduce cloud_to_local mappers (git history of supabase_mapper.gd has the prior pattern) with last-write-wins on `updated_at`; or (b) minimally, amend README.md:5 (and any landing copy) to describe one-way cloud backup, removing the cross-device claim.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-092 [LOW] [OPEN] AuthManager._set_state accepts any int, no enum-range guard

- **Audit ref**: 4.8.2-authmanager-set-state
- **Location**: `v1/scripts/autoload/auth_manager.gd:176`
- **Execution phase**: E
- **Current evidence**: L176-177 unchanged: `func _set_state(new_state: int, account: Dictionary) -> void:\n\tauth_state = new_state` — parameter typed `int` not `AuthState`, no `assert(new_state in AuthState.values())`, then `SignalBus.auth_state_changed.emit(new_state)` at L185 propagates any value.
- **Remediation**: Change signature to `func _set_state(new_state: AuthState, account: Dictionary) -> void:` (all 6 internal call sites already pass enum members: L36, L44, L65, L126, L168, L173) and add `assert(new_state in AuthState.values())` as a debug-build tripwire.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-093 [LOW] [PARTIAL] Index coverage: 8 FK indexes exist (finding was stale at audit time); only display_name index missing

- **Audit ref**: 4.7.4
- **Location**: `v1/scripts/autoload/database/schema.gd:167`
- **Execution phase**: E
- **Current evidence**: schema.gd:166-174 creates 8 indexes: `CREATE INDEX IF NOT EXISTS idx_characters_account ...` through `idx_badges_account ON badges_unlocked(account_id)` — these were added by commit e444034 (2026-04-21), i.e. BEFORE the 2026-04-23 audit, so the audit claim 'no indexes beyond PRIMARY KEYs' was already inaccurate. `accounts.auth_uid` is covered by an implicit SQLite unique index via `auth_uid TEXT UNIQUE` (schema.gd:16), so get_account_by_auth_uid does not table-scan. Remaining gap: no index on accounts(display_name), so get_account_by_username (accounts_repo.gd:52-63) scans.
- **Remediation**: Only remaining action from the original recommendation: add `DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_accounts_display_name ON accounts(display_name);")` after schema.gd:174. Negligible at current scale (1-10 accounts) — original DEFERRED disposition remains reasonable.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-094 [LOW] [OPEN] Device-specific paths still logged in plaintext (user_data_dir, blocked audio paths)

- **Audit ref**: 4.9.3-LOW
- **Location**: `v1/scripts/autoload/local_database.gd:79`
- **Execution phase**: E
- **Current evidence**: local_database.gd:76-80 error context includes `"user_data_dir": OS.get_user_data_dir()` — an absolute device path (contains OS username) written to a log the user may share. Also audio_manager.gd:161 logs arbitrary non-res:// paths verbatim (`AppLogger.error("AudioManager", "Blocked non-resource audio path", {"path": path})`). No path sanitization exists in `_redact_context`.
- **Remediation**: Drop `user_data_dir` from the local_database.gd:79 context (OS name + `user://` path already identify the location class), or log only its hash. For audio_manager.gd:161 log `path.get_file()` (basename) instead of the full path. Optionally add a logger-level scrub replacing `OS.get_user_data_dir()` prefix with `<user_data>` in string context values.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-095 [LOW] [OPEN] _is_saving latch does not chain with _save_dirty for dirty-during-save

- **Audit ref**: 4.8.2-savemanager-latch
- **Location**: `v1/scripts/autoload/save_manager.gd:111`
- **Execution phase**: E
- **Current evidence**: L110-113 unchanged: `func _on_auto_save() -> void:\n\tif _save_dirty and not _is_saving:\n\t\t_save_dirty = false\n\t\tsave_game()`. `save_game` (L116-180) clears `_is_saving` at L179 and emits `save_completed` at L180, but any `_mark_dirty` triggered re-entrantly during the save (e.g. from a `save_completed` listener chain or `_save_to_sqlite` side effects) waits up to a full AUTO_SAVE_INTERVAL; window-close edge (4.1.2 L533-535 cross-ref) still unhandled here.
- **Remediation**: At the end of `save_game()` after `_is_saving = false` (L179), add `if _save_dirty: call_deferred("save_game")` (clearing the flag first); ensure the WM_CLOSE_REQUEST path performs a final synchronous save when `_save_dirty` is set.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-096 [LOW] [OPEN] Integrity-key hex validation is length-only, no charset check

- **Audit ref**: 4.1.2-L483
- **Location**: `v1/scripts/autoload/save_manager.gd:483`
- **Execution phase**: E
- **Current evidence**: L483-484: `if hex.length() == 64: return hex.hex_decode()` — non-hex characters pass the length gate and `hex_decode()` yields garbage bytes, making every subsequent HMAC fail silently.
- **Remediation**: Tighten to `if hex.length() == 64 and hex.is_valid_hex_number(false):` (or check `hex.hex_decode().size() == 32` before returning); on invalid content, log and fall through to key regeneration deliberately rather than accidentally.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-097 [LOW] [OPEN] Integrity-key hex validation is length-only

- **Audit ref**: 4.4.7-L483
- **Location**: `v1/scripts/autoload/save_manager.gd:483`
- **Execution phase**: E
- **Current evidence**: Line 483: `if hex.length() == 64:` then `return hex.hex_decode()`. No character-set check — 64 bytes of garbage passes and hex_decode yields a wrong/truncated key, silently changing the HMAC key. Unchanged.
- **Remediation**: Extend the guard: `if hex.length() == 64 and hex.is_valid_hex_number(false):`. On failure, treat as the 'read failed' path from 4.4.7-L477 (loud error), not as first-run regeneration.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-098 [LOW] [OPEN] WM_CLOSE_REQUEST does not hold the app open until save I/O completes

- **Audit ref**: 4.1.2-L533-async
- **Location**: `v1/scripts/autoload/save_manager.gd:534`
- **Execution phase**: E
- **Current evidence**: L533-535 calls `save_game()` synchronously from _notification with no quit gating. Grep across v1/project.godot and v1/scripts/ finds zero occurrences of `auto_accept_quit` (exit 1), so the OS default auto-quit can tear down the process while writes are in flight.
- **Remediation**: In `_ready()` (L85) call `get_tree().set_auto_accept_quit(false)`; in `_notification` on WM_CLOSE_REQUEST run save_game and call `get_tree().quit()` only after the save path completes (or after the save_completed/save_failed signal fires).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-099 [LOW] [OPEN] Window-close during an active autosave is skipped; last dirty state lost

- **Audit ref**: 4.1.2-L533-reentry
- **Location**: `v1/scripts/autoload/save_manager.gd:535`
- **Execution phase**: E
- **Current evidence**: L533-535: `if what == NOTIFICATION_WM_CLOSE_REQUEST: save_game()` combined with L117-119: `if _is_saving: AppLogger.warn("SaveManager", "Salvataggio gia' in corso, skip"); return` — a close arriving mid-autosave early-returns without persisting the latest edits. No flush-on-completion flag exists.
- **Remediation**: In the L117 early-return path set a `_flush_requested := true` flag (or `_save_dirty = true`); at the end of save_game (after L180) re-invoke save_game once if the flag is set.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-100 [LOW] [OPEN] JWT expiry anchored to mutable system clock

- **Audit ref**: 4.1.1-L181
- **Location**: `v1/scripts/autoload/supabase_client.gd:181`
- **Execution phase**: E
- **Current evidence**: L181: `_jwt_expires_at = Time.get_unix_time_from_system() + float(expires_in)` — unchanged; compared against system clock again at L246.
- **Remediation**: Anchor on monotonic time: store `_jwt_expires_at_ticks = Time.get_ticks_msec() + expires_in * 1000` and compare with Time.get_ticks_msec() in _ensure_jwt (L246).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-101 [LOW] [OPEN] JWT expiry deadline computed from system wall-clock

- **Audit ref**: 4.4.6-L181
- **Location**: `v1/scripts/autoload/supabase_client.gd:181`
- **Execution phase**: E
- **Current evidence**: Line 181 in _apply_auth_response(): `_jwt_expires_at = Time.get_unix_time_from_system() + float(expires_in)`. Unchanged — clock skew or user clock edits make the client refresh too late (401s) or too eagerly.
- **Remediation**: Track expiry monotonically: `_jwt_expires_at_ms = Time.get_ticks_msec() + expires_in * 1000` and compare with ticks at the refresh check. Persisted expires_at in the session cfg can stay wall-clock but treat it as a hint and refresh-on-restore (which _load_session already does at line 158).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-102 [LOW] [OPEN] No response-schema validation on 2xx auth bodies

- **Audit ref**: 4.10.1
- **Location**: `v1/scripts/autoload/supabase_client.gd:334`
- **Execution phase**: E
- **Current evidence**: L334-335: `if status >= 200 and status < 300 and body is Dictionary:` / `_apply_auth_response(body)` — an error-shaped 200 body still flows into _apply_auth_response, yields empty _jwt_token/user_id, and lands in the ERROR branch at L199-202 with a misleading log trail.
- **Remediation**: Validate required keys before applying: `if not (body.has("access_token") and (body.has("user") or body.has("id"))): AppLogger.error("SupabaseClient", "auth_response_malformed", {"rid": rid}); SignalBus.cloud_auth_completed.emit(false); return`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-103 [LOW] [OPEN] _is_relation_error uses fragile substring match instead of PG error code

- **Audit ref**: 4.1.1-L389
- **Location**: `v1/scripts/autoload/supabase_client.gd:393`
- **Execution phase**: E
- **Current evidence**: L390-394: `var msg: String = body.get("message", "")` / `return "relation" in msg and "does not exist" in msg` — still substring-based.
- **Remediation**: Match PostgreSQL undefined_table code instead: `return body is Dictionary and body.get("code", "") == "42P01"`.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-104 [LOW] [OPEN] Arrow bob accumulates clock-derived offsets into position.y — anchor drift

- **Audit ref**: 4.2-L300-arrow-drift
- **Location**: `v1/scripts/menu/tutorial_manager.gd:300`
- **Execution phase**: E
- **Current evidence**: L299-300 unchanged: `if _arrow.visible:\n  _arrow.position.y += sin(Time.get_ticks_msec() / 300.0) * 0.3`. The `+=` integrates the sine per frame instead of setting an absolute offset, so amplitude and phase depend on frame rate, and floating-point accumulation walks the arrow off the anchor set by _show_arrow L308 during long steps. Related: `ARROW_ANIMATE_SPEED := 2.0` (L9) is declared and never used.
- **Remediation**: In _show_arrow store `_arrow_base_y = pos.y - 30`, then in _process write absolute: `_arrow.position.y = _arrow_base_y + sin(Time.get_ticks_msec() / 300.0) * 4.0`. This removes the frame-rate dependence and drift; wire in or delete the unused ARROW_ANIMATE_SPEED constant.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-105 [INFO] [OPEN] Section 4.9 roll-up: all 5 rows re-verified, zero remediated since 2026-04-23

- **Audit ref**: 4.9.6
- **Location**: `v1/scripts/autoload/logger.gd:97`
- **Execution phase**: E
- **Current evidence**: Roll-up table rows re-checked against working tree: bindings-bypass HIGH (logger.gd:97 + db_helpers.gd:44) OPEN; storm-overflow MEDIUM (logger.gd:133) OPEN; no-metrics MEDIUM (performance_manager.gd) OPEN; request-id LOW (supabase_client.gd:254-270) DEFERRED; path-leak LOW (local_database.gd:79) OPEN. Uncommitted working-tree edits touch only project.godot/main.tscn/cozy_theme.tres — none of the audited files.
- **Remediation**: No standalone fix — closes automatically when items 4.9.2 through 4.9.5 and 4.1.12-L44 are resolved. Suggested order: array-redaction + bindings call-site first (HIGH, data leak), then error-buffer, then metrics, then correlation header.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-106 [INFO] [OPEN] Log structure sound (JSONL + rotation); session_id 16-bit entropy concern unchanged

- **Audit ref**: 4.9.1
- **Location**: `v1/scripts/autoload/logger.gd:222`
- **Execution phase**: E
- **Current evidence**: Structure unchanged: JSONL entries (L119-129) with timestamp/level/session_id/source/message/context to rotating `user://logs/` files (5 MB x 5, L12-13). The one concern — session_id entropy — is the same code as 4.1.3-L219: `"%08x-%04x-%04x"` at L222-228 keeps only 16 random bits. Report itself judged it "fine for forensics on a single install".
- **Remediation**: Resolved automatically by the 4.1.3-L219 fix (widen to %08x / full 32-bit mask). No other action needed for this section.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-107 [INFO] [OPEN] Migration mutates the save dict in place; partial migration is not rolled back

- **Audit ref**: 4.13.3-non-transactional
- **Location**: `v1/scripts/autoload/save_manager.gd:332`
- **Execution phase**: E
- **Current evidence**: `_migrate_save_data(data: Dictionary)` L332-416 erases keys (L371-378) and rewrites sections directly on the caller's dict. A crash mid-migration leaves a half-migrated dict; safe today only because all steps are erase/assign (idempotent), as the report noted.
- **Remediation**: Operate on `var work := data.duplicate(true)` and return `work` only after the full chain completes; on any step failure return the original `data` untouched and log, so re-entry always starts from a consistent version.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-108 [INFO] [OPEN] Migration chain is a flat if-ladder; adding v6 requires manual new block

- **Audit ref**: 4.13.3-flat-ladder
- **Location**: `v1/scripts/autoload/save_manager.gd:355`
- **Execution phase**: E
- **Current evidence**: L355-414: sequential `if version == "1.0.0": ... if version == "2.0.0": ... if version == "3.0.0": ... if version == "4.0.0": ...` blocks each mutating `data` and reassigning `version`. Unchanged since audit; a forgotten block silently strands old saves at an intermediate version.
- **Remediation**: Replace the ladder with an ordered `const MIGRATIONS: Array = [{from, to, Callable}]` walked in a loop until `version == SAVE_VERSION`, with an assertion that the chain reaches SAVE_VERSION so a missing step fails loudly in dev.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-109 [INFO] [OPEN] Contract-level cross-reference table — all 6 referenced findings still OPEN

- **Audit ref**: 4.10.5
- **Location**: `v1/scripts/autoload/supabase_client.gd:208`
- **Execution phase**: E
- **Current evidence**: Cross-refs verified individually in current code: 4.1.1-L208 (sentinel, L208-237) OPEN; 4.1.1-L297 (401 drop, L297-299) OPEN; 4.1.1-L300 (404 swallow, L300-311) OPEN; 4.1.1-L440 (`id=eq.` empty, L441) OPEN; 4.1.1-L494 (`user_id=eq.`, L494) OPEN; 4.5.3 (supabase_http.gd:109-116 returns raw text body on JSON parse failure — `parsed = body_text` at :116) OPEN.
- **Remediation**: No separate fix — remediate via the individual 4.1.1 entries plus 4.5.3 (emit `{"parse_error": true, "raw": body_text}` instead of a bare String body in supabase_http.gd:116).
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-110 [INFO] [OPEN] Request-ID correlation — pointer to 4.9.2, rid scheme unchanged

- **Audit ref**: 4.10.4
- **Location**: `v1/scripts/autoload/supabase_client.gd:533`
- **Execution phase**: E
- **Current evidence**: Section is a cross-reference only ('already covered in 4.9.2'). Current rid scheme unchanged: `_next_rid` at L533-535 returns `"%s_%d"`. No remediation landed; note the rid-mismatch defect recorded under 4.1.1-L501 makes correlation actively broken for sync pushes.
- **Remediation**: Resolve via the 4.1.1-L501 fix (single rid per logical request, returned rid used for tracking); then rids double as correlation IDs in logs.
- **Acceptance**: code change applied at the location above; deep tests green; gdlint + gdformat clean on the touched file; behavior verified per remediation text.

### V-111 [HIGH] [FIXED] preflight.sh speech-file GO/NO-GO gate removed

- **Audit ref**: 4.12.1
- **Location**: `scripts/preflight.sh:150`
- **Execution phase**: -
- **Current evidence**: Section [8] now contains only: line 149 `echo "[8] Presentation artifacts"`, line 150 `check "pptx presentazione presente" "test -f Mini-Cozy-Room-Presentazione-Progetto.pptx"`, line 151 `echo ""`. The four speech checks (former L151-154 `test -f v1/docs/speech_*.md`) are gone; grep 'speech' in preflight.sh returns nothing. The retained gate passes: Mini-Cozy-Room-Presentazione-Progetto.pptx exists at repo root (33MB), and v1/docs/ now contains only diagrams/ (speech files deleted as planned).
- **Remediation**: No action for this finding. Adjacent note (do not fix unasked): preflight line 58 `check "Git clean working tree" ...` will currently report NO-GO because of the uncommitted theme/scene/addon-binary changes and untracked _render/, finale.original.pptx — expected until Phase J git hygiene lands.
- **Acceptance**: none required — status FIXED (historical record kept for traceability).

### V-112 [LOW] [DEFERRED] Python CI deps installed inline; no requirements.txt / pyproject.toml

- **Audit ref**: 4.11.2
- **Location**: `.github/workflows/ci.yml:45`
- **Execution phase**: -
- **Current evidence**: ci.yml:45 `run: pip install "gdtoolkit>=4,<5"` and ci.yml:190 `run: pip install "Pillow>=10,<12"` — byte-identical to audit time. `ls /data/Projectwork/requirements.txt pyproject.toml` → No such file. Report marked this DEFERRED and nothing changed.
- **Remediation**: If ever promoted: commit a root requirements-ci.txt with `gdtoolkit>=4,<5` and `Pillow>=10,<12` (or exact pins + hashes via pip-tools), replace both inline installs with `pip install -r requirements-ci.txt`, and mention it in README dev-setup.
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-113 [LOW] [FIXED] All 8 comment/docstring refs to deleted docs purged

- **Audit ref**: 4.12.2
- **Location**: `ci/validate_no_keystore.py:86`
- **Execution phase**: -
- **Current evidence**: grep for ANDROID_SIGNING|BUILD_RELEASE_PLAN|GUIDA_ALEX|speech|DEEP_READ across all 8 files returns zero matches. Current text: ci/validate_no_keystore.py:86 `print("     See CHANGELOG.md Security section for keystore handling.")`; v1/export_credentials.cfg.example:16-18 references scripts/generate_keystores.sh, CHANGELOG.md (sezione Security), .github/workflows/build.yml; scripts/generate_keystores.sh:4-5 `# Per il flusso completo vedi .github/workflows/build.yml ... e CHANGELOG.md (sezione Security).`; scripts/ci/extract_changelog.py:8 `Invoked by .github/workflows/release.yml when a tag v*.*.* is pushed.`; ci/extract_palette.py and ci/scaffold_character.py docstrings are self-explaining; ci/validate_pixelart_deliverables.py:2 `"""Validate pixel-art deliverables for the Relax Room character pipeline.`; v1/tests/integration/test_catalogs.gd:18 `# AND the relevant READMEs + CHANGELOG.`
- **Remediation**: No action required — remediation matches the audit's prescribed rewrite for every one of the 8 sites.
- **Acceptance**: none required — status FIXED (historical record kept for traceability).

### V-114 [LOW] [OBSOLETE] Team HTML pages: no speech_*.md refs, no .md links — dead-link risk never materialized

- **Audit ref**: 4.12.4
- **Location**: `docs/team/renan.html:83`
- **Execution phase**: -
- **Current evidence**: grep 'speech_' across docs/team/*.html → zero matches; grep 'href=.*\.md' → zero matches. What the audit's rg sweep flagged are plain-prose mentions of other deleted doc names inside content lists, e.g. renan.html:83 `<li>Definizione 9 pattern codificati (P-01..P-09) documentati in <code>CONSOLIDATED_PROJECT_REPORT.md</code></li>`, renan.html:157-159 (CONSOLIDATED_PROJECT_REPORT.md, DEEP_READ_REGISTRY_2026-04-16.md, GUIDA_*.md), cristian.html:147-148 (GUIDA_CRISTIAN_CICD.md, GUIDA_ALEX_PIXEL_ART.md), elia.html:163 (GUIDA_ELIA_DATABASE.md) — all inside <code>/<strong> text, no hyperlinks. Exactly the audit's 'content survives inline / moot' branch: the landing site never shipped .md files, so nothing can 404.
- **Remediation**: No functional action needed. Optional cosmetic polish (flagging only, per scope discipline): the pages present filenames of now-deleted docs as if current; if the team pages get another content pass, rephrase to past tense ('documentato nel report tecnico consolidato, ora in git history') so visitors aren't pointed at artifacts that no longer exist in the tree.
- **Acceptance**: none required — status OBSOLETE (historical record kept for traceability).

### V-115 [LOW] [FIXED] README cross-refs to doomed docs removed; guide README is planned stub

- **Audit ref**: 4.12.3
- **Location**: `v1/guide/README.md:5`
- **Execution phase**: -
- **Current evidence**: grep for CONSOLIDATED_PROJECT_REPORT|DEEP_READ_REGISTRY|GUIDA_*|BUILD_RELEASE_PLAN|ANDROID_SIGNING|TASKS_CLOSED|speech_ across all 12 listed READMEs matches only v1/guide/README.md:5-6, which is the intentional tombstone: '# v1/guide — stub ... Le guide operative per team (GUIDA_ALEX_PIXEL_ART, GUIDA_CRISTIAN_CICD, GUIDA_ELIA_DATABASE, SETUP_AMBIENTE) sono state rimosse dal tree...' with git-history recovery commands — the 'will become stub' outcome the audit planned. Root README's document table (L57-66) links only surviving files (v1/*/README.md, supabase/README.md, CHANGELOG.md, AUDIT_REPORT_2026-04-23.md); former L67-68 refs to CONSOLIDATED_PROJECT_REPORT.md / DEEP_READ_REGISTRY are gone. The doomed docs themselves are deleted (root has only README/CHANGELOG/AUDIT .md; v1/docs/ contains only diagrams/).
- **Remediation**: No action required. The prose mentions inside the guide stub are deliberate pointers into git history, not dead links.
- **Acceptance**: none required — status FIXED (historical record kept for traceability).

### V-116 [LOW] [DEFERRED] delete_account is soft-delete only, no cascade or cloud purge

- **Audit ref**: 4.4.5
- **Location**: `v1/scripts/autoload/auth_manager.gd:167`
- **Execution phase**: -
- **Current evidence**: Lines 153-169 unchanged: `LocalDatabase.soft_delete_account(current_account_id)` at 167. AccountsRepo.soft_delete_account (accounts_repo.gd:86-98) sets deleted_at AND blanks display_name/password_hash (slightly more purge than the audit stated), but child rows (characters, badges, rooms, placed_decorations) survive and no Supabase deletion request exists. A hard `AccountsRepo.delete_account` (accounts_repo.gd:82-83, real DELETE) exists but is never called by AuthManager. Audit marked DEFERRED for v1.0; nothing changed.
- **Remediation**: Keep DEFERRED for offline v1.0. For cloud-enabled release: wire AccountsRepo.delete_account plus cascading deletes on child tables (or add ON DELETE CASCADE FKs in schema.gd) behind a `hard: bool` param on AuthManager.delete_account, and add SupabaseClient.request_account_deletion for pushed rows.
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-117 [LOW] [ACCEPTED] Hardcoded _SESSION_SALT — accepted threat model, unchanged

- **Audit ref**: 4.1.1-L26
- **Location**: `v1/scripts/autoload/supabase_client.gd:26`
- **Execution phase**: -
- **Current evidence**: L26: `const _SESSION_SALT := "relax-room-2026-session-v1"` with threat-model comment at L21-25 ("non protegge da attacker che legge memoria... blocca grep banale"). v1/README.md:325 documents device-local encrypted session. Audit already marked ACCEPTED; nothing changed.
- **Remediation**: None required (accepted). Optional hardening: mix in a per-install random component stored alongside the cfg to raise the bar slightly.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

### V-118 [LOW] [ACCEPTED] Session-key derivation: hardcoded salt + public user_data_dir

- **Audit ref**: 4.4.6-L26
- **Location**: `v1/scripts/autoload/supabase_client.gd:26`
- **Execution phase**: -
- **Current evidence**: Line 26: `const _SESSION_SALT := "relax-room-2026-session-v1"` with comment block (21-25) explicitly documenting the accepted threat model (blocks trivial grep + cross-device copy, not process-memory reads). Unchanged; audit accepted this.
- **Remediation**: No action for current threat model. If the bar rises, use OS keychain via a GDExtension or per-install random salt stored with restrictive permissions.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

### V-119 [LOW] [DEFERRED] Client rid still log-local — no x-client-request-id header sent to Supabase

- **Audit ref**: 4.9.2
- **Location**: `v1/scripts/autoload/supabase_client.gd:254`
- **Execution phase**: -
- **Current evidence**: `_auth_headers()` (L254-260) returns only `apikey` + `Content-Type`; `_bearer_headers()` (L263-270) adds only `Authorization: Bearer`. Per-request `rid` from `_next_rid(...)` (e.g. L93, L214, L226) is passed to `_http.request(...)` for local routing/logging only. No correlation header exists. Report already marked this DEFERRED; nothing changed.
- **Remediation**: When picking it up: give `_auth_headers`/`_bearer_headers` an optional `rid: String = ""` parameter and append `"x-client-request-id: " + rid` when non-empty; pass the already-generated rid at each call site (rid is created before the header call in every flow, so only argument plumbing is needed).
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-120 [LOW] [DEFERRED] No per-endpoint circuit breaker; 429 backoff is global only

- **Audit ref**: 4.5.4
- **Location**: `v1/scripts/autoload/supabase_client.gd:317`
- **Execution phase**: -
- **Current evidence**: L312-322: 429 branch sets global `_retry_attempts` / `_backoff_until_ms` (checked in _on_sync_timer L524). No `_endpoint_failure_count` dictionary exists; a persistently-500ing endpoint is retried every cycle. Audit marked DEFERRED; unchanged.
- **Remediation**: When picked up: add `_endpoint_failure_count: Dictionary` keyed by table/endpoint; increment on non-2xx in _on_request_completed; if >10 failures in 5 min, set a per-endpoint skip-until timestamp consulted in _push_local_state/_process_sync_queue.
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-121 [LOW] [DEFERRED] No health check before start_sync; offline discovered via 15 s timeout

- **Audit ref**: 4.5.5
- **Location**: `v1/scripts/autoload/supabase_client.gd:409`
- **Execution phase**: -
- **Current evidence**: L409-419: start_sync checks only `_is_syncing`/`is_online()` then goes straight to `_process_sync_queue()` + `_push_local_state()`. Offline detection still happens post-hoc at the status==0 branch (L292-296) after supabase_http.gd's 15 s REQUEST_TIMEOUT. Audit marked DEFERRED; unchanged.
- **Remediation**: When picked up: issue a cheap probe (GET `_base_url() + "/rest/v1/"` with _bearer_headers, rid `health_check`) at the top of start_sync; only proceed to push on 2xx/4xx, bail with _finish_sync(false) on status 0/5xx.
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-122 [LOW] [FIXED] Toast layer name "n" renamed to "ToastManager"

- **Audit ref**: 4.3-toast-layer-name
- **Location**: `v1/scripts/main.gd:58`
- **Execution phase**: -
- **Current evidence**: main.gd:56-59 now reads: `var toast_layer := CanvasLayer.new()` / `toast_layer.set_script(TOAST_SCRIPT)` / `toast_layer.name = "ToastManager"` / `add_child(toast_layer)`. No occurrence of `name = "n"` remains in the file; descriptive identifier restored.
- **Remediation**: None required. If any name-based lookup elsewhere still expects the old "n" node name, verify those call sites (audit 4.1.6 brittle _find_node_by_name lookups), but the rename itself is complete.
- **Acceptance**: none required — status FIXED (historical record kept for traceability).

### V-123 [INFO] [DEFERRED] File-size bloat TODO B-033 (split auth/sync/session) still pending

- **Audit ref**: 4.1.1-B033
- **Location**: `v1/scripts/autoload/supabase_client.gd:7`
- **Execution phase**: -
- **Current evidence**: L1: `# gdlint: disable=max-file-lines`; L7-8: `## TODO B-033 post-demo: split auth + sync + session persistence in moduli / ## dedicati per rientrare sotto 500 righe.` File is still 547 lines.
- **Remediation**: Execute the planned split: extract SupabaseAuth (sign_up/sign_in/refresh/session persistence, ~L87-203) and SupabaseSyncEngine (~L406-528) into scripts/autoload/supabase/ modules with the client as facade, mirroring the database/ repo split pattern from commit e444034.
- **Acceptance**: none required — status DEFERRED (historical record kept for traceability).

### V-124 [INFO] [ACCEPTED] Idempotency review (no defect) — merge-duplicates upsert still in place

- **Audit ref**: 4.10.2
- **Location**: `v1/scripts/autoload/supabase_client.gd:224`
- **Execution phase**: -
- **Current evidence**: L223-224: `var headers := _bearer_headers()` / `headers.append("Prefer: resolution=merge-duplicates")` — upsert remains record-level idempotent; DELETE by `id=eq.<x>` (L234) remains idempotent. Audit recorded this as a strength; still accurate.
- **Remediation**: No action needed.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

### V-125 [INFO] [ACCEPTED] Retry-safety review (no defect) — refresh-401 loop still terminates in one hop

- **Audit ref**: 4.10.3
- **Location**: `v1/scripts/autoload/supabase_client.gd:354`
- **Execution phase**: -
- **Current evidence**: L354-357: `if rid.contains("refresh"):` / `connection_state = ConnectionState.OFFLINE` / `SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)` — stale-refresh 401 routes to OFFLINE, no infinite loop. Audit's assessment still holds.
- **Remediation**: No action needed.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

### V-126 [INFO] [ACCEPTED] State-machine inventory still accurate (one method-name drift)

- **Audit ref**: 4.8.1-inventory
- **Location**: `v1/scripts/rooms/pet_controller.gd:196`
- **Execution phase**: -
- **Current evidence**: All four inventoried machines exist unchanged: `AuthManager.AuthState` (auth_manager.gd:5, funnel `_set_state` L176), `SupabaseClient.ConnectionState` (supabase_client.gd:11, implicit multi-site assignment), `PetController.State` (pet_controller.gd:5) with funnel `func _set_state(new_state: State) -> void:` at L196-200 — the report calls it `_change_state`, actual name is `_set_state` — and `Logger.Level` (logger.gd:9). No machine gained transition-rejection logic since the audit.
- **Remediation**: No action required; inventory row for PetController should be corrected to `_set_state` when the report is refreshed.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

### V-127 [INFO] [ACCEPTED] PetController allows any→any state transition (documented as intentional)

- **Audit ref**: 4.8.2-petcontroller-any-any
- **Location**: `v1/scripts/rooms/pet_controller.gd:196`
- **Execution phase**: -
- **Current evidence**: L196-200: `func _set_state(new_state: State) -> void:\n\tif _state == State.SLEEP and new_state != State.SLEEP:\n\t\t...\n\t_state = new_state\n\t_state_timer = 0.0` — no rejection matrix; SLEEP→WILD via toggle at L53-55 still works. Report classified this INFO/intentional; nothing changed.
- **Remediation**: None required (intentional). Param is now typed `State`, which already gives editor-level checking the audit didn't credit.
- **Acceptance**: none required — status ACCEPTED (historical record kept for traceability).

---

# PART III — FRESH GAP REGISTER (workflow hunt, 2026-07-20)

Totals: HIGH 15 · MEDIUM 25 · LOW 17 · INFO 13. Total: 70.

### G-001 [HIGH] (assets_gap/assets/ui-mobile) virtual_joystick.tscn references two missing textures — scene cannot load on mobile/web exports

- **Location**: `/data/Projectwork/v1/scenes/ui/virtual_joystick.tscn:4`
- **Execution phase**: G
- **Evidence**: scenes/ui/virtual_joystick.tscn:4-5 declares ext_resources `res://assets/menu/ui/sprite_pad_base.png` and `res://assets/menu/ui/sprite_pad_lever.png`. Neither file exists — v1/assets/menu/ui/ contains only ui_stress_bar.png. scripts/main.gd:72-77 loads this scene only when `OS.has_feature("mobile") or OS.has_feature("web")`; on the Android APK (which the repo builds — see 'local APK build script' commit 176a77a) the PackedScene load fails, `joy_scene` is null, and the joystick is silently absent, leaving mobile with no movement input. Desktop is unaffected. Aseprite source exists at v1/assets/menu/aseprite_menu/sprite_pad.aseprite (in-project art, freely editable).
- **Action**: Re-export sprite_pad_base.png and sprite_pad_lever.png from assets/menu/aseprite_menu/sprite_pad.aseprite into v1/assets/menu/ui/, matching the uid slots in virtual_joystick.tscn (uid://dss01ljguvr3s, uid://bkpqg1ekq7uuj) or letting Godot regenerate them; add a mobile smoke test that instantiates the scene.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-002 [HIGH] (catalogs_data/tracks.json / audio) Mood 'stormy' emitted by AudioManager has zero matching tracks — storm music never plays

- **Location**: `v1/scripts/autoload/audio_manager.gd:404`
- **Execution phase**: F
- **Evidence**: audio_manager.gd:400-404 (crossfade_to_mood_track): `if clamped < Constants.MOOD_STORMY_THRESHOLD: ... SignalBus.mood_changed.emit("stormy")`. The handler _on_mood_changed (audio_manager.gd:201-218) filters tracks by `mood in moods` and returns on empty candidates: `if candidates.is_empty(): return`. tracks.json carries only moods ["calm","neutral"] (rain_loop) and ["tense"] (rain_thunder) — no track has "stormy", so crossing the stormy threshold is a silent no-op and the thunderstorm track is unreachable from the mood slider. The comment at audio_manager.gd:390 states the intent was to 'propaga mood_changed("tense") per riusare la track selection esistente' — the code emits "stormy" instead, contradicting its own design note. ("neutral" on rain_loop is valid: StressManager emits "neutral" via mood_changed, stress_manager.gd:10,114.)
- **Action**: Either add "stormy" to rain_thunder's moods array in v1/data/tracks.json:17 (one-line data fix, matches the track's content) or change audio_manager.gd:403-404 to emit "tense" per the documented intent. Add a regression test asserting every mood string emitted in code has >=1 catalog track.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-003 [HIGH] (ci_export_health/release-pipeline/android-signing) build.yml keystore injection is a no-op: export_presets.cfg has no keystore/* keys

- **Location**: `.github/workflows/build.yml:194`
- **Execution phase**: I
- **Evidence**: Tag-release path patches the Android preset with: `sed -i 's|keystore/release=""|keystore/release="res://certs/release.keystore"|' export_presets.cfg` (build.yml:194-196, also release_user/release_password). But v1/export_presets.cfg [preset.2.options] (lines 94-284) contains NO `keystore/release`, `keystore/release_user`, or `keystore/release_password` keys at all — grep for 'keystore' matches only the comment at lines 113-114. All three seds silently match nothing, while build.yml:193 flips `package/signed=true`. Result on any v*.*.* tag: signed=true with no release keystore configured → Godot Android release export fails. The verify grep at build.yml:198 uses `|| echo "(grep: no match)"` and the export step has `continue-on-error: true` (build.yml:262), so the break is invisible. A signed release APK can never be produced by this pipeline as-is.
- **Action**: Add the three empty keys to v1/export_presets.cfg [preset.2.options] (`keystore/release=""`, `keystore/release_user=""`, `keystore/release_password=""`) so the seds match, or replace the seds with `--export-release` env-based signing (GODOT_ANDROID_KEYSTORE_* env vars supported by Godot 4.x export). Then make the workflow fail if the post-sed grep finds no `keystore/release=` line on tag builds.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-004 [HIGH] (ci_export_health/preflight/go-no-go) preflight.sh verdict: NO-GO (exit 1, failures=2) — dirty tree + 3 failing deep tests

- **Location**: `scripts/preflight.sh:154`
- **Execution phase**: I
- **Evidence**: Full run (via `bash scripts/preflight.sh`, 2026-07-20): [1] Toolchain: godot4 in PATH PASS; 'Git clean working tree' FAIL (25 modified/untracked entries incl. v1/project.godot, v1/scenes/main/main.tscn, v1/assets/ui/cozy_theme.tres, _render/, finale.original.pptx); remote origin reachable PASS. [2] File integrity: all 8 PASS. [3] JSON validity: all 5 PASS. [4] sprite_path integrity PASS. [5] Headless boot PASS (exit 0, 0 parse, 0 script). [6] Runtime 6s PASS (0 parse, 0 script). [7] Deep test suite FAIL (exit 1, 3 fail): test_panel_signals_emitted (1/2 asserts), test_toggle_same_panel_closes_it (2/3), test_click_same_hud_button_toggles_panel_closed (1/2) — the known panel-toggle failures, which also make CI job deep-tests (ci.yml:235) red. [8] pptx present PASS. Verdict: NO-GO.
- **Action**: Fix the 3 panel-toggle test failures (Phase H scope; likely interacts with the gdformat-flagged tween_callback close-path in panel_manager.gd:106-112), then commit/clean the working tree; re-run preflight expecting GO (failures=0).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-005 [HIGH] (ci_export_health/ci/lint) CI lint job is red: gdformat --check fails on panel_manager.gd (committed state)

- **Location**: `v1/scripts/ui/panel_manager.gd:109`
- **Execution phase**: I
- **Evidence**: Local run of the exact CI command (`ci.yml:51 gdformat --check v1/scripts/ v1/tests/`, gdtoolkit 4.5.0) exits 1: 'would reformat v1/scripts/ui/panel_manager.gd, 1 file would be reformatted, 58 files unchanged'. The offending block is the `_tween.tween_callback(func() -> void:` lambda at lines ~106-112; gdformat wants the lambda wrapped/indented one level deeper. `git status --porcelain` on the file is empty — the failure is in COMMITTED code (last touched by 58a61b5 'fix(demo-triage)'), so the ci.yml lint job fails on main for every push touching v1/**. gdlint on the same scope is clean ('Success: no problems found', exit 0).
- **Action**: Run `gdformat v1/scripts/ui/panel_manager.gd` and commit the reformat (single-file diff: lambda body re-indented inside tween_callback parentheses). Verify with `gdformat --check v1/scripts/ v1/tests/` exit 0.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-006 [HIGH] (features_todo/mood-audio) Mood slider never switches audio track — self-emit guard makes swap a structural no-op

- **Location**: `v1/scripts/autoload/audio_manager.gd:402`
- **Execution phase**: F
- **Evidence**: README.md:97 claims "Mood slider profile HUD: cambia audio track + overlay + pet behavior real-time". Overlay and pet work; audio track swap cannot ever fire from the slider. In `crossfade_to_mood_track` (audio_manager.gd:392-412) the code sets `current_mood = "stormy"` (and "tense"/"calm") BEFORE `SignalBus.mood_changed.emit(...)`; the receiving handler `_on_mood_changed` (audio_manager.gd:199-202) starts with `if mood == current_mood: return` — so the track-selection body is always skipped for slider-driven changes. Additionally "stormy" matches no track: tracks.json moods are only [calm, neutral] and [tense], so even without the guard stormy would no-op (CHANGELOG.md:77-79 admits the missing storm track but not the guard bug). Net effect: slider only scales volume (0.5x at mood 0). Side effect: the pre-set `current_mood="stormy"` can also swallow a subsequent legitimate StressManager mood emission of the same value.
- **Action**: In crossfade_to_mood_track, call the track-selection logic directly (extract _select_track_for_mood(mood) and call it) instead of emitting mood_changed after mutating current_mood; map slider stormy→"tense" so rain_thunder actually swaps in; alternatively correct the README claim to "volume + ambience modulation".
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-007 [HIGH] (features_todo/cloud-sync) "Sync cross-device" claimed but cloud pull is never wired — push-only

- **Location**: `v1/scripts/autoload/supabase_client.gd:208`
- **Execution phase**: F
- **Evidence**: README.md:5 claims "Account Supabase opzionale per sync cross-device". supabase_client.gd:208 defines `func fetch_table(table: String, query: String = "") -> String:` but a repo-wide grep finds ZERO call sites in scripts/ or tests/ — the only occurrence is the definition itself. Only push exists (5 tables via sync_queue). README.md:39 even admits "supabase/ Schema cloud (push-only, stub)", contradicting line 5 of the same file. A user logging in on a second device gets an empty room: no download of profiles/user_currency/user_settings/music_preferences/room_decorations ever happens.
- **Action**: Either implement pull-on-login (call fetch_table for the 5 cloud tables after session restore, map via supabase_mapper, merge into SaveManager with last-write-wins) or correct README.md:5 to "backup cloud push-only (restore non ancora implementato)". Doc fix is the demo-safe option; pull belongs in Phase F.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-008 [HIGH] (i18n/i18n/missing-keys) Audit-flagged keys SAVE_FAILED, SAVE_INTEGRITY_VIOLATION, CLOUD_SYNC_ERROR still absent — save/sync failures remain invisible to users

- **Location**: `v1/locale/en.po:54`
- **Execution phase**: F
- **Evidence**: Repo-wide grep for SAVE_FAILED|SAVE_INTEGRITY_VIOLATION|CLOUD_SYNC_ERROR matches only AUDIT_REPORT_2026-04-23.md:702 (the remediation instruction itself). Neither .po file has them, no toast call for save-failure paths exists (the only save toast is the success path 'Partita salvata ✓' at toast_manager.gd:32). This is the audit's HIGH 'No save failed user journey' finding (AUDIT_REPORT_2026-04-23.md:698-702), still OPEN; it depends on the missing error-signal vocabulary (audit lines 677-690: save_failed, save_integrity_violation, sync_error signals absent from signal_bus.gd).
- **Action**: Add the three msgid/msgstr pairs to both .po files, add the error signals to SignalBus, emit them from save_manager/supabase_client failure sites, and have toast_manager subscribe and show tr(<key>) with error severity.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-009 [HIGH] (i18n/i18n/key-usage) 27 of 34 .po keys are dead — no code or scene references them

- **Location**: `v1/locale/it.po:10`
- **Execution phase**: F
- **Evidence**: Both v1/locale/it.po and v1/locale/en.po contain the same 34 msgids (full parity, no empty msgstr). Only 7 keys are ever consumed, all via 8 tr() calls in v1/scripts/ui/profile_hud_panel.gd (lines 61, 105, 115, 126, 142, 154, 241): UI_PROFILE_IMAGE_TOOLTIP, UI_PROFILE_SETTINGS_TOOLTIP, UI_PROFILE_CLOSE_TOOLTIP, UI_PROFILE_MOOD_LABEL, UI_PROFILE_MOOD_HINT, UI_PROFILE_GUEST, TOAST_LANG_CHANGED. Per-key grep across v1/scripts + v1/scenes returns 0 hits for the other 27: UI_MENU_NEW_GAME, UI_MENU_LOAD_GAME, UI_MENU_OPTIONS, UI_MENU_QUIT, UI_HUD_DECO, UI_HUD_PROFILE, UI_HUD_MENU, UI_PROFILE_LANG_TOOLTIP, TOAST_IMAGE_LOAD_ERROR, TOAST_IMAGE_SAVED, TOAST_BADGE_UNLOCKED, UI_SETTINGS_TITLE, UI_SETTINGS_VOLUME_MASTER/MUSIC/AMBIENCE, UI_SETTINGS_LANGUAGE, UI_SETTINGS_REPLAY_TUTORIAL, all 7 UI_AUTH_*, all 3 UI_DECO_*. No scene uses translation keys as node text and no scene sets auto_translate (grep 'UI_|TOAST_' and 'auto_translate' in v1/scenes: empty). Reverse direction is clean: all 7 used keys exist in both files, so there are no used-but-untranslated keys.
- **Action**: Wire the 27 dead keys to their intended UI sites (they map 1:1 to existing hardcoded strings — see companion items) instead of deleting them; the catalogs were clearly authored ahead of the wiring work.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-010 [HIGH] (i18n/i18n/language-switch) Saved language is never applied at boot — TranslationServer.set_locale only runs on user click

- **Location**: `v1/scripts/autoload/save_manager.gd:45`
- **Execution phase**: F
- **Evidence**: Grep for TranslationServer/set_locale across v1/scripts finds only settings_panel.gd:173 and profile_hud_panel.gd:239, both inside user-triggered handlers. No autoload (SaveManager, GameManager, main.gd) applies the persisted "language" setting at startup, so every launch reverts to OS locale with project fallback it (project.godot:91-92: locale/translations=it.po+en.po, locale/fallback="it"). A user who selected EN gets Italian tr() strings again on next boot until they re-toggle.
- **Action**: In SaveManager (after settings load) or main entry _ready(), call TranslationServer.set_locale(get_setting("language", <one canonical default>)) before any UI builds.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-011 [HIGH] (i18n/i18n/hardcoded-strings) Mixed-language shipping UI: auth flow hardcoded English while rest of game is hardcoded Italian

- **Location**: `v1/scripts/menu/auth_screen.gd:48`
- **Execution phase**: F
- **Evidence**: auth_screen.gd is 100% hardcoded English: :48 "Relax Room", :55 "Your cozy desktop companion", :90 "Play as Guest", :98 "Username", :103 "Password", :111 "Login", :118 "Don't have an account? Register", :127 "Choose a username", :133 "Choose a password", :140 "Confirm password", :148 "Register", :155 "Already have an account? Login", plus validation errors :178 "Please enter username and password", :191 "Internal error: form not ready", :197 "Please fill in all fields", :200 "Passwords don't match". Backend errors surfaced via _show_error(result["error"]) at :182/:204 are also hardcoded English in auth_manager.gd:51-113 ("Username must be at least 3 characters", "Username already taken", "Invalid credentials", "Too many attempts. Wait %ds", etc.). With fallback=it every Italian user sees an English login screen followed by an Italian game. The 7 UI_AUTH_* keys covering most of these labels already exist unused in both .po files (it.po:87-106).
- **Action**: Wrap all auth_screen labels/placeholders in tr(UI_AUTH_*) (keys exist); move auth_manager error strings to new AUTH_ERR_* keys returned as key + args and translated at display time in auth_screen.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-012 [HIGH] (i18n/i18n/language-switch) Language switch re-renders nothing: language_changed signal has zero subscribers and no node uses key-based auto-translate

- **Location**: `v1/scripts/ui/settings_panel.gd:167`
- **Execution phase**: F
- **Evidence**: settings_panel.gd:167-176 (_on_language_selected) does: TranslationServer.set_locale(lang_code); SignalBus.settings_updated.emit("language", ...) [persists]; SignalBus.language_changed.emit(lang_code). Grep for language_changed across v1/scripts: declared at signal_bus.gd:50, emitted at settings_panel.gd:175 and profile_hud_panel.gd:237 — ZERO .connect() subscribers. The comment at settings_panel.gd:169-172 claims nodes with 'testo = "UI_KEY"' re-translate via auto_translate, but no such node exists anywhere (scenes contain literal Italian text: main_menu.tscn:53-88, main.tscn:85-97). Net effect of a switch: (a) the persisted setting changes, (b) TOAST_LANG_CHANGED toast renders in the new locale (profile_hud_panel.gd:241), (c) the IT/EN badge updates but only on the profile-HUD toggle path (_refresh_lang_button, profile_hud_panel.gd:221-230 — the settings dropdown path never refreshes it), (d) panels re-instantiated later by panel_manager.gd (instantiate at :45, queue_free at :113/:138) pick up the new locale for the 7 tr() keys on next open. Everything currently on screen stays stale: game HUD, main scene bottom bar, open panel tooltips, main menu, tutorial.
- **Action**: After migrating strings to tr()/keys: subscribe UI roots to SignalBus.language_changed and re-apply texts (or set node text to msgid keys and rely on auto_translate_mode ALWAYS), and refresh the profile-HUD lang badge from the settings-dropdown path too.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-013 [HIGH] (scenes_integrity/scene-integrity/uncommitted-diff) main.tscn: accidental editor drags broke floor collision and room alignment — REVERT

- **Location**: `v1/scenes/main/main.tscn:48`
- **Execution phase**: J
- **Evidence**: FloorBounds got `position = Vector2(257.22833, -714.39526)`, `scale = Vector2(0.87839943, 2.2701287)` (main.tscn:49-50) and a rewritten polygon (line 52). Effective world-space polygon (scale*v + node pos + RoomBounds(-2,-69)): (655,152) / (1335,514) / (646,873) / (-34,506) vs committed (640,265) / (1100,480) / (640,685) / (180,480). New bbox -34..1335 x 152..873 overflows the 1280x720 viewport right (+55px), left (-34px) and bottom (+153px), and the top vertex sits 136px above the wall/floor boundary (FloorRect anchor 0.4 => y=288) — character can walk onto the wall and off-screen; walkable area is 2.55x larger. Non-uniform scale on a collision node plus the incoherent sibling drags — Decorations (4,-73) at line 39, RoomBounds (-2,-69) at line 46, RoomGrid (2,-79) at line 55 — desync decorations, grid overlay and collision from the static RoomBackground at (640,360) and from each other (grid vs decorations differ by (2,-6)). Classic accidental drag-select in the 2D editor, not an intentional redesign. Verdict: MIXED in the strict sense (the MenuButton unique_id and DropZone layout_mode/focus_mode hunks are harmless resave churn) but the churn has zero value, so full revert is the right call.
- **Action**: Run `git checkout -- v1/scenes/main/main.tscn` (or `git restore`) to discard the whole file. If you want to keep the serialization churn, selectively revert only the 4 transform hunks (Decorations position, RoomBounds position, FloorBounds position/scale/polygon, RoomGrid position); the editor will re-add unique_id/layout_mode churn on next save anyway.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-014 [HIGH] (scenes_integrity/scene-integrity/ext-resource) virtual_joystick.tscn references two nonexistent textures with dead uids — mobile joystick silently fails

- **Location**: `v1/scenes/ui/virtual_joystick.tscn:4`
- **Execution phase**: J
- **Evidence**: Lines 4-5: `path="res://assets/menu/ui/sprite_pad_base.png"` (uid://dss01ljguvr3s) and `path="res://assets/menu/ui/sprite_pad_lever.png"` (uid://bkpqg1ekq7uuj). Neither path exists — the real textures are at v1/assets/menu/sprite_pad_base.png (uid://ct0sgpldlep3q) and v1/addons/virtual_joystick/textures/sprite_pad_base.png (uid://o58ft21vixtg) — and no .import file in the repo carries the scene's uids, so Godot's uid-fallback resolution cannot recover. v1/scripts/main.gd:72 loads this scene when `OS.has_feature("mobile") or OS.has_feature("web")`; load() will fail on missing dependencies, the `if joy_scene != null` guard swallows it, and the Android APK / HTML5 build ships with no touch input and error spam. This is committed damage (last touched in 91f34ae 'Integrazione asset da ZroGP/Projectwork-IFTS'), not part of the uncommitted diff. Only 2 broken refs found across all 17 .tscn/.tres files scanned under v1/scenes and v1/assets/ui — every other ext_resource path resolves.
- **Action**: Repoint the two ext_resource entries to res://addons/virtual_joystick/textures/sprite_pad_base.png and sprite_pad_lever.png (or res://assets/menu/sprite_pad_*.png) with their real uids, then verify with a headless load of the scene. Add a mobile-feature smoke check so a null joy_scene fails CI instead of being silently swallowed.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-015 [HIGH] (test_failures/ui/panel-lifecycle) Root cause: commit 58a61b5 deferred panel_closed emission and state clearing to end of 0.3s fade tween

- **Location**: `v1/scripts/ui/panel_manager.gd:109`
- **Execution phase**: H
- **Evidence**: Regression introduced by commit 58a61b5 (2026-04-22, 'fix(demo-triage)... B-036'), the last commit to touch this file. Before it, close_current_panel() ran `_current_panel = null`, `_current_panel_name = ""` and `SignalBus.panel_closed.emit(closing_name)` synchronously, deferring only `closing_panel.queue_free` to the tween end. After it, all state clearing and the signal emission live inside `_tween.tween_callback(func() -> void: ... SignalBus.panel_closed.emit(closing_name))` at v1/scripts/ui/panel_manager.gd:109-115, which fires only after the fade tween of `Constants.PANEL_TWEEN_DURATION := 0.3` seconds (v1/scripts/utils/constants.gd:37). The tests await only wait_frames(3)/wait_frames(5) (~50-83 ms of accumulated tween delta at 60 fps; test_base.gd:92 awaits process_frame), so at assertion time the callback has not run: is_panel_open() is still true, get_current_panel_name() still returns the old name, and panel_closed has not been emitted. Both failing test files predate the commit (last touched 2026-04-21 in 0f9bd7a/10b1fbb), so this is a code regression against the established contract, not a test-expectation change. Deferred emission is also inconsistent with v1/scripts/ui/settings_panel.gd:100, which emits panel_closed synchronously at close-initiation, and with _close_immediate() (panel_manager.gd:141) which also emits synchronously. The uncommitted main.tscn diff is NOT implicated: test_panels.gd never loads main.tscn (it builds a bare CanvasLayer + PanelManager in _build_panel_manager), and the scene diff only touches Decorations/RoomBounds/FloorBounds transforms, DropZone layout_mode/focus_mode, and a MenuButton unique_id — none of which affect panel close; the other 14 test_ui_events tests pass against the modified scene.
- **Action**: Fix the implementation, preserving B-036 intent. In close_current_panel() (panel_manager.gd:76-116): restore synchronous behavior — set `_current_panel = null`, `_current_panel_name = ""` and `SignalBus.panel_closed.emit(closing_name)` immediately at close-initiation, keeping only `closing_panel.queue_free()` in the tween callback. To keep the B-036 guard (re-click during fade must not spawn a duplicate panel), add two fields `var _closing_panel: PanelContainer = null` / `var _closing_panel_name: String = ""`, set them at close-initiation, clear them in the tween callback, and in toggle_panel() early-return when `panel_name == _closing_panel_name and is_instance_valid(_closing_panel)` (the re-click is noise; panel is already closing). The `closing` meta guard at line 84 then becomes redundant and can be dropped. Important detail: own the close fade with `closing_panel.create_tween()` instead of the shared `_tween`, otherwise open_panel()'s `_tween.kill()` (lines 56-58) would cancel the pending queue_free when a different panel is opened mid-fade and leak the fading panel node (at current HEAD that path goes through _close_immediate, but with synchronous state clearing _close_immediate early-returns). Verify with: cd /data/Projectwork && ./scripts/deep_test.sh — expect 111/111.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-016 [MEDIUM] (assets_gap/assets/licensing) Eder Muniz forest pack requires credit — no credits screen or attribution exists in-game

- **Location**: `/data/Projectwork/v1/assets/backgrounds/Free Pixel Art Forest/license.txt:3`
- **Execution phase**: G
- **Evidence**: license.txt states 'You must give appropriate credit' and 'You can NOT re-distribute the files, no matter how much you modify it'. The forest layers are actively used at runtime (window_background.gd:6 LAYER_BASE_PATH, all 8 referenced layer PNGs verified present). grep for credits/crediti across scripts/menu and scripts/ui finds no credits UI. Additionally, three downloaded packs sit in a Git repo that also serves a public landing page: SoppyCraft plants (LICENSE.txt: 'may not resell or redistribute these files as-is'), Thurraya rooms (README.txt: 'cannot resell or redistribute'), Eder Muniz forest — publicly hosting the raw pack files is arguably redistribution. Kenney UI pack is CC0 (no constraint); Mixkit is free-license; charachters/menu/pets/room are in-project art (freely modifiable).
- **Action**: Add a credits entry (main menu or settings) crediting 'Eder Muniz — Free Pixel Art Forest', SoppyCraft, Thurraya, Kenney, Mixkit. If the GitHub repo is public, consider excluding raw no-redistribution packs from the public tree (keep only game-consumed sprites) or making the repo private.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-017 [MEDIUM] (assets_gap/assets/docs) assets/room/README.md documents ~13 files that no longer exist (mess/, bed/, door.png)

- **Location**: `/data/Projectwork/v1/assets/room/README.md:16`
- **Execution phase**: G
- **Evidence**: The README lists `bed/sprite_bed_*.png` (8 files), `mess/floor_mess1-3.png` (3 files), and `door.png` — none exist on disk. Actual contents of v1/assets/room/: room.png, room_original_2528x1696.png, window1-3.png, aseprite_room/ (door.aseprite, room_base.aseprite, sprite_windows.aseprite). The files were removed by commits e96b446/4e2c4cd (ZroGP fork asset purge) but the README was never updated. Any asset-creation plan (Phase G) reading this README would wrongly assume the art exists. Same drift in assets/charachters/README.md, which claims `female/female_red_shirt/` exists with a .tscn scene ('Scena .tscn esiste ma non selezionabile') — the entire charachters/female/ directory is absent and no female .tscn exists in scenes/.
- **Action**: Update assets/room/README.md and assets/charachters/README.md to match disk reality (remove bed/, mess/, door.png, female/ claims), or restore the files as original art; keep the READMEs as the source of truth for Phase G scoping.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-018 [MEDIUM] (assets_gap/assets/ui-icons) Badge icons and profile placeholder are emoji strings, not image assets — rendering depends on font glyph coverage

- **Location**: `/data/Projectwork/v1/data/badges.json:7`
- **Execution phase**: G
- **Evidence**: badges.json uses emoji as icons (🏠 🏛️ 🎨 🌈 ⛈️ 🦉, default 🏅). profile_hud_panel.gd:281-287 renders them as `Label.text`; the profile-image fallback is `_profile_btn.text = "👤"` (profile_hud_panel.gd:175,181), plus ⚙ (line 104) and ✕ (line 114) buttons. No font resource exists in the project (no .ttf/.otf under v1/assets; cozy_theme.tres sets only font colors/sizes, no font override; project.godot sets no custom font), so rendering relies on Godot's default font, which has no color-emoji glyphs — high risk of tofu boxes, especially on export templates without system-font fallback. Prior audit line 776 flagged the same class of issue for emoji display names. There are zero badge icon image files anywhere under v1/assets.
- **Action**: Either add a bundled emoji-capable fallback font (e.g. Noto Emoji, OFL) wired into cozy_theme.tres, or replace emoji icons with 6 small pixel-art badge PNGs (16x16) + icon_path field in badges.json, and swap ⚙/✕/👤 for TextureButtons using Kenney CC0 UI glyphs already in the repo.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-019 [MEDIUM] (assets_gap/assets/mess) All 6 mess_catalog.json entries have empty sprite_path — every mess renders as a runtime placeholder circle

- **Location**: `/data/Projectwork/v1/data/mess_catalog.json:9`
- **Execution phase**: G
- **Evidence**: All six entries (crumbs_spot, coffee_stain, dust_bunny, crumpled_paper, dirty_plate, sock_single) have `"sprite_path": ""` (mess_catalog.json:9,19,29,39,49,59). scripts/rooms/mess_node.gd:90-103 `_resolve_texture` falls through to `_make_placeholder_texture` (lines 106-119), drawing a flat colored circle with darkened outline per `placeholder_color`. No real mess art exists anywhere under v1/assets — the documented assets/room/mess/floor_mess1-3.png were deleted in commit e96b446 ('Rimozione asset copiati dal fork ZroGP per conformità alla direttiva anti-copia'). Every mess in the shipped game is a colored dot.
- **Action**: Draw 6 original mess sprites in Aseprite (sizes per catalog size_px: 28-44 px), place under v1/assets/room/mess/, and fill the six sprite_path fields. Must be original art — the previous sprites were removed under the anti-copy directive, so re-importing ZroGP fork assets is not an option.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-020 [MEDIUM] (assets_gap/assets/audio) tracks.json ambience array is empty and assets/audio/ambience/ does not exist — ambience subsystem has zero assets

- **Location**: `/data/Projectwork/v1/data/tracks.json:20`
- **Execution phase**: G
- **Evidence**: tracks.json:20 has `"ambience": []`. audio_manager.gd:_find_ambience_path (lines 322-336) first checks the empty catalog, then falls back to `res://assets/audio/ambience/%s.ogg|.wav` — the directory does not exist (v1/assets/audio/ contains only music/ with the 2 Mixkit WAVs). Any `_start_ambience` call hits push_warning 'ambience file not found' (line 302). No UI emits `ambience_toggled` (only declared in signal_bus.gd:21; settings_panel.gd only has an ambience volume slider at lines 48-49), but a saved state containing `active_ambience` IDs re-triggers `_start_ambience` at boot (audio_manager.gd:84-85). The full ambience playback machinery (players dict, crossfade, volume bus) is shipped dead weight with a settings slider controlling nothing audible.
- **Action**: Either populate ambience: source 2-3 loopable CC0/Mixkit ambience files into v1/assets/audio/ambience/ + catalog entries + a toggle UI in settings_panel.gd, or explicitly mark the subsystem post-demo and hide the ambience volume slider until assets exist.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-021 [MEDIUM] (catalogs_data/CI validator coverage) badges.json and mess_catalog.json are excluded from all three CI catalog validators

- **Location**: `ci/validate_json_catalogs.py:178`
- **Execution phase**: F
- **Evidence**: VALIDATORS dict at ci/validate_json_catalogs.py:178-183 contains only characters/decorations/rooms/tracks; validate_sprite_paths.py:67-71 likewise. A schema break, duplicate id, or condition typo in badges.json or mess_catalog.json passes CI silently. The failure mode is real: badge_manager.gd:85-98 `_get_counter_for_type` falls through to `return 0` for unknown condition.type, making a mistyped badge permanently unobtainable with no warning; game_manager.gd:162-166 `get_mess_stress_weight` silently returns 0.10 for unknown mess ids. Current data happens to be clean — my deep check confirmed all 6 badge condition types are in the handled set {decorations_placed, mood_changes, play_time_seconds, stormy_mood}, thresholds are positive ints, all ids unique, and mess fields well-typed (stress_weight in (0,1], spawn_weight > 0, valid #rrggbb placeholder colors).
- **Action**: Add validate_badges (required fields id/name/description/icon/condition; condition.type in the badge_manager whitelist; threshold positive int; unique ids) and validate_mess (8 required fields, weight ranges, hex color format, unique ids) to ci/validate_json_catalogs.py, and have badge_manager.gd push_warning on unknown condition.type instead of silently returning 0.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-022 [MEDIUM] (catalogs_data/characters.json) characters.json is ~95% dead data with three competing sources of truth for characters

- **Location**: `v1/data/characters.json:9`
- **Execution phase**: F
- **Evidence**: Runtime code reads only the array size and `id`: main_menu.gd:100-102 (`characters.size() <= 1` bypass + `characters[0].get("id")`). The fields gender, sprite_path, sprite_type, and the full 25-path animations tree (idle/walk/interact x 8 directions + rotate) are consumed exclusively by ci/validate_json_catalogs.py and ci/validate_sprite_paths.py — actual character visuals come from the hardcoded scene: character_select.gd:12-18 `const CHARACTERS := [{"id": "male_old", ... "scene": "res://scenes/male-old-character.tscn"}]` and room_base.gd:13-15 `const CHARACTER_SCENES := {"male_old": "res://scenes/male-old-character.tscn"}`. Drift hazard: adding a character to the JSON alone flips main_menu into showing a character_select screen that cannot show the new character (its list is hardcoded). All 25 animation paths do exist on disk with .import sidecars, so the dead data is at least internally valid.
- **Action**: Pick one source of truth: either make character_select.gd/room_base.gd read GameManager.characters_catalog (add a "scene" field per entry), or shrink characters.json to the fields actually consumed (id, name) and drop the animations tree from catalog + validators. Add a CI check that catalog character ids == room_base.CHARACTER_SCENES keys == character_select.CHARACTERS ids.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-023 [MEDIUM] (catalogs_data/constants.gd cross-ref) MOOD_AUDIO_TRACK_STORM points to a nonexistent file and is referenced nowhere

- **Location**: `v1/scripts/utils/constants.gd:65`
- **Execution phase**: F
- **Evidence**: `const MOOD_AUDIO_TRACK_STORM := "res://assets/audio/storm_ambient.ogg"` — v1/assets/audio/ contains only music/mixkit-light-rain-loop-1253.wav and mixkit-light-rain-with-thunderstorm-1290.wav; storm_ambient.ogg does not exist on disk. Grep across scripts/ and tests/ shows the constant is defined but never used. ci/validate_cross_references.py only checks CHAR_/ROOM_/THEME_ prefixes (lines 16-20), so this dangling res:// path constant is invisible to CI.
- **Action**: Delete the dead constant (preferred, ties into the HIGH finding's resolution) or ship storm_ambient.ogg and wire it up. Extend ci/validate_cross_references.py to verify any `res://` string constant in constants.gd resolves to an existing file.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-024 [MEDIUM] (ci_export_health/release-pipeline/android-export) Android export failure fully masked: continue-on-error + || echo, release job still waits on it

- **Location**: `.github/workflows/build.yml:262`
- **Execution phase**: I
- **Evidence**: The 'Export Android APK' step is `continue-on-error: true` with both export invocations suffixed `|| echo "... export failed — see known-issue comment"` (build.yml:262-273). Comment admits Android export in barichello/godot-ci:4.6 fails with 'configuration errors' (known issue pre-Fase C). Verify/SHA256 steps also continue-on-error and exit 0 when no APK exists (build.yml:275-283). Meanwhile release.yml:44-48 gates the GitHub Release on check-name 'Build Android APK', which will report success even when zero APKs were produced — a v-tag release can publish with the Android asset silently absent (or the Download Android artifact step failing late).
- **Action**: Either make Android export a hard failure on tag builds (drop continue-on-error when ref is a tag), or exclude Android from the release gate and the release asset list until the gradle_build/custom-template fix in the TODO comment lands.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-025 [MEDIUM] (ci_export_health/dist/staleness) dist/ artifacts (2026-04-21) predate last v1 commit (2026-04-23) and current uncommitted edits

- **Location**: `dist/RelaxRoom-Windows-v1.0.zip:?`
- **Execution phase**: I
- **Evidence**: All dist artifacts are dated 2026-04-21 15:09: RelaxRoom-Web-v1.0.zip (25MB), RelaxRoom-Windows-v1.0.zip (52MB), unpacked dist/html5/ (index.wasm 37MB, index.pck 15MB) and dist/windows/RelaxRoom.exe (119MB). Last commit touching v1/ is 99fc76d 2026-04-23 03:14 ('chore(refs): purge dead doc-pointer comments'), so binaries are missing at least the 04-21→04-23 game commits, plus the current uncommitted edits to v1/project.godot, v1/scenes/main/main.tscn, v1/assets/ui/cozy_theme.tres. Naming also drifts: zips say 'v1.0' while the canonical version (v1/VERSION, project.godot config/version, preset file_version/product_version, constants.gd APP_VERSION) is 1.0.0.
- **Action**: Re-export Windows + Web after the pending v1 work is committed, and name artifacts from v1/VERSION (RelaxRoom-<platform>-v1.0.0.zip), ideally via the same script/workflow that reads VERSION so dist naming can never drift again.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-026 [MEDIUM] (ci_export_health/tooling/exec-bits) preflight.sh and build_apk_local.sh are not executable (./scripts/preflight.sh → exit 126)

- **Location**: `scripts/preflight.sh:1`
- **Execution phase**: I
- **Evidence**: `./scripts/preflight.sh` fails with 'Permission denied' (exit 126). `stat` shows -rw-rw-r-- on scripts/preflight.sh and scripts/build_apk_local.sh, while bump_version.sh, deep_test.sh, generate_keystores.sh, godot-validate.sh, smoke_test.sh are all -rwxrwxr-x. The documented usage line in the script header ('Usage: ./scripts/preflight.sh') is therefore broken; only `bash scripts/preflight.sh` works.
- **Action**: `chmod +x scripts/preflight.sh scripts/build_apk_local.sh` and commit the mode change (git tracks the exec bit).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-027 [MEDIUM] (ci_export_health/export/icons) Project icon is the stock Godot robot; Android launcher icons unset

- **Location**: `v1/icon.svg:1`
- **Execution phase**: I
- **Evidence**: v1/project.godot:24 sets config/icon="res://icon.svg", and v1/icon.svg is the unmodified default Godot logo (995 bytes, `fill="#478cbf"` robot paths). Web preset has html/export_icon=true (export_presets.cfg:63) so the web build ships the Godot robot as favicon/loading icon (visible in dist/html5/index.icon.png, index.apple-touch-icon.png). Android preset launcher_icons/main_192x192, adaptive_foreground/background/monochrome_432x432 are all empty strings (export_presets.cfg:122-125) → APK would ship default Godot launcher icons. Only Windows has a real dedicated icon (application/icon=res://icon.ico, file exists, 3.4KB). PWA icons empty but progressive_web_app/enabled=false, so not an issue.
- **Action**: Create a Relax Room icon set: replace v1/icon.svg, regenerate icon.ico from it, and fill the four Android launcher_icons paths (192x192 + 432x432 adaptive set) before any public release.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-028 [MEDIUM] (features_todo/badges) night_owl badge (30 min play) unlocks only if an unrelated event fires — no timer re-check

- **Location**: `v1/scripts/autoload/badge_manager.gd:91`
- **Execution phase**: F
- **Evidence**: badges.json:39-44 defines night_owl "Gioca per 30 minuti consecutivi" (play_time_seconds >= 1800). BadgeManager is explicitly "zero polling" (badge_manager.gd:5): `_check_all_conditions` runs only on decoration_placed, mood_level_changed (L23-24) and once deferred at boot (L26). play_time_seconds is computed lazily in `_get_counter_for_type` (L91-92). A player who idles/relaxes — the game's core use case as a background companion — passes 30 min without either signal and never unlocks the badge; it appears only on the next decoration/mood interaction, possibly hours later.
- **Action**: Add a Timer node in BadgeManager._ready (wait_time 60 s, autostart) whose timeout calls _check_all_conditions(); stop it once night_owl is unlocked.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-029 [MEDIUM] (features_todo/badges) Cumulative badge counters are session-proxied, not lifetime — 25/100-deco badges and total_earned drift

- **Location**: `v1/scripts/autoload/badge_manager.gd:20`
- **Execution phase**: F
- **Evidence**: badge_manager.gd:19-21 rehydrates `_decorations_placed_counter = SaveManager.get_decorations().size()` with comment "non conta quelle rimosse, ma per demo e` sufficiente". cozy_collector (threshold 25) and interior_designer (threshold 100) say "in totale" (badges.json:13,22): a player who places 30 and deletes 10 restarts at 20, losing progress. mood_changes counter (mood_explorer, threshold 10) is purely in-memory and resets every session with no rehydration at all. Same class of gap: supabase_mapper.gd:61 `"total_earned": account.get("coins", 0),  # TODO: track lifetime earnings separately (needs DB column)` pushes current balance as lifetime earnings to the cloud.
- **Action**: Persist lifetime counters (decorations_placed_total, mood_changes_total, coins_earned_total) in the save file v6 or a new SQLite columns, increment on the respective signals, and rehydrate from there; update supabase_mapper to send the real total_earned.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-030 [MEDIUM] (features_todo/i18n) i18n IT/EN claimed demo-ready; only ~16 tr() call sites, 35 msgids, lang toggle hidden

- **Location**: `v1/scripts/ui/settings_panel.gd:57`
- **Execution phase**: F
- **Evidence**: README.md:104 lists "i18n IT/EN via .po + TranslationServer.set_locale()" among demo-ready features and README.md:101 claims profile HUD has "lang toggle IT/EN". Reality: settings_panel.gd:56-57 comment says "la maggior parte delle stringhe UI e` italiano hardcoded, solo ~16 passaggi con tr() cambiano lingua al momento. i18n completo e` WIP"; settings_panel.gd:172 "i18n completo e` WIP post-demo"; profile_hud_panel.gd:98 hides the toggle (`_lang_btn.visible = false`, comment L95 "nascosto pre-demo"). Both .po files have only 35 msgids. Switching to EN leaves tutorial, menus, panels, toasts in Italian. CHANGELOG.md:80-81 admits it under Known limitations, but the feature lists overclaim.
- **Action**: Phase F: extract all user-facing strings to tr() keys and extend the .po files (tutorial_manager, main_menu, settings_panel, deco_panel, toasts, character_select), then unhide _lang_btn; until then amend README.md:101/104 to "i18n parziale (ProfileHUDPanel only)".
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-031 [MEDIUM] (i18n/i18n/data-catalogs) JSON catalogs are single-language with inconsistent languages: badges Italian-only, decoration categories English-only

- **Location**: `v1/data/badges.json:5`
- **Execution phase**: F
- **Evidence**: badges.json name/description are Italian only ("Primo Arredo", "Piazza la tua prima decorazione nella stanza", ...) and are user-facing via badge_manager.gd:73 toast and profile_hud_panel.gd:284 tooltip. decorations.json:3-14 category names are English only ("Beds", "Desks", "Wall Decor", ...) and are user-facing via deco_panel.gd:85/:166/:168 collapsible headers. Neither has any locale structure, so catalog content can never follow the language setting and the deco panel shows English headers inside an otherwise Italian UI.
- **Action**: Either add per-locale fields ({"name": {"it": ..., "en": ...}}) resolved at load, or replace display strings with msgid keys (BADGE_<id>_NAME etc.) added to both .po files and resolved via tr() at render.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-032 [MEDIUM] (i18n/i18n/hardcoded-strings) Main menu and main-scene HUD buttons hardcoded Italian in .tscn despite matching UI_MENU_*/UI_HUD_* keys existing

- **Location**: `v1/scenes/menu/main_menu.tscn:64`
- **Execution phase**: F
- **Evidence**: main_menu.tscn:53 "Relax Room", :64 "Nuova Partita", :70 "Carica Partita", :76 "Opzioni", :82 "Profilo", :88 "Esci"; main.tscn:85 "Menu", :91 "Decora", :97 "Profilo". All have exact unused counterparts (UI_MENU_NEW_GAME/LOAD_GAME/OPTIONS/QUIT, UI_HUD_MENU/DECO/PROFILE, it.po:10-30). Because scene text is a literal Italian string and not the msgid, Godot auto-translate cannot resolve it, so these never switch language.
- **Action**: Replace scene text values with the msgid keys (auto_translate_mode ALWAYS resolves them and also live-updates on set_locale — this is the cheapest full fix for these 9 buttons).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-033 [MEDIUM] (i18n/i18n/hardcoded-strings) Tutorial: 8 step messages plus chrome hardcoded Italian, no keys exist for any of it

- **Location**: `v1/scripts/menu/tutorial_manager.gd:44`
- **Execution phase**: F
- **Evidence**: tutorial_manager.gd:44-114 _define_steps() embeds 8 Italian BBCode messages ("Benvenuto nella tua [b]Relax Room[/b]! 🏠...", "Usa [b]WASD[/b]...", ..., "[b]Missione completata![/b] 🎉"); :179 "Salta tutorial", :207 "Passo %d / %d", :216 "Chiudi". Zero TUTORIAL_* keys in either .po. English players get a full Italian onboarding.
- **Action**: Add TUTORIAL_STEP_1..8 + TUTORIAL_SKIP/TUTORIAL_CLOSE/TUTORIAL_PROGRESS keys to both .po files and make _define_steps() store keys resolved via tr() at display time (tr() supports the BBCode strings unchanged).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-034 [MEDIUM] (i18n/i18n/hardcoded-strings) Remaining hardcoded UI surfaces: deco_panel, character_select, game_hud, decoration_system, file dialog

- **Location**: `v1/scripts/ui/deco_panel.gd:69`
- **Execution phase**: F
- **Evidence**: deco_panel.gd:31 "Decorazioni" (unused key UI_DECO_TITLE exists), :69 "Nessuna decorazione disponibile.", :178/:180 "Esci Modalità Modifica"/"Modalità Modifica" (unused UI_DECO_MODE_DISABLE/ENABLE exist, though msgstr wording differs: "Fine"/"Modifica"). character_select.gd:58 "Scegli il tuo Personaggio", :135 "Inizia a Giocare". game_hud.gd:68 "Serenita", :141 tooltip "Profilo + Mood". profile_hud_panel.gd:81 "Ospite" default (should be tr("UI_PROFILE_GUEST") like :154), :198 FileDialog title "Scegli immagine profilo (solo locale)". decoration_system.gd:110/:119/:128/:138 English tooltips "Rotate"/"Flip"/"Scale"/"Delete". The lang button at profile_hud_panel.gd:226-229 also never sets the existing UI_PROFILE_LANG_TOOLTIP key as its tooltip — that key is dead because the tooltip is simply never assigned.
- **Action**: Wrap all in tr() using existing keys where available (UI_DECO_*, UI_PROFILE_GUEST, UI_PROFILE_LANG_TOOLTIP) and add ~8 new keys for the rest (character select, serenity header, file dialog title, deco tooltips, empty-catalog message).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-035 [MEDIUM] (i18n/i18n/hardcoded-strings) Toasts hardcode the exact msgstr of existing unused TOAST_* keys

- **Location**: `v1/scripts/ui/profile_hud_panel.gd:209`
- **Execution phase**: F
- **Evidence**: profile_hud_panel.gd:209 emits "Impossibile leggere l'immagine selezionata" — byte-identical to it.po TOAST_IMAGE_LOAD_ERROR msgstr (it.po:55-56); :218 emits "Immagine profilo aggiornata (solo locale)" = TOAST_IMAGE_SAVED (it.po:58-59); badge_manager.gd:73 emits "🏅 Badge sbloccato: %s" = TOAST_BADGE_UNLOCKED (it.po:64-65). Same file already uses tr() correctly one line down at :241 for TOAST_LANG_CHANGED. Also untranslatable with no key at all: profile_hud_panel.gd:214 "Errore salvataggio immagine (%d)", toast_manager.gd:32 "Partita salvata ✓", :36 "Posizionato: %s", :40 "Rimosso: %s", room_base.gd:98 "Decorazione sconosciuta: %s", drop_zone.gd:52 "Stanza non pronta, riprova fra un attimo".
- **Action**: Swap the three literals for tr("TOAST_IMAGE_LOAD_ERROR")/tr("TOAST_IMAGE_SAVED")/tr("TOAST_BADGE_UNLOCKED") (one-line changes), and add new TOAST_* keys for the six keyless toast strings.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-036 [MEDIUM] (i18n/i18n/hardcoded-strings) profile_panel entirely hardcoded Italian including destructive-action confirm dialogs

- **Location**: `v1/scripts/ui/profile_panel.gd:76`
- **Execution phase**: F
- **Evidence**: profile_panel.gd:39 "Profilo", :45 "Account", :59 "Azioni", :67 "Elimina Personaggio", :76-77 confirm "Eliminare il personaggio?"/"Il personaggio e la stanza verranno rimossi. Account e monete restano.", :88 "Elimina Account", :97-98 "Eliminare l'account?"/"Tutti i dati verranno eliminati permanentemente.", :112 "Esci dall'account", :147 "Ospite", :150 "Registrato", :153 "Non connesso". No PROFILE_*/CONFIRM_* keys exist. Delete-account/delete-character confirmations being untranslatable is the riskiest subset (user consents to permanent data loss in a language they may not read).
- **Action**: Add UI_PROFILE_PANEL_* and CONFIRM_DELETE_* keys to both .po files and wrap all 12 literals in tr(); reuse existing UI_PROFILE_GUEST for :147.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-037 [MEDIUM] (i18n/i18n/hardcoded-strings) settings_panel builds all its UI from hardcoded mixed IT/EN literals while all 6 UI_SETTINGS_* keys sit unused

- **Location**: `v1/scripts/ui/settings_panel.gd:31`
- **Execution phase**: F
- **Evidence**: settings_panel.gd:31 title "Impostazioni" (Italian), :37 "Volume", :42/:45/:48 slider labels "Master"/"Music"/"Ambience" (English), :63 "Language" (English), :87 "Ripeti Tutorial" (Italian) — a single panel mixing both languages. Unused keys UI_SETTINGS_TITLE, UI_SETTINGS_VOLUME_MASTER/MUSIC/AMBIENCE, UI_SETTINGS_LANGUAGE, UI_SETTINGS_REPLAY_TUTORIAL exist in both .po files (it.po:68-84).
- **Action**: Replace each literal with tr(<matching UI_SETTINGS_* key>); the panel is re-instantiated per open via panel_manager so it will pick up locale changes without extra wiring.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-038 [MEDIUM] (test_failures/tests/integration) Affected test: test_panels::test_panel_signals_emitted — panel_closed never observed within awaited frames

- **Location**: `v1/tests/integration/test_panels.gd:113`
- **Execution phase**: H
- **Evidence**: Test toggles settings open, then closed, awaiting wait_frames(2)+wait_frames(3) (test_panels.gd:106-109), then disconnects the SignalBus listeners at lines 110-111 and asserts `"settings" in closed_received` (line 113: 'panel_closed must fire with name'). panel_opened is received (passes); panel_closed is emitted only in the tween callback after the 0.3 s fade (panel_manager.gd:114), i.e. after the listener has already been disconnected — closed_received stays empty. Test expectation is correct per the pre-58a61b5 contract and per settings_panel.gd:100 which emits the same signal synchronously.
- **Action**: No test change. Fixed automatically by the root-cause fix (synchronous panel_closed emission at close-initiation in close_current_panel).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-039 [MEDIUM] (test_failures/tests/integration) Affected test: test_panels::test_toggle_same_panel_closes_it — is_panel_open() true and name still 'settings' after toggle-close

- **Location**: `v1/tests/integration/test_panels.gd:75`
- **Execution phase**: H
- **Evidence**: Two assertions fail (both reported by the runner): `assert_false(_panel_manager.is_panel_open())` at line 75 and `assert_eq(_panel_manager.get_current_panel_name(), "")` at line 76 ('assert_eq: expected  got settings'). After the second toggle_panel("settings") the test awaits wait_frames(3) (line 73, comment 'allow fade-out tween to complete' — 3 frames ≈ 50 ms, insufficient for the 0.3 s tween, but sufficient under the old synchronous-clear contract). Because 58a61b5 defers `_current_panel = null` / `_current_panel_name = ""` to the tween callback (panel_manager.gd:110-112), both getters still report the fading panel.
- **Action**: No test change. Fixed automatically by the root-cause fix (clear _current_panel/_current_panel_name synchronously at close-initiation; the fading node is tracked separately in _closing_panel).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-040 [MEDIUM] (test_failures/tests/integration) Affected test: test_ui_events::test_click_same_hud_button_toggles_panel_closed — name still 'deco' after second HUD press

- **Location**: `v1/tests/integration/test_ui_events.gd:222`
- **Execution phase**: H
- **Evidence**: Loads the real main.tscn, emits DecoButton.pressed twice (wired via main.gd:91 `button.pressed.connect(_panel_manager.toggle_panel.bind(panel_name))`), awaits wait_frames(5) after the second press (test_ui_events.gd:221), then asserts get_current_panel_name() == "" (line 222: 'second press on same HUD button must close panel'). Fails with 'expected  got deco' — same deferred-state root cause: 5 frames ≈ 83 ms < 0.3 s fade, so the tween callback that clears _current_panel_name (panel_manager.gd:110-112) has not fired. The HUD wiring itself is correct (first press opens 'deco', line 218 passes), and the uncommitted main.tscn diff is not a factor — this test drives pressed.emit() directly and every other test in the file passes against the modified scene.
- **Action**: No test change. Fixed automatically by the root-cause fix in panel_manager.gd; re-run ./scripts/deep_test.sh to confirm test_ui_events 15/15.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-041 [LOW] (assets_gap/assets/placeholder) _placeholder_temp/puny_characters_cc0 pack still in tree — marked 'remove before final merge'

- **Location**: `/data/Projectwork/v1/assets/_placeholder_temp/README.md:3`
- **Execution phase**: G
- **Evidence**: assets/_placeholder_temp/README.md: 'Rimuovere prima del merge finale. Questi file non sono asset del progetto.' Contains the CC0 Puny Characters pack (opengameart, shubibubi) used to 'coprire i buchi alla presentazione'. Verified unreferenced: no .gd/.tscn/.json/.tres outside the folder mentions _placeholder_temp, and the underscore prefix excludes it from the validator. Pure repo weight/housekeeping; CC0 so no license risk.
- **Action**: Delete v1/assets/_placeholder_temp/ once the presentation window is past (Phase J git hygiene), or keep and document a firm removal deadline.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-042 [LOW] (assets_gap/assets/characters) Character roster is 1 of 3-4 documented — male_yellow_shirt sheet set incomplete, female set absent entirely

- **Location**: `/data/Projectwork/v1/data/characters.json:2`
- **Execution phase**: G
- **Evidence**: characters.json contains exactly 1 character (male_old) with 26 path fields (8 idle + 8 walk + 8 interact + 1 rotate + sprite_path) — ALL verified present on disk under assets/charachters/male/old/. However assets/charachters/male/male_yellow_shirt/ holds only male_rotate.png + male_walk.png (+ aseprite sources) — no idle/interact strips, so it cannot be catalogued as-is; and the female/female_red_shirt/ set documented in assets/charachters/README.md does not exist at all (no directory, no .tscn; only stale comments in room_base.gd:86-88 reference a 'female-character.tscn'). Character select therefore offers a single character.
- **Action**: For Phase F/G: export the missing male_yellow_shirt idle/interact strips from aseprite_male/ sources and add a second catalog entry; treat the female set as net-new original art (sources were never in this repo). Update charachters/README.md status table meanwhile.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-043 [LOW] (assets_gap/assets/audio) Dead constant MOOD_AUDIO_TRACK_STORM points to non-existent storm_ambient.ogg

- **Location**: `/data/Projectwork/v1/scripts/utils/constants.gd:65`
- **Execution phase**: G
- **Evidence**: constants.gd:65 `const MOOD_AUDIO_TRACK_STORM := "res://assets/audio/storm_ambient.ogg"` — file does not exist and the constant is never read anywhere (grep across scripts/scenes: only the definition). audio_manager.gd:388-404 deliberately documents the demo-safe strategy 'no asset storm dedicato' and instead emits mood_changed("stormy") to swap between the two existing rain WAVs. No runtime impact today, but the constant is a trap for anyone wiring stormy audio later.
- **Action**: Delete the constant, or source an actual storm loop (Mixkit has thunderstorm loops under the same free license as the 2 existing tracks) and wire it into the stormy mood path.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-044 [LOW] (catalogs_data/mess_catalog.json) label_it/label_en are dead fields; all 6 sprite_path values empty so mess always renders placeholder rects

- **Location**: `v1/data/mess_catalog.json:5`
- **Execution phase**: F
- **Evidence**: Grep across v1/scripts/ finds no consumer of label_it or label_en — mess UI never shows a name. Consumers of the other fields are real: mess_spawner.gd:97,105 (spawn_weight, weighted sampling, total 7.10), stress_manager.gd:170-171 -> game_manager.gd:162-166 (stress_weight), mess_node.gd:91-102 (sprite_path/size_px/placeholder_color — with sprite_path "" on every entry the ColorRect placeholder branch always runs). Missing mess sprites are already scoped under the Phase G task.
- **Action**: Either surface label_it/label_en in a tooltip/toast on clean-up (they align with the it/en locale setup) or drop the two fields; when Phase G produces mess sprites, fill sprite_path and add mess_catalog.json to validate_sprite_paths.py.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-045 [LOW] (catalogs_data/tracks.json) title/artist/genre are dead metadata and the ambience subsystem has no data and no UI trigger

- **Location**: `v1/data/tracks.json:20`
- **Execution phase**: F
- **Evidence**: No `get("title")`, `get("artist")`, or `get("genre")` anywhere in v1/scripts/ — no now-playing UI exists. `"ambience": []` is empty, no UI code emits ambience_toggled (grep in scripts/ui/ and scripts/menu/ returns nothing), and the fallback lookup dir in audio_manager.gd:330-334 (res://assets/audio/ambience/) does not exist on disk. The ambience code path in audio_manager.gd:310-355 is fully unreachable dead weight fed by an empty catalog array.
- **Action**: Keep title/artist for a future now-playing label (cheap) but either populate ambience with at least one entry + a settings toggle, or note the subsystem as deferred so the empty array stops looking like missing data.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-046 [LOW] (ci_export_health/ci/pixelart-validator) validate_pixelart_deliverables emits 13 warnings (missing .aseprite twins, off-palette colors, 6 undelivered cat animations)

- **Location**: `ci/validate_pixelart_deliverables.py:?`
- **Execution phase**: I
- **Evidence**: Exit 0 (non-blocking, CI job validate-pixelart passes) but reports: cat_sleep.png and cat_walk.png each missing their aseprite_pets/ .aseprite twin AND each contain 3 colors outside the 24-color palette (#3a2e52, #c8c8dc, #1a1626, #f0e060); 6 pet animations declared but not delivered (Task 5): cat_annoyed, cat_jump, cat_licking, cat_play, cat_roll, cat_surprised. extract_palette.py --check passes (palette in sync, 24 colors). Summary line: 'OK 0 character folder(s) + pets checked, 13 warning(s)'.
- **Action**: Track under Phase G (missing assets): deliver the 6 cat animation PNGs + .aseprite sources, quantize cat_sleep/cat_walk to the palette or add the 4 colors to the palette deliberately, and add the missing .aseprite twins.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-047 [LOW] (features_todo/character-select) character_select.gd is functional but unreachable dead code with the current 1-character catalog

- **Location**: `v1/scripts/menu/character_select.gd:12`
- **Execution phase**: F
- **Evidence**: Read in full (213 lines): the screen works if reached — UI is built in code, prev/next wrap correctly (L143-150), preview instantiates res://scenes/male-old-character.tscn (exists on disk, matches room_base.gd:14), start sets GameManager.current_character_id and emits character_selected which main_menu consumes (main_menu.gd:124-133). But main_menu.gd:100-102 bypasses it whenever `characters.size() <= 1`, and characters.json contains exactly 1 entry (male_old) — so it is never shown in any real session and is untested at runtime. Minor latent issues for when it activates: KEY_ENTER handled but not KEY_KP_ENTER (L200), and `const CHARACTER_SCENE` (L7) is self-referential and unused. game_manager.gd:122 `# TODO: Phase 5 — add character selection UI and outfit system`: change_character() exists but no outfit UI anywhere.
- **Action**: Keep the gate (intentional per main_menu.gd:97-99 comment) but add a headless test that forces a 2-entry catalog through the select flow so the path stays green; add KEY_KP_ENTER; drop the unused const. Outfit system stays Phase 5 backlog — do not claim it.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-048 [LOW] (features_todo/tutorial) Tutorial has 8 steps, not the claimed 9; all steps verified completable

- **Location**: `v1/scripts/menu/tutorial_manager.gd:43`
- **Execution phase**: F
- **Evidence**: README.md:99 claims "Tutorial 9 step signal-driven". `_define_steps` (tutorial_manager.gd:43-116) defines exactly 8: welcome(auto 3s), movement(wait_for_input), open deco panel(panel_opened/deco), place decoration(decoration_placed), select decoration(decoration_selected), open profile(panel_opened/profile), close panel(panel_closed), final(auto 4s). Every awaited signal exists in signal_bus.gd (L26,32,33) and has real emitters (panel_manager.gd:62,114; decoration_system.gd:152; drop-zone placement). Safety nets confirmed: STEP_TIMEOUT 30 s auto-advance (L295), skip button (L179), replay from settings (settings_panel.gd:85-92), and main_menu resets tutorial_completed on New Game (main_menu.gd:95-96). Feature is solid; only the count in docs is wrong.
- **Action**: Correct README.md:99 to "Tutorial 8 step" (or add the intended 9th step, e.g. mood-slider introduction, which would also help badge discoverability).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-049 [LOW] (features_todo/mess-system) Mess loop works end-to-end but all 6 mess visuals are runtime-drawn placeholder circles

- **Location**: `v1/scripts/rooms/mess_node.gd:97`
- **Execution phase**: F
- **Evidence**: Loop verified: spawn via MessSpawner timer, clean emits coins (`SignalBus.coins_changed.emit(...)` + `SaveManager.inventory_data["coins"] += clean_reward`, mess_node.gd:74-75) and stress relief via StressManager._on_mess_cleaned (stress_manager.gd:36,77). However every entry in mess_catalog.json has `"sprite_path": ""` (lines 9,19,29,39,49,59), so mess_node.gd:97-106 falls back to `_make_placeholder_texture` — a flat colored circle with outline. README.md:96 sells "Mess system: oggetti sporchi si accumulano" without noting the art is placeholder.
- **Action**: Phase G: produce 6 mess pixel-art sprites (dust, crumbs, stain, etc.), fill sprite_path in mess_catalog.json; validate_sprites CI job will then cover them.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-050 [LOW] (i18n/i18n/hardcoded-strings) Mood label displays raw internal English level ids regardless of locale

- **Location**: `v1/scripts/ui/game_hud.gd:177`
- **Execution phase**: F
- **Evidence**: game_hud.gd:102 initializes _mood_label.text = "calm" and :177 assigns _mood_label.text = level, where level is the internal id from stress_manager.gd:9-11 (LEVEL_CALM="calm", LEVEL_NEUTRAL="neutral", LEVEL_TENSE="tense"). Internal state ids are leaked directly into the HUD and are untranslatable.
- **Action**: Map ids to keys (MOOD_CALM/MOOD_NEUTRAL/MOOD_TENSE) in both .po files and render tr("MOOD_" + level.to_upper()); keep the ids themselves untouched as state values.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-051 [LOW] (i18n/i18n/language-switch) Inconsistent language defaults across code paths: "en" vs "it" vs project fallback "it"

- **Location**: `v1/scripts/ui/profile_hud_panel.gd:224`
- **Execution phase**: F
- **Evidence**: save_manager.gd:45 and :463 default "language": "en"; settings_panel.gd:139 get_setting("language", "en"); profile_hud_panel.gd:224 and :234 get_setting(LANGUAGE_SETTING_KEY, "it"); project.godot:92 locale/fallback="it". On a fresh profile the settings dropdown claims EN, the HUD badge claims IT, and tr() actually resolves per OS locale with it fallback — three sources of truth that can all disagree.
- **Action**: Define one canonical default (Constants, e.g. DEFAULT_LANGUAGE := "it" to match project fallback) and use it in save_manager, settings_panel, and profile_hud_panel.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-052 [LOW] (i18n/i18n/test-coverage) Zero i18n test coverage in the 111-test harness

- **Location**: `v1/tests/README.md:5`
- **Execution phase**: F
- **Evidence**: No test in v1/tests/ touches TranslationServer, tr(), or the .po files (grep hits were false positives: polygon/position; README mentions 'preflight locale' only as CI container locale). Nothing guards key parity between it.po and en.po, catches dead/missing keys, or verifies set_locale round-trip.
- **Action**: Add a headless test that (a) parses both .po files and asserts identical msgid sets, (b) greps tr("...") call sites and asserts every used key exists, (c) asserts TranslationServer.get_loaded_locales() contains it+en and tr() of a sentinel key differs across set_locale("it")/set_locale("en").
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-053 [LOW] (runtime_boot/test-isolation) All ERROR/WARN in user:// logs are deep_test fixtures written against the REAL user profile/save path

- **Location**: `/data/Projectwork/scripts/deep_test.sh:?`
- **Execution phase**: E
- **Evidence**: Aggregating every session_*.jsonl in ~/.local/share/RelaxRoom/logs yields exactly 4 distinct ERROR/WARN signatures, 57 occurrences each (57 harness executions), all test-induced, none produced by today's four boot probes (today's boot sessions are INFO-only): (1) WARN SaveManager 'Primary save corrupt or missing, trying backup'; (2) WARN SaveManager 'HMAC mismatch — save file may be tampered' with context path 'user://save_data.json'; (3) WARN SaveManager 'Save from newer version' (context app/save versions); (4) ERROR PanelManager 'Unknown panel name' with context name 'does_not_exist' (clearly a negative test). Signature (2) referencing user://save_data.json shows the test harness tampers/exercises SaveManager against the real profile's save path — tests and real gameplay share ~/.local/share/RelaxRoom (same cozy_room.db, save_data.json, test_results.jsonl side by side), so a test run can clobber a real save and pollutes the production log/DB surface.
- **Action**: Run the test harness with an isolated user dir (godot4 --headless --user-data-dir or a dedicated custom_user_dir override via feature tag/env) so negative-test fixtures never touch the real RelaxRoom profile; then real user:// ERROR/WARN entries become actionable signal instead of noise.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-054 [LOW] (runtime_boot/audio-lifecycle) Every run exits with ObjectDB leak WARNING + '1 resources still in use' ERROR (music playback)

- **Location**: `/data/Projectwork/v1/scripts/autoload/audio_manager.gd:440`
- **Execution phase**: E
- **Evidence**: Every boot (including plain menu boot) ends with 'WARNING: ObjectDB instances leaked at exit' and 'ERROR: 1 resources still in use at exit'. --verbose identifies: 'Leaked instance: AudioStreamPlaybackWAV:9223372098913699421 - Reference count: 1', 'Leaked instance: AudioStreamWAV:...', 'Resource still in use: res://assets/audio/music/mixkit-light-rain-loop-1253.wav (AudioStreamWAV)' — the menu music track from /data/Projectwork/v1/data/tracks.json:7. AudioManager already has cleanup (audio_manager.gd:435-437 '_notification: NOTIFICATION_WM_CLOSE_REQUEST or NOTIFICATION_PREDELETE -> _release_streams()'; :440-446 stops players and nulls streams), but PREDELETE fires during SceneTree teardown when the AudioServer mix loop no longer runs, so the active AudioStreamPlaybackWAV held by AudioServer is never freed before the ObjectDB exit check. Exit-time-only; no runtime/user impact; not headless-specific (same order applies on desktop quit). Cost: every log and CI run carries a fixed WARNING+ERROR pair that can mask genuinely new leaks.
- **Action**: Stop music before quit while the mix loop is still alive: connect AudioManager to SceneTree.tree_exiting (or intercept the quit path) calling _release_streams(), then allow one audio mix pass before quit; if the leak persists (known Godot teardown behavior for playing streams at quit), whitelist this exact signature in test/CI log assertions so new leaks are not hidden behind it.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-055 [LOW] (runtime_boot/log-hygiene) AppLogger session jsonl files accumulate unbounded in user://logs (214 files, 83 zero-byte)

- **Location**: `/data/Projectwork/v1/scripts/autoload/logger.gd:?`
- **Execution phase**: E
- **Evidence**: ~/.local/share/RelaxRoom/logs contains 214 session_*.jsonl files, 83 of them zero-byte, dating back to 2026-04-16. AppLogger creates one session_YYYYMMDD_HHMMSS.jsonl per boot and never prunes; Godot's own godot.log rotation (5-file cap) does not cover these. Each of today's 7 probe runs added a new file. On a player machine this grows forever (~1 file per launch), and zero-byte files are created even when nothing beyond autoload INFO is ever written.
- **Action**: In Logger startup, prune session_*.jsonl beyond the newest N (e.g. 20), and lazily create the file on first write to avoid zero-byte files. Mirror the existing engine log rotation policy.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-056 [LOW] (scenes_integrity/uncommitted-diff/theme) cozy_theme.tres diff is resave restructure, no stylebox lost — KEEP (only comments are gone)

- **Location**: `v1/assets/ui/cozy_theme.tres:1`
- **Execution phase**: J
- **Evidence**: Property-level comparison of HEAD vs working tree (parsed both, matched every sub_resource id and [resource] key): zero styleboxes removed, zero property values changed. The 220-line diff is (a) all `; ---` comment headers stripped (Godot never preserves comments on resave), (b) sub_resources and [resource] keys re-emitted in alphabetical order, (c) 4 ext_resources (white.png, white_pressed.png, brown_pressed.png, grey_inlay.png) gained proper uid= attributes — an improvement that stabilizes references, and (d) the single semantic change: `default_font_color = Color(0.95, 0.9, 0.8, 1)` deleted from [resource]. That key is not a valid `Theme` property (Theme exposes default_base_scale/default_font/default_font_size only), so the committed line was a silent no-op the editor discarded — no visual change; per-control font colors (Button, Label, LineEdit, etc.) are all preserved. Only real loss: the organizational comments.
- **Action**: KEEP and commit. If the comments are valued as documentation, move them to a sibling note outside the .tres (they cannot survive any future editor save).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-057 [LOW] (scenes_integrity/uncommitted-diff/project-config) project.godot diff is pure Godot resave normalization — KEEP

- **Location**: `v1/project.godot:15`
- **Execution phase**: J
- **Evidence**: Every hunk is editor rewrite churn: keys inside [application] reordered (config/version moved after description, features/icon after custom_user_dir), [internationalization] section relocated to alphabetical position before [rendering] with identical content (`locale/translations=PackedStringArray("res://locale/it.po", "res://locale/en.po")`, `locale/fallback="it"` preserved verbatim), and `window/per_pixel_transparency/allowed=false` dropped because false is the engine default (no-op removal). No setting changed value; translations, autoloads, viewport 1280x720, stretch mode all intact.
- **Action**: KEEP — commit it (alone or with the theme file) so the editor stops re-normalizing on every open. Reverting is equally safe but the churn will come back the next time anyone opens the project in the 4.6 editor.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-058 [INFO] (assets_gap/assets/verified-ok) Everything else verified clean: 129/129 decorations, windows, forest layers, cozy_theme textures, zero orphan .import files

- **Location**: `/data/Projectwork/v1/data/decorations.json:1`
- **Execution phase**: G
- **Evidence**: Full census results: decorations.json 129/129 sprite_path files exist (57 kenney_furniture_cc0, 20 sprites/rooms/Individuals, 33 sc_indoor_plants_free, 13 bongseng, 3 room windows, 1 pet — no placeholder-dir paths). tracks.json 2/2 WAVs exist. Window scenes window1-3.tscn → assets/room/window1-3.png all exist (32x64/48x64/64x64 real pixel art, not placeholders). window_background.gd's 8 hardcoded forest layer files all exist (12 layers on disk). cozy_theme.tres: all 10 Kenney 9-slice textures exist; the uncommitted diff (git diff HEAD) only adds uid= attributes to 4 ext_resources, reorders styleboxes, adds a StyleBoxFlat separator and btn_disabled modulate — no new texture paths introduced. Orphan .import check: 347 .import files under v1/assets, 0 orphans; repo-wide (excluding .godot/) also 0. project.godot icon (icon.svg) and theme path OK. pets: all 5 PNGs exist including cat_void_iso.png used by scenes/cat_void_iso.tscn.
- **Action**: No action needed for these areas; safe to scope Phase G exclusively to the items above (joystick pads, 6 mess sprites, badge/emoji strategy, ambience audio, yellow-shirt completion, README sync, credits screen).
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-059 [INFO] (catalogs_data/decorations.json) Full 129-sprite + 13-category verification clean (exceeded the 20-sample ask)

- **Location**: `v1/data/decorations.json:2`
- **Execution phase**: F
- **Evidence**: Verified ALL 129 sprite_paths exist on disk with .import sidecars (not just a 20-sample), 129 unique ids, all placement_type in {floor,wall,any}, all item_scale positive. deco_panel.gd:63-119 builds its category list dynamically from the catalog's `categories` array (no hardcoded 13-list to drift): 13 categories, `pets` hidden:true (deco_panel.gd:78 skips it) leaving 12 visible, each with >=1 item — counts: beds 11, desks 7, chairs 14, wardrobes 11, windows 6, wall_decor 3, potted_plants 19, plants 14, accessories 17, room_elements 9, tables 12, doors 5, pets 1. pet_cat_void is unreachable via the panel but restorable from saves via room_base.gd:298-303 _find_item_data — consistent. One cosmetic oddity: the asset file 'small table wood leftt.png' (double-t typo) matches the catalog string exactly (decorations.json:90), so it loads fine; renaming would require touching both.
- **Action**: Nothing blocking. Optionally rename the 'leftt' asset + catalog string in one commit for hygiene, and add an 'every visible category has >=1 item' assertion to validate_json_catalogs.py so a future empty category can't render a dead header.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-060 [INFO] (catalogs_data/rooms.json themes) Task Q4 answer: rooms.json themes contain no asset paths at all — pure color overlays, all 3 valid

- **Location**: `v1/data/rooms.json:7`
- **Execution phase**: F
- **Evidence**: The 3 themes (modern/natural/pink) carry only id/name/wall_color/floor_color as 6-digit hex without '#'. Consumer is main.gd:104-116: `Color(wall_hex)` — the Godot 4 Color(String) constructor accepts un-prefixed HTML hex, so "2a2535" is valid. main.gd fallback defaults ("2a2535"/"3d3347") exactly match the modern theme, so a missing theme degrades to modern colors. There are no wall/floor texture paths to verify; constants THEME_MODERN/NATURAL/PINK all cross-ref cleanly (CI PASSED 5/5).
- **Action**: No action needed for correctness. If themed wall/floor textures are planned (Phase G), add explicit texture path fields then and extend validate_sprite_paths.py to cover rooms.json.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-061 [INFO] (ci_export_health/ci/validators-local-run) All 10 CI Python validators pass locally (exit 0); gdlint clean; version sync verified

- **Location**: `.github/workflows/ci.yml:31`
- **Execution phase**: I
- **Evidence**: ci.yml defines 12 jobs: lint, validate-json, validate-sprites, validate-crossrefs, validate-db, validate-button-focus, validate-version, validate-no-keystore, validate-signals, validate-pixelart, smoke-headless, deep-tests. Local runs with exact CI invocations, all exit 0: validate_json_catalogs.py v1/data (4 catalogs OK); validate_sprite_paths.py v1 (157 paths); validate_cross_references.py (5 cross-refs); validate_db_schema.py schema.gd (10 CREATE TABLE valid); validate_button_focus.py v1/scripts (all Button.new() have focus_mode); validate_version_sync.py (VERSION=1.0.0 == project.godot:19 == preset file/product_version:30-31 == Android version/name:110 == constants.gd APP_VERSION); validate_no_keystore.py (1065 files, none tracked); validate_signal_count.py --min 40 (48 signals, no dupes); extract_palette.py --check (24 colors in sync); validate_pixelart_deliverables.py --check-palette (0 errors/13 warns). gdtoolkit 4.5.0 installed; gdlint v1/scripts/ v1/tests/ = 'Success: no problems found'. Of the 12 CI jobs, the only locally-reproducible failures are lint (gdformat step) and deep-tests (3 panel tests) — reported separately above. No leftover godot processes after runs.
- **Action**: None — baseline is healthy except the two red jobs reported as HIGH items.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-062 [INFO] (features_todo/tech-debt) Deferred B-033 module splits acknowledged in supabase_client and save_manager — no user impact

- **Location**: `v1/scripts/autoload/supabase_client.gd:7`
- **Execution phase**: F
- **Evidence**: Remaining TODO census beyond items above: supabase_client.gd:7 "TODO B-033 post-demo: split auth + sync + session persistence in moduli" and save_manager.gd:5 "TODO B-033 post-demo: split helpers (_migrate, _apply_save_data, ...)". These are the two monoliths left after local_database.gd was split into 9 repos (done, per CHANGELOG). Pure maintainability debt, correctly labeled post-demo. Full marker census otherwise: game_manager.gd:122 (Phase 5, covered above), supabase_mapper.gd:61 (covered above), settings_panel.gd:57/172 + profile_hud_panel.gd:5-9,95 (i18n/placeholders, covered above), mess_node.gd:97-106 (placeholder art, covered above), character_select.gd:86 (benign preview-root comment). No FIXME/HACK/XXX markers exist.
- **Action**: Schedule both splits in the post-demo refactor phase (Phase E/F); no doc or claim change needed.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-063 [INFO] (features_todo/docs-staleness) profile_hud_panel.gd header still labels profile image and badge row as post-demo placeholders — both are implemented

- **Location**: `v1/scripts/ui/profile_hud_panel.gd:5`
- **Execution phase**: F
- **Evidence**: Header doc (L5-6) says "Label placeholder 'Immagine profilo' (T-R-015c post-demo)" and "Label placeholder 'Badge' (T-R-015d post-demo)", and L9 says "mood ... effects post-demo". The code below contradicts all three: profile image button opens a FileDialog and loads user://profile_image.png into a TextureRect (L55-73, L168-179 with emoji fallback); badge row renders unlocked/locked emoji from BadgeManager (L85-93, _refresh_badges L264+); mood effects are fully live via MoodManager. Stale comments will mislead the Phase F implementer into re-building finished features.
- **Action**: Update the class docstring to reflect implemented state; only the language toggle (L95-98) remains genuinely deferred.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-064 [INFO] (i18n/i18n/docs-accuracy) Stale WIP comments overstate i18n coverage ("~16 tr() passages"; auto_translate claim false)

- **Location**: `v1/scripts/ui/settings_panel.gd:56`
- **Execution phase**: F
- **Evidence**: settings_panel.gd:56-57 comment says "solo ~16 passaggi con tr() cambiano lingua al momento" — actual count is 8 tr() call sites (7 unique keys), all in profile_hud_panel.gd. settings_panel.gd:169-172 claims nodes with text set to "UI_KEY" re-translate via auto_translate — no such node exists in any .tscn (grep verified), so the described partial-live-switch behavior does not exist at all.
- **Action**: Update both comments when doing the i18n pass so the next maintainer doesn't trust a mechanism that isn't wired.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-065 [INFO] (runtime_boot/engine-noise) Verbose-only 'Unrecognized output string misc2' gamepad-mapping notices are engine artifacts

- **Location**: `/data/Projectwork/v1/project.godot:?`
- **Execution phase**: E
- **Evidence**: Verbose boots print 3x 'Unrecognized output string "misc2" in mapping:' for Horipad Steam (x2) and Nintendo Switch 2 Pro Controller entries — Godot 4.6's bundled SDL gamecontroller DB contains fields newer than its parser. Engine-side, only visible with --verbose, zero project impact. Similarly, the 'Orphan StringName: ...' list (41-42 entries) at verbose exit is downstream of the audio playback leak plus normal static teardown, not a project defect.
- **Action**: No action; do not spend fix-phase effort here. Exclude these patterns from any automated log-scanning gates.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-066 [INFO] (runtime_boot/runtime-boot) All four headless boots clean: no parse/script/missing-resource errors

- **Location**: `/data/Projectwork/v1/scenes/main/main.tscn:?`
- **Execution phase**: E
- **Evidence**: godot4 4.6.stable headless runs of default boot, res://scenes/main/main.tscn, res://scenes/menu/auth_screen.tscn, res://scenes/menu/character_select.tscn all completed with zero parse errors, zero missing-resource warnings, zero script errors. main.tscn direct load exercised the full gameplay path: 'Helpers: floor_polygon_initialized {vertices:4}', 'RoomBase: pet_spawned {variant: simple}', 'Main: Scene initialized, HUD buttons wired', 'Tutorial: Tutorial started'. auth_screen and character_select instantiate silently (their scripts emit no _ready logs) and run standalone without an active session/character without erroring. Uncommitted edits to project.godot / main.tscn / cozy_theme.tres do not break boot.
- **Action**: No action needed; treat this as the verified runtime baseline for Phase A. Any fix phases can re-run these four probes as a cheap regression gate.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-067 [INFO] (scenes_integrity/uncommitted-diff/ci-guard) DropZone focus_mode=0 removal and layout_mode 1->3 do NOT trip validate-button-focus and are behavior-neutral

- **Location**: `ci/validate_button_focus.py:23`
- **Execution phase**: J
- **Evidence**: ci/validate_button_focus.py only scans `Button.new()` occurrences in v1/scripts/**/*.gd (BUTTON_NEW_RE at lines 23-25, rglob('*.gd') at line 32) — it never parses .tscn files, so the scene edit cannot trip the CI job. Semantically: DropZone is a plain `Control` (main.tscn:61) whose focus_mode default IS FOCUS_NONE (0), so the editor pruned a default-valued property — zero behavior change; the B-001/B-003 concern (Button default FOCUS_ALL stealing ui_* navigation) does not apply to Control. layout_mode 1->3 (LAYOUT_MODE_UNCONTROLLED) is the correct serialization for a Control parented to a CanvasLayer in Godot 4.x — normalization, not damage. All three HUD Buttons (MenuButton/DecoButton/ProfileButton, main.tscn:81-97) retain explicit focus_mode = 0.
- **Action**: No action needed on this hunk. Adjacent note (do not fix unasked): if scene-level focus_mode regressions matter, validate_button_focus.py could grow a .tscn pass that requires `focus_mode = 0` on Button nodes in scenes — currently only runtime-created buttons are guarded.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-068 [INFO] (scenes_integrity/uncommitted-diff/scene-format) unique_id attributes are Godot 4.6 scene-format churn, not corruption

- **Location**: `v1/scenes/main/main.tscn:81`
- **Execution phase**: J
- **Evidence**: HEAD already carries 16 `unique_id=` attributes (e.g., DecoButton had one, main.tscn HEAD; MenuButton was the only node missing it). The uncommitted diff adds exactly one: `[node name="MenuButton" ... unique_id=257583661]` (main.tscn:81) — the 4.6 editor back-fills ids on nodes that lack them at resave. Working tree has 17 ids, all format-consistent random positive ints, zero duplicates (verified with sort|uniq -d). This is harmless serialization churn; no node names, parents, or types changed.
- **Action**: None. If main.tscn is fully reverted per the HIGH finding above, the MenuButton id simply gets re-assigned (a different random value) on the next intentional editor save — cosmetically noisy in future diffs but functionally irrelevant.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-069 [INFO] (scenes_integrity/orphan-scan) cat_void.tscn, cat_void_iso.tscn, male-old-character.tscn are NOT orphans — all string-loaded

- **Location**: `v1/scripts/rooms/room_base.gd:20`
- **Execution phase**: J
- **Evidence**: v1/scripts/rooms/room_base.gd:20-21 loads `res://scenes/cat_void.tscn` ("simple") and `res://scenes/cat_void_iso.tscn` ("iso"); v1/scenes/male-old-character.tscn is referenced four ways: main.tscn:6 (PackedScene ext_resource), v1/scripts/menu/character_select.gd:16, v1/scripts/rooms/room_base.gd:14, and v1/tests/integration/test_input.gd:8. Related: v1/data/decorations.json:174 references the cat via sprite `res://assets/pets/cat_void_simple.png` (exists). Caveat worth noting: all references except main.tscn's are raw string paths, invisible to Godot's dependency/uid tracker — moving these scenes out of v1/scenes/ root (e.g., into scenes/characters/) would break them silently at runtime.
- **Action**: No deletion. If the v1/scenes root is ever tidied, update the string paths in room_base.gd, character_select.gd and test_input.gd in the same change, and add them to ci/validate_cross_references.py coverage if not already checked.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

### G-070 [INFO] (test_failures/ui/panel-lifecycle) Adjacent latent issue (flag only): shared _tween can cancel a pending queue_free

- **Location**: `v1/scripts/ui/panel_manager.gd:56`
- **Execution phase**: H
- **Evidence**: open_panel() and close_current_panel() share one `_tween` field and both kill any running tween (panel_manager.gd:56-58 and 102-104). Any code path that starts a new tween while a close-fade is pending would cancel that fade's tween_callback and leak the fading panel in the tree (invisible mouse_filter=IGNORE node until scene teardown, consistent with the 'CanvasItem RIDs leaked' warnings at test exit). At current HEAD this is mostly masked because the swap path goes through _close_immediate(), but the root-cause fix changes that flow — hence the recommendation in the root-cause item to give the close fade a panel-owned tween (`closing_panel.create_tween()`). Not fixing anything beyond that here per scope discipline.
- **Action**: Handle as part of the root-cause fix (panel-owned close tween); no separate change.
- **Acceptance**: action executed and verified (test, validator, or headless run as appropriate to the item); no regression in the 111-test suite.

---

# PART IV — PHASE PLAYBOOKS

Every phase ends with: `gdformat v1/scripts && gdlint v1/scripts && ./scripts/smoke_test.sh && ./scripts/deep_test.sh` green (plus phase-specific checks). Items reference register IDs (V-xxx / G-xxx) via file:line anchors in Parts II–III.

## Phase C — Data-integrity CRITICALs + error-signal vocabulary

### C.1 SignalBus failure vocabulary (prerequisite for every other C/D item)
File: `v1/scripts/autoload/signal_bus.gd`. Add typed signals:

```gdscript
signal save_failed(reason: String)
signal save_integrity_violation(path: String)
signal sync_error(operation: String, reason: String)
signal sync_payload_corrupted(queue_id: int, preview: String)
signal catalog_load_failed(path: String, reason: String)
signal db_error(context: String, reason: String)
signal save_integrity_unavailable()
```

Wiring: `v1/scripts/main.gd` connects each to ToastManager with severity colors (error = red, warn = amber). Toast strings via `tr()` keys added to both `.po` files in the same commit (`TOAST_SAVE_FAILED`, `TOAST_SAVE_TAMPERED`, `TOAST_SYNC_ERROR`, `TOAST_DB_ERROR`, `TOAST_CATALOG_ERROR`). Listeners disconnect in `_exit_tree()` (constraint 4). CI `validate-signals` still passes (≥ 40, no dupes).

### C.2 save_manager.gd atomic-write truthfulness (V: 4.1.2-L169/L174/L152/L161)
Order inside `save_game()`:
1. After `store_string` → `var werr := file.get_error()`; non-OK → abort, `save_failed.emit("temp_write")`, keep `_is_saving` handling coherent.
2. Backup step: if primary exists and backup copy fails → **abort the save** (never overwrite without durable backup), `save_failed.emit("backup")`.
3. Rename: retry `rename_absolute` 3× (frame-deferred between attempts). Fallback `copy_absolute` **checked**; after copy, re-read file and compare HMAC with in-memory value; mismatch → `save_failed.emit("verify")` + keep temp for forensics.
4. `save_completed` emits only on verified success. All failure paths emit `save_failed` exactly once.

### C.3 local_database.gd transaction honesty (V: 4.1.4-L113)
`_on_save_requested`: check `BEGIN` return — on failure log + `db_error.emit("begin", ...)` + return without claiming success. On any repo write failure → `ROLLBACK` + `db_error`. Check `COMMIT` return; failure → forced `ROLLBACK` + `db_error`. Success path emits new `save_db_mirror_completed(ok: bool)`; SaveManager correlates (C.5).

### C.4 schema.gd migration safety (V: 4.1.11-L195 + 4.1.11-L188)
Migration 1 rewritten: exact-column check via `PRAGMA table_info('characters')` (kills the substring match), whole migration wrapped in BEGIN/COMMIT with per-statement return checks, backup row-count compared to source row-count **before** any DROP; mismatch → ROLLBACK + hard init error. Same pattern applied to migration 2/3 blocks.

### C.5 inventory_repo.gd transactional save (V: 4.1.16-L58)
Wrap DELETE+INSERT loop in `SAVEPOINT inventory_save` / `RELEASE` with `ROLLBACK TO` on any statement failure, so the repo is safe both inside and outside the outer transaction.

### C.6 SaveManager ⇄ SQLite dual-write correlation (V: 4.1.2-L177, folded into C phase because it gates the meaning of `save_completed`)
Replace fire-and-forget `save_to_database_requested` emission with synchronous call `LocalDatabase.apply_save(payload) -> bool` (new façade method wrapping `_on_save_requested` logic and returning transaction outcome). `save_completed` requires JSON write verified **and** DB apply true; else `save_failed` with reason `"db_mirror"`. Comment B-016 rewritten to describe the real guarantee.

### C.7 Real PBKDF2-HMAC-SHA256 (V: 4.4.1)
`v1/scripts/autoload/auth_manager.gd`:
- New `_pbkdf2_hmac_sha256(password: String, salt: PackedByteArray, iterations: int, dk_len: int) -> PackedByteArray` implementing RFC 8018 §5.2 with `Crypto.hmac_digest(HashingContext.HASH_SHA256, key, data)`: per-block `U_1 = HMAC(pw, salt‖INT_32_BE(i))`, `U_j = HMAC(pw, U_{j-1})`, `T_i = XOR(U_1..U_c)`.
- New stored format `v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>` (iter = 100_000, salt 16 B random, dk 32 B).
- Verify path accepts v4 natively; v1/v2/v3 verified with legacy routine then transparently re-hashed to v4 on successful login (existing migration pattern).
- Old helper renamed `_legacy_salted_sha256_loop` — no longer claims PBKDF2 anywhere.
- README/CHANGELOG crypto claims corrected in the same commit.
- Unit vectors: validate implementation against 3 known PBKDF2-HMAC-SHA256 test vectors (computed with Python `hashlib.pbkdf2_hmac` and embedded in a new test module) in Phase H.

**Phase C exit criteria**: 5 CRITICAL register entries → FIXED; new signals visible in `validate-signals`; suite green; a forced save-failure manual probe (read-only FS simulation via test) produces a toast, not `save_completed`.

## Phase D — HIGH defects

### D.1 Supabase sync engine repair (V: 4.1.1-L501/L297/L300/L422/L161 + G sync)
`supabase_client.gd` — one cohesive rework of the push pipeline:
1. **Rid unification**: every wire call's returned rid becomes the tracking key. `_pending_requests[rid] = {"kind": "queue"|"push", "queue_id": id?}`. `_handle_sync_response` routes on `upsert_`/`delete_`/`fetch_` prefixes; `_get_queue_id_from_rid` replaced by the map.
2. **Empty-rid handling**: `""` return (not-ready/rejected) → count as failed item immediately; never park in pending.
3. **Watchdog**: 30 s Timer during sync; on expiry `_finish_sync(false)` + clear pending + `sync_error.emit("watchdog", ...)`.
4. **401 replay**: buffer `{method, table, query, body, rid, kind}` on 401; after successful `_apply_auth_response` replay once; on refresh failure fail-fast all buffered + `sync_error`.
5. **Missing-table kill-switch**: `Constants.SUPABASE_ALLOW_MISSING_TABLES := true` (documented); `false` path routes to `AppLogger.error` + `sync_error`.
6. **Corrupt-payload DLQ**: parse failure → WARN log {queue_id, table, len, head 32} + `sync_payload_corrupted` + move row to new `sync_dead_letter` table (schema migration + repo method) instead of delete. Same for retry-exhausted.
7. **Session persistence**: plaintext fallback checked; double-failure → `AppLogger.error("session_persist_double_failure")`, in-memory session retained; plaintext fallback no longer writes `refresh_token` (session survives process lifetime only — documented downgrade).
8. `_process_sync_queue` response handling deferred (`call_deferred`) to kill re-entrancy (V: 4.8.4).

### D.2 supabase_http.gd pool hygiene (V: 4.5.1, 4.5.3)
Remove the mismatched `disconnect` (CONNECT_ONE_SHOT + synthetic emit already covers the error path); JSON parse failure of non-empty body → `body = null` + `error` field with 100-char preview instead of raw-text type lie.

### D.3 Panel toggle semantics (G-test root cause; V: 4.3 latent tween)
`panel_manager.gd`: state (`_current_panel`, `_current_panel_name`) clears and `panel_closed` emits **at close-start**; the fade tween + `queue_free` operate on a captured `closing_panel` local only. B-001 focus release preserved. Dedicated per-close tween variable (kills shared `_tween` cancel-vs-queue_free hazard). `_close_immediate` aligned. Tests in Phase H then pass as originally written.

### D.4 Audio: mood actually drives music (G audio HIGH ×2; V: 4.1.5-L137/L96)
`audio_manager.gd`:
- Fix the self-emit guard so `_on_mood_changed` performs the crossfade track swap when the target mood's track differs (root-cause the structural no-op at :402).
- `tracks.json`: `rain_thunder` gains `"stormy"` in its moods array (fixes zero-track stormy) — catalog edit here because it is the functional fix; dead `MOOD_AUDIO_TRACK_STORM` constant removed (V/G constants).
- `_load_tracks()` validates entries once (path exists, moods array non-empty, id unique); malformed → WARN + skipped.
- Shuffle uses `_mood_rng`; `crossfade_to_mood_track` renamed `apply_mood_scalar` (callers updated).

### D.5 Logger truthfulness (V: 4.1.3-L253/L133; 4.9.5 folded)
- Open with `READ_WRITE` + `seek_end` (append semantics); rotation names gain a monotonic counter suffix to kill same-second collisions.
- Buffer overflow: rate-limited `push_warning` on first drop + `dropped_count` entry on next successful flush.
- Dedicated 500-slot ERROR ring retained across overflow storms, flushed with the normal buffer.

### D.6 DB layer returns + redaction (V: 4.1.12-L44, 4.1.13-L28/L66, 4.1.19, 4.3-db-error)
- `db_helpers.gd`: on failure log `db.error_message`, SQL preview 400 chars, bindings replaced by `{count, types}` — never raw values; every failure emits `SignalBus.db_error`.
- `accounts_repo.gd`: UPDATE/INSERT returns checked; failure → return −1/empty; `create_account` pre-checks username conflict and fail-explicit.
- `sync_queue_repo.gd`: 64 KB payload cap (reject + WARN), `increment_retry(queue_id)` implemented and called from the sync engine, `ORDER BY created_at, id` tiebreaker.

### D.7 Auth rate-limit persistence (V: 4.4.2 + 4.2 wall-clock pair)
Schema migration: `accounts` gains `failed_attempts INTEGER DEFAULT 0`, `lockout_until_mono INTEGER DEFAULT 0` — per-username persistence via AccountsRepo helpers; lockout measured with `Time.get_ticks_msec()` for in-session checks plus persisted absolute deadline for cross-restart enforcement; counters reset on success. Injectable `_now_s()` seam for tests.

### D.8 Tutorial signal hygiene (V: 4.1.6-L264/L237)
Single stateful connection handle per step (no re-subscribe on filter reject); filter misses logged at DEBUG; the arbitrary `< 10` connection cap removed.

### D.9 Room/character/pet robustness (V: 4.1.8-L80, 4.1.10-L77, 4.1.9-L286/L101)
- `room_base.gd`: swap block guarded by `is_instance_valid`; nudge target post-processed through `Helpers.clamp_inside_floor`.
- `pet_controller.gd`: WILD movement clamped to floor polygon with direction reflection.
- `main_menu.gd`: `change_scene_to_file` return checked; `_transitioning` released only on confirmed change (scene_changed hook) with the 5 s timer as failure-detector emitting a toast; empty character catalog → hard error dialog instead of invented `"male_old"`.

### D.10 Profile image input validation (V: 4.1.7-L207)
10 MB size cap via `FileAccess.get_file_as_bytes().size()` pre-check + PNG/JPG magic-byte sniff before `Image.load_from_file`; failure toast; partial PNG cleanup on error.

### D.11 game_manager catalog failures visible (V: 4.2-gamemanager)
`_load_catalog` returns `null` on open/parse/type failure; caller logs ERROR + `catalog_load_failed.emit(path, reason)`; boot continues with empty dict but user sees toast (main scene) — silent-empty eliminated.

### D.12 Landing-page PARTIAL closures (V: 4.11.4a/b)
Team subpages: Lucide pinned + SRI; 3 remaining `emergentagent.com` CSS background URLs self-hosted under `docs/assets/`; SRI attributes on particles/AOS across all pages.

**Phase D exit criteria**: all 42 HIGH + 4 PARTIAL register entries FIXED (or explicitly re-classified with rationale); suite green; manual headless sync-cycle probe with a mock-invalid config shows clean OFFLINE handling, no stuck `_is_syncing`.

## Phase E — MEDIUM + LOW defects

Grouped batches (each a commit):
- **E.1 Type coercions + defaults**: `int()`/`bool()` explicit coercions (characters_repo genere, settings_repo ambience_enabled); `Constants.DEFAULT_PLAYLIST_MODE` single source; three call sites converge.
- **E.2 Save resilience extras**: backup ring ×3 dated; orphan `save_data.tmp.json` adoption on `_ready` (HMAC-verified); newer-version save → refuse apply, park as `save_data.newer.json`, toast; hex-key charset regex; `_save_dirty` flush-after-save chaining; `set_auto_accept_quit(false)` + quit-after-save-confirmed.
- **E.3 Auth polish**: username regex `^[A-Za-z0-9_.-]{3,24}$` + NFC normalize; legacy-salt verify logs deprecation WARN with counter; `_set_state` enum guard.
- **E.4 Supabase polish**: `_set_connection_state` central setter (asserts + emits); early-return config path emits OFFLINE; `refresh_jwt` empty-token → OFFLINE transition; empty-`eq.` delete guard in `delete_from_table`; `_is_relation_error` matches PG code `42P01`; JWT expiry anchored to `Time.get_ticks_msec()` delta; rid sentinel documented; `x-client-request-id` header.
- **E.5 Observability**: metrics counters (save_attempts, save_failures, sync_cycles, sync_failures, hmac_mismatches, http_timeouts) flushed as structured INFO every 5 min + at exit; session-id keeps full 32 bits; device-path redaction in log payloads; `user://logs` retention — delete sessions beyond newest 20 / 30 days at boot (fixes unbounded 214-file accumulation).
- **E.6 UI/room polish**: mood slider via `set_value_no_signal`; `_refresh_badges` deferred post-load; `Vector2.ZERO` pet-spawn sentinel → explicit `_character_pos_ready` flag; `has_signal` string guard → static reference; tutorial arrow bob rewritten `initial_y + sin(...)` with name-unique target validation; `Carica Partita` checks JSON **or** SQLite account.
- **E.7 rooms_deco single truth**: normalized `placed_decorations` becomes authoritative; JSON blob column kept write-through for save-file compatibility with a documented order; `remove_placed_decoration` returns `changes()`-based bool.
- **E.8 Supabase repo schema**: author `supabase/schema.sql` (5 tables + RLS by `auth.uid()`) + `supabase/README.md` reproducible-setup instructions.

**Exit**: all MEDIUM register entries FIXED/ACCEPTED-with-rationale; suite green.

## Phase F — Features, i18n, catalog hygiene

### F.1 i18n completion (G i18n ×16) — design
- **Key set**: ~120 keys, prefixed by surface: `UI_MENU_*`, `UI_HUD_*`, `UI_SETTINGS_*`, `UI_AUTH_*`, `UI_PROFILE_*`, `UI_DECO_*`, `UI_CHARSEL_*`, `TUTORIAL_STEP_1..8`, `TOAST_*`, `BADGE_<id>_NAME/DESC`, `MESS_<id>_LABEL`, `MOOD_LEVEL_*`, `CONFIRM_*`. Both `.po` files complete and key-parallel; dead keys pruned.
- **Static scene texts**: node `text` set to the key (Godot auto-translate handles swap); scripted strings via `tr()`.
- **Boot locale**: applied in `GameManager._ready` from settings repo (fallback `OS.get_locale_language()` → `it`), before first scene renders.
- **Live switch**: `language_changed` subscribers — HUD, open panel (rebuild), menu — plus `TranslationServer.set_locale` first; hidden language toggle re-enabled in settings.
- **Catalog locale fields**: badges + mess use `label_it`/`label_en` selected by locale helper `Helpers.locale_label(entry)`; decoration category display names get keys.
- **Consistency**: single default-language constant; `game_hud` mood label localized.

### F.2 Badge system completion (G features ×2)
- night_owl: 60 s repeating Timer in BadgeManager re-evaluates play-time badges.
- Lifetime counters: settings-table-backed `stat_total_coins_earned`, `stat_decos_placed_total` incremented at source events; badge thresholds read lifetime values; `supabase_mapper.total_earned` TODO resolved by the same counter.

### F.3 Character roster + reachable selection (G features/catalogs)
- `characters.json` cleaned to live schema; second entry `male_yellow` wired to the Phase-G palette-swap sheet set + new scene `scenes/characters/male_yellow.tscn` (duplicated from male-old-character with swapped SpriteFrames).
- `main_menu` flow: with 2 catalog entries, existing skip-if-single logic naturally routes through `character_select`; selection persisted via CharactersRepo; `game_manager` TODO(Phase 5) marker resolved; outfit system explicitly descoped in CHANGELOG (documented decision, no dead stub).

### F.4 Cloud pull sync (V: 4.13.5, G features HIGH)
`start_sync` becomes pull-then-push: fetch the 5 tables scoped `user_id=eq.<uid>`; rows applied via mapper when cloud `updated_at` is newer than local (last-write-wins); guarded by `Constants.SUPABASE_PULL_ENABLED := true`. README claim now truthful.

### F.5 Ambience subsystem activation (G assets/catalogs)
`tracks.json` ambience array gains 2 entries (Phase-G synthesized loops); AudioManager ambience player path wired to `ambience_enabled` setting; settings toggle exposed.

### F.6 Credits (G assets license)
Settings panel "Crediti" section (scrollable label): Eder Muniz forest (required credit), SoppyCraft, Thurraya, Kenney (CC0), Mixkit, team art. Key-translated.

### F.7 Catalog + validator hygiene (G catalogs)
Dead fields either wired (tracks title/artist shown as now-playing in settings) or removed with schema doc update; `mess_catalog` labels used in clean-toast; `ci/validate_json_catalogs.py` extended to badges + mess (schema + uniqueness + sprite existence).

**Exit**: language switch fully re-renders IT⇄EN at runtime; badges all reachably unlockable; 2 characters selectable; ambience audible; credits visible; validators green including new coverage.

## Phase G — Asset production (specs in PART V)

G.1 six mess sprites → `assets/room/mess/<id>.png` + catalog sprite_path fill.
G.2 joystick base+knob textures at the exact missing paths; scene uids re-pointed.
G.3 ambience loops `ambience_rain_soft.wav`, `ambience_fireplace.wav` (synthesized, seamless).
G.4 badge icons ×6 16×16 + profile placeholder 32×32.
G.5 project icon (SVG pixel grid) + 432×432 Android adaptive foreground/background PNGs; export_presets icon fields set.
G.6 male_yellow full sheet set via deterministic palette swap of male_old (shirt ramp → yellow ramp from project palette).
G.7 purge `_placeholder_temp/puny_characters_cc0`; `assets/room/README.md` rewritten to actual contents; pixel-art validator manifest updated to shipped deliverables (13 warnings → 0).

**Exit**: no runtime placeholder rendering paths reachable; `validate-sprites` + `validate-pixelart` green with zero warnings; all new art on project palette.

## Phase H — Test repair + regression coverage

- H.1 The 3 panel tests pass unmodified post-D.3 (they encode correct semantics). If any expectation is genuinely wrong, fix the test with justification in the commit body.
- H.2 New modules: `test_pbkdf2.gd` (3 vectors vs `hashlib.pbkdf2_hmac` ground truth), `test_save_failures.gd` (backup-fail abort, HMAC-mismatch signal + quarantine, orphan-temp adoption, newer-version park), `test_sync_rids.gd` (pending-map keying, empty-rid rejection, watchdog), `test_i18n.gd` (key parity it⇄en, locale boot application, no hardcoded UI strings regression sweep), `test_badges_lifetime.gd`, `test_assets_presence.gd` (mess sprites, joystick textures, ambience files, badge icons).
- H.3 `deep_test.sh` isolation: run with `XDG_DATA_HOME` pointed at a temp dir so fixtures stop polluting the real user profile; assert real profile untouched.
- H.4 Target: suite ≥ 130 tests, 100 % pass.

## Phase I — Full verification

1. `gdformat v1/scripts v1/tests` then `gdformat --check` clean (fixes the red CI lint on committed panel_manager).
2. `gdlint` clean; 10+ validators green (incl. extended ones).
3. `./scripts/smoke_test.sh` PASS; `./scripts/deep_test.sh` 100 %.
4. `chmod +x scripts/*.sh`; `./scripts/preflight.sh` → **GO** (exit 0).
5. CI workflow repairs: `build.yml` keystore injection matched to actual preset keys (or removed with signed-tag docs); Android job failure surfaced as explicit `outcome` check instead of silent `continue-on-error` masking; `softprops/action-gh-release` + `barichello/godot-ci` SHA-pinned.
6. `addons/godot-sqlite/SHA256SUMS` committed + CI verification step.
7. Local export smoke if templates present (`godot4 --headless --export-release "Windows Desktop"`); otherwise documented as CI-only.

## Phase J — Git hygiene, version, commits

1. `git checkout -- v1/scenes/main/main.tscn` (revert editor damage); keep project.godot + cozy_theme resaves.
2. `.gitattributes`: drop LFS filter lines for `*.so/dll/dylib/wasm/a` (repo holds normal blobs; kills phantom diffs). Verify `git status` clean on addon binaries afterward.
3. `.gitignore`: `_render/`, `_render_orig/`, `*.original.pptx`.
4. Version: `v1/VERSION` → 1.1.0; `project.godot` config/version; export_presets sync via `scripts/sync_version_to_presets.py`; CHANGELOG.md v1.1.0 section (fixes, features, security note on real PBKDF2, credits).
5. Commit series (conventional, thematic, author Renan Augusto Macena, no AI/co-author metadata):
   `fix(save)` → `fix(db)` → `fix(auth)` → `feat(signals)` → `fix(sync)` → `fix(audio)` → `fix(ui)` → `fix(logging)` → `feat(i18n)` → `feat(badges,characters)` → `feat(assets)` → `test(...)` → `ci(...)` → `chore(git,release)`.
6. Final: preflight GO on clean tree; push only if remote configured and user policy allows (push is default-allowed on main per repo history; keep commits local otherwise).

---

# PART V — ASSET PRODUCTION SPECIFICATIONS

Common rules: Nearest-filter pixel art, palette `v1/assets/palette/palette_projectwork.gpl` (load, quantize output to it), PNG-8/32 with alpha, `Sprite2D.centered=false` convention for room objects, bottom-center anchor per decoration_system. Generator scripts live in `ci/asset_gen/` (committed, reproducible, Pillow-based, seeded — re-runnable by CI or a teammate).

## V.1 Mess sprites (6) — 32×32
| id (from mess_catalog.json) | Visual recipe |
|---|---|
| entry 1..6 (exact ids read from catalog at generation time) | Each type gets a hand-coded pixel matrix: crumpled paper (light gray ball, 3-tone shading), coffee stain (brown ellipse, darker rim, glossy dot), dust bunny (soft gray puff, 2-tone + stray hairs), scattered crumbs (5–7 warm-brown clusters), dirty sock (folded S-shape, 2 tones + heel patch), fallen leaves (3 overlapping leaf silhouettes, green/olive). Outline: darkest palette neutral at 60 % alpha, consistent with existing room art. |
Catalog: fill `sprite_path` per entry; keep `placeholder_color` as fallback field (mess_node placeholder branch stays as defensive fallback).

## V.2 Virtual joystick textures — exact missing paths from the .tscn
- Base: 128×128 ring, 12 px stroke, palette neutral-dark at 55 % alpha, inner tick marks N/E/S/W.
- Knob: 64×64 filled circle, light neutral, 2-tone bevel, 70 % alpha.
- Scene: replace dead `uid://` references with fresh imports; verify load on `OS.has_feature("mobile")` simulation via `--headless` load of the scene.

## V.3 Ambience loops (synthesized, no external assets)
- `ambience_rain_soft.wav`: 30 s, 44.1 kHz 16-bit stereo; filtered white noise (Butterworth band 400–2 800 Hz) + sparse droplet transients (Poisson λ≈3/s, exponential decay sine bursts 1.2–2.4 kHz); 1 s equal-power crossfade tail-to-head for seamless loop; peak −6 dBFS.
- `ambience_fireplace.wav`: 30 s; brown noise base (−12 dB) + crackle bursts (random 30–80 ms noise snaps through 3–6 kHz bandpass, λ≈1.5/s) + low ember rumble (80–140 Hz sine drift); same loop treatment.
- Generator: `ci/asset_gen/gen_ambience.py` (numpy + stdlib wave). Import hints: loop=true in .import.

## V.4 Badge icons — 16×16 ×6 + profile placeholder 32×32
Icon per badge id (read from badges.json): first_deco (tiny plant pot), collector_25 (stacked boxes), collector_100 (chest), night_owl (crescent+star), clean_freak (sparkle broom), first_login (door+heart). Profile placeholder: neutral bust silhouette on theme-surface circle. Palette-locked, 1 px dark outline.

## V.5 Project + Android icons
- `v1/icon.svg`: 16×16 logical pixel grid as SVG rects — cozy room motif: warm-lit window (amber) on dark-blue wall, tiny heart above. Crisp at 128 px.
- Android: `android_icon_fg.png` 432×432 (motif, transparent bg, safe-zone 66 %), `android_icon_bg.png` 432×432 flat dark-blue; export_presets launcher-icon fields pointed at them.

## V.6 Character `male_yellow` sheet set
- Source: `assets/charachters/male/old/` sheets (idle/walk/interact/rotate, 8-dir, 32×32 frames).
- Transform: deterministic ramp remap — sample the shirt color ramp (3–4 tones) from source frames, map to yellow ramp drawn from project palette (base ≈ #e8c04a family), preserve outlines/skin/pants; Pillow per-pixel exact-color LUT (no HSV blur, keeps pixel-art crispness).
- Output: mirrored directory structure under `assets/charachters/male/male_yellow_shirt/` with identical naming; validated by frame-count parity check in generator.
- Scene: `male_yellow.tscn` duplicating the male-old character scene with re-pointed textures; catalog entry `{"id": "male_yellow", "name": "Ragazzo Solare", ...}` matching live schema.

---

# PART VI — i18n KEY MAP (target state)

Full key inventory (both .po files, key-parallel, ~120 keys — final count fixed during F.1):
- Menu: `UI_MENU_NEW_GAME`, `UI_MENU_LOAD_GAME`, `UI_MENU_OPTIONS`, `UI_MENU_PROFILE`, `UI_MENU_QUIT`
- HUD: `UI_HUD_MENU`, `UI_HUD_DECORATE`, `UI_HUD_OPTIONS`, `UI_HUD_PROFILE`, `UI_HUD_SERENITY`, `UI_HUD_COINS`
- Auth: `UI_AUTH_LOGIN`, `UI_AUTH_REGISTER`, `UI_AUTH_GUEST`, `UI_AUTH_USERNAME`, `UI_AUTH_PASSWORD`, `UI_AUTH_CONFIRM`, `UI_AUTH_USERNAME_HINT`, `UI_AUTH_PASSWORD_HINT`, `UI_AUTH_ERR_*` (5 error variants incl. lockout with %d)
- Settings: `UI_SETTINGS_TITLE`, `_MUSIC`, `_AMBIENCE`, `_VOLUME`, `_LANGUAGE`, `_PLAYLIST_MODE`, `_CREDITS`, `_NOW_PLAYING`
- Profile: `UI_PROFILE_TITLE`, `_BADGES`, `_IMAGE_PICK`, `_DELETE_ACCOUNT`, `CONFIRM_DELETE_TITLE`, `CONFIRM_DELETE_BODY`, `CONFIRM_YES`, `CONFIRM_NO`
- Deco: `UI_DECO_TITLE`, `UI_DECO_CAT_<13 categories>`, `UI_DECO_EDIT_HINT`
- Character select: `UI_CHARSEL_TITLE`, `UI_CHARSEL_CONFIRM`
- Tutorial: `TUTORIAL_STEP_1`…`TUTORIAL_STEP_8`, `TUTORIAL_SKIP`, `TUTORIAL_DONE`
- Toasts: `TOAST_SAVE_OK`, `TOAST_SAVE_FAILED`, `TOAST_SAVE_TAMPERED`, `TOAST_SYNC_ERROR`, `TOAST_SYNC_OK`, `TOAST_DB_ERROR`, `TOAST_CATALOG_ERROR`, `TOAST_MESS_CLEANED` (with %s label), `TOAST_BADGE_UNLOCKED` (%s), `TOAST_COINS_EARNED` (%d), `TOAST_IMG_TOO_LARGE`, `TOAST_IMG_INVALID`
- Badges: `BADGE_<id>_NAME` + `BADGE_<id>_DESC` ×6
- Mess: `MESS_<id>_LABEL` ×6 (or catalog label_it/label_en via locale helper — decision F.1, catalog fields preferred to keep content data-driven)
- Mood: `MOOD_LEVEL_CALM`, `_NEUTRAL`, `_TENSE`, `_STORMY`
Boot wiring, live-switch wiring, and dead-key pruning per F.1.

---

# PART VII — VERIFICATION MATRIX & RELEASE CHECKLIST

## VII.1 Per-phase verification matrix
| Phase | Mandatory gates |
|---|---|
| C | suite green · validate-signals green · forced-save-failure probe shows toast+save_failed · PBKDF2 vectors pass (pre-H spot check via godot4 -s) |
| D | suite green · headless sync probe: no stuck `_is_syncing` · panel toggle manual probe · mood slider crossfades track in probe scene |
| E | suite green · logger retention probe (boot twice, old sessions pruned) · metrics line visible in log |
| F | IT⇄EX live switch full re-render · badge unlock probe (night_owl via shortened timer in test) · 2-char selection persists across restart |
| G | validate-sprites/pixelart zero warnings · no `_make_placeholder_texture` hit in normal gameplay probe · joystick scene loads clean |
| H | ≥130 tests, 100 % pass · real user profile untouched by test run |
| I | gdlint+gdformat clean · all validators green · preflight GO |
| J | `git status` clean · CHANGELOG v1.1.0 · version triple-sync validator green |

## VII.2 Release checklist (v1.1.0)
- [ ] All PART II actionable entries FIXED or ACCEPTED-with-written-rationale
- [ ] All PART III gaps closed (or documented as descoped with reason)
- [ ] 5 CRITICALs verified fixed by dedicated tests
- [ ] Crypto claims in README/CHANGELOG match implementation (RFC 8018 PBKDF2-HMAC-SHA256)
- [ ] i18n: `msgfmt --check` equivalent parity (custom validator) on it/en
- [ ] Eder Muniz credit visible in-game
- [ ] No placeholder assets reachable at runtime; `_placeholder_temp/` deleted
- [ ] Suite 100 %, preflight GO, CI dry-run green on all 12 jobs
- [ ] Tree clean, commits conventional, author correct, no AI attribution anywhere
- [ ] Tag `v1.1.0` ready (created only on explicit release decision)

## VII.3 Standing risks & mitigations
1. **Godot tween/test timing**: panel semantics fix removes timing coupling; any remaining tween assertions use signal awaits, not frame counts.
2. **Sync rework regression surface**: sync is off by default; watchdog guarantees no permanent wedge even under unknown response shapes; DLQ preserves data.
3. **PBKDF2 perf**: 100 k HMAC iterations in GDScript — measure on login probe; if > 1.5 s on desktop, lower to spec-permitted 60 k with documented rationale (still real PBKDF2) — decision recorded in CHANGELOG.
4. **Palette-swap fidelity**: LUT remap is exact-color; any unmapped stray colors reported by generator and fixed by extending the LUT, never by blur.
5. **LFS attr removal**: affects future commits only; binaries stay normal blobs; documented in CHANGELOG for contributors.

*End of master plan.*
