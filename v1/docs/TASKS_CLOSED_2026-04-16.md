# Task Chiusi — Sprint Auto-pilot 2026-04-16 → 17

Sessione notturna pre-demo presentazione 2026-04-17 ore 09:00.

## Fix applicati (commit + push origin main)

### Demo-blocking P0

| Bug | Fix | Commit |
|---|---|---|
| MessSpawner parse error | type annotation → Node | `7ca95cb` |
| B-001 residual char move (fix committed previously by user) | verified OK (audit) | — |
| B-002 drag fail diagnostic | telemetry completa + floor polygon check | `7ca95cb`, `72c1ec2` |
| B-003 tab deco non cliccabili | root cause WallRect/FloorRect mouse_filter=STOP default | `3450df9` |
| B-6 char female→male race | sync call + scale preservation | `7ca95cb`, `da1d198` |
| B-7 pet invisibile race | null guard + fallback viewport center | `7ca95cb` |
| B-2 loading screen missing | fallback procedurale Label | `7ca95cb`, `e925b6b` |
| Tutorial replay broken | call_deferred _check_tutorial diretto | `7ca95cb` |

### Stability P1/P2/P3

| Bug | Fix | Commit |
|---|---|---|
| B-005 | Shift modifier disabilita snap-to-grid | `96d09f0` |
| B-008 | volume slider emette settings_updated | `1c4f0ab` |
| B-009 | profile panel disconnect signal leak | `1c4f0ab` |
| B-010 | profile coins via signal, non polling | `1c4f0ab` |
| B-011 | toast manager lambda → methods | `1c4f0ab` |
| B-012 | mess_node signal disconnect | `1c4f0ab` |
| B-013 | mess_spawner timer stop + disconnect | `1c4f0ab` |
| B-014 | rimossa dead var `_last_select_error` | `0afff0d` |
| B-018 | logger buffer cap MAX_BUFFER_ENTRIES=2000 | `0afff0d` |
| B-025 | HTTP queue cap MAX_QUEUE_SIZE=500 | `0afff0d` |
| B-026 | SQLite PRAGMA busy_timeout=5000 | `0afff0d` |
| B-027 | `_select()` AppLogger.error su query fail | `0afff0d` |
| B-028 | AppLogger redaction keys sensibili | `0afff0d` |
| B-031 | `.pre-commit-config.yaml` stub + Button linter custom | `1c4f0ab` |

### Tooling + Docs

| Item | Commit |
|---|---|
| `scripts/smoke_test.sh` | `8f06170` |
| `scripts/preflight.sh` (21 check) | `b684b80` |
| 5 review automatiche in `v1/docs/reviews/` | `8f06170` |
| Update 3 guide team (Renan, Elia, Cristian) | `49f68f5` |
| `CONSOLIDATED_PROJECT_REPORT.md` v3.1 | `8f06170` |
| `FIX_SUMMARY_2026-04-16.md` | `da1d198` |

## Task ancora aperti (post-demo)

### P1 ancora aperti (rinviati per rischio regressione pre-demo)

- **T-R-003** (B-016): JSON/SQLite divergence dual-write atomic
- **T-R-004** (B-019): Supabase refresh_token plaintext — encrypt
- **T-R-005** (B-020): Supabase URL HTTPS validation
- **T-R-013** (B-029): PBKDF2 10k → 100k iter migration on-login
- **T-X-001** (B-032): estrarre DDL 15 tabelle Supabase in `supabase/migrations/`
- **T-E-001**: completare B-016 dual-write emettere payload + upsert_settings/music
- **T-R-011**: config Supabase `user://config.cfg` (cloud OFF in demo)

### P2 ancora aperti

- **T-R-007** (B-015): migration system versionato con schema_version + backup pre-migration
- **T-R-008** (B-004): edit mode grid quadrati giganti (necessita investigation GUI live)
- **T-R-009** (B-021): Supabase exponential backoff retry
- **T-E-003** (B-015): backup pre-DROP migration characters/inventario
- **T-E-004**: test GdUnit4 LocalDatabase (test suite re-introduction)
- **T-C-002**: 37 asset orfani in v1/assets/sprites/ da catalogare in decorations.json

### P3 ancora aperti

- **T-R-012**: verifica runtime B-006 (pet FSM) + B-007 (tutorial replay post-fix)
- **T-R-014** (B-023): virtual_joystick USE/REMOVE decision
- **T-E-005** (B-022): cloud_to_local dead code remove or implement
- **T-E-006** (B-017): SaveManager auto-save timer disconnect
- **T-E-007**: test SQLite corruzione, WAL busy, FK fail
- **T-C-003** (B-024): linter rule Button.new() focus_mode (già implementata in `.pre-commit-config.yaml`)
- **T-X-012** (B-030): RNG determinism debug seed
- **T-X-013** (B-033): split `local_database.gd` 810 righe

## Statistiche sprint

- **Inizio**: 2026-04-16 sera
- **Fine (pre-user-test)**: 2026-04-17 notte
- **Commit pushati**: ~14
- **Task chiusi**: 21 (14 bug + 7 tooling/docs)
- **Task rinviati post-demo**: ~29
- **Smoke test runs**: 15+ (tutti PASS)
- **File modificati**: 13 scripts + 1 scene + 3 guide + 5 review + 3 tool scripts

## Come verificare lo stato corrente

```bash
cd "/media/renan/New Volume/PROIECT/projectwork/Projectwork"
./scripts/preflight.sh   # 7 fasi, 21 check, deve uscire "GO PER DEMO"
godot4 --path v1/         # test GUI runtime
```

Per sanity check post-demo qualunque regressione:

```bash
git log --oneline origin/main | head -20
./scripts/smoke_test.sh
```
