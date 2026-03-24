## SupabaseClient — Thin REST wrapper for Supabase PostgREST and GoTrue APIs.
## Handles authentication tokens, request construction, and response parsing.
##
## Lightweight, purpose-built REST client for Supabase. Handles authentication
## (email/password + token refresh), CRUD operations via PostgREST, and HTTP
## connection pooling. Does NOT depend on external plugins. If Supabase keys
## are not configured, all online features gracefully disable without
## impacting offline gameplay.
extends Node

const AUTH_TOKEN_PATH := "user://auth.cfg"
const TOKEN_REFRESH_MARGIN := 60.0  # Refresh 60s before expiry
const REQUEST_TIMEOUT := 10.0
const POOL_SIZE := 4
const MAX_POOL_SIZE := 8

var _base_url: String = ""
var _anon_key: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _is_authenticated: bool = false
var _token_expires_at: float = 0.0

var _http_pool: Array[HTTPRequest] = []
var _refresh_timer: Timer
var _is_refreshing: bool = false


func _ready() -> void:
	_load_config()
	_initialize_http_pool()
	_setup_refresh_timer()
	_try_restore_session()

	if is_configured():
		(
			AppLogger
			. info(
				"SupabaseClient",
				"Initialized",
				{
					"url": _base_url.left(40),
					"online_features": true,
				}
			)
		)
	else:
		AppLogger.info("SupabaseClient", "No Supabase config found — online features disabled")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_auth_tokens()


# --- Public API: Configuration ---


## Returns true if Supabase URL and anon key are configured.
func is_configured() -> bool:
	return not _base_url.is_empty() and not _anon_key.is_empty()


## Returns true if the user is currently authenticated.
func is_authenticated() -> bool:
	return _is_authenticated


## Returns the current user's UUID, or empty string if not authenticated.
func get_user_id() -> String:
	return _user_id


# --- Public API: Authentication ---


## Register a new user with email and password.
func sign_up(email: String, password: String) -> Dictionary:
	if not is_configured():
		return _offline_error()

	if email.strip_edges().is_empty() or password.is_empty():
		AppLogger.warn("SupabaseClient", "Sign up: email o password vuoti")
		return {"error": "validation_failed", "message": "Email and password are required"}

	AppLogger.info("SupabaseClient", "Signing up", {"email": email})
	var url := _base_url + "/auth/v1/signup"
	var body := JSON.stringify({"email": email, "password": password})
	var result: Variant = await _post(url, body, _anon_headers())

	if result is Dictionary and result.has("access_token"):
		_apply_auth_response(result)

	return result if result is Dictionary else {"error": "unexpected_response"}


## Sign in with email and password.
func sign_in_email(email: String, password: String) -> Dictionary:
	if not is_configured():
		return _offline_error()

	if email.strip_edges().is_empty() or password.is_empty():
		AppLogger.warn("SupabaseClient", "Sign in: email o password vuoti")
		return {"error": "validation_failed", "message": "Email and password are required"}

	AppLogger.info("SupabaseClient", "Signing in", {"email": email})
	var url := _base_url + "/auth/v1/token?grant_type=password"
	var body := JSON.stringify({"email": email, "password": password})
	var result: Variant = await _post(url, body, _anon_headers())

	if result is Dictionary and result.has("access_token"):
		_apply_auth_response(result)
	elif result is Dictionary:
		var msg: String = result.get("error_description", result.get("msg", "Unknown error"))
		AppLogger.warn("SupabaseClient", "Sign in failed", {"reason": msg})
		SignalBus.auth_error.emit(msg)

	return result if result is Dictionary else {"error": "unexpected_response"}


## Sign out the current user.
func sign_out() -> void:
	if not _is_authenticated:
		return

	AppLogger.info("SupabaseClient", "Signing out", {"user_id": _user_id})

	if is_configured():
		var url := _base_url + "/auth/v1/logout"
		await _post(url, "", _bearer_headers())

	_clear_auth()
	_delete_auth_tokens()
	SignalBus.user_signed_out.emit()


## Refresh the current session using the stored refresh token.
func refresh_session() -> Dictionary:
	if _refresh_token.is_empty() or not is_configured():
		return _offline_error()
	if _is_refreshing:
		return {"error": "refresh_in_progress"}

	_is_refreshing = true
	AppLogger.debug("SupabaseClient", "Refreshing session")
	var url := _base_url + "/auth/v1/token?grant_type=refresh_token"
	var body := JSON.stringify({"refresh_token": _refresh_token})
	var result: Variant = await _post(url, body, _anon_headers())

	if result is Dictionary and result.has("access_token"):
		_apply_auth_response(result)
		AppLogger.info("SupabaseClient", "Session refreshed")
	else:
		AppLogger.warn("SupabaseClient", "Session refresh failed — clearing auth")
		_clear_auth()

	_is_refreshing = false
	return result if result is Dictionary else {"error": "unexpected_response"}


