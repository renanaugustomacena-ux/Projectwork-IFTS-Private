# DevBridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Debug-only localhost HTTP control API (autoload `DevBridge`) so dev tools can query state and trigger UI-equivalent actions in a running Relax Room instance.

**Architecture:** One new autoload (`v1/scripts/autoload/dev_bridge.gd`, last in chain) polling a `TCPServer` bound to `127.0.0.1` from `_process()`. Minimal HTTP/1.1 subset, JSON responses, `Connection: close`. Commands mirror exact UI entry points — never system-output signals. Spec: `v1/docs/specs/2026-08-08-dev-bridge-design.md`.

**Tech Stack:** Godot 4.6, GDScript (typed), custom headless test harness (`v1/tests/test_runner.tscn`), gdlint/gdformat.

## Global Constraints

- Godot **4.6** project at `v1/`; all repo paths below are relative to repo root `C:\Users\Renan Macena\Desktop\Projectwork-IFTS-Private`.
- Branch: `feat/dev-bridge` (already checked out).
- gdlint (`gdlintrc`): **tabs** for indentation, `max-line-length: 120`, `max-file-lines: 500`, snake_case functions/vars, UPPER_SNAKE consts, class order: `extends` → docstring → signals → enums → consts → pubvars → prvvars → funcs.
- Bind address hardcoded `127.0.0.1`. Default port **8080**, valid range **1024–65535**. Explicit opt-in flag `--bridge` in `OS.get_cmdline_user_args()`; gate 1 is `OS.is_debug_build()`.
- Limits: body ≤ **65536** bytes, headers ≤ **8192** bytes, event ring **200** entries, request timeout **5000** ms, ≤ **2** accepts/frame, ≤ **1** request served/frame.
- **The one rule:** the bridge may only emit *input* signals (ones UI controls emit) or call public manager methods UI/game code already calls. Never emit output signals (`save_completed`, `mess_spawned`, `stress_changed`, …).
- Test command (headless, from repo root): `godot4 --headless --path v1/ res://tests/test_runner.tscn` — exit 0 = all pass. If `godot4` is not on PATH on this Windows machine, locate the Godot 4.6 binary first (PowerShell: `Get-Command godot* ; ls "$env:LOCALAPPDATA\Programs" ; ls C:\Godot*`) and substitute it. `./scripts/deep_test.sh` wraps the same run.
- Commit messages: Italian conventional-commit style used by the repo (`feat(...):`, `test(...):`, `docs(...):`), each ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Autoload singletons available everywhere: `SignalBus`, `AppLogger` (`info/warn/error(source: String, message: String, context: Dictionary = {})`), `SaveManager` (`get_setting(key, default)`, `inventory_data: Dictionary`), `StressManager` (`get_stress_value() -> float`, `get_stress_level() -> String`, `current_mood: String`, `apply_delta(delta: float)`, `reset()`), `AudioManager` (`pause()`), `GameManager`. Class `Constants` (`scripts/utils/constants.gd`) exposes `LANGUAGES: Dictionary`. Class `PanelManager` (`scripts/ui/panel_manager.gd`) instance lives at `get_tree().current_scene.get_node("PanelManager")` only in the game scene (`scripts/main.gd:19-22`).

---

### Task 1: DevBridge lifecycle — gating, start/stop, autoload registration

**Files:**
- Create: `v1/scripts/autoload/dev_bridge.gd`
- Create: `v1/tests/integration/test_bridge.gd`
- Modify: `v1/project.godot` (autoload section, after `BadgeManager`)
- Modify: `v1/tests/test_runner.gd:16-29` (`TEST_MODULES`)

**Interfaces:**
- Consumes: `AppLogger.info/error(source, message, context)`; `TestBase` assert helpers (`assert_true/assert_false/assert_eq/assert_non_null`).
- Produces (used by Tasks 2–5): autoload singleton `DevBridge` with `start(port: int) -> bool`, `stop() -> void`, `is_active() -> bool`, const `MAX_BODY_BYTES := 65536`, private `_server: TCPServer`, `_conns: Array[Dictionary]`, `_start_ms: int`. Test module `test_bridge.gd` with const `TEST_PORT := 8123`.

- [ ] **Step 1: Write the failing tests**

Create `v1/tests/integration/test_bridge.gd` (tab-indented):

```gdscript
extends TestBase
## Modulo test DevBridge — API HTTP locale debug-only.
##
## NOTA: /screenshot e /quit sono verificati manualmente (viewport reale /
## terminazione processo) — vedi sezione "Verifica manuale" nel piano.
## I test chiamano DevBridge.start(TEST_PORT) direttamente: gli user args
## (--bridge) non sono simulabili in un run headless del runner.

const TEST_PORT := 8123


func test_inert_without_flag() -> void:
	# Il runner gira senza `-- --bridge`: l'autoload deve essere spento.
	assert_false(DevBridge.is_active(), "bridge attivo senza flag --bridge")


func test_start_rejects_invalid_port() -> void:
	assert_false(DevBridge.start(80), "porta < 1024 accettata")
	assert_false(DevBridge.start(70000), "porta > 65535 accettata")
	assert_false(DevBridge.is_active(), "bridge attivo dopo start invalido")


func test_start_binds_localhost() -> void:
	assert_true(DevBridge.start(TEST_PORT), "start(%d) fallito" % TEST_PORT)
	assert_true(DevBridge.is_active(), "is_active() falso dopo start riuscito")
	# Idempotente: secondo start non deve fallire ne' ribindare.
	assert_true(DevBridge.start(TEST_PORT), "start idempotente fallito")
```

