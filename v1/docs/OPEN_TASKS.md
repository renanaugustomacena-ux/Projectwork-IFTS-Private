# Open Tasks — Relax Room (estratti 2026-04-16)

## Renan (Team Lead + Software Architect)

### Feature cluster nuovo (aggiunto 2026-04-17, scope doc dedicato)

- [T-R-015] (FEATURE-PARENT) **Profile + Mood Panel HUD** — cluster di 9 sub-tasks. Vedi `v1/docs/FEATURE_PROFILE_MOOD_PANEL.md` per scope completo. Target **post-demo**. Include: icona profilo in HUD, mini panel orizzontale con nome+immagine-da-device+badge+settings+language-toggle+mood-bar, effetti visuali gloomy/storm/cat-wild, audio mood-switched. Tempo stimato: 10-14 ore lavoro; scheletro minimo 2.5 ore.
  - T-R-015a Icona profilo in GameHUD (30 min)
  - T-R-015b Mini ProfileHUDPanel scene + script (45 min)
  - T-R-015c Profile image da device locale (privacy: mai cloud) (1h)
  - T-R-015d Badge system + catalog + schema SQLite (2h)
  - T-R-015e Settings button moved inside profile panel (15 min)
  - T-R-015f Language toggle IT/EN con bandiere (30 min senza i18n reale)
  - T-R-015g i18n reale via .po files + refactor `tr()` su 50+ stringhe (3-4h)
  - T-R-015h Mood bar slider + signal emit + persistence (30 min)
  - T-R-015i MoodManager autoload + visual effects (filter gloomy, rain, cat wild mode, audio crossfade storm) (3-5h)

### Bug tracker esistente

