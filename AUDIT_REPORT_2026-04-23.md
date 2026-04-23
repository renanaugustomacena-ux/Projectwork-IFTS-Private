# AUDIT REPORT — Relax Room / Projectwork-IFTS
**Date**: 2026-04-23
**Commit base**: `58a61b5` (branch `demo-triage-2026-04-22`)
**Target**: `/home/renan/Projectwork`
**Author**: Renan Augusto Macena

---

## 1. Scope

Full-codebase integrity + stability audit of Relax Room v1.0.0 (shipped 2026-04-22), run skill-by-skill against the Godot 4.6 GDScript codebase + Python CI validators + Netlify landing page + Supabase sync layer.

**In scope** (audited):

- `v1/scripts/` — 49 GDScript files, ~8,732 LOC
- `v1/tests/` — 10 GDScript files, ~1,748 LOC (custom headless harness)
- `v1/scenes/` — 22 TSCN scenes, 1 TRES resource, ~1,227 LOC
- `v1/data/` — 6 JSON catalogs + SQLite schema
- `v1/addons/godot-sqlite/` — version pin review only, no code audit (upstream)
- `v1/addons/virtual_joystick/` — version pin review only, no code audit (upstream)
- `ci/` — 10 Python validators
- `scripts/` — 4 shell scripts + `scripts/ci/extract_changelog.py`
- `.github/workflows/` — 4 workflows (`ci.yml`, `build.yml`, `release.yml`, `pages.yml`)
- `docs/` — landing page (index.html + style.css + main.js + 3 team subpages)
- `supabase/` — schema/config stub

**Out of scope** (cataloged only, not audited line-by-line):

- Third-party vendor assets (Kenney CC0, SoppyCraft, Thurraya, Eder Muniz, Mixkit, Kenney UI Pack)
- Native SQLite binaries shipped with `addons/godot-sqlite/bin/`
- Generated binaries in `dist/` (Windows `.exe`, HTML5 export, DLL)
- `.po` translation files (spot-check only)
- Generated PDFs, PPTX

---

## 2. Methodology

Skill-by-skill serial pass. For each skill in § 4, I:

1. Read all relevant source files in full (small batches for >500 lines).
2. Produce findings with `path:line` anchors, severity, suggested remediation.
3. Append to the corresponding section below.
4. Move to next skill.

No speculative claims. If a file does not need remediation, I say so explicitly rather than omitting.

**Tools used**:

- `Read` (full file reads, batched)
- `Bash` (`rg`, `wc`, `find`, `awk`) for mechanical measurement
- `Grep` for pattern-level sweeps
- Audit skills: `deep-audit`, `correctness-check`, `silent-failure-hunter`, `security-review`, `resilience-check`, `complexity-check`, `db-review`, `state-audit`, `observability-audit`, `api-contract-review`, `dependency-audit`, `change-impact`, `data-lifecycle-review`

---

## 3. Findings severity legend

| Level | Meaning | Action |
|---|---|---|
| **CRITICAL** | Security vulnerability, data loss, crash vector | Fix before next release |
| **HIGH** | Functional bug or significant quality issue | Fix before next release |
| **MEDIUM** | Maintainability concern, latent risk | Fix in next sprint |
| **LOW** | Style, minor improvement | Backlog |
| **INFO** | Observation, no action required | Reference only |

Each finding follows this shape:

```
[SEVERITY] [file:line] Short title
  Evidence: ...
  Risk: ...
  Remediation: ...
  Status: (OPEN / DEFERRED / FIXED)
```

---

## 4. Audit sections

### 4.1 deep-audit — hot-file structural review

Targets: 10 largest GDScript files (`supabase_client.gd` 547 L, `save_manager.gd` 535 L, `audio_manager.gd` 473 L, `tutorial_manager.gd` 376 L, `local_database.gd` 323 L, `profile_hud_panel.gd` 309 L, `room_base.gd` 303 L, `main_menu.gd` 288 L, `pet_controller.gd` 268 L, `logger.gd` 264 L) + 9 DB repos under `autoload/database/`. Each file read fully in ≤280-line batches.

Methodology per file: walk every function, assertion, exception handler, subprocess call, return value. Classify per deep-audit rubric (false positive / mock contamination / silent fail / tool-false-positive).

---

#### 4.1.1 `v1/scripts/autoload/supabase_client.gd` — 547 lines

**Status**: WARNING — 3 HIGH, 5 MEDIUM, 3 LOW

* **L45–47** — `if not _config.get("valid", false): AppLogger.info(...); return`
  **Classification**: Silent Fail (by omission)
  **Severity**: MEDIUM
  **Evidence**: On missing/invalid config the autoload returns early from `_ready()` with only an INFO log. No signal is emitted to tell the rest of the game "cloud disabled". Callers of `is_configured()` (8 call sites) work, but any code that assumes `_http` is non-null (e.g. late-bound signal wiring tests) silently no-ops.
  **Remediation**: Emit `SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)` before the early return, so observers have a consistent state-change event. Status: OPEN.

* **L107–113** — `func refresh_jwt() -> void: if _refresh_token.is_empty(): return`
  **Classification**: Silent Fail
  **Severity**: MEDIUM
  **Evidence**: `_ensure_jwt()` at L240–248 calls `refresh_jwt()` when the token is within 60 s of expiry. If `_refresh_token` is already empty (session expired), `refresh_jwt()` returns silently — no caller-visible signal, no state transition. Subsequent HTTP calls carry an expired Bearer, hit 401, route to `refresh_jwt()` again → infinite no-op loop until HTTP layer times out.
  **Remediation**: When refresh token is empty, emit `SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)` and set `_jwt_token = ""`. Status: OPEN.

* **L161–174** — `_save_session()` fallback path
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: Encrypted save error is logged (L173), then falls back to `cfg.save(SESSION_PATH)` at L174 — return value **not checked**. If plaintext save also fails (disk full / permission), the user's session is lost on next launch with zero feedback. Also, fallback writes **plaintext refresh token** to disk, silently downgrading the security posture of B-019.
  **Remediation**: Check fallback return; on double failure, `AppLogger.error` with `{"context": "session_persist_double_failure"}` AND keep in-memory state. Status: OPEN.

* **L208–237** — `fetch_table / upsert_to_table / delete_from_table` return `""` on `_ensure_jwt` false
  **Classification**: Silent Fail (sentinel return)
  **Severity**: MEDIUM
  **Evidence**: These public methods return `String` (request id) on success, empty string on "not ready". No doc-comment explains the sentinel. Three call-sites (L457, L464, L478, L485, L494, L498) do not check for `""`. If called pre-auth, the RID is lost; caller has no correlation id to match a later response.
  **Remediation**: Change return type to `Variant` with `null` sentinel, or raise via `SignalBus.cloud_request_rejected`. Status: OPEN.

* **L297–299** — HTTP 401 path in `_on_request_completed`
  **Classification**: False Negative (incomplete retry)
  **Severity**: HIGH
  **Evidence**: On 401 the code calls `refresh_jwt()` but does **not** re-queue the original request that triggered the 401. The upstream sync operation (fetch/upsert/delete) gets no completion event; its `rid` lingers in `_pending_requests` forever if it was a sync-push. Sync engine (L501) can deadlock.
  **Remediation**: Buffer failed requests with their method/url/body/headers, replay after `_apply_auth_response` succeeds. Status: OPEN.

* **L300–311** — `status == 404` or relation-error swallow
  **Classification**: Silent Fail (by design, but risky)
  **Severity**: HIGH
  **Evidence**: When a Supabase table does not exist, the client logs WARN and moves on. This is an Elia-schema-evolution concession (L3–5 file docstring). Post-demo, once schema is frozen, this masks **real data loss**: a typo in `_push_local_state` table names (L457, L464, L478, L485, L494, L498) would be swallowed as "table not found, skip gracefully" — user believes sync worked, cloud has nothing.
  **Remediation**: Guard this permissive branch behind `Constants.SUPABASE_ALLOW_MISSING_TABLES: bool` that defaults to `true` pre-demo and `false` post-demo; when `false`, route to `AppLogger.error` and emit `SignalBus.sync_error`. Status: OPEN.

* **L422–443** — `_process_sync_queue()` silently drops corrupt payloads
  **Classification**: Silent Fail (data loss)
  **Severity**: HIGH
  **Evidence**: L434 `if json.parse(payload_str) != OK: LocalDatabase.clear_sync_item(queue_id); continue`. If a queued offline edit becomes unparseable (disk corruption, migration bug), it is **deleted from the queue with no log, no notification, no DLQ**. The user's edit disappears.
  **Remediation**: Log with payload length + first 32 chars; move to a `sync_dead_letter` table instead of deleting; emit `SignalBus.sync_payload_corrupted`. Status: OPEN.

* **L440–443** — delete branch builds `id=eq.` + `str(payload.get("id", ""))`
  **Classification**: Silent Fail (dangerous query)
  **Severity**: MEDIUM
  **Evidence**: If payload is malformed and `id` is missing, the URL becomes `…?id=eq.` — Supabase PostgREST returns 400 or interprets as "all rows where id equals empty string". Safe only because RLS scopes by user, but a defense-in-depth gap. No assertion on `payload.has("id")`.
  **Remediation**: `if not payload is Dictionary or not payload.has("id"): continue` + log. Status: OPEN.

