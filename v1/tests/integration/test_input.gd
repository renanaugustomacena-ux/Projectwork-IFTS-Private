## test_input — character movement via simulated Input.action_press.
##
## Instantiates male-old-character.tscn standalone and drives WASD via Input
## input map. Tests verify velocity, animation, flip_h. Does NOT mount into
## main.tscn (avoids coupling with room logic).
extends "res://tests/integration/test_base.gd"

const CHAR_SCENE := "res://scenes/male-old-character.tscn"

var _char: CharacterBody2D = null


func _setup_character() -> void:
	if _char != null and is_instance_valid(_char):
		_char.queue_free()
		await wait_frames(1)
	var scene := load(CHAR_SCENE) as PackedScene
	if scene == null:
		fail("male-old-character.tscn failed to load")
		return
	_char = scene.instantiate() as CharacterBody2D
	if _char == null:
		fail("scene root is not a CharacterBody2D")
		return
	_char.position = Vector2(640, 400)
	add_child(_char)
	# Release any pressed actions from previous tests
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)
	await wait_frames(2)


func _simulate_action_for_frames(action: String, frames: int) -> void:
	Input.action_press(action, 1.0)
	for _i in range(frames):
		await get_tree().physics_frame
	# Don't release here — caller chooses when


func _release_all() -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)


# ---- Character scene smoke ----


func test_character_scene_instantiates() -> void:
	await _setup_character()
	assert_non_null(_char)
	assert_true(_char is CharacterBody2D)
	# Scene root node name is "CharacterBody2D" (generic) — we rely on
	# the caller (room_base.gd) to rename it to "Character" after instantiate.
	assert_eq(_char.collision_mask, 3, "character should collide with walls (1) + decorations (2)")


func test_character_has_animated_sprite() -> void:
	await _setup_character()
	var anim := _char.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_non_null(anim, "male_old requires AnimatedSprite2D child")
	assert_non_null(anim.sprite_frames)


func test_character_animations_registered() -> void:
	await _setup_character()
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	# Check for the animations character_controller.gd references
	var required := [
		"idle_down", "idle_up", "idle_side",
		"idle_vertical_down", "idle_vertical_up",
		"walk_down", "walk_up", "walk_side",
		"walk_side_down", "walk_side_up",
	]
	var missing: Array[String] = []
	for anim_name in required:
		if not anim.sprite_frames.has_animation(anim_name):
			missing.append(anim_name)
	if not missing.is_empty():
		fail("animations missing on male_old: %s" % ", ".join(missing))
	else:
		assert_true(true, "all required animations present")


# ---- Movement ----


func test_right_input_sets_positive_x_velocity() -> void:
	await _setup_character()
	Input.action_press("ui_right", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(_char.velocity.x > 0.0,
		"ui_right should produce positive x velocity, got %f" % _char.velocity.x)
	_release_all()


func test_left_input_sets_negative_x_velocity() -> void:
	await _setup_character()
	Input.action_press("ui_left", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(_char.velocity.x < 0.0,
		"ui_left should produce negative x velocity, got %f" % _char.velocity.x)
	_release_all()


func test_up_input_sets_negative_y_velocity() -> void:
	await _setup_character()
	Input.action_press("ui_up", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(_char.velocity.y < 0.0,
		"ui_up should produce negative y velocity, got %f" % _char.velocity.y)
	_release_all()


func test_down_input_sets_positive_y_velocity() -> void:
	await _setup_character()
	Input.action_press("ui_down", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(_char.velocity.y > 0.0,
		"ui_down should produce positive y velocity, got %f" % _char.velocity.y)
	_release_all()


func test_release_stops_movement() -> void:
	await _setup_character()
	Input.action_press("ui_right", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(_char.velocity.x > 0.0)
	Input.action_release("ui_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_approx(_char.velocity.x, 0.0, 0.1,
		"releasing input must zero velocity, got %f" % _char.velocity.x)


func test_diagonal_input_normalized_speed() -> void:
	await _setup_character()
	Input.action_press("ui_right", 1.0)
	Input.action_press("ui_down", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Diagonal should be normalized — not SPEED on each axis, but SPEED total
	var speed := _char.velocity.length()
	assert_approx(speed, 120.0, 0.5,
		"diagonal must be normalized to SPEED=120, got %f" % speed)
	_release_all()


# ---- Animation response ----


func test_right_input_plays_walk_side() -> void:
	await _setup_character()
	Input.action_press("ui_right", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert_eq(anim.animation, StringName("walk_side"),
		"expected walk_side, got %s" % anim.animation)
	assert_false(anim.flip_h, "facing right must not flip")
	_release_all()


func test_left_input_plays_walk_side_with_flip() -> void:
	await _setup_character()
	Input.action_press("ui_left", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert_eq(anim.animation, StringName("walk_side"))
	assert_true(anim.flip_h, "facing left must flip horizontally")
	_release_all()


func test_down_input_plays_walk_down() -> void:
	await _setup_character()
	Input.action_press("ui_down", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert_eq(anim.animation, StringName("walk_down"))
	_release_all()


func test_up_input_plays_walk_up() -> void:
	await _setup_character()
	Input.action_press("ui_up", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert_eq(anim.animation, StringName("walk_up"))
	_release_all()


func test_idle_animation_after_release() -> void:
	await _setup_character()
	Input.action_press("ui_right", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("ui_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anim := _char.get_node("AnimatedSprite2D") as AnimatedSprite2D
	# After releasing, should enter an idle_* animation (based on _last_direction)
	var name := String(anim.animation)
	assert_true(name.begins_with("idle_"),
		"after release must play idle_*, got %s" % name)
