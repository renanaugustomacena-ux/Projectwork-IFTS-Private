## SettingsPanel — Audio volume sliders and language selector.
## Reads/writes via SaveManager.settings and emits signals for live updates.
extends PanelContainer

var _master_slider: HSlider
var _music_slider: HSlider
var _ambience_slider: HSlider
var _language_option: OptionButton
var _loading: bool = false


func _ready() -> void:
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Audio section
	var audio_label := Label.new()
	audio_label.text = "Audio"
	audio_label.add_theme_font_size_override("font_size", 11)
	audio_label.modulate.a = 0.7
	vbox.add_child(audio_label)

	_master_slider = _create_slider(vbox, "Master", 0.8)
	_master_slider.value_changed.connect(_on_master_changed)

	_music_slider = _create_slider(vbox, "Music", 0.6)
	_music_slider.value_changed.connect(_on_music_changed)

	_ambience_slider = _create_slider(vbox, "Ambience", 0.4)
	_ambience_slider.value_changed.connect(_on_ambience_changed)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Language — hidden until translation files are added
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	lang_row.visible = false
	vbox.add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = "Language"
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)

	_language_option = OptionButton.new()
	var lang_keys := Constants.LANGUAGES.keys()
	for i in lang_keys.size():
		var code: String = lang_keys[i]
		var display_name: String = Constants.LANGUAGES[code]
		_language_option.add_item(display_name, i)
		_language_option.set_item_metadata(i, code)
	_language_option.item_selected.connect(_on_language_selected)
	lang_row.add_child(_language_option)

	# Separator
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Replay Tutorial
	var tutorial_btn := Button.new()
	tutorial_btn.text = "Replay Tutorial"
	tutorial_btn.pressed.connect(_on_replay_tutorial)
	vbox.add_child(tutorial_btn)


func _on_replay_tutorial() -> void:
	SignalBus.settings_updated.emit("tutorial_completed", false)
	SignalBus.save_requested.emit()
	# Close the panel and restart scene
	SignalBus.panel_closed.emit("settings")
	call_deferred("_restart_scene")


func _restart_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _create_slider(parent: VBoxContainer, label_text: String, default_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	return slider


func _load_settings() -> void:
	_loading = true
	_master_slider.value = SaveManager.get_setting("master_volume", 0.8)
	_music_slider.value = SaveManager.get_setting("music_volume", 0.6)
	_ambience_slider.value = SaveManager.get_setting("ambience_volume", 0.4)
	_loading = false

	var current_lang: String = SaveManager.get_setting("language", "en")
	for i in _language_option.item_count:
		if _language_option.get_item_metadata(i) == current_lang:
			_language_option.selected = i
			break


func _on_master_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("master", value)


func _on_music_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("music", value)


func _on_ambience_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("ambience", value)


func _on_language_selected(index: int) -> void:
	var lang_code: String = _language_option.get_item_metadata(index)
	SignalBus.settings_updated.emit("language", lang_code)
	SignalBus.language_changed.emit(lang_code)
	AppLogger.info("SettingsPanel", "Language changed", {"lang": lang_code})


func _exit_tree() -> void:
	if _master_slider and _master_slider.value_changed.is_connected(
		_on_master_changed
	):
		_master_slider.value_changed.disconnect(_on_master_changed)
	if _music_slider and _music_slider.value_changed.is_connected(
		_on_music_changed
	):
		_music_slider.value_changed.disconnect(_on_music_changed)
	if _ambience_slider and _ambience_slider.value_changed.is_connected(
		_on_ambience_changed
	):
		_ambience_slider.value_changed.disconnect(_on_ambience_changed)
	if _language_option and _language_option.item_selected.is_connected(
		_on_language_selected
	):
		_language_option.item_selected.disconnect(_on_language_selected)