* **L494** — `delete_from_table("room_decorations", "user_id=eq." + supabase_user_id)` before re-upsert
  **Classification**: Silent Fail (catastrophic if RLS absent)
  **Severity**: MEDIUM
  **Evidence**: If `supabase_user_id` were empty here (line 447 guards the function, so it shouldn't be — but that guard is the only line of defense), this query becomes `user_id=eq.`. PostgREST + missing RLS = mass deletion. The guard at L447–449 is sufficient today, but one refactor away from disaster.
  **Remediation**: Also assert inside the `delete_from_table` helper: `if query.ends_with("eq.") or query.ends_with("eq."): return`. Status: OPEN.

* **L501–502** — `if _pending_requests.is_empty(): _finish_sync(true)` timing
  **Classification**: False Positive (sync "success" while pending)
  **Severity**: MEDIUM
  **Evidence**: `_finish_sync(true)` is called at the end of `_push_local_state` only if `_pending_requests.is_empty()`. If the HTTP layer rejects a request pre-send (e.g. `_http.request` returns non-OK internally — not visible here), the `_pending_requests[rid] = true` entry was set **before** the request, and stays forever. Meanwhile none of those entries will ever be cleared (no response arrives). `_is_syncing` stays `true`. Next timer tick → `start_sync` returns early (L410–411). **Permanent stuck-syncing state.**
  **Remediation**: Inspect `_http.request(...)` return code; if non-OK, remove the rid from `_pending_requests` immediately and track as failed. Status: OPEN.

* **L181** — `_jwt_expires_at = Time.get_unix_time_from_system() + float(expires_in)`
  **Classification**: False Positive (clock-based trust)
  **Severity**: LOW
  **Evidence**: Uses system clock for expiry. User moving clock backwards would extend token validity; forwards would force immediate refresh. Acceptable for offline-first local-only accounts, not for hostile-user scenarios.
  **Remediation**: Use `Time.get_ticks_msec()` delta anchored at response receipt. Status: OPEN (LOW priority).

* **L389–394** — `_is_relation_error` substring match
  **Classification**: False Positive (fragile matcher)
  **Severity**: LOW
  **Evidence**: Matches any Supabase error message containing "relation" AND "does not exist". A future error like "user relation X does not exist in user_id mapping" would be treated as a missing-table. Unlikely but unguarded.
  **Remediation**: Match on PostgreSQL error code `42P01` (undefined_table) via `body.get("code")` instead. Status: OPEN.

* **L26** — `_SESSION_SALT := "relax-room-2026-session-v1"` hardcoded
  **Classification**: Mock Contamination (illusion of security)
  **Severity**: LOW
  **Evidence**: Salt committed in source. Attacker with repo access + filesystem access derives `_derive_session_key()` trivially. Comment at L20–26 explicitly acknowledges limited threat model.
  **Remediation**: Document this as the accepted threat model in `v1/README.md` and `CHANGELOG.md` Security section (already mentioned there — ok). Status: ACCEPTED.

* **TODO B-033** (L7–8) — file acknowledges >500-line bloat, targets post-demo split.
  Status: DEFERRED.

---

#### 4.1.2 `v1/scripts/autoload/save_manager.gd` — 535 lines

**Status**: CRITICAL — 1 CRITICAL, 4 HIGH, 3 MEDIUM, 3 LOW

* **L169–180** — atomic rename with copy fallback; `save_completed` emits unconditionally
  **Classification**: Tool False Positive (PASS without verification)
  **Severity**: **CRITICAL**
  **Evidence**: `DirAccess.rename_absolute(TEMP → SAVE)` fails → falls to `DirAccess.copy_absolute(TEMP, SAVE)` at L174 with **no return-value check**. Execution continues to L180 `SignalBus.save_completed.emit()`. If both rename AND copy fail, the signal still fires. Every downstream listener (UI toast, cloud sync trigger, analytics) treats the save as successful.
  **Remediation**: Capture `copy_absolute` return, if non-OK `AppLogger.error` + emit `SignalBus.save_failed(err)` instead of `save_completed`. Make `_is_saving` retain `true` until verified. Status: OPEN.

* **L174** — `copy_absolute` fallback is not atomic
  **Classification**: False Positive (contract violation)
  **Severity**: HIGH
  **Evidence**: File-header docstring promises "Atomic write" (L148). The fallback path does a regular copy, which can partial-write if the process is killed mid-copy (OS fsync semantics). The `save_completed` signal then lies about integrity.
  **Remediation**: Retry rename with exponential backoff (3 attempts) before degrading to copy. If copy is used, compute HMAC of the written file and compare against in-memory HMAC; on mismatch, abort. Status: OPEN.

* **L152–158** — temp file write does not verify `store_string` success
  **Classification**: Silent Fail
  **Severity**: MEDIUM
  **Evidence**: `file.store_string(...)` at L157 has no return check. Godot's FileAccess does surface errors, but they are only checkable via `get_error()` after the call. If disk is near-full, the write can truncate silently. The subsequent `file.close()` at L158 also unchecked.
  **Remediation**: After `store_string`, `var err := file.get_error(); if err != OK: ... return`. Status: OPEN.

* **L161–166** — backup copy failure is logged but not blocking
  **Classification**: False Negative
  **Severity**: HIGH
  **Evidence**: If backup creation fails, the rename at L169 proceeds anyway, overwriting the primary save with the new data and leaving NO previous version to recover from. Combined with the L169–180 finding, a single failed rename after a failed backup = total data loss with `save_completed` still firing.
  **Remediation**: Fail the save if backup fails when primary exists; refuse to overwrite without a durable backup. Status: OPEN.

* **L177** — dual-write signal-emit pattern (B-016 claim)
  **Classification**: False Positive (contract misleading)
  **Severity**: HIGH
  **Evidence**: Comment at L184 asserts "B-016: payload completo dual-write JSON+SQLite". But `_save_to_sqlite` merely fires `SignalBus.save_to_database_requested`; it does not wait for, or verify, the SQLite write. SaveManager emits `save_completed` at L180 before the SQL write has completed. A transient SQLite failure (lock contention, disk) leaves JSON and SQLite divergent — exactly what B-016 claimed to fix.
  **Remediation**: Switch to a request/response pattern — emit request with a correlation id, receive `SignalBus.save_to_database_completed(id, ok)`, then emit `save_completed` only when both writes confirmed. Or use a direct `LocalDatabase.apply_save(...)` synchronous call. Status: OPEN.

* **L257–263** — HMAC mismatch returns null; upstream silently uses backup or "no save"
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: `AppLogger.warn(...)` at L262 is the only signal. Caller at L210–213 falls through to backup; if backup also fails HMAC, `load_game` at L214–217 logs a `push_warning` and returns empty. The player opens the game to pristine "new account" state after what was actually a tamper-detection event. No UI notification, no cloud-escalation, no tamper counter.
  **Remediation**: Emit `SignalBus.save_integrity_violation(path)`; UI toast; stash corrupt save under `user://save_data.quarantine.<timestamp>.json` for forensic retrieval. Status: OPEN.

* **L186–204** — comment "B-016 dual-write" misleading
  **Classification**: Mock Contamination (illusion of guarantee)
  **Severity**: MEDIUM
  **Evidence**: See L177 finding. The comment promises atomicity that the code does not deliver.
  **Remediation**: Rewrite comment to accurately describe fire-and-forget signal pattern; OR implement the promised guarantee. Status: OPEN.

* **L381–395** — v3→v4 inventory reset drops `items` silently
  **Classification**: Silent Fail
  **Severity**: MEDIUM
  **Evidence**: If inventory lacks `coins` or `items` keys during migration, items is reset to `[]` with only a WARN log. No backup of the original inventory payload, no user notification. User loses inventory silently.
  **Remediation**: Before reset, serialize original inventory into `user://save_data.v3_preserved.json` for potential recovery. Status: OPEN.

* **L477–492** — `_get_integrity_key` regenerates silently if write fails
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: `f.store_string(key.hex_encode())` at L490 has no return check. On fail, the returned key is valid in memory for this session, but `SECRET_PATH` doesn't persist. Next launch regenerates a new key → all existing HMACs fail → saves treated as tampered → loaded-from-backup (also fails HMAC with new key) → "no valid save". Silent total wipe.
  **Remediation**: Check `store_string` + `close` + re-read to verify. If write fails, abort save_game (HMAC cannot be persisted) and emit `SignalBus.save_integrity_unavailable`. Status: OPEN.

* **L483** — hex validation length-only, no charset check
  **Classification**: False Negative (mild)
  **Severity**: LOW
  **Evidence**: `if hex.length() == 64: return hex.hex_decode()`. `hex_decode()` on invalid chars returns a PackedByteArray of indeterminate content. Key becomes garbage, HMAC fails silently on next save/load.
  **Remediation**: Regex `^[0-9a-fA-F]{64}$` or catch via `hex_decode()` emptiness check. Status: OPEN.

* **L533–535** — `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → `save_game()`, but save_game is re-entrant-safe with skip
  **Classification**: False Negative (edge case)
  **Severity**: LOW
  **Evidence**: If a window-close fires during an active autosave, `save_game()` at L117 returns early without persisting the latest dirty state. User's last-minute edits lost.
  **Remediation**: Queue a "flush on completion" flag; when current save finishes, re-run if dirty. Status: OPEN.

* **L533–535** — NOTIFICATION_WM_CLOSE_REQUEST does NOT await save completion
  **Classification**: False Positive (assumed sync)
  **Severity**: LOW
  **Evidence**: Godot's autoload `_notification` does not hold the window open waiting for I/O. Call to `save_game()` returns while writes are in-flight. The OS may close the window before flush completes.
  **Remediation**: Use `get_tree().set_auto_accept_quit(false)` + explicit quit after save completion signal. Status: OPEN.

---

#### 4.1.3 `v1/scripts/autoload/logger.gd` — 264 lines

**Status**: WARNING — 0 CRITICAL, 2 HIGH, 1 MEDIUM, 0 LOW

* **L253** — `_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)`
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: Opens with `WRITE`, which truncates any existing file. Because `_open_log_file()` is re-invoked after rotation AND on `_flush_buffer()` retry (L158), any re-open on the same session filename silently wipes prior log content. Filenames derive from `Time.get_datetime_dict_from_system()` at second resolution (L240-251), so two opens in the same second (common during rapid rotation or retry loop after a first failed open) collide and destroy earlier log lines — the very diagnostic data the logger exists to preserve.
  **Remediation**: Use `FileAccess.READ_WRITE` + `seek_end()`, or `FileAccess.WRITE_READ` only when the file is known not to exist. Append monotonic counter to filename if collision possible. Status: OPEN.

* **L133–135** — `if _log_buffer.size() >= MAX_BUFFER_ENTRIES: _log_buffer.pop_front()` / `_log_buffer.append(json_line)`
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: When buffer cap is hit the oldest entry is dropped silently with no metric/warn. Combined with L160–168 behavior (flush-failure path retains only last 100), the logger can swallow thousands of log lines (including ERROR entries) without any signal that drops occurred. The `push_warning` at L166 only fires on flush retry, never on steady-state cap hits — so a runaway log rate produces a misleadingly terse file and a cleanly passing session.
  **Remediation**: Emit a single rate-limited `push_warning` on first drop and include a `dropped_count` counter entry on the next successful flush. Status: OPEN.

* **L219–221** — `var random_bytes := crypto.generate_random_bytes(4)` / `var random_int := random_bytes[0] << 24 | ...`
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: The comment at L216 claims "Numeri casuali crittograficamente sicuri" but only the low 16 bits are then used (L227: `random_int & 0xFFFF`), truncating away 16 bits of entropy. Collision space for concurrent sessions in the same second is 2^16 ≈ 65k, not 2^32. Claim vs. delivered entropy do not match.
  **Remediation**: Widen hex width to 8 and keep the full 32 bits, or drop the `<< 24` shuffle and just read 2 bytes. Status: OPEN.

#### 4.1.4 `v1/scripts/autoload/local_database.gd` — 323 lines

**Status**: FAIL — 1 CRITICAL, 1 HIGH, 1 MEDIUM, 0 LOW

* **L113–139** — `DBHelpers.execute(_db, "BEGIN TRANSACTION;")` … COMMIT/ROLLBACK flow
  **Classification**: Tool False Positive
  **Severity**: **CRITICAL**
  **Evidence**: Return value of `BEGIN TRANSACTION` is never checked for SQL engine failure. `DBHelpers.execute` returns false on failure but the BEGIN at L113 ignores it — if BEGIN fails (pre-existing transaction, lock after busy_timeout), subsequent upserts run in autocommit mode yet the code still emits COMMIT/ROLLBACK against a non-existent transaction. No error logged on COMMIT failure either. `_on_save_requested` can report implicit success while having only partially written to disk, defeating the dual-write atomicity claim at L121.
  **Remediation**: Check BEGIN return; on failure, abort with logged error. Check COMMIT return; on failure, force ROLLBACK and surface to `SignalBus.save_failed`. Status: OPEN.

* **L108–110** — `account_id = AccountsRepo.upsert_account(_db, auth_uid, Constants.AUTH_GUEST_EMAIL, "")`
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: When `get_account_by_auth_uid` returns an empty dict, code unconditionally upserts a guest account and uses its id. If the auth state genuinely holds a valid `auth_uid` that is simply not yet persisted (first-login race), this writes all game state under the *guest* account row instead of the intended authenticated user — permanent data divergence, visible only on next login when "their" save appears empty.
  **Remediation**: Branch on whether `AuthManager.current_auth_uid` equals `AUTH_GUEST_UID` before falling through to guest-upsert. Status: OPEN.

* **L94–96** — `PRAGMA foreign_keys;` warn-only
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Warns but does not fail-close. Every repo relies on `ON DELETE CASCADE` for invariant safety; if FKs are disabled, soft deletes leak orphan rows indefinitely.
  **Remediation**: Treat FK-disabled as a hard init error or retry `PRAGMA foreign_keys=ON` before accepting writes. Status: OPEN.

#### 4.1.5 `v1/scripts/autoload/audio_manager.gd` — 473 lines

**Status**: WARNING — 0 CRITICAL, 2 HIGH, 1 MEDIUM, 0 LOW

* **L137–140** — `while new_index == current_track_index and tracks.size() > 1: new_index = randi() % tracks.size()`
  **Classification**: False Positive
  **Severity**: HIGH
  **Evidence**: Uses global `randi()` instead of the `_mood_rng` that `_ready()` seeded (L56–59) for debug reproducibility. Shuffle-next in debug is non-deterministic, breaking the reproducibility invariant and silently contaminating bug repros.
  **Remediation**: Replace with `_mood_rng.randi() % tracks.size()`. Status: OPEN.

* **L96–97** — `var raw = tracks[current_track_index]` / `if raw is not Dictionary:`
  **Classification**: Mock Contamination
  **Severity**: HIGH
  **Evidence**: `tracks` populated at L64–66 directly from `GameManager.tracks_catalog["tracks"]` without schema validation. Malformed catalog entry (missing `path`, non-Dict, empty string) survives past load; detected only in hot-path `play()` after `current_track_index` may already reference it via save state.
  **Remediation**: Filter/validate tracks once in `_load_tracks()` and reject malformed entries before they can be indexed. Status: OPEN.

* **L392–412** — `func crossfade_to_mood_track(mood: float) -> void:` naming misnomer
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Name implies "crossfade to mood track" but function only adjusts volume + emits signals; no track swap here. Real crossfade lives in `_on_mood_changed`. Misnomer creates a false audit signal.
  **Remediation**: Rename to `apply_mood_scalar`. Status: OPEN.

#### 4.1.6 `v1/scripts/menu/tutorial_manager.gd` — 376 lines

**Status**: WARNING — 0 CRITICAL, 2 HIGH, 1 MEDIUM, 0 LOW

* **L264–270** — re-connect one-shot on filter reject
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: Re-connects a new one-shot callable each time the filter rejects an event. `_disconnect_all_signals()` (L358–368) only runs on step change — a long-running step that sees many non-matching emissions accumulates unbounded connections. Both grows handler list monotonically AND silently swallows the event: no metric/log records the filter rejection. Tutorial stays stuck.
  **Remediation**: Track one active connection handle; reject-in-place via stateful callable rather than re-subscribe; log filter misses. Status: OPEN.

* **L237** — `if sig.get_connections().size() < 10:`
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: If another subsystem has 10+ connections on the bus signal, the tutorial step silently becomes a no-op: short-circuits without warn/error, orphaned until `STEP_TIMEOUT` (30 s).
  **Remediation**: Drop the cap or log when connection refused; tutorial is ephemeral, 10 is arbitrary. Status: OPEN.

* **L305–309** — `_find_node_by_name(get_tree().root, target_name)`
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Returns *first* matching name; Godot does not enforce uniqueness. A hidden/overlapping node with the same name routes the arrow to the wrong control silently.
  **Remediation**: Use `NodePath` or group-based lookup; enforce uniqueness. Status: OPEN.

#### 4.1.7 `v1/scripts/ui/profile_hud_panel.gd` — 309 lines

**Status**: WARNING — 0 CRITICAL, 1 HIGH, 2 MEDIUM, 0 LOW

* **L207–218** — `Image.load_from_file(path)` → `img.resize` → `img.save_png`
  **Classification**: Mock Contamination / Silent Fail
  **Severity**: HIGH
  **Evidence**: Accepts arbitrary user-selected path with no content-type validation. A maliciously renamed file (e.g. `.png.exe`, 1 GB file) is loaded with no size guard / MIME check. OOM / DoS on user action. Error path emits toast but does not cleanup partial PNG on disk.
  **Remediation**: Check `FileAccess.get_file_as_bytes(path).size()` against a 10 MB cap and verify first bytes match PNG/JPG magic before `load_from_file`. Status: OPEN.

* **L160** — `_mood_slider.value = clampf(saved_mood, 0.0, 1.0)` emits while `_loading` guard active
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: `.value` set triggers `value_changed` → `_on_mood_changed` → SignalBus emit. The `_loading` latch protects this path; fragile coupling — hoisting a sibling refresh above L164 breaks it.
  **Remediation**: Use `set_value_no_signal` (Godot 4.2+) instead of relying on the latch. Status: OPEN.

* **L271** — `BadgeManager.get_unlocked_badges()` called pre-load
  **Classification**: Silent Fail
  **Severity**: MEDIUM
  **Evidence**: `_refresh_badges` invoked in `_build_ui()` L92 before `_load_state()` L35. If BadgeManager depends on a loaded account, returns empty/guest. Visual audit sees "no badges" on boot, masking genuine unlocks until next `badge_unlocked` emission.
  **Remediation**: Defer to `SignalBus.load_completed` or call after `_load_state()`. Status: OPEN.

#### 4.1.8 `v1/scripts/rooms/room_base.gd` — 303 lines

**Status**: WARNING — 0 CRITICAL, 1 HIGH, 2 MEDIUM, 0 LOW

* **L80–89** — character swap: no null-check on freed reference
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: L80 dereferences `character_node.position` without guard. Idempotency guard at L74 only short-circuits same-scene case; a real swap with a freed reference falls through and hard-faults.
  **Remediation**: Guard whole swap block with `if character_node == null or not is_instance_valid(character_node): return` before L80. Status: OPEN.

* **L110–117** — nudge_pos not clamped inside floor polygon
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: `_find_nearest_free_position` places target +20 px beyond edge, no verification against floor polygon. Character can land outside walkable bounds or through a wall.
  **Remediation**: Post-process through `Helpers.clamp_inside_floor` and loop for non-colliding spot. Status: OPEN.

* **L280–284** — `Vector2.ZERO` sentinel conflates "unset" with legal origin
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Treats `Vector2.ZERO` as sentinel "unset position", but `(0,0)` is a legal spawn. Designer placing character at origin silently jumps pet to (640,360).
  **Remediation**: Use nullable typed var or dedicated `_character_pos_ready` flag. Status: OPEN.

#### 4.1.9 `v1/scripts/menu/main_menu.gd` — 288 lines

**Status**: WARNING — 0 CRITICAL, 2 HIGH, 1 MEDIUM, 0 LOW

* **L286–288** — 5 s fallback timer unconditionally releases `_transitioning`
  **Classification**: Tool False Positive
  **Severity**: HIGH
  **Evidence**: Timer releases `_transitioning` after 5 s regardless of actual scene-change outcome. On slow devices, legitimate-slow loads let user double-click "Nuova Partita", re-invoking `_on_nuova_partita` which re-resets character data and re-schedules another transition. Comment claims "in case scene change fails silently" but mechanism does not detect failure.
  **Remediation**: Check `change_scene_to_file` return code; hook `tree_changed`/`scene_changed` to release flag on success only. Status: OPEN.

* **L101–103** — hardcoded `"male_old"` fallback for empty catalog
  **Classification**: Mock Contamination
  **Severity**: HIGH
  **Evidence**: Fallback to hardcoded string both when catalog empty AND as `.get` default. Corrupt/empty catalog proceeds with char id that may not exist in `CHARACTER_SCENES` — false PASS for "character selected" while state is stale.
  **Remediation**: Hard-fail with user-visible error when catalog empty; do not invent id. Status: OPEN.

* **L40–42** — save-file existence check ignores SQLite state
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Checks JSON save existence only. Authoritative save state can live in DB when JSON absent. Disabling `Carica Partita` on JSON absence misleads users whose DB has data.
  **Remediation**: Check both JSON existence AND `LocalDatabase.get_account_by_auth_uid`. Status: OPEN.

#### 4.1.10 `v1/scripts/rooms/pet_controller.gd` — 268 lines

**Status**: WARNING — 0 CRITICAL, 1 HIGH, 1 MEDIUM, 0 LOW

* **L77–85** — WILD state has no bounds check
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: WILD moves at 140 px/s with no bounds check against floor polygon. `Helpers.clamp_inside_floor` used in WANDER (L212) but not here. Pet escapes room, vanishes off-screen, tunnels through colliders. If `pet_wild_mode_requested(false)` signal dropped, pet permanently off-grid.
  **Remediation**: After `move_and_slide`, reflect `_wild_direction` if position outside floor. Status: OPEN.

* **L46–47** — `SignalBus.has_signal("pet_wild_mode_requested")` string-literal guard
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Defensive `has_signal` guard via string literal. If signal renamed on bus side, pet silently loses WILD capability with no compile-time nor runtime error.
  **Remediation**: Reference signal statically and let missing signal fail at parse time. Status: OPEN.

#### 4.1.11 `v1/scripts/autoload/database/schema.gd` — 228 lines

**Status**: FAIL — 1 CRITICAL, 1 HIGH, 0 MEDIUM, 0 LOW

* **L195–204** — migration 1 DROP / CREATE outside transaction, return values ignored
  **Classification**: Tool False Positive
  **Severity**: **CRITICAL**
  **Evidence**: Migration runs DROP / CREATE outside a transaction with zero return-value checks. If `CREATE TABLE characters_bak AS SELECT * FROM characters` fails mid-sequence, `DROP TABLE characters` at L202 still executes, annihilating user data with the backup table potentially empty. Comment advertises "safety net" but code does not verify backup succeeded before destroying source.
  **Remediation**: Wrap migration in BEGIN/COMMIT/ROLLBACK; check each return; abort with log if backup row count != source row count pre-DROP. Status: OPEN.

* **L188** — `if "character_id" in schema: return` substring match on DDL
  **Classification**: False Positive
  **Severity**: HIGH
  **Evidence**: Bare substring match. A future column named `foo_character_id` or a comment containing "character_id" in the DDL would short-circuit migration as "already done".
  **Remediation**: Use `PRAGMA table_info('characters')` with exact column name match. Status: OPEN.

#### 4.1.12 `v1/scripts/autoload/database/db_helpers.gd` — 49 lines

**Status**: WARNING — 0 CRITICAL, 1 HIGH, 1 MEDIUM, 0 LOW

* **L44** — `AppLogger.error("LocalDatabase", "select_bound_failed", {"sql": sql.left(80), "bindings": bindings})` leaks values
  **Classification**: Silent Fail (data leak)
  **Severity**: HIGH
  **Evidence**: Dumps full `bindings` array into error log without redaction. Callers pass `password_hash`, `auth_uid`, `mail`. On query failure, these land in plaintext JSONL under `user://logs/`. Logger's REDACT_KEYS only applies to keyed dicts; anonymous array bypasses filter.
  **Remediation**: Log only `bindings.size()` or first-n *types*, never raw values. Or wrap bindings in named dict so redactor can see them. Status: OPEN.

