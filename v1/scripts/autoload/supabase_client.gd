# gdlint: disable=max-file-lines
## SupabaseClient — Cloud sync via Supabase REST API.
## Offline-first: all operations degrade gracefully when network is unavailable.
## Elia is actively evolving the Supabase schema — this client handles missing
## tables and columns without crashing while
## Constants.SUPABASE_ALLOW_MISSING_TABLES stays true.
##
## TODO B-033 post-demo: split auth + sync + session persistence in moduli
## dedicati per rientrare sotto 500 righe.
extends Node

enum ConnectionState { OFFLINE, CONNECTING, ONLINE, ERROR }

const ConfigScript := preload("res://scripts/utils/supabase_config.gd")
const HttpScript := preload("res://scripts/utils/supabase_http.gd")
const MapperScript := preload("res://scripts/utils/supabase_mapper.gd")
const AUTH_ENDPOINT := "/auth/v1"
const REST_ENDPOINT := "/rest/v1"
const SESSION_PATH := "user://supabase_session.cfg"
# Phase D watchdog: hard ceiling for one sync cycle (queue + push + 401 replay).
const SYNC_WATCHDOG_TIMEOUT_S := 30.0
# Phase D: per-cycle queue dispatch cap. Keeps one cycle's wire load far below
# SupabaseHttp.MAX_QUEUE_SIZE (500, where the oldest request gets dropped) and
# completable within the 30 s watchdog on a slow link; remaining rows stay in
# sync_queue for the next cycle.
const MAX_QUEUE_DISPATCH_PER_CYCLE := 50
# B-021 exponential backoff on HTTP 429. Max cap 5 min (300_000 ms).
const _BACKOFF_MAX_MS: int = 300_000
# 2^9 * 1000 ms = 512 s already exceeds _BACKOFF_MAX_MS; clamping the exponent
# here keeps pow() inside int64 (attempt >= 54 overflowed to a negative delay
# that silently disabled the backoff window — Phase D fix).
const _BACKOFF_MAX_EXPONENT: int = 9
# Marker on a dispatched request whose 2xx must trigger the parked
# room_decorations upserts (delete-then-insert serialization, Phase D).
const _FOLLOWUP_DECO_UPSERTS := "deco_upserts"
# JWT refresh safety skew: refresh when the token is within 60 s of expiry.
const _JWT_REFRESH_SKEW_MS: int = 60_000
# Salt per derivare chiave di cifratura dal percorso user data dir.
# Stesso device → stessa chiave. Altro device → non riesce a decifrare.
# Raddrizza il pattern plaintext su disco (fix B-019: token encryption).
# Nota: non protegge da attacker che legge memoria del processo, ma blocca
# grep banale + copia del .cfg su altro PC.
const _SESSION_SALT := "relax-room-2026-session-v1"

var connection_state: int = ConnectionState.OFFLINE
var supabase_user_id: String = ""
var _jwt_token: String = ""
var _refresh_token: String = ""
# Monotonic JWT deadline in Time.get_ticks_msec() units, anchored at response
# receipt: wall-clock jumps (NTP, DST, manual set) can neither force premature
# refreshes nor mask real expiry (audit 4.1.1-L181).
var _jwt_expires_at_ms: int = 0
var _config: Dictionary = {}
var _http = null
var _sync_timer: Timer = null
var _watchdog_timer: Timer = null
var _is_syncing: bool = false
# Keyed by the rid RETURNED from the wire helpers (audit 4.1.1-L501).
# rid -> {kind: "queue"|"push", queue_id: int, op: "upsert"|"delete"|"fetch",
#         table: String, query: String, body: Variant, replayed: bool}
var _pending_requests: Dictionary = {}
# Phase D: accounting for wire requests still live when their sync cycle was
# force-finished (watchdog / auth abort). rid -> info, drained as the late
# responses arrive so a straggler 2xx still clears its sync_queue row.
var _stale_requests: Dictionary = {}
# Requests that hit 401 mid-sync, parked for a single replay after refresh.
var _retry_buffer: Array[Dictionary] = []
# room_decorations upserts parked until the preceding DELETE commits (Phase D).
var _pending_deco_upserts: Array = []
var _failed_items: int = 0
var _request_counter: int = 0
var _backoff_until_ms: int = 0
var _retry_attempts: int = 0
# Phase D: Supabase rotates refresh tokens — at most ONE refresh POST may be
# in flight; concurrent refreshes invalidate each other's tokens.
var _refresh_in_flight: bool = false


