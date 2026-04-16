## test_helpers — pure logic unit tests (no scene tree).
##
## Copre: Helpers.snap_to_grid, Helpers.clamp_to_viewport,
## Helpers.vec2_to_array / array_to_vec2, Helpers.format_time,
## floor polygon init + clamp_inside_floor.
extends "res://tests/integration/test_base.gd"


func test_snap_to_grid_integers_preserved() -> void:
	# Grid 64: (0,0), (64,64), (128,128) must return same
	assert_eq(Helpers.snap_to_grid(Vector2(0, 0)), Vector2(0, 0))
	assert_eq(Helpers.snap_to_grid(Vector2(64, 64)), Vector2(64, 64))
	assert_eq(Helpers.snap_to_grid(Vector2(128, 128)), Vector2(128, 128))


func test_snap_to_grid_rounds_nearest() -> void:
	# 30 rounds to 32 (nearest multiple of 64 is 0 or 64; roundf(30/64)=0)
	assert_eq(Helpers.snap_to_grid(Vector2(30, 30)), Vector2(0, 0))
	assert_eq(Helpers.snap_to_grid(Vector2(40, 40)), Vector2(64, 64))
	assert_eq(Helpers.snap_to_grid(Vector2(95, 95)), Vector2(64, 64))
	assert_eq(Helpers.snap_to_grid(Vector2(97, 97)), Vector2(128, 128))


func test_snap_to_grid_custom_cell_size() -> void:
	assert_eq(Helpers.snap_to_grid(Vector2(50, 50), 32), Vector2(64, 64))
	assert_eq(Helpers.snap_to_grid(Vector2(50, 50), 16), Vector2(48, 48))


func test_snap_to_grid_negative_coordinates() -> void:
	# -30 rounds to 0, -40 rounds to -64
	assert_eq(Helpers.snap_to_grid(Vector2(-30, -30)), Vector2(0, 0))
	assert_eq(Helpers.snap_to_grid(Vector2(-40, -40)), Vector2(-64, -64))


func test_vec2_array_roundtrip() -> void:
	var v := Vector2(123.45, -67.89)
	var arr := Helpers.vec2_to_array(v)
	assert_eq(arr.size(), 2)
	assert_approx(arr[0], 123.45)
	assert_approx(arr[1], -67.89)
	var v2 := Helpers.array_to_vec2(arr)
	assert_approx(v2.x, v.x)
	assert_approx(v2.y, v.y)


func test_array_to_vec2_short_array_returns_zero() -> void:
	# Safety: malformed saved data shouldn't crash
	assert_eq(Helpers.array_to_vec2([]), Vector2.ZERO)
	assert_eq(Helpers.array_to_vec2([5.0]), Vector2.ZERO)


func test_format_time_under_minute() -> void:
	assert_eq(Helpers.format_time(0), "00:00")
	assert_eq(Helpers.format_time(7), "00:07")
	assert_eq(Helpers.format_time(59), "00:59")


func test_format_time_over_minute() -> void:
	assert_eq(Helpers.format_time(60), "01:00")
	assert_eq(Helpers.format_time(125), "02:05")
	assert_eq(Helpers.format_time(3599), "59:59")


func test_clamp_to_viewport_inside_is_unchanged() -> void:
	var p := Vector2(400, 400)
	assert_eq(Helpers.clamp_to_viewport(p), p)


func test_clamp_to_viewport_clamps_outside() -> void:
	var p := Vector2(-100, 2000)
	var clamped := Helpers.clamp_to_viewport(p)
	assert_in_range(clamped.x, 0.0, float(Constants.VIEWPORT_WIDTH))
	assert_in_range(clamped.y, 0.0, float(Constants.VIEWPORT_HEIGHT))
	assert_eq(clamped.x, 0.0)
	assert_eq(clamped.y, float(Constants.VIEWPORT_HEIGHT))


func test_floor_polygon_init_via_node() -> void:
	# Synthesize a CollisionPolygon2D with a rhombus matching main.tscn
	var poly_node := CollisionPolygon2D.new()
	poly_node.polygon = PackedVector2Array([
		Vector2(640, 265), Vector2(1100, 480),
		Vector2(640, 685), Vector2(180, 480),
	])
	add_child(poly_node)
	Helpers.set_floor_polygon_from_node(poly_node)
	assert_true(Helpers.has_floor_polygon())
	var poly := Helpers.get_floor_polygon_world()
	assert_eq(poly.size(), 4)
	poly_node.queue_free()


func test_is_inside_floor_center_true() -> void:
	# Centroid of the rhombus is roughly (640, 477)
	assert_true(Helpers.is_inside_floor(Vector2(640, 477)))


func test_is_inside_floor_corner_outside() -> void:
	# (0,0) outside rhombus
	assert_false(Helpers.is_inside_floor(Vector2(0, 0)))


func test_clamp_inside_floor_outside_point_brought_in() -> void:
	var original := Vector2(0, 0)
	var clamped := Helpers.clamp_inside_floor(original)
	assert_true(Helpers.is_inside_floor(clamped),
		"clamp_inside_floor must return a point strictly inside (got %s)" % clamped)


func test_clamp_inside_floor_inside_point_unchanged() -> void:
	var p := Vector2(640, 450)
	var clamped := Helpers.clamp_inside_floor(p)
	assert_approx(clamped.x, p.x)
	assert_approx(clamped.y, p.y)


func test_get_floor_bounds_matches_polygon() -> void:
	var bounds := Helpers.get_floor_bounds()
	# Rhombus extends x=[180..1100], y=[265..685]
	assert_approx(bounds.position.x, 180.0)
	assert_approx(bounds.position.y, 265.0)
	assert_approx(bounds.end.x, 1100.0)
	assert_approx(bounds.end.y, 685.0)
