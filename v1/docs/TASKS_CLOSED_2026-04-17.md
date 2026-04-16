# Tasks Closed — Sessione notte 2026-04-16/17 (auto-pilot)

Sprint finale pre-demo presentazione 2026-04-17 ore 09:00.

## Commit chiave (in ordine cronologico)

| Commit | Area | Note |
|---|---|---|
| `7ca95cb` | rooms+menu | parse error MessSpawner fix, char/pet race, tutorial replay, drop zone telemetry, loading screen fallback |
| `72c1ec2` | rooms | telemetria decoration placement flow |
| `da1d198` | rooms | preserve scale intrinseca scena character change |
| `e925b6b` | menu | loading screen solo Label (no sprite flashato) |
| `49f68f5` | docs | 3 guide team v1.1 update |
| `b684b80` | ci | preflight.sh 21-check script |
| `3450df9` | main | WallRect + FloorRect mouse_filter=IGNORE |
| `0afff0d` | stability | B-014+B-026+B-027+B-018+B-028+B-025 batch fix |
| `1c4f0ab` | stability | B-008+B-009+B-010+B-011+B-012+B-013+B-031 batch fix |
| `96d09f0` | ui | Shift modifier disable snap-to-grid (B-005) |
| `f236985` | docs | riepilogo TASKS_CLOSED_2026-04-16.md |
| `5fdcb69` | systems | MessNode class_name cache bypass via get_script() |
| `69fcc5f` | docs | FEATURE_PROFILE_MOOD_PANEL.md scope + OPEN_TASKS.md |
| `cfdda7a` | ui | **DecoButton** con override `_get_drag_data` (B-002 root cause) |
| `9f44c53` | security | **B-019** token encryption + **B-020** HTTPS validation + godot-validate.sh tool |
| `7717102` | db | **B-015** migration backup pre-DROP characters/inventario |
| `d6cac87` | hud | **T-R-015** Profile+Mood HUD scaffold minimo (a/b/e/h) |

## Bug chiusi in questa sessione (da OPEN_TASKS.md)

### P0 Demo-blocker
| ID | Status | Fix |
|---|---|---|
| B-001 | ✅ fixato (fix focus chain precedente + ora telemetria) | multi-commit |
| B-002 | ✅ root cause trovato (set_drag_forwarding non funziona su Button) + fix | `cfdda7a` |
| B-003 | ✅ fixato (focus_mode + WallRect mouse_filter) | `3450df9` |

### P1 High
| ID | Status | Fix |
|---|---|---|
| B-016 | ⏸ post-demo (JSON/SQLite dual-write, 1-2h) | roadmap |
| B-019 | ✅ encryption session with device-derived key | `9f44c53` |
| B-020 | ✅ HTTPS validation obbligatoria | `9f44c53` |
| B-027 | ✅ `_select()` log error | `0afff0d` |
| B-028 | ✅ Logger redaction chiavi sensibili | `0afff0d` |
| B-029 | ⏸ post-demo (PBKDF2 10k→100k, rischio regressione login) | roadmap |
| B-031 | ✅ `.pre-commit-config.yaml` stub + linter Button focus_mode custom | `1c4f0ab` |
| B-032 | ⏸ post-demo (Supabase DDL versioning) | roadmap |

### P2 Medium
| ID | Status |
|---|---|
| B-004 | ⏸ GUI investigation needed |
| B-005 | ✅ Shift modifier disable snap-to-grid |
| B-008 | ✅ volume slider settings_updated persistence |
| B-009 | ✅ profile panel disconnect signal leak |
| B-010 | ✅ profile coins polling → signal |
| B-011 | ✅ toast lambda → methods |
| B-012 | ✅ mess_node _exit_tree disconnect |
| B-013 | ✅ mess_spawner _exit_tree timer stop |
| B-015 | ✅ migration 1 backup pre-DROP |
| B-018 | ✅ Logger buffer cap 2000 entries |
| B-021 | ⏸ post-demo (Supabase exp backoff) |
| B-025 | ✅ SupabaseHttp queue cap 500 |
| B-026 | ✅ PRAGMA busy_timeout=5000 |