func _ready() -> void:
	_config = ConfigScript.load_config()
	if not _config.get("valid", false):
		AppLogger.info("SupabaseClient", "No valid Supabase config, cloud sync disabled")
		# Route through the central setter (audit 4.8.2). The declared initial
		# state is already OFFLINE, so this is a same-state no-op today; it
		# guards the invalid-config path should the default ever change.
		_set_connection_state(ConnectionState.OFFLINE)
		return
	_http = HttpScript.new()
	_http.initialize(self)
	_http.request_completed.connect(_on_request_completed)
	_setup_sync_timer()
	_setup_watchdog_timer()
	_try_restore_session()
	(
		AppLogger
		. info(
			"SupabaseClient",
			"Initialized",
			{
				"url": _config["url"].left(40),
			}
		)
	)


# ---- Configuration ----


func is_configured() -> bool:
	return _config.get("valid", false)


func is_online() -> bool:
	return connection_state == ConnectionState.ONLINE


## Central connection-state mutator (audit 4.8.2): every transition flows
## through here so cloud_connection_changed fires exactly once per REAL state
## change and same-state writes never re-emit.
func _set_connection_state(new_state: int) -> void:
	assert(new_state in ConnectionState.values(), "invalid ConnectionState")
	if new_state == connection_state:
		return
	connection_state = new_state
	SignalBus.cloud_connection_changed.emit(new_state)


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
	if _refresh_in_flight:
		# One refresh at a time (Phase D): _ensure_jwt runs once per dispatched
		# request, so a sync starting near token expiry would otherwise POST
		# 6+N concurrent refreshes all carrying the SAME rotating refresh
		# token — GoTrue rotates on the first and rejects the siblings.
		return
	if _refresh_token.is_empty():
		# No refresh token: a silent no-op would strand observers and loop
		# expired sessions through 401s (audit 4.1.1-L107). Drop the stale
		# JWT, surface OFFLINE, and fail any buffered replays.
		_jwt_token = ""
		_set_connection_state(ConnectionState.OFFLINE)
		_fail_retry_buffer("refresh_unavailable")
		return
	_refresh_in_flight = true
	var url := _base_url() + AUTH_ENDPOINT + "/token?grant_type=refresh_token"
	var body := JSON.stringify({"refresh_token": _refresh_token})
	var rid := _next_rid("auth_refresh")
	_http.request(url, HTTPClient.METHOD_POST, _auth_headers(), body, rid)


func sign_out_cloud() -> void:
	_jwt_token = ""
	_refresh_token = ""
	_jwt_expires_at_ms = 0
	supabase_user_id = ""
	_set_connection_state(ConnectionState.OFFLINE)
	_save_session()
	AppLogger.info("SupabaseClient", "Signed out from cloud")


# ---- Session Persistence ----


