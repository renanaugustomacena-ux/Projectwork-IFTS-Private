## DecorationSystem — Handles decoration interaction: click popup, drag, rotate, scale, delete.
## Attach to individual decoration Sprite2D nodes in the room.
extends Sprite2D

const DRAG_THRESHOLD := 5.0
const SCALE_STEPS := [0.5, 1.0, 1.5]

var item_id: String = ""
var base_item_scale: float = 1.0

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _click_start_pos: Vector2 = Vector2.ZERO
var _mouse_pressed: bool = false
var _popup: PanelContainer = null

static var _active_popup_owner: Sprite2D = null


func _ready() -> void:
	set_process_input(true)
	base_item_scale = scale.x


func _input(event: InputEvent) -> void:
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
					# Clicked elsewhere — dismiss popup
					if _popup != null:
						_dismiss_popup()
			else:
				if _mouse_pressed:
					_mouse_pressed = false
					if _is_dragging:
						_is_dragging = false
						_save_position()
					else:
						# Was a click, not a drag — show popup
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
	# Dismiss any other decoration's popup
	if _active_popup_owner != null and _active_popup_owner != self:
		if is_instance_valid(_active_popup_owner):
			_active_popup_owner._dismiss_popup()
	_active_popup_owner = self
	_show_popup()


func _show_popup() -> void:
	_popup = PanelContainer.new()
	_popup.z_index = 50

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

	# Position popup above the decoration center
	var tex_size := texture.get_size() * scale if texture else Vector2.ZERO
	_popup.position = Vector2(
		global_position.x + tex_size.x * 0.5 - 50,
		global_position.y - 36
	)

	# Add to the decorations container (sibling of this sprite)
	get_parent().add_child(_popup)
	SignalBus.decoration_selected.emit(item_id)


func _dismiss_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	if _active_popup_owner == self:
		_active_popup_owner = null
	SignalBus.decoration_deselected.emit()


func _on_rotate() -> void:
	rotation_degrees = fmod(rotation_degrees + 90.0, 360.0)
	_save_rotation()
	SignalBus.decoration_rotated.emit(item_id, rotation_degrees)


func _on_scale() -> void:
	# Cycle through scale steps relative to base_item_scale
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
	for i in range(SaveManager.decorations.size()):
		var deco: Dictionary = SaveManager.decorations[i]
		if deco.get("item_id", "") == item_id:
			deco["position"] = Helpers.vec2_to_array(position)
			SignalBus.decoration_moved.emit(item_id, position)
			SignalBus.save_requested.emit()
			return


func _save_rotation() -> void:
	for i in range(SaveManager.decorations.size()):
		var deco: Dictionary = SaveManager.decorations[i]
		if deco.get("item_id", "") == item_id:
			deco["rotation"] = rotation_degrees
			SignalBus.save_requested.emit()
			return


func _save_scale(new_scale: float) -> void:
	for i in range(SaveManager.decorations.size()):
		var deco: Dictionary = SaveManager.decorations[i]
		if deco.get("item_id", "") == item_id:
			deco["item_scale"] = new_scale
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


func _exit_tree() -> void:
	_dismiss_popup()
