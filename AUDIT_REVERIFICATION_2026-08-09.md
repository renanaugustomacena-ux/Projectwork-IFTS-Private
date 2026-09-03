> Istantanea storica. Stato corrente: vedi CHANGELOG 1.3.0 e il piano 2026-09-03.

# Audit Re-verification — 2026-08-09

Re-verification of `MASTER_PLAN_2026-07-20.md` findings against current `main`
(94f1ce5, v1.1.0 + DevBridge), plus the first **dynamic audit** performed through
the DevBridge (`--bridge`, 127.0.0.1:8080) and live player field reports.

- **Method**: 5 parallel verification agents re-read each CRITICAL/HIGH register
  entry and judged it ONLY against current code (register statuses were a
  2026-07-20 snapshot, stale after v1.1.0). Dynamic session: scripted
  bridge run (status / commands / events ring / logs / screenshot / quit) plus
  one unscripted player session.
- **Scope, wave 1** (this document as originally written): all 5 CRITICAL + 43
  HIGH V-findings, all 15 HIGH G-gaps = **63 items**.
- **Scope, wave 2** (added after the fact, § 4): the MEDIUM/LOW remainder —
  V-049..V-127 (79) plus G-016..G-070 (55) = **134 items**. Same method, same
  code-only rule.
- Register total: V-001..V-127 (127) + G-001..G-070 (70) = **197 findings**,
  now all re-verified (63 + 134 = 197).

## 1. Headline

### Wave 1 — CRITICAL + HIGH (63 items)

| Verdict | Count | Items |
|---|---|---|
| FIXED | **55** | everything not listed in § 2 / § 3 |
| PARTIAL | 4 | V-019, V-034, G-004, G-011 |
| OPEN | 4 | V-021, V-022, G-003, G-007 |

55 + 4 + 4 = 63.

### Wave 2 — MEDIUM/LOW (134 items, § 4)

| Verdict | Count | Items |
|---|---|---|
| FIXED | **105** | everything not listed in § 4 |
| PARTIAL | 14 | § 4.2 (13 entries, V-071/V-072 counted as two) |
| OPEN | 15 | § 4.1 (14 entries, V-117/V-118 counted as two) |

105 + 14 + 15 = 134.

### Register total (both waves)

| Verdict | Count |
|---|---|
| FIXED | **160** |
| PARTIAL | 18 |
| OPEN | 19 |
| **Total** | **197** |

160 + 18 + 19 = 197 — the whole register, no item left unjudged.

New findings raised by this re-verification, outside the register:

| Source | Count | Items |
|---|---|---|
| Dynamic audit (DevBridge) | 4 | DYN-1..DYN-4 |
| Player field reports | 3 | PLR-1..PLR-3 |

All five CRITICALs are confirmed FIXED in current code (real PBKDF2 v4,
SAVEPOINT-wrapped inventory writes, verified migration backups, checked
BEGIN/COMMIT/ROLLBACK, honest `save_completed`).

> **Reading order matters.** The wave-1 tables (§ 1, § 2, § 3) record the state
> at re-verification time, before any fix landed. § 4 records wave 2, verified
> later the same day. § 9 lists the 16 register items and 3 new findings that
> branch `fix/audit-followup-2026-08-09` closed — which is why several wave-1
> OPEN/PARTIAL entries are no longer open in the working tree. Where the two
> disagree, § 9 is the current state.

## 2. Still OPEN (from register)

State at re-verification time. All four were closed on
`fix/audit-followup-2026-08-09` the same day — V-021 and V-022 fixed, G-003
and G-007 de-claimed. See § 9.

