## RoomBase — Manages modular room: decoration spawning and character display.
extends Node2D

const DecorationScript := preload("res://scripts/rooms/decoration_system.gd")

const CHARACTER_SCENES := {
	"male_yellow_shirt": "res://scenes/male-character.tscn",
	"female_red_shirt": "res://scenes/female-character.tscn",
}

@onready var decorations_container: Node2D = $Decorations
@onready var character_node: Node2D = $Character


func _ready() -> void:
	SignalBus.character_changed.connect(_on_character_changed)
	SignalBus.decoration_placed.connect(_on_decoration_placed)
	SignalBus.load_completed.connect(_on_load_completed)
	_reload_decorations()


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
	add_child(new_char)
	character_node = new_char


func _on_decoration_placed(item_id: String, pos: Vector2) -> void:
	var item_data := _find_item_data(item_id)
	if item_data.is_empty():
		return
	var item_scale: float = item_data.get("item_scale", 1.0)
	_spawn_decoration(item_id, pos, item_scale)
	(
		SaveManager
		. decorations
		. append(
			{
				"item_id": item_id,
				"position": Helpers.vec2_to_array(pos),
				"item_scale": item_scale,
			}
		)
	)
	SignalBus.save_requested.emit()


func _reload_decorations() -> void:
	for child in decorations_container.get_children():
		child.queue_free()

	for deco_data in SaveManager.decorations:
		var item_id: String = deco_data.get("item_id", "")
		if _find_item_data(item_id).is_empty():
			push_warning("RoomBase: skipping unknown decoration '%s'" % item_id)
			continue
		var pos: Array = deco_data.get("position", [0, 0])
		var item_scale: float = deco_data.get("item_scale", 1.0)
		_spawn_decoration(item_id, Helpers.array_to_vec2(pos), item_scale)


func _spawn_decoration(item_id: String, pos: Vector2, item_scale: float) -> void:
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
	sprite.name = item_id

	if DecorationScript:
		sprite.set_script(DecorationScript)
		sprite.item_id = item_id

	decorations_container.add_child(sprite)


func _find_item_data(item_id: String) -> Dictionary:
	var catalog: Dictionary = GameManager.decorations_catalog
	for deco in catalog.get("decorations", []):
		if deco is Dictionary and deco.get("id", "") == item_id:
			return deco
	return {}
