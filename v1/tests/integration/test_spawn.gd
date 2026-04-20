## test_spawn — decoration spawn lifecycle on a minimal Room instance.
##
## Each test builds a fresh Room with decorations container + floor polygon,
## so tests are isolated from each other.
extends "res://tests/integration/test_base.gd"

const DecorationScript := preload("res://scripts/rooms/decoration_system.gd")

var _room: Node2D = null
var _decorations_container: Node2D = null


func _build_minimal_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.queue_free()
		await wait_frames(1)
	_room = Node2D.new()
	_room.name = "TestRoom"
	add_child(_room)

	_decorations_container = Node2D.new()
	_decorations_container.name = "Decorations"
	_room.add_child(_decorations_container)

	# Initialize floor polygon (same rhombus as main.tscn)
	var poly_node := CollisionPolygon2D.new()
	poly_node.polygon = PackedVector2Array(
		[
			Vector2(640, 265),
			Vector2(1100, 480),
			Vector2(640, 685),
			Vector2(180, 480),
		]
	)
	_room.add_child(poly_node)
	Helpers.set_floor_polygon_from_node(poly_node)


func _spawn_manually(item_id: String, pos: Vector2, item_scale: float, rot: float, flip_h: bool) -> Sprite2D:
	# Mirror of room_base._spawn_decoration — standalone so we don't need
	# the full main.tscn tree.
	var item_data := _find_item(item_id)
	if item_data.is_empty():
		return null
	var sprite_path: String = item_data.get("sprite_path", "")
	var texture: Texture2D = load(sprite_path) as Texture2D
	if texture == null:
		return null

	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(item_scale, item_scale)
	sprite.position = pos
	sprite.rotation_degrees = rot
	sprite.flip_h = flip_h
	sprite.name = item_id
	sprite.set_script(DecorationScript)
	sprite.item_id = item_id
	sprite.base_item_scale = item_scale
	sprite.deco_data = {
		"item_id": item_id,
		"position": [pos.x, pos.y],
		"item_scale": item_scale,
		"rotation": rot,
		"flip_h": flip_h,
	}
	_decorations_container.add_child(sprite)
	return sprite


func _find_item(item_id: String) -> Dictionary:
	for d in GameManager.decorations_catalog.get("decorations", []):
		if d is Dictionary and d.get("id", "") == item_id:
			return d
	return {}


# ---- Tests ----


func test_can_spawn_first_decoration() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 3.0, 0.0, false)
	assert_non_null(sprite, "bed_1 must spawn from catalog")
	await wait_frames(1)
	assert_eq(_decorations_container.get_child_count(), 1)


func test_spawn_all_catalog_decorations_succeeds() -> void:
	# Exhaustive: every deco in the catalog must be spawnable.
	# This catches regressions where a catalog entry references a missing sprite.
	await _build_minimal_room()
	var failed: Array[String] = []
	var idx := 0
	for deco in GameManager.decorations_catalog.get("decorations", []):
		var id: String = deco.get("id", "")
		var scale: float = float(deco.get("item_scale", 1.0))
		var pos := Vector2(200 + (idx % 10) * 30, 300 + (idx / 10) * 30)
		var sprite := _spawn_manually(id, pos, scale, 0.0, false)
		if sprite == null:
			failed.append(id)
		idx += 1
	if not failed.is_empty():
		fail("spawn failed for: %s" % ", ".join(failed))
	else:
		assert_true(true, "all 72 decorations spawnable")


func test_spawned_sprite_uses_nearest_filter() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 3.0, 0.0, false)
	assert_eq(
		sprite.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"all decoration sprites must have nearest filter for pixel art crispness"
	)


func test_spawned_sprite_non_centered() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 3.0, 0.0, false)
	assert_false(sprite.centered, "anchor convention: decorations are NOT centered")


func test_spawned_sprite_scale_applied() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 2.5, 0.0, false)
	assert_approx(sprite.scale.x, 2.5)
	assert_approx(sprite.scale.y, 2.5)


func test_spawned_sprite_has_item_id_meta() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("plant_0", Vector2(640, 500), 6.0, 0.0, false)
	assert_eq(sprite.item_id, "plant_0")
	assert_approx(sprite.base_item_scale, 6.0)


func test_rotation_persists_to_deco_data() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 3.0, 0.0, false)
	sprite._on_rotate()
	assert_approx(sprite.rotation_degrees, 90.0)
	assert_approx(
		float(sprite.deco_data.get("rotation", -1.0)), 90.0, 0.1, "rotation must be mirrored in deco_data dict"
	)


func test_flip_persists_to_deco_data() -> void:
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 3.0, 0.0, false)
	sprite._on_flip()
	assert_true(sprite.flip_h)
	assert_eq(sprite.deco_data.get("flip_h", false), true)


func test_scale_cycles_through_steps() -> void:
	# SCALE_STEPS := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]
	await _build_minimal_room()
	var sprite: Sprite2D = _spawn_manually("bed_1", Vector2(640, 500), 1.0, 0.0, false)
	sprite._on_scale()
	# 1.0 → 1.5 (next in SCALE_STEPS)
	assert_approx(sprite.scale.x, 1.5)


func test_decoration_placed_signal_updates_savemanager() -> void:
	await _build_minimal_room()
	var before_count: int = SaveManager.get_decorations().size()
	# Add directly via SaveManager (what room_base.gd does in reality)
	(
		SaveManager
		. add_decoration(
			{
				"item_id": "bed_1",
				"position": [640, 500],
				"item_scale": 3.0,
				"rotation": 0.0,
				"flip_h": false,
			}
		)
	)
	var after_count: int = SaveManager.get_decorations().size()
	assert_eq(after_count, before_count + 1)
	# Cleanup
	var decos := SaveManager.get_decorations()
	SaveManager.remove_decoration(decos[decos.size() - 1])


func test_clamp_inside_floor_placement() -> void:
	await _build_minimal_room()
	# Drop far outside polygon; should be clamped inside
	var raw := Vector2(2000, 2000)
	var clamped := Helpers.clamp_inside_floor(raw)
	assert_true(
		Helpers.is_inside_floor(clamped), "clamp_inside_floor must return a strictly-inside point, got %s" % clamped
	)
