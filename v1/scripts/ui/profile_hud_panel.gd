## ProfileHUDPanel — Mini pannello orizzontale del profilo (feature T-R-015).
##
## Scope SCHELETRO (pre-demo 2026-04-17):
## - Label nome utente
## - Label placeholder "Immagine profilo (click per scegliere)" (T-R-015c post-demo)
## - Label placeholder "Badge" (T-R-015d post-demo)
## - Bottone "Impostazioni" (apre settings_panel via PanelManager)
## - Bottone language toggle EN/IT (solo visuale, T-R-015g .po files post-demo)
## - Mood slider HSlider 0..1 emette mood_level_changed (T-R-015i effects post-demo)
##
## Layout: PanelContainer top-right anchored, dimensione compatta 420x140.
## Stile: coerente con cozy_theme.tres, testo crema su sfondo scuro.
extends PanelContainer

const MOOD_SETTING_KEY := "mood_level"
const LANGUAGE_SETTING_KEY := "language"

var _name_label: Label = null
var _profile_btn: Button = null
var _settings_btn: Button = null
var _lang_btn: Button = null
var _close_btn: Button = null
var _mood_slider: HSlider = null
var _loading: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(420, 140)
	_build_ui()
	_load_state()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Row 1: profile image placeholder + name + lang + settings
	var row_top := HBoxContainer.new()
	row_top.add_theme_constant_override("separation", 10)
	vbox.add_child(row_top)

	# Profile image placeholder (64x64 button per T-R-015c futuro)
	_profile_btn = Button.new()
	_profile_btn.custom_minimum_size = Vector2(56, 56)
	_profile_btn.text = "👤"
	_profile_btn.focus_mode = Control.FOCUS_NONE
	_profile_btn.tooltip_text = "Immagine profilo (placeholder — sceglibile da file in futuro)"
	_profile_btn.add_theme_font_size_override("font_size", 28)
	# T-R-015c post-demo: pressed.connect a FileDialog per scelta immagine locale
	row_top.add_child(_profile_btn)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_top.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.text = "Ospite"
	_name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(_name_label)

	var badges_label := Label.new()
	badges_label.text = "🏅 Badge in arrivo..."
	badges_label.add_theme_font_size_override("font_size", 11)
	badges_label.modulate.a = 0.6
	info_vbox.add_child(badges_label)

	# Language toggle — nascosto pre-demo, i18n completa in arrivo post-demo.
	_lang_btn = Button.new()
	_lang_btn.focus_mode = Control.FOCUS_NONE
	_lang_btn.visible = false

	# Settings button
	_settings_btn = Button.new()
	_settings_btn.custom_minimum_size = Vector2(40, 28)
	_settings_btn.focus_mode = Control.FOCUS_NONE
	_settings_btn.text = "⚙"
	_settings_btn.tooltip_text = "Impostazioni"
	_settings_btn.add_theme_font_size_override("font_size", 18)
	_settings_btn.pressed.connect(_on_settings_pressed)
	row_top.add_child(_settings_btn)

	# Close button (X) — re-emits profile_hud_requested to toggle-close.
	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(32, 28)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "✕"
	_close_btn.tooltip_text = "Chiudi"
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.pressed.connect(_on_close_pressed)
	row_top.add_child(_close_btn)

	# Row 2: mood bar
	var mood_row := HBoxContainer.new()
	mood_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mood_row)

	var mood_label := Label.new()
	mood_label.text = "Mood"
	mood_label.custom_minimum_size = Vector2(50, 0)
	mood_label.add_theme_font_size_override("font_size", 12)
	mood_row.add_child(mood_label)

	_mood_slider = HSlider.new()
	_mood_slider.min_value = 0.0
	_mood_slider.max_value = 1.0
	_mood_slider.step = 0.01
	_mood_slider.value = 1.0  # default cozy originale
	_mood_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_slider.focus_mode = Control.FOCUS_NONE
	_mood_slider.value_changed.connect(_on_mood_changed)
	mood_row.add_child(_mood_slider)

	var mood_hint := Label.new()
	mood_hint.text = "🌧 ↔ 🌸"
	mood_hint.custom_minimum_size = Vector2(60, 0)
	mood_hint.add_theme_font_size_override("font_size", 12)
	mood_row.add_child(mood_hint)


func _load_state() -> void:
	_loading = true
	# Nome utente da AuthManager
	if _name_label != null:
		var username: String = AuthManager.current_username
		if username.is_empty() or username == "guest":
			_name_label.text = "Ospite"
		else:
			_name_label.text = username
	# Mood slider da settings
	if _mood_slider != null:
		var saved_mood: float = SaveManager.get_setting(MOOD_SETTING_KEY, 1.0)
		_mood_slider.value = clampf(saved_mood, 0.0, 1.0)
	# Language button label
	_refresh_lang_button()
	_loading = false


func _refresh_lang_button() -> void:
	if _lang_btn == null:
		return
	var current_lang: String = SaveManager.get_setting(LANGUAGE_SETTING_KEY, "it")
	if current_lang == "it":
		_lang_btn.text = "IT"
		_lang_btn.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3, 1.0))
	else:
		_lang_btn.text = "EN"
		_lang_btn.add_theme_color_override("font_color", Color(0.2, 0.4, 0.8, 1.0))


func _on_lang_toggled() -> void:
	var current: String = SaveManager.get_setting(LANGUAGE_SETTING_KEY, "it")
	var new_lang: String = "en" if current == "it" else "it"
	SignalBus.settings_updated.emit(LANGUAGE_SETTING_KEY, new_lang)
	SignalBus.language_changed.emit(new_lang)
	_refresh_lang_button()
	SignalBus.toast_requested.emit(
		"Lingua: %s" % new_lang.to_upper() + " (i18n reale in arrivo)", "info"
	)


func _on_settings_pressed() -> void:
	# Chiude il profilo HUD e apre settings standalone. Stesso comportamento
	# del bottone Opzioni del HUD principale — cosi il flusso e consistente.
	SignalBus.profile_hud_closed.emit()


func _on_close_pressed() -> void:
	# Trova PanelManager e chiudi direttamente — no signal bouncing.
	var root := get_tree().root
	var pm := root.find_child("PanelManager", true, false)
	if pm != null and pm.has_method("close_current_panel"):
		pm.close_current_panel()
		return
	# Fallback — auto-destroy se PanelManager non trovato.
	queue_free()


func _on_mood_changed(value: float) -> void:
	if _loading:
		return
	SignalBus.mood_level_changed.emit(value)
	SignalBus.settings_updated.emit(MOOD_SETTING_KEY, value)


func _exit_tree() -> void:
	if _settings_btn != null and _settings_btn.pressed.is_connected(_on_settings_pressed):
		_settings_btn.pressed.disconnect(_on_settings_pressed)
	if _lang_btn != null and _lang_btn.pressed.is_connected(_on_lang_toggled):
		_lang_btn.pressed.disconnect(_on_lang_toggled)
	if _close_btn != null and _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.disconnect(_on_close_pressed)
	if _mood_slider != null and _mood_slider.value_changed.is_connected(_on_mood_changed):
		_mood_slider.value_changed.disconnect(_on_mood_changed)