# --- Public API: Database (PostgREST) ---


## SELECT rows from a table. query_params uses PostgREST syntax.
## Example: select("profiles", "user_id=eq.abc123&limit=1")
func select(table: String, query_params: String = "") -> Array:
	if not is_configured() or not _is_authenticated:
		return []

	var url := "%s/rest/v1/%s?%s" % [_base_url, table.uri_encode(), query_params]
	var result: Variant = await _http_get(url, _bearer_headers())

	if result is Array:
		return result
	return []


## INSERT a row into a table. Returns the inserted row.
func insert(table: String, data: Dictionary) -> Dictionary:
	if not is_configured() or not _is_authenticated:
		return _offline_error()

	var url := "%s/rest/v1/%s" % [_base_url, table.uri_encode()]
	var headers := _bearer_headers()
	headers.append("Prefer: return=representation")
	var result: Variant = await _post(url, JSON.stringify(data), headers)
	return result if result is Dictionary else _parse_array_result(result)


## UPDATE rows matching query_params. Returns updated rows.
func update(table: String, query_params: String, data: Dictionary) -> Dictionary:
	if not is_configured() or not _is_authenticated:
		return _offline_error()

	var url := "%s/rest/v1/%s?%s" % [_base_url, table.uri_encode(), query_params]
	var headers := _bearer_headers()
	headers.append("Prefer: return=representation")
	var result: Variant = await _patch(url, JSON.stringify(data), headers)
	return result if result is Dictionary else _parse_array_result(result)


## DELETE rows matching query_params.
func delete(table: String, query_params: String) -> Dictionary:
	if not is_configured() or not _is_authenticated:
		return _offline_error()

	var url := "%s/rest/v1/%s?%s" % [_base_url, table.uri_encode(), query_params]
	var result: Variant = await _delete_request(url, _bearer_headers())
	return result if result is Dictionary else {}


## UPSERT a row (insert or update on conflict). Returns the row.
func upsert(table: String, data: Dictionary) -> Dictionary:
	if not is_configured() or not _is_authenticated:
		return _offline_error()

	var url := "%s/rest/v1/%s" % [_base_url, table.uri_encode()]
	var headers := _bearer_headers()
	headers.append("Prefer: return=representation,resolution=merge-duplicates")
	var result: Variant = await _post(url, JSON.stringify(data), headers)
	return result if result is Dictionary else _parse_array_result(result)


# --- Internal: Configuration Loading ---


func _load_config() -> void:
	var config := EnvLoader.load_config()
	_base_url = config.get("SUPABASE_URL", "")
	_anon_key = config.get("SUPABASE_ANON_KEY", "")

	# Strip trailing slash from URL
	if _base_url.ends_with("/"):
		_base_url = _base_url.left(_base_url.length() - 1)


func _try_restore_session() -> void:
	if not is_configured():
		return
	if not FileAccess.file_exists(AUTH_TOKEN_PATH):
		return

	var cfg := ConfigFile.new()
	var err := cfg.load_encrypted_pass(AUTH_TOKEN_PATH, _get_encryption_key())
	if err != OK:
		_try_restore_legacy_session()
		return

	_refresh_token = cfg.get_value("auth", "refresh_token", "")
	if not _refresh_token.is_empty():
		AppLogger.debug("SupabaseClient", "Found saved session, attempting refresh")
		call_deferred("_deferred_refresh")


func _try_restore_legacy_session() -> void:
	var file := FileAccess.open(AUTH_TOKEN_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return
	_refresh_token = data.get("refresh_token", "")
	if not _refresh_token.is_empty():
		AppLogger.info("SupabaseClient", "Migrating legacy auth tokens to encrypted format")
		_save_auth_tokens()
		call_deferred("_deferred_refresh")


func _get_encryption_key() -> String:
	return "MCR_%s_%s" % [OS.get_unique_id(), _anon_key.left(16)]


func _deferred_refresh() -> void:
	await refresh_session()


# --- Internal: Token Management ---


func _apply_auth_response(data: Dictionary) -> void:
	_access_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")

	var expires_in: int = data.get("expires_in", 3600)
	_token_expires_at = Time.get_unix_time_from_system() + float(expires_in)

	var user = data.get("user", {})
	if user is Dictionary:
		_user_id = user.get("id", "")

	_is_authenticated = not _access_token.is_empty() and not _user_id.is_empty()

	if _is_authenticated:
		AppLogger.info("SupabaseClient", "Authenticated", {"user_id": _user_id})
		_save_auth_tokens()
		_restart_refresh_timer(expires_in)
		SignalBus.user_authenticated.emit(_user_id)


func _clear_auth() -> void:
	_access_token = ""
	_refresh_token = ""
	_user_id = ""
	_is_authenticated = false
	_token_expires_at = 0.0
	_refresh_timer.stop()


func _save_auth_tokens() -> void:
	if _refresh_token.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", _refresh_token)
	var err := cfg.save_encrypted_pass(AUTH_TOKEN_PATH, _get_encryption_key())
	if err != OK:
		AppLogger.error("SupabaseClient", "Salvataggio token fallito", {"errore": err})


func _delete_auth_tokens() -> void:
	if FileAccess.file_exists(AUTH_TOKEN_PATH):
		DirAccess.remove_absolute(AUTH_TOKEN_PATH)


# --- Internal: Token Refresh Timer ---


func _setup_refresh_timer() -> void:
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_on_refresh_timer)
	add_child(_refresh_timer)