- [ ] **Step 2: Register the module and run tests to verify they fail**

In `v1/tests/test_runner.gd`, append to `TEST_MODULES` after the `test_phase_f.gd` line:

```gdscript
	"res://tests/integration/test_bridge.gd",
```

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: FAIL — script `test_bridge.gd` cannot resolve `DevBridge` (autoload does not exist yet). Parse error or test failures both count as the expected red state.

- [ ] **Step 3: Write the lifecycle implementation**

Create `v1/scripts/autoload/dev_bridge.gd`:

```gdscript
extends Node
## DevBridge — API HTTP locale debug-only per audit e test.
##
## Spec: v1/docs/specs/2026-08-08-dev-bridge-design.md
## Tre gate indipendenti: build debug + flag `--bridge` + bind 127.0.0.1.
## Regola architetturale: il bridge fa SOLO cio' che la UI puo' fare —
## emette segnali di input o chiama metodi pubblici gia' usati dalla UI.
## Mai emettere segnali di output dei sistemi (save_completed, mess_spawned...).

const SOURCE := "dev_bridge"
const BRIDGE_VERSION := "1.0.0"
const DEFAULT_PORT := 8080
const PORT_MIN := 1024
const PORT_MAX := 65535
const MAX_BODY_BYTES := 65536
const MAX_HEADER_BYTES := 8192
const RING_CAP := 200
const REQUEST_TIMEOUT_MS := 5000
const MAX_ACCEPTS_PER_FRAME := 2

var _server: TCPServer = null
var _active := false
var _start_ms := 0
var _events: Array[Dictionary] = []
var _events_dropped := 0
# Connessioni in corso: {peer: StreamPeerTCP, buf: PackedByteArray, deadline_ms: int}
var _conns: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	if not args.has("--bridge"):
		return
	var port := DEFAULT_PORT
	for arg in args:
		if arg.begins_with("--bridge-port="):
			var raw := arg.trim_prefix("--bridge-port=")
			if not raw.is_valid_int():
				AppLogger.error(SOURCE, "bridge_port_not_numeric", {"raw": raw})
				return
			port = raw.to_int()
	start(port)


func is_active() -> bool:
	return _active


## Avvia il server sulla porta data. Pubblico: i test lo chiamano direttamente
## perche' gli user args non sono simulabili in un run del test runner.
func start(port: int) -> bool:
	if _active:
		return true
	if port < PORT_MIN or port > PORT_MAX:
		AppLogger.error(SOURCE, "port_out_of_range", {"port": port})
		return false
	var server := TCPServer.new()
	var err := server.listen(port, "127.0.0.1")
	if err != OK:
		AppLogger.error(SOURCE, "listen_failed", {"port": port, "err": err})
		return false
	_server = server
	_active = true
	_start_ms = Time.get_ticks_msec()
	set_process(true)
	AppLogger.info(SOURCE, "listening", {"port": port})
	return true


func stop() -> void:
	if not _active:
		return
	for conn in _conns:
		conn.peer.disconnect_from_host()
	_conns.clear()
	_server.stop()
	_server = null
	_active = false
	set_process(false)
	AppLogger.info(SOURCE, "stopped")
```

- [ ] **Step 4: Register the autoload**

In `v1/project.godot`, `[autoload]` section, add after the `BadgeManager` line (position 13, LAST — every manager must exist before the bridge starts):

```
DevBridge="*res://scripts/autoload/dev_bridge.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0 — 112 existing + 3 new, ALL PASS. If `test_inert_without_flag` fails, the runner run itself passed `--bridge` somehow — investigate before proceeding (gate 2 is broken).

- [ ] **Step 6: Commit**

```bash
git add v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd v1/project.godot v1/tests/test_runner.gd
git commit -m "feat(bridge): autoload DevBridge — lifecycle e triplo gate di attivazione

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: HTTP core — accept loop, parser, responder, `/status`, error paths

**Files:**
- Modify: `v1/scripts/autoload/dev_bridge.gd` (add `_process` + HTTP functions)
- Modify: `v1/tests/integration/test_bridge.gd` (add `_http` helper + 6 tests)

**Interfaces:**
- Consumes (Task 1): `DevBridge.start/is_active`, `_server`, `_conns`, `_start_ms`, consts.
- Produces (Tasks 3–5): `_route(peer, method, path, query, body)` with a `match` on path — later tasks add arms; `_respond_json(peer, status, body_dict)`; `_respond_bytes(peer, status, content_type, bytes)`; `_parse_query(full_path) -> Dictionary`; test helper `_http(method: String, path: String, body: String = "") -> Dictionary` returning `{status: int, body: String, json: Variant}` and `_raw_send(raw: String) -> Dictionary` (same shape).

