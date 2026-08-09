# Audit Re-verification — 2026-08-09

Re-verification of `MASTER_PLAN_2026-07-20.md` findings against current `main`
(94f1ce5, v1.1.0 + DevBridge), plus the first **dynamic audit** performed through
the DevBridge (`--bridge`, 127.0.0.1:8080) and live player field reports.

- **Method**: 5 parallel verification agents re-read each CRITICAL/HIGH register
  entry and judged it ONLY against current code (register statuses were a
  2026-07-20 snapshot, stale after v1.1.0). Dynamic session: scripted
  bridge run (status / commands / events ring / logs / screenshot / quit) plus
  one unscripted player session.
- **Scope**: all 5 CRITICAL + 43 HIGH V-findings, all 15 HIGH G-gaps = **63
  items re-verified**. MEDIUM/LOW (V-048..V-122, G-016..G-070, ~132 items)
  **not re-verified in this pass**.

## 1. Headline

| Verdict | Count | Items |
|---|---|---|
| FIXED | **55** | everything not listed below |
| PARTIAL | 4 | V-019, V-034, G-004, G-011 |
| OPEN | 4 | V-021, V-022, G-003, G-007 |
| New findings (dynamic) | 4 | DYN-1..DYN-4 |
| New findings (player) | 3 | PLR-1..PLR-3 |

All five CRITICALs are confirmed FIXED in current code (real PBKDF2 v4,
SAVEPOINT-wrapped inventory writes, verified migration backups, checked
BEGIN/COMMIT/ROLLBACK, honest `save_completed`).

## 2. Still OPEN (from register)

| ID | Sev | Finding | Current evidence |
|---|---|---|---|
| V-021 | HIGH | Missing auth_uid row still unconditionally upserts guest email for ANY uid (incl. real authenticated ones) | `local_database.gd:144-145` (moved into `_resolve_save_account_id`) |
| V-022 | HIGH | Log redaction filter still skips Arrays — array-nested values bypass REDACT_KEYS | `logger.gd:114-132` (no Array branch; known exploit at call site closed, class of bug open) |
| G-003 | HIGH | build.yml keystore injection still a no-op: `export_presets.cfg` has no `keystore/*` keys, sed matches nothing | `export_presets.cfg:113-114`, `build.yml:194-196` |
| G-007 | HIGH | Cloud sync still push-only; `fetch_table` branch unreachable; README still claims "sync cross-device" | `supabase_client.gd:659-767`, `README.md:5` |

## 3. PARTIAL (from register)

| ID | Sev | Residual gap |
|---|---|---|
| V-019 | HIGH | Catalog-load failure now distinct + logged, but non-fatal, and the boot-time `catalog_load_failed` emit fires before any toast listener exists — user never sees it |
| V-034 | HIGH | refresh_token no longer plaintext, but JWT still written unencrypted in the cfg fallback; no error signal on encryption failure |
| G-004 | HIGH | preflight literal NO-GO persists: 5 untracked `.uid` files dirty the tree check (`ambience_controller`, `test_crypto`, `test_i18n_assets`, `test_phase_f`, `test_save_failures`) |
| G-011 | HIGH | Auth static labels localized, but form validation errors and AuthManager backend errors remain hardcoded English |

