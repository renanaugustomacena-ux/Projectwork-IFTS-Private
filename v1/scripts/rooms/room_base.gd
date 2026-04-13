## RoomBase — Manages modular room: decoration spawning and character display.
extends Node2D

const DecorationScript := preload("res://scripts/rooms/decoration_system.gd")

## Collision footprint ratios — only the bottom portion blocks movement.
const COLLISION_WIDTH_RATIO := 0.7
const COLLISION_HEIGHT_RATIO := 0.3
## Interaction area extends slightly beyond collision so character can reach.
const INTERACTION_PADDING := 8.0

const CHARACTER_SCENES := {
	"male_old": "res://scenes/male-old-character.tscn",
	"female": "res://scenes/female-character.tscn",
	"male": "res://scenes/male-character.tscn",
}

## Pet variants. The active one is selected via SaveManager setting "pet_variant"
## (values: "simple" — original 16x16 strip; "iso" — 32x32 isometric strip).
const PET_SCENES := {
	"simple": "res://scenes/cat_void.tscn",
	"iso": "res://scenes/cat_void_iso.tscn",
}
const PET_VARIANT_DEFAULT := "simple"

@onready var decorations_container: Node2D = $Decorations
@onready var character_node: Node2D = $Character
@onready var _floor_bounds_node: CollisionPolygon2D = $RoomBounds/FloorBounds


func _ready() -> void:
	SignalBus.character_changed.connect(_on_character_changed)
	SignalBus.decoration_placed.connect(_on_decoration_placed)
	SignalBus.load_completed.connect(_on_load_completed)
	_setup_floor_bounds()
	_reload_decorations()
	_spawn_pet()
	# Apply character chosen in main menu (signal fired before this scene loaded)
	if GameManager.current_character_id != "male_old":
		call_deferred("_on_character_changed", GameManager.current_character_id)


func _setup_floor_bounds() -> void:
	if _floor_bounds_node == null:
		push_warning("RoomBase: FloorBounds node not found at $RoomBounds/FloorBounds")
		return
	Helpers.set_floor_polygon_from_node(_floor_bounds_node)


func _on_load_completed() -> void:
	_reload_decorations()


func _on_character_changed(character_id: String) -> void:
	var scene_path: String = CHARACTER_SCENES.get(character_id, "")
	if scene_path.is_empty():
		push_warning("RoomBase: no scene for character '%s'" % character_id)
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("RoomBase: failed to load scene '%s'" % scene_path)
		return
	var old_pos := character_node.position
	var old_scale := character_node.scale
	character_node.queue_free()
	var new_char := scene.instantiate()
	new_char.name = "Character"
	new_char.position = old_pos
	new_char.scale = old_scale
	call_deferred("add_child", new_char)
	character_node = new_char


func _on_decoration_placed(item_id: String, pos: Vector2) -> void:
	var item_data := _find_item_data(item_id)
	if item_data.is_empty():
		return
	var item_scale: float = item_data.get("item_scale", 1.0)
	var deco_data := {
		"item_id": item_id,
		"position": Helpers.vec2_to_array(pos),
		"item_scale": item_scale,
		"rotation": 0.0,
		"flip_h": false,
	}
	# Check if placement would overlap with character and nudge if needed
	var char_pos := character_node.position
	var tex_data := _get_texture_for_id(item_id)
	if tex_data != null:
		var deco_rect := Rect2(pos, tex_data.get_size() * item_scale)
		if deco_rect.has_point(char_pos):
			# Nudge character out of overlap (push to nearest edge)
			var nudge_pos := _find_nearest_free_position(char_pos, deco_rect)
			character_node.position = nudge_pos
	SaveManager.add_decoration(deco_data)
	_spawn_decoration(item_id, pos, item_scale, 0.0, false, deco_data)
	SignalBus.save_requested.emit()


func _reload_decorations() -> void:
	for child in decorations_container.get_children():
		child.queue_free()

	for deco_data in SaveManager.get_decorations():
		var item_id: String = deco_data.get("item_id", "")
		if _find_item_data(item_id).is_empty():
			push_warning("RoomBase: skipping unknown decoration '%s'" % item_id)
			continue
		var pos: Array = deco_data.get("position", [0, 0])
		var item_scale: float = deco_data.get("item_scale", 1.0)
		var rot: float = deco_data.get("rotation", 0.0)
		var flipped: bool = deco_data.get("flip_h", false)
		var pos_vec := Helpers.array_to_vec2(pos)
		# Trust saved positions — don't re-clamp on reload (causes position shift)
		_spawn_decoration(item_id, pos_vec, item_scale, rot, flipped, deco_data)


