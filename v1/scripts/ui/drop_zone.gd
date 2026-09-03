## DropZone — Transparent Control overlay that bridges UI drag-and-drop to game world.
## Catches drop events from DecoPanel and relays them to room placement logic.
##
## Placement rules are enforced HERE, at the boundary where the item enters
## the world (module 23: validate at the boundary, trust inside). The same
## geometry (floor polygon, wall band) that clamps drags in decoration_system
## validates drops here, so the two paths can never disagree.
extends Control

## How far (px) a drop may miss its legal zone and still be accepted+clamped.
## Beyond the slack the drop is refused outright and Godot shows the
## "forbidden" cursor — a window can no longer be parked on the floor.
const FLOOR_DROP_SLACK := 120.0
const WALL_DROP_SLACK := 90.0

var _last_hint_msec: int = -100000


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drop(data):
		AppLogger.info("DropZone", "can_drop_invalid_data", {"data_type": typeof(data)})
		return false
	var placement_type := Helpers.placement_type_of(data)
	if not _is_zone_valid(at_position, placement_type, data):
		AppLogger.info("DropZone", "can_drop_zone_invalid", {"pos": at_position, "placement_type": placement_type})
		_hint_invalid_zone(placement_type)
		return false
	return true


## Un toast al massimo ogni 2 s durante il trascinamento: prima l'unico
## segnale era il cursore "vietato" e il rilascio spariva nel nulla (PT-11).
func _hint_invalid_zone(placement_type: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hint_msec < 2000:
		return
	_last_hint_msec = now
	var key := "TOAST_DROP_INVALID_WALL" if placement_type == "wall" else "TOAST_DROP_INVALID_FLOOR"
	SignalBus.toast_requested.emit(tr(key), "warning")


func _is_valid_drop(data: Variant) -> bool:
	return data is Dictionary and "item_id" in data


## Zone check with the item's real geometry: the drop is valid when the
## clamped position is within the slack of where the user dropped. Uses the
## same clamps as drag/spawn — one source of truth for "legal placement".
func _is_zone_valid(at_position: Vector2, placement_type: String, data: Dictionary) -> bool:
	var item_size := _item_world_size(data)
	if placement_type == "wall":
		if not Helpers.has_wall_band():
			return true
		var center := at_position + item_size * 0.5
		return center.distance_to(Helpers.clamp_wall_anchor(center, item_size * 0.5)) <= WALL_DROP_SLACK
	if not Helpers.has_floor_polygon():
		return true
	var anchor := at_position + Vector2(item_size.x * 0.5, item_size.y)
	return anchor.distance_to(Helpers.clamp_inside_floor(anchor)) <= FLOOR_DROP_SLACK


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item_id: String = data.get("item_id", "")
	var placement_type := Helpers.placement_type_of(data)
	var raw_pos := at_position
	# Pixel-precise drop: no snap. Shift held → optional 64px grid snap.
	if Input.is_key_pressed(KEY_SHIFT):
		at_position = Helpers.snap_to_grid(at_position)
	if not Helpers.has_floor_polygon():
		AppLogger.warn(
			"DropZone",
			"floor_polygon_not_initialized",
			{"item_id": item_id, "raw_pos": raw_pos, "snap_pos": at_position}
		)
		SignalBus.toast_requested.emit(tr("TOAST_ROOM_NOT_READY"), "warning")
		return
	var item_size := _item_world_size(data)
	if placement_type == "wall":
		# Clamp the whole rect onto the wall band (center-based).
		var center := at_position + item_size * 0.5
		at_position = Helpers.clamp_wall_anchor(center, item_size * 0.5) - item_size * 0.5
	else:
		# Clamp the FOOT anchor (bottom-center), not the raw top-left: near
		# the front edge the old point-clamp left the sprite's whole height
		# hanging outside the room.
		var offset := Vector2(item_size.x * 0.5, item_size.y)
		at_position = Helpers.clamp_inside_floor(at_position + offset) - offset
	AppLogger.info(
		"DropZone",
		"drop_accepted",
		{"item_id": item_id, "raw_pos": raw_pos, "final_pos": at_position, "type": placement_type}
	)
	SignalBus.decoration_placed.emit(item_id, at_position)


## Scaled sprite size of the dragged item, Vector2.ZERO when unknown.
func _item_world_size(data: Dictionary) -> Vector2:
	var tex := _get_texture_for_item(data.get("item_id", ""))
	if tex == null:
		return Vector2.ZERO
	return tex.get_size() * float(data.get("item_scale", 1.0))


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
