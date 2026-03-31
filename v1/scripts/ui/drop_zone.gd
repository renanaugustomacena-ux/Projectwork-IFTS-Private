## DropZone — Transparent Control overlay that bridges UI drag-and-drop to game world.
## Catches drop events from DecoPanel and relays them to room placement logic.
extends Control

const WALL_ZONE_RATIO := 0.4


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drop(data):
		return false

	if not _is_zone_valid(at_position, data.get("placement_type", "any")):
		return false

	return true


func _is_valid_drop(data: Variant) -> bool:
	return data is Dictionary and "item_id" in data


func _is_zone_valid(at_position: Vector2, placement_type: String) -> bool:
	var floor_y: float = size.y * WALL_ZONE_RATIO
	match placement_type:
		"floor":
			return at_position.y > floor_y
		"wall":
			return at_position.y <= floor_y
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item_id: String = data.get("item_id", "")
	var item_scale: float = data.get("item_scale", 1.0)
	at_position = Helpers.snap_to_grid(at_position)
	var tex := _get_texture_for_item(item_id)
	if tex:
		var tex_size := tex.get_size() * item_scale
		at_position.x = clampf(at_position.x, 0.0, size.x - tex_size.x)
		at_position.y = clampf(at_position.y, 0.0, size.y - tex_size.y)
	SignalBus.decoration_placed.emit(item_id, at_position)


func _get_texture_for_item(item_id: String) -> Texture2D:
	var catalog: Dictionary = GameManager.decorations_catalog
	for deco in catalog.get("decorations", []):
		if deco is Dictionary and deco.get("id", "") == item_id:
			var path: String = deco.get("sprite_path", "")
			if not path.is_empty():
				var tex := load(path) as Texture2D
				if tex == null:
					push_warning("DropZone: texture non trovata: %s" % path)
				return tex
	return null
