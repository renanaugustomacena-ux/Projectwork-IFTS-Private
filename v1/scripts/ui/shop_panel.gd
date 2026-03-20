## ShopPanel — Browsable catalog of all decorations across all rooms.
## Items are organized by category with drag-and-drop to the room.
extends PanelContainer

var _vbox: VBoxContainer
var _category_containers: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_populate_catalog()


func _build_ui() -> void:
	custom_minimum_size = Vector2(260, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

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
		empty.text = "No items available."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate.a = 0.6
		_vbox.add_child(empty)
		return

	for cat_data in categories:
		if cat_data is not Dictionary:
			continue
		var cat_id: String = cat_data.get("id", "")
		var cat_name: String = cat_data.get("name", cat_id)
		var cat_items := _get_items_for_category(items, cat_id)
		if cat_items.is_empty():
			continue

		var header := Button.new()
		header.text = "+ %s (%d)" % [cat_name, cat_items.size()]
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.add_theme_font_size_override("font_size", 13)
		header.pressed.connect(_on_category_toggled.bind(cat_id))
		_vbox.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_vbox.add_child(grid)

		grid.visible = false
		_category_containers[cat_id] = {"header": header, "grid": grid}

		for item_data in cat_items:
			var drag_btn := _create_drag_button(item_data)
			grid.add_child(drag_btn)


func _get_items_for_category(items: Array, cat_id: String) -> Array:
	var result: Array = []
	for item in items:
		if item is Dictionary and item.get("category", "") == cat_id:
			result.append(item)
	return result


func _create_drag_button(item_data: Dictionary) -> Button:
	var item_id: String = item_data.get("id", "")
	var item_name: String = item_data.get("name", item_id)
	var sprite_path: String = item_data.get("sprite_path", "")
	var item_scale: float = item_data.get("item_scale", 1.0)
	var placement_type: String = item_data.get("placement_type", "any")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 56)
	btn.tooltip_text = item_name

	if not sprite_path.is_empty():
		var tex := load(sprite_path) as Texture2D
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true

	btn.set_meta(
		"drag_data",
		{
			"item_id": item_id,
			"sprite_path": sprite_path,
			"item_scale": item_scale,
			"placement_type": placement_type,
		}
	)

	btn.gui_input.connect(_on_button_gui_input.bind(btn))
	return btn


func _on_button_gui_input(event: InputEvent, btn: Button) -> void:
	if not (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		return
	var drag_data: Dictionary = btn.get_meta("drag_data", {})
	if drag_data.is_empty():
		return

	var preview := TextureRect.new()
	var tex := load(drag_data.get("sprite_path", "")) as Texture2D
	if tex:
		preview.texture = tex
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var preview_scale: float = drag_data.get("item_scale", 1.0)
		preview.custom_minimum_size = tex.get_size() * preview_scale * 0.5
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	btn.force_drag(drag_data, preview)
	SignalBus.shop_item_selected.emit(drag_data.get("item_id", ""))


func _on_category_toggled(cat_id: String) -> void:
	if cat_id not in _category_containers:
		return
	var data: Dictionary = _category_containers[cat_id]
	var grid: GridContainer = data["grid"]
	var header: Button = data["header"]
	grid.visible = not grid.visible
	var base_text := header.text.substr(2)
	if grid.visible:
		header.text = "- %s" % base_text
	else:
		header.text = "+ %s" % base_text