- [ ] **Step 1: Write the failing tests**

Append to `v1/tests/integration/test_bridge.gd`:

```gdscript
func test_status_ok_schema() -> void:
	var resp: Dictionary = await _http("GET", "/status")
	assert_eq(resp.status, 200, "GET /status non 200")
	assert_true(resp.json is Dictionary, "/status body non e' un oggetto JSON")
	if resp.json is Dictionary:
		for key in [
			"app_version", "bridge_version", "fps", "current_scene",
			"mood_level", "mood", "stress", "stress_level", "coins", "uptime_s",
		]:
			assert_true(resp.json.has(key), "/status manca chiave '%s'" % key)


func test_status_values_sane() -> void:
	var resp: Dictionary = await _http("GET", "/status")
	assert_eq(resp.status, 200)
	var version_file := FileAccess.open("res://VERSION", FileAccess.READ)
	assert_non_null(version_file, "res://VERSION non leggibile")
	if version_file != null and resp.json is Dictionary:
		var expected := version_file.get_as_text().strip_edges()
		assert_eq(str(resp.json.app_version), expected, "app_version != VERSION file")
		assert_true(float(resp.json.uptime_s) >= 0.0, "uptime_s negativo")
		assert_true(float(resp.json.fps) >= 0.0, "fps negativo")


func test_unknown_path_404() -> void:
	var resp: Dictionary = await _http("GET", "/nope")
	assert_eq(resp.status, 404, "path ignoto non 404")
	assert_true(resp.json is Dictionary and resp.json.has("error"), "404 senza campo error")


func test_wrong_method_405() -> void:
	var resp: Dictionary = await _http("POST", "/status")
	assert_eq(resp.status, 405, "POST /status non 405")


func test_malformed_request_400() -> void:
	var resp: Dictionary = await _raw_send("GARBAGE-SENZA-SPAZI\r\n\r\n")
	assert_eq(resp.status, 400, "request line malformata non 400")
	# Il gioco deve essere ancora vivo: una seconda richiesta valida risponde.
	var again: Dictionary = await _http("GET", "/status")
	assert_eq(again.status, 200, "bridge morto dopo richiesta malformata")


func test_oversized_body_413() -> void:
	# Content-Length oltre il tetto: 413 immediato, senza inviare il body.
	var raw := "POST /command HTTP/1.1\r\nHost: x\r\nContent-Length: 70000\r\n\r\n"
	var resp: Dictionary = await _raw_send(raw)
	assert_eq(resp.status, 413, "body oltre 64 KB non 413")
```

And these two transport helpers (place them at the END of the file, after all `test_*` methods — the runner treats every `test_*`-prefixed method as a test, helpers must not match):

```gdscript
func _http(method: String, path: String, body: String = "") -> Dictionary:
	var payload := body.to_utf8_buffer()
	var req := "%s %s HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: %d\r\n\r\n" % [
		method, path, payload.size(),
	]
	var raw_req := req.to_utf8_buffer()
	raw_req.append_array(payload)
	return await _transport(raw_req)


func _raw_send(raw: String) -> Dictionary:
	return await _transport(raw.to_utf8_buffer())


func _transport(raw_req: PackedByteArray) -> Dictionary:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", TEST_PORT) != OK:
		return {"status": -1, "body": "", "json": null}
	for i in range(120):
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			return {"status": -1, "body": "", "json": null}
		await get_tree().process_frame
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return {"status": -1, "body": "", "json": null}
	peer.set_no_delay(true)
	peer.put_data(raw_req)
	var raw := PackedByteArray()
	for i in range(300):
		peer.poll()
		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk: Array = peer.get_data(avail)
			if chunk[0] == OK:
				raw.append_array(chunk[1])
		elif peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break  # server ha chiuso (Connection: close) e buffer svuotato
		await get_tree().process_frame
	var text := raw.get_string_from_utf8()
	var sep := text.find("\r\n\r\n")
	if sep < 0:
		return {"status": -1, "body": text, "json": null}
	var status_parts := text.substr(0, sep).split("\r\n")[0].split(" ")
	var status := -1
	if status_parts.size() >= 2 and status_parts[1].is_valid_int():
		status = status_parts[1].to_int()
	var body_text := text.substr(sep + 4)
	return {"status": status, "body": body_text, "json": JSON.parse_string(body_text)}
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: the 6 new tests FAIL (status -1: server accepts nothing yet — `_process` not implemented). Task 1 tests still pass.

- [ ] **Step 3: Implement accept loop, parser, responder, `/status`**

In `v1/scripts/autoload/dev_bridge.gd`, add one class-level const next to the existing ones (GDScript does NOT allow `const` inside functions):

```gdscript
const STATUS_TEXT := {
	200: "OK", 400: "Bad Request", 404: "Not Found",
	405: "Method Not Allowed", 413: "Payload Too Large", 500: "Internal Server Error",
}
```

Then append the functions:

```gdscript
func _process(_delta: float) -> void:
	if not _active:
		return
	var accepts := 0
	while _server.is_connection_available() and accepts < MAX_ACCEPTS_PER_FRAME:
		var peer := _server.take_connection()
		if peer != null:
			peer.set_no_delay(true)
			_conns.append({
				"peer": peer,
				"buf": PackedByteArray(),
				"deadline_ms": Time.get_ticks_msec() + REQUEST_TIMEOUT_MS,
			})
		accepts += 1
	_pump_connections()