## Derive una chiave di cifratura dal percorso user data dir + salt costante.
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
				"SupabaseClient", "session_loaded_legacy_plaintext", {"action": "migrating_to_encrypted_on_next_save"}
			)
		else:
			return
	_jwt_token = cfg.get_value("session", "jwt", "")
	_refresh_token = cfg.get_value("session", "refresh_token", "")
	# On disk the expiry is a wall-clock estimate (the only representation
	# meaningful across restarts); convert the remaining lifetime back to the
	# monotonic anchor used at runtime (audit 4.1.1-L181).
	var stored_expires_at: float = cfg.get_value("session", "expires_at", 0.0)
	var remaining_s := stored_expires_at - Time.get_unix_time_from_system()
	_jwt_expires_at_ms = Time.get_ticks_msec() + int(maxf(remaining_s, 0.0) * 1000.0)
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
	# Persist a wall-clock estimate derived from the monotonic deadline: raw
	# ticks are process-relative and meaningless in a future run.
	var remaining_ms := _jwt_expires_at_ms - Time.get_ticks_msec()
	var expires_at_wall := Time.get_unix_time_from_system() + float(maxi(remaining_ms, 0)) / 1000.0
	cfg.set_value("session", "expires_at", expires_at_wall)
	cfg.set_value("session", "user_id", supabase_user_id)
	cfg.set_value("session", "local_account_id", AuthManager.current_account_id)
	# Salvataggio cifrato (fix B-019). Chiave derivata dal device user dir +
	# salt costante. Godot 4.5 nativo: ConfigFile.save_encrypted_pass.
	var pass_key := _derive_session_key()
	var err := cfg.save_encrypted_pass(SESSION_PATH, pass_key)
	if err == OK:
		return
	AppLogger.error("SupabaseClient", "session_save_encrypted_failed", {"err": err, "fallback": "plaintext"})
	# The plaintext fallback intentionally drops the refresh token: writing
	# it unencrypted would defeat B-019. Documented downgrade: the restored
	# session survives only until the JWT expires (process-lifetime session),
	# after which the user re-authenticates (audit 4.1.1-L161).
	cfg.set_value("session", "refresh_token", "")
	var fallback_err := cfg.save(SESSION_PATH)
	if fallback_err != OK:
		# Both persistence paths failed: keep the session in memory only.
		AppLogger.error("SupabaseClient", "session_persist_double_failure", {"err": fallback_err})


func _apply_auth_response(data: Dictionary) -> void:
	_jwt_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", _refresh_token)
	var expires_in: int = data.get("expires_in", 3600)
	# Monotonic anchor captured at response receipt (audit 4.1.1-L181).
	_jwt_expires_at_ms = Time.get_ticks_msec() + expires_in * 1000
	var user: Dictionary = data.get("user", {})
	supabase_user_id = user.get("id", data.get("id", ""))
	if not _jwt_token.is_empty() and not supabase_user_id.is_empty():
		_set_connection_state(ConnectionState.ONLINE)
		_save_session()
		SignalBus.cloud_auth_completed.emit(true)
		(
			AppLogger
			. info(
				"SupabaseClient",
				"Authenticated",
				{
					"user_id": supabase_user_id.left(8) + "...",
				}
			)
		)
		_replay_buffered_requests()
	else:
		_set_connection_state(ConnectionState.ERROR)
		SignalBus.cloud_auth_completed.emit(false)
		_fail_retry_buffer("auth_invalid_response")


# ---- REST Operations ----


func fetch_table(table: String, query: String = "") -> String:
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table
	if not query.is_empty():
		url += "?" + query
	var rid := _next_rid("fetch_" + table)
	var headers := _bearer_headers()
	# Cloud-side correlation of client requests in Supabase logs (audit 4.9.2).
	headers.append("x-client-request-id: " + rid)
	_http.request(url, HTTPClient.METHOD_GET, headers, "", rid)
	return rid


func upsert_to_table(table: String, data: Variant) -> String:
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table
	var headers := _bearer_headers()
	headers.append("Prefer: resolution=merge-duplicates")
	var body := JSON.stringify(data)
	var rid := _next_rid("upsert_" + table)
	headers.append("x-client-request-id: " + rid)
	_http.request(url, HTTPClient.METHOD_POST, headers, body, rid)
	return rid


func delete_from_table(table: String, query: String) -> String:
	if query.ends_with("=eq."):
		# V-078 defense-in-depth: an empty eq value ("id=eq.") no longer scopes
		# the filter to one row. Refuse rather than risk a mass delete.
		AppLogger.error("SupabaseClient", "refusing_unscoped_delete", {"table": table})
		return ""
	if not _ensure_jwt():
		return ""
	var url := _base_url() + REST_ENDPOINT + "/" + table + "?" + query
	var rid := _next_rid("delete_" + table)
	var headers := _bearer_headers()
	headers.append("x-client-request-id: " + rid)
	_http.request(url, HTTPClient.METHOD_DELETE, headers, "", rid)
	return rid