| ID | Sev | Finding | Current evidence |
|---|---|---|---|
| V-021 | HIGH | Missing auth_uid row still unconditionally upserts guest email for ANY uid (incl. real authenticated ones) | `local_database.gd:144-145` (moved into `_resolve_save_account_id`) |
| V-022 | HIGH | Log redaction filter still skips Arrays — array-nested values bypass REDACT_KEYS | `logger.gd:114-132` (no Array branch; known exploit at call site closed, class of bug open) |
| G-003 | HIGH | build.yml keystore injection still a no-op: `export_presets.cfg` has no `keystore/*` keys, sed matches nothing | `export_presets.cfg:113-114`, `build.yml:194-196` |
| G-007 | HIGH | Cloud sync still push-only; `fetch_table` branch unreachable; README still claims "sync cross-device" | `supabase_client.gd:659-767`, `README.md:5` |

## 3. PARTIAL (from register)

State at re-verification time. V-019, G-004 and G-011 were closed the same day
(§ 9); **V-034 is the one still open** — the JWT is still written unencrypted
in the cfg fallback and an encryption failure raises no signal.

| ID | Sev | Residual gap |
|---|---|---|
| V-019 | HIGH | Catalog-load failure now distinct + logged, but non-fatal, and the boot-time `catalog_load_failed` emit fires before any toast listener exists — user never sees it |
| V-034 | HIGH | refresh_token no longer plaintext, but JWT still written unencrypted in the cfg fallback; no error signal on encryption failure |
| G-004 | HIGH | preflight literal NO-GO persists: 5 untracked `.uid` files dirty the tree check (`ambience_controller`, `test_crypto`, `test_i18n_assets`, `test_phase_f`, `test_save_failures`) |
| G-011 | HIGH | Auth static labels localized, but form validation errors and AuthManager backend errors remain hardcoded English |

## 4. MEDIUM/LOW re-verification (wave 2)

Second wave, completed after this document was first written. Same rule: each
entry judged only against current code. 105 of 134 came back FIXED; the 29
residuals are below.

### 4.1 Still OPEN

| ID | Residual |
|---|---|
| V-055 | account lockout deadline uses wall clock — clock rewind extends/clears lockout |
| V-062 | SQLite foreign-key check is warn-only; init proceeds |
| V-094 | user-data path logged verbatim |
| V-102 | any 2xx dict accepted as auth response, no schema check |
| V-112 | CI pip installs unpinned, no requirements file |
| V-116 | delete_account is soft-delete only; child rows survive, no cloud purge |
| V-117 / V-118 | session key from constant salt + public path — accepted design |
| V-120 | 429 backoff is global, no per-endpoint breaker |
| V-121 | no health probe before sync |
| G-024 | Android export job stays green despite failure |
| G-027 | Android launcher icons unset |
| G-031 | decoration category headers English-only |
| G-042 | male_yellow_shirt incomplete, female set missing |
| G-051 | default-language literals disagree across files, no canonical constant |

### 4.2 PARTIAL

| ID | Residual |
|---|---|
| V-050 | two macOS addon binaries absent from SHA256SUMS, unverified |
| V-054 | legacy pre-v2 password hashes accepted indefinitely, no cutoff |
| V-066 | a valid temp save NEWER than a valid primary is deleted, not adopted — an interrupted save is still lost |
| V-071 / V-072 | v3 inventory reset is preserved to a file but still silent to the user |
| V-073 | cloud-disabled state change is a no-op at boot, observers never notified |
| V-079 | cloud DELETE filter is id-only, tenant isolation relies entirely on RLS |
| V-086 | metric registry exists but save/sync/HMAC/db counters uninstrumented |
| V-093 | no index on accounts.display_name |
| G-018 | badge/HUD icons still emoji, badge icon_path dead, no fallback font shipped |
| G-044 | mess label_it/label_en dead |
| G-046 | 3 .aseprite sources + 6 cat animations undelivered |
| G-054 | exit-time leak persists |
| G-055 | log file still eagerly created |

Two of these are now documented rather than fixed, deliberately: V-079 is
called out in `supabase/README.md` and `v1/data/README.md` as the known limit
of an id-only DELETE filter, and G-042 / G-044 are recorded in the asset
READMEs so the missing female set and the dead mess labels are not
re-discovered as bugs.

