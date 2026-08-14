## ShopPanel — Negozio (spec 2026-08-14, fase economia).
##
## Interamente data-driven da data/shop.json: le sezioni e le voci vengono
## dal catalogo, il pannello e` un motore di rendering generico (modulo 11).
## Acquisto → GameManager.purchase_item (unico punto che tocca i coins);
## "Mangia" consuma cibo player e abbassa lo stress; "Dai da mangiare"
## consuma croccantini e chiede la ciotola via SignalBus.
extends PanelContainer

const SECTION_KEYS := {
	"food_player": "UI_SHOP_SECTION_FOOD",
	"food_cat": "UI_SHOP_SECTION_CAT",
	"tools": "UI_SHOP_SECTION_TOOLS",
}

var _list: VBoxContainer = null
var _coins_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	var title := Label.new()
	title.text = tr("UI_SHOP_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_coins_label)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	root.add_child(_list)

	SignalBus.coins_changed.connect(_on_coins_changed)
	SignalBus.inventory_updated.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if SignalBus.coins_changed.is_connected(_on_coins_changed):
		SignalBus.coins_changed.disconnect(_on_coins_changed)
	if SignalBus.inventory_updated.is_connected(_rebuild):
		SignalBus.inventory_updated.disconnect(_rebuild)


## Review 2026-08-14: i coins cambiano anche per pulizie che finiscono col
## pannello aperto — aggiornare SOLO l'etichetta, non ricostruire le righe
## (il rebuild distruggeva i bottoni sotto il mouse a ogni payout; un
## acquisto emette anche inventory_updated, che fa il rebuild completo).
func _on_coins_changed(_delta: int, total: int) -> void:
	if _coins_label != null:
		_coins_label.text = "★ %d" % total


func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_coins_label.text = "★ %d" % int(SaveManager.inventory_data.get("coins", 0))
	for section: String in SECTION_KEYS:
		var entries: Array = GameManager.get_shop_section(section)
		if entries.is_empty():
			continue
		var header := Label.new()
		header.text = tr(SECTION_KEYS[section])
		header.add_theme_font_size_override("font_size", 15)
		_list.add_child(header)
		for entry: Dictionary in entries:
			_list.add_child(_build_row(section, entry))


func _build_row(section: String, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = Color(str(entry.get("icon_color", "#888888")))
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = Helpers.locale_label(entry)
	info.add_child(name_label)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 11)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.text = _subtitle_for(section, entry)
	info.add_child(sub)
	row.add_child(info)

	for action_btn in _action_buttons(section, entry):
		row.add_child(action_btn)
	return row


func _subtitle_for(section: String, entry: Dictionary) -> String:
	var qty := SaveManager.get_item_qty(str(entry.get("id", "")))
	match section:
		"food_player":
			return "-%d stress · x%d" % [int(entry.get("stress_relief", 0)), qty]
		"food_cat":
			return "x%d" % qty
		"tools":
			return "x%.1f" % float(entry.get("speed_multiplier", 1.0))
	return ""


func _action_buttons(section: String, entry: Dictionary) -> Array[Button]:
	var out: Array[Button] = []
	var item_id := str(entry.get("id", ""))
	var price := int(entry.get("price", 0))
	var qty := SaveManager.get_item_qty(item_id)
	var owned_tool := section == "tools" and qty > 0

	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_ALL
	buy.custom_minimum_size = Vector2(72, 30)
	if owned_tool:
		buy.text = tr("UI_SHOP_OWNED")
		buy.disabled = true
	else:
		buy.text = "%s %d" % [tr("UI_SHOP_BUY"), price]
		buy.pressed.connect(_on_buy_pressed.bind(item_id))
	out.append(buy)

	if section == "food_player" and qty > 0:
		var eat := Button.new()
		eat.focus_mode = Control.FOCUS_ALL
		eat.custom_minimum_size = Vector2(72, 30)
		eat.text = tr("UI_SHOP_EAT")
		eat.pressed.connect(_on_eat_pressed.bind(item_id))
		out.append(eat)
	elif section == "food_cat" and qty > 0:
		var feed := Button.new()
		feed.focus_mode = Control.FOCUS_ALL
		feed.custom_minimum_size = Vector2(72, 30)
		feed.text = tr("UI_SHOP_FEED")
		feed.disabled = not get_tree().get_nodes_in_group("pet_bowl").is_empty()
		feed.pressed.connect(_on_feed_pressed.bind(item_id))
		out.append(feed)
	return out


func _on_buy_pressed(item_id: String) -> void:
	GameManager.purchase_item(item_id)
	# coins_changed/inventory_updated fanno gia` il rebuild.


func _on_eat_pressed(item_id: String) -> void:
	var entry := GameManager.get_shop_entry(item_id)
	if entry.is_empty() or not SaveManager.consume_item(item_id):
		return
	var relief := float(entry.get("stress_relief", 0)) / 100.0
	StressManager.apply_delta(-relief)
	SignalBus.player_ate.emit(item_id, relief)
	SignalBus.toast_requested.emit(tr("TOAST_ATE") % Helpers.locale_label(entry), "info")
	SignalBus.save_requested.emit()


func _on_feed_pressed(item_id: String) -> void:
	if not get_tree().get_nodes_in_group("pet_bowl").is_empty():
		SignalBus.toast_requested.emit(tr("TOAST_BOWL_ALREADY"), "warning")
		return
	if not SaveManager.consume_item(item_id):
		return
	# Vector2.INF = "davanti al personaggio": la posizione vera la risolve
	# room_base, che conosce il character_node (il pannello non deve).
	SignalBus.pet_feed_requested.emit(Vector2.INF)
	SignalBus.toast_requested.emit(tr("TOAST_BOWL_PLACED"), "info")
	SignalBus.save_requested.emit()
