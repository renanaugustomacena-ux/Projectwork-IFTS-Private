## SupabaseClient — Cloud sync via Supabase REST API.
## Offline-first: all operations degrade gracefully when network is unavailable.
## Elia is actively evolving the Supabase schema — this client handles missing
## tables and columns without crashing.
extends Node

const _ConfigScript := preload("res://scripts/utils/supabase_config.gd")
const _HttpScript := preload("res://scripts/utils/supabase_http.gd")
const _MapperScript := preload("res://scripts/utils/supabase_mapper.gd")

enum ConnectionState { OFFLINE, CONNECTING, ONLINE, ERROR }

const AUTH_ENDPOINT := "/auth/v1"
const REST_ENDPOINT := "/rest/v1"
const SESSION_PATH := "user://supabase_session.cfg"

var connection_state: int = ConnectionState.OFFLINE
var supabase_user_id: String = ""
var _jwt_token: String = ""
var _refresh_token: String = ""
var _jwt_expires_at: float = 0.0
var _config: Dictionary = {}
var _http = null
var _sync_timer: Timer = null
var _is_syncing: bool = false
var _pending_requests: Dictionary = {}
var _request_counter: int = 0


func _ready() -> void:
	_config = _ConfigScript.load_config()
	if not _config.get("valid", false):
		AppLogger.info(
			"SupabaseClient", "No valid Supabase config, cloud sync disabled"
		)
		return
	_http = _HttpScript.new()
	_http.initialize(self)
	_http.request_completed.connect(_on_request_completed)
	_setup_sync_timer()
	_try_restore_session()
	AppLogger.info("SupabaseClient", "Initialized", {
		"url": _config["url"].left(40),
	})


# ---- Configuration ----


func is_configured() -> bool:
	return _config.get("valid", false)


func is_online() -> bool:
	return connection_state == ConnectionState.ONLINE


func _base_url() -> String:
	return _config.get("url", "")


func _anon_key() -> String:
	return _config.get("anon_key", "")


# ---- Supabase Auth ----


func sign_up(email: String, password: String) -> void:
	if not is_configured():
		SignalBus.cloud_auth_completed.emit(false)
		return
	var url := _base_url() + AUTH_ENDPOINT + "/signup"
	var body := JSON.stringify({"email": email, "password": password})
	var rid := _next_rid("auth_signup")
	_http.request(url, HTTPClient.METHOD_POST, _auth_headers(), body, rid)


func sign_in(email: String, password: String) -> void:
	if not is_configured():
		SignalBus.cloud_auth_completed.emit(false)
		return
	var url := _base_url() + AUTH_ENDPOINT + "/token?grant_type=password"
	var body := JSON.stringify({"email": email, "password": password})
	var rid := _next_rid("auth_signin")
	_http.request(url, HTTPClient.METHOD_POST, _auth_headers(), body, rid)


func refresh_jwt() -> void:
	if _refresh_token.is_empty():
		return
	var url := _base_url() + AUTH_ENDPOINT + "/token?grant_type=refresh_token"
	var body := JSON.stringify({"refresh_token": _refresh_token})
	var rid := _next_rid("auth_refresh")
	_http.request(url, HTTPClient.METHOD_POST, _auth_headers(), body, rid)


func sign_out_cloud() -> void:
	_jwt_token = ""
	_refresh_token = ""
	_jwt_expires_at = 0.0
	supabase_user_id = ""
	connection_state = ConnectionState.OFFLINE
	_save_session()
	SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)
	AppLogger.info("SupabaseClient", "Signed out from cloud")


# ---- Session Persistence ----


## Derive una chiave di cifratura dal percorso user data dir + salt costante.
## Stesso device → stessa chiave. Altro device → non riesce a decifrare.
## Raddrizza il pattern plaintext su disco (fix B-019: token encryption).
## Nota: non protegge da attacker che legge memoria del processo, ma blocca
## grep banale + copia del .cfg su altro PC.
const _SESSION_SALT := "relax-room-2026-session-v1"


func _derive_session_key() -> String:
	return (OS.get_user_data_dir() + _SESSION_SALT).sha256_text()