## 5. New findings — dynamic audit (DevBridge)

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

## 6. New findings — player field reports (2026-08-09, live session)

| ID | Sev | Report | Root cause (verified in code) |
|---|---|---|---|
| PLR-1 | HIGH (UX) | Rain SOUND at sun-end of mood slider; lowering darkens but shows no rain drops and rain sound fades | Content mapping, not code: the "calm" music track IS a rain recording (`rain_loop`, tracks.json:4-7) and `ambience_rain_soft` is tagged for ALL moods incl. calm (tracks.json:28-38); rain VISUALS gated at mood < **0.15** (`MOOD_GLOOMY_THRESHOLD`, constants.gd:72) while darkening starts at 0.5 (mood_manager.gd:46-58) — huge "dark but no rain" dead zone, and sunny plays rain audio |
| PLR-2 | HIGH (UX) | No interaction/collision with placed decorations (character + cat) | Three verified causes: (1) **interaction system is dead code** — `interaction_type` present in 0/129 catalog entries, so the Area2D branch (room_base.gd:263-281) never runs; (2) physics footprint is only a 70%×30% strip at sprite base (room_base.gd:8-9) — character overlaps most of the sprite freely; (3) cat ignores furniture BY DESIGN (`pet_controller.gd:36`, mask=walls only) |
| PLR-3 | MEDIUM | Character walks outside the room floor borders | Not G-013 (drift is reverted — polygon intact, centroid matches boot log). Boundary is a hollow segment fence (`main.tscn:44-48`, build_mode 1); character controller has no `clamp_inside_floor` (pet got it in V-043, character relies on physics only). Needs a live movement repro to pin (bridge has no input injection yet — candidate DevBridge v1.1 feature) |

## 7. Recommendation (feeds the isometric-vs-polish decision)

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
5. Later pass: re-verify the MEDIUM/LOW register items.

Status of this recommendation: (1), (4) and (5) are **done** — see § 4 and § 9.
(3) resolved by de-claiming both: Android is now labelled experimental and
unsigned, cloud is now documented as push-only backup. (2) still stands: PLR-2
and PLR-3 are deliberately deferred into the isometric rework.

## 8. Asset gaps

Content holes that no amount of code can close — they need a file that does not
exist in the repo. Listed here so a fix attempt does not get re-litigated as a
bug.

| ID | Area | Gap | Consequence today |
|---|---|---|---|
| AG-1 | Music | **No calm, non-rain music track exists.** `v1/assets/audio/music/` holds exactly two files and BOTH are rain recordings: `mixkit-light-rain-loop-1253.wav` (catalogued as `rain_loop`, "Light Rain", covering `calm`+`neutral`) and `mixkit-light-rain-with-thunderstorm-1290.wav` (`rain_thunder`, `tense`+`stormy`) | The PLR-1 fix removed rain from the calm **ambience** bed (now fireplace) and aligned rain **visuals** with the darkening ramp, but the calm band's **music** is still a rain recording. Un-tagging `rain_loop` from `calm`/`neutral` would leave the sunny half of the mood slider with no music at all (`_pick_mood_track_index` returns -1 → no crossfade), which is worse. Needs a real acquisition: one loopable, royalty-clear, non-rain ambient/lo-fi track (~1–3 min) re-tagged as `calm`+`neutral`, demoting `rain_loop` to `tense` |

Not fabricated, synthesised or downloaded as part of the fix: acquiring audio is
a licensing decision, not a code change.

## 9. Closed on branch `fix/audit-followup-2026-08-09`

Everything below was fixed, verified and committed on 2026-08-09, after the
tables in § 1 were written. The suite is green at **196 pass / 0 fail across 15
modules** (`./scripts/deep_test.sh`), `gdlint` clean, `gdformat --check` clean.

### Register items