* **L13–14** — `sql.left(80)` truncation hides WHERE clauses
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: 80-char cap cuts WHERE context. No engine-level error detail (`db.error_message`) logged even though `godot-sqlite` exposes one.
  **Remediation**: Include `db.error_message`; raise cap to 400 or switch to hash-plus-preview. Status: OPEN.

#### 4.1.13 `v1/scripts/autoload/database/accounts_repo.gd` — 121 lines

**Status**: WARNING — 0 CRITICAL, 2 HIGH, 0 MEDIUM, 0 LOW

* **L28–35** — UPDATE return not checked
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: `DBHelpers.execute_bound(db, "UPDATE accounts SET ...;", [...])` return discarded. On failure, `upsert_account` still returns existing `account_id`, caller continues as if updated.
  **Remediation**: Capture ok; return -1 on fail. Status: OPEN.

* **L66–79** — INSERT + last_insert_rowid() without ok-check
  **Classification**: False Positive
  **Severity**: HIGH
  **Evidence**: INSERT return unchecked. On UNIQUE constraint violation on `auth_uid`, INSERT fails silently and `last_insert_rowid()` returns id of *previous* insert in this session (SQLite semantics). Duplicate-username registration claims success, points at wrong account.
  **Remediation**: Check INSERT ok; pre-check via `get_account_by_username`; fail-explicit on conflict. Status: OPEN.

#### 4.1.14 `v1/scripts/autoload/database/badges_repo.gd` — 40 lines

**Status**: PASS — no findings

Tiny CRUD wrapper; `INSERT OR IGNORE` handles uniqueness cleanly; the only return from `unlock_badge` is `execute_bound`'s own ok/fail. No diagnostic blindness observed.

#### 4.1.15 `v1/scripts/autoload/database/characters_repo.gd` — 65 lines

**Status**: WARNING — 0 CRITICAL, 0 HIGH, 1 MEDIUM, 0 LOW

* **L31** — `1 if data.get("genere", true) else 0`
  **Classification**: Mock Contamination
  **Severity**: MEDIUM
  **Evidence**: Inbound `data["genere"]` could arrive as string ("male"/"female") or int. Truthy-check converts `"female"` → `1` (truthy), `0` → `0`, silently corrupting semantic. Schema column is `genere INTEGER DEFAULT 1` but no input type validation.
  **Remediation**: Coerce explicitly — `int(data.get("genere", 1))` or reject unexpected types with warn. Status: OPEN.

#### 4.1.16 `v1/scripts/autoload/database/inventory_repo.gd` — 72 lines

**Status**: FAIL — 1 CRITICAL, 0 HIGH, 0 MEDIUM, 0 LOW

* **L58–70** — DELETE + INSERT loop without surrounding transaction
  **Classification**: Tool False Positive
  **Severity**: **CRITICAL**
  **Evidence**: `save_inventory` performs DELETE then re-INSERT loop *without* surrounding transaction. If INSERT loop fails partway, function returns `false` but DELETE already committed in autocommit mode, destroying inventory and leaving partial/empty state. Caller at local_database.gd L118–120 wraps in BEGIN/COMMIT, but that outer transaction's BEGIN return is also unchecked (see 4.1.4). If `save_inventory` called directly via facade (L222–226), zero safety net. Claimed as B-016 "dual-write completo" — it is not.
  **Remediation**: Assert outer transaction active, or wrap in SAVEPOINT/ROLLBACK TO SAVEPOINT. Status: OPEN.

#### 4.1.17 `v1/scripts/autoload/database/rooms_deco_repo.gd` — 90 lines

**Status**: WARNING — 0 CRITICAL, 0 HIGH, 2 MEDIUM, 0 LOW

* **L16** — dual storage: JSON blob column + normalized placed_decorations table
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: Decorations stored twice with no synchronization contract documented. A reader cannot tell which is authoritative; reconciliation bugs surface as "decoration disappeared after reload".
  **Remediation**: Pick one source of truth; if both needed, document write-through order. Status: OPEN.

* **L85–89** — DELETE returns true even for non-existent IDs
  **Classification**: Silent Fail
  **Severity**: MEDIUM
  **Evidence**: Attempting to remove non-existent `placement_id` returns `true` (DDL succeeded; rows-affected zero). Callers cannot distinguish "removed" from "did not exist".
  **Remediation**: Run `SELECT changes()` after DELETE, propagate zero-rows as distinct warn. Status: OPEN.

#### 4.1.18 `v1/scripts/autoload/database/settings_repo.gd` — 168 lines

**Status**: WARNING — 0 CRITICAL, 0 HIGH, 2 MEDIUM, 0 LOW

* **L143** — `1 if data.get("ambience_enabled", true) else 0`
  **Classification**: Mock Contamination
  **Severity**: MEDIUM
  **Evidence**: Same bool-to-int truthy-coercion as characters_repo L31.
  **Remediation**: `bool(data.get("ambience_enabled", true))`. Status: OPEN.

* **L139–146** — three different defaults for `playlist_mode` across the stack
  **Classification**: False Positive
  **Severity**: MEDIUM
  **Evidence**: DB default `"sequential"`, audio_manager.gd L12 default `"shuffle"`, audio_manager.gd L72 SaveManager fallback `"shuffle"`. Reading from DB yields "sequential" for a user whose gameplay was in "shuffle" — audit blind spot.
  **Remediation**: Centralize in `Constants.DEFAULT_PLAYLIST_MODE`; reference from all three sites. Status: OPEN.

#### 4.1.19 `v1/scripts/autoload/database/sync_queue_repo.gd` — 27 lines

**Status**: WARNING — 0 CRITICAL, 1 HIGH, 0 MEDIUM, 0 LOW

* **L10–18** — unbounded payload size + `retry_count` declared but never used
  **Classification**: Silent Fail
  **Severity**: HIGH
  **Evidence**: Payload serialized to JSON with no size check — unbounded dict → unbounded text blob → disk exhaustion. `retry_count` declared in schema (schema.gd L80) but never incremented or read anywhere; queue has no actual back-off/retry semantics despite the column existing.
  **Remediation**: Bound payload size (64 KB cap); implement `increment_retry(queue_id)`; add ORDER BY tiebreaker. Status: OPEN.

---

#### 4.1.X Section 4.1 roll-up

| File | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| supabase_client.gd | 0 | 3 | 5 | 3 |
| save_manager.gd | 1 | 4 | 3 | 3 |
| logger.gd | 0 | 2 | 1 | 0 |
| local_database.gd | 1 | 1 | 1 | 0 |
| audio_manager.gd | 0 | 2 | 1 | 0 |
| tutorial_manager.gd | 0 | 2 | 1 | 0 |
| profile_hud_panel.gd | 0 | 1 | 2 | 0 |
| room_base.gd | 0 | 1 | 2 | 0 |
| main_menu.gd | 0 | 2 | 1 | 0 |
| pet_controller.gd | 0 | 1 | 1 | 0 |
| schema.gd | 1 | 1 | 0 | 0 |
| db_helpers.gd | 0 | 1 | 1 | 0 |
| accounts_repo.gd | 0 | 2 | 0 | 0 |
| badges_repo.gd | 0 | 0 | 0 | 0 |
| characters_repo.gd | 0 | 0 | 1 | 0 |
| inventory_repo.gd | 1 | 0 | 0 | 0 |
| rooms_deco_repo.gd | 0 | 0 | 2 | 0 |
| settings_repo.gd | 0 | 0 | 2 | 0 |
| sync_queue_repo.gd | 0 | 1 | 0 | 0 |
| **Total** | **4** | **24** | **24** | **6** |

Top 4 CRITICAL items (must-fix before next release):
1. `save_manager.gd` L169–180 — `save_completed` emits even when rename AND copy both fail.
2. `local_database.gd` L113–139 — BEGIN/COMMIT return not checked; dual-write atomicity not enforced.
3. `schema.gd` L195–204 — migration 1 destroys data if backup CREATE fails.
4. `inventory_repo.gd` L58–70 — DELETE + re-INSERT loop without transactional guarantee.