func _pump_connections() -> void:
	# Al massimo UNA richiesta completa servita per frame (budget hitch).
	var now := Time.get_ticks_msec()
	var served := false
	var keep: Array[Dictionary] = []
	for conn in _conns:
		var peer: StreamPeerTCP = conn.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		if now > int(conn.deadline_ms):
			peer.disconnect_from_host()
			continue
		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk: Array = peer.get_data(avail)
			if chunk[0] == OK:
				# ATTENZIONE: i Packed*Array dentro un Dictionary sono copy-on-write.
				# `conn.buf.append_array(...)` muterebbe una COPIA e perderebbe i
				# byte ricevuti: serve leggere, modificare e riscrivere la chiave.
				var buf: PackedByteArray = conn.buf
				buf.append_array(chunk[1])
				conn.buf = buf
		if conn.buf.size() > MAX_HEADER_BYTES + MAX_BODY_BYTES:
			_respond_json(peer, 413, {"error": "payload too large"})
			continue
		if not served and _try_serve(conn):
			served = true
			continue
		keep.append(conn)
	_conns = keep


## Ritorna true se la richiesta e' stata servita (o rifiutata) e la
## connessione va scartata; false se aspettiamo altri byte.
func _try_serve(conn: Dictionary) -> bool:
	var raw: PackedByteArray = conn.buf
	var peer: StreamPeerTCP = conn.peer
	var header_end := _find_header_end(raw)
	if header_end < 0:
		return false
	var head_lines := raw.slice(0, header_end).get_string_from_utf8().split("\r\n")
	var request_line := head_lines[0].split(" ")
	if request_line.size() != 3:
		_respond_json(peer, 400, {"error": "malformed request line"})
		return true
	var content_length := 0
	for i in range(1, head_lines.size()):
		if head_lines[i].to_lower().begins_with("content-length:"):
			var value := head_lines[i].substr(15).strip_edges()
			if value.is_valid_int():
				content_length = value.to_int()
	if content_length > MAX_BODY_BYTES:
		_respond_json(peer, 413, {"error": "body too large"})
		return true
	var body_start := header_end + 4
	if raw.size() < body_start + content_length:
		return false
	var body := raw.slice(body_start, body_start + content_length)
	var full_path := request_line[1]
	_route(peer, request_line[0], full_path.split("?")[0], _parse_query(full_path), body)
	return true


func _find_header_end(raw: PackedByteArray) -> int:
	for i in range(0, raw.size() - 3):
		if raw[i] == 13 and raw[i + 1] == 10 and raw[i + 2] == 13 and raw[i + 3] == 10:
			return i
	return -1


func _parse_query(full_path: String) -> Dictionary:
	var out := {}
	var parts := full_path.split("?", true, 1)
	if parts.size() < 2:
		return out
	for pair in parts[1].split("&"):
		var kv := pair.split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() == 2 else ""
	return out


func _route(
	peer: StreamPeerTCP, method: String, path: String, query: Dictionary, body: PackedByteArray
) -> void:
	match path:
		"/status":
			if method != "GET":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			_respond_json(peer, 200, _build_status())
		_:
			_respond_json(peer, 404, {"error": "unknown path"})


func _build_status() -> Dictionary:
	var scene := get_tree().current_scene
	return {
		"app_version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
		"bridge_version": BRIDGE_VERSION,
		"fps": Engine.get_frames_per_second(),
		"current_scene": str(scene.name) if scene != null else "",
		"mood_level": SaveManager.get_setting("mood_level", 1.0),
		"mood": StressManager.current_mood,
		"stress": StressManager.get_stress_value(),
		"stress_level": StressManager.get_stress_level(),
		"coins": int(SaveManager.inventory_data.get("coins", 0)),
		"uptime_s": (Time.get_ticks_msec() - _start_ms) / 1000.0,
	}


func _respond_json(peer: StreamPeerTCP, status: int, body: Dictionary) -> void:
	_respond_bytes(peer, status, "application/json", JSON.stringify(body).to_utf8_buffer())


func _respond_bytes(
	peer: StreamPeerTCP, status: int, content_type: String, payload: PackedByteArray
) -> void:
	var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
		status, STATUS_TEXT.get(status, "Error"), content_type, payload.size(),
	]
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(payload)
	peer.disconnect_from_host()