| ID | Was | Now | How |
|---|---|---|---|
| V-019 | PARTIAL | FIXED | boot-time catalog failures queue in `_pending_catalog_failures`; `main.gd` drains them right after wiring toasts, so the user actually sees the failure |
| V-021 | OPEN | FIXED | `_resolve_save_account_id()` mints the `offline@local` row only for the guest uid; a real authenticated uid with no row logs ERROR, returns `-1`, and `apply_save` aborts with `db_error` |
| V-022 | OPEN | FIXED | one redaction pass feeds both the JSONL line and the console line (they were separate paths, console started from raw context), and it now descends into Arrays |
| G-004 | PARTIAL | FIXED | the 5 untracked `.uid` files are committed; preflight's tree check is clean |
| G-011 | PARTIAL | FIXED | form-validation errors and `AuthManager` backend errors go through translation keys instead of hardcoded English |
| G-034 / G-035 | — | FIXED | the confirm dialogs that delete a character and an account are localized |
| G-036 / G-050 | — | FIXED | internal ids and fixed strings removed from HUD, toasts and the decoration edit handles |
| G-053 | — | FIXED | the suite runs in a throwaway user dir with a `.test_sandbox` sentinel the runner requires; a direct Godot invocation of `test_runner.tscn` aborts instead of overwriting the real player profile; CI asserts the real user dir never appears |
| G-003 | OPEN | DE-CLAIMED | no-op keystore injection removed, false release gate removed, `*.apk` dropped from release assets, job renamed "sperimentale, non firmato", export forced to debug |
| G-007 | OPEN | DE-CLAIMED | every doc reworded from "sync cross-device" to push-only cloud backup; code unchanged, as decided |
| G-017 | — | FIXED | `assets/room/` and `assets/charachters/` READMEs reconciled with the disk: dropped `bed/`, `floor_mess1-3.png`, `door.png` and the whole `female/` set; added `male_rose`, in the catalog and undocumented |
| G-026 | — | FIXED | exec bit restored on `preflight.sh`, `build_apk_local.sh`, `deep_test.sh`, `godot-validate.sh`, `smoke_test.sh` — all were 100644, so the documented `./scripts/...` invocation exited 126 |
| G-048 | — | FIXED | root README said "Tutorial 9 step"; `_define_steps()` defines 8 |
| G-063 | — | FIXED | `profile_hud_panel.gd` docstring stopped calling profile image, badges, language and mood "post-demo placeholders" months after they shipped |

### Findings raised by this re-verification

| ID | Now | How |
|---|---|---|
| DYN-1 | FIXED | a skipped save at the menu is `SaveOutcome.NOTHING_TO_SAVE`, a success — quitting from the menu no longer needs two closes |
| DYN-2 | FIXED | AppLogger closes its file at teardown; shutdown flushes no longer hit a null handle |
| PLR-1 | FIXED | rain visuals and the soft-rain ambience both start below mood 0.50, aligned with the darkening ramp; thunderstorm music below 0.25; pet WILD below 0.10. The calm ambience bed is fireplace, not rain |

### Still open after this branch

- **DYN-3**: a skipped save still produces no bus outcome. Neither
  `save_completed` nor `save_failed` fires; "skipped" lives only in a WARN log
  line. The quit path no longer misreads it, but it is still not a first-class
  observable.
- **DYN-4**: exit-time leaks persist (see also G-054).
- **V-034**: the only wave-1 PARTIAL not closed. The JWT is still written
  unencrypted in the cfg fallback, and a failed encryption raises no signal.
- **PLR-2**, **PLR-3**: deliberately folded into the isometric rework.
- **AG-1**: no calm, non-rain music track exists. Unchanged — acquiring audio
  is a licensing decision, not a code change (§ 8).
- The 29 MEDIUM/LOW residuals of § 4.

## 10. Raw verdict data

Agent outputs (verbatim verdict lines) retained in session transcript
2026-08-09; per-finding one-liners available on request. Verifiers: 5×
independent agents, adversarial instructions, code-only evidence.
