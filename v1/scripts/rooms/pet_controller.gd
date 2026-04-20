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
var _rng := RandomNumberGenerator.new()

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_home_position = position
	collision_mask = 1  # Walls only, don't collide with decorations
	collision_layer = 0  # Don't block anything
	# B-030: seed deterministico in debug per riproducibilita` FSM pet
	if OS.is_debug_build():
		_rng.seed = Constants.DEBUG_RNG_SEED + 2
	else:
		_rng.randomize()
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
	_play_anim("idle")

	if _state_timer > _random_duration():
		var roll := _rng.randf()
		# Priorita` 1: dopo cooldown lungo, chance di dormire
		if _idle_timer > SLEEP_COOLDOWN and roll < 0.3:
			_set_state(State.SLEEP)
			return
		# Priorita` 2: se il personaggio si e` allontanato, vai a seguirlo
		if _character_ref and _is_far_from_character():
			_set_state(State.FOLLOW)
			return
		# Priorita` 3: altrimenti ~55% di probabilita` di iniziare a vagare
		# nella stanza (fix del gap pre-esistente: senza questa transizione
		# il gatto restava bloccato in idle fino al cooldown di 2 minuti).
		if roll < 0.55:
			_set_state(State.WANDER)
			return
		# Fallback: resetta il timer e resta idle ancora un momento
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


func _process_sleep(delta: float) -> void:
	velocity = Vector2.ZERO
	# No move_and_slide — sleeping pet must not drift
	_play_anim("sleep")

	# Gentle breathing scale pulse
	if _anim:
		var breath := 1.0 + sin(_state_timer * 1.5) * 0.03
		var base := absf(_anim.scale.x)
		_anim.scale = Vector2(base, base * breath)

	# Wake up after a while or if character is nearby
	if _state_timer > 15.0:
		_set_state(State.IDLE)
	elif _character_ref and _is_close_to_character():
		_set_state(State.PLAY)
		_idle_timer = 0.0


func _process_play(_delta: float) -> void:
	velocity = Vector2.ZERO
	# No move_and_slide — playing pet stays in place

	# Bounce animation
	if _anim:
		var bounce := absf(sin(_state_timer * 4.0)) * 3.0
		_anim.position.y = -bounce

	_play_anim("idle")

	if _state_timer > 3.0:
		_reset_anim_position()
		_set_state(State.FOLLOW)


func _set_state(new_state: State) -> void:
	if _state == State.SLEEP and new_state != State.SLEEP:
		_reset_anim_scale()
	_state = new_state
	_state_timer = 0.0
	if new_state == State.WANDER:
		_pick_wander_target()


func _pick_wander_target() -> void:
	var offset := Vector2(
		_rng.randf_range(-WANDER_RANGE, WANDER_RANGE),
		_rng.randf_range(-WANDER_RANGE * 0.3, WANDER_RANGE * 0.3),
	)
	_wander_target = _home_position + offset
	# Clamp to floor polygon instead of hardcoded rect
	_wander_target = Helpers.clamp_inside_floor(_wander_target)


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
	return _rng.randf_range(STATE_CHANGE_MIN, STATE_CHANGE_MAX)


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