```

Note: `query` is unused by `/status` — later tasks use it. gdlint has `unused-argument: null` (disabled), so this passes.

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0, 112 + 9 tests ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
git commit -m "feat(bridge): core HTTP — accept loop, parser, /status, errori 400/404/405/413

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `/command` dispatch — the 7 UI-equivalent actions

**Files:**
- Modify: `v1/scripts/autoload/dev_bridge.gd` (add `/command` arm + handlers)
- Modify: `v1/tests/integration/test_bridge.gd` (add 6 tests)

**Interfaces:**
- Consumes (Task 2): `_route` match, `_respond_json`, test `_http`.
- Consumes (codebase): `SignalBus.mood_level_changed/settings_updated/save_requested` (input signals), `StressManager.apply_delta/get_stress_value/reset`, `AudioManager.pause()`, `TranslationServer.set_locale`, `Constants.LANGUAGES`, `PanelManager` node at `current_scene/PanelManager`.
- Produces: `VALID_ACTIONS` const; `_handle_command(peer, body)`.

- [ ] **Step 1: Write the failing tests**

Insert into `v1/tests/integration/test_bridge.gd` after `test_oversized_body_413` (keep helpers at the end of the file):

```gdscript
func test_command_set_mood() -> void:
	var previous: float = float(SaveManager.get_setting("mood_level", 1.0))
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "set_mood", "value": 0.25})
	)
	assert_eq(resp.status, 200, "set_mood non 200")
	# Percorso UI completo: settings_updated -> SaveManager persiste la chiave.
	assert_approx(float(SaveManager.get_setting("mood_level", 1.0)), 0.25, 0.001,
		"mood_level non persistito via settings_updated")
	await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": previous}))


func test_command_set_mood_out_of_range() -> void:
	var previous: float = float(SaveManager.get_setting("mood_level", 1.0))
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "set_mood", "value": 1.7})
	)
	assert_eq(resp.status, 400, "set_mood fuori range non 400")
	assert_approx(float(SaveManager.get_setting("mood_level", 1.0)), previous, 0.001,
		"mood cambiato nonostante il 400")


func test_command_unknown_action() -> void:
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "fly_to_moon"})
	)
	assert_eq(resp.status, 400, "azione ignota non 400")
	if resp.json is Dictionary:
		assert_true(str(resp.json.get("error", "")).contains("set_mood"),
			"il 400 non elenca le azioni valide")


func test_command_set_stress() -> void:
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "set_stress", "value": 0.5})
	)
	assert_eq(resp.status, 200, "set_stress non 200")
	assert_approx(StressManager.get_stress_value(), 0.5, 0.001, "stress non applicato")
	StressManager.reset()


func test_command_save_emits_request() -> void:
	var seen := [false]
	var handler := func() -> void: seen[0] = true
	SignalBus.save_requested.connect(handler)
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "save"}))
	SignalBus.save_requested.disconnect(handler)
	assert_eq(resp.status, 200, "save non 200")
	assert_true(seen[0], "save_requested non emesso")


func test_command_open_panel_without_game_scene() -> void:
	# In headless il current_scene e' il test runner: niente PanelManager.
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "open_panel", "panel": "settings"})
	)
	assert_eq(resp.status, 400, "open_panel senza scena di gioco non 400")
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: the 6 new tests FAIL with status 404 (`/command` not routed yet). Earlier tests still pass.

- [ ] **Step 3: Implement the dispatch**

In `_route`, add this arm BEFORE the `_:` fallback:

```gdscript
		"/command":
			if method != "POST":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			_handle_command(peer, body)
```

Append the handler functions (each names the UI entry point it mirrors):

```gdscript
const VALID_ACTIONS := [
	"set_mood", "set_stress", "save", "set_language",
	"toggle_track", "open_panel", "close_panel",
]


func _handle_command(peer: StreamPeerTCP, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_respond_json(peer, 400, {"error": "body must be a JSON object"})
		return
	var action := str(parsed.get("action", ""))
	match action:
		"set_mood":
			var value: Variant = parsed.get("value")
			if not _is_unit_float(value):
				_respond_json(peer, 400, {"error": "value must be a number in 0.0-1.0"})
				return
			# Specchia profile_hud_panel._on_mood_changed (slider mood).
			SignalBus.mood_level_changed.emit(float(value))
			SignalBus.settings_updated.emit("mood_level", float(value))
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": float(value)})
		"set_stress":
			var value: Variant = parsed.get("value")
			if not _is_unit_float(value):
				_respond_json(peer, 400, {"error": "value must be a number in 0.0-1.0"})
				return
			# API pubblica usata da gioco e test (StressManager.apply_delta).
			StressManager.apply_delta(float(value) - StressManager.get_stress_value())
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": float(value)})
		"save":
			SignalBus.save_requested.emit()
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": "requested"})
		"set_language":
			var lang := str(parsed.get("lang", ""))
			if not Constants.LANGUAGES.has(lang):
				_respond_json(peer, 400, {"error": "lang must be one of %s" % [
					Constants.LANGUAGES.keys(),
				]})
				return
			# Specchia settings_panel.gd:224-225.
			TranslationServer.set_locale(lang)
			SignalBus.settings_updated.emit("language", lang)
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": lang})
		"toggle_track":
			# Stesso toggle play/pause usato dal controllo musica del HUD.
			AudioManager.pause()
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": "toggled"})
		"open_panel", "close_panel":
			var panel_manager := _find_panel_manager()
			if panel_manager == null:
				_respond_json(peer, 400, {"error": "no active game scene (PanelManager not found)"})
				return
			if action == "open_panel":
				panel_manager.open_panel(str(parsed.get("panel", "")))
			else:
				panel_manager.close_current_panel()
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": "requested"})
		_:
			_respond_json(peer, 400, {"error": "unknown action; valid: %s" % [VALID_ACTIONS]})


func _is_unit_float(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	return float(value) >= 0.0 and float(value) <= 1.0


func _find_panel_manager() -> PanelManager:
	# main.gd crea PanelManager come figlio della scena di gioco (main.gd:19-22).
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("PanelManager") as PanelManager
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0, 112 + 15 ALL PASS. Note: `set_mood 0.25` may trigger MoodManager overlay effects headless — harmless.

- [ ] **Step 5: Commit**

```bash
git add v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
git commit -m "feat(bridge): dispatch /command — 7 azioni UI-equivalenti con validazione

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Observability — `/events` ring, `/tree`, `/logs/tail`