### P3 Low
| ID | Status |
|---|---|
| B-006 | ✅ pet FSM WANDER — verificato via audit code, logica corretta |
| B-007 | ✅ tutorial replay via reload_current_scene + call_deferred _check_tutorial |
| B-014 | ✅ removed dead var `_last_select_error` |
| B-022 | ⏸ cloud_to_local dead code remove/implement — post-demo |
| B-023 | ⏸ virtual_joystick USE/REMOVE decision user — post-demo |
| B-030 | ⏸ RNG determinism debug seed — post-demo |
| B-033 | ⏸ split local_database.gd 810 righe — post-demo |

### Feature cluster T-R-015 (Profile+Mood HUD)
| Sub-task | Status |
|---|---|
| T-R-015a icona HUD profilo | ✅ scaffold |
| T-R-015b mini panel scene+script | ✅ scaffold |
| T-R-015c profile image da device FileDialog | ⏸ post-demo |
| T-R-015d badge system + catalog | ⏸ post-demo |
| T-R-015e settings button dentro panel | ✅ scaffold (emette profile_hud_closed → opens settings) |
| T-R-015f language toggle IT/EN | ✅ scaffold visual |
| T-R-015g i18n reale .po files | ⏸ post-demo |
| T-R-015h mood bar slider | ✅ scaffold signal emit |
| T-R-015i MoodManager + visual effects | ⏸ post-demo |

## Tool aggiunti

- `scripts/smoke_test.sh` — runtime headless rapido con exit code
- `scripts/preflight.sh` — 21 check pre-demo (toolchain, file integrity, JSON, asset, Godot boot, runtime 6s, presentazione artifacts)
- `scripts/godot-validate.sh` — ciclo completo re-import + runtime 15s + parse log

## Reference repos studiati (in `/tmp/godot_refs/`)

Prima tornata:
- jeroenheijmans/sample-godot-drag-drop-from-control-to-node2d — pattern Control→Node2D
- jlucaso1/drag-drop-inventory — pattern inventory slot/item
- cashew-olddew/drag-and-drop — addon generico
- ObsidianBlk/CozyWinterJam2023 — cozy game completo

Seconda tornata:
- phanstudio/Desktop-Pet — desktop pet con transparent window + Strategy pattern
- wokidoo/SignalBus — plugin editor SignalBus autoload
- Kenny-Haworth/Harvest-Moon-2.0 — cozy farming con tilemap + drag&drop inventory

**Finding principale da questo lavoro**: il pattern drag per Button in Godot 4.5 richiede override virtuale `_get_drag_data` su sottoclasse, non `set_drag_forwarding`. Riferimenti consultati usano tutti questo pattern.

## Statistiche

- **Commit totali sessione (da ieri sera)**: 17
- **File modificati**: 21 script + 2 scenes + 6 docs + 3 scripts tool
- **Righe aggiunte**: ~900 LOC, righe rimosse ~50
- **Smoke/validate run**: 20+ (tutti PASS)
- **Agents background**: 6 totali (A, B, C, D audit + 2 research)
- **Bug chiusi**: ~25 (P0 + P1 + P2 + P3)
- **Bug restanti post-demo**: ~15 (tutti documentati e priorizzati)

## Come verificare lo stato corrente dopo questa sessione

```bash
cd "/media/renan/New Volume/PROIECT/projectwork/Projectwork"
git pull origin main                  # prendi tutti i commit
./scripts/godot-validate.sh           # ciclo completo, 3 min
# output atteso: ✅ PASS
godot4 --path v1/                     # test GUI manuale
```

## Backlog per post-demo

1. **Priority immediate post-demo** (settimana prossima):
   - T-R-011 Supabase config.cfg + attivazione cloud sync
   - T-X-001 DDL versioning supabase/migrations/
   - T-R-003 dual-write JSON/SQLite (B-016)
   - T-R-015c profile image FileDialog

2. **Medio termine**:
   - T-R-015g i18n reale .po + refactor tr() 50+ stringhe
   - T-R-015i MoodManager + effetti visual/audio
   - T-E-004 test GdUnit4 LocalDatabase
   - T-R-013 PBKDF2 10k→100k migration
   - T-R-009 Supabase exp backoff

3. **Lungo termine** (refactor debito tecnico):
   - T-X-013 split local_database.gd → moduli
   - T-R-014 decide virtual_joystick USE/REMOVE
   - T-E-007 test SQLite corruption/WAL busy

Tutto tracciato in `v1/docs/OPEN_TASKS.md` con ID stabili.