### 4.2 correctness-check — silent failures, hidden side effects, non-determinism

Scope: all `v1/scripts/autoload/**` + `v1/scripts/systems/**` + `v1/scripts/rooms/**`. Scanned with `rg` for non-determinism patterns (`randi()`, `Time.get_unix_time`), silent-fail patterns (`pass`, swallowed returns), state-transition enums, and side-effect surfaces.

**Good signals** (found during sweep, no remediation needed):
- No `except: pass` / `empty-except` patterns (GDScript idiom; push_error+return used throughout). Code audits cleanly against the silent-fail rubric at the exception-handler level.
- Every `push_error` site inspected (logger.gd, save_manager.gd, audio_manager.gd, game_manager.gd) pairs with an explicit `return` or state rollback.
- Enumerated state machines are real enums, not magic strings:
  - `AuthManager.AuthState` { LOGGED_OUT, GUEST, AUTHENTICATED } — `v1/scripts/autoload/auth_manager.gd:5`
  - `SupabaseClient.ConnectionState` { OFFLINE, CONNECTING, ONLINE, ERROR } — `v1/scripts/autoload/supabase_client.gd:11`
  - `PetController.State` { IDLE, WANDER, FOLLOW, SLEEP, PLAY, WILD } — `v1/scripts/rooms/pet_controller.gd:5`
  - `Logger.Level` { DEBUG, INFO, WARN, ERROR } — `v1/scripts/autoload/logger.gd:9`

**Findings cross-referenced from § 4.1** (do not re-open — same bug, same fix):

| Ref | Category | Severity |
|---|---|---|
| 4.1.1 L45–47 (supabase no-signal on disabled) | Silent Fail | MEDIUM |
| 4.1.1 L107–113 (refresh_jwt empty-token silent) | Silent Fail | MEDIUM |
| 4.1.1 L161–174 (session save plaintext fallback unchecked) | Silent Fail | HIGH |
| 4.1.1 L297–299 (401 retry lost original request) | Silent Fail | HIGH |
| 4.1.1 L300–311 (404 swallow) | Silent Fail (by design) | HIGH |
| 4.1.1 L422–443 (corrupt payload silently dropped) | Silent Fail | HIGH |
| 4.1.1 L501–502 (deadlock on dropped request) | State-transition deadlock | HIGH |
| 4.1.1 L181 (system-clock JWT expiry) | Non-Determinism | LOW |
| 4.1.2 L169–180 (save_completed emits on cascading failure) | Silent Fail | CRITICAL |
| 4.1.2 L152–158 (store_string unchecked) | Silent Fail | MEDIUM |
| 4.1.2 L177 (SQLite fire-and-forget claiming transactional) | Silent Fail | HIGH |
| 4.1.2 L257–263 (HMAC mismatch → silent default state) | Silent Fail | HIGH |
| 4.1.2 L477–492 (integrity key regen silently on failed persist) | Silent Fail | HIGH |
| 4.1.3 L253 (log file WRITE truncation race) | Silent Fail | HIGH |
| 4.1.3 L133–135 (log-buffer overflow silently drops entries) | Silent Fail | HIGH |
| 4.1.5 L137–140 (bare `randi()` in debug-seeded RNG context) | Non-Determinism | HIGH |
| 4.1.6 L264–270 (re-connect on filter reject accumulating) | State invariant | HIGH |
| 4.1.9 L286–288 (5 s fallback unconditionally clears _transitioning) | State invariant | HIGH |
| 4.1.19 L10–18 (sync_queue retry_count declared unused) | State-field never mutated | HIGH |

**New findings (not in § 4.1):**

* **`v1/scripts/autoload/auth_manager.gd:72`** — `var now := Time.get_unix_time_from_system()` in rate-limit calculation
  **Category**: Non-Determinism
  **Severity**: MEDIUM
  **Evidence**: Uses system wall-clock for rate-limit expiry evaluation. User manipulating system clock backwards permanently extends lockout window. More critical for CI/tests: `AppLogger` and rate-limit logic cannot be tested with injected time — fixture-based tests for "5 failed attempts in 5 min" require real wall-clock waits.
  **Remediation**: Extract a `_get_now_sec() -> float` method; in tests, subclass or patch to return a canned value. For production, can still read `Time.get_unix_time_from_system()`. Status: OPEN.

* **`v1/scripts/autoload/auth_manager.gd:133`** — same pattern (`_lockout_until = Time.get_unix_time_from_system() + ...`)
  **Category**: Non-Determinism
  **Severity**: MEDIUM
  **Evidence**: Same clock-based issue. Lockout duration is wall-clock-denominated; clock change invalidates the lockout.
  **Remediation**: Use `Time.get_ticks_msec()` for monotonic lockout (cannot be rewound by clock edits). Status: OPEN.

* **`v1/scripts/autoload/game_manager.gd:75–93`** — catalog JSON load returns `{}` on every failure mode
  **Category**: Silent Failure
  **Severity**: HIGH
  **Evidence**: `_load_catalog(path)` (L75–93) returns `{}` for: file-not-open, parse-error, and wrong-root-type. Caller cannot distinguish between a missing catalog, corrupt catalog, and legitimately empty catalog. All three downstream paths (characters, decorations, rooms, tracks, badges, mess) silently become empty arrays — the game proceeds with a "character selector with no characters" / "decoration catalog with no decorations" appearance, which users will attribute to their own save, not the true corruption cause.
  **Remediation**: Return `Variant` with `null` sentinel for error paths; caller handles each distinctly. Or emit `SignalBus.catalog_load_failed(path, reason)` and let the UI show a hard-error dialog. Status: OPEN.

* **`v1/scripts/menu/tutorial_manager.gd:300`** — `_arrow.position.y += sin(Time.get_ticks_msec() / 300.0) * 0.3`
  **Category**: Non-Determinism (mild) + Hidden Side Effect
  **Severity**: LOW
  **Evidence**: Position offset is computed from monotonic clock and directly written back into the node's position. Over many frames this produces cumulative floating-point drift on top of the parent-relative position — the arrow slowly walks away from its anchor.
  **Remediation**: Store initial position once, write `initial_y + sin(...)*0.3`, never `+=`. Status: OPEN.

* **Hidden side-effect scan — module/autoload import execution**
  **Category**: Side Effect
  **Severity**: LOW (all clean)
  **Evidence**: Every autoload inspected (signal_bus.gd, logger.gd, local_database.gd, auth_manager.gd, game_manager.gd, save_manager.gd, supabase_client.gd, audio_manager.gd, mood_manager.gd, badge_manager.gd, stress_manager.gd, performance_manager.gd) performs side-effect work only inside `_ready()` — no module-level imperative code. This is Godot-idiomatic and audit-clean.
  **Remediation**: None required. Status: INFO.

* **Non-determinism sweep — float `==` comparisons**
  **Category**: Non-Determinism (LOW)
  **Severity**: LOW
  **Evidence**: `rg -n "== 0.0|== 1.0|== [0-9]" v1/scripts/` found no float equality comparisons in business-critical paths (only int comparisons). Good.
  **Remediation**: None. Status: INFO.

**Section 4.2 roll-up** (new findings only; cross-refs counted in 4.1):
- 1 HIGH (game_manager catalog silent empty)
- 2 MEDIUM (auth_manager wall-clock)
- 2 LOW (arrow drift; clean side-effect scan)

### 4.3 silent-failure-hunter — swallowed errors, bad fallbacks

Scope: the full error-propagation graph — log → signal → UI toast → user decision. Question: when something fails, does the user ever learn?

**Headline finding**: `SignalBus` declares **48 signals** (grep confirmed, `v1/scripts/autoload/signal_bus.gd` line-count 48 `^signal ` matches). Of those, exactly **one** is an error signal: `auth_error(message: String)` on `v1/scripts/autoload/signal_bus.gd:54`. No `save_failed`, `save_integrity_violation`, `sync_error`, `sync_payload_corrupted`, `db_error`, `catalog_load_failed`, `cloud_sync_rejected`, `hmac_mismatch`. The propagation chain is **architecturally open-loop**: every failure in § 4.1 flows into `AppLogger` and stops. Users see either no UI signal or a misleading "success" toast.

This is a structural silent-failure pattern that multiplies every finding in § 4.1 and § 4.2 with severity ≥ MEDIUM. The fix is not local per-file — it is a new signal vocabulary.

**Cross-ref index** (all items surface at logger only, not UI):

| Ref | Failure mode | Currently visible to user? |
|---|---|---|
| 4.1.2 L169–180 | Save file lost | **NO** (save_completed still emits) |
| 4.1.2 L257–263 | Save tampered | NO (load falls through to backup or defaults) |
| 4.1.2 L477–492 | HMAC key lost | NO (next-boot wipes look like "no save") |
| 4.1.1 L422–443 | Queue payload corrupted | NO (item just vanishes) |
| 4.1.1 L300–311 | Supabase table missing | NO (log WARN only) |
| 4.1.4 L113–139 | SQLite transaction broken | NO (dual-write divergence only visible via test) |
| 4.1.11 L195–204 | Migration destroyed data | NO (silent wipe, no recovery UI) |
| 4.1.16 L58–70 | Inventory partially rewritten | NO |
| 4.2 (new) game_manager L75–93 | Catalog load failed | NO (empty collections presented as "normal") |

**New findings (propagation-specific):**

* **`v1/scripts/autoload/signal_bus.gd` — single-error-signal architecture**
  **Category**: Bad Fallback / Propagation Gap
  **Severity**: HIGH
  **Evidence**: 48 signals, 1 error channel. Error-carrying events are encoded as `cloud_connection_changed(ConnectionState.ERROR)` which conflates "connection error" with "sign-in failed" with "table missing". `save_completed` emits even on failure (4.1.2 L180). No event says "save failed, last known good state is X".
  **Remediation**: Add minimum error-signal vocabulary:
  ```gdscript
  signal save_failed(reason: String, last_good_save_path: String)
  signal save_integrity_violation(path: String, hmac_expected: String, hmac_actual: String)
  signal sync_error(operation: String, reason: String)
  signal sync_payload_corrupted(queue_id: int, preview: String)
  signal catalog_load_failed(path: String, reason: String)
  signal db_error(context: String, reason: String)
  ```
  Wire each to `ToastManager` for user-visible feedback with appropriate severity color. Status: OPEN.

* **`v1/scripts/main.gd` toast layer name `"n"`**
  **Category**: Possible Rename Artifact
  **Severity**: LOW
  **Evidence**: `toast_layer.name = "n"` (`v1/scripts/main.gd`, referenced in grep output). Non-descriptive identifier in main scene tree. Likely an incomplete rename from a refactor (`"notifications"` → `"n"`?). Does not impact runtime but confuses scene-tree debugging and `_find_node_by_name` calls (see 4.1.6 L305–309 finding — brittle name lookups).
  **Remediation**: Rename to `ToastLayer` or `NotificationsLayer`. Status: OPEN.

* **No "save failed" user journey**
  **Category**: UX Silent Fail
  **Severity**: HIGH
  **Evidence**: Search for "save failed", "errore salvataggio", "salva fallit" in `v1/locale/it.po` + `v1/locale/en.po` + all UI scripts reveals **zero** translation strings or toast calls for save-failure paths. Users have literally no channel to learn their save failed.
  **Remediation**: Add translation keys `SAVE_FAILED`, `SAVE_INTEGRITY_VIOLATION`, `CLOUD_SYNC_ERROR`. Wire to ToastManager. Status: OPEN.

* **`v1/scripts/autoload/local_database.gd` — db_error never signalled to higher layers**
  **Category**: Propagation Gap
  **Severity**: HIGH
  **Evidence**: `DBHelpers.execute` logs errors (see 4.1.12) but `LocalDatabase` wrapper methods (`get_account`, `save_inventory`, etc.) return default values (`{}`, `false`) with no outward signal. A UI asking "was my game saved?" gets `save_completed` from SaveManager even when the SQLite half failed.
  **Remediation**: Introduce `SignalBus.db_error` (see first finding above); emit from every DBHelpers error site. Status: OPEN.

**Section 4.3 roll-up**: 1 HIGH architectural (signal vocabulary), 2 HIGH application (save UX, DB propagation), 1 LOW (toast name). Multiplies every 4.1 HIGH-and-above finding into HIGH-visible-to-user when considered end-to-end.

### 4.4 security-review — auth, crypto, secrets, input validation

Scope: `v1/scripts/autoload/auth_manager.gd` (full file read), PBKDF2 migration chain (v1 → v2 → v3), HMAC save integrity, Supabase session storage, keystore guards, secret leakage, input validation at boundaries.

**Headline finding**: the password hashing routine is **labeled "PBKDF2" in comments but is NOT RFC 2898 PBKDF2**. This violates the global security rule "Never roll your own crypto" and mislabels the actual construction in a way that misleads reviewers and future maintainers.

#### 4.4.1 `v1/scripts/autoload/auth_manager.gd:198–209` — custom iterated-SHA256, not PBKDF2-HMAC-SHA256

**Status**: **CRITICAL** (crypto mislabeling + weaker construction than claimed)

```gdscript
func _hash_with_salt_iter(
    password: String, salt_hex: String, iter: int,
) -> String:
    # PBKDF2-style iterated SHA-256 using HashingContext.
    var data := (salt_hex + password).to_utf8_buffer()
    var result := _sha256(data)
    for i in range(iter - 1):
        result = _sha256(result + data)
    return result.hex_encode()
```

