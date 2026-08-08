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
			"app_version", "bridge_version", "fps", "current_scene",
			"mood_level", "mood", "stress", "stress_level", "coins", "uptime_s",
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
