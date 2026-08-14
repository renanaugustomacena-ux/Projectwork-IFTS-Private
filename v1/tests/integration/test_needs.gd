## test_needs — giardino e bisogni fisiologici (fase 3, spec 2026-08-14):
## accumulatore offline, registro zone e clamp di unione pavimento+giardino.
extends "res://tests/integration/test_base.gd"

const PetScript := preload("res://scripts/rooms/pet_controller.gd")

const GARDEN_POLY := [Vector2(0, 700), Vector2(400, 700), Vector2(400, 900), Vector2(0, 900)]
const FLOOR_POLY := [Vector2(646, 263), Vector2(974, 434), Vector2(646, 606), Vector2(319, 434)]

var _poly_node: CollisionPolygon2D = null


func _install_geometry() -> void:
	if _poly_node != null and is_instance_valid(_poly_node):
		_poly_node.queue_free()
	_poly_node = CollisionPolygon2D.new()
	_poly_node.polygon = PackedVector2Array(FLOOR_POLY)
	add_child(_poly_node)
	Helpers.set_floor_polygon_from_node(_poly_node)
	Helpers.clear_zones()
	Helpers.register_zone_polygon("garden", PackedVector2Array(GARDEN_POLY))


func test_offline_potty_accrual() -> void:
	var six_h: float = PetScript.POTTY_INTERVAL_SEC
	# Niente maturato se la scadenza e` nel futuro.
	var r: Dictionary = PetScript.accrue_offline_potties(1000.0, 500.0)
	assert_eq(int(r["count"]), 0)
	assert_approx(float(r["next"]), 1000.0, 0.001, "scadenza futura intatta")
	# Una scadenza passata = 1 bisogno, next avanza di un intervallo.
	r = PetScript.accrue_offline_potties(1000.0, 1000.0)
	assert_eq(int(r["count"]), 1)
	assert_approx(float(r["next"]), 1000.0 + six_h, 0.001)
	# 3 intervalli passati = 3 bisogni.
	r = PetScript.accrue_offline_potties(1000.0, 1000.0 + 2.5 * six_h)
	assert_eq(int(r["count"]), 3)
	# Una settimana via: il cap difensivo limita a MAX_OFFLINE_POTTIES.
	r = PetScript.accrue_offline_potties(1000.0, 1000.0 + 7.0 * 24.0 * 3600.0)
	assert_eq(int(r["count"]), PetScript.MAX_OFFLINE_POTTIES, "cap offline")
	assert_true(float(r["next"]) > 1000.0 + 7.0 * 24.0 * 3600.0, "next oltre adesso")
	# Orologio mai inizializzato: nessun bisogno.
	r = PetScript.accrue_offline_potties(0.0, 99999.0)
	assert_eq(int(r["count"]), 0)


func test_zone_registry_and_membership() -> void:
	_install_geometry()
	assert_true(Helpers.has_zone("garden"))
	assert_true(Helpers.is_inside_zone("garden", Vector2(200, 800)))
	assert_false(Helpers.is_inside_zone("garden", Vector2(646, 434)), "il centro stanza non e` giardino")
	assert_false(Helpers.has_zone("void"), "zona sconosciuta assente")
	var clamped := Helpers.clamp_inside_zone("garden", Vector2(200, 950))
	assert_true(Helpers.is_inside_zone("garden", clamped), "clamp rientra nella zona")


func test_union_clamp_lets_the_cat_cross() -> void:
	_install_geometry()
	# Dentro il pavimento: invariato.
	var inside_floor := Vector2(646, 434)
	assert_eq(Helpers.clamp_inside_floor_or_zone("garden", inside_floor), inside_floor)
	# Dentro il giardino: invariato (con il solo clamp pavimento sarebbe respinto).
	var in_garden := Vector2(200, 800)
	assert_eq(Helpers.clamp_inside_floor_or_zone("garden", in_garden), in_garden)
	# Fuori da entrambi: finisce nel piu` vicino dei due.
	var outside := Vector2(100, 1100)
	var fixed := Helpers.clamp_inside_floor_or_zone("garden", outside)
	assert_true(
		Helpers.is_inside_zone("garden", fixed) or Helpers.is_inside_floor(fixed),
		"il clamp di unione atterra in un'area legale"
	)
	assert_true(Helpers.is_inside_zone("garden", fixed), "qui il giardino e` il piu` vicino")


func test_random_garden_point_is_inside() -> void:
	_install_geometry()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for _i in range(10):
		var p := Helpers.random_point_in_zone("garden", rng)
		assert_true(Helpers.is_inside_zone("garden", p), "punto casuale dentro la zona (%s)" % p)


func test_zz_teardown_needs() -> void:
	Helpers.clear_zones()
	if _poly_node != null and is_instance_valid(_poly_node):
		_poly_node.queue_free()
		_poly_node = null
	assert_true(true)