**Files:**
- Modify: `v1/scripts/autoload/dev_bridge.gd`
- Modify: `v1/tests/integration/test_bridge.gd` (add 4 tests)

**Interfaces:**
- Consumes: `_route` match, `_respond_json`, `start()` (tap hookup added there), `AppLogger.get_log_file_path() -> String`, `SignalBus.get_signal_list()`.
- Produces: `EVENT_TAPS` const, `_events`/`_events_dropped` populated, `_record(sig_name, args)`.

- [ ] **Step 1: Write the failing tests**

Insert after `test_command_open_panel_without_game_scene`:

```gdscript
func test_events_contains_mood_traffic() -> void:
	await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": 0.42}))
	var resp: Dictionary = await _http("GET", "/events")
	assert_eq(resp.status, 200, "GET /events non 200")
	var found := false
	if resp.json is Dictionary:
		for event in resp.json.get("events", []):
			if event.get("signal", "") == "mood_level_changed":
				found = true
	assert_true(found, "/events non contiene mood_level_changed")
	await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": 1.0}))


func test_events_ring_capped_at_200() -> void:
	for i in range(250):
		SignalBus.mood_level_changed.emit(0.5)
	var resp: Dictionary = await _http("GET", "/events")
	assert_eq(resp.status, 200)
	if resp.json is Dictionary:
		assert_true(resp.json.get("events", []).size() <= 200, "ring oltre 200 voci")
		assert_true(int(resp.json.get("dropped", 0)) > 0, "dropped non conteggiato")
	SignalBus.mood_level_changed.emit(1.0)


func test_tree_returns_root_structure() -> void:
	var resp: Dictionary = await _http("GET", "/tree?depth=2")
	assert_eq(resp.status, 200, "GET /tree non 200")
	if resp.json is Dictionary:
		var tree: Dictionary = resp.json.get("tree", {})
		assert_eq(str(tree.get("name", "")), "root", "radice non 'root'")
		assert_true(tree.get("children", []).size() > 0, "root senza figli (autoload attesi)")


func test_logs_tail_returns_lines() -> void:
	AppLogger.info("dev_bridge_test", "riga_sentinella_test_bridge")
	var resp: Dictionary = await _http("GET", "/logs/tail?n=50")
	assert_eq(resp.status, 200, "GET /logs/tail non 200")
	if resp.json is Dictionary:
		assert_true(resp.json.get("lines", null) is Array, "lines non e' un array")
```

Note: `test_logs_tail` asserts only shape, not content — AppLogger buffers writes, so the sentinel line may not be flushed to disk yet. That is accepted spec behavior (dev tool reads the file as-is).

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: 4 new tests FAIL with 404. Earlier tests pass.

- [ ] **Step 3: Implement taps and endpoints**

Add const (near the other consts):

```gdscript
# Segnali SignalBus registrati nel ring /events — SOLO ascolto, mai emissione.
const EVENT_TAPS := [
	"mood_level_changed", "mood_changed", "stress_changed", "save_completed",
	"save_failed", "mess_spawned", "mess_cleaned", "coins_changed",
	"badge_unlocked", "db_error", "sync_error", "catalog_load_failed",
	"language_changed", "track_play_pause_toggled", "panel_opened", "panel_closed",
]
const TREE_DEPTH_DEFAULT := 3
const TREE_DEPTH_MAX := 8
const LOGS_TAIL_DEFAULT := 100
const LOGS_TAIL_MAX := 1000
```

In `start()`, right before `set_process(true)`, add:

```gdscript
	_connect_event_taps()
```

Add the tap machinery (GDScript has no variadics: one tap per arity, signal name bound as LAST arg):

