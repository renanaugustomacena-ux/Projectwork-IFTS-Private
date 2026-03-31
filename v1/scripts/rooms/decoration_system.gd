## DecorationSystem — Handles decoration interaction: click popup, drag, rotate, scale, delete.
## Attach to individual decoration Sprite2D nodes in the room.
extends Sprite2D

const DRAG_THRESHOLD := 5.0
const SCALE_STEPS := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]

var item_id: String = ""
var base_item_scale: float = 1.0
var _deco_data: Dictionary = {}

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _click_start_pos: Vector2 = Vector2.ZERO
var _mouse_pressed: bool = false
var _popup_layer: CanvasLayer = null
var _popup: PanelContainer = null

static var _active_popup_owner: Sprite2D = null


func _ready() -> void:
	set_process_unhandled_input(true)
	base_item_scale = scale.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				if _is_mouse_over():
					_mouse_pressed = true
					_click_start_pos = get_global_mouse_position()
					_drag_offset = global_position - _click_start_pos
					get_viewport().set_input_as_handled()
				else:
					if _popup != null:
						_dismiss_popup()
			else:
				if _mouse_pressed:
					_mouse_pressed = false
					if _is_dragging:
						_is_dragging = false
						_save_position()
					else:
						_toggle_popup()

	elif event is InputEventMouseMotion and _mouse_pressed:
		if not _is_dragging:
			var dist := _click_start_pos.distance_to(
				get_global_mouse_position()
			)
			if dist > DRAG_THRESHOLD and GameManager.is_decoration_mode:
				_is_dragging = true
				_dismiss_popup()
		if _is_dragging:
			var raw_pos := get_global_mouse_position() + _drag_offset
			var snapped := Helpers.snap_to_grid(raw_pos)
			global_position = Helpers.clamp_to_viewport(
				snapped, 0.0, get_viewport().get_visible_rect().size
			)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _popup != null:
			_dismiss_popup()


func _toggle_popup() -> void:
	if _popup != null:
		_dismiss_popup()
		return
	if _active_popup_owner != null and _active_popup_owner != self:
		if is_instance_valid(_active_popup_owner):
			_active_popup_owner._dismiss_popup()
	_active_popup_owner = self
	_show_popup()


func _show_popup() -> void:
	# Use a CanvasLayer so the popup buttons (Controls) receive proper GUI input
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 100
	get_tree().root.add_child(_popup_layer)

	_popup = PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	_popup.add_child(hbox)

	# Rotate button
	var rotate_btn := Button.new()
	rotate_btn.text = "R"
	rotate_btn.tooltip_text = "Rotate"
	rotate_btn.custom_minimum_size = Vector2(28, 28)
	rotate_btn.pressed.connect(_on_rotate)
	hbox.add_child(rotate_btn)

	# Flip button (perspective)
	var flip_btn := Button.new()
	flip_btn.text = "F"
	flip_btn.tooltip_text = "Flip"
	flip_btn.custom_minimum_size = Vector2(28, 28)
	flip_btn.pressed.connect(_on_flip)
	hbox.add_child(flip_btn)

	# Scale button
	var scale_btn := Button.new()
	scale_btn.text = "S"
	scale_btn.tooltip_text = "Scale"
	scale_btn.custom_minimum_size = Vector2(28, 28)
	scale_btn.pressed.connect(_on_scale)
	hbox.add_child(scale_btn)

	# Delete button — only in edit mode
	if GameManager.is_decoration_mode:
		var delete_btn := Button.new()
		delete_btn.text = "X"
		delete_btn.tooltip_text = "Delete"
		delete_btn.custom_minimum_size = Vector2(28, 28)
		delete_btn.add_theme_color_override(
			"font_color", Color(0.9, 0.3, 0.3)
		)
		delete_btn.pressed.connect(_on_delete)
		hbox.add_child(delete_btn)

	# Convert decoration position to screen coordinates for the CanvasLayer
	var screen_pos := get_canvas_transform() * global_position
	var tex_size := texture.get_size() * scale if texture else Vector2.ZERO
	var canvas_scale := get_canvas_transform().get_scale()
	_popup.position = Vector2(
		screen_pos.x + tex_size.x * canvas_scale.x * 0.5 - 50,
		screen_pos.y - 36
	)

	_popup_layer.add_child(_popup)
	SignalBus.decoration_selected.emit(item_id)


func _dismiss_popup() -> void:
	if _popup_layer != null and is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null
	_popup = null
	if _active_popup_owner == self:
		_active_popup_owner = null
	SignalBus.decoration_deselected.emit()


func _on_rotate() -> void:
	rotation_degrees = fmod(rotation_degrees + 90.0, 360.0)
	_save_rotation()
	SignalBus.decoration_rotated.emit(item_id, rotation_degrees)


func _on_flip() -> void:
	flip_h = not flip_h
	_save_flip()


func _on_scale() -> void:
	var current_mult := scale.x / base_item_scale
	var next_mult := SCALE_STEPS[0]
	for i in range(SCALE_STEPS.size()):
		if absf(current_mult - SCALE_STEPS[i]) < 0.05:
			next_mult = SCALE_STEPS[(i + 1) % SCALE_STEPS.size()]
			break
	var new_scale := base_item_scale * next_mult
	scale = Vector2(new_scale, new_scale)
	_save_scale(new_scale)
	SignalBus.decoration_scaled.emit(item_id, new_scale)


func _on_delete() -> void:
	_dismiss_popup()
	_remove_from_room()


func _is_mouse_over() -> bool:
	if texture == null:
		return false
	var mouse_pos := get_local_mouse_position()
	var tex_size := texture.get_size()
	return Rect2(Vector2.ZERO, tex_size).has_point(mouse_pos)


func _save_position() -> void:
	if _deco_data.is_empty():
		return
	_deco_data["position"] = Helpers.vec2_to_array(position)
	SignalBus.decoration_moved.emit(item_id, position)
	SignalBus.save_requested.emit()


func _save_rotation() -> void:
	if _deco_data.is_empty():
		return
	_deco_data["rotation"] = rotation_degrees
	SignalBus.save_requested.emit()


func _save_flip() -> void:
	if _deco_data.is_empty():
		return
	_deco_data["flip_h"] = flip_h
	SignalBus.save_requested.emit()


func _save_scale(new_scale: float) -> void:
	if _deco_data.is_empty():
		return
	_deco_data["item_scale"] = new_scale
	SignalBus.save_requested.emit()


func _remove_from_room() -> void:
	var idx := SaveManager.decorations.find(_deco_data)
	if idx >= 0:
		SaveManager.decorations.remove_at(idx)
	SignalBus.decoration_removed.emit(item_id)
	SignalBus.save_requested.emit()
	queue_free()


func _exit_tree() -> void:
	_dismiss_popup()
