## DecorationSystem — Handles decoration interaction: click popup, drag, rotate, scale, delete.
## Attach to individual decoration Sprite2D nodes in the room.
extends Sprite2D

const DRAG_THRESHOLD := 5.0
const SCALE_STEPS := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]

static var _active_popup_owner: Sprite2D = null

var item_id: String = ""
var base_item_scale: float = 1.0
var deco_data: Dictionary = {}
## Catalog entry for this item (placement rules, rotatable, flat, scale
## bounds). Assigned by the spawner; empty dict falls back to safe defaults.
var catalog_data: Dictionary = {}

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _click_start_pos: Vector2 = Vector2.ZERO
var _mouse_pressed: bool = false
var _popup_layer: CanvasLayer = null
var _popup: PanelContainer = null


func _ready() -> void:
	set_process_unhandled_input(true)
	# base_item_scale is assigned by the spawner (room_base) with the CATALOG
	# scale before add_child. Do NOT rebase it to scale.x here: after a
	# save/reload scale.x is the saved absolute scale, and rebasing made the
	# SCALE_STEPS ladder compound unboundedly across sessions (Phase E).


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
						dismiss_popup()
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
			var dist := _click_start_pos.distance_to(get_global_mouse_position())
			if dist > DRAG_THRESHOLD and GameManager.is_decoration_mode:
				_is_dragging = true
				dismiss_popup()
		if _is_dragging:
			# Pixel-precise drag: no snap. Shift held → optional 64px grid snap.
			var raw_pos := get_global_mouse_position() + _drag_offset
			var snap_pos := raw_pos
			if Input.is_key_pressed(KEY_SHIFT):
				snap_pos = Helpers.snap_to_grid(raw_pos)
			# Every placement type has its own legal zone and its own clamp —
			# the rule comes from the data, the geometry from Helpers (single
			# source of truth). Floor items clamp their foot anchor into the
			# floor polygon; wall items clamp their rect onto the wall band
			# (before this, a window could be parked in the middle of the
			# floor because "wall" simply skipped validation).
			var placement_type := Helpers.placement_type_of(deco_data)
			if placement_type == "wall":
				var half := _half_size()
				var clamped_center: Vector2 = Helpers.clamp_wall_anchor(snap_pos + half, half)
				global_position = clamped_center - half
			else:
				var anchor_offset := _floor_anchor_offset()
				var clamped_anchor: Vector2 = Helpers.clamp_inside_floor(snap_pos + anchor_offset)
				global_position = clamped_anchor - anchor_offset
				if not Helpers.is_flat(catalog_data):
					z_index = Helpers.z_for_foot_y(global_position.y + anchor_offset.y)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _popup != null:
			dismiss_popup()


func _floor_anchor_offset() -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var tex_size := texture.get_size() * scale
	return Vector2(tex_size.x * 0.5, tex_size.y)


func _half_size() -> Vector2:
	if texture == null:
		return Vector2.ZERO
	return texture.get_size() * scale * 0.5


func _toggle_popup() -> void:
	if _popup != null:
		dismiss_popup()
		return
	# GP-09: i comandi di modifica esistono solo in Modalita` modifica, come
	# lo spostamento; un click in gioco non deve specchiare l'arredamento.
	if not GameManager.is_decoration_mode:
		return
	if _active_popup_owner != null and _active_popup_owner != self:
		if is_instance_valid(_active_popup_owner):
			_active_popup_owner.dismiss_popup()
	_active_popup_owner = self
	_show_popup()


func _show_popup() -> void:
	# Use a CanvasLayer so the popup buttons (Controls) receive proper GUI input
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 60  # sotto tutorial (100) e toast (90), sopra la UI (10)
	get_tree().root.add_child(_popup_layer)

	_popup = PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	_popup.add_child(hbox)

	# Rotate button — only for items the catalog marks rotatable. Perspective
	# furniture rotated 90° lies "on its side" and looks broken; flat items
	# (rugs) opt in via "rotatable": true. The rule lives in the data.
	if Helpers.is_rotatable(catalog_data):
		var rotate_btn := Button.new()
		rotate_btn.text = "R"
		rotate_btn.tooltip_text = tr("UI_DECO_ROTATE")
		rotate_btn.custom_minimum_size = _popup_button_size()
		rotate_btn.focus_mode = Control.FOCUS_NONE
		rotate_btn.pressed.connect(_on_rotate)
		hbox.add_child(rotate_btn)

	# Flip button (perspective)
	var flip_btn := Button.new()
	flip_btn.text = "F"
	flip_btn.tooltip_text = tr("UI_DECO_FLIP")
	flip_btn.custom_minimum_size = _popup_button_size()
	flip_btn.focus_mode = Control.FOCUS_NONE
	flip_btn.pressed.connect(_on_flip)
	hbox.add_child(flip_btn)

	# Scale button
	var scale_btn := Button.new()
	scale_btn.text = "S"
	scale_btn.tooltip_text = tr("UI_DECO_SCALE")
	scale_btn.custom_minimum_size = _popup_button_size()
	scale_btn.focus_mode = Control.FOCUS_NONE
	scale_btn.pressed.connect(_on_scale)
	hbox.add_child(scale_btn)

	# Delete button — only in edit mode
	if GameManager.is_decoration_mode:
		var delete_btn := Button.new()
		delete_btn.text = "X"
		delete_btn.tooltip_text = tr("UI_DECO_DELETE")
		delete_btn.custom_minimum_size = _popup_button_size()
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		delete_btn.pressed.connect(_on_delete)
		hbox.add_child(delete_btn)

	# Convert decoration position to screen coordinates for the CanvasLayer
	var screen_pos := get_canvas_transform() * global_position
	var tex_size := texture.get_size() * scale if texture else Vector2.ZERO
	var canvas_scale := get_canvas_transform().get_scale()
	_popup.position = Vector2(screen_pos.x + tex_size.x * canvas_scale.x * 0.5 - 50, screen_pos.y - 36)
	# GP-10: un quadro alto sul muro mandava il popup a y negativa, fuori
	# schermo e quindi ineliminabile.
	var vp_size := get_viewport().get_visible_rect().size
	_popup.position = _popup.position.clamp(Vector2(4, 4), vp_size - Vector2(150, 44))

	_popup_layer.add_child(_popup)
	SignalBus.decoration_selected.emit(item_id)


