## TestBase — superclasse comune per moduli di test.
##
## Fornisce metodi di asserzione che il runner esterno conteggia.
## Ogni modulo di test extends questa classe e dichiara metodi `test_*`.
extends Node
class_name TestBase

# Variables manipulated by the runner between tests.
# Do NOT rename — runner accesses them via set()/get() reflection.
var _current_test_name: String = ""
var _assertions_in_test: int = 0
var _failures_in_test: Array[String] = []


func assert_true(condition: bool, message: String = "") -> void:
	_assertions_in_test += 1
	if not condition:
		_failures_in_test.append("assert_true failed" + ((": " + message) if message != "" else ""))


func assert_false(condition: bool, message: String = "") -> void:
	_assertions_in_test += 1
	if condition:
		_failures_in_test.append("assert_false failed" + ((": " + message) if message != "" else ""))


func assert_eq(a: Variant, b: Variant, message: String = "") -> void:
	_assertions_in_test += 1
	if a != b:
		var context := (": " + message) if message != "" else ""
		_failures_in_test.append("assert_eq: expected %s got %s%s" % [b, a, context])


func assert_ne(a: Variant, b: Variant, message: String = "") -> void:
	_assertions_in_test += 1
	if a == b:
		_failures_in_test.append("assert_ne: both %s%s" % [a, (": " + message) if message != "" else ""])


func assert_approx(a: float, b: float, epsilon: float = 0.001, message: String = "") -> void:
	_assertions_in_test += 1
	if absf(a - b) > epsilon:
		var context := (": " + message) if message != "" else ""
		_failures_in_test.append("assert_approx: |%f - %f| > %f%s" % [a, b, epsilon, context])


func assert_non_null(value: Variant, message: String = "") -> void:
	_assertions_in_test += 1
	if value == null:
		_failures_in_test.append("assert_non_null: got null" + ((" (" + message + ")") if message != "" else ""))


func assert_null(value: Variant, message: String = "") -> void:
	_assertions_in_test += 1
	if value != null:
		_failures_in_test.append("assert_null: got %s%s" % [value, (" (" + message + ")") if message != "" else ""])


func assert_in_range(value: float, low: float, high: float, message: String = "") -> void:
	_assertions_in_test += 1
	if value < low or value > high:
		var context := (": " + message) if message != "" else ""
		_failures_in_test.append("assert_in_range: %f not in [%f, %f]%s" % [value, low, high, context])


func assert_array_size(arr: Array, expected_size: int, message: String = "") -> void:
	_assertions_in_test += 1
	if arr.size() != expected_size:
		var context := (": " + message) if message != "" else ""
		_failures_in_test.append("assert_array_size: expected %d got %d%s" % [expected_size, arr.size(), context])


func assert_has(dict: Dictionary, key: String, message: String = "") -> void:
	_assertions_in_test += 1
	if not dict.has(key):
		var context := (": " + message) if message != "" else ""
		_failures_in_test.append("assert_has: key %s missing%s" % [key, context])


func fail(message: String) -> void:
	_assertions_in_test += 1
	_failures_in_test.append("explicit fail: " + message)


## Runner calls this before each test_* method to reset per-test state.
## Needed because set() of typed Array[String] to untyped [] silently fails.
func _reset_failures() -> void:
	_failures_in_test.clear()


## Waits N frames. Use in tests that need tree-processing (input, timers).
func wait_frames(n: int = 1) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Waits real wall-clock seconds.
func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