* **Classification**: Mock Contamination (false security claim)
  **Severity**: **CRITICAL**
  **Evidence**: RFC 2898 PBKDF2-HMAC-SHA256 is defined as:
  ```
  U_1 = HMAC-SHA256(password, salt || INT(i))
  U_2 = HMAC-SHA256(password, U_1)
  …
  U_c = HMAC-SHA256(password, U_{c-1})
  T_i = U_1 XOR U_2 XOR … XOR U_c
  DK  = T_1 || T_2 || … || T_L
  ```
  The code above uses `SHA-256(result ‖ salt‖password)` in a chain. There is **no HMAC**, **no XOR**, and `salt‖password` is concatenated inside the repeated hash rather than fed via HMAC key. This construction:
  1. Is *not* PBKDF2.
  2. Is weaker than PBKDF2-HMAC-SHA256 at the same iteration count because it lacks HMAC's keyed-compression advantage.
  3. Makes GPU-accelerated brute-force easier since each iteration is a single SHA-256 compression round (~half the work of one HMAC-SHA256 round).
  4. Is susceptible to length-extension patterns against the `salt‖password` prefix (mitigated in practice by the fixed output length, but still weaker).
  5. Mislabels the scheme — CHANGELOG.md L34 advertises "PBKDF2 v3 password hashing 100k iter SHA-256" to users. The repo's README and CHANGELOG are making a compliance-adjacent claim that is technically incorrect.
  **Remediation**: Replace with Godot's real primitives. Options:
  - Best: use Godot's `Crypto.hmac_digest(HashingContext.HASH_SHA256, key, data)` — Godot 4+ exposes HMAC. Then implement the RFC 2898 outer-XOR loop.
  - Pragmatic: upgrade to Argon2id via a GDExtension (`godot-argon2` exists) or port a vetted PBKDF2 GDScript implementation.
  - At minimum: rename the helper to `_salted_sha256_loop` and update CHANGELOG/README to accurately describe "iterated salted SHA-256" not "PBKDF2". Do not ship a v1.1 with the misleading label.
  **Migration impact**: All v3 hashes will need re-hashing on next login (same pattern already used for v1/v2 → v3). Introduce `v4:pbkdf2-hmac-sha256:iter:salt:hash`. Status: **OPEN (must fix before v1.1)**.

#### 4.4.2 `v1/scripts/autoload/auth_manager.gd:23–24, 72–78, 130–134` — rate-limit state in-memory only

**Status**: FAIL — HIGH

* **Classification**: Silent Fail (bypass)
  **Severity**: HIGH
  **Evidence**: `_failed_attempts` and `_lockout_until` are instance vars on the autoload. Not persisted. Attacker process-restart loop (quit + relaunch the game, 50 ms cycle on Windows) resets counters to 0. Effective rate limit = 5 attempts per process lifetime, not per account lifetime. Commented as "Rate limit 5 tentativi/5min" in README — actual behavior is "5 tentativi per esecuzione".
  **Remediation**: Persist `_failed_attempts` + `_lockout_until` to `accounts` table (per-user) or a dedicated `rate_limit` table. Reset on successful login. Prefer per-username rate-limit rows — per-process counter is trivially bypassed. Status: OPEN.

#### 4.4.3 `v1/scripts/autoload/auth_manager.gd:49–53` — username validation: length only

**Status**: WARNING — MEDIUM

* **Classification**: Input Validation Gap
  **Severity**: MEDIUM
  **Evidence**: `username.strip_edges()` + length check only (3 ≤ len ≤ `AUTH_MAX_USERNAME_LENGTH`). No charset validation. Accepts:
  - RTL override / invisible Unicode (U+202E, U+200B)
  - NULL byte (may corrupt log output)
  - SQL-reserved names (mitigated by parameterized queries, but UX confusing)
  - Emoji-only names (DB stores, but `display_name` rendering may break)
  - Whitespace in middle (leads to `get_account_by_username` matching issues)
  **Remediation**: Regex whitelist `^[A-Za-z0-9_.-]{3,24}$` (or similar) + NFC normalize. Status: OPEN.

#### 4.4.4 `v1/scripts/autoload/auth_manager.gd:15, 106` — pre-v2 legacy fixed-salt accepted on login

**Status**: WARNING — MEDIUM

* **Classification**: Deprecated Crypto Path
  **Severity**: MEDIUM
  **Evidence**: `_LEGACY_SALT := "MiniCozyRoom2026"` is a single global salt; any stored hash in that format is rainbow-tableable. Code migrates on successful login (L108–109), but accounts that were created pre-v2 and never logged in post-v2-deploy remain vulnerable. The fixed-salt format is also accepted in the login path, meaning an attacker with DB read access can precompute rainbow tables once and crack all stale hashes offline.
  **Remediation**: Log a WARN on every successful legacy verify, counting them; after a grace period (e.g. 60 days post-v1.0 release), refuse legacy verifies entirely and force password reset via `SignalBus.password_reset_required`. Status: OPEN.

#### 4.4.5 `v1/scripts/autoload/auth_manager.gd:153–169` — `delete_account` is soft-delete only

**Status**: WARNING — LOW

* **Classification**: Data Lifecycle Gap
  **Severity**: LOW (game is offline-first, no GDPR obligation currently)
  **Evidence**: `soft_delete_account` (L167) sets a flag but does not purge rows. No hard-delete path exists. If cloud sync is enabled and an account's row was pushed, it persists on Supabase. No cascade to `characters`, `badges_unlocked`, `rooms`, `placed_decorations`.
  **Remediation**: For v1.0 demo this is acceptable (no PII beyond display_name/email). For cloud-enabled release, add `LocalDatabase.hard_delete_account(id)` + `SupabaseClient.request_account_deletion`. Document in privacy policy. Status: DEFERRED.

#### 4.4.6 Session storage — cross-reference to § 4.1

| Ref | Finding | Severity |
|---|---|---|
| 4.1.1 L26 | Session-key derivation uses hardcoded salt + public user_data_dir | LOW (accepted threat model) |
| 4.1.1 L161–174 | Plaintext fallback after encrypted save fails | HIGH |
| 4.1.1 L181 | JWT expiry wall-clock based | LOW |

#### 4.4.7 HMAC save integrity — cross-reference to § 4.1

| Ref | Finding | Severity |
|---|---|---|
| 4.1.2 L257–263 | HMAC mismatch → silent return to defaults | HIGH |
| 4.1.2 L477–492 | Integrity key silently regenerated if persist fails | HIGH |
| 4.1.2 L483 | Hex validation length-only | LOW |

#### 4.4.8 Secret-leakage sweep

| Area | Status |
|---|---|
| `rg -i "api_key|secret|password_hash|jwt" v1/scripts/ | grep -v ".gd:.*#"` | **1 concrete leak** at `v1/scripts/autoload/database/db_helpers.gd:44` (see 4.1.12) — bindings array dumped to log including raw password hashes |
| Supabase `anon_key` | Publishable by design, RLS-protected. Not a leak. |
| `_SESSION_SALT` hardcoded | Documented as accepted threat model (see 4.1.1 L26) |
| Keystore files | CI validator `ci/validate_no_keystore.py` blocks `*.keystore`, `*.jks`, `*.p12`, `*.pfx`, `keystore-credentials.*`. Good. |
| `.env` / `*.cfg.local` | In `.gitignore` (L44–45). Good. |

#### 4.4.9 Input validation sweep — other boundaries

* **`v1/scripts/ui/profile_hud_panel.gd` L207–218** — profile image file path unbounded, see 4.1.7. **HIGH**.
* **`v1/scripts/autoload/supabase_client.gd` L440–443** — id-only delete query, see 4.1.1. **MEDIUM**.
* **No XSS surface** — no web-view/WebKit embedded.
* **No SQL injection surface** — all SQL uses `DBHelpers.execute_bound` with parameters.

#### 4.4.10 Section 4.4 roll-up

| # | Severity | Title |
|---|---|---|
| 4.4.1 | **CRITICAL** | Crypto mislabel: "PBKDF2" label on non-PBKDF2 construction |
| 4.4.2 | HIGH | Rate limit in-memory only, trivially bypassed |
| 4.4.3 | MEDIUM | Username validation: length only, no charset |
| 4.4.4 | MEDIUM | Pre-v2 fixed-salt format still accepted indefinitely |
| 4.4.5 | LOW | Account deletion is soft-delete only |

Plus 5 cross-referenced HIGH from § 4.1 (session plaintext fallback, HMAC mismatch silent, HMAC key regen, profile image path validation, bindings leak).

### 4.5 resilience-check — timeouts, retries, backoff, graceful degradation

Scope: HTTP client (`v1/scripts/utils/supabase_http.gd` full read), Supabase sync engine (`supabase_client.gd` already read in 4.1.1), SQLite busy-timeout, logger buffer overflow, queue bounds.

**Positive resilience patterns observed:**

| Pattern | Location | Rating |
|---|---|---|
| HTTP pool with cap (3 concurrent) | `supabase_http.gd:7` | Good |
| HTTP per-request timeout (15 s) | `supabase_http.gd:8,21` | Good |
| HTTP queue cap (500) with drop-oldest | `supabase_http.gd:9,42–53` | Adequate (+ see finding 4.5.2) |
| Exponential backoff on 429 (B-021) | `supabase_client.gd:312–322` | Good |
| Backoff cap at 5 min | `supabase_client.gd:20` | Good |
| Per-item retry count (SUPABASE_MAX_RETRY=5) | `supabase_client.gd:427` | OK (but unused — see 4.1.19) |
| SQLite WAL mode | `local_database.gd:89` | Good |
| SQLite busy_timeout=5000 ms | `local_database.gd:93` | Good |
| Logger buffer cap (2000) with drop-oldest | `logger.gd:15,133–135` | Adequate (+ see 4.1.3) |
| FPS cap 60 focused / 15 background | `performance_manager.gd` | Good |

**New findings (not in § 4.1):**

#### 4.5.1 `v1/scripts/utils/supabase_http.gd:71–84` — unmatched `disconnect` leaks bound callables

**Status**: FAIL — HIGH

```gdscript
http.request_completed.connect(_on_http_done.bind(http, rid), CONNECT_ONE_SHOT)
var err := http.request(...)
if err != OK:
    http.request_completed.disconnect(_on_http_done)   # <-- does NOT match the bound callable
    _return_to_pool(http)
```

* **Classification**: Silent Fail (use-after-free / callable leak)
  **Severity**: HIGH
  **Evidence**: `connect(_on_http_done.bind(http, rid), CONNECT_ONE_SHOT)` registers a bound Callable; `disconnect(_on_http_done)` (no `.bind(...)`) does not match any connection — Godot 4 signals compare Callables by method + target + bound args. The `disconnect` call silently succeeds as a no-op (Godot does not error on missing connection). The `CONNECT_ONE_SHOT` flag would normally auto-disconnect after emit, but since `request()` returned an error the signal never emits. The HTTPRequest node is returned to `_pool` at L73 with a **stale bound callable still connected**. Next `_send` picks it up, connects a *new* bound callable with the *new* rid; old callable still resident. If request succeeds, both callables fire — `_return_to_pool` removes the node from `_busy` twice (the `erase` at L131 is idempotent, so that specific line survives), but `request_completed` is emitted with the stale rid as well as the new one. Callers see a phantom completion for an rid that was reported as failed earlier.
  **Remediation**: Since `.bind(...)` creates a new Callable each time, you can't reliably disconnect by literal match. Options:
  1. Store the bound Callable in a dict `{http: Callable}` and disconnect via that handle.
  2. Use an unbound `_on_http_done(result, code, headers, bytes)` + lookup rid from `_busy` dict.
  3. Skip the explicit disconnect — rely on CONNECT_ONE_SHOT + emit a synthetic completion (emit `request_completed` with status 0 before returning to pool, which triggers the one-shot). Current code actually does the emit at L74–84 — the bug is only the mis-matched `disconnect`. Removing line 72 (the disconnect) is the minimal fix.
  Status: OPEN.

#### 4.5.2 `v1/scripts/utils/supabase_http.gd:42–51` — drop-oldest silently relies on SQLite sync_queue backup

**Status**: WARNING — MEDIUM

* **Classification**: Silent Fail (compounding)
  **Severity**: MEDIUM
  **Evidence**: Comment at L43–44 claims "L'utente avra` comunque il SQLite sync_queue come backup persistente per retry". But `sync_queue_repo.gd` itself silently drops items on JSON parse error (see 4.1.1 L422–443) and has no retry mechanism wired to its `retry_count` column (see 4.1.19). The defense-in-depth assumption is incorrect: dropping from the HTTP in-memory queue + dropping from the SQLite queue on parse issues = two cumulative silent-loss paths.
  **Remediation**: Wire `SignalBus.sync_payload_dropped(rid)` when drop-oldest fires; verify sync_queue actually has corresponding entry before dropping. Status: OPEN.

#### 4.5.3 `v1/scripts/utils/supabase_http.gd:109–116` — JSON parse failure silently returns raw text as body

**Status**: WARNING — MEDIUM

* **Classification**: Silent Fail (type contract lie)
  **Severity**: MEDIUM
  **Evidence**: When Supabase returns non-JSON (HTML error page, plain-text WAF block, empty body with 204), L113–116 fall through to `parsed = body_text`. The emitted response contract in the rest of the codebase expects `body` to be `Dictionary | Array | null`; a `String` body flows back into `supabase_client.gd:390` `_is_relation_error(body)` which does `body is Dictionary` → false → returns false → error cascades incorrectly.
  **Remediation**: On parse failure of non-empty body, emit with `status: response_code, body: null, error: "Expected JSON, got text: <first 100 chars>"`. Status: OPEN.

#### 4.5.4 No circuit breaker — persistently-failing Supabase wastes pool capacity

**Status**: INFO — LOW (design choice, not bug)

* **Classification**: Gap (missing pattern)
  **Severity**: LOW
  **Evidence**: Backoff at L317 delays the *next sync cycle* but does not park individual failed-request endpoints. If Supabase returns 500 for `/rest/v1/user_settings` specifically (schema bug or WAF rule), every sync cycle retries the same endpoint. No per-endpoint circuit breaker.
  **Remediation**: Not blocking for v1.x. Future: maintain `_endpoint_failure_count: Dictionary`; if > 10 in 5 min, skip that endpoint for 15 min. Status: DEFERRED.

#### 4.5.5 No health check before `start_sync` — burns a pool slot to discover offline state

