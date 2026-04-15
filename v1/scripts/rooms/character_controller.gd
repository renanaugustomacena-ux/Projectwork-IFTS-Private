## CharacterController — Top-down movement for the cozy room character.
extends CharacterBody2D

const SPEED := 120.0
const DIRECTION_THRESHOLD := 1.2

var _last_direction := Vector2.DOWN
var _last_anim: String = ""
var _dbg_boot_logs := 5
var _dbg_move_logs := 30

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Collide with room walls (layer 1) and decorations (layer 2)
	collision_mask = 3
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)
	AppLogger.info(
		"CharCtrl",
		"ready",
		{
			"start_pos": position,
			"collision_layer": collision_layer,
			"collision_mask": collision_mask,
			"motion_mode": motion_mode,
			"anim_node": "ok" if _anim != null else "NULL",
		}
	)


func _exit_tree() -> void:
	if SignalBus.decoration_mode_changed.is_connected(_on_decoration_mode_changed):
		SignalBus.decoration_mode_changed.disconnect(_on_decoration_mode_changed)


func _on_decoration_mode_changed(active: bool) -> void:
	if active:
		# In edit mode, ignore decoration collisions so dragging doesn't push us
		collision_mask = 1
	else:
		collision_mask = 3


func _physics_process(_delta: float) -> void:
	# Block movement when a UI panel is open (prevents WASD from
	# moving the character while interacting with deco panel, etc.)
	var focus_node := get_viewport().gui_get_focus_owner()
	if focus_node != null:
		if _dbg_boot_logs > 0:
			_dbg_boot_logs -= 1
			AppLogger.info(
				"CharCtrl",
				"GATE BLOCKING",
				{
					"focus_owner": "%s (%s)" % [focus_node.name, focus_node.get_class()],
					"pos": position,
				}
			)
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)
	if direction != Vector2.ZERO and _dbg_move_logs > 0:
		_dbg_move_logs -= 1
		var pos_before := position
		velocity = direction.normalized() * SPEED
		move_and_slide()
		AppLogger.info(
			"CharCtrl",
			"input + move",
			{
				"dir": direction,
				"pos_before": pos_before,
				"pos_after": position,
				"delta": position - pos_before,
				"velocity_after": velocity,
			}
		)
		_update_animation(direction)
		return
	velocity = direction.normalized() * SPEED
	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	if _anim == null:
		return
	if direction.length() < 0.1:
		_play_idle()
		return
	_last_direction = direction
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	var anim_name: String
	if abs_x > abs_y * DIRECTION_THRESHOLD:
		_anim.flip_h = direction.x < 0
		anim_name = "walk_side"
	elif abs_y > abs_x * DIRECTION_THRESHOLD:
		anim_name = "walk_down" if direction.y > 0 else "walk_up"
	elif direction.y > 0:
		_anim.flip_h = direction.x < 0
		anim_name = "walk_side_down"
	else:
		_anim.flip_h = direction.x < 0
		anim_name = "walk_side_up"
	_play_anim(anim_name)


func _play_idle() -> void:
	if _anim == null:
		return
	var abs_x := absf(_last_direction.x)
	var abs_y := absf(_last_direction.y)
	var anim_name: String
	if abs_x > abs_y * DIRECTION_THRESHOLD:
		anim_name = "idle_side"
	elif abs_y > abs_x * DIRECTION_THRESHOLD:
		anim_name = "idle_down" if _last_direction.y > 0 else "idle_up"
	elif _last_direction.y > 0:
		anim_name = "idle_vertical_down"
	else:
		anim_name = "idle_vertical_up"
	_play_anim(anim_name)


func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	if anim_name != _last_anim:
		_last_anim = anim_name
		_anim.play(anim_name)
