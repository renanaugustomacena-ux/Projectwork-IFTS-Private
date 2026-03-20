## DecorationSystem — Handles in-room drag repositioning and right-click removal.
## Attach this script to individual decoration Sprite2D nodes for interaction.
extends Sprite2D

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var item_id: String = ""


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not GameManager.is_decoration_mode:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		# Right-click to remove
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if _is_mouse_over():
				_remove_from_room()
				return

		# Left-click to drag
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if _is_mouse_over():
					is_dragging = true
					drag_offset = global_position - get_global_mouse_position()
			else:
				if is_dragging:
					is_dragging = false
					_save_position()

	elif event is InputEventMouseMotion and is_dragging:
		var raw_pos := get_global_mouse_position() + drag_offset
		var snapped := Helpers.snap_to_grid(raw_pos)
		global_position = Helpers.clamp_to_viewport(
			snapped, 0.0, get_viewport().get_visible_rect().size
		)


func _is_mouse_over() -> bool:
	if texture == null:
		return false
	var mouse_pos := get_local_mouse_position()
	var tex_size := texture.get_size()
	return Rect2(Vector2.ZERO, tex_size).has_point(mouse_pos)


func _save_position() -> void:
	for i in range(SaveManager.decorations.size()):
		if SaveManager.decorations[i].get("item_id", "") == item_id:
			SaveManager.decorations[i]["position"] = Helpers.vec2_to_array(position)
			SignalBus.decoration_moved.emit(item_id, position)
			SignalBus.save_requested.emit()
			return


func _remove_from_room() -> void:
	for i in range(SaveManager.decorations.size()):
		if SaveManager.decorations[i].get("item_id", "") == item_id:
			SaveManager.decorations.remove_at(i)
			break
	SignalBus.decoration_removed.emit(item_id)
	SignalBus.save_requested.emit()
	queue_free()
