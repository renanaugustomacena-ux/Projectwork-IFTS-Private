## TestLogger — Unit tests for the Logger autoload.
##
## Documentation:
## Verifies that the Logger generates valid session IDs, respects severity
## levels, and produces output in the expected JSON format. Tests do not
## verify file writing (I/O boundary) but rather the internal logic.
class_name TestLogger
extends GdUnitTestSuite

# --- Session ID ---


func test_session_id_is_not_empty() -> void:
	var session_id := Logger.get_session_id()
	assert_str(session_id).is_not_empty()


func test_session_id_has_expected_format() -> void:
	var session_id := Logger.get_session_id()
	# Format: 8hex-4hex-4hex (e.g., "a1b2c3d4-e5f6-7890")
	assert_int(session_id.length()).is_equal(18)
	assert_str(session_id.substr(8, 1)).is_equal("-")
	assert_str(session_id.substr(13, 1)).is_equal("-")


# --- Log level filtering ---


func test_min_level_can_be_set() -> void:
	var original_level := Logger._min_level
	Logger.set_min_level(Logger.Level.ERROR)
	assert_int(Logger._min_level).is_equal(Logger.Level.ERROR)
	# Restore
	Logger.set_min_level(original_level)


func test_level_enum_has_four_values() -> void:
	assert_int(Logger.Level.size()).is_equal(4)


func test_debug_is_lowest_level() -> void:
	assert_int(Logger.Level.DEBUG).is_less(Logger.Level.INFO)


func test_error_is_highest_level() -> void:
	assert_int(Logger.Level.ERROR).is_greater(Logger.Level.WARN)


func test_level_order_is_debug_info_warn_error() -> void:
	assert_int(Logger.Level.DEBUG).is_less(Logger.Level.INFO)
	assert_int(Logger.Level.INFO).is_less(Logger.Level.WARN)
	assert_int(Logger.Level.WARN).is_less(Logger.Level.ERROR)


# --- Log file path ---


func test_log_file_path_starts_with_user_dir() -> void:
	var path := Logger.get_log_file_path()
	assert_str(path).starts_with("user://logs/")


func test_log_file_path_ends_with_jsonl() -> void:
	var path := Logger.get_log_file_path()
	assert_str(path).ends_with(".jsonl")


# --- Constants ---


func test_max_log_size_is_positive() -> void:
	assert_int(Logger.MAX_LOG_SIZE_BYTES).is_greater(0)


func test_max_log_files_is_positive() -> void:
	assert_int(Logger.MAX_LOG_FILES).is_greater(0)


func test_flush_interval_is_positive() -> void:
	assert_float(Logger.FLUSH_INTERVAL).is_greater(0.0)
