# gdlint: disable=max-public-methods
extends TestBase
## Modulo test DevBridge — API HTTP locale debug-only.
##
## NOTA: /screenshot e /quit sono verificati manualmente (viewport reale /
## terminazione processo) — vedi sezione "Verifica manuale" nel piano.
## I test chiamano DevBridge.start(TEST_PORT) direttamente: gli user args
## (--bridge) non sono simulabili in un run headless del runner.
## Il runner ordina i metodi test alfabeticamente (test_runner.gd:89): i prefissi
## `aa`/`zz` fissano il primo/ultimo test del modulo; ogni test HTTP auto-avvia il
## bridge con DevBridge.start(TEST_PORT).

const TEST_PORT := 8123


func test_aa_inert_without_flag() -> void:
	# Prefisso `aa` per ordinare PRIMO nel modulo: il runner ordina i metodi
	# alfabeticamente (test_runner.gd:89) e il modulo bridge e' l'ultimo, quindi
	# qui si osserva lo stato di boot reale PRIMA che qualunque test avvii il
	# bridge. Cattura is_active() diretto, senza stop()/start() che lo renderebbe
	# tautologico. Il runner gira senza `-- --bridge`: l'autoload e' spento al boot.
	var active_at_boot := DevBridge.is_active()
	assert_false(active_at_boot, "bridge attivo senza flag --bridge")


func test_start_rejects_invalid_port() -> void:
	DevBridge.stop()
	assert_false(DevBridge.start(80), "porta < 1024 accettata")
	assert_false(DevBridge.start(70000), "porta > 65535 accettata")
	assert_false(DevBridge.is_active(), "bridge attivo dopo start invalido")


func test_start_binds_localhost() -> void:
	assert_true(DevBridge.start(TEST_PORT), "start(%d) fallito" % TEST_PORT)
	assert_true(DevBridge.is_active(), "is_active() falso dopo start riuscito")
	# Idempotente: secondo start non deve fallire ne' ribindare.
	assert_true(DevBridge.start(TEST_PORT), "start idempotente fallito")


func test_status_ok_schema() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("GET", "/status")
	assert_eq(resp.status, 200, "GET /status non 200")
	assert_true(resp.json is Dictionary, "/status body non e' un oggetto JSON")
	if resp.json is Dictionary:
		for key in [
			"app_version",
			"bridge_version",
			"fps",
			"current_scene",
			"mood_level",
			"mood",
			"stress",
			"stress_level",
			"coins",
			"uptime_s",
		]:
			assert_true(resp.json.has(key), "/status manca chiave '%s'" % key)


func test_status_values_sane() -> void:
	DevBridge.start(TEST_PORT)
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
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("GET", "/nope")
	assert_eq(resp.status, 404, "path ignoto non 404")
	assert_true(resp.json is Dictionary and resp.json.has("error"), "404 senza campo error")


func test_wrong_method_405() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("POST", "/status")
	assert_eq(resp.status, 405, "POST /status non 405")


func test_malformed_request_400() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _raw_send("GARBAGE-SENZA-SPAZI\r\n\r\n")
	assert_eq(resp.status, 400, "request line malformata non 400")
	# Il gioco deve essere ancora vivo: una seconda richiesta valida risponde.
	var again: Dictionary = await _http("GET", "/status")
	assert_eq(again.status, 200, "bridge morto dopo richiesta malformata")


func test_oversized_body_413() -> void:
	DevBridge.start(TEST_PORT)
	# Content-Length oltre il tetto: 413 immediato, senza inviare il body.
	var raw := "POST /command HTTP/1.1\r\nHost: x\r\nContent-Length: 70000\r\n\r\n"
	var resp: Dictionary = await _raw_send(raw)
	assert_eq(resp.status, 413, "body oltre 64 KB non 413")


func test_command_set_mood() -> void:
	DevBridge.start(TEST_PORT)
	var previous: float = float(SaveManager.get_setting("mood_level", 1.0))
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": 0.25}))
	assert_eq(resp.status, 200, "set_mood non 200")
	# Percorso UI completo: settings_updated -> SaveManager persiste la chiave.
	assert_approx(
		float(SaveManager.get_setting("mood_level", 1.0)), 0.25, 0.001, "mood_level non persistito via settings_updated"
	)
	await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": previous}))


