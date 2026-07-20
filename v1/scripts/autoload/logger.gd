## Logger — Structured logging with correlation IDs, severity levels, and file output.
## Provides real-time debugging information with traceable context across all systems.
##
## Registered as the second autoload (after SignalBus) to be available to all
## subsequent systems. Writes structured JSON Lines to rotating log files
## and simultaneously to the Godot console.
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

const LOG_DIR := "user://logs/"
const MAX_LOG_SIZE_BYTES := 5_242_880  # 5 MB
const MAX_LOG_FILES := 5
const FLUSH_INTERVAL := 2.0  # seconds
const METRICS_FLUSH_INTERVAL := 300.0  # seconds between structured metrics snapshots (4.9.4)
const MAX_SESSION_FILES := 20  # startup retention cap for session .jsonl files in LOG_DIR (G-055)
const MAX_BUFFER_ENTRIES := 2000  # cap memoria: se oltre, drop oldest (fix B-018)
const MAX_ERROR_RING_ENTRIES := 500  # dedicated ERROR retention, never evicted by normal overflow (4.9.5)
const MAX_RETAINED_ON_FLUSH_FAILURE := 100
const REDACT_KEYS := [
	"password", "password_hash", "token", "jwt", "refresh_token", "access_token", "hmac_key", "secret", "anon_key"
]
const REDACTED := "***"

var _session_id: String = ""
var _log_file: FileAccess = null
var _log_file_path: String = ""
var _min_level: Level = Level.DEBUG
var _log_buffer: Array[Dictionary] = []  # entries: {"line": String, "is_error": bool}
var _error_ring: Array[String] = []  # ERROR lines evicted from _log_buffer, pre-marked "late_error"
var _dropped_count: int = 0
var _drop_warned: bool = false
var _file_counter: int = 0  # monotonic suffix: same-second re-opens never truncate earlier files
var _flush_timer: Timer
var _current_file_size: int = 0
var _metrics_timer: Timer
var _metric_counters: Dictionary = {}  # String -> int, cumulative for the session (4.9.4)
var _metric_gauges: Dictionary = {}  # String -> Variant, last-set values included in each snapshot
var _metrics_dirty: bool = false
var _user_data_dir: String = ""  # cached absolute prefix scrubbed from payloads (4.9.3-LOW)