**Status**: INFO — LOW

* **Classification**: Gap
  **Severity**: LOW
  **Evidence**: `supabase_client.gd:409–419` `start_sync` goes straight to push. Offline-state detection (L293–296) happens only after the first HTTP attempt times out 15 s later. One-way latency wasted per failed cycle.
  **Remediation**: Cheap `HEAD` to `_base_url() + "/rest/v1/"` before pushing — if 0/5xx, bail early. Status: DEFERRED.

#### 4.5.6 Section 4.5 roll-up

| # | Severity | Title |
|---|---|---|
| 4.5.1 | HIGH | HTTP pool bound-callable leak (disconnect no-match) |
| 4.5.2 | MEDIUM | Drop-oldest relies on sync_queue backup that itself silently drops |
| 4.5.3 | MEDIUM | JSON parse failure returns raw text; downstream type contract breaks |
| 4.5.4 | LOW | No per-endpoint circuit breaker |
| 4.5.5 | LOW | No health check before sync |

Cross-refs: 4.1.1 L297–299 (401 retry incomplete), 4.1.1 L422–443 (corrupt payload drop), 4.1.1 L501–502 (sync deadlock), 4.1.19 (retry_count unused).

### 4.6 complexity-check — cyclomatic load, over-engineering, god objects

Scope: every GDScript file ≥200 lines (15 files per 4.1 census).

#### 4.6.1 God-object / file-size risk

Two files exceed the project's own 500-line target and explicitly self-document the debt:

| File | Lines | Self-declared debt | Status |
|---|---|---|---|
| `v1/scripts/autoload/supabase_client.gd` | 547 | `## TODO B-033 post-demo: split auth + sync + session persistence in moduli dedicati per rientrare sotto 500 righe.` (L7–8) | `# gdlint: disable=max-file-lines` directive at L1 |
| `v1/scripts/autoload/save_manager.gd` | 535 | `## TODO B-033 post-demo: split helpers (_migrate, _apply_save_data, HMAC utils) in save_manager/*.gd moduli per rientrare sotto 500 righe.` (L5–6) | Same disable directive |

The TODO+disable pattern is honest — but it becomes a broken-window if other files start using the same disable directive as an excuse. Recommendation: leave disable in place for these two (split is scheduled), but block adding the disable to any new file via a CI check.

#### 4.6.2 Cyclomatic hotspots

Heuristic: `rg -c "if |elif |match |for |while " <file>` control-flow density.

| File | Control-flow tokens | Assessment |
|---|---|---|
| supabase_client.gd (547 L) | ~55 | HIGH — branch density from status code matching + JWT lifecycle |
| save_manager.gd (535 L) | ~45 | HIGH — migration chain + type-check cascade |
| audio_manager.gd (473 L) | ~40 | MEDIUM — stream management + mood switching |
| tutorial_manager.gd (376 L) | ~35 | MEDIUM — signal filter + step state machine |
| local_database.gd (323 L) | ~20 | LOW — mostly thin passthrough |

#### 4.6.3 Over-engineering sweep

Looked for speculative abstractions that do not earn their weight.

* **`v1/scripts/autoload/database/rooms_deco_repo.gd`** — dual storage (JSON blob column + normalized placed_decorations table) is an abstraction without a clear usage-pattern justification. See 4.1.17. **MEDIUM** redundancy.
* **`v1/scripts/utils/supabase_mapper.gd`** (not read exhaustively but grepped) — exists as a separate module for 5 `*_to_cloud` functions; adequate. Not over-engineered.
* **`SignalBus`** — 48 signals. Count is high but proportional to the feature surface and every signal has a named emitter. Not a god-object.

#### 4.6.4 Complexity findings summary

| # | Severity | Title |
|---|---|---|
| 4.6.1 | MEDIUM | 2 files (supabase_client, save_manager) exceed 500 LOC target with self-acknowledged TODO |
| 4.6.2 | MEDIUM | HIGH branch density in supabase_client + save_manager — refactor priority |
| 4.6.3 | MEDIUM | rooms_deco_repo dual-storage adds complexity without documented rationale |

No CRITICAL / HIGH from this skill on its own (the real risk is encoded in § 4.1 as silent-fail findings within these dense files).

### 4.7 db-review — SQLite schema, repo modules, migrations, Supabase schema

Scope: `v1/scripts/autoload/local_database.gd` + 9 files in `v1/scripts/autoload/database/` (schema, db_helpers, accounts, badges, characters, inventory, rooms_deco, settings, sync_queue), plus `supabase/` schema stub.

#### 4.7.1 Schema structure — 9 tables

| Table | Purpose |
|---|---|
| `accounts` | Auth UID + display name + password hash + FK parent for all user state |
| `characters` | Character per account (1:1) |
| `rooms` | Room state (room_type, theme, decorations JSON blob) |
| `placed_decorations` | Normalized deco rows (see 4.1.17 dual-storage concern) |
| `inventario` | Currency + items |
| `badges_unlocked` | Per-account badge unlocks |
| `settings` | Key-value user preferences |
| `music_state` | Playback position (partial, per 4.1.18) |
| `sync_queue` | Pending Supabase upserts |

`PRAGMA foreign_keys=ON`, `PRAGMA journal_mode=WAL`, `busy_timeout=5000` — all good.

#### 4.7.2 Cross-referenced findings from § 4.1

| Ref | Severity | Summary |
|---|---|---|
| 4.1.4 L113–139 | **CRITICAL** | BEGIN/COMMIT return values unchecked; dual-write atomicity claim false |
| 4.1.4 L108–110 | HIGH | Guest-account fallback shadows authenticated writes |
| 4.1.4 L94–96 | MEDIUM | FK-off treated as warn instead of hard-fail |
| 4.1.11 L195–204 | **CRITICAL** | Migration 1 destroys user data if backup-CREATE fails |
| 4.1.11 L188 | HIGH | Migration "already applied" check uses substring match on DDL |
| 4.1.12 L44 | HIGH | `bindings` array dumped to log — raw password_hash leak path |
| 4.1.12 L13 | MEDIUM | SQL truncation at 80 chars hides WHERE context |
| 4.1.13 L28–35 | HIGH | accounts UPDATE return ignored; stale return on failure |
| 4.1.13 L66–79 | HIGH | create_account INSERT unchecked; `last_insert_rowid()` stale on UNIQUE violation |
| 4.1.15 L31 | MEDIUM | `genere` truthy-coercion |
| 4.1.16 L58–70 | **CRITICAL** | inventory DELETE+INSERT without transactional guarantee |
| 4.1.17 L16 | MEDIUM | Dual-storage (JSON blob + normalized rows) with no sync contract |
| 4.1.17 L85–89 | MEDIUM | DELETE of non-existent IDs indistinguishable from success |
| 4.1.18 L143 | MEDIUM | `ambience_enabled` truthy-coercion |
| 4.1.18 L139–146 | MEDIUM | 3 different defaults for `playlist_mode` across stack |
| 4.1.19 L10–18 | HIGH | sync_queue unbounded payload; `retry_count` column exists but never read/written |

#### 4.7.3 Supabase schema

`/home/renan/Projectwork/supabase/` is a stub (per Phase 1 exploration). Schema is pushed-to-cloud by the client without a local `schema.sql` or Supabase migration files under version control. Elia is "actively evolving schema" (see comment at `supabase_client.gd:3–5`).

* **Finding**: Cloud schema is not reproducible from the repo. Any developer wanting to stand up a fresh Supabase project cannot replay it. **HIGH** (ops/onboarding risk), **LOW** (functional risk while the demo runs on the existing Supabase project).
* **Remediation**: `supabase db dump --schema public > supabase/schema.sql`, commit. Also: `supabase migrations list` → commit each generated migration file. Status: OPEN.

#### 4.7.4 Index coverage

No indexes explicitly created in `schema.gd` beyond PRIMARY KEYs. Hot query `get_account_by_auth_uid` + `get_account_by_username` both scan the `accounts` table. For current scale (1–10 accounts per install) this is negligible. For any future scenario with more accounts or a larger save DB (inventory rows per user), add `CREATE INDEX idx_accounts_auth_uid ON accounts(auth_uid);` + `idx_accounts_display_name`.
* **Severity**: LOW (not blocking)
* **Status**: DEFERRED.

#### 4.7.5 Section 4.7 roll-up (new findings only, cross-refs counted in 4.1)

| # | Severity | Title |
|---|---|---|
| 4.7.3 | HIGH (ops) | Supabase schema not version-controlled |
| 4.7.4 | LOW | No indexes beyond PRIMARY KEYs |

### 4.8 state-audit — invariants, lifecycle, concurrency

Scope: stateful autoloads — `GameManager`, `AuthManager`, `SaveManager`, `MoodManager`, `StressManager`, `BadgeManager`, `SupabaseClient`. Plus `PetController` FSM.

#### 4.8.1 State-machine inventory

| Owner | State enum | Transitions explicit? | Invalid transitions rejected? | Concurrency guard |
|---|---|---|---|---|
| `AuthManager.AuthState` | LOGGED_OUT / GUEST / AUTHENTICATED | Yes (`_set_state`) | Not enforced — any caller can move to any state | N/A (single-threaded) |
| `SupabaseClient.ConnectionState` | OFFLINE / CONNECTING / ONLINE / ERROR | Implicit (assigned at multiple call sites) | No | `_is_syncing` flag; see 4.1.1 L501 deadlock finding |
| `PetController.State` | IDLE / WANDER / FOLLOW / SLEEP / PLAY / WILD | Yes (`_change_state`) | No rejection; any → any allowed | N/A |
| `Logger.Level` | DEBUG / INFO / WARN / ERROR | N/A (priority enum, not FSM) | — | — |

#### 4.8.2 Invariant violations

* **`AuthManager._set_state` (L176–185)** — always trusts the caller's `new_state`. No guard like `assert(new_state in AuthState.values())`. A caller could pass an int not in the enum (typed as `int`). Godot 4 int enum typing does not enforce range. **LOW — defensive typing gap.**

* **`SupabaseClient.connection_state`** — written at L121, L185, L200, L202, L295, L356 across 6 call sites with no setter. Any state transition bypasses a central checkpoint. Combined with the deadlock finding (4.1.1 L501), the lack of a centralized setter makes state corruption hard to trace. **MEDIUM — no single funnel for state change.**
  **Remediation**: `func _set_connection_state(new_state: int) -> void: assert(new_state in ConnectionState.values()); if connection_state == new_state: return; connection_state = new_state; SignalBus.cloud_connection_changed.emit(new_state)`.

* **`SaveManager._is_saving` latch** — the only concurrency guard. Does not chain with `_save_dirty` to detect "dirty DURING save". See 4.1.2 L533–535 window-close edge case. **LOW.**

* **`PetController` — any → any transitions allowed** — a `_change_state(WILD)` from SLEEP works. Probably intentional (pets can be jolted awake), but the code has no assertion layer. Harmless here; documented for completeness. **INFO.**

#### 4.8.3 Zombie-state cleanup on startup

* `AuthManager._ready()` (L27–29): tries auto-login; falls back to guest. OK.
* `SupabaseClient._try_restore_session()` (L135–158): restores JWT + schedules refresh. OK.
* `SaveManager`: does NOT detect unfinished saves (e.g. `TEMP_PATH` orphan after crash). **MEDIUM — orphan `user://save_data.tmp.json` may exist after a crash between temp-write and rename; next boot ignores it.**
  **Remediation**: On `_ready`, if `TEMP_PATH` exists and primary doesn't, compare HMACs and adopt the temp. Status: OPEN.

#### 4.8.4 Concurrency / re-entrancy

GDScript is single-threaded at the Node level; `use_threads = false` is set on HTTPRequests (`supabase_http.gd:22`). Real concurrency risk is **signal re-entrancy** and **timer-induced re-entry**.

* **`SaveManager._on_auto_save`** (L110–113): timer tick → `save_game`. `save_game` checks `_is_saving` and bails. Re-entrance safe.
* **`SupabaseClient._on_sync_timer`** (L522–527): backoff + `_is_syncing` check. Re-entrance safe.
* **`SupabaseClient.start_sync`** → `_process_sync_queue` emits many upserts synchronously; each hits HTTP layer. If any of those emit a signal back synchronously (e.g. via `request_completed` path from `_send` at supabase_http.gd L74–84 for immediate error), `_on_request_completed` is called **while still inside `_process_sync_queue`**. Depending on what fields it mutates (clears `_pending_requests[rid]`), iteration state becomes inconsistent.
  **Severity**: MEDIUM — signal-re-entrancy risk, not observed to trigger today but structurally possible.

#### 4.8.5 Section 4.8 roll-up

| # | Severity | Title |
|---|---|---|
| 4.8.2 (SupabaseClient no central setter) | MEDIUM | 6 call sites mutate `connection_state` directly |
| 4.8.3 (orphan temp on save crash) | MEDIUM | No recovery path for `save_data.tmp.json` after abnormal exit |
| 4.8.4 (signal re-entrancy) | MEDIUM | `_process_sync_queue` can be re-entered via synchronous error emit |
| 4.8.2 (_set_state no enum guard) | LOW | `AuthManager._set_state` accepts any int |

Cross-refs: 4.1.1 L501 (sync deadlock), 4.1.6 L264 (tutorial signal accumulation), 4.2 (auth wall-clock lockout).

### 4.9 observability-audit — logging, metrics, correlation IDs, redaction

Scope: `v1/scripts/autoload/logger.gd` (264 L, already read fully in 4.1.3) + cross-cutting use of AppLogger across the codebase + `PerformanceManager`.

#### 4.9.1 Log structure

Format: JSON Lines to `user://logs/<timestamp>-<session_id>.jsonl`. Rotating file cap 5 MB × 5 files. Per-line fields: `t` (timestamp ISO 8601), `level`, `tag`, `msg`, `data` (optional dict), `session_id`.

