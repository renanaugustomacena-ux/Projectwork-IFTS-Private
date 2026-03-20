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

var _session_id: String = ""
var _log_file: FileAccess = null
var _log_file_path: String = ""
var _min_level: Level = Level.DEBUG
var _log_buffer: Array[String] = []
var _flush_timer: Timer
var _current_file_size: int = 0


func _ready() -> void:
	_session_id = _generate_session_id()
	_ensure_log_directory()
	_open_log_file()
	_setup_flush_timer()
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
		entry["context"] = context

	var json_line := JSON.stringify(entry)
	_log_buffer.append(json_line)

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
	if _log_buffer.is_empty():
		return

	if _log_file == null:
		_open_log_file()
	if _log_file == null:
		# Cannot write — clear buffer to prevent unbounded growth
		push_warning("Logger: cleared %d buffered entries (log file unavailable)" % _log_buffer.size())
		_log_buffer.clear()
		return

	for line in _log_buffer:
		_log_file.store_line(line)
		_current_file_size += line.length() + 1  # +1 for newline

	_log_file.flush()
	_log_buffer.clear()
	_check_rotation()


func _check_rotation() -> void:
	if _current_file_size < MAX_LOG_SIZE_BYTES:
		return

	_log_file.close()
	_log_file = null
	_cleanup_old_logs()
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


func _generate_session_id() -> String:
	var unix_time := int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = unix_time ^ OS.get_process_id()
	return (
		"%08x-%04x-%04x"
		% [
			unix_time & 0xFFFFFFFF,
			rng.randi() & 0xFFFF,
			rng.randi() & 0xFFFF,
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
		"session_%04d%02d%02d_%02d%02d%02d.jsonl"
		% [
			dt["year"],
			dt["month"],
			dt["day"],
			dt["hour"],
			dt["minute"],
			dt["second"],
		]
	)
	_log_file_path = LOG_DIR + filename
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
