# DevBridge — Debug-Only Local Control API — Design Spec

- **Date**: 2026-08-08
- **Status**: Approved (design discussed and accepted in brainstorming session)
- **Author**: Renan Augusto Macena, with Claude Code
- **Scope**: Development tooling only. No gameplay change, no player-facing surface.

## 1. Context and goal

Relax Room v1.1.0 is entering a re-audit phase: re-verify the remaining findings of
`MASTER_PLAN_2026-07-20.md` against the current code, ahead of the isometric visual
upgrade and the "smoother than any competitor" polish push.

Auditing today is limited to reading code and running the headless test suite. There is
no way to interrogate or drive the *live* game from outside the process. The DevBridge
closes that gap: a minimal, debug-only, localhost HTTP API through which development
tools (curl, Python scripts, CI, Claude Code) can query state and trigger UI-equivalent
actions in a running instance.

**Non-goals**

- Not a gameplay or user-facing feature. Players can never see or enable it.
- Not an external-app integration surface (stream decks, OBS, etc.). If that is ever
  wanted, it gets its own design with real authentication.
- Not a replacement for the headless test harness. It complements it.

## 2. Architecture

One new autoload: `res://scripts/autoload/dev_bridge.gd`, registered **last** in the
`[autoload]` chain of `project.godot` (position 13, after `BadgeManager`), so every
manager exists before the bridge starts.

- Uses Godot's built-in `TCPServer`, polled from `_process()` on the main thread.
  No threads: handlers touch game state only between frames, so there are no data races
  with gameplay code by construction.
- Protocol: minimal HTTP/1.1 subset — parse request line, headers, optional body;
  respond with `Connection: close` (one request per connection, no keep-alive).
- Responses are JSON (`application/json`) except `GET /screenshot` (`image/png`).

## 3. Activation and security model

Three independent gates. If any gate fails, `_ready()` calls `set_process(false)` and
the autoload stays inert for the whole session (zero per-frame cost).

| # | Gate | Effect |
|---|------|--------|
| 1 | `OS.is_debug_build()` | In release exports the server code path is dead, unconditionally |
| 2 | `--bridge` in `OS.get_cmdline_user_args()` | Explicit opt-in per launch: `godot4 --path v1 -- --bridge [--bridge-port=8080]`. Pressing Play in the editor does NOT open a port unless the flag is added to run args |
| 3 | Bind address hardcoded `127.0.0.1` | Never reachable from the network; not configurable |

- Default port **8080**, overridable via `--bridge-port=<n>` (valid range 1024–65535;
  invalid value → log error, bridge stays disabled). If the port is busy, log the
  failure and stay disabled — never retry-loop or steal another port.
- **No auth token**, deliberately: localhost + debug build + explicit flag is the
  accepted threat model for a dev tool. Consequence: any *local* process could connect
  while the flag is active. Mitigations: no secrets in any response, `logs/tail` serves
  AppLogger output that is already redacted at write time, and the bridge is off by
  default even in dev.

## 4. API surface

| Method | Path | Purpose | Response (200) |
|--------|------|---------|----------------|
| GET | `/status` | Liveness + top-level state | `{app_version, fps, current_scene, mood_level, mood, stress, stress_level, coins, uptime_s, bridge_version}` |
| GET | `/tree?depth=N` | Scene-tree dump from root, default depth 3, max 8 | `{tree: {name, class, visible, children: [...]}}` |
| GET | `/events` | Ring buffer of recent SignalBus traffic | `{events: [{t_ms, signal, args}], dropped}` |
| GET | `/logs/tail?n=N` | Last N lines (default 100, max 1000) of current AppLogger JSONL | `{lines: [...]}` |
| GET | `/screenshot` | Current viewport as PNG | binary `image/png` |
| POST | `/command` | Execute one UI-equivalent action | `{ok: true, action, detail}` |
| POST | `/quit` | Clean shutdown through the existing final-save flow | `{ok: true}` then process exit |

### 4.1 `/events` ring buffer

At startup the bridge connects (listen-only) to a curated list of SignalBus signals —
state-change and error signals such as `mood_changed`, `stress_changed`,
`save_completed`, `save_failed`, `mess_spawned`, `mess_cleaned`, `coins_changed`,
`badge_unlocked`, `db_error`, `sync_error`, `catalog_load_failed` — and records
`{t_ms, signal, args}` into a fixed 200-entry ring. Older entries are dropped and
counted in `dropped`. Args are stringified defensively (no object refs leak).

### 4.2 `/command` actions (initial set)

Request body: `{"action": "<name>", ...params}`, max 64 KB.

| Action | Params | Route |
|--------|--------|-------|
| `set_mood` | `value: float 0.0–1.0` | `SignalBus.mood_level_changed.emit(value)` — same signal the profile-HUD mood slider emits |
| `set_stress` | `value: float 0.0–1.0` | StressManager public setter (same entry the game/tests use) |
| `save` | — | `SignalBus.save_requested.emit()` |
| `set_language` | `lang: "it"\|"en"` | Mirror `settings_panel.gd:224-225`: `TranslationServer.set_locale(lang)` + `SignalBus.settings_updated.emit("language", lang)` |
| `toggle_track` | — | `AudioManager.pause()` — the play/pause toggle the music HUD uses (emits `track_play_pause_toggled`) |
| `open_panel` | `panel: String` | `PanelManager.open_panel(panel)` (`scripts/ui/panel_manager.gd:45`), instance located at runtime from the active Room UI |
| `close_panel` | — | `PanelManager.close_current_panel()` (`scripts/ui/panel_manager.gd:85`) |