func _ready() -> void:
	_session_id = _generate_session_id()
	_user_data_dir = OS.get_user_data_dir()
	_ensure_log_directory()
	_open_log_file()
	_prune_old_session_files()
	_setup_flush_timer()
	_setup_metrics_timer()
	info(
		"Logger",
		"Session started",
		{
			"session_id": _session_id,
			"engine_version": Engine.get_version_info().get("string", "unknown"),
			"os": OS.get_name(),
		}
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_metrics()
		info("Logger", "Session ended")
		_flush_buffer()
		if _log_file != null:
			_log_file.close()


## Log a DEBUG-level message. Suppressed in production builds.
func debug(source: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.DEBUG, source, message, context)


## Log an INFO-level message.
func info(source: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.INFO, source, message, context)


## Log a WARN-level message. Outputs via push_warning in Godot console.
func warn(source: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.WARN, source, message, context)


## Log an ERROR-level message. Outputs via push_error in Godot console.
func error(source: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.ERROR, source, message, context)


## Returns the current session correlation ID.
func get_session_id() -> String:
	return _session_id


## Increments a named metric counter. Counters accumulate for the session and
## are flushed as one structured INFO line ({"metrics": {...}}) every
## METRICS_FLUSH_INTERVAL seconds and at exit. (4.9.4)
func count_metric(metric_name: String, amount: int = 1) -> void:
	_metric_counters[metric_name] = int(_metric_counters.get(metric_name, 0)) + amount
	_metrics_dirty = true


## Records a named gauge value (last-write-wins), included alongside the
## counters in every metrics snapshot line. (4.9.4)
func set_gauge(metric_name: String, value: Variant) -> void:
	_metric_gauges[metric_name] = value
	_metrics_dirty = true


## Sanitizza chiavi sensibili (password, token, ecc.) nel context prima di
## serializzarlo nel log. Previene accidentale esposizione credenziali in
## log files JSONL che l'utente potrebbe condividere per debugging. (fix B-028)
func _redact_context(context: Dictionary) -> Dictionary:
	var out := {}
	for k in context.keys():
		var key_lower := str(k).to_lower()
		var value: Variant = context[k]
		var is_sensitive := false
		for sensitive in REDACT_KEYS:
			if sensitive in key_lower:
				is_sensitive = true
				break
		if is_sensitive:
			out[k] = REDACTED
		elif value is Dictionary:
			out[k] = _redact_context(value)
		elif value is String:
			out[k] = _redact_device_path(value)
		else:
			out[k] = value
	return out


## Replaces the absolute user-data directory prefix inside String payload
## values with "user://" so shared logs never expose device paths or the OS
## username. (4.9.3-LOW)
func _redact_device_path(value: String) -> String:
	if _user_data_dir.is_empty() or not value.contains(_user_data_dir):
		return value
	return value.replace(_user_data_dir + "/", "user://").replace(_user_data_dir, "user://")


## Set the minimum log level. Messages below this level are discarded.
func set_min_level(level: Level) -> void:
	_min_level = level


## Returns the path to the current log file.
func get_log_file_path() -> String:
	return _log_file_path


func _log(level: Level, source: String, message: String, context: Dictionary) -> void:
	if level < _min_level:
		return

	var level_name := Level.keys()[level] as String
	var timestamp := Time.get_datetime_string_from_system(true)
	var short_id := _session_id.left(8)

	var entry := {
		"timestamp": timestamp,
		"level": level_name,
		"session_id": _session_id,
		"source": source,
		"message": message,
	}
	if not context.is_empty():
		entry["context"] = _redact_context(context)

	var json_line := JSON.stringify(entry)

	# Cap buffer per prevenire OOM se flush fallisce ripetutamente (B-018).
	# At cap, evict the oldest entry: ERROR lines move to the dedicated ring
	# (4.9.5), everything else is counted as dropped (4.1.3-L133).
	if _log_buffer.size() >= MAX_BUFFER_ENTRIES:
		_evict_oldest_entry()
	_log_buffer.append({"line": json_line, "is_error": level == Level.ERROR})

	# Console output with severity-appropriate method
	var console_msg := "[%s][%s] %s: %s" % [level_name, short_id, source, message]
	if not context.is_empty():
		console_msg += " " + str(context)

	match level:
		Level.DEBUG:
			print(console_msg)
		Level.INFO:
			print(console_msg)
		Level.WARN:
			push_warning(console_msg)
		Level.ERROR:
			push_error(console_msg)


func _flush_buffer() -> void:
	if _log_buffer.is_empty() and _error_ring.is_empty() and _dropped_count == 0:
		return

	if _log_file == null:
		_open_log_file()
	if _log_file == null:
		_trim_unflushed_buffer()
		return

	for entry in _log_buffer:
		_write_line(entry["line"] as String)

	# ERROR lines evicted from the main buffer are written out of chronological
	# order; each was already marked with "late_error": true at eviction (4.9.5).
	for line in _error_ring:
		_write_line(line)

	if _dropped_count > 0:
		_write_line(_build_dropped_report_line())
		_dropped_count = 0
		_drop_warned = false

	_log_file.flush()
	_log_buffer.clear()
	_error_ring.clear()
	_check_rotation()


func _write_line(line: String) -> void:
	_log_file.store_line(line)
	_current_file_size += line.length() + 1  # +1 for newline


## Log file unavailable: keep the newest entries (and the ERROR ring intact),
## trim only the oldest mixed entries to avoid unbounded growth.
func _trim_unflushed_buffer() -> void:
	if _log_buffer.size() <= MAX_RETAINED_ON_FLUSH_FAILURE:
		return
	var trim_count := _log_buffer.size() - MAX_RETAINED_ON_FLUSH_FAILURE
	for i in trim_count:
		_evict_oldest_entry()
	push_warning(
		(
			"Logger: trimmed %d old entries, retaining %d (log file unavailable)"
			% [trim_count, MAX_RETAINED_ON_FLUSH_FAILURE]
		)
	)


## Evicts the oldest buffered entry. ERROR entries survive in the dedicated
## ring (normal overflow never discards them); anything else counts as dropped.
func _evict_oldest_entry() -> void:
	var evicted: Dictionary = _log_buffer.pop_front()
	if evicted.get("is_error", false):
		_retain_late_error(evicted["line"] as String)
	else:
		_register_drop()


func _retain_late_error(line: String) -> void:
	if _error_ring.size() >= MAX_ERROR_RING_ENTRIES:
		_error_ring.pop_front()
		_register_drop()
	_error_ring.append(_mark_late_error(line))


func _mark_late_error(line: String) -> String:
	var parsed: Variant = JSON.parse_string(line)
	if parsed is Dictionary:
		parsed["late_error"] = true
		return JSON.stringify(parsed)
	return line


## Counts a genuinely lost entry and warns once per reporting cycle; the exact
## count lands in the log file on the next successful flush (4.1.3-L133).
func _register_drop() -> void:
	_dropped_count += 1
	count_metric("log_entries_dropped")
	if not _drop_warned:
		_drop_warned = true
		push_warning("Logger: buffer full, dropping oldest entries (count reported on next flush)")


func _build_dropped_report_line() -> String:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"level": "WARN",
		"session_id": _session_id,
		"source": "Logger",
		"message": "entries_dropped",
		"context": {"dropped_count": _dropped_count},
	}
	return JSON.stringify(entry)


