## SettingsPanel — Audio volume sliders and language selector.
## Reads/writes via SaveManager.settings and emits signals for live updates.
extends PanelContainer

var _master_slider: HSlider
var _music_slider: HSlider
var _ambience_slider: HSlider
var _language_option: OptionButton
var _ambience_check: CheckButton
var _loading: bool = false
var _root_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	_load_settings()
	SignalBus.language_changed.connect(_on_language_changed)


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
	_root_box = vbox

	# Title
	var title := Label.new()
	title.text = tr("UI_SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Audio section
	var audio_label := Label.new()
	audio_label.text = tr("UI_SETTINGS_VOLUME")
	audio_label.add_theme_font_size_override("font_size", 11)
	audio_label.modulate.a = 0.7
	vbox.add_child(audio_label)

	_master_slider = _create_slider(vbox, tr("UI_SETTINGS_MASTER"), 0.8)
	_master_slider.value_changed.connect(_on_master_changed)

	_music_slider = _create_slider(vbox, tr("UI_SETTINGS_MUSIC"), 0.6)
	_music_slider.value_changed.connect(_on_music_changed)

	_ambience_slider = _create_slider(vbox, tr("UI_SETTINGS_AMBIENCE"), 0.4)
	_ambience_slider.value_changed.connect(_on_ambience_changed)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Selettore lingua: le stringhe del pannello passano da tr() e il pannello
	# si ricostruisce su language_changed, quindi il cambio e` immediato.
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	vbox.add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = tr("UI_SETTINGS_LANGUAGE")
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

	# Ambience on/off: il tappeto sonoro e` indipendente dalla playlist.
	_ambience_check = CheckButton.new()
	_ambience_check.focus_mode = Control.FOCUS_NONE
	_ambience_check.text = tr("UI_SETTINGS_AMBIENCE_ENABLED")
	_ambience_check.toggled.connect(_on_ambience_enabled_toggled)
	vbox.add_child(_ambience_check)

	# Separator
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_build_credits(vbox)

	# Replay Tutorial — only show in-game, not from main menu
	var current_scene := get_tree().current_scene
	var in_game := current_scene and current_scene.scene_file_path == "res://scenes/main/main.tscn"
	if in_game:
		var tutorial_btn := Button.new()
		tutorial_btn.focus_mode = Control.FOCUS_NONE
		tutorial_btn.text = tr("UI_SETTINGS_REPLAY_TUTORIAL")
		tutorial_btn.pressed.connect(_on_replay_tutorial)
		vbox.add_child(tutorial_btn)


## Crediti: la licenza del pack foresta (Eder Muniz) richiede attribuzione
## visibile nel gioco, non solo nel repository.
func _build_credits(parent: VBoxContainer) -> void:
	var credits_label := Label.new()
	credits_label.text = tr("UI_SETTINGS_CREDITS")
	credits_label.add_theme_font_size_override("font_size", 11)
	credits_label.modulate.a = 0.7
	parent.add_child(credits_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 88)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var body := Label.new()
	body.text = tr("CREDITS_BODY")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 10)
	scroll.add_child(body)


func _on_ambience_enabled_toggled(pressed: bool) -> void:
	if _loading:
		return
	AudioManager.set_ambience_enabled(pressed)


## Ricostruisce il pannello dopo un cambio lingua: le stringhe passate da
## tr() sono gia` risolte nei nodi, quindi l'unico modo onesto di aggiornarle
## e` rifare la UI con lo stato corrente.
func _on_language_changed(_lang_code: String) -> void:
	for child in get_children():
		child.queue_free()
	_build_ui()
	_load_settings()


func _on_replay_tutorial() -> void:
	SignalBus.settings_updated.emit("tutorial_completed", false)
	# Flush sincrono su disco: save_requested setta solo dirty flag con
	# auto-save ogni 60s, ma qui ricarichiamo subito la scena, quindi
	# dobbiamo forzare il save immediato altrimenti il tutorial_completed
	# resetta nel save file solo al prossimo tick di auto-save.
	SaveManager.save_game()
	# Close the panel and restart scene
	SignalBus.panel_closed.emit("settings")
	call_deferred("_restart_scene")


func _restart_scene() -> void:
	var current := get_tree().current_scene
	if current and current.scene_file_path == "res://scenes/main/main.tscn":
		get_tree().reload_current_scene()
	# From main menu: do nothing — user starts game via New Game button


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
	if _ambience_check != null:
		_ambience_check.button_pressed = bool(SaveManager.get_setting("ambience_enabled", true))
	_loading = false

	var current_lang: String = SaveManager.get_setting("language", "en")
	for i in _language_option.item_count:
		if _language_option.get_item_metadata(i) == current_lang:
			_language_option.selected = i
			break


func _on_master_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("master", value)
		# Persisti il setting cosi` resta tra sessioni (fix B-008).
		# volume_changed da solo lo applica live ma SaveManager non sa
		# che deve marcare dirty → auto-save 60s non include i nuovi volumi.
		SignalBus.settings_updated.emit("master_volume", value)


func _on_music_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("music", value)
		SignalBus.settings_updated.emit("music_volume", value)


func _on_ambience_changed(value: float) -> void:
	if not _loading:
		SignalBus.volume_changed.emit("ambience", value)
		SignalBus.settings_updated.emit("ambience_volume", value)


func _on_language_selected(index: int) -> void:
	var lang_code: String = _language_option.get_item_metadata(index)
	# I nodi con testo = "UI_KEY" si ri-traducono da soli; quelli costruiti da
	# script con tr() hanno gia` risolto la stringa, per questo il pannello si
	# ricostruisce alla ricezione di language_changed (_on_language_changed).
	TranslationServer.set_locale(lang_code)
	SignalBus.settings_updated.emit("language", lang_code)
	SignalBus.language_changed.emit(lang_code)
	AppLogger.info("SettingsPanel", "Language changed", {"lang": lang_code})


func _exit_tree() -> void:
	if SignalBus.language_changed.is_connected(_on_language_changed):
		SignalBus.language_changed.disconnect(_on_language_changed)
	if _ambience_check and _ambience_check.toggled.is_connected(_on_ambience_enabled_toggled):
		_ambience_check.toggled.disconnect(_on_ambience_enabled_toggled)
	if _master_slider and _master_slider.value_changed.is_connected(_on_master_changed):
		_master_slider.value_changed.disconnect(_on_master_changed)
	if _music_slider and _music_slider.value_changed.is_connected(_on_music_changed):
		_music_slider.value_changed.disconnect(_on_music_changed)
	if _ambience_slider and _ambience_slider.value_changed.is_connected(_on_ambience_changed):
		_ambience_slider.value_changed.disconnect(_on_ambience_changed)
	if _language_option and _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.disconnect(_on_language_selected)
