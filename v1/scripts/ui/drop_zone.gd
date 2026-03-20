## DropZone — Transparent Control overlay that bridges UI drag-and-drop to game world.
## Catches drop events from DecoPanel and relays them to room placement logic.
extends Control

const WALL_ZONE_RATIO := 0.4
const OVERLAP_THRESHOLD := 0.5


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drop(data):
		return false

	if not _is_zone_valid(at_position, data.get("placement_type", "any")):
		return false

	var sprite_path: String = data.get("sprite_path", "")
	var tex := load(sprite_path) as Texture2D if not sprite_path.is_empty() else null
	if tex == null:
		return false

	var item_scale: float = data.get("item_scale", 1.0)
	var snapped := Helpers.snap_to_grid(at_position)
	var new_rect := Rect2(snapped, tex.get_size() * item_scale)
	return not _has_overlap(new_rect)


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


func _has_overlap(new_rect: Rect2) -> bool:
	for deco_data in SaveManager.decorations:
		var existing_pos := Helpers.array_to_vec2(deco_data.get("position", [0, 0]))
		var existing_scale: float = deco_data.get("item_scale", 1.0)
		var existing_id: String = deco_data.get("item_id", "")

		var existing_tex := _get_texture_for_item(existing_id)
		if existing_tex == null:
			continue

		var existing_size: Vector2 = existing_tex.get_size() * existing_scale
		var existing_rect := Rect2(existing_pos, existing_size)

		var intersection := new_rect.intersection(existing_rect)
		if intersection.has_area():
			var overlap_area := intersection.get_area()
			var smaller_area := minf(new_rect.get_area(), existing_rect.get_area())
			if smaller_area > 0 and overlap_area / smaller_area > OVERLAP_THRESHOLD:
				return true
	return false


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
				return load(path) as Texture2D
	return null
