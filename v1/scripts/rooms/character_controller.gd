## CharacterController — Top-down movement for the cozy room character.
extends CharacterBody2D

const SPEED := 120.0
const DIRECTION_THRESHOLD := 1.2

var _last_direction := Vector2.DOWN
var _last_anim: String = ""
# Ground-contact point relative to the body origin. Read from the collision
# shape so the shape stays the single source of truth (the collider IS the
# feet — Q3 pattern: collision geometry is authoritative, visuals follow it).
var _foot_offset := Vector2.ZERO

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Collide with room walls (layer 1) and decorations (layer 2)
	collision_mask = 3
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		_foot_offset = shape_node.position
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)


func _exit_tree() -> void:
	if SignalBus.decoration_mode_changed.is_connected(_on_decoration_mode_changed):
		SignalBus.decoration_mode_changed.disconnect(_on_decoration_mode_changed)


func _on_decoration_mode_changed(active: bool) -> void:
	if active:
		# In edit mode, ignore decoration collisions so dragging doesn't push us
		collision_mask = 1
	else:
		collision_mask = 3
		# Sblocca il character se stiamo dentro una deco al rientro da edit:
		# durante edit ignora layer 2, puo` finire sopra una scrivania; al
		# ritorno a mask=3 senza nudge, move_and_slide non riesce a de-penetrare
		# e l'utente resta bloccato. (fix B-035)
		call_deferred("_nudge_out_of_decorations")


func _nudge_out_of_decorations() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var world := get_world_2d()
	if world == null:
		return
	var space := world.direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = global_transform * shape_node.transform
	query.collision_mask = 2  # solo deco layer
	query.exclude = [get_rid()]
	var results := space.intersect_shape(query, 8)
	if results.is_empty():
		return
	# Calcola vettore di push: somma direzioni "away from deco center", poi
	# step-out di 56px in quella direzione. Se ancora dentro dopo step, il
	# corpo verra` de-penetrato dal prossimo move_and_slide con mask=3 attivo.
	var push := Vector2.ZERO
	for entry in results:
		var body: Object = entry.get("collider")
		if body == null or not (body is Node2D):
			continue
		var body_pos: Vector2 = (body as Node2D).global_position
		var away := global_position - body_pos
		if away.length() > 0.01:
			push += away.normalized()
	if push.length() > 0.01:
		# Clamp the teleport target through the floor polygon: the raw 56px
		# step near a room edge could land OUTSIDE the boundary segments, and
		# from there the character could never walk back in (validate at the
		# boundary — every teleport is a boundary, not just player input).
		var target := global_position + push.normalized() * 56.0
		global_position = Helpers.clamp_inside_floor(target + _foot_offset) - _foot_offset


func _physics_process(_delta: float) -> void:
	# Block movement when a UI panel is open (prevents WASD from
	# moving the character while interacting with deco panel, etc.)
	if get_viewport().gui_get_focus_owner() != null:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction.normalized() * SPEED
	move_and_slide()
	# Belt-and-braces: the wall segments are thin lines, so any residual
	# tunneling (or a stale out-of-bounds save position) self-heals here.
	# No-op whenever the foot point is already inside the polygon.
	var foot := global_position + _foot_offset
	var clamped := Helpers.clamp_inside_floor(foot)
	if clamped != foot:
		global_position = clamped - _foot_offset
	# Depth: entities sort by ground contact — feet lower on screen = in front.
	z_index = Helpers.z_for_foot_y(global_position.y + _foot_offset.y)
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
