## SlotSelect — schermata dei 10 slot di salvataggio (fase 4, spec 2026-08-14).
##
## Costruita interamente in codice (come GameHud): una riga per slot con
## anteprima non-distruttiva (nome, data, coins via SaveManager.peek_slot).
## Slot occupato → Carica / Elimina (conferma a doppio tap); slot vuoto →
## Nuova partita. La scelta viene solo SEGNALATA: e` il menu a cambiare lo
## slot attivo e a guidare il flusso esistente di load/new game.
extends Control

signal slot_load_requested(slot: int)
signal slot_new_requested(slot: int)
signal closed

var _rows: VBoxContainer = null
var _confirm_slot: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var title := Label.new()
	title.text = tr("UI_SLOTS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)

	var close_btn := Button.new()
	close_btn.text = tr("UI_SLOTS_CLOSE")
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.pressed.connect(func() -> void: closed.emit())
	root.add_child(close_btn)

	_rebuild()


func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.MAX_SLOTS + 1):
		_rows.add_child(_build_row(slot))


func _build_row(slot: int) -> Control:
	var meta := SaveManager.peek_slot(slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(meta.get("exists", false)):
		var nome := str(meta.get("nome", ""))
		if nome.is_empty():
			nome = tr("UI_SLOT_UNNAMED")
		var when := str(meta.get("last_saved", "")).replace("T", " ")
		info.text = "%d · %s — ★%d · %s" % [slot, nome, int(meta.get("coins", 0)), when]
	else:
		info.text = "%d · %s" % [slot, tr("UI_SLOT_EMPTY")]
		info.modulate = Color(1, 1, 1, 0.6)
	if slot == SaveManager.active_slot:
		info.text += "  ◂"
	row.add_child(info)

	if bool(meta.get("exists", false)):
		var load_btn := Button.new()
		load_btn.text = tr("UI_SLOT_LOAD")
		load_btn.focus_mode = Control.FOCUS_ALL
		load_btn.custom_minimum_size = Vector2(84, 30)
		load_btn.pressed.connect(func() -> void: slot_load_requested.emit(slot))
		row.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = tr("UI_SLOT_DELETE_CONFIRM") if _confirm_slot == slot else tr("UI_SLOT_DELETE")
		del_btn.focus_mode = Control.FOCUS_ALL
		del_btn.custom_minimum_size = Vector2(84, 30)
		del_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		del_btn.pressed.connect(_on_delete_pressed.bind(slot))
		row.add_child(del_btn)
	else:
		var new_btn := Button.new()
		new_btn.text = tr("UI_SLOT_NEW")
		new_btn.focus_mode = Control.FOCUS_ALL
		new_btn.custom_minimum_size = Vector2(176, 30)
		new_btn.pressed.connect(func() -> void: slot_new_requested.emit(slot))
		row.add_child(new_btn)
	return row


## Doppio tap di conferma: il primo click arma, il secondo cancella davvero.
func _on_delete_pressed(slot: int) -> void:
	if _confirm_slot != slot:
		_confirm_slot = slot
		_rebuild()
		return
	_confirm_slot = -1
	SaveManager.delete_slot_files(slot)
	_rebuild()
