## test_movement_bounds — runtime containment: the character is DRIVEN with
## simulated input through real physics against the same wall segments as
## main.tscn, and must (a) get close to the back wall, (b) reach the front
## edge, (c) never put its foot point outside the floor polygon.
##
## This is the machine version of "walk into every corner": before the
## 2026-08-14 geometry fix, (a) failed by ~80px (full-body capsule hit the
## back wall head-first) and (c) failed at the bottom diagonals (collision
## diamond larger than the visual floor).
extends "res://tests/integration/test_base.gd"

const CHAR_SCENE := "res://scenes/male-old-character.tscn"
# Same polygon as main.tscn FloorBounds (top, right, bottom, left).
const POLY := [
	Vector2(646, 263),
	Vector2(974, 434),
	Vector2(646, 606),
	Vector2(319, 434),
]
const DRIVE_FRAMES := 80  # ~1.3s at 60Hz: travel + sustained push on the wall

var _room: Node2D = null
var _char: CharacterBody2D = null
var _foot_offset := Vector2.ZERO


func _setup_room_and_character(spawn: Vector2) -> void:
	_teardown()
	_room = Node2D.new()
	_room.name = "BoundsTestRoom"
	add_child(_room)

	# Wall segments identical to main.tscn (StaticBody2D default layer = 1).
	var walls := StaticBody2D.new()
	var poly := CollisionPolygon2D.new()
	poly.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	poly.polygon = PackedVector2Array(POLY)
	walls.add_child(poly)
	_room.add_child(walls)
	Helpers.set_floor_polygon_from_node(poly)

	var scene := load(CHAR_SCENE) as PackedScene
	if scene == null:
		fail("male-old-character.tscn failed to load")
		return
	_char = scene.instantiate() as CharacterBody2D
	_char.position = spawn
	_room.add_child(_char)
	var shape := _char.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_foot_offset = shape.position if shape != null else Vector2.ZERO
	_release_all()
	await wait_frames(2)


func _foot() -> Vector2:
	return _char.position + _foot_offset


func _drive(actions: Array, frames: int) -> void:
	for action: String in actions:
		Input.action_press(action, 1.0)
	for _i in range(frames):
		await get_tree().physics_frame
	_release_all()


func _release_all() -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)


func test_character_reaches_the_back_wall() -> void:
	# Foot starts at (646, 340); the wall corner base is at y=263.
	await _setup_room_and_character(Vector2(640, 289))
	await _drive(["ui_up"], DRIVE_FRAMES)
	var foot := _foot()
	# Pre-fix the feet stalled around y=353 (head hit the old boundary).
	assert_true(foot.y <= 305.0, "feet should get near the wall base, got y=%.1f" % foot.y)
	assert_true(Helpers.is_inside_floor(foot), "foot must stay on the floor at the top")


func test_character_reaches_the_front_edge_without_leaving() -> void:
	# Foot starts at (646, 540); the floor's front tip is at y=606.
	await _setup_room_and_character(Vector2(640, 489))
	await _drive(["ui_down"], DRIVE_FRAMES)
	var foot := _foot()
	assert_true(foot.y >= 575.0, "feet should reach near the front edge, got y=%.1f" % foot.y)
	assert_true(Helpers.is_inside_floor(foot), "foot must never exit at the bottom")
	# Depth ordering is live: z tracks the foot contact row.
	assert_eq(_char.z_index, Helpers.z_for_foot_y(foot.y), "z_index follows foot y")


func test_character_slides_along_the_bottom_left_diagonal() -> void:
	# Foot starts at (500, 500), pushing down-left into the SW edge: the old
	# oversized diamond let the character walk out of the visible room here.
	await _setup_room_and_character(Vector2(494, 449))
	await _drive(["ui_down", "ui_left"], DRIVE_FRAMES)
	var foot := _foot()
	assert_true(foot.x < 500.0, "character should have moved (slid along the edge)")
	assert_true(Helpers.is_inside_floor(foot), "foot must stay inside on the diagonal, got %s" % foot)


func test_zz_teardown_movement() -> void:
	_teardown()
	assert_true(true)


func _teardown() -> void:
	_release_all()
	if _room != null and is_instance_valid(_room):
		_room.queue_free()
		_room = null
		_char = null
