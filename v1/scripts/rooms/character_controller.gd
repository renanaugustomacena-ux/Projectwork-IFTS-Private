## CharacterController — Top-down movement for the cozy room character.
extends CharacterBody2D

const SPEED := 120.0

var _last_direction := Vector2.DOWN

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	if direction.length() < 0.1:
		_play_idle()
		return
	_last_direction = direction
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	if abs_x > abs_y * 1.5:
		_anim.flip_h = direction.x < 0
		_anim.play("walk_side")
	elif abs_y > abs_x * 1.5:
		if direction.y > 0:
			_anim.play("walk_down")
		else:
			_anim.play("walk_up")
	elif direction.y > 0:
		_anim.flip_h = direction.x < 0
		_anim.play("walk_side_down")
	else:
		_anim.flip_h = direction.x < 0
		_anim.play("walk_side_up")


func _play_idle() -> void:
	var abs_x := absf(_last_direction.x)
	var abs_y := absf(_last_direction.y)
	if abs_x > abs_y:
		_anim.play("idle_side")
	elif _last_direction.y > 0:
		_anim.play("idle_down")
	else:
		_anim.play("idle_up")
