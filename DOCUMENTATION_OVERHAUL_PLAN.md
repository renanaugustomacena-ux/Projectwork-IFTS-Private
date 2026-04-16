# Documentation Overhaul — Relax Room

## Context

Before pushing 22 local commits to origin/main, we need to clean up all project documentation. The game name is officially **Relax Room** but most docs still say "Relax Room". The consolidated report (2,500 lines) is bloated with resolved audit history. Cristian's guide assigns blame for bugs he didn't cause. Duplicate files exist across folders. Goal: single source of truth, concise, only open tasks, correct metrics, respectful tone.

## Progress

**Phase 1: DONE** — Deleted `MiniCozyRoom_DA_CONFRONTARE/`, `v1/SPRINT_WALKTHROUGH.md`, `v1/TECHNICAL_GUIDE.md`

**Phase 2-7: NOT STARTED** — Interrupted, resume next session.

---

## Verified Current Metrics (from codebase scan)

| Metric | Old (report) | Actual |
|--------|-------------|--------|
| GDScript files | 36 | 35 |
| LOC (GDScript) | 5,289 | 6,963 |
| Scenes (.tscn) | 42 | 39 |
| Assets | ~490 | 588 |
| Decorations | 69 / 11 cat | 97 / 13 cat |
| Characters | 1 | 3 |
| Signals (SignalBus) | 31 | 37 |
| Autoload singletons | 7 | 9 |
| Deadline | 17 Apr | 22 Apr 2026 |

---

## Phase 1: Delete Dead Weight — DONE

| Action | Path | Status |
|--------|------|--------|
| Delete folder | `MiniCozyRoom_DA_CONFRONTARE/` (archived duplicates) | DONE |
| Delete file | `v1/SPRINT_WALKTHROUGH.md` (historical sprint log) | DONE |
| Delete file | `v1/TECHNICAL_GUIDE.md` (generic Godot tutorial) | DONE |

All content preserved in git history.

---

## Phase 2: Rewrite Cristian's Guide

**File:** `v1/guide/GUIDA_CRISTIAN_CICD.md` (1,123 -> ~80 lines)

**Approach:** Clean slate. Remove ALL completed task walkthroughs, educational content, and blame-adjacent language. Only open tasks remain.

**New structure:**
1. Header with role, deadline, reference links
2. Quick summary: "All CI/CD and code tasks complete. Remaining work below."
3. **Task 6**: Update documentation references (~1 hour, LOW priority)
4. **Task 8**: Find/create additional graphic assets — loading screen, extra decorations (1-2 hours, MEDIUM priority, evaluate if needed for presentation)
5. Brief reference section (CI pipeline location, setup guide link)

**Key principle:** No history of who fixed what. No condescending explanations.

---

## Phase 3: Trim Consolidated Report

**File:** `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` (2,500 -> ~400-500 lines)

**KEEP (with updated metrics):**
- Part I: Executive Summary + Stack + Metrics (corrected numbers)
- Part II: Architecture diagrams, autoload order, signal map, data flows
- Part VIII S31: Open PR plan (only PRs 1-4)
- Part IX: Build & Deployment instructions
- Part X: Troubleshooting
- Appendix B: Database Schema
- Appendix C: Signal Registry (updated to 37)
- Appendix I: Useful Commands

**CUT entirely:**
- Part III: Stato Componenti (historical audit verdicts)
- Part IV: Analisi Codice Riga per Riga (historical script-by-script review)
- Part V: Diagnosi Bug Runtime (historical bug analysis, open bugs captured in PR plan)
- Part VI: Registro Audit Completo (12-pass audit history)
- Part VII: Piano UX (historical acceptance criteria)
- Part VIII S29-30: Sprint schedule/tasks (completed history)
- Part VIII S31.1-33.2: Execution plans, validation protocols, stabilization plans
- Part XI: Statistiche (replaced by corrected Part I metrics)
- Part XII: Guide Operative (redundant with SETUP_AMBIENTE.md)
- Appendices A, D, E, F, G, H, J, K (glossary, inventories, changelogs — low value)

---

## Phase 4: Trim Other Guides