## 4. New findings — dynamic audit (DevBridge)

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| DYN-1 | HIGH (UX) | **Quit-from-menu requires two closes.** Final save at menu is skipped by design (`save_skipped_state_not_loaded`), but `_final_save_and_quit` treats the skip as FAILURE: retries, logs `Final save failed twice, staying alive; close again to force quit`. Every player quitting from the menu hits this | `save_manager.gd:330,343,1171-1197`; observed live via `/quit` |
| DYN-2 | MEDIUM | **Logger shutdown race.** On WM_CLOSE, AppLogger (autoload #2) closes its file before SaveManager (#6) finishes; shutdown WARN/ERROR flushes hit a null handle → engine `Parameter "f" is null` spam and lost final log lines | `logger.gd:63,208-227` vs SaveManager shutdown logging; observed live |
| DYN-3 | LOW | `save_requested` at menu produces NO bus outcome (`save_completed`/`save_failed` both absent; log-only WARN) — "skipped" is not a first-class observable outcome | events ring capture, 2026-08-09 session |
| DYN-4 | INFO | Exit leaks: `4 ObjectDB instances` + `1 resource still in use` at process exit (possibly 4.7.1-runtime-specific) | console tail, both sessions |

Dynamic positives (evidence for the record): clean boot with zero WARN/ERROR;
locale applied at boot (G-010 confirmed live); mood→stress→bus cascade correct —
`set_stress 0.75` → `stress_changed(0.75, "tense")` → `mood_changed("tense")`
3 ms later; hysteresis levels correct; passive decay observed (0.75→0.7489 in
3 s); fps stable at 60 through all interactions; panel open/close and live
language switch logged cleanly in the player session.

## 5. New findings — player field reports (2026-08-09, live session)

| ID | Sev | Report | Root cause (verified in code) |
|---|---|---|---|
| PLR-1 | HIGH (UX) | Rain SOUND at sun-end of mood slider; lowering darkens but shows no rain drops and rain sound fades | Content mapping, not code: the "calm" music track IS a rain recording (`rain_loop`, tracks.json:4-7) and `ambience_rain_soft` is tagged for ALL moods incl. calm (tracks.json:28-38); rain VISUALS gated at mood < **0.15** (`MOOD_GLOOMY_THRESHOLD`, constants.gd:72) while darkening starts at 0.5 (mood_manager.gd:46-58) — huge "dark but no rain" dead zone, and sunny plays rain audio |
| PLR-2 | HIGH (UX) | No interaction/collision with placed decorations (character + cat) | Three verified causes: (1) **interaction system is dead code** — `interaction_type` present in 0/129 catalog entries, so the Area2D branch (room_base.gd:263-281) never runs; (2) physics footprint is only a 70%×30% strip at sprite base (room_base.gd:8-9) — character overlaps most of the sprite freely; (3) cat ignores furniture BY DESIGN (`pet_controller.gd:36`, mask=walls only) |
| PLR-3 | MEDIUM | Character walks outside the room floor borders | Not G-013 (drift is reverted — polygon intact, centroid matches boot log). Boundary is a hollow segment fence (`main.tscn:44-48`, build_mode 1); character controller has no `clamp_inside_floor` (pet got it in V-043, character relies on physics only). Needs a live movement repro to pin (bridge has no input injection yet — candidate DevBridge v1.1 feature) |

## 6. Recommendation (feeds the isometric-vs-polish decision)

1. **Quick-wins polish batch** (small, high player impact): DYN-1 (treat
   save-skip as success on quit), DYN-2 (logger close ordering), PLR-1 (mood
   thresholds + audio content mapping), V-021, V-022, V-019 residual, G-011
   residual.
2. **Fold PLR-2 + PLR-3 into the isometric upgrade design** — furniture
   collision/interaction and floor containment are exactly the room-physics
   layer the isometric rework rebuilds; fixing them twice would be waste.
3. **Decide or de-claim**: G-003 (Android signing) and G-007 (cloud pull) are
   scope decisions — implement or remove the claims (README/build).
4. **Hygiene**: commit the 5 missing `.uid` files (closes G-004's tree check).
5. Later pass: re-verify the ~132 MEDIUM/LOW register items.

## 7. Asset gaps

Content holes that no amount of code can close — they need a file that does not
exist in the repo. Listed here so a fix attempt does not get re-litigated as a
bug.

| ID | Area | Gap | Consequence today |
|---|---|---|---|
| AG-1 | Music | **No calm, non-rain music track exists.** `v1/assets/audio/music/` holds exactly two files and BOTH are rain recordings: `mixkit-light-rain-loop-1253.wav` (catalogued as `rain_loop`, "Light Rain", covering `calm`+`neutral`) and `mixkit-light-rain-with-thunderstorm-1290.wav` (`rain_thunder`, `tense`+`stormy`) | The PLR-1 fix removed rain from the calm **ambience** bed (now fireplace) and aligned rain **visuals** with the darkening ramp, but the calm band's **music** is still a rain recording. Un-tagging `rain_loop` from `calm`/`neutral` would leave the sunny half of the mood slider with no music at all (`_pick_mood_track_index` returns -1 → no crossfade), which is worse. Needs a real acquisition: one loopable, royalty-clear, non-rain ambient/lo-fi track (~1–3 min) re-tagged as `calm`+`neutral`, demoting `rain_loop` to `tense` |

Not fabricated, synthesised or downloaded as part of the fix: acquiring audio is
a licensing decision, not a code change.

## 8. Raw verdict data

Agent outputs (verbatim verdict lines) retained in session transcript
2026-08-09; per-finding one-liners available on request. Verifiers: 5×
independent agents, adversarial instructions, code-only evidence.