func _ensure_jwt() -> bool:
	if not is_configured():
		return false
	if _jwt_token.is_empty():
		return false
	# Refresh when inside the safety skew of the monotonic deadline (4.1.1-L181)
	if Time.get_ticks_msec() > _jwt_expires_at_ms - _JWT_REFRESH_SKEW_MS:
		refresh_jwt()
	return true


# ---- Headers ----


func _auth_headers() -> PackedStringArray:
	return PackedStringArray(
		[
			"apikey: " + _anon_key(),
			"Content-Type: application/json",
		]
	)


func _bearer_headers() -> PackedStringArray:
	return PackedStringArray(
		[
			"apikey: " + _anon_key(),
			"Authorization: Bearer " + _jwt_token,
			"Content-Type: application/json",
		]
	)


# ---- Response Router ----


func _on_request_completed(response: Dictionary) -> void:
	var rid: String = response.get("request_id", "")
	var status: int = response.get("status", 0)
	var body: Variant = response.get("body", null)

	# Auth responses
	if rid.begins_with("auth_"):
		_handle_auth_response(rid, status, body)
		return

	# Table operations — routed on the wire-helper rid prefixes.
	if _is_table_rid(rid):
		# Deferred routing (audit 4.8.4): a synthetic emit arriving
		# synchronously inside _process_sync_queue must never mutate
		# _pending_requests while the dispatch loop is registering rids.
		call_deferred("_handle_sync_response", rid, status, body)
		return

	AppLogger.warn("SupabaseClient", "Unroutable response", {"rid": rid, "status": status})


func _is_table_rid(rid: String) -> bool:
	return rid.begins_with("upsert_") or rid.begins_with("delete_") or rid.begins_with("fetch_")


func _handle_auth_response(
	rid: String,
	status: int,
	body: Variant,
) -> void:
	# The refresh gate opens on ANY terminal outcome for the refresh request:
	# SupabaseHttp guarantees exactly one completion per request, so the flag
	# can never leak set (Phase D).
	if rid.begins_with("auth_refresh"):
		_refresh_in_flight = false
	if status >= 200 and status < 300 and body is Dictionary:
		_apply_auth_response(body)
	else:
		var msg: String = ""
		if body is Dictionary:
			msg = body.get("error_description", body.get("msg", "Auth failed"))
		else:
			msg = "Auth failed (HTTP %d)" % status
		(
			AppLogger
			. error(
				"SupabaseClient",
				"Auth error",
				{
					"rid": rid,
					"status": status,
					"msg": msg,
				}
			)
		)
		if rid.contains("refresh"):
			# Refresh failed — session expired
			_set_connection_state(ConnectionState.OFFLINE)
			_fail_retry_buffer("refresh_failed")
		else:
			SignalBus.cloud_auth_completed.emit(false)
			SignalBus.auth_error.emit(msg)


func _handle_sync_response(
	rid: String,
	status: int,
	body: Variant,
) -> void:
	if not _pending_requests.has(rid):
		# Response for a cycle that was already force-finished (Phase D):
		# settle it via the straggler map, never against the current cycle.
		_handle_stale_sync_response(rid, status)
		return
	var info: Dictionary = _pending_requests[rid]
	_pending_requests.erase(rid)
	if status >= 200 and status < 300:
		_retry_attempts = 0
		_backoff_until_ms = 0
		if info.get("kind", "") == "queue":
			var queue_id := int(info.get("queue_id", -1))
			if queue_id > 0:
				LocalDatabase.clear_sync_item(queue_id)
		if str(info.get("followup", "")) == _FOLLOWUP_DECO_UPSERTS:
			# The room_decorations DELETE has committed server-side: only now
			# is it safe to send the replacement upserts (Phase D — on the
			# 3-slot pool the DELETE raced its own upserts and wiped them).
			_dispatch_deco_upserts()
	elif status == 401:
		_buffer_for_replay(rid, info)
	elif status == 0:
		AppLogger.warn("SupabaseClient", "Network failure", {"rid": rid})
		_set_connection_state(ConnectionState.OFFLINE)
		# Transient outcome: never consumes the poison-payload retry budget.
		_count_item_failed(info, false)
	elif status == 404 or (status == 400 and _is_relation_error(body)):
		_handle_missing_table(rid, info)
	elif status == 429:
		_apply_rate_limit_backoff(rid)
		# Transient outcome: the backoff window already throttles retries.
		_count_item_failed(info, false)
	else:
		AppLogger.warn("SupabaseClient", "Sync request failed", {"rid": rid, "status": status})
		_count_item_failed(info)
	_check_sync_finished()


