## test_trust — confidenza del gatto (fase 2, spec 2026-08-14).
extends "res://tests/integration/test_base.gd"

const PetScript := preload("res://scripts/rooms/pet_controller.gd")
const CAT_SCENE := "res://scenes/cat_void.tscn"

var _saved_pet: Dictionary = {}


func _snapshot() -> void:
	_saved_pet = SaveManager.pet_data.duplicate(true)


func _restore() -> void:
	SaveManager.pet_data = _saved_pet.duplicate(true)


func test_trust_tiers() -> void:
	assert_eq(PetScript.trust_tier(0.0), "avoid")
	assert_eq(PetScript.trust_tier(19.9), "avoid")
	assert_eq(PetScript.trust_tier(20.0), "neutral")
	assert_eq(PetScript.trust_tier(69.9), "neutral")
	assert_eq(PetScript.trust_tier(70.0), "close")
	assert_eq(PetScript.trust_tier(89.9), "close")
	assert_eq(PetScript.trust_tier(90.0), "bonded")
	assert_eq(PetScript.trust_tier(100.0), "bonded")


func test_meal_gain_requires_hunger() -> void:
	var now := 1_000_000.0
	assert_approx(PetScript.meal_trust_gain(0.0, now), 8.0, 0.001, "primo pasto: fame piena")
	var just_fed := now - 60.0
	assert_approx(PetScript.meal_trust_gain(just_fed, now), 0.0, 0.001, "pasto ripetuto: niente trust")
	var four_hours_ago := now - 4.0 * 3600.0
	assert_approx(PetScript.meal_trust_gain(four_hours_ago, now), 8.0, 0.001, "dopo 4h ha di nuovo fame")


func test_pet_trust_persistence_and_clamp() -> void:
	_snapshot()
	var payload := JSON.stringify(
		{"version": "5.1.0", "pet": {"trust": 42.5, "next_potty_at": 123.0, "last_meal_at": 456.0}}
	)
	SaveManager._apply_save_data(JSON.parse_string(payload))
	assert_approx(float(SaveManager.pet_data["trust"]), 42.5, 0.001, "trust round-trips through JSON")
	assert_approx(float(SaveManager.pet_data["next_potty_at"]), 123.0, 0.001)
	# Un valore fuori scala nel file viene clampato al confine (modulo 23).
	SaveManager._apply_save_data(JSON.parse_string(JSON.stringify({"version": "5.1.0", "pet": {"trust": 150.0}})))
	assert_approx(float(SaveManager.pet_data["trust"]), 100.0, 0.001, "trust clamped to 100")
	_restore()


func test_low_trust_cat_flees_from_player() -> void:
	_snapshot()
	SaveManager.pet_data["trust"] = 0.0
	var room := Node2D.new()
	add_child(room)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(646, 263), Vector2(974, 434), Vector2(646, 606), Vector2(319, 434)])
	room.add_child(poly)
	Helpers.set_floor_polygon_from_node(poly)
	var body := CharacterBody2D.new()
	body.name = "Character"
	body.position = Vector2(620, 450)
	room.add_child(body)
	var pet: CharacterBody2D = (load(CAT_SCENE) as PackedScene).instantiate()
	pet.position = Vector2(660, 450)  # a 40px: sotto la soglia di fuga (100)
	room.add_child(pet)
	await wait_frames(6)
	assert_eq(pet._state, PetScript.State.AVOID, "gatto diffidente scappa dal player vicino")
	var dist_now: float = pet.position.distance_to(body.position)
	assert_true(dist_now > 40.0, "si sta allontanando (dist %f)" % dist_now)
	room.queue_free()
	await wait_frames(1)
	_restore()


func test_high_trust_cat_does_not_flee() -> void:
	_snapshot()
	SaveManager.pet_data["trust"] = 80.0
	var room := Node2D.new()
	add_child(room)
	var body := CharacterBody2D.new()
	body.name = "Character"
	body.position = Vector2(620, 450)
	room.add_child(body)
	var pet: CharacterBody2D = (load(CAT_SCENE) as PackedScene).instantiate()
	pet.position = Vector2(660, 450)
	room.add_child(pet)
	await wait_frames(6)
	assert_ne(pet._state, PetScript.State.AVOID, "gatto fidato non scappa")
	room.queue_free()
	await wait_frames(1)
	_restore()