func _check_rotation() -> void:
	if _current_file_size < MAX_LOG_SIZE_BYTES:
		return

	_log_file.close()
	_log_file = null
	_cleanup_old_logs()
	# Monotonic suffix guarantees a fresh filename even within the same second,
	# so rotation can never truncate the file just closed (4.1.3-L253).
	_file_counter += 1
	_open_log_file()


func _cleanup_old_logs() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return

	var log_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".jsonl") and not dir.current_is_dir():
			log_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	log_files.sort()

	# Keep only MAX_LOG_FILES - 1 (to leave room for the new one)
	while log_files.size() >= MAX_LOG_FILES:
		var oldest := log_files.pop_front() as String
		dir.remove(oldest)


## Startup retention: deletes session .jsonl files beyond the newest
## MAX_SESSION_FILES (by modified time), fixing unbounded one-file-per-boot
## accumulation in user://logs. (G-055)
func _prune_old_session_files() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return

	var entries: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".jsonl") and not dir.current_is_dir():
			entries.append({"name": file_name, "mtime": FileAccess.get_modified_time(LOG_DIR + file_name)})
		file_name = dir.get_next()
	dir.list_dir_end()

	if entries.size() <= MAX_SESSION_FILES:
		return

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["mtime"]) > int(b["mtime"]))
	var deleted_count := 0
	for i in range(MAX_SESSION_FILES, entries.size()):
		var entry_name := entries[i]["name"] as String
		if LOG_DIR + entry_name == _log_file_path:
			continue  # never delete the active session file
		if dir.remove(entry_name) == OK:
			deleted_count += 1
	if deleted_count > 0:
		info("Logger", "Pruned old session logs", {"deleted_count": deleted_count, "retained_max": MAX_SESSION_FILES})


func _generate_session_id() -> String:
	# Combines multiple entropy sources to prevent collisions:
	#   1. Unix time (changes every second)
	#   2. Engine microsecond tick counter (low 16 bits)
	#   3. All 32 cryptographically secure random bits, kept in full (4.1.3-L219)
	var unix_time := int(Time.get_unix_time_from_system())
	var ticks := Time.get_ticks_usec()
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(4)
	var random_int := random_bytes[0] << 24 | random_bytes[1] << 16 | random_bytes[2] << 8 | random_bytes[3]
	return (
		"%08x-%04x-%08x"
		% [
			unix_time & 0xFFFFFFFF,
			ticks & 0xFFFF,
			random_int & 0xFFFFFFFF,
		]
	)


func _ensure_log_directory() -> void:
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		var err := DirAccess.make_dir_recursive_absolute(LOG_DIR)
		if err != OK:
			push_error("Logger: failed to create log directory '%s' (error: %d)" % [LOG_DIR, err])


func _open_log_file() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var filename := (
		"session_%04d%02d%02d_%02d%02d%02d_%03d.jsonl"
		% [
			dt["year"],
			dt["month"],
			dt["day"],
			dt["hour"],
			dt["minute"],
			dt["second"],
			_file_counter,
		]
	)
	_log_file_path = LOG_DIR + filename
	if FileAccess.file_exists(_log_file_path):
		# Re-open of an existing file (retry or same-second restart): append,
		# never truncate prior content (4.1.3-L253).
		_log_file = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
		if _log_file != null:
			_log_file.seek_end()
			_current_file_size = _log_file.get_length()
	else:
		_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
		_current_file_size = 0
	if _log_file == null:
		push_error("Logger: failed to open log file '%s' (error: %s)" % [_log_file_path, FileAccess.get_open_error()])


func _setup_flush_timer() -> void:
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_flush_buffer)
	add_child(_flush_timer)


func _setup_metrics_timer() -> void:
	_metrics_timer = Timer.new()
	_metrics_timer.wait_time = METRICS_FLUSH_INTERVAL
	_metrics_timer.autostart = true
	_metrics_timer.timeout.connect(_flush_metrics)
	add_child(_metrics_timer)


## Emits cumulative counters and current gauges as a single structured INFO
## line. Skipped when nothing changed since the previous snapshot. (4.9.4)
func _flush_metrics() -> void:
	if not _metrics_dirty:
		return
	_metrics_dirty = false
	var snapshot := {}
	snapshot.merge(_metric_gauges)
	snapshot.merge(_metric_counters)
	info("Metrics", "snapshot", {"metrics": snapshot})