## Settles a response that arrived after its sync cycle was force-finished
## (watchdog timeout or auth-failure abort). Terminal accounting only: a late
## 2xx must still clear its sync_queue row — otherwise the row re-dispatches
## every cycle as a duplicate upsert. Deliberately never touches _failed_items
## or _check_sync_finished (cross-cycle contamination), and never dispatches
## followups (the cycle that parked them is over).
func _handle_stale_sync_response(rid: String, status: int) -> void:
	if not _stale_requests.has(rid):
		AppLogger.warn("SupabaseClient", "Untracked sync response", {"rid": rid, "status": status})
		return
	var info: Dictionary = _stale_requests[rid]
	_stale_requests.erase(rid)
	if status >= 200 and status < 300:
		if info.get("kind", "") == "queue":
			var queue_id := int(info.get("queue_id", -1))
			if queue_id > 0:
				LocalDatabase.clear_sync_item(queue_id)
		return
	# Late failures need no retry accounting: the row is still in sync_queue
	# and the next cycle's own dispatch handles genuine rejections.
	AppLogger.warn("SupabaseClient", "Straggler settled after sync finish", {"rid": rid, "status": status})


## 401 mid-sync: park the request for a single replay after the JWT refresh
## (audit 4.1.1-L297). A second 401 for the same logical request fails it.
func _buffer_for_replay(rid: String, info: Dictionary) -> void:
	if info.is_empty() or info.get("replayed", false):
		AppLogger.warn("SupabaseClient", "Unauthorized after replay, item failed", {"rid": rid})
		# Auth failure, not a poison payload: keep the retry budget intact.
		_count_item_failed(info, false)
		return
	AppLogger.warn("SupabaseClient", "JWT rejected, buffering request for replay", {"rid": rid})
	info["replayed"] = true
	_retry_buffer.append(info)
	# Only the first buffered request triggers the refresh: Supabase rotates
	# refresh tokens, so concurrent refresh calls would invalidate each other.
	if _retry_buffer.size() == 1:
		refresh_jwt()


func _replay_buffered_requests() -> void:
	if _retry_buffer.is_empty():
		return
	var buffered := _retry_buffer.duplicate()
	_retry_buffer.clear()
	AppLogger.info("SupabaseClient", "Replaying buffered requests", {"count": buffered.size()})
	for info: Dictionary in buffered:
		_dispatch_tracked(info)
	_check_sync_finished()


func _fail_retry_buffer(reason: String) -> void:
	if _retry_buffer.is_empty():
		return
	(
		AppLogger
		. error(
			"SupabaseClient",
			"JWT refresh failed, failing buffered requests",
			{
				"count": _retry_buffer.size(),
				"reason": reason,
			}
		)
	)
	for info: Dictionary in _retry_buffer:
		# Auth infrastructure failure, not a poison payload (Phase D).
		_count_item_failed(info, false)
	_retry_buffer.clear()
	SignalBus.sync_error.emit("auth", reason)
	if _is_syncing:
		_finish_sync(false)


func _handle_missing_table(rid: String, info: Dictionary) -> void:
	var table := str(info.get("table", ""))
	if Constants.SUPABASE_ALLOW_MISSING_TABLES:
		# Elia is still evolving the cloud schema — tolerate and skip. Queue
		# rows stay put and are retried on later cycles (audit 4.1.1-L300).
		AppLogger.warn("SupabaseClient", "Table not found, skipping", {"rid": rid, "table": table})
		return
	AppLogger.error("SupabaseClient", "Table missing on cloud schema", {"rid": rid, "table": table})
	SignalBus.sync_error.emit(table, "missing_table")
	_count_item_failed(info)