```gdscript
func _connect_event_taps() -> void:
	var arg_counts := {}
	for info in SignalBus.get_signal_list():
		arg_counts[str(info.name)] = info.args.size()
	for sig_name in EVENT_TAPS:
		if not arg_counts.has(sig_name):
			AppLogger.warn(SOURCE, "tap_signal_missing", {"signal": sig_name})
			continue
		match int(arg_counts[sig_name]):
			0:
				SignalBus.connect(sig_name, _tap0.bind(sig_name))
			1:
				SignalBus.connect(sig_name, _tap1.bind(sig_name))
			2:
				SignalBus.connect(sig_name, _tap2.bind(sig_name))
			_:
				AppLogger.warn(SOURCE, "tap_arity_unsupported", {"signal": sig_name})


func _tap0(sig_name: String) -> void:
	_record(sig_name, [])


func _tap1(a: Variant, sig_name: String) -> void:
	_record(sig_name, [a])


func _tap2(a: Variant, b: Variant, sig_name: String) -> void:
	_record(sig_name, [a, b])


func _record(sig_name: String, args: Array) -> void:
	var safe_args: Array[String] = []
	for arg in args:
		safe_args.append(str(arg))  # stringify difensivo: nessun ref di oggetti
	_events.append({"t_ms": Time.get_ticks_msec(), "signal": sig_name, "args": safe_args})
	while _events.size() > RING_CAP:
		_events.pop_front()
		_events_dropped += 1
```

Add the three `_route` arms before `_:`:

```gdscript
		"/events":
			if method != "GET":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			_respond_json(peer, 200, {"events": _events, "dropped": _events_dropped})
		"/tree":
			if method != "GET":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			var depth := TREE_DEPTH_DEFAULT
			if str(query.get("depth", "")).is_valid_int():
				depth = clampi(str(query.get("depth")).to_int(), 1, TREE_DEPTH_MAX)
			_respond_json(peer, 200, {"tree": _dump_tree(get_tree().root, depth)})
		"/logs/tail":
			if method != "GET":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			var n := LOGS_TAIL_DEFAULT
			if str(query.get("n", "")).is_valid_int():
				n = clampi(str(query.get("n")).to_int(), 1, LOGS_TAIL_MAX)
			_respond_json(peer, 200, {"lines": _tail_log(n)})
```

Add the two helpers:

```gdscript
func _dump_tree(node: Node, depth: int) -> Dictionary:
	var entry := {"name": str(node.name), "class": node.get_class()}
	if node is CanvasItem or node is Node3D or node is Window:
		entry["visible"] = node.visible
	if depth > 1:
		var children: Array[Dictionary] = []
		for child in node.get_children():
			children.append(_dump_tree(child, depth - 1))
		entry["children"] = children
	return entry


func _tail_log(n: int) -> Array:
	var path := AppLogger.get_log_file_path()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var lines := file.get_as_text().split("\n", false)
	var start := maxi(0, lines.size() - n)
	var out: Array[String] = []
	for i in range(start, lines.size()):
		out.append(lines[i])
	return out
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0, 112 + 19 ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
git commit -m "feat(bridge): osservabilita' — ring /events, /tree, /logs/tail

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `/screenshot`, `/quit`, teardown test, manual verification

**Files:**
- Modify: `v1/scripts/autoload/dev_bridge.gd` (2 route arms)
- Modify: `v1/tests/integration/test_bridge.gd` (final teardown test)

**Interfaces:**
- Consumes: `_route`, `_respond_json`, `_respond_bytes`, `stop()`.
- Produces: complete endpoint surface per spec §4.

- [ ] **Step 1: Write the failing teardown test**

Add as the LAST `test_*` method (declaration order = execution order; this must run after every other bridge test, but BEFORE the helper functions in the file):

```gdscript
func test_zz_stop_closes_server() -> void:
	DevBridge.stop()
	assert_false(DevBridge.is_active(), "is_active() vero dopo stop()")
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", TEST_PORT)
	var connected := false
	for i in range(30):
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			connected = true
			break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			break
		await get_tree().process_frame
	assert_false(connected, "porta ancora aperta dopo stop()")
```

- [ ] **Step 2: Run tests — teardown passes already (stop() exists from Task 1); verify /screenshot and /quit are still 404**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0. This step is a regression checkpoint before adding the last two routes.

- [ ] **Step 3: Implement the two remaining routes**

Add to `_route` before `_:`:

```gdscript
		"/screenshot":
			if method != "GET":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			var texture := get_viewport().get_texture()
			var image := texture.get_image() if texture != null else null
			if image == null:
				_respond_json(peer, 500, {"error": "no viewport image (headless?)"})
				return
			_respond_bytes(peer, 200, "image/png", image.save_png_to_buffer())
		"/quit":
			if method != "POST":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			_respond_json(peer, 200, {"ok": true})
			# Stesso percorso della X della finestra: SaveManager intercetta
			# WM_CLOSE_REQUEST (auto_accept_quit off), salva e poi esce.
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
```

- [ ] **Step 4: Run the full suite (regression)**

Run: `godot4 --headless --path v1/ res://tests/test_runner.tscn`
Expected: exit 0, 112 + 20 ALL PASS.

- [ ] **Step 5: Manual verification (documents spec §7 exclusions)**

Launch the real game with the bridge (substitute the Godot binary):

```bash
godot4 --path v1/ -- --bridge &
sleep 8
curl -s http://127.0.0.1:8080/status
curl -s -X POST http://127.0.0.1:8080/command -d '{"action":"set_mood","value":0.1}'
curl -s http://127.0.0.1:8080/screenshot -o /tmp/bridge_shot.png && file /tmp/bridge_shot.png
curl -s -X POST http://127.0.0.1:8080/quit
```