func _restart_refresh_timer(expires_in: int) -> void:
	var delay := maxf(float(expires_in) - TOKEN_REFRESH_MARGIN, 30.0)
	_refresh_timer.wait_time = delay
	_refresh_timer.start()


func _on_refresh_timer() -> void:
	if _is_authenticated:
		await refresh_session()


# --- Internal: HTTP Pool ---


func _initialize_http_pool() -> void:
	for i in POOL_SIZE:
		var http := HTTPRequest.new()
		http.timeout = REQUEST_TIMEOUT
		add_child(http)
		_http_pool.append(http)


func _get_available_http() -> HTTPRequest:
	for http in _http_pool:
		if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return http

	if _http_pool.size() < MAX_POOL_SIZE:
		var http := HTTPRequest.new()
		http.timeout = REQUEST_TIMEOUT
		add_child(http)
		_http_pool.append(http)
		AppLogger.debug("SupabaseClient", "HTTP pool expanded", {"size": _http_pool.size()})
		return http

	AppLogger.warn("SupabaseClient", "HTTP pool al limite, attesa client libero", {"max": MAX_POOL_SIZE})
	while true:
		await get_tree().process_frame
		for http in _http_pool:
			if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				return http

	return _http_pool[0]


# --- Internal: HTTP Methods ---


func _http_get(url: String, headers: PackedStringArray) -> Variant:
	var http := await _get_available_http()
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		AppLogger.error("SupabaseClient", "GET request failed to start", {"error": err})
		return {"error": "request_start_failed"}
	var response: Array = await http.request_completed
	return _parse_response(response)


func _post(url: String, body: String, headers: PackedStringArray) -> Variant:
	var http := await _get_available_http()
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		AppLogger.error("SupabaseClient", "POST request failed to start", {"error": err})
		return {"error": "request_start_failed"}
	var response: Array = await http.request_completed
	return _parse_response(response)


func _patch(url: String, body: String, headers: PackedStringArray) -> Variant:
	var http := await _get_available_http()
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	if err != OK:
		AppLogger.error("SupabaseClient", "PATCH request failed to start", {"error": err})
		return {"error": "request_start_failed"}
	var response: Array = await http.request_completed
	return _parse_response(response)


func _delete_request(url: String, headers: PackedStringArray) -> Variant:
	var http := await _get_available_http()
	var err := http.request(url, headers, HTTPClient.METHOD_DELETE)
	if err != OK:
		AppLogger.error("SupabaseClient", "DELETE request failed to start", {"error": err})
		return {"error": "request_start_failed"}
	var response: Array = await http.request_completed
	return _parse_response(response)


# --- Internal: Response Parsing ---


func _parse_response(response: Array) -> Variant:
	var result: int = response[0]
	var response_code: int = response[1]
	var headers: PackedStringArray = response[2]
	var body: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		(
			AppLogger
			. error(
				"SupabaseClient",
				"HTTP request failed",
				{
					"result_code": result,
				}
			)
		)
		return {"error": "request_failed", "result_code": result}

	var body_text := body.get_string_from_utf8()
	if body_text.is_empty():
		return {}

	var json := JSON.new()
	if json.parse(body_text) != OK:
		(
			AppLogger
			. error(
				"SupabaseClient",
				"JSON parse error",
				{
					"body_preview": body_text.left(200),
				}
			)
		)
		return {"error": "parse_failed"}

	if response_code >= 400:
		(
			AppLogger
			. warn(
				"SupabaseClient",
				"HTTP error response",
				{
					"status": response_code,
					"body_preview": body_text.left(200),
				}
			)
		)

	return json.data


func _parse_array_result(result: Variant) -> Dictionary:
	if result is Array and result.size() > 0 and result[0] is Dictionary:
		return result[0]
	return {}


# --- Internal: Headers ---


func _anon_headers() -> PackedStringArray:
	return PackedStringArray(
		[
			"Content-Type: application/json",
			"apikey: %s" % _anon_key,
		]
	)


func _bearer_headers() -> PackedStringArray:
	var token := _access_token if _is_authenticated else _anon_key
	return PackedStringArray(
		[
			"Content-Type: application/json",
			"apikey: %s" % _anon_key,
			"Authorization: Bearer %s" % token,
		]
	)


func _offline_error() -> Dictionary:
	return {"error": "offline", "message": "Supabase not configured or not authenticated"}