func _apply_rate_limit_backoff(rid: String) -> void:
	# B-021: exponential backoff invece di ritentare al prossimo tick.
	# delay = min(2^attempts * 1000, 300_000). Reset a 0 su 2xx.
	_retry_attempts += 1
	var delay_ms: int = _BACKOFF_MAX_MS
	if _retry_attempts < _BACKOFF_MAX_EXPONENT:
		delay_ms = mini(int(pow(2, _retry_attempts) * 1000), _BACKOFF_MAX_MS)
	_backoff_until_ms = Time.get_ticks_msec() + delay_ms
	AppLogger.warn(
		"SupabaseClient",
		"Rate limited, backoff applied",
		{"rid": rid, "delay_ms": delay_ms, "attempt": _retry_attempts}
	)


## Counts a failed item for the cycle result. `consume_retry` must be false
## for transient outcomes (network down, 429, auth infrastructure failures):
## sync_queue.retry_count is a poison-payload budget, and letting ~6 flaky
## cycles quarantine perfectly healthy rows to the dead-letter table silently
## lost user data (Phase D fix).
func _count_item_failed(info: Dictionary, consume_retry: bool = true) -> void:
	_failed_items += 1
	if not consume_retry:
		return
	if info.get("kind", "") == "queue":
		var queue_id := int(info.get("queue_id", -1))
		if queue_id > 0:
			LocalDatabase.increment_retry(queue_id)


func _is_relation_error(body: Variant) -> bool:
	if body is Dictionary:
		if body.has("code"):
			# PostgreSQL undefined_table error code — authoritative over any
			# message-text heuristic (audit 4.1.1-L389).
			return str(body["code"]) == "42P01"
		var msg: String = body.get("message", "")
		return "relation" in msg and "does not exist" in msg
	return false


# ---- Sync Engine ----


func start_sync() -> void:
	if _is_syncing:
		return
	if not is_online():
		return
	_is_syncing = true
	_pending_requests.clear()
	_retry_buffer.clear()
	_failed_items = 0
	SignalBus.sync_started.emit()
	AppLogger.info("SupabaseClient", "Sync started")
	if _watchdog_timer != null:
		_watchdog_timer.start()
	_process_sync_queue()
	_push_local_state()
	_check_sync_finished()


func _process_sync_queue() -> void:
	var pending := LocalDatabase.get_pending_sync()
	var dispatched := 0
	for item in pending:
		if dispatched >= MAX_QUEUE_DISPATCH_PER_CYCLE:
			# Cap the per-cycle wire load (Phase D): a long-offline backlog
			# dispatched in one loop overflowed the HTTP queue (B-025 drop
			# path) and could never finish inside the watchdog window. The
			# remaining rows stay queued for the next cycle.
			(
				AppLogger
				. info(
					"SupabaseClient",
					"Queue dispatch capped for this cycle",
					{
						"dispatched": dispatched,
						"remaining": pending.size() - dispatched,
					}
				)
			)
			break
		var queue_id := int(item.get("queue_id", -1))
		var table_name: String = item.get("table_name", "")
		var payload_str: String = item.get("payload", "{}")
		if int(item.get("retry_count", 0)) > Constants.SUPABASE_MAX_RETRY:
			_quarantine_sync_item(queue_id, table_name, payload_str, "retry_exhausted")
			continue
		var json := JSON.new()
		if json.parse(payload_str) != OK:
			_quarantine_sync_item(queue_id, table_name, payload_str, "parse_failed")
			continue
		var payload: Variant = json.data
		if item.get("operation", "") == "DELETE":
			var row_id := str(payload.get("id", "")) if payload is Dictionary else ""
			_dispatch_sync_request("queue", queue_id, "delete", table_name, "id=eq." + row_id, null)
		else:
			_dispatch_sync_request("queue", queue_id, "upsert", table_name, "", payload)
		dispatched += 1


