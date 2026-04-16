## DropZone — Transparent Control overlay that bridges UI drag-and-drop to game world.
## Catches drop events from DecoPanel and relays them to room placement logic.
extends Control

const WALL_ZONE_RATIO := 0.4


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drop(data):
		return false
	# Enforce wall vs floor placement zones
	var placement_type: String = data.get("placement_type", "any")
	if not _is_zone_valid(at_position, placement_type):
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
	var raw_pos := at_position
	# Shift tenuto premuto al drop → no snap grid (placement fine, fix B-005)
	if not Input.is_key_pressed(KEY_SHIFT):
		at_position = Helpers.snap_to_grid(at_position)
	# Clamp inside room floor polygon so decorations can't escape. Se floor
	# polygon non e` stato inizializzato (RoomBase._setup_floor_bounds ha fallito),
	# clamp_inside_floor ritorna il punto invariato → decorazione puo` finire
	# fuori viewport e risultare invisibile. Logging esplicito per diagnosi
	# (fix BUG-C-001).
	if not Helpers.has_floor_polygon():
		AppLogger.warn(
			"DropZone",
			"floor_polygon_not_initialized",
			{"item_id": item_id, "raw_pos": raw_pos, "snap_pos": at_position}
		)
		SignalBus.toast_requested.emit(
			"Stanza non pronta, riprova fra un attimo", "warning"
		)
		return
	at_position = Helpers.clamp_inside_floor(at_position)
	AppLogger.info(
		"DropZone",
		"drop_accepted",
		{"item_id": item_id, "raw_pos": raw_pos, "final_pos": at_position}
	)
	SignalBus.decoration_placed.emit(item_id, at_position)


## DropZone is inside a CanvasLayer with no Camera2D, so canvas coordinates
## equal world coordinates. We add the Control's global position to lift a
## local point into world space.
func _to_world(local_point: Vector2) -> Vector2:
	return global_position + local_point


func _from_world(world_point: Vector2) -> Vector2:
	return world_point - global_position


func _floor_anchor_for(at_position: Vector2, data: Variant) -> Vector2:
	var item_id: String = data.get("item_id", "")
	var item_scale: float = data.get("item_scale", 1.0)
	var tex := _get_texture_for_item(item_id)
	if tex == null:
		return at_position
	var tex_size := tex.get_size() * item_scale
	return at_position + Vector2(tex_size.x * 0.5, tex_size.y)


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