* **Good**: JSONL is machine-parseable; session_id correlates events; rotating prevents disk fill.
* **Concern**: `session_id` uses only 16 bits of entropy (see 4.1.3 L219–221 finding). In practice, sessions from different devices never converge in one log; collision within a session is what matters. Fine for forensics on a single install.

#### 4.9.2 Correlation

`SupabaseClient` uses per-request `rid` = `<prefix>_<counter>` (`_next_rid`). This is log-local; not echoed to the server side. Cloud-side logs (Supabase dashboard) cannot be joined to client logs.

* **Severity**: LOW (feature request, not bug)
* **Remediation**: Add `x-client-request-id: <rid>` header in `_auth_headers` / `_bearer_headers`. Supabase PostgREST logs it. Status: DEFERRED.

#### 4.9.3 Redaction

`logger.gd` has a `REDACT_KEYS` concept (per 4.1 census, file structure). Items it would redact by key name include: `password`, `password_hash`, `jwt`, `refresh_token`, `api_key`.

**Redaction gap**: only applies to keyed dicts. Positional arrays bypass the filter — see 4.1.12 L44: `bindings` array leaks raw values to logs. **HIGH** (cross-ref).

Second gap: `AppLogger.error` / `warn` call sites frequently pass `{"err": err, ...}` where `err` is a Godot error code int; safe. But `{"path": path, ...}` where path may contain `user_data_dir` (device-specific) is logged plainly. Mild privacy leak (device identifier). **LOW.**

#### 4.9.4 Metrics

`PerformanceManager` (per census) tracks FPS / focused-vs-background state. Not surfaced via AppLogger structured events.

* **Finding**: No counter/metric for: save attempts, save failures, sync cycles, backoff applications, HMAC mismatches, HTTP timeouts. All visible only via grepping INFO/WARN/ERROR lines.
* **Severity**: MEDIUM (operational blindness)
* **Remediation**: Emit `perf.metric.<name>` INFO events on a counter cadence, or ship a `metrics.jsonl` with periodic snapshot. Status: OPEN (v1.1).

#### 4.9.5 Logging hot paths

Concern: under error loops (Supabase 429 storm, HMAC mismatch loop), the logger's buffer (cap 2000 lines) fills quickly — see 4.1.3 L133–135 silent drop. During an incident the most-recent 2000 entries are WARN/ERROR from the storm; the earlier INFO showing when the incident started is dropped. Classic "incident logs lost the start of the incident" pattern.

* **Severity**: MEDIUM (forensic blindness during exactly when you need logs)
* **Remediation**: Dedicated retention for ERROR entries — separate 500-slot error buffer never dropped via normal overflow. Status: OPEN.

#### 4.9.6 Section 4.9 roll-up (new + cross-ref)

| # | Severity | Title |
|---|---|---|
| 4.9.3 (cross-ref 4.1.12) | HIGH | `bindings` array bypasses log redaction |
| 4.9.5 | MEDIUM | Storm-overflow drops early INFO entries (incident-start blindness) |
| 4.9.4 | MEDIUM | No structured metrics for save/sync/error counters |
| 4.9.2 | LOW | No client→server request-id correlation header |
| 4.9.3 (path leak) | LOW | Device path in logs |

### 4.10 api-contract-review — Supabase REST contract, idempotency

Scope: `v1/scripts/utils/supabase_http.gd`, `supabase_client.gd` (request construction), `supabase_mapper.gd` (payload shape).

#### 4.10.1 Request/response contract

Requests: 3 auth flows (signup, signin, refresh) + 3 table operations (fetch, upsert, delete). Headers centralized in `_auth_headers()` / `_bearer_headers()`. Bearer-token formatting correct (`Authorization: Bearer <jwt>`).

Responses: dispatched in `_on_request_completed` by `rid` prefix (`auth_` / `sync_` / other).

* **Strength**: Single funnel for all responses; logic is centralized.
* **Gap**: no schema validation on response bodies. If Supabase returns `{"error": "..."}` with status 200 (rare but possible on some REST backends), the happy-path at L334 treats body as Dictionary and tries `_apply_auth_response` which extracts fields — ends up with empty user_id, triggers L200 ERROR state. Functional but noisy log trail with misleading "Authenticated" (L190) never firing.

#### 4.10.2 Idempotency

* **Upsert** (L219–228): sets `Prefer: resolution=merge-duplicates`. This makes upsert idempotent at the record level. Good.
* **Delete** (L231–237): DELETE `id=eq.<x>` — idempotent (second call returns 0 rows affected). Good.
* **Auth sign-up**: not idempotent on the server side; repeating returns 409/422 via Supabase. Handled at L336–360.
* **Fetch** (L208–216): obviously idempotent.

#### 4.10.3 Retry safety

Upsert + delete are safe to retry under merge-duplicates semantics. Auth flows are not retry-safe — `refresh_jwt` on a stale refresh_token returns 401, which the client re-routes back to `refresh_jwt` if `rid.contains("refresh")` (L354–357). Loop terminates at one hop because subsequent call returns 401 immediately and routes to OFFLINE emit (L356–357). OK.

#### 4.10.4 Request ID correlation — already covered in 4.9.2

#### 4.10.5 Cross-references from § 4.1 that are contract-level

| Ref | Severity | Summary |
|---|---|---|
| 4.1.1 L208–237 | MEDIUM | fetch/upsert/delete return empty-string on not-ready; sentinel undocumented in signature |
| 4.1.1 L297–299 | HIGH | 401 handling drops the original request without retry-queue |
| 4.1.1 L300–311 | HIGH | 404/relation-error swallow — contract with Supabase says missing table → skip |
| 4.1.1 L440–443 | MEDIUM | DELETE builds `id=eq.<empty>` when payload malformed |
| 4.1.1 L494 | MEDIUM | `user_id=eq.` would delete all rows without RLS |
| 4.5.3 | MEDIUM | JSON parse failure returns raw text, contract type-lie |

#### 4.10.6 Section 4.10 roll-up (new findings)

| # | Severity | Title |
|---|---|---|
| 4.10.1 | LOW | No response-schema validation on 2xx bodies |

Section body is small because all API-contract issues are already captured in § 4.1 + § 4.5.

### 4.11 dependency-audit — addons, Python CI, GitHub Actions, landing CDNs

#### 4.11.1 Godot addons

| Addon | Version | Source | Status | Notes |
|---|---|---|---|---|
| `godot-sqlite` | 4.7 | Piet Bronders & Jeroen De Geeter (2peaks.dev) | ACTIVE | Native GDExtension. Compatibility_minimum 4.5; project uses Godot 4.6 ✓. Ships 18 pre-compiled binaries (Linux x86_64/arm64, Windows x86_64, Android arm64/x86_64, macOS, iOS, Web wasm32 threads/no-threads). |
| `virtual_joystick` | 1.0.0 | Carlos Filho (CF Studios) | ACTIVE | GDScript-only plugin. Mobile-gated via `OS.has_feature("mobile")` per B-023 fix. |

* **No known CVEs** for either addon as of 2026-04-23 (checked: github.com/2shady4u/godot-sqlite, github.com/MarcoFazioRandom/Virtual-Joystick-Godot).
* **Binary integrity**: `godot-sqlite/bin/` binaries are committed to repo. No checksums in repo for verifying they match upstream release. **MEDIUM — supply-chain gap**: a future contributor swapping a single `.dll` with a malicious build would be hard to catch via git-diff alone.
  **Remediation**: add `addons/godot-sqlite/SHA256SUMS` listing checksums of each `.dll`/`.so`/`.wasm`; CI verifies. Status: OPEN.

#### 4.11.2 Python CI tooling

`.github/workflows/ci.yml`:
* **Line 45**: `pip install "gdtoolkit>=4,<5"` — range-pinned. Any `4.x` patch accepted. Good.
* **Line 190**: `pip install "Pillow>=10,<12"` — range-pinned across major 10 and 11. Acceptable but consider tightening to `>=10,<11` if Pillow 11 changed API.
* No `requirements.txt` / `pyproject.toml` committed. CI installs inline. Local developer wanting to run validators reads workflow YAML to find the install commands.
  * **Severity**: LOW (reproducibility / onboarding friction). Status: DEFERRED.

#### 4.11.3 GitHub Actions version pinning

All workflow refs (`ci.yml`, `build.yml`, `release.yml`, `pages.yml`) are **major-pinned** (e.g. `actions/checkout@v4`). Renovate / Dependabot would pick up breaking bumps, but in the interim a malicious tag replacement in a compromised upstream action would execute in the pipeline.

| Action | Current pin | Risk |
|---|---|---|
| `actions/checkout@v4` | major | Official GitHub — LOW |
| `actions/setup-python@v5` | major | Official GitHub — LOW |
| `actions/upload-artifact@v4`, `download-artifact@v4` | major | Official — LOW |
| `actions/configure-pages@v5`, `upload-pages-artifact@v3`, `deploy-pages@v4` | major | Official — LOW |
| `lewagon/wait-on-check-action@v1.3.4` | **patch-pinned** | Third-party — already tight ✓ |
| `softprops/action-gh-release@v2` | major | Third-party — MEDIUM |
| Container `barichello/godot-ci:4.6` | tag | Not digest-pinned — MEDIUM (tag could be re-pushed) |

* **Finding**: third-party `softprops/action-gh-release@v2` + container `barichello/godot-ci:4.6` should be SHA-pinned for supply-chain hardening. **MEDIUM.**
* **Remediation**: `uses: softprops/action-gh-release@<commit-sha>` + `container: barichello/godot-ci@sha256:<digest>`. Dependabot PRs then surface the upgrade. Status: OPEN.

#### 4.11.4 Landing page CDN dependencies

From `/home/renan/Projectwork/docs/index.html` (full read in Phase 1 review):

| URL | Version pin | SRI | Risk |
|---|---|---|---|
| `https://unpkg.com/lucide@latest` (L15) | **UNPINNED (`latest`)** | None | **HIGH** — any upstream release instantly changes shipped landing page; no SRI catches a compromised upstream |
| `https://cdn.jsdelivr.net/particles.js/2.0.0/particles.min.js` (L18) | 2.0.0 pinned | None | MEDIUM — jsDelivr is reputable but no SRI |
| `https://unpkg.com/aos@2.3.1/dist/aos.css` (L21) | 2.3.1 pinned | None | MEDIUM — unpkg; no SRI |
| `https://unpkg.com/aos@2.3.1/dist/aos.js` (L22) | 2.3.1 pinned | None | MEDIUM — same |
| `https://fonts.googleapis.com/css2?...` (L12) | N/A | N/A | LOW — Google-hosted |
| `https://static.prod-images.emergentagent.com/jobs/.../*.png` (L125, L181) | ephemeral CDN path | N/A | **HIGH** — third-party image hosting with unknown SLA; if image 404s the landing page looks broken |

* **Finding 4.11.4a** — Lucide pinned to `@latest` is the loudest issue. Any Lucide update (API change, accidental 404) instantly breaks or silently alters the shipped site. **HIGH.**
* **Finding 4.11.4b** — `emergentagent.com` CDN is out of the team's control and not versioned. Images can 404 at any time. **HIGH.**
* **Finding 4.11.4c** — No Subresource Integrity (SRI) hashes on any CDN script/style. A compromised unpkg or jsDelivr edge node serving altered code would execute in the user's browser. Unlikely but a supply-chain risk. **MEDIUM.**

**Remediation (executed in Phase 6)**:
1. Pin Lucide to a concrete version, e.g. `https://unpkg.com/lucide@0.445.0/dist/umd/lucide.min.js` with SRI.
2. Self-host hero + mascot images under `docs/assets/`.
3. Add `integrity=sha384-...` + `crossorigin="anonymous"` to `particles.min.js`, `aos.js`, `aos.css`, Lucide.

#### 4.11.5 Section 4.11 roll-up

| # | Severity | Title |
|---|---|---|
| 4.11.4a | HIGH | Landing page ships Lucide Icons `@latest` — uncontrolled |
| 4.11.4b | HIGH | Hero + mascot images on emergentagent.com — third-party CDN, unknown SLA |
| 4.11.4c | MEDIUM | No SRI on any CDN script/style |
| 4.11.3 (softprops + container) | MEDIUM | Third-party action + container not SHA-pinned |
| 4.11.1 | MEDIUM | godot-sqlite binaries committed without checksums |
| 4.11.2 | LOW | Python deps installed inline in CI, no requirements.txt |

### 4.12 change-impact — cross-references for to-be-deleted docs

Executed pre-flight for Phase 5 (doc prune). `rg -l` sweep across the repo for every doomed `.md` identifier (excluding the doomed files themselves from self-refs).

#### 4.12.1 Runtime-impact refs (MUST fix before delete)

* **`scripts/preflight.sh:150–154`** — uses `test -f v1/docs/speech_renan.md` etc. as GO/NO-GO gate. Deleting the speech files **will make preflight fail** with exit 1, breaking the release pipeline pre-demo checks.
  ```
  150: check "pptx presentazione presente" "test -f Mini-Cozy-Room-Presentazione-Progetto.pptx"
  151: check "speech_renan presente" "test -f v1/docs/speech_renan.md"
  152: check "speech_elia presente" "test -f v1/docs/speech_elia.md"
  153: check "speech_cristian presente" "test -f v1/docs/speech_cristian.md"
  154: check "speech_esteso presente" "test -f v1/docs/speech_esteso.md"
  ```
  **Severity**: HIGH (blocks preflight).
  **Remediation**: Remove L151–154 entirely (demo has shipped; speech files no longer needed). Keep L150 (pptx still exists). Apply edit in Phase 6 **before** the prune commit in Phase 5, OR batch both in Phase 5.

#### 4.12.2 Comment-only / docstring refs (SHOULD fix but non-blocking)