func test_command_set_mood_out_of_range() -> void:
	DevBridge.start(TEST_PORT)
	var previous: float = float(SaveManager.get_setting("mood_level", 1.0))
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "set_mood", "value": 1.7}))
	assert_eq(resp.status, 400, "set_mood fuori range non 400")
	assert_approx(float(SaveManager.get_setting("mood_level", 1.0)), previous, 0.001, "mood cambiato nonostante il 400")


func test_command_unknown_action() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "fly_to_moon"}))
	assert_eq(resp.status, 400, "azione ignota non 400")
	if resp.json is Dictionary:
		assert_true(str(resp.json.get("error", "")).contains("set_mood"), "il 400 non elenca le azioni valide")


func test_command_set_stress() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "set_stress", "value": 0.5}))
	assert_eq(resp.status, 200, "set_stress non 200")
	assert_approx(StressManager.get_stress_value(), 0.5, 0.001, "stress non applicato")
	StressManager.reset()


func test_command_set_language() -> void:
	DevBridge.start(TEST_PORT)
	var original: String = TranslationServer.get_locale()
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "set_language", "lang": "en"}))
	assert_eq(resp.status, 200, "set_language non 200")
	assert_true(TranslationServer.get_locale().begins_with("en"), "locale non passato a 'en'")
	# Il percorso UI completo emette language_changed: deve finire nel ring /events.
	var events: Dictionary = await _http("GET", "/events")
	var found := false
	if events.json is Dictionary:
		for event in events.json.get("events", []):
			if event.get("signal", "") == "language_changed":
				found = true
	assert_true(found, "/events non contiene language_changed")
	# Ripristina la locale originale via lo stesso percorso comando (chiavi it/en).
	var restore := "it" if original.begins_with("it") else "en"
	await _http("POST", "/command", JSON.stringify({"action": "set_language", "lang": restore}))


func test_command_save_emits_request() -> void:
	DevBridge.start(TEST_PORT)
	var seen := [false]
	var handler := func() -> void: seen[0] = true
	SignalBus.save_requested.connect(handler)
	var resp: Dictionary = await _http("POST", "/command", JSON.stringify({"action": "save"}))
	SignalBus.save_requested.disconnect(handler)
	assert_eq(resp.status, 200, "save non 200")
	assert_true(seen[0], "save_requested non emesso")


func test_command_open_panel_without_game_scene() -> void:
	DevBridge.start(TEST_PORT)
	# In headless il current_scene e' il test runner: niente PanelManager.
	var resp: Dictionary = await _http(
		"POST", "/command", JSON.stringify({"action": "open_panel", "panel": "settings"})
	)
	assert_eq(resp.status, 400, "open_panel senza scena di gioco non 400")


func test_events_contains_mood_traffic() -> void:
	DevBridge.start(TEST_PORT)
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
	DevBridge.start(TEST_PORT)
	for i in range(250):
		SignalBus.mood_level_changed.emit(0.5)
	var resp: Dictionary = await _http("GET", "/events")
	assert_eq(resp.status, 200)
	if resp.json is Dictionary:
		assert_true(resp.json.get("events", []).size() <= 200, "ring oltre 200 voci")
		assert_true(int(resp.json.get("dropped", 0)) > 0, "dropped non conteggiato")
	SignalBus.mood_level_changed.emit(1.0)


func test_tree_returns_root_structure() -> void:
	DevBridge.start(TEST_PORT)
	var resp: Dictionary = await _http("GET", "/tree?depth=2")
	assert_eq(resp.status, 200, "GET /tree non 200")
	if resp.json is Dictionary:
		var tree: Dictionary = resp.json.get("tree", {})
		assert_eq(str(tree.get("name", "")), "root", "radice non 'root'")
		assert_true(tree.get("children", []).size() > 0, "root senza figli (autoload attesi)")


func test_logs_tail_returns_lines() -> void:
	DevBridge.start(TEST_PORT)
	AppLogger.info("dev_bridge_test", "riga_sentinella_test_bridge")
	var resp: Dictionary = await _http("GET", "/logs/tail?n=50")
	assert_eq(resp.status, 200, "GET /logs/tail non 200")
	if resp.json is Dictionary:
		assert_true(resp.json.get("lines", null) is Array, "lines non e' un array")


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


func _http(method: String, path: String, body: String = "") -> Dictionary:
	var payload := body.to_utf8_buffer()
	var req := (
		"%s %s HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: %d\r\n\r\n"
		% [
			method,
			path,
			payload.size(),
		]
	)
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