func _try_restore_session() -> void:
	# Legge prima formato cifrato (nuovo), poi fallback plaintext legacy
	# per backward compatibility con session pre-fix B-019.
	var cfg := ConfigFile.new()
	var pass_key := _derive_session_key()
	var err := cfg.load_encrypted_pass(SESSION_PATH, pass_key)
	if err != OK:
		# Fallback legacy plaintext
		err = cfg.load(SESSION_PATH)
		if err == OK:
			AppLogger.warn(
				"SupabaseClient",
				"session_loaded_legacy_plaintext",
				{"action": "migrating_to_encrypted_on_next_save"}
			)
		else:
			return
	_jwt_token = cfg.get_value("session", "jwt", "")
	_refresh_token = cfg.get_value("session", "refresh_token", "")
	_jwt_expires_at = cfg.get_value("session", "expires_at", 0.0)
	supabase_user_id = cfg.get_value("session", "user_id", "")
	if _refresh_token.is_empty():
		return
	# Try refreshing the token
	AppLogger.info("SupabaseClient", "Restoring session, refreshing JWT")
	refresh_jwt()


func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "jwt", _jwt_token)
	cfg.set_value("session", "refresh_token", _refresh_token)
	cfg.set_value("session", "expires_at", _jwt_expires_at)
	cfg.set_value("session", "user_id", supabase_user_id)
	cfg.set_value("session", "local_account_id", AuthManager.current_account_id)
	# Salvataggio cifrato (fix B-019). Chiave derivata dal device user dir +
	# salt costante. Godot 4.5 nativo: ConfigFile.save_encrypted_pass.
	var pass_key := _derive_session_key()
	var err := cfg.save_encrypted_pass(SESSION_PATH, pass_key)
	if err != OK:
		AppLogger.error(
			"SupabaseClient",
			"session_save_encrypted_failed",
			{"err": err, "fallback": "plaintext"}
		)
		cfg.save(SESSION_PATH)


func _apply_auth_response(data: Dictionary) -> void:
	_jwt_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", _refresh_token)
	var expires_in: int = data.get("expires_in", 3600)
	_jwt_expires_at = Time.get_unix_time_from_system() + float(expires_in)
	var user: Dictionary = data.get("user", {})
	supabase_user_id = user.get("id", data.get("id", ""))
	if not _jwt_token.is_empty() and not supabase_user_id.is_empty():
		connection_state = ConnectionState.ONLINE
		_save_session()
		SignalBus.cloud_auth_completed.emit(true)
		SignalBus.cloud_connection_changed.emit(ConnectionState.ONLINE)
		AppLogger.info("SupabaseClient", "Authenticated", {
			"user_id": supabase_user_id.left(8) + "...",
		})
	else:
		connection_state = ConnectionState.ERROR
		SignalBus.cloud_auth_completed.emit(false)
		SignalBus.cloud_connection_changed.emit(ConnectionState.ERROR)


# ---- REST Operations ----


func fetch_table(table: String, query: String = "") -> String:
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table
	if not query.is_empty():
		url += "?" + query
	var rid := _next_rid("fetch_" + table)
	_http.request(url, HTTPClient.METHOD_GET, _bearer_headers(), "", rid)
	return rid


func upsert_to_table(table: String, data: Variant) -> String:
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table
	var headers := _bearer_headers()
	headers.append("Prefer: resolution=merge-duplicates")
	var body := JSON.stringify(data)
	var rid := _next_rid("upsert_" + table)
	_http.request(url, HTTPClient.METHOD_POST, headers, body, rid)
	return rid


func delete_from_table(table: String, query: String) -> String:
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table + "?" + query
	var rid := _next_rid("delete_" + table)
	_http.request(url, HTTPClient.METHOD_DELETE, _bearer_headers(), "", rid)
	return rid


func _ensure_jwt() -> bool:
	if not is_configured():
		return false
	if _jwt_token.is_empty():
		return false
	# Refresh if expiring within 60 seconds
	if Time.get_unix_time_from_system() > _jwt_expires_at - 60.0:
		refresh_jwt()
	return true


# ---- Headers ----


func _auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + _anon_key(),
		"Content-Type: application/json",
	])


