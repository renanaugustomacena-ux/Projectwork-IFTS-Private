## test_stress — StressManager state machine con isteresi + decay passivo.
extends "res://tests/integration/test_base.gd"


func _before_each() -> void:
	StressManager.reset()


func test_initial_state_is_calm() -> void:
	_before_each()
	assert_eq(StressManager.get_stress_level(), "calm")
	assert_approx(StressManager.get_stress_value(), 0.0)


func test_apply_delta_below_neutral_stays_calm() -> void:
	_before_each()
	StressManager.apply_delta(0.30)  # Below 0.35 UP threshold
	assert_eq(StressManager.get_stress_level(), "calm")
	assert_approx(StressManager.get_stress_value(), 0.30, 0.001)


func test_apply_delta_crosses_to_neutral() -> void:
	_before_each()
	StressManager.apply_delta(0.40)  # Above 0.35 UP threshold
	assert_eq(StressManager.get_stress_level(), "neutral")


func test_apply_delta_crosses_to_tense() -> void:
	_before_each()
	StressManager.apply_delta(0.70)  # Above 0.60 UP threshold
	assert_eq(StressManager.get_stress_level(), "tense")


func test_hysteresis_neutral_to_calm_requires_lower_threshold() -> void:
	_before_each()
	# Go up to neutral
	StressManager.apply_delta(0.40)
	assert_eq(StressManager.get_stress_level(), "neutral")
	# Coming back below 0.35 (UP threshold) is NOT enough to go calm
	StressManager.apply_delta(-0.10)  # stress = 0.30
	assert_eq(
		StressManager.get_stress_level(), "neutral", "hysteresis: 0.30 should stay neutral (DOWN threshold is 0.25)"
	)
	# Drop below 0.25 to trigger calm
	StressManager.apply_delta(-0.10)  # stress = 0.20
	assert_eq(StressManager.get_stress_level(), "calm")


func test_hysteresis_tense_to_neutral_requires_lower_threshold() -> void:
	_before_each()
	StressManager.apply_delta(0.70)
	assert_eq(StressManager.get_stress_level(), "tense")
	# 0.55 should NOT revert to neutral because DOWN_NEUTRAL is 0.50
	StressManager.apply_delta(-0.15)  # 0.55
	assert_eq(StressManager.get_stress_level(), "tense", "hysteresis: 0.55 should stay tense (DOWN_NEUTRAL = 0.50)")
	# Cross below 0.50
	StressManager.apply_delta(-0.10)  # 0.45
	assert_eq(StressManager.get_stress_level(), "neutral")


func test_stress_value_clamped_0_1() -> void:
	_before_each()
	StressManager.apply_delta(5.0)
	assert_approx(StressManager.get_stress_value(), 1.0)
	StressManager.apply_delta(-10.0)
	assert_approx(StressManager.get_stress_value(), 0.0)


func test_mess_spawned_signal_applies_weight() -> void:
	_before_each()
	# Use a known mess id from catalog
	var first_mess: Dictionary = GameManager.mess_catalog.get("mess", [])[0]
	var id: String = first_mess.get("id", "")
	var weight: float = float(first_mess.get("stress_weight", 0.10))
	SignalBus.mess_spawned.emit(id, Vector2.ZERO)
	assert_approx(StressManager.get_stress_value(), weight, 0.001)


func test_mess_cleaned_signal_removes_weight() -> void:
	_before_each()
	var first_mess: Dictionary = GameManager.mess_catalog.get("mess", [])[0]
	var id: String = first_mess.get("id", "")
	SignalBus.mess_spawned.emit(id, Vector2.ZERO)
	var after_spawn: float = StressManager.get_stress_value()
	assert_true(after_spawn > 0.0)
	SignalBus.mess_cleaned.emit(id)
	# Cleaning the same mess id removes exactly the weight we applied
	assert_approx(StressManager.get_stress_value(), 0.0, 0.001)


func test_multiple_messes_stack_weights() -> void:
	_before_each()
	var entries: Array = GameManager.mess_catalog.get("mess", [])
	var total_weight: float = 0.0
	# Pick 3 distinct messes
	for i in range(mini(3, entries.size())):
		var e: Dictionary = entries[i]
		SignalBus.mess_spawned.emit(e.get("id", ""), Vector2.ZERO)
		total_weight += float(e.get("stress_weight", 0.10))
	assert_approx(StressManager.get_stress_value(), total_weight, 0.01)


func test_reset_zeros_state() -> void:
	StressManager.apply_delta(0.8)
	assert_true(StressManager.get_stress_value() > 0.5)
	StressManager.reset()
	assert_approx(StressManager.get_stress_value(), 0.0)
	assert_eq(StressManager.get_stress_level(), "calm")


func test_stress_persist_to_character_data() -> void:
	_before_each()
	StressManager.apply_delta(0.42)  # ~42
	# _persist() runs on every _notify_change via _set_stress
	var stored: int = int(SaveManager.character_data.get("livello_stress", -1))
	# Should be 42 (float 0.42 * 100 = 42) ± rounding
	assert_in_range(float(stored), 41.0, 43.0, "livello_stress int persist expected ~42, got %d" % stored)