**`v1/guide/GUIDA_RENAN_GAMEPLAY_UI.md`** (1,509 -> ~100 lines)
- Remove 21 completed task walkthroughs
- Keep only 4 open PRs with brief descriptions:
  - PR 1: Floor bounds unification (CRITICO)
  - PR 2: Pet animations per state
  - PR 3: Character flicker investigation
  - PR 4: Decor categories UX

**`v1/guide/GUIDA_ELIA_DATABASE.md`** (683 -> ~50 lines)
- Remove 7 completed task walkthroughs
- Keep only open task: Supabase integration (Phase 4)

**`v1/guide/README.md`** (280 -> ~60 lines)
- Clean index: link to each guide, current open tasks per person, deadline
- Remove historical sprint info, dependency maps, validation checklists

**`v1/guide/SETUP_AMBIENTE.md`** (664 lines — keep mostly as-is)
- Rename "Relax Room" -> "Relax Room" throughout
- Quick scan for outdated sections

---

## Phase 5: Rename "Relax Room" -> "Relax Room" Everywhere

**Config files:**
- `v1/project.godot`: `config/name` and `project/assembly_name`
- `v1/export_presets.cfg`: export path `MiniCozyRoom.exe` -> `RelaxRoom.exe`

**Documentation (after rewrites):**
- `README.md` (root)
- `v1/README.md`
- `v1/guide/SETUP_AMBIENTE.md`
- `v1/docs/presentazione_progetto.md` (lines 89, 286)
- `v1/study/*.md` (10 files — simple find/replace)
- Sub-folder READMEs in `v1/assets/`, `v1/addons/`, `v1/scenes/`, `v1/scripts/`, `v1/data/`, `v1/tests/`

**Landing page:**
- `docs/index.html` (~8 occurrences)
- `docs/main.js` (1 occurrence)

---

## Phase 6: Update Root README.md

- Title: "Relax Room"
- Correct all metrics (decorations, signals, characters, assets)
- Update "Funzionalita' Implementate" (3 characters, 97 decorations, tutorial system, character selection)
- Update "Stato dei Sistemi" table
- Clean up landing page URLs

---

## Phase 7: Update v1/README.md

- Fix vision section: "Relax Room nasce da..." (not "Relax Room")
- Correct all metric references throughout
- Update data catalog descriptions (97 decorations/13 cat, 3 characters)
- Verify scene tree diagrams match actual main.tscn

---

## Verification

After all edits:
1. `grep -rn "Relax Room" .` — should return 0 hits (except git history)
2. `grep -rn "MiniCozyRoom" . --include="*.md" --include="*.html"` — 0 hits in docs
3. Verify consolidated report < 500 lines: `wc -l v1/docs/CONSOLIDATED_PROJECT_REPORT.md`
4. Verify all guides < 120 lines each
5. Open Godot project briefly to confirm project.godot loads with new name
6. Visual scan of each rewritten file for tone/accuracy

---

## Files Modified (Summary)

| File | Action |
|------|--------|
| `MiniCozyRoom_DA_CONFRONTARE/` | DELETE — DONE |
| `v1/SPRINT_WALKTHROUGH.md` | DELETE — DONE |
| `v1/TECHNICAL_GUIDE.md` | DELETE — DONE |
| `v1/guide/GUIDA_CRISTIAN_CICD.md` | REWRITE (1123->80) |
| `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` | REWRITE (2500->450) |
| `v1/guide/GUIDA_RENAN_GAMEPLAY_UI.md` | REWRITE (1509->100) |
| `v1/guide/GUIDA_ELIA_DATABASE.md` | REWRITE (683->50) |
| `v1/guide/README.md` | REWRITE (280->60) |
| `v1/guide/SETUP_AMBIENTE.md` | RENAME only |
| `README.md` (root) | UPDATE metrics + name |
| `v1/README.md` | UPDATE metrics + name |
| `v1/project.godot` | RENAME (2 lines) |
| `v1/export_presets.cfg` | RENAME export path |
| `v1/docs/presentazione_progetto.md` | RENAME (2 occurrences) |
| `docs/index.html` | RENAME (~8 occurrences) |
| `docs/main.js` | RENAME (1 occurrence) |
| `v1/study/*.md` (10 files) | RENAME |
| Sub-folder READMEs (~8 files) | RENAME |
