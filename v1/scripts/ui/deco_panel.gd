## DecoPanel — Right-side decoration catalog with drag-and-drop support.
## Items are organized by category. Drag an item from the panel to the room to place it.
extends PanelContainer

var _vbox: VBoxContainer
var _mode_button: Button
var _category_containers: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_populate_catalog()


func _build_ui() -> void:
	custom_minimum_size = Vector2(240, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(outer_vbox)

	# Title
	var title := Label.new()
	title.text = "Decorazioni"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	# Mode toggle button
	_mode_button = Button.new()
	_mode_button.custom_minimum_size = Vector2(0, 32)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.pressed.connect(_on_mode_toggled)
	outer_vbox.add_child(_mode_button)
	_update_mode_button()

	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# Scrollable area for categories
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_vbox)


func _populate_catalog() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_category_containers.clear()

	var catalog: Dictionary = GameManager.decorations_catalog
	var categories: Array = catalog.get("categories", [])
	var items: Array = catalog.get("decorations", [])

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nessuna decorazione disponibile."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate.a = 0.6
		_vbox.add_child(empty)
		return

	for cat_data in categories:
		if cat_data is not Dictionary:
			continue
		if cat_data.get("hidden", false):
			continue
		var cat_id: String = cat_data.get("id", "")
		var cat_name: String = cat_data.get("name", cat_id)

		# Category header button
		var header := Button.new()
		header.text = "+ %s" % cat_name
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.focus_mode = Control.FOCUS_NONE
		header.add_theme_font_size_override("font_size", 13)
		header.pressed.connect(_on_category_toggled.bind(cat_id))
		_vbox.add_child(header)

		# Grid for items in this category
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_vbox.add_child(grid)

		grid.visible = false
		_category_containers[cat_id] = {"header": header, "grid": grid}

		# Add drag-enabled buttons for items in this category
		for item_data in items:
			if item_data is not Dictionary:
				continue
			if item_data.get("category", "") != cat_id:
				continue

			var item_id: String = item_data.get("id", "")
			var item_name: String = item_data.get("name", item_id)
			var sprite_path: String = item_data.get("sprite_path", "")
			var item_scale: float = item_data.get("item_scale", 1.0)
			var placement_type: String = item_data.get("placement_type", "any")

			var drag_btn := _create_drag_button(item_id, item_name, sprite_path, item_scale, placement_type)
			if drag_btn:
				grid.add_child(drag_btn)


func _create_drag_button(
	item_id: String, item_name: String, sprite_path: String, item_scale: float, placement_type: String
) -> Control:  # Returns null if texture missing
	# DecoButton (TextureRect sottoclasse) ha _get_drag_data override. Usiamo
	# TextureRect e non Button perche` Button intercetta mouse_down con la sua
	# logica _pressing_inside che interferisce con la drag detection nativa di
	# Godot 4 (viewport aspetta mouse_move threshold tra press e release).
	# Pattern verificato in jlucaso1/drag-drop-inventory + jeroenheijmans/sample.
	var tex: Texture2D = null
	if not sprite_path.is_empty():
		tex = load(sprite_path) as Texture2D
	if tex == null:
		return null

	var btn := DecoButton.new()
	btn.custom_minimum_size = Vector2(68, 56)
	btn.tooltip_text = item_name
	btn.texture = tex

	# Store drag data as metadata — DecoButton._get_drag_data legge questo
	btn.set_meta(
		"drag_data",
		{
			"item_id": item_id,
			"sprite_path": sprite_path,
			"item_scale": item_scale,
			"placement_type": placement_type,
		}
	)
	return btn


func _on_category_toggled(cat_id: String) -> void:
	if cat_id not in _category_containers:
		return
	var data: Dictionary = _category_containers[cat_id]
	var grid: GridContainer = data["grid"]
	var header: Button = data["header"]
	grid.visible = not grid.visible
	var cat_name := header.text.substr(2)
	if grid.visible:
		header.text = "- %s" % cat_name
	else:
		header.text = "+ %s" % cat_name


func _on_mode_toggled() -> void:
	GameManager.toggle_decoration_mode()
	_update_mode_button()


func _update_mode_button() -> void:
	if GameManager.is_decoration_mode:
		_mode_button.text = "Esci Modalità Modifica"
	else:
		_mode_button.text = "Modalità Modifica"


func _exit_tree() -> void:
	if _mode_button and _mode_button.pressed.is_connected(_on_mode_toggled):
		_mode_button.pressed.disconnect(_on_mode_toggled)