Unknown action → `400` with the list of valid actions in the error body.
Param validation failure → `400` with the reason.

### 4.3 The one architectural rule

**The bridge may only do what the UI can do.** Allowed: emitting *input* signals
(signals that UI controls themselves emit, e.g. `mood_level_changed`,
`save_requested`) and calling public manager methods that UI/game code already calls.
Forbidden: emitting system-*output* signals (`save_completed`, `mess_spawned`,
`stress_changed`, …) — that would inject false events into the bus and invalidate any
audit performed through the bridge. Every action added to the dispatch table must name
the UI entry point it mirrors.

## 5. Error handling

The bridge must never crash or stall the game.

| Condition | Response |
|-----------|----------|
| Malformed HTTP / unparseable JSON body | `400` `{error}` |
| Unknown path | `404` `{error}` |
| Wrong method on a known path | `405` `{error}` |
| Body > 64 KB | `413` `{error}`, connection closed |
| Handler failure | `500` `{error: "internal"}`; detail logged via AppLogger, context `dev_bridge` |
| Request incomplete after 5 s | connection dropped silently |

All bridge logging goes through AppLogger with context `dev_bridge`, so bridge noise is
filterable and subject to the existing redaction rules.

## 6. Performance constraints

- Disabled (gates failed): `set_process(false)` — literally zero per-frame cost.
- Enabled and idle: one non-blocking `is_connection_available()` poll per frame.
- Enabled and active: at most **2** connections accepted and **1** request fully
  served per frame; the rest wait in the OS backlog. A request must never add a
  visible hitch — target < 2 ms handler budget except `/screenshot` (allowed one
  slow frame; it is a dev tool).
- Compatible with PerformanceManager's background FPS cap (15 fps → worst-case ~66 ms
  extra latency per request in background; acceptable, do not fight the cap).

## 7. Testing

New module `tests/integration/test_bridge.gd`, registered in `TEST_MODULES` of
`tests/test_runner.gd` (runner is reflection-based; tests are `test_*` methods,
sync or `await`-async). Target ~12 tests:

1. Bridge autoload exists and is inert without the `--bridge` flag (no listening port).
2. `start()` with test config binds 127.0.0.1 and reports listening.
3. Loopback `GET /status` via `StreamPeerTCP` → 200, JSON parses, all schema keys present.
4. `fps`/`uptime_s` sane (> 0); `app_version` matches `VERSION` file.
5. `GET /unknown` → 404 JSON error.
6. `POST /status` → 405.
7. Malformed request line → 400, connection closed, game still alive.
8. Body > 64 KB → 413.
9. `POST /command set_mood 0.25` → 200 and MoodManager state actually changed
   (assert via manager, not via the bridge's own response).
10. Unknown action → 400 listing valid actions.
11. `set_mood` out of range → 400, mood unchanged.
12. `/events` contains the mood-change bus traffic produced by test 9
    (`mood_level_changed` and/or `mood_changed`); ring never exceeds 200 entries.

`/screenshot` and `/quit` are exercised manually (screenshot needs a real viewport;
quit kills the process) — documented as such in the test module header.

## 8. Documentation updates

- `v1/scripts/README.md`: autoload table +1 row (DevBridge, position 13).
- `v1/README.md`: autoload chain table +1 row; "12 autoload" wording → 13; short
  "Dev bridge" subsection under Testing with the launch flag and a curl example.
- Repo root `README.md`: autoload count if mentioned (currently says 12).
- `v1/tests/README.md`: module table +1 row (test_bridge).
- `CHANGELOG.md`: entry under `[Unreleased]` → Added (dev tooling).

## 9. Files touched

| File | Change |
|------|--------|
| `v1/scripts/autoload/dev_bridge.gd` | new (~350 lines) |
| `v1/project.godot` | +1 autoload line (last position) |
| `v1/tests/integration/test_bridge.gd` | new (~12 tests) |
| `v1/tests/test_runner.gd` | +1 `TEST_MODULES` entry |
| `v1/scripts/README.md`, `v1/README.md`, `README.md`, `v1/tests/README.md`, `CHANGELOG.md` | doc rows/wording |

## 10. Acceptance criteria

- Release export: no listener on any port, flag or not (gate 1).
- Debug run without `--bridge`: no listener (gate 2).
- Debug run with `--bridge`: `curl http://127.0.0.1:8080/status` returns valid JSON;
  `set_mood` via curl visibly moves the in-game mood (audio/overlay react).
- Full suite `./scripts/deep_test.sh` passes: 112 existing + ~12 new, exit 0.
- `./scripts/preflight.sh` still GO.
- No new gdlint violations (`gdlintrc` config).

## 11. Out of scope / future

- Auth token + non-localhost binding (only if external-app control is ever designed).
- Write-endpoints for decorations (place/move/remove) — candidate second iteration,
  after the audit proves the read/command core.
- Isometric upgrade and master-plan backlog: separate workstreams, designed after
  the audit this tool enables.
