## test_cleaning — pulizia a tempo dei mess (fase economia).
##
## Le durate vengono da entry di catalogo COSTRUITE dal test (sub-secondo),
## cosi' il ciclo completo — avvio, progresso, payout, rimozione dal save —
## gira in poche decine di frame reali.
extends "res://tests/integration/test_base.gd"

const MessNodeScript := preload("res://scripts/rooms/mess_node.gd")

var _saved_coins: int = 0
var _saved_items: Array = []


func _fast_entry(duration: float = 0.5) -> Dictionary:
	return {
		"id": "crumbs_spot",  # id reale: lo stress lookup deve trovarlo
		"stress_weight": 0.06,
		"clean_reward": 2,
		"clean_duration_sec": duration,
		"placeholder_color": "#c2a677",
		"size_px": 16,
	}


func _snapshot() -> void:
	_saved_coins = int(SaveManager.inventory_data.get("coins", 0))
	_saved_items = (SaveManager.inventory_data.get("items", []) as Array).duplicate(true)
	SaveManager.inventory_data["items"] = []


func _restore() -> void:
	SaveManager.inventory_data["coins"] = _saved_coins
	SaveManager.inventory_data["items"] = _saved_items.duplicate(true)


func test_cleaning_full_cycle_pays_at_completion() -> void:
	_snapshot()
	SaveManager.inventory_data["coins"] = 0
	var persisted := {"mess_id": "crumbs_spot", "position": [640, 450], "spawned_at": 0.0, "cleaning_ends_at": 0.0}
	SaveManager.add_mess(persisted)
	var mess: Area2D = MessNodeScript.new()
	# 1.0s: la durata minima ammessa da MessNode (le durate sub-secondo
	# vengono clampate a 1s per difesa).
	mess.setup(_fast_entry(1.0), Vector2(640, 450), persisted)
	add_child(mess)
	await wait_frames(2)
	assert_false(mess.is_cleaning(), "spawns dirty")
	mess.start_cleaning()
	assert_true(mess.is_cleaning(), "cleaning after interact")
	assert_true(float(persisted.get("cleaning_ends_at", 0.0)) > 0.0, "ends_at persisted")
	assert_eq(int(SaveManager.inventory_data["coins"]), 0, "no payout at start")
	await wait_frames(85)  # ~1.4s a 60Hz > 1.0s di durata
	assert_false(is_instance_valid(mess), "node freed at completion")
	assert_eq(int(SaveManager.inventory_data["coins"]), 2, "reward paid at completion")
	assert_eq(SaveManager.get_messes().find(persisted), -1, "entry removed from save")
	_restore()


func test_reloaded_mess_with_past_deadline_completes_immediately() -> void:
	_snapshot()
	SaveManager.inventory_data["coins"] = 0
	var persisted := {
		"mess_id": "crumbs_spot",
		"position": [640, 450],
		"spawned_at": 0.0,
		"cleaning_started_at": Time.get_unix_time_from_system() - 10.0,
		"cleaning_ends_at": Time.get_unix_time_from_system() - 5.0,
	}
	SaveManager.add_mess(persisted)
	var mess: Area2D = MessNodeScript.new()
	mess.setup(_fast_entry(0.4), Vector2(640, 450), persisted)
	add_child(mess)
	await wait_frames(3)
	assert_false(is_instance_valid(mess), "past-deadline mess completes on first frames")
	assert_eq(int(SaveManager.inventory_data["coins"]), 2, "reward granted")
	_restore()


func test_absurd_deadline_is_clamped() -> void:
	_snapshot()
	var now := Time.get_unix_time_from_system()
	var persisted := {
		"mess_id": "crumbs_spot",
		"position": [640, 450],
		"spawned_at": 0.0,
		"cleaning_ends_at": now + 999999.0,
	}
	var mess: Area2D = MessNodeScript.new()
	mess.setup(_fast_entry(7.0), Vector2(640, 450), persisted)
	add_child(mess)
	await wait_frames(1)
	assert_true(
		float(persisted["cleaning_ends_at"]) <= Time.get_unix_time_from_system() + 7.5,
		"clock-skew deadline clamped to catalog duration"
	)
	mess.queue_free()
	SaveManager.remove_mess(persisted)
	await wait_frames(1)
	_restore()


func test_tool_shortens_cleaning() -> void:
	_snapshot()
	SaveManager.add_item("vacuum")  # x4 dal catalogo shop
	var persisted := {"mess_id": "crumbs_spot", "position": [640, 450], "spawned_at": 0.0, "cleaning_ends_at": 0.0}
	var mess: Area2D = MessNodeScript.new()
	mess.setup(_fast_entry(8.0), Vector2(640, 450), persisted)
	add_child(mess)
	await wait_frames(1)
	var before := Time.get_unix_time_from_system()
	mess.start_cleaning()
	var expected: float = before + 8.0 / 4.0
	assert_in_range(float(persisted["cleaning_ends_at"]), expected - 0.5, expected + 0.5, "durata divisa dal x4")
	mess.queue_free()
	await wait_frames(1)
	_restore()


func test_mess_cap_is_enforced() -> void:
	# Self-contained: track exactly what got in (previous tests may leave
	# state) and remove only that, asserting on deltas.
	var before := SaveManager.get_messes().size()
	var accepted: Array = []
	for i in range(SaveManager.MAX_SAVED_MESSES + 5):
		var entry := {"mess_id": "crumbs_spot", "position": [0, 0], "spawned_at": 0.0, "cleaning_ends_at": 0.0}
		var size_before := SaveManager.get_messes().size()
		SaveManager.add_mess(entry)
		if SaveManager.get_messes().size() > size_before:
			accepted.append(entry)
	assert_true(SaveManager.get_messes().size() <= SaveManager.MAX_SAVED_MESSES, "cap respected")
	assert_true(accepted.size() <= SaveManager.MAX_SAVED_MESSES, "no acceptance past the cap")
	for entry: Dictionary in accepted:
		SaveManager.remove_mess(entry)
	assert_eq(SaveManager.get_messes().size(), before, "test leaves no residue")
