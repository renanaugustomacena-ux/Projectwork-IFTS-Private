## test_placement — placement rules: wall band geometry, placement_type
## normalization, per-item flags and z ordering bands.
##
## The wall band is derived from the floor polygon (its two edges adjacent to
## the topmost vertex), so these tests pin down that derivation with a known
## diamond before exercising the clamps that every boundary (drop, drag,
## load-heal) shares.
extends "res://tests/integration/test_base.gd"

# Same shape family as main.tscn's FloorBounds: top, right, bottom, left.
const POLY := [
	Vector2(646, 263),
	Vector2(974, 434),
	Vector2(646, 606),
	Vector2(319, 434),
]

var _poly_node: CollisionPolygon2D = null


func _install_polygon() -> void:
	if _poly_node != null and is_instance_valid(_poly_node):
		_poly_node.queue_free()
	_poly_node = CollisionPolygon2D.new()
	_poly_node.polygon = PackedVector2Array(POLY)
	add_child(_poly_node)
	Helpers.set_floor_polygon_from_node(_poly_node)


func test_wall_band_derived_from_polygon() -> void:
	_install_polygon()
	assert_true(Helpers.has_wall_band(), "wall band should derive from the diamond")
	# Base at the top vertex equals the vertex's own y.
	assert_approx(Helpers.wall_base_y_at(646.0), 263.0, 0.5, "base at top vertex")
	# Base at the left vertex equals the left vertex's y.
	assert_approx(Helpers.wall_base_y_at(319.0), 434.0, 0.5, "base at left vertex")
	# Halfway along the left edge interpolates linearly.
	var mid_x := (319.0 + 646.0) * 0.5
	assert_approx(Helpers.wall_base_y_at(mid_x), (434.0 + 263.0) * 0.5, 0.5, "left edge midpoint")
	# Outside the wall span there is no wall.
	assert_eq(Helpers.wall_base_y_at(100.0), INF, "left of the room")
	assert_eq(Helpers.wall_base_y_at(1200.0), INF, "right of the room")


func test_clamp_wall_anchor_moves_floor_point_onto_wall() -> void:
	_install_polygon()
	var half := Vector2(30, 25)
	# A window dropped in the middle of the floor must be lifted onto the wall.
	var on_floor := Vector2(646, 500)
	var clamped := Helpers.clamp_wall_anchor(on_floor, half)
	var base := Helpers.wall_base_y_at(clamped.x)
	assert_true(clamped.y + half.y <= base, "rect bottom above the wall base")
	assert_true(clamped.y - half.y >= base - Helpers.WALL_BAND_HEIGHT, "rect top inside the band")
	# A point already on the wall face stays put.
	var legal := Vector2(500, Helpers.wall_base_y_at(500.0) - 80.0)
	assert_true(legal.distance_to(Helpers.clamp_wall_anchor(legal, half)) < 0.5, "legal point unchanged")
	assert_true(Helpers.is_on_wall(legal, half), "is_on_wall accepts a legal point")
	assert_false(Helpers.is_on_wall(on_floor, half), "is_on_wall rejects a floor point")


func test_placement_type_normalization() -> void:
	assert_eq(Helpers.placement_type_of({"placement_type": "floor"}), "floor")
	assert_eq(Helpers.placement_type_of({"placement_type": "wall"}), "wall")
	# Retired/unknown values fall back to floor (warn-and-continue, not crash).
	assert_eq(Helpers.placement_type_of({"placement_type": "any"}), "floor")
	assert_eq(Helpers.placement_type_of({"placement_type": "ceiling"}), "floor")
	assert_eq(Helpers.placement_type_of({}), "floor")


func test_item_flags_and_scale_bounds() -> void:
	assert_false(Helpers.is_rotatable({}), "rotation is opt-in")
	assert_true(Helpers.is_rotatable({"rotatable": true}))
	assert_false(Helpers.is_flat({}), "flat is opt-in")
	assert_true(Helpers.is_flat({"flat": true}))
	var default_bounds := Helpers.scale_bounds_of({})
	assert_approx(default_bounds.x, 0.5, 0.001, "default min multiplier")
	assert_approx(default_bounds.y, 2.0, 0.001, "default max multiplier")
	var custom := Helpers.scale_bounds_of({"scale_min": 1.0, "scale_max": 1.5})
	assert_approx(custom.x, 1.0, 0.001)
	assert_approx(custom.y, 1.5, 0.001)
	# Inverted bounds are repaired, never returned inverted.
	var inverted := Helpers.scale_bounds_of({"scale_min": 3.0, "scale_max": 1.0})
	assert_true(inverted.x <= inverted.y, "bounds never inverted")


func test_z_order_bands() -> void:
	assert_true(Helpers.Z_WALL < Helpers.Z_FLAT, "walls behind rugs")
	assert_true(Helpers.Z_FLAT < Helpers.z_for_foot_y(0.0), "rugs behind any standing entity")
	assert_true(Helpers.z_for_foot_y(300.0) < Helpers.z_for_foot_y(500.0), "lower feet draw in front")
	assert_eq(Helpers.z_for_foot_y(-50.0), Helpers.Z_FOOT_MIN, "negative y clamps to the band floor")


func test_teardown_placement() -> void:
	# Restore the real room polygon absence so later modules re-init cleanly.
	if _poly_node != null and is_instance_valid(_poly_node):
		_poly_node.queue_free()
		_poly_node = null
	assert_true(true)
