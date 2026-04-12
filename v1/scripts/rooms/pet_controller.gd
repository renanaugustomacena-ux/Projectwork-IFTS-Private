## PetController — Autonomous pet behavior with state machine.
## Manages idle, wander, follow, sleep, and play states.
extends CharacterBody2D

enum State { IDLE, WANDER, FOLLOW, SLEEP, PLAY }

const WANDER_SPEED := 30.0
const FOLLOW_SPEED := 80.0
const FOLLOW_DISTANCE := 120.0
const FOLLOW_STOP_DISTANCE := 40.0
const WANDER_RANGE := 200.0
const STATE_CHANGE_MIN := 3.0
const STATE_CHANGE_MAX := 8.0
const SLEEP_COOLDOWN := 120.0  # 2 min before considering sleep
const PLAY_RANGE := 60.0

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _idle_timer: float = 0.0
var _wander_target := Vector2.ZERO
var _home_position := Vector2.ZERO
var _character_ref: CharacterBody2D = null

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_home_position = position
	collision_mask = 1  # Walls only, don't collide with decorations
	collision_layer = 0  # Don't block anything
	_find_character()
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_state_timer += delta
	_idle_timer += delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.FOLLOW:
			_process_follow(delta)
		State.SLEEP:
			_process_sleep(delta)
		State.PLAY:
			_process_play(delta)


func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_play_anim("idle")

	if _state_timer > _random_duration():
		var roll := randf()
		if _idle_timer > SLEEP_COOLDOWN and roll < 0.2:
			_set_state(State.SLEEP)
		elif roll < 0.5:
			_set_state(State.WANDER)
		elif _character_ref and _is_far_from_character():
			_set_state(State.FOLLOW)
		else:
			# Reset timer for another idle period
			_state_timer = 0.0


func _process_wander(_delta: float) -> void:
	if _wander_target == Vector2.ZERO:
		_pick_wander_target()

	var dir := (_wander_target - position).normalized()
	velocity = dir * WANDER_SPEED
	move_and_slide()

	_anim.flip_h = dir.x < 0
	_play_anim("walk")

	# Reached target or timeout
	if position.distance_to(_wander_target) < 8.0:
		_set_state(State.IDLE)
	elif _state_timer > 6.0:
		_set_state(State.IDLE)


func _process_follow(_delta: float) -> void:
	if _character_ref == null or not is_instance_valid(_character_ref):
		_find_character()
		if _character_ref == null:
			_set_state(State.IDLE)
			return

	var char_pos := _character_ref.global_position
	var dist := position.distance_to(char_pos)

	if dist < FOLLOW_STOP_DISTANCE:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.IDLE)
		_idle_timer = 0.0  # Reset sleep timer when near character
		return

	var dir := (char_pos - position).normalized()
	velocity = dir * FOLLOW_SPEED
	move_and_slide()

	_anim.flip_h = dir.x < 0
	_play_anim("walk")

	if _state_timer > 10.0:
		_set_state(State.IDLE)


func _process_sleep(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_play_anim("sleep")

	# Slight scale pulse to simulate breathing
	if _anim:
		var breath := sin(_state_timer * 1.5) * 0.03
		_anim.scale = Vector2(
			_anim.scale.x,
			absf(_anim.scale.x) + breath
		)

	# Wake up after a while or if character is nearby
	if _state_timer > 15.0:
		_reset_anim_scale()
		_set_state(State.IDLE)
	elif _character_ref and _is_close_to_character():
		_reset_anim_scale()
		_set_state(State.PLAY)
		_idle_timer = 0.0


func _process_play(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	# Bounce animation
	if _anim:
		var bounce := absf(sin(_state_timer * 4.0)) * 3.0
		_anim.position.y = -bounce
		_anim.flip_h = not _anim.flip_h if fmod(
			_state_timer, 0.5
		) < 0.02 else _anim.flip_h

	_play_anim("idle")

	if _state_timer > 3.0:
		_reset_anim_position()
		_set_state(State.FOLLOW)


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_timer = 0.0
	if new_state == State.WANDER:
		_pick_wander_target()


func _pick_wander_target() -> void:
	var offset := Vector2(
		randf_range(-WANDER_RANGE, WANDER_RANGE),
		randf_range(-WANDER_RANGE * 0.3, WANDER_RANGE * 0.3),
	)
	_wander_target = _home_position + offset
	# Clamp to room bounds
	_wander_target.x = clampf(
		_wander_target.x, 100.0, 1180.0
	)
	_wander_target.y = clampf(
		_wander_target.y, 300.0, 650.0
	)


func _find_character() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var char_node := parent.get_node_or_null("Character")
	if char_node is CharacterBody2D:
		_character_ref = char_node


func _is_far_from_character() -> bool:
	if _character_ref == null:
		return false
	return position.distance_to(
		_character_ref.global_position
	) > FOLLOW_DISTANCE


func _is_close_to_character() -> bool:
	if _character_ref == null:
		return false
	return position.distance_to(
		_character_ref.global_position
	) < PLAY_RANGE


func _random_duration() -> float:
	return randf_range(STATE_CHANGE_MIN, STATE_CHANGE_MAX)


var _last_anim: String = ""

func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	if anim_name != _last_anim:
		_last_anim = anim_name
		if _anim.sprite_frames and _anim.sprite_frames.has_animation(anim_name):
			_anim.play(anim_name)
		elif _anim.sprite_frames and _anim.sprite_frames.has_animation("default"):
			_anim.play("default")


func _reset_anim_scale() -> void:
	if _anim:
		var base_scale := absf(_anim.scale.x)
		_anim.scale = Vector2(base_scale, base_scale)


func _reset_anim_position() -> void:
	if _anim:
		_anim.position.y = 0.0
