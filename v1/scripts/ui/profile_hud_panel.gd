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
const PROFILE_IMAGE_PATH := "user://profile_image.png"
const PROFILE_IMAGE_SIZE := 128

var _name_label: Label = null
var _profile_btn: Button = null
var _profile_tex_rect: TextureRect = null
var _settings_btn: Button = null
var _lang_btn: Button = null
var _close_btn: Button = null
var _mood_slider: HSlider = null
var _loading: bool = false
var _file_dialog: FileDialog = null


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

	# Profile image button (T-R-015c): click -> FileDialog per scegliere PNG/JPG
	# locale. L'immagine resta SOLO su disco locale (user://profile_image.png),
	# mai caricata su Supabase (privacy-first).
	_profile_btn = Button.new()
	_profile_btn.custom_minimum_size = Vector2(56, 56)
	_profile_btn.focus_mode = Control.FOCUS_NONE
	_profile_btn.tooltip_text = (
		"Immagine profilo — click per scegliere PNG/JPG dal disco.\n"
		+ "Salvata solo in locale, mai inviata online."
	)
	_profile_btn.flat = true
	_profile_btn.pressed.connect(_on_profile_btn_pressed)
	row_top.add_child(_profile_btn)

	# TextureRect figlio mostra l'immagine (o placeholder emoji se assente)
	_profile_tex_rect = TextureRect.new()
	_profile_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_profile_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_profile_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_profile_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_profile_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_btn.add_child(_profile_tex_rect)

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
	# Profile image (T-R-015c): carica da user:// se esiste
	_refresh_profile_image()
	_loading = false


func _refresh_profile_image() -> void:
	if _profile_tex_rect == null or _profile_btn == null:
		return
	var saved_path: String = SaveManager.get_setting(
		"profile_image_path", ""
	)
	var file_path: String = saved_path if saved_path != "" else PROFILE_IMAGE_PATH
	if not FileAccess.file_exists(file_path):
		# Fallback: mostra emoji placeholder come Button.text
		_profile_btn.text = "👤"
		_profile_btn.add_theme_font_size_override("font_size", 28)
		_profile_tex_rect.texture = null
		return
	var img := Image.load_from_file(file_path)
	if img == null or img.is_empty():
		_profile_btn.text = "👤"
		_profile_tex_rect.texture = null
		return
	_profile_btn.text = ""
	var tex := ImageTexture.create_from_image(img)
	_profile_tex_rect.texture = tex


func _on_profile_btn_pressed() -> void:
	# T-R-015c: apre FileDialog nativo per selezione PNG/JPG.
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.popup_centered(Vector2i(800, 600))
		return
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(
		["*.png,*.jpg,*.jpeg ; Immagini (PNG, JPG)"]
	)
	_file_dialog.title = "Scegli immagine profilo (solo locale)"
	_file_dialog.file_selected.connect(_on_profile_image_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_profile_image_selected(path: String) -> void:
	# Carica, ridimensiona a 128x128 per risparmiare disco, salva in user://
	# Privacy: MAI upload cloud, solo filesystem locale.
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		SignalBus.toast_requested.emit(
			"Impossibile leggere l'immagine selezionata", "error"
		)
		return
	img.resize(
		PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS
	)
	var err := img.save_png(PROFILE_IMAGE_PATH)
	if err != OK:
		SignalBus.toast_requested.emit(
			"Errore salvataggio immagine (%d)" % err, "error"
		)
		return
	SignalBus.settings_updated.emit("profile_image_path", PROFILE_IMAGE_PATH)
	_refresh_profile_image()
	SignalBus.toast_requested.emit(
		"Immagine profilo aggiornata (solo locale)", "success"
	)


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
	if _profile_btn != null and _profile_btn.pressed.is_connected(_on_profile_btn_pressed):
		_profile_btn.pressed.disconnect(_on_profile_btn_pressed)
	if _file_dialog != null and is_instance_valid(_file_dialog):
		if _file_dialog.file_selected.is_connected(_on_profile_image_selected):
			_file_dialog.file_selected.disconnect(_on_profile_image_selected)