## Corrupt or retry-exhausted payloads are never plain-deleted: they move to
## sync_dead_letter for offline inspection (audit 4.1.1-L422).
func _quarantine_sync_item(queue_id: int, table_name: String, payload_str: String, reason: String) -> void:
	var preview := payload_str.left(32)
	(
		AppLogger
		. warn(
			"SupabaseClient",
			"Sync payload quarantined",
			{
				"queue_id": queue_id,
				"table": table_name,
				"payload_len": payload_str.length(),
				"head": preview,
				"reason": reason,
			}
		)
	)
	SignalBus.sync_payload_corrupted.emit(queue_id, preview)
	if not LocalDatabase.move_sync_item_to_dead_letter(queue_id, reason):
		AppLogger.error("SupabaseClient", "Dead-letter move failed, row left queued", {"queue_id": queue_id})


func _push_local_state() -> void:
	if supabase_user_id.is_empty():
		_finish_sync(false)
		return
	var account := LocalDatabase.get_account(AuthManager.current_account_id)
	var character := LocalDatabase.get_character(AuthManager.current_account_id)
	if not account.is_empty():
		var profile: Dictionary = MapperScript.profile_to_cloud(account, character, supabase_user_id)
		_dispatch_sync_request("push", -1, "upsert", "profiles", "", profile)
		var currency: Dictionary = MapperScript.currency_to_cloud(account, supabase_user_id)
		_dispatch_sync_request("push", -1, "upsert", "user_currency", "", currency)
	_dispatch_sync_request("push", -1, "upsert", "user_settings", "", _collect_cloud_settings())
	var music: Dictionary = SaveManager.get_music_state()
	var cloud_music: Dictionary = MapperScript.music_to_cloud(music, supabase_user_id)
	_dispatch_sync_request("push", -1, "upsert", "music_preferences", "", cloud_music)
	var decos: Array = SaveManager.get_decorations()
	if not decos.is_empty():
		# Serialize DELETE -> upserts (Phase D): the pool runs 3 requests in
		# parallel, so dispatching the delete and the replacement upserts
		# back-to-back let PostgREST commit an upsert BEFORE the delete
		# executed — wiping the freshly inserted row. The upserts are parked
		# here and dispatched only from the DELETE's 2xx handler.
		_pending_deco_upserts = MapperScript.decorations_to_cloud(decos, supabase_user_id)
		var del_query := "user_id=eq." + supabase_user_id
		_dispatch_sync_request("push", -1, "delete", "room_decorations", del_query, null, _FOLLOWUP_DECO_UPSERTS)


func _collect_cloud_settings() -> Dictionary:
	var settings_data: Dictionary = {
		"language": SaveManager.get_setting("language", "en"),
		"display_mode": SaveManager.get_setting("display_mode", "windowed"),
		"master_volume": SaveManager.get_setting("master_volume", 0.8),
		"music_volume": SaveManager.get_setting("music_volume", 0.6),
		"ambience_volume": SaveManager.get_setting("ambience_volume", 0.4),
	}
	return MapperScript.settings_to_cloud(settings_data, supabase_user_id)


func _dispatch_sync_request(
	kind: String,
	queue_id: int,
	op: String,
	table: String,
	query: String,
	body: Variant,
	followup: String = "",
) -> void:
	var info := {
		"kind": kind,
		"queue_id": queue_id,
		"op": op,
		"table": table,
		"query": query,
		"body": body,
		"replayed": false,
		"followup": followup,
	}
	_dispatch_tracked(info)


## Dispatches the room_decorations upserts parked by _push_local_state once
## the preceding DELETE has committed server-side (Phase D serialization).
func _dispatch_deco_upserts() -> void:
	var decos := _pending_deco_upserts
	_pending_deco_upserts = []
	for deco: Dictionary in decos:
		_dispatch_sync_request("push", -1, "upsert", "room_decorations", "", deco)


