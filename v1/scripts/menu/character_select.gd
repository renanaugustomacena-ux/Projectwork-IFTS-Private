## CharacterSelect — Full-screen character selection before entering the room.
## Shown after "New Game" so the player can choose their character.
extends Control

signal character_selected(character_id: String)

const CHARACTER_SCENE := "res://scenes/menu/character_select.tscn"

## Available characters — must match CHARACTER_SCENES in room_base.gd.
## Currently only 1 character (male_old). character_select screen
## may be bypassed by main_menu.gd when size() == 1.
const CHARACTERS := [
	{
		"id": "male_old",
		"name": "Ragazzo Classico",
		"scene": "res://scenes/male-old-character.tscn",
	},
]

var _current_index: int = 0
var _preview_node: Node = null
var _name_label: Label = null
var _counter_label: Label = null
var _left_btn: Button = null
var _right_btn: Button = null
var _start_btn: Button = null
var _title_label: Label = null
var _tween: Tween = null


func _ready() -> void:
	_build_ui()
	_show_character(_current_index)


func _build_ui() -> void:
	# Full-screen dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_left = 0.2
	vbox.anchor_right = 0.8
	vbox.anchor_top = 0.1
	vbox.anchor_bottom = 0.9
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Scegli il tuo Personaggio"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override(
		"font_color", Color(0.9, 0.85, 0.7, 1.0)
	)
	vbox.add_child(_title_label)

	# Spacer
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer_top)

	# Preview container (centered)
	var preview_container := CenterContainer.new()
	preview_container.custom_minimum_size = Vector2(256, 256)
	vbox.add_child(preview_container)

	# SubViewportContainer for character preview
	var svpc := SubViewportContainer.new()
	svpc.custom_minimum_size = Vector2(192, 192)
	svpc.stretch = true
	preview_container.add_child(svpc)

	var svp := SubViewport.new()
	svp.size = Vector2i(192, 192)
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svpc.add_child(svp)

	# Placeholder for character scene
	var preview_root := Node2D.new()
	preview_root.name = "PreviewRoot"
	preview_root.position = Vector2(96, 140)
	svp.add_child(preview_root)
	_preview_node = preview_root

	# Character name
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override(
		"font_color", Color(0.8, 0.75, 0.65, 1.0)
	)
	vbox.add_child(_name_label)

	# Counter (1/3)
	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 14)
	_counter_label.add_theme_color_override(
		"font_color", Color(0.6, 0.55, 0.5, 0.7)
	)
	vbox.add_child(_counter_label)

	# Navigation row
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 40)
	vbox.add_child(nav)

	_left_btn = Button.new()
	_left_btn.focus_mode = Control.FOCUS_ALL  # keyboard nav (arrow keys)
	_left_btn.text = "◀"
	_left_btn.custom_minimum_size = Vector2(60, 40)
	_left_btn.pressed.connect(_on_prev)
	nav.add_child(_left_btn)

	_right_btn = Button.new()
	_right_btn.focus_mode = Control.FOCUS_ALL  # keyboard nav
	_right_btn.text = "▶"
	_right_btn.custom_minimum_size = Vector2(60, 40)
	_right_btn.pressed.connect(_on_next)
	nav.add_child(_right_btn)

	# Spacer
	var spacer_bot := Control.new()
	spacer_bot.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_bot)

	# Start button
	_start_btn = Button.new()
	_start_btn.focus_mode = Control.FOCUS_ALL  # keyboard nav (Enter)
	_start_btn.text = "Inizia a Giocare"
	_start_btn.custom_minimum_size = Vector2(200, 48)
	_start_btn.pressed.connect(_on_start)
	var start_container := CenterContainer.new()
	start_container.add_child(_start_btn)
	vbox.add_child(start_container)


func _on_prev() -> void:
	_current_index = (
		(_current_index - 1 + CHARACTERS.size())
		% CHARACTERS.size()
	)
	_show_character(_current_index)


func _on_next() -> void:
	_current_index = (_current_index + 1) % CHARACTERS.size()
	_show_character(_current_index)


func _on_start() -> void:
	var char_data: Dictionary = CHARACTERS[_current_index]
	var char_id: String = char_data["id"]
	GameManager.current_character_id = char_id
	character_selected.emit(char_id)


func _show_character(index: int) -> void:
	if _preview_node == null:
		return
	# Clear previous preview
	for child in _preview_node.get_children():
		child.queue_free()

	var char_data: Dictionary = CHARACTERS[index]
	_name_label.text = char_data["name"]
	_counter_label.text = "%d / %d" % [index + 1, CHARACTERS.size()]

	var scene := load(char_data["scene"]) as PackedScene
	if scene == null:
		push_warning(
			"CharacterSelect: failed to load '%s'"
			% char_data["scene"]
		)
		return
	var instance := scene.instantiate()
	# Disable the controller script so the preview just plays idle
	instance.set_physics_process(false)
	instance.set_process_unhandled_input(false)
	_preview_node.add_child(instance)

	# Fade in
	if _tween and _tween.is_running():
		_tween.kill()
	var parent: Node = _preview_node.get_parent()
	if parent is CanvasItem:
		(parent as CanvasItem).modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(
			parent, "modulate:a", 1.0, 0.25
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_on_prev()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_on_next()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_on_start()
				get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if _left_btn and _left_btn.pressed.is_connected(_on_prev):
		_left_btn.pressed.disconnect(_on_prev)
	if _right_btn and _right_btn.pressed.is_connected(_on_next):
		_right_btn.pressed.disconnect(_on_next)
	if _start_btn and _start_btn.pressed.is_connected(_on_start):
		_start_btn.pressed.disconnect(_on_start)