Expected: `/status` JSON with `app_version` `1.1.0`; after `set_mood 0.1` the room visibly turns gloomy/rainy and audio shifts; screenshot is a valid PNG; `/quit` closes the game after a save (check the process exited and no `save_failed` toast appeared). Also verify gate 2: launch WITHOUT `-- --bridge`, confirm `curl http://127.0.0.1:8080/status` fails to connect, close the game.

- [ ] **Step 6: Commit**

```bash
git add v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
git commit -m "feat(bridge): /screenshot e /quit, test di teardown — superficie endpoint completa

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Documentation, changelog, full verification

**Files:**
- Modify: `README.md` (repo root — autoload table + count)
- Modify: `v1/README.md` (autoload chain + testing section)
- Modify: `v1/scripts/README.md` (autoload table)
- Modify: `v1/tests/README.md` (module table + totals)
- Modify: `CHANGELOG.md` (`[Unreleased]`)

**Interfaces:**
- Consumes: final test count from Task 5's run (expected 132 total = 112 + 20; use the runner's actual reported total).

- [ ] **Step 1: Update repo root `README.md`**

- Heading `## Stato dei sistemi (12 autoload singleton)` → `(13 autoload singleton)`.
- Append row 13 to the autoload table, matching its column format:

```markdown
| 13 | **DevBridge** | `autoload/dev_bridge.gd` | API HTTP locale debug-only (127.0.0.1, `--bridge`, porta 8080). Audit e test |
```

- In the Testing section, after the `deep_test.sh` block, add:

```markdown
Dev bridge (solo build debug, mai attivo senza flag):

```bash
godot4 --path v1/ -- --bridge          # avvia il gioco con l'API su 127.0.0.1:8080
curl http://127.0.0.1:8080/status      # stato: versione, fps, mood, stress, coins
curl -X POST http://127.0.0.1:8080/command -d '{"action":"set_mood","value":0.5}'
```
```

- [ ] **Step 2: Update `v1/README.md`, `v1/scripts/README.md`, `v1/tests/README.md`**

- `v1/README.md`: find the autoload chain table/mentions ("12 autoload"), add DevBridge as position 13 with one line: *API HTTP locale debug-only per audit/test — attiva solo con `--bridge` in build debug, bind 127.0.0.1:8080*. Update any "12" count referring to autoloads.
- `v1/scripts/README.md`: append DevBridge row to its autoload table, same one-line description, using that file's existing column format.
- `v1/tests/README.md`: add module row matching the table format: `| test_bridge.gd | 20 | Lifecycle e triplo gate, parser HTTP (400/404/405/413), /status schema+valori, dispatch /command (mood/stress/save/panel), ring /events cap 200, /tree, /logs/tail, teardown stop() |` — and update the totals ("112 test" → the runner's actual total, expected "132 test", both in the intro line and the `**Totale**` line).

- [ ] **Step 3: Update `CHANGELOG.md`**

Under `## [Unreleased]`, add:

```markdown
### Added

- **DevBridge (tooling di sviluppo)**: API HTTP locale debug-only per audit e
  test. Autoload 13, attivo solo con build debug + flag `--bridge`, bind
  esclusivo 127.0.0.1 (default 8080). Endpoint: `/status`, `/tree`, `/events`
  (ring 200 segnali SignalBus), `/logs/tail`, `/screenshot`, `/command` (7
  azioni UI-equivalenti), `/quit` (percorso WM_CLOSE con salvataggio finale).
  Regola architetturale: solo segnali di input o metodi pubblici gia' usati
  dalla UI — mai segnali di output dei sistemi. 20 test di integrazione.
  Spec: `v1/docs/specs/2026-08-08-dev-bridge-design.md`.
```

- [ ] **Step 4: Full verification**

```bash
./scripts/deep_test.sh        # expected: ALL PASS, exit 0 (132 test)
./scripts/preflight.sh        # expected: GO, exit 0
```

If `gdlint`/`gdformat` are available locally (`pip show gdtoolkit`), also run:

```bash
gdlint v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
gdformat --check v1/scripts/autoload/dev_bridge.gd v1/tests/integration/test_bridge.gd
```

Expected: zero violations. If gdformat reformats, re-run tests before committing. If the tools are not installed, note it — CI runs them via pre-commit.

- [ ] **Step 5: Commit**

```bash
git add README.md v1/README.md v1/scripts/README.md v1/tests/README.md CHANGELOG.md
git commit -m "docs(bridge): DevBridge nei README (13 autoload), changelog, guida d'uso

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Spec acceptance criteria → where verified

| Spec §10 criterion | Verified by |
|---|---|
| Release export: no listener ever | Gate 1 code path (Task 1) — structural; release export smoke is part of CI build |
| Debug without `--bridge`: no listener | `test_inert_without_flag` (Task 1) |
| Debug with `--bridge`: curl /status + set_mood visible | Task 5 Step 5 manual verification |
| Full suite passes | Every task's run step + Task 6 Step 4 |
| preflight GO | Task 6 Step 4 |
| No new gdlint violations | Task 6 Step 4 |
