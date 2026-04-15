## CharacterController — Top-down movement for the cozy room character.
extends CharacterBody2D

const SPEED := 800.0  # DIAGNOSTICA TEMPORANEA: era 120.0, alzato per rendere il movimento impossibile da missare visivamente. Riabbassare dopo conferma fix.
const DIRECTION_THRESHOLD := 1.2

var _last_direction := Vector2.DOWN
var _last_anim: String = ""
var _ui_panel_open: bool = false
var _debug_input_logs_remaining: int = 500
var _debug_block_logs_remaining: int = 5

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Collide with room walls (layer 1) and decorations (layer 2)
	collision_mask = 3
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)
	SignalBus.panel_opened.connect(_on_panel_opened)
	SignalBus.panel_closed.connect(_on_panel_closed)


func _exit_tree() -> void:
	if SignalBus.decoration_mode_changed.is_connected(_on_decoration_mode_changed):
		SignalBus.decoration_mode_changed.disconnect(_on_decoration_mode_changed)
	if SignalBus.panel_opened.is_connected(_on_panel_opened):
		SignalBus.panel_opened.disconnect(_on_panel_opened)
	if SignalBus.panel_closed.is_connected(_on_panel_closed):
		SignalBus.panel_closed.disconnect(_on_panel_closed)


func _on_decoration_mode_changed(active: bool) -> void:
	if active:
		# In edit mode, ignore decoration collisions so dragging doesn't push us
		collision_mask = 1
	else:
		collision_mask = 3


func _on_panel_opened(_panel_name: String) -> void:
	_ui_panel_open = true


func _on_panel_closed(_panel_name: String) -> void:
	_ui_panel_open = false


func _physics_process(_delta: float) -> void:
	# Blocca il movimento solo se un UI panel e' effettivamente aperto.
	# Tracciamo lo stato via SignalBus.panel_opened/panel_closed invece di
	# ispezionare gui_get_focus_owner(), che e' un proxy fragile: in Godot 4.5
	# qualunque Control focusable residuo (anche invisibile o non intenzionale)
	# ritorna non-null e blocca per sempre l'input del character. Lo stato
	# signal-driven riflette l'intent reale (l'utente sta interagendo con
	# un pannello) senza dipendere dal focus chain.
	if _ui_panel_open:
		if _debug_block_logs_remaining > 0:
			_debug_block_logs_remaining -= 1
			AppLogger.info(
				"CharCtrl",
				"blocked by ui_panel_open",
				{"pos": position}
			)
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)
	if direction != Vector2.ZERO and _debug_input_logs_remaining > 0:
		_debug_input_logs_remaining -= 1
		var focus_node := get_viewport().gui_get_focus_owner()
		var focus_name: String = "null"
		if focus_node != null:
			focus_name = "%s (%s)" % [focus_node.name, focus_node.get_class()]
		AppLogger.info(
			"CharCtrl",
			"input received",
			{
				"dir": direction,
				"pos": position,
				"collision_mask": collision_mask,
				"focus_owner": focus_name,
				"panel_open_flag": _ui_panel_open,
			}
		)
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