## Sends the wire request and tracks the RETURNED rid (audit 4.1.1-L501):
## the rid produced by the wire helper is the only key responses match on.
func _dispatch_tracked(info: Dictionary) -> void:
	var rid := ""
	match str(info.get("op", "")):
		"upsert":
			rid = upsert_to_table(str(info.get("table", "")), info.get("body"))
		"delete":
			rid = delete_from_table(str(info.get("table", "")), str(info.get("query", "")))
		"fetch":
			rid = fetch_table(str(info.get("table", "")), str(info.get("query", "")))
	if rid.is_empty():
		# Not-ready sentinel from the wire helper (audit 4.1.1-L208): count
		# the item as failed immediately — never park it in the pending map.
		# Not-ready is transient (no JWT yet / offline): no retry consumed.
		_count_item_failed(info, false)
		return
	_pending_requests[rid] = info


func _check_sync_finished() -> void:
	if not _is_syncing:
		return
	if _pending_requests.is_empty() and _retry_buffer.is_empty():
		_finish_sync(_failed_items == 0)


func _finish_sync(success: bool) -> void:
	_is_syncing = false
	# Requests still on the wire when a watchdog/auth abort finishes the cycle
	# keep their accounting in _stale_requests (Phase D): their late responses
	# settle through _handle_stale_sync_response, so a straggler 2xx still
	# clears its sync_queue row instead of re-upserting forever.
	_stale_requests.merge(_pending_requests, true)
	_pending_requests.clear()
	_retry_buffer.clear()
	_pending_deco_upserts = []
	if _watchdog_timer != null:
		_watchdog_timer.stop()
	SignalBus.sync_completed.emit(success)
	AppLogger.info("SupabaseClient", "Sync completed", {"success": success, "failed_items": _failed_items})


# ---- Timers ----


func _setup_sync_timer() -> void:
	_sync_timer = Timer.new()
	_sync_timer.wait_time = Constants.SUPABASE_SYNC_INTERVAL
	_sync_timer.autostart = false
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)
	# Phase D: the timer was created but never started, so neither periodic
	# sync nor OFFLINE recovery could ever run. Ticking while logged out is a
	# cheap no-op (_on_sync_timer early-returns without a refresh token).
	_sync_timer.start()


func _setup_watchdog_timer() -> void:
	_watchdog_timer = Timer.new()
	_watchdog_timer.wait_time = SYNC_WATCHDOG_TIMEOUT_S
	_watchdog_timer.one_shot = true
	_watchdog_timer.autostart = false
	_watchdog_timer.timeout.connect(_on_sync_watchdog_timeout)
	add_child(_watchdog_timer)


func _on_sync_timer() -> void:
	# B-021: skip sync se in backoff window dopo HTTP 429
	if Time.get_ticks_msec() < _backoff_until_ms:
		return
	if is_online():
		if not _is_syncing:
			start_sync()
		return
	# OFFLINE -> ONLINE recovery (Phase D): a transient network blip flips the
	# state to OFFLINE and nothing else ever restores ONLINE, silently killing
	# cloud sync for the rest of the session. With a refresh token available,
	# retry the JWT refresh (single-flight via _refresh_in_flight); a success
	# restores ONLINE through _apply_auth_response and the next tick syncs.
	if connection_state == ConnectionState.OFFLINE and not _refresh_token.is_empty():
		refresh_jwt()


func _on_sync_watchdog_timeout() -> void:
	if not _is_syncing:
		return
	(
		AppLogger
		. error(
			"SupabaseClient",
			"Sync watchdog expired",
			{
				"pending": _pending_requests.size(),
				"buffered": _retry_buffer.size(),
			}
		)
	)
	SignalBus.sync_error.emit("watchdog", "sync timed out")
	_finish_sync(false)


# ---- Helpers ----


func _next_rid(prefix: String) -> String:
	_request_counter += 1
	return "%s_%d" % [prefix, _request_counter]


# ---- Lifecycle ----


func _exit_tree() -> void:
	if _sync_timer and _sync_timer.timeout.is_connected(_on_sync_timer):
		_sync_timer.timeout.disconnect(_on_sync_timer)
	if _watchdog_timer and _watchdog_timer.timeout.is_connected(_on_sync_watchdog_timeout):
		_watchdog_timer.timeout.disconnect(_on_sync_watchdog_timeout)
	if _http:
		_http.request_completed.disconnect(_on_request_completed)
		_http.cleanup()
	_save_session()