func _bearer_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + _anon_key(),
		"Authorization: Bearer " + _jwt_token,
		"Content-Type: application/json",
	])


# ---- Response Router ----


func _on_request_completed(response: Dictionary) -> void:
	var rid: String = response.get("request_id", "")
	var status: int = response.get("status", 0)
	var body: Variant = response.get("body", null)

	# Auth responses
	if rid.begins_with("auth_"):
		_handle_auth_response(rid, status, body)
		return

	# Sync responses
	if rid.begins_with("sync_"):
		_handle_sync_response(rid, status, body)
		return

	# Table operations
	if status == 0:
		# Network failure
		AppLogger.warn("SupabaseClient", "Network failure", {"rid": rid})
		connection_state = ConnectionState.OFFLINE
		SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)
	elif status == 401:
		AppLogger.warn("SupabaseClient", "JWT expired, refreshing", {"rid": rid})
		refresh_jwt()
	elif status == 404 or (status == 400 and _is_relation_error(body)):
		# Table doesn't exist — Elia changed schema, skip gracefully
		AppLogger.warn("SupabaseClient", "Table not found, skipping", {
			"rid": rid,
		})
	elif status == 429:
		AppLogger.warn("SupabaseClient", "Rate limited", {"rid": rid})
	elif status >= 200 and status < 300:
		AppLogger.info("SupabaseClient", "Request OK", {"rid": rid})


func _handle_auth_response(
	rid: String, status: int, body: Variant,
) -> void:
	if status >= 200 and status < 300 and body is Dictionary:
		_apply_auth_response(body)
	else:
		var msg: String = ""
		if body is Dictionary:
			msg = body.get("error_description", body.get("msg", "Auth failed"))
		else:
			msg = "Auth failed (HTTP %d)" % status
		AppLogger.error("SupabaseClient", "Auth error", {
			"rid": rid, "status": status, "msg": msg,
		})
		if rid.contains("refresh"):
			# Refresh failed — session expired
			connection_state = ConnectionState.OFFLINE
			SignalBus.cloud_connection_changed.emit(ConnectionState.OFFLINE)
		else:
			SignalBus.cloud_auth_completed.emit(false)
			SignalBus.auth_error.emit(msg)


func _handle_sync_response(
	rid: String, status: int, _body: Variant,
) -> void:
	# Track sync completion
	_pending_requests.erase(rid)
	if status >= 200 and status < 300:
		# Clear from sync queue if this was a queued item
		var queue_id: int = _get_queue_id_from_rid(rid)
		if queue_id > 0:
			LocalDatabase.clear_sync_item(queue_id)
	elif status == 0:
		AppLogger.warn("SupabaseClient", "Sync request failed (offline)", {
			"rid": rid,
		})
	if _pending_requests.is_empty() and _is_syncing:
		_finish_sync(true)


func _is_relation_error(body: Variant) -> bool:
	if body is Dictionary:
		var msg: String = body.get("message", "")
		return "relation" in msg and "does not exist" in msg
	return false


func _get_queue_id_from_rid(rid: String) -> int:
	# Convention: sync_queue_42 → queue_id=42
	if rid.begins_with("sync_queue_"):
		var id_str := rid.substr("sync_queue_".length())
		if id_str.is_valid_int():
			return int(id_str)
	return -1


# ---- Sync Engine ----


func start_sync() -> void:
	if _is_syncing:
		return
	if not is_online():
		return
	_is_syncing = true
	_pending_requests.clear()
	SignalBus.sync_started.emit()
	AppLogger.info("SupabaseClient", "Sync started")
	_process_sync_queue()
	_push_local_state()


func _process_sync_queue() -> void:
	var pending := LocalDatabase.get_pending_sync()
	for item in pending:
		var queue_id: int = item.get("queue_id", -1)
		var retry: int = item.get("retry_count", 0)
		if retry > Constants.SUPABASE_MAX_RETRY:
			LocalDatabase.clear_sync_item(queue_id)
			continue
		var table_name: String = item.get("table_name", "")
		var operation: String = item.get("operation", "")
		var payload_str: String = item.get("payload", "{}")
		var json := JSON.new()
		if json.parse(payload_str) != OK:
			LocalDatabase.clear_sync_item(queue_id)
			continue
		var payload: Variant = json.data
		var rid := "sync_queue_%d" % queue_id
		_pending_requests[rid] = true
		if operation == "DELETE":
			delete_from_table(table_name, "id=eq." + str(payload.get("id", "")))
		else:
			upsert_to_table(table_name, payload)