| File:line | Reference | Action |
|---|---|---|
| `ci/validate_no_keystore.py:86` | `"See docs/ANDROID_SIGNING.md §9 (incident response)."` | Update print string to reference CHANGELOG or remove |
| `v1/export_credentials.cfg.example:16,18` | Comments referencing `docs/ANDROID_SIGNING.md`, `BUILD_RELEASE_PLAN.md §3` | Rewrite to reference CHANGELOG + inline note |
| `scripts/generate_keystores.sh:4` | `# BUILD_RELEASE_PLAN.md §3).` | Remove reference |
| `scripts/ci/extract_changelog.py:9` | `Fase E del piano BUILD_RELEASE_PLAN §6.` | Remove reference |
| `ci/extract_palette.py:4` | `Automates Task 1 of v1/guide/GUIDA_ALEX_PIXEL_ART.md.` | Remove or rewrite to self-explain |
| `ci/scaffold_character.py:4` | `Run once per character (Task 2 / Task 3 of GUIDA_ALEX_PIXEL_ART.md)` | Remove |
| `ci/validate_pixelart_deliverables.py:2` | `"""Validate pixel-art deliverables per v1/guide/GUIDA_ALEX_PIXEL_ART.md."""` | Rewrite docstring |
| `v1/tests/integration/test_catalogs.gd:18` | `# AND the docs (README, speech, pptx, DEEP_READ_REGISTRY).` | Remove |

**Severity**: LOW-MEDIUM (dead pointers in comments, no runtime impact).
**Batch**: apply in a single commit `chore(refs): purge dead doc pointers after prune`.

#### 4.12.3 Surviving README-level cross-refs (Phase 4 README refresh)

Surviving files that contain links / paths to doomed docs and MUST be updated during README refresh:

| File | Refs to doomed docs |
|---|---|
| `README.md` (root) | `CONSOLIDATED_PROJECT_REPORT.md`, `DEEP_READ_REGISTRY_2026-04-16.md` (L67, L68) |
| `v1/README.md` | multi-ref; full rewrite planned |
| `v1/addons/README.md` | references to deleted guides |
| `v1/assets/README.md` | Ditto |
| `v1/assets/charachters/README.md` | Ditto |
| `v1/data/README.md` | Refs Elia guide |
| `v1/docs/diagrams/README.md` | May reference speech docs |
| `v1/guide/README.md` | Central index to ALL deleted team guides — will become stub |
| `v1/guide/references/README.md` | Refs LICENSE_NOTES (kept) + deleted docs |
| `v1/scenes/README.md` | Minor refs |
| `v1/scripts/README.md` | Ditto |
| `v1/tests/README.md` | Refs TASKS_CLOSED |

All 12 are on the Phase 4 edit list.

#### 4.12.4 Landing page refs

`docs/team/cristian.html`, `docs/team/elia.html`, `docs/team/renan.html` were flagged in the grep. Need read-through in Phase 6 to confirm whether they *quote* content from speech_*.md (in which case the content survives because it's already inline in HTML) or *link* to those files (in which case the link is dead once git pushes to Netlify — landing page doesn't ship `.md` files anyway, so this is moot).

**Severity**: LOW. Verified in Phase 6.

#### 4.12.5 Section 4.12 roll-up

| # | Severity | Title |
|---|---|---|
| 4.12.1 | HIGH | `scripts/preflight.sh` L151–154 uses doomed speech files as gate |
| 4.12.2 | LOW-MEDIUM | 7 files have comment/docstring refs to doomed docs |
| 4.12.3 | LOW | 12 surviving READMEs + root link to doomed docs |
| 4.12.4 | LOW | 3 team HTML subpages may reference speech_*.md |

### 4.13 data-lifecycle-review — save/load/backup/migration/account deletion

Scope: every data touchpoint from account creation through deletion.

#### 4.13.1 Account lifecycle

| Stage | Mechanism | Gap |
|---|---|---|
| Creation | `AuthManager.register` → `LocalDatabase.create_account` | INSERT return unchecked (4.1.13 L66–79) |
| Authentication | Guest / PBKDF2-like / legacy | Custom KDF mislabeled "PBKDF2" (4.4.1 CRITICAL) |
| Update (pw change) | `LocalDatabase.update_password_hash` | Called transparently on v1/v2→v3 migration (auth_manager L120) |
| Soft delete | `AuthManager.delete_account` → `soft_delete_account` (sets flag) | No hard-delete path (4.4.5) |
| Hard delete | **Not implemented** | Data retained indefinitely locally and on cloud |
| Logout | `sign_out()` → `_set_state(LOGGED_OUT, {})` | Session file not cleared; next boot may auto-restore |

#### 4.13.2 Save lifecycle

| Stage | Mechanism | Cross-ref |
|---|---|---|
| Auto-save | 60 s timer (`SAVE_INTERVAL`) when dirty | OK |
| Window-close | `NOTIFICATION_WM_CLOSE_REQUEST` → save_game | 4.1.2 L533 re-entrancy gap |
| Atomic write | temp + rename + backup | 4.1.2 L169–180 CRITICAL |
| HMAC | `_compute_hmac` on save+load | 4.1.2 L257 silent loss, L477 key regen |
| Backup rotation | Single backup (BACKUP_PATH) | No historical retention |
| Load fallback | primary → backup → defaults | 4.1.2 silent default slide |

**Gap**: only one backup (`save_data.backup.json`). If both primary and backup are corrupted, user loses everything. No N-deep versioned backups.
* **Severity**: MEDIUM
* **Remediation**: ring of 3 dated backups (`save_data.backup.1.json`, `.2.json`, `.3.json`). Status: OPEN.

#### 4.13.3 Migration chain

Version chain: `1.0.0 → 2.0.0 → 3.0.0 → 4.0.0 → 5.0.0`. Handled in `_migrate_save_data` (L332–416).

* **Chain-break risk**: migration is a single flat `if` ladder. Adding `6.0.0` requires a new `if version == "5.0.0":` block. Easy to forget forward-only direction.
* **Forward-compat**: save from newer app than SAVE_VERSION logs WARN and returns data unchanged (L338–340). Caller applies as-is, possibly crashing on unknown fields. **MEDIUM.**
* **v3→v4 inventory silent reset**: 4.1.2 L381–395 (MEDIUM).
* **Migration not transactional**: partial migration leaves half-v4, half-v5 dict. On crash mid-migration, next boot re-enters migration and re-applies steps already done (idempotent for `erase` + `assign` patterns, not for `coins += delta` patterns — which this codebase fortunately does not use).

#### 4.13.4 Sync queue lifecycle

| Stage | Cross-ref |
|---|---|
| Enqueue | `LocalDatabase.enqueue_sync` (sync_queue_repo) — 4.1.19 unbounded payload |
| Process | `supabase_client._process_sync_queue` L422 — 4.1.1 silent drop on parse err |
| Retry | `retry_count` column exists but never used — 4.1.19 |
| Clear | `clear_sync_item(queue_id)` on success or max-retry (4.1.1 L427) |
| Bound | No size limit on rows; `sync_queue` table can grow unbounded |

**Gap**: sync_queue has no row cap. A user offline for days with many edits fills the table indefinitely. SQLite handles it, but disk footprint grows silently.
* **Severity**: LOW (offline is temporary; 1000+ rows still fit in a few MB)
* **Remediation**: add `CREATE TRIGGER trim_sync_queue AFTER INSERT ... WHEN rows > 1000 DELETE oldest N`. Status: DEFERRED.

#### 4.13.5 Cloud-side lifecycle (Supabase)

Per `supabase_client.gd:446–498` (`_push_local_state`):
* Pushes: profiles, user_currency, user_settings, music_preferences, room_decorations.
* Pull paths: `fetch_table` exists but no call sites visible in the codebase — cloud→local sync is not wired. **Pure push model.**
* Conflict resolution: `merge-duplicates` on server side (PostgREST), so last-write-wins per row.

**Gap**: no cloud→local sync. If user plays on device B, device A never sees B's changes. Claimed "cross-device sync" in README is **asymmetric**. **MEDIUM** (UX misrepresentation), but acceptable for v1.0 demo. Post-demo, add pull sync on `start_sync`.

#### 4.13.6 Retention / GDPR

* Account deletion is soft (flag only, 4.4.5).
* No user-initiated data export (GDPR portability).
* No data retention policy documented.
* Offline-first + local-SQLite means most data is user-owned; cloud has only what was pushed.

**Severity**: LOW (academic project scope, no GDPR obligation)
**Status**: DEFERRED (post-v1.x).

#### 4.13.7 Section 4.13 roll-up (new findings)

| # | Severity | Title |
|---|---|---|
| 4.13.1 (no hard delete) | LOW | Soft-delete only; no hard-delete path |
| 4.13.2 (single backup) | MEDIUM | Only 1 backup file; no versioned ring |
| 4.13.3 (newer-than-app save) | MEDIUM | Forward-compat path returns data unchanged, risk of crash on unknown fields |
| 4.13.4 (unbounded sync_queue rows) | LOW | No row cap |
| 4.13.5 (no cloud → local pull) | MEDIUM | Asymmetric sync misrepresents "cross-device" claim |

Cross-refs: 4.1.2 L169 (save atomicity), L257 (HMAC), L477 (key regen), L381 (inventory migration); 4.1.19 (sync_queue retry_count unused); 4.4.1 (crypto mislabel); 4.4.5 (soft delete).

---

## 5. Cross-cutting summary

### 5.1 Severity roll-up

| Section | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| 4.1 deep-audit (19 files) | 4 | 24 | 24 | 6 |
| 4.2 correctness (new only) | 0 | 1 | 2 | 2 |
| 4.3 silent-failure-hunter | 0 | 3 | 0 | 1 |
| 4.4 security | 1 | 1 | 2 | 1 |
| 4.5 resilience | 0 | 1 | 2 | 2 |
| 4.6 complexity | 0 | 0 | 3 | 0 |
| 4.7 db-review (new only) | 0 | 1 | 0 | 1 |
| 4.8 state-audit | 0 | 0 | 3 | 1 |
| 4.9 observability (new only) | 0 | 0 | 2 | 2 |
| 4.10 api-contract (new only) | 0 | 0 | 0 | 1 |
| 4.11 dependency | 0 | 2 | 3 | 1 |
| 4.12 change-impact | 0 | 1 | 0 | 2 |
| 4.13 data-lifecycle | 0 | 0 | 3 | 2 |
| **TOTAL (new + cross-ref)** | **5** | **34** | **44** | **22** |

### 5.2 Top-5 must-fix items (CRITICAL) — pre-v1.1

1. **`v1/scripts/autoload/auth_manager.gd:198–209`** — Custom iterated SHA-256 mislabeled "PBKDF2"; replace with real PBKDF2-HMAC-SHA256 (Godot 4 `Crypto.hmac_digest` + RFC 2898 outer XOR) or Argon2id via GDExtension. **Security / crypto / spec-compliance.**
2. **`v1/scripts/autoload/save_manager.gd:169–180`** — `save_completed` signal fires even when rename AND copy both fail. Add failure detection and route to a new `SignalBus.save_failed` signal. **Data integrity.**
3. **`v1/scripts/autoload/local_database.gd:113–139`** — BEGIN/COMMIT return values unchecked; dual-write atomicity is not actually enforced despite the code structure implying it. **Data integrity.**
4. **`v1/scripts/autoload/database/schema.gd:195–204`** — Migration 1 destroys `characters` table without verifying the backup CREATE succeeded. **Data loss risk on boot.**
5. **`v1/scripts/autoload/database/inventory_repo.gd:58–70`** — DELETE + re-INSERT loop without transactional wrapping; partial failure destroys inventory. **Data loss risk on save.**

### 5.3 Deferred-remediation index

All items marked `Status: OPEN` above are candidates for a post-audit remediation sprint. Suggested ordering: CRITICAL (5 items) → security HIGH (PBKDF2 ecosystem, rate-limit persistence, bindings log leak) → save/sync HIGH (signal vocabulary, cloud→local pull, orphan temp recovery) → MEDIUM cluster → LOW cluster.

### 5.4 Files touched this session (plan forward)

- `AUDIT_REPORT_2026-04-23.md` (this report) — CREATED
- 21 README files — TO REFRESH (Phase 4)
- 42 non-README `.md` files — TO DELETE (Phase 5)
- `scripts/preflight.sh` — trim speech-file checks (Phase 4 pre-delete)
- 7 code files with dead doc-pointer comments — purge (Phase 4)
- `netlify.toml` (NEW at repo root) — CREATE (Phase 6)
- `docs/index.html` — direct download URLs, self-host images, SRI pins, version badge (Phase 6)
- `docs/_headers` — CREATE (Phase 6)
- `docs/_redirects` — CREATE (Phase 6)
- `docs/assets/hero.png`, `docs/assets/mascot.png` — CREATE (Phase 6)

### 5.5 Pre-deploy checklist

Before `netlify deploy --prod --dir=docs`:
- [ ] All 21 READMEs refreshed and dead-linked docs purged
- [ ] `preflight.sh` speech-file checks removed
- [ ] `netlify.toml` at repo root has `publish = "docs"`
- [ ] Download button hrefs verified via `curl -sfSI -L` returning 200
- [ ] `docs/assets/hero.png` + `mascot.png` exist
- [ ] SRI hashes present on all CDN scripts
- [ ] Lucide Icons pinned to a concrete version (not `@latest`)
- [ ] `docs/_headers` + `docs/_redirects` committed
- [ ] `python3 -m http.server -d docs 8765` serves `/` 200 with theme toggle + particles + AOS working
- [ ] Git tree clean; all commits authored `Renan Augusto Macena`, no AI / co-author trailers
- [ ] Tarball snapshot `/home/renan/audit-snapshots/Projectwork_2026-04-23.tar.gz` exists (safety net)

---

## 5. Cross-cutting summary (appended at end of session)

_Section pending — populated after all 13 skill sections complete._

### 5.1 Severity roll-up
_Pending._

### 5.2 Files touched this session
_Pending._

### 5.3 Deferred-remediation index
_Pending._

### 5.4 Pre-deploy checklist
_Pending._

---

_End of scaffold. Sections will be populated in the order listed in § 4._
