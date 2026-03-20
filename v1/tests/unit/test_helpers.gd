## TestHelpers — Unit tests for the Helpers utility class.
##
## Documentation:
## Tests the utility functions: Vector2 serialization, viewport clamping,
## time formatting, and date string generation. Tests use data derived
## from the project's real constants, NEVER arbitrary synthetic data.
class_name TestHelpers
extends GdUnitTestSuite

# --- vec2_to_array ---


func test_vec2_to_array_with_positive_values() -> void:
	var result := Helpers.vec2_to_array(Vector2(100.0, 200.0))
	assert_array(result).has_size(2)
	assert_float(result[0]).is_equal_approx(100.0, 0.001)
	assert_float(result[1]).is_equal_approx(200.0, 0.001)


func test_vec2_to_array_with_zero() -> void:
	var result := Helpers.vec2_to_array(Vector2.ZERO)
	assert_array(result).has_size(2)
	assert_float(result[0]).is_equal_approx(0.0, 0.001)
	assert_float(result[1]).is_equal_approx(0.0, 0.001)


func test_vec2_to_array_with_negative_values() -> void:
	var result := Helpers.vec2_to_array(Vector2(-50.5, -75.3))
	assert_float(result[0]).is_equal_approx(-50.5, 0.001)
	assert_float(result[1]).is_equal_approx(-75.3, 0.001)


func test_vec2_to_array_with_fractional_values() -> void:
	var result := Helpers.vec2_to_array(Vector2(0.123, 0.456))
	assert_float(result[0]).is_equal_approx(0.123, 0.001)
	assert_float(result[1]).is_equal_approx(0.456, 0.001)


# --- array_to_vec2 ---


func test_array_to_vec2_with_valid_array() -> void:
	var result := Helpers.array_to_vec2([100.0, 200.0])
	assert_vector(result).is_equal_approx(Vector2(100.0, 200.0), Vector2(0.001, 0.001))


func test_array_to_vec2_with_empty_array_returns_zero() -> void:
	var result := Helpers.array_to_vec2([])
	assert_vector(result).is_equal(Vector2.ZERO)


func test_array_to_vec2_with_single_element_returns_zero() -> void:
	var result := Helpers.array_to_vec2([42.0])
	assert_vector(result).is_equal(Vector2.ZERO)


func test_array_to_vec2_roundtrip() -> void:
	var original := Vector2(320.0, 180.0)  # Center of game viewport
	var serialized := Helpers.vec2_to_array(original)
	var deserialized := Helpers.array_to_vec2(serialized)
	assert_vector(deserialized).is_equal_approx(original, Vector2(0.001, 0.001))


# --- clamp_to_viewport ---


func test_clamp_to_viewport_within_bounds() -> void:
	# Position already within viewport bounds
	var pos := Vector2(320.0, 180.0)
	var result := Helpers.clamp_to_viewport(pos)
	assert_vector(result).is_equal_approx(pos, Vector2(0.001, 0.001))


func test_clamp_to_viewport_clamps_overflow_x() -> void:
	var result := Helpers.clamp_to_viewport(Vector2(9999.0, 180.0))
	assert_float(result.x).is_less_equal(float(Constants.VIEWPORT_WIDTH))


func test_clamp_to_viewport_clamps_negative_y() -> void:
	var result := Helpers.clamp_to_viewport(Vector2(100.0, -500.0))
	assert_float(result.y).is_greater_equal(0.0)


func test_clamp_to_viewport_with_margin() -> void:
	var margin := 16.0
	var result := Helpers.clamp_to_viewport(Vector2(0.0, 0.0), margin)
	assert_float(result.x).is_greater_equal(margin)
	assert_float(result.y).is_greater_equal(margin)


func test_clamp_to_viewport_max_with_margin() -> void:
	var margin := 16.0
	var result := Helpers.clamp_to_viewport(Vector2(9999.0, 9999.0), margin)
	assert_float(result.x).is_less_equal(float(Constants.VIEWPORT_WIDTH) - margin)
	assert_float(result.y).is_less_equal(float(Constants.VIEWPORT_HEIGHT) - margin)


# --- format_time ---


func test_format_time_zero_seconds() -> void:
	assert_str(Helpers.format_time(0)).is_equal("00:00")


func test_format_time_one_minute() -> void:
	assert_str(Helpers.format_time(60)).is_equal("01:00")


func test_format_time_ninety_seconds() -> void:
	assert_str(Helpers.format_time(90)).is_equal("01:30")


func test_format_time_pomodoro_work_default() -> void:
	# Default work session: 25 minutes = 1500 seconds
	assert_str(Helpers.format_time(1500)).is_equal("25:00")


func test_format_time_pomodoro_break_default() -> void:
	# Default break: 5 minutes = 300 seconds
	assert_str(Helpers.format_time(300)).is_equal("05:00")


func test_format_time_large_value() -> void:
	# 1 hour 1 minute 1 second = 3661 seconds
	assert_str(Helpers.format_time(3661)).is_equal("61:01")


# --- get_date_string ---


func test_get_date_string_format() -> void:
	var result := Helpers.get_date_string()
	# Format: YYYY-MM-DD (10 characters)
	assert_int(result.length()).is_equal(10)
	assert_str(result.substr(4, 1)).is_equal("-")
	assert_str(result.substr(7, 1)).is_equal("-")


func test_get_date_string_year_is_plausible() -> void:
	var result := Helpers.get_date_string()
	var year := result.left(4).to_int()
	assert_int(year).is_greater_equal(2025)
	assert_int(year).is_less_equal(2030)