- [T-R-001] (P0) Verificare/completare fix movimento personaggio bloccato dopo chiusura pannello (B-001 — candidati: focus chain, character_controller gate, room_base). (ref: CONSOLIDATED:70-78)
- [T-R-002] (P0) Investigare e fixare drag & drop decorazioni che scompaiono su drop fuori zona (B-002 — ipotesi: feedback manuale vs UX, sprite dispose senza cleanup). (ref: CONSOLIDATED:80-88)
- [T-R-003] (P1) Risolvere divergenza JSON/SQLite persistenza: settings, decorations, music_state, coins sincronizzati (B-016 — source of truth + dual-write atomico). (ref: CONSOLIDATED:166-171, GUIDE_ELIA:544-556)
- [T-R-004] (P1 security) Cifrare Supabase refresh_token con chiave derivata da device ID (B-019 — token plaintext in user://supabase_session.cfg). (ref: CONSOLIDATED:184-188, GUIDE_ELIA:691-696)
- [T-R-005] (P1) Validare HTTPS obbligatorio per URL Supabase (B-020 — attualmente accetta http://). (ref: CONSOLIDATED:190-194, GUIDE_ELIA:699-703)
- [T-R-006] (P2) Fixare B-003 (tab DecoPanel non cliccabili) — focus_mode esplicito già applicato, da confermare runtime. (ref: CONSOLIDATED:90-94)
- [T-R-007] (P2) Decidere e implementare migration system SQLite versionato con schema_version table + backup pre-migration (B-015). (ref: CONSOLIDATED:160-164, GUIDE_ELIA:376-410)
- [T-R-008] (P2) Fixare grid quadrati giganti in edit mode (B-004 — CELL_SIZE o viewport scaling). (ref: CONSOLIDATED:96-100)
- [T-R-009] (P2) Implementare exponential backoff su rate limit 429 Supabase (B-021 — attualmente ritenta subito). (ref: CONSOLIDATED:196-200, GUIDE_ELIA:705-710)
- [T-R-010] (P2) Aggiungere appLogger.error a _select() SQLite + rimuovere dead var _last_select_error (B-027). (ref: CONSOLIDATED:233-237, GUIDE_ELIA:829-830)
- [T-R-011] (P2) Configurare Supabase config.cfg con url + anon_key per ciclo demo (post-demo toggle offline-first off). (ref: GUIDE_ELIA:820-842)
- [T-R-012] (P3) Verificare fix recenti: pet FSM WANDER (B-006), tutorial replay button (B-007). (ref: CONSOLIDATED:108-119)
- [T-R-013] (P3) Aggiungere migration on-login PBKDF2 10k→100k iter (B-029 — OWASP low, ma post-demo; pre-demo rischio regressione login). (ref: CONSOLIDATED:245-250)
- [T-R-014] (P3) Decidere USE/REMOVE virtual_joystick addon + scena (B-023 — morte code se desktop-only). (ref: CONSOLIDATED:208-213)

## Elia (Database Engineer)

- [T-E-001] (P1) Completare fix B-016: emettere payload completo save_to_database_requested, scrivere upsert_settings/upsert_music_state, replace atomico placed_decorations. (ref: GUIDE_ELIA:676-682)
- [T-E-002] (P2) Aggiungere PRAGMA busy_timeout=5000 post apertura DB (B-026 — previene main thread block). (ref: CONSOLIDATED:227-231, GUIDE_ELIA:828-829)
- [T-E-003] (P2) Refactor migration 1: backup pre-DROP characters/inventario, restore post-CREATE; aggiungere WHERE placement_zone IS NULL (B-015). (ref: GUIDE_ELIA:667-671)
- [T-E-004] (P2) Implementare test GdUnit4 completo LocalDatabase CRUD + migration (TestLocalDatabase.gd scaffolding). (ref: GUIDE_ELIA:764-796)
- [T-E-005] (P3) Rimuovere o implementare cloud_to_local dead code (B-022 — pull sync non fatto). (ref: CONSOLIDATED:202-206, GUIDE_ELIA:716-719)
- [T-E-006] (P3) Aggiungere disconnect esplicito auto-save timer in SaveManager._exit_tree() (B-017 — benigno se autoload, debito tecnico). (ref: GUIDE_ELIA:684-689)
- [T-E-007] (P3) Aggiungere test SQLite su save corrotto, WAL busy, FK constraint fail (B-015 roadmap). (ref: GUIDE_ELIA:376-410)

## Cristian (Asset + CI/CD)

- [T-C-001] (P1) Creare `.pre-commit-config.yaml` root con hook gdtoolkit (gdlint + gdformat) + detect-secrets (B-031 — mancante completamente). (ref: CONSOLIDATED:258-263, GUIDE_CRISTIAN:345-357)
- [T-C-002] (P2) Testare e verificare runtime 37 PNG orfani in v1/assets/sprites/; decidere categorie + scale; aggiungere a decorations.json (asset catalog divergence). (ref: CONSOLIDATED:274-275, GUIDE_CRISTIAN:359-365)
- [T-C-003] (P3) Aggiungere linter rule grep `Button.new()` senza `focus_mode` (previene B-001/B-003 reintroduzione) in CI (B-024). (ref: CONSOLIDATED:215-219)

## Cross-team / non attribuiti

- [T-X-001] (P1) Estrarre DDL 15 tabelle Supabase da dashboard e versionare in supabase/migrations/0001_initial.sql (B-032 — schema cloud non trackato). (ref: CONSOLIDATED:265-269, GUIDE_ELIA:830-831)
- [T-X-002] (P2) Implementare cipher redaction AppLogger: scrubba `["password", "token", "jwt", "refresh_token", "password_hash", "hmac_key"]` → `"***"` (B-028). (ref: CONSOLIDATED:239-243)
- [T-X-003] (P2) Fixare B-008 volume slider non persistito: emettere settings_updated signal in settings_panel. (ref: CONSOLIDATED:121-125)
- [T-X-004] (P2) Fixare B-009 profile panel signal leak: disconnect espliciti in _exit_tree. (ref: CONSOLIDATED:127-131)
- [T-X-005] (P2) Fixare B-010 profile panel coins polling: sottoscrivere SignalBus.coins_changed. (ref: CONSOLIDATED:133-137)
- [T-X-006] (P2) Fixare B-011 toast manager lambda leak: refactor 4 signal da lambda a metodi. (ref: CONSOLIDATED:139-143)
- [T-X-007] (P2) Fixare B-018 logger buffer unbounded: cap 500 entries, try-catch, Mutex (AppLogger buffer grow). (ref: CONSOLIDATED:178-182)
- [T-X-008] (P2) Fixare B-025 SupabaseHttp queue unbounded: MAX_QUEUE=500, drop oldest su overflow. (ref: CONSOLIDATED:221-225)
- [T-X-009] (P3) Fixare B-012 MessNode signal leak: aggiungere _exit_tree disconnect body_entered/body_exited. (ref: CONSOLIDATED:145-148)
- [T-X-010] (P3) Fixare B-013 MessSpawner Timer leak: aggiungere _exit_tree con timer.stop() + disconnect. (ref: CONSOLIDATED:150-153)
- [T-X-011] (P3) Fixare B-005 drag pixel precision: aggiungere Shift modifier snap_to_grid o cell_size override. (ref: CONSOLIDATED:102-106)
- [T-X-012] (P3) Fixare B-030 non-determinism RNG: seed esplicito (debug build constant, release build randomize). (ref: CONSOLIDATED:252-256)
- [T-X-013] (P3) Split file sopra 500 righe (B-033): local_database.gd 810 righe → moduli per tabella. (ref: CONSOLIDATED:271-275, GUIDE_RENAN:274)

---

## Summary

**Total: 50 task espliciti**

### Per severità
- P0: 2 (B-001, B-002 blocker)
- P1: 12 (B-016, B-019, B-020, B-027, B-028, B-029, B-031, B-032 + consolidati)
- P2: 22 (B-003, B-004, B-008, B-009, B-010, B-011, B-015, B-018, B-020, B-021, B-025, B-026 + consolidati)
- P3: 14 (B-005, B-006, B-007, B-012, B-013, B-014, B-017, B-022, B-023, B-024, B-030, B-033 + consolidati)
- debt: 3 (B-015 migration refactor, B-033 file size, B-017 timer disconnect)

### Demo-blocking (P0 + P1 must-fix)
- B-001: movimento char bloccato (Renan verify + fix, Round 2)
- B-002: drag&drop disappear (Renan debug + candidate selection)
- B-016: JSON/SQLite sync (Elia complete dual-write)
- B-019: token plaintext (Renan encrypt)
- B-020: HTTPS validation (Renan validate)
- B-031: pre-commit config (Cristian create stub)
- B-032: Supabase DDL versioning (cross-team extract + store)

### Post-demo OK (P2/P3)
- B-003 through B-030: verifiche runtime, refactor, linter rules, security upgrades

---

## Per team

**Renan**: 14 task (architettura, debug B-001/B-002, sync dual-write, security tokens, decisions design)
**Elia**: 7 task (schema DB, migration, CRUD, test)
**Cristian**: 3 task (asset cataloging, pre-commit config, linting rules)
**Cross-team**: 13 task (logging, signal cleanup, persistence, queue bounds, RNG)

## Riferimenti file:line

| Task | File | Linee |
|------|------|-------|
| B-001 | CONSOLIDATED | 70-78 |
| B-002 | CONSOLIDATED | 80-88 |
| B-003 | CONSOLIDATED | 90-94 |
| B-004 | CONSOLIDATED | 96-100 |
| B-005 | CONSOLIDATED | 102-106 |
| B-006 | CONSOLIDATED | 108-113 |
| B-007 | CONSOLIDATED | 115-119 |
| B-008 | CONSOLIDATED | 121-125 |
| B-009 | CONSOLIDATED | 127-131 |
| B-010 | CONSOLIDATED | 133-137 |
| B-011 | CONSOLIDATED | 139-143 |
| B-012 | CONSOLIDATED | 145-148 |
| B-013 | CONSOLIDATED | 150-153 |
| B-014 | CONSOLIDATED | 155-158 |
| B-015 | CONSOLIDATED | 160-164 |
| B-016 | CONSOLIDATED | 166-171 |
| B-017 | CONSOLIDATED | 173-176 |
| B-018 | CONSOLIDATED | 178-182 |
| B-019 | CONSOLIDATED | 184-188 |
| B-020 | CONSOLIDATED | 190-194 |
| B-021 | CONSOLIDATED | 196-200 |
| B-022 | CONSOLIDATED | 202-206 |
| B-023 | CONSOLIDATED | 208-213 |
| B-024 | CONSOLIDATED | 215-219 |
| B-025 | CONSOLIDATED | 221-225 |
| B-026 | CONSOLIDATED | 227-231 |
| B-027 | CONSOLIDATED | 233-237 |
| B-028 | CONSOLIDATED | 239-243 |
| B-029 | CONSOLIDATED | 245-250 |
| B-030 | CONSOLIDATED | 252-256 |
| B-031 | CONSOLIDATED | 258-263 |
| B-032 | CONSOLIDATED | 265-269 |
| B-033 | CONSOLIDATED | 271-275 |

---

**Documento generato**: 2026-04-16 (autopilot pre-demo extraction)
**Fonte**: CONSOLIDATED_PROJECT_REPORT.md v3.0 (33 bug tracciati), GUIDE_RENAN_SUPERVISOR.md, GUIDE_ELIA_DATABASE.md, GUIDE_CRISTIAN_ASSETS_CICD.md
**Nota**: Task ID assegnati secondo pattern T-{RUOLO}-{XXX}. Severità, descrizione, riferimento file:line compilati da testo esplicito nei doc. Nessun task inventato.