func _spawn_decoration(
	item_id: String, pos: Vector2, item_scale: float,
	rot: float = 0.0, flipped: bool = false, deco_data: Dictionary = {}
) -> void:
	var item_data := _find_item_data(item_id)
	if item_data.is_empty():
		return
	var sprite_path: String = item_data.get("sprite_path", "")
	if sprite_path.is_empty():
		return

	var texture := load(sprite_path) as Texture2D
	if texture == null:
		return

	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(item_scale, item_scale)
	sprite.position = pos
	sprite.rotation_degrees = rot
	sprite.flip_h = flipped
	sprite.name = item_id

	if DecorationScript:
		sprite.set_script(DecorationScript)
		sprite.item_id = item_id
		sprite.base_item_scale = item_scale
		sprite.deco_data = deco_data

	# --- Collision: footprint-based (bottom portion only) ---
	# Only the base of the decoration blocks movement, not the full sprite.
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex_size := texture.get_size()
	var foot_w := tex_size.x * COLLISION_WIDTH_RATIO
	var foot_h := tex_size.y * COLLISION_HEIGHT_RATIO
	rect.size = Vector2(foot_w, foot_h)
	# Position at bottom-center of the texture (sprites are non-centered)
	shape.shape = rect
	shape.position = Vector2(tex_size.x * 0.5, tex_size.y - foot_h * 0.5)
	body.add_child(shape)
	sprite.add_child(body)

	# --- Interaction Area2D for interactable furniture ---
	var interaction_type: String = item_data.get("interaction_type", "")
	if not interaction_type.is_empty():
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1  # Detect character (layer 1)
		area.monitoring = true
		area.monitorable = false
		area.set_meta("interaction_type", interaction_type)
		area.set_meta("item_id", item_id)
		var area_shape := CollisionShape2D.new()
		var area_rect := RectangleShape2D.new()
		# Interaction zone slightly larger than collision footprint
		area_rect.size = Vector2(
			foot_w + INTERACTION_PADDING * 2.0,
			foot_h + INTERACTION_PADDING * 2.0
		)
		area_shape.shape = area_rect
		area_shape.position = Vector2(tex_size.x * 0.5, tex_size.y - foot_h * 0.5)
		area.add_child(area_shape)
		area.body_entered.connect(_on_interaction_body_entered.bind(area))
		area.body_exited.connect(_on_interaction_body_exited.bind(area))
		sprite.add_child(area)

	decorations_container.add_child(sprite)


func _on_interaction_body_entered(body: Node2D, area: Area2D) -> void:
	if body is CharacterBody2D:
		var itype: String = area.get_meta("interaction_type", "")
		var iid: String = area.get_meta("item_id", "")
		SignalBus.interaction_available.emit(iid, itype)


func _on_interaction_body_exited(body: Node2D, _area: Area2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_unavailable.emit()


func _find_nearest_free_position(char_pos: Vector2, blocked: Rect2) -> Vector2:
	var cx: float = clampf(char_pos.x, blocked.position.x, blocked.end.x)
	var cy: float = clampf(char_pos.y, blocked.position.y, blocked.end.y)
	var dist_left: float = abs(cx - blocked.position.x)
	var dist_right: float = abs(cx - blocked.end.x)
	var dist_top: float = abs(cy - blocked.position.y)
	var dist_bottom: float = abs(cy - blocked.end.y)
	var min_dist: float = minf(minf(dist_left, dist_right), minf(dist_top, dist_bottom))
	if min_dist == dist_left:
		return Vector2(blocked.position.x - 20.0, char_pos.y)
	if min_dist == dist_right:
		return Vector2(blocked.end.x + 20.0, char_pos.y)
	if min_dist == dist_top:
		return Vector2(char_pos.x, blocked.position.y - 20.0)
	return Vector2(char_pos.x, blocked.end.y + 20.0)


func _get_texture_for_id(item_id: String) -> Texture2D:
	var item_data := _find_item_data(item_id)
	var path: String = item_data.get("sprite_path", "")
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _spawn_pet() -> void:
	var variant: String = SaveManager.get_setting("pet_variant", PET_VARIANT_DEFAULT)
	var scene_path: String = PET_SCENES.get(variant, PET_SCENES[PET_VARIANT_DEFAULT])
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("RoomBase: pet scene not found (%s)" % scene_path)
		return
	var pet := scene.instantiate()
	pet.name = "Pet"
	# Spawn near the character, offset to the right
	var char_pos := character_node.position
	pet.position = Vector2(
		char_pos.x + 60.0,
		char_pos.y + 20.0,
	)
	add_child(pet)


func _exit_tree() -> void:
	if SignalBus.character_changed.is_connected(_on_character_changed):
		SignalBus.character_changed.disconnect(_on_character_changed)
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)


func _find_item_data(item_id: String) -> Dictionary:
	var catalog: Dictionary = GameManager.decorations_catalog
	for deco in catalog.get("decorations", []):
		if deco is Dictionary and deco.get("id", "") == item_id:
			return deco
	return {}
