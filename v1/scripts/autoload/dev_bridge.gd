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
const STATUS_TEXT := {
	200: "OK", 400: "Bad Request", 404: "Not Found",
	405: "Method Not Allowed", 413: "Payload Too Large", 500: "Internal Server Error",
}
const VALID_ACTIONS := [
	"set_mood", "set_stress", "save", "set_language",
	"toggle_track", "open_panel", "close_panel",
]
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
	# Garanzia strutturale: una build release non puo' MAI mettersi in ascolto,
	# indipendentemente dai punti di chiamata.
	if not OS.is_debug_build():
		return false
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
	_events.clear()
	_events_dropped = 0
	_connect_event_taps()
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
		"/command":
			if method != "POST":
				_respond_json(peer, 405, {"error": "method not allowed"})
				return
			_handle_command(peer, body)
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
			# Segnale di input: stesso percorso del salvataggio richiesto dalla UI (SaveManager ascolta save_requested).
			SignalBus.save_requested.emit()
			_respond_json(peer, 200, {"ok": true, "action": action, "detail": "requested"})
		"set_language":
			var lang := str(parsed.get("lang", ""))
			if not Constants.LANGUAGES.has(lang):
				_respond_json(peer, 400, {"error": "lang must be one of %s" % [
					Constants.LANGUAGES.keys(),
				]})
				return
			# Specchia settings_panel.gd:224-226.
			TranslationServer.set_locale(lang)
			SignalBus.settings_updated.emit("language", lang)
			SignalBus.language_changed.emit(lang)
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
				var callable := _tap0.bind(sig_name)
				if not SignalBus.is_connected(sig_name, callable):
					SignalBus.connect(sig_name, callable)
			1:
				var callable := _tap1.bind(sig_name)
				if not SignalBus.is_connected(sig_name, callable):
					SignalBus.connect(sig_name, callable)
			2:
				var callable := _tap2.bind(sig_name)
				if not SignalBus.is_connected(sig_name, callable):
					SignalBus.connect(sig_name, callable)
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
	if path == null or path == "":
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	if text == null or text == "":
		return []
	var lines := text.split("\n", false)
	var start := maxi(0, lines.size() - n)
	var out: Array[String] = []
	for i in range(start, lines.size()):
		out.append(lines[i])
	return out
