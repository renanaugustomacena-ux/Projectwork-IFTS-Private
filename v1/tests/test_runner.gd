## Test Runner — headless Godot test harness.
##
## Carica ogni test module in `tests/integration/`, invoca tutti i metodi che
## iniziano con `test_`, aggrega risultati PASS/FAIL, scrive JSONL in
## `user://test_results.jsonl`, esce con code 0 (all pass) o 1 (>= 1 fail).
##
## Ogni test module extends `TestBase` (vedi test_base.gd) e usa
## `assert_true`, `assert_eq`, `assert_approx`, `assert_non_null`.
##
## Invocazione CLI:
##   godot --headless --path v1/ res://tests/test_runner.tscn
##
## Exit code: 0 = ALL PASS, 1 = >= 1 FAIL, 2 = harness error.
extends Node

const TEST_MODULES := [
	"res://tests/integration/test_helpers.gd",
	"res://tests/integration/test_catalogs.gd",
	"res://tests/integration/test_stress.gd",
	"res://tests/integration/test_save.gd",
	"res://tests/integration/test_spawn.gd",
	"res://tests/integration/test_panels.gd",
	"res://tests/integration/test_input.gd",
	"res://tests/integration/test_ui_events.gd",
]

const RESULTS_PATH := "user://test_results.jsonl"

var _total_pass: int = 0
var _total_fail: int = 0
var _module_stats: Array[Dictionary] = []
var _failures: Array[Dictionary] = []
var _results_file: FileAccess = null


func _ready() -> void:
	# Give autoloads 1 frame to settle before running any test
	await get_tree().process_frame
	_results_file = FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	print("")
	print("============================================")
	print("  Relax Room — Deep Integration Test Suite")
	print("============================================")
	print("")
	await _run_all_modules()
	_print_report()
	if _results_file:
		_results_file.close()
	get_tree().quit(0 if _total_fail == 0 else 1)


func _run_all_modules() -> void:
	for module_path in TEST_MODULES:
		if not ResourceLoader.exists(module_path):
			push_error("test_runner: missing module %s" % module_path)
			_total_fail += 1
			continue
		var script_res: GDScript = load(module_path) as GDScript
		if script_res == null:
			push_error("test_runner: failed to load %s" % module_path)
			_total_fail += 1
			continue
		await _run_module(module_path, script_res)


func _run_module(module_path: String, script_res: GDScript) -> void:
	var instance: Node = script_res.new()
	if instance == null:
		push_error("test_runner: failed to instantiate %s" % module_path)
		_total_fail += 1
		return
	instance.name = module_path.get_file().get_basename()
	add_child(instance)

	# Give module 1 frame to run its own _ready if it needs setup
	await get_tree().process_frame

	var method_list: Array = instance.get_method_list()
	var test_methods: Array[String] = []
	for m in method_list:
		var mname: String = m.get("name", "")
		if mname.begins_with("test_"):
			test_methods.append(mname)
	test_methods.sort()

	var module_pass: int = 0
	var module_fail: int = 0
	print("── %s (%d tests)" % [instance.name, test_methods.size()])

	for method_name in test_methods:
		# Reset per-test counters on the instance so each test is independent.
		# Use method call for the Array reset to avoid the typed-Array quirk
		# where set("_failures_in_test", []) silently leaves the old array
		# because `[]` is untyped and doesn't fit Array[String] assignment.
		instance.set("_current_test_name", method_name)
		instance.set("_assertions_in_test", 0)
		if instance.has_method("_reset_failures"):
			instance.call("_reset_failures")
		else:
			var prev: Array = instance.get("_failures_in_test")
			if prev is Array:
				prev.clear()

		var callable := Callable(instance, method_name)
		if not callable.is_valid():
			continue
		var start := Time.get_ticks_msec()
		# In Godot 4, async methods return a Signal that resolves on completion;
		# sync methods return their value. `await` on a non-awaitable is a no-op,
		# so this line is safe for both kinds.
		@warning_ignore("redundant_await")
		# await su sync call ritorna il valore; await su async ritorna il signal
		# finito. Non storiamo il risultato (no-op vs il linter).
		await callable.call()
		var elapsed := Time.get_ticks_msec() - start

		var failures_in_test: Array = instance.get("_failures_in_test")
		var assertions: int = instance.get("_assertions_in_test")

		if failures_in_test.is_empty():
			module_pass += 1
			print("   ✓ %s (%d assert, %dms)" % [method_name, assertions, elapsed])
		else:
			module_fail += 1
			print("   ✗ %s (%d fail / %d assert, %dms)" % [method_name, failures_in_test.size(), assertions, elapsed])
			for f in failures_in_test:
				print("       └─ %s" % f)
				(
					_failures
					. append(
						{
							"module": instance.name,
							"test": method_name,
							"message": f,
						}
					)
				)

		_write_jsonl(
			{
				"module": instance.name,
				"test": method_name,
				"pass": failures_in_test.is_empty(),
				"assertions": assertions,
				"failures": failures_in_test,
				"elapsed_ms": elapsed,
			}
		)

	_total_pass += module_pass
	_total_fail += module_fail
	(
		_module_stats
		. append(
			{
				"name": instance.name,
				"pass": module_pass,
				"fail": module_fail,
			}
		)
	)
	print("")

	instance.queue_free()
	await get_tree().process_frame


func _print_report() -> void:
	print("============================================")
	print("  REPORT")
	print("============================================")
	for stats in _module_stats:
		var status := "✅" if stats["fail"] == 0 else "❌"
		print("  %s %-30s %d pass / %d fail" % [status, stats["name"], stats["pass"], stats["fail"]])
	print("")
	print("  Totals: %d pass, %d fail" % [_total_pass, _total_fail])
	if _total_fail > 0:
		print("")
		print("  FAILURES:")
		for f in _failures:
			print("    · %s::%s — %s" % [f["module"], f["test"], f["message"]])
	print("")
	if _total_fail == 0:
		print("  ✅ ALL PASS")
	else:
		print("  ❌ %d FAILURES" % _total_fail)
	print("")
	print("  Results: %s" % RESULTS_PATH)
	print("============================================")


func _write_jsonl(entry: Dictionary) -> void:
	if _results_file == null:
		return
	_results_file.store_line(JSON.stringify(entry))