func dismiss_popup() -> void:
	if _popup_layer != null and is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null
	_popup = null
	if _active_popup_owner == self:
		_active_popup_owner = null


func _popup_button_size() -> Vector2:
	return Vector2(48, 48) if OS.has_feature("mobile") else Vector2(28, 28)


func _on_rotate() -> void:
	AudioManager.play_sfx("deco_rotate")
	rotation_degrees = fmod(rotation_degrees + 90.0, 360.0)
	_save_rotation()


func _on_flip() -> void:
	AudioManager.play_sfx("deco_rotate")
	flip_h = not flip_h
	_save_flip()


func _on_scale() -> void:
	# Ladder restricted to the catalog's allowed multiplier range, so no item
	# can drift far from its authored proportion (0.25x plants and 3x beds
	# were a large part of "this furniture does not belong here").
	var bounds := Helpers.scale_bounds_of(catalog_data)
	var steps: Array[float] = []
	for s: float in SCALE_STEPS:
		if s >= bounds.x - 0.001 and s <= bounds.y + 0.001:
			steps.append(s)
	if steps.is_empty():
		steps.append(1.0)
	var current_mult := scale.x / base_item_scale
	# GP-31: il primo gradino strettamente maggiore dell'attuale, poi si
	# ricomincia dal piu` piccolo (prima un valore fuori griglia saltava a 0.5).
	var next_mult: float = steps[0]
	for s: float in steps:
		if s > current_mult + 0.05:
			next_mult = s
			break
	var new_scale := base_item_scale * next_mult
	scale = Vector2(new_scale, new_scale)
	AudioManager.play_sfx("deco_scale")
	# GP-05: la profondita` segue il bordo inferiore, che con la scala cambia.
	if texture != null and Helpers.placement_type_of(catalog_data) == "floor" and not Helpers.is_flat(catalog_data):
		z_index = Helpers.z_for_foot_y(position.y + texture.get_size().y * new_scale)
	_save_scale(new_scale)


func _on_delete() -> void:
	dismiss_popup()
	_remove_from_room()


func _is_mouse_over() -> bool:
	if texture == null:
		return false
	var mouse_pos := get_local_mouse_position()
	var tex_size := texture.get_size()
	return Rect2(Vector2.ZERO, tex_size).has_point(mouse_pos)


func _save_position() -> void:
	if deco_data.is_empty():
		return
	deco_data["position"] = Helpers.vec2_to_array(position)
	SignalBus.save_requested.emit()


func _save_rotation() -> void:
	if deco_data.is_empty():
		return
	deco_data["rotation"] = rotation_degrees
	SignalBus.save_requested.emit()


func _save_flip() -> void:
	if deco_data.is_empty():
		return
	deco_data["flip_h"] = flip_h
	SignalBus.save_requested.emit()


func _save_scale(new_scale: float) -> void:
	if deco_data.is_empty():
		return
	deco_data["item_scale"] = new_scale
	SignalBus.save_requested.emit()


func _remove_from_room() -> void:
	# V-059 companion: remove_decoration reports whether the entry existed.
	# A did-not-exist removal is logged as WARN instead of silently ignored.
	if not SaveManager.remove_decoration(deco_data):
		AppLogger.warn("DecorationSystem", "remove_decoration_not_found", {"item_id": item_id})
	SignalBus.decoration_removed.emit(item_id)
	SignalBus.save_requested.emit()
	AudioManager.play_sfx("deco_remove")
	queue_free()


func _exit_tree() -> void:
	dismiss_popup()
