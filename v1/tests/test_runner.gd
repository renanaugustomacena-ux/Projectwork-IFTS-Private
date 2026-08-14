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
##   ./scripts/deep_test.sh
##
## SOLO tramite il wrapper: la suite scrive save, DB e log dentro `user://`, che
## per il gioco e` il profilo reale del giocatore. Il wrapper redirige `user://`
## su una directory usa-e-getta e ci pianta SANDBOX_MARKER; senza quel marker il
## runner abortisce invece di distruggere i dati veri (audit G-053).
##
## Exit code: 0 = ALL PASS, 1 = >= 1 FAIL, 2 = harness error / user:// non isolata.
extends Node

const TEST_MODULES := [
	"res://tests/integration/test_helpers.gd",
	"res://tests/integration/test_placement.gd",
	"res://tests/integration/test_catalogs.gd",
	"res://tests/integration/test_stress.gd",
	"res://tests/integration/test_shop.gd",
	"res://tests/integration/test_cleaning.gd",
	"res://tests/integration/test_trust.gd",
	"res://tests/integration/test_save.gd",
	"res://tests/integration/test_spawn.gd",
	"res://tests/integration/test_panels.gd",
	"res://tests/integration/test_input.gd",
	"res://tests/integration/test_movement_bounds.gd",
	"res://tests/integration/test_ui_events.gd",
	"res://tests/integration/test_crypto.gd",
	"res://tests/integration/test_save_failures.gd",
	"res://tests/integration/test_i18n_assets.gd",
	"res://tests/integration/test_phase_f.gd",
	"res://tests/integration/test_bridge.gd",
	"res://tests/integration/test_logger.gd",
	"res://tests/integration/test_mood.gd",
]

const RESULTS_PATH := "user://test_results.jsonl"

## Sentinella creata da `scripts/deep_test.sh` dentro la user dir usa-e-getta.
## E` la prova empirica che `user://` NON e` il profilo del giocatore: la sua
## assenza blocca la suite prima di aprire un solo file (audit G-053).
const SANDBOX_MARKER := "user://.test_sandbox"

var _total_pass: int = 0
var _total_fail: int = 0
var _module_stats: Array[Dictionary] = []
var _failures: Array[Dictionary] = []
var _results_file: FileAccess = null


func _ready() -> void:
	# Gate d'isolamento PRIMA di qualunque scrittura: se user:// e` il profilo
	# reale non tocchiamo niente e usciamo con harness error.
	if not FileAccess.file_exists(SANDBOX_MARKER):
		_print_sandbox_error()
		get_tree().quit(2)
		return
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


## Spiega perche` la suite si e` fermata e come lanciarla davvero. Stampiamo su
## stdout (il gate di CI legge lo stdout) e su stderr per non passare inosservati.
func _print_sandbox_error() -> void:
	printerr("test_runner: user:// non e` una sandbox di test, esecuzione annullata (G-053)")
	print("")
	print("============================================")
	print("  ❌ SUITE ANNULLATA — user:// non isolata")
	print("============================================")
	print("")
	print("  user:// risolve in: %s" % OS.get_user_data_dir())
	print("  Marker mancante:    %s" % SANDBOX_MARKER)
	print("")
	print("  Questa e` la directory del profilo reale: eseguire la suite qui")
	print("  sovrascriverebbe save_data.json, cozy_room.db e integrity.key del")
	print("  giocatore. Lancia la suite dal wrapper, che crea una user dir")
	print("  usa-e-getta (unica per run) e ci pianta il marker:")
	print("")
	print("      ./scripts/deep_test.sh")
	print("")
	print("============================================")


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
	print("  Results: %s" % ProjectSettings.globalize_path(RESULTS_PATH))
	print("============================================")


func _write_jsonl(entry: Dictionary) -> void:
	if _results_file == null:
		return
	_results_file.store_line(JSON.stringify(entry))