func _push_local_state() -> void:
	if supabase_user_id.is_empty():
		_finish_sync(false)
		return
	# Push profile
	var account := LocalDatabase.get_account(AuthManager.current_account_id)
	var character := LocalDatabase.get_character(AuthManager.current_account_id)
	if not account.is_empty():
		var profile: Dictionary = _MapperScript.profile_to_cloud(
			account, character, supabase_user_id
		)
		var rid: String = _next_rid("sync_push_profiles")
		_pending_requests[rid] = true
		upsert_to_table("profiles", profile)

	# Push currency
	if not account.is_empty():
		var currency: Dictionary = _MapperScript.currency_to_cloud(account, supabase_user_id)
		var rid: String = _next_rid("sync_push_user_currency")
		_pending_requests[rid] = true
		upsert_to_table("user_currency", currency)

	# Push settings
	var settings: Variant = SaveManager.get_setting("language", "en")
	var settings_data: Dictionary = {
		"language": settings,
		"display_mode": SaveManager.get_setting("display_mode", "windowed"),
		"master_volume": SaveManager.get_setting("master_volume", 0.8),
		"music_volume": SaveManager.get_setting("music_volume", 0.6),
		"ambience_volume": SaveManager.get_setting("ambience_volume", 0.4),
	}
	var cloud_settings: Dictionary = _MapperScript.settings_to_cloud(
		settings_data, supabase_user_id
	)
	var settings_rid: String = _next_rid("sync_push_user_settings")
	_pending_requests[settings_rid] = true
	upsert_to_table("user_settings", cloud_settings)

	# Push music preferences
	var music: Dictionary = SaveManager.get_music_state()
	var cloud_music: Dictionary = _MapperScript.music_to_cloud(music, supabase_user_id)
	var music_rid: String = _next_rid("sync_push_music_preferences")
	_pending_requests[music_rid] = true
	upsert_to_table("music_preferences", cloud_music)

	# Push decorations
	var decos: Array = SaveManager.get_decorations()
	if not decos.is_empty():
		var cloud_decos: Array = _MapperScript.decorations_to_cloud(
			decos, supabase_user_id
		)
		# Delete old decorations first, then insert new
		var del_rid: String = _next_rid("sync_push_room_decorations_del")
		_pending_requests[del_rid] = true
		delete_from_table(
			"room_decorations",
			"user_id=eq." + supabase_user_id
		)
		for deco: Dictionary in cloud_decos:
			var deco_rid: String = _next_rid("sync_push_room_decorations")
			_pending_requests[deco_rid] = true
			upsert_to_table("room_decorations", deco)

	# If no pending requests, finish immediately
	if _pending_requests.is_empty():
		_finish_sync(true)


func _finish_sync(success: bool) -> void:
	_is_syncing = false
	SignalBus.sync_completed.emit(success)
	AppLogger.info("SupabaseClient", "Sync completed", {"success": success})


# ---- Timer ----


func _setup_sync_timer() -> void:
	_sync_timer = Timer.new()
	_sync_timer.wait_time = Constants.SUPABASE_SYNC_INTERVAL
	_sync_timer.autostart = false
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)


func _on_sync_timer() -> void:
	if is_online() and not _is_syncing:
		start_sync()


# ---- Helpers ----


func _next_rid(prefix: String) -> String:
	_request_counter += 1
	return "%s_%d" % [prefix, _request_counter]


# ---- Lifecycle ----


func _exit_tree() -> void:
	if _sync_timer and _sync_timer.timeout.is_connected(_on_sync_timer):
		_sync_timer.timeout.disconnect(_on_sync_timer)
	if _http:
		_http.request_completed.disconnect(_on_request_completed)
		_http.cleanup()
	_save_session()
