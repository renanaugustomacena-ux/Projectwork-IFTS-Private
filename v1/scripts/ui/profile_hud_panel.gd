## ProfileHUDPanel — Mini pannello orizzontale del profilo (feature T-R-015).
##
## Contenuto, tutto implementato (la docstring elencava questi punti come
## segnaposto "post-demo" molto dopo che erano stati completati — G-063):
## - Label nome utente
## - Immagine profilo: click per scegliere un PNG, validata (tetto 10 MB +
##   magic byte) e scritta con staging write-then-rename (T-R-015c)
## - Badge sbloccati, letti da BadgeManager (T-R-015d)
## - Bottone "Impostazioni" (apre settings_panel via PanelManager)
## - Toggle lingua IT/EN: cambia davvero locale a runtime via
##   TranslationServer, l'intera UI si ri-etichetta (T-R-015g)
## - Mood slider HSlider 0..1: emette mood_level_changed, che pilota overlay,
##   pioggia, ambience, musica e comportamento del pet (T-R-015i)
##
## Layout: PanelContainer top-right anchored, dimensione compatta 420x140.
## Stile: coerente con cozy_theme.tres, testo crema su sfondo scuro.
extends PanelContainer

const MOOD_SETTING_KEY := "mood_level"
const PROFILE_IMAGE_PATH := "user://profile_image.png"
# Write-then-rename staging path (Phase D): the previous good avatar must
# survive any failed save, so writes never touch PROFILE_IMAGE_PATH directly.
const PROFILE_IMAGE_TMP_PATH := "user://profile_image.tmp.png"
const PROFILE_IMAGE_SIZE := 128
const MAX_PROFILE_IMAGE_BYTES := 10 * 1024 * 1024  # 10 MB cap on selected file
# Decompression-bomb cap (Phase D): a ~1 MB 16000x16000 PNG passes the byte
# cap but decodes to 1+ GB. Either dimension above this rejects the file.
const MAX_PROFILE_IMAGE_DIMENSION := 8192

var _name_label: Label = null
var _profile_btn: Button = null
var _profile_tex_rect: TextureRect = null
var _settings_btn: Button = null
var _close_btn: Button = null
var _mood_slider: HSlider = null
var _file_dialog: FileDialog = null
var _badges_row: HBoxContainer = null  # T-R-015d


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
	_profile_btn.tooltip_text = tr("UI_PROFILE_IMAGE_TOOLTIP")
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
	_name_label.text = tr("UI_PROFILE_GUEST")
	_name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(_name_label)

	# T-R-015d: riga badge. HBoxContainer di Label (emoji icon) — unlocked
	# colore pieno, locked grayed. First fill happens in _load_state (after
	# account state is available — V-088 / 4.1.7-L271), then on badge_unlocked
	# and on every load_completed so boot always shows real badges.
	var badges_row := HBoxContainer.new()
	badges_row.name = "BadgesRow"
	badges_row.add_theme_constant_override("separation", 4)
	info_vbox.add_child(badges_row)
	_badges_row = badges_row
	SignalBus.badge_unlocked.connect(_on_badge_unlocked)
	SignalBus.load_completed.connect(_refresh_badges)
	# I tooltip sono costruiti con tr()/Helpers all'apertura del pannello:
	# senza questo restano nella lingua attiva in quel momento anche dopo un
	# cambio lingua a pannello aperto.
	SignalBus.language_changed.connect(_on_language_changed)

	# Settings button
	_settings_btn = Button.new()
	_settings_btn.custom_minimum_size = Vector2(40, 28)
	_settings_btn.focus_mode = Control.FOCUS_NONE
	_settings_btn.text = "⚙"
	_settings_btn.tooltip_text = tr("UI_PROFILE_SETTINGS_TOOLTIP")
	_settings_btn.add_theme_font_size_override("font_size", 18)
	_settings_btn.pressed.connect(_on_settings_pressed)
	row_top.add_child(_settings_btn)

	# Close button (X) — re-emits profile_hud_requested to toggle-close.
	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(32, 28)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "✕"
	_close_btn.tooltip_text = tr("UI_PROFILE_CLOSE_TOOLTIP")
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.pressed.connect(_on_close_pressed)
	row_top.add_child(_close_btn)

	# Row 2: mood bar
	var mood_row := HBoxContainer.new()
	mood_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mood_row)

	var mood_label := Label.new()
	mood_label.text = tr("UI_PROFILE_MOOD_LABEL")
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
	mood_hint.text = tr("UI_PROFILE_MOOD_HINT")
	mood_hint.custom_minimum_size = Vector2(60, 0)
	mood_hint.add_theme_font_size_override("font_size", 12)
	mood_row.add_child(mood_hint)


func _load_state() -> void:
	# Nome utente da AuthManager
	if _name_label != null:
		var username: String = AuthManager.current_username
		if username.is_empty() or username == "guest":
			_name_label.text = tr("UI_PROFILE_GUEST")
		else:
			_name_label.text = username
	# Mood slider from settings. set_value_no_signal (V-087 / 4.1.7-L160):
	# the initial value must not fire value_changed, so no _loading latch is
	# needed — only real user interaction reaches _on_mood_changed.
	if _mood_slider != null:
		var saved_mood: float = SaveManager.get_setting(MOOD_SETTING_KEY, 1.0)
		_mood_slider.set_value_no_signal(clampf(saved_mood, 0.0, 1.0))
	# Profile image (T-R-015c): carica da user:// se esiste
	_refresh_profile_image()
	# Badges last: account state is loaded now (V-088 / 4.1.7-L271).
	_refresh_badges()


func _refresh_profile_image() -> void:
	if _profile_tex_rect == null or _profile_btn == null:
		return
	var saved_path: String = SaveManager.get_setting("profile_image_path", "")
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
	_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg ; Immagini (PNG, JPG)"])
	_file_dialog.title = "Scegli immagine profilo (solo locale)"
	_file_dialog.file_selected.connect(_on_profile_image_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_profile_image_selected(path: String) -> void:
	# Carica, ridimensiona a 128x128 per risparmiare disco, salva in user://
	# Privacy: MAI upload cloud, solo filesystem locale.
	# Validation: byte-size cap + magic-byte sniff BEFORE any decode — the
	# FileDialog extension filter is advisory only and can be bypassed.
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		SignalBus.toast_requested.emit(tr("TOAST_IMG_UNREADABLE"), "error")
		return
	if bytes.size() > MAX_PROFILE_IMAGE_BYTES:
		# i18n key in Phase F
		SignalBus.toast_requested.emit(tr("TOAST_IMG_TOO_LARGE"), "error")
		return
	var img := _decode_profile_image(bytes)
	if img == null or img.is_empty():
		# i18n key in Phase F
		SignalBus.toast_requested.emit(tr("TOAST_IMG_INVALID"), "error")
		return
	img.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
	# Write-then-rename (Phase D): saving straight onto PROFILE_IMAGE_PATH and
	# deleting on failure destroyed the user's previous good avatar whenever
	# the write failed WITHOUT truncating (e.g. read-only file). The rename
	# replaces the old image only after a fully successful write.
	var err := img.save_png(PROFILE_IMAGE_TMP_PATH)
	if err != OK:
		_remove_tmp_profile_image()
		SignalBus.toast_requested.emit(tr("TOAST_IMG_SAVE_ERROR") % err, "error")
		return
	var rename_err := DirAccess.rename_absolute(PROFILE_IMAGE_TMP_PATH, PROFILE_IMAGE_PATH)
	if rename_err != OK:
		_remove_tmp_profile_image()
		SignalBus.toast_requested.emit(tr("TOAST_IMG_SAVE_ERROR") % rename_err, "error")
		return
	SignalBus.settings_updated.emit("profile_image_path", PROFILE_IMAGE_PATH)
	_refresh_profile_image()
	SignalBus.toast_requested.emit(tr("TOAST_IMG_UPDATED"), "success")


## Decodes the raw bytes as PNG or JPEG after magic-byte sniffing.
## Returns null when the bytes are neither PNG (89 50 4E 47) nor JPEG
## (FF D8 FF), when the declared/decoded dimensions exceed
## MAX_PROFILE_IMAGE_DIMENSION (decompression-bomb guard, Phase D), or when
## the matching decoder rejects the buffer.
func _decode_profile_image(bytes: PackedByteArray) -> Image:
	var is_png := bytes.size() >= 4 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47
	var is_jpg := bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF
	if not is_png and not is_jpg:
		return null
	# PNG dimensions come straight from the IHDR header BEFORE any decode —
	# rejecting here avoids the 1+ GB transient allocation entirely.
	if is_png and not _png_dimensions_ok(bytes):
		return null
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes) if is_png else img.load_jpg_from_buffer(bytes)
	if err != OK:
		return null
	# JPEG dimensions are not cheaply parseable pre-decode: enforce the cap
	# right after decode, before the main-thread Lanczos resize.
	if img.get_width() > MAX_PROFILE_IMAGE_DIMENSION or img.get_height() > MAX_PROFILE_IMAGE_DIMENSION:
		return null
	return img


## True when the PNG IHDR declares sane dimensions. IHDR is the mandatory
## first chunk: width and height are big-endian uint32 at byte offsets 16 and
## 20 (8-byte signature + 4-byte chunk length + 4-byte "IHDR" type).
func _png_dimensions_ok(bytes: PackedByteArray) -> bool:
	if bytes.size() < 24:
		return false
	if bytes[12] != 0x49 or bytes[13] != 0x48 or bytes[14] != 0x44 or bytes[15] != 0x52:
		return false  # first chunk is not IHDR — malformed PNG
	var width := (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]
	var height := (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]
	if width < 1 or height < 1:
		return false
	return width <= MAX_PROFILE_IMAGE_DIMENSION and height <= MAX_PROFILE_IMAGE_DIMENSION


## Removes the temporary avatar file left behind by a failed save or rename.
## The final PROFILE_IMAGE_PATH is deliberately never deleted here: on any
## failure the previous good avatar must survive (Phase D).
func _remove_tmp_profile_image() -> void:
	if not FileAccess.file_exists(PROFILE_IMAGE_TMP_PATH):
		return
	var err := DirAccess.remove_absolute(PROFILE_IMAGE_TMP_PATH)
	if err != OK:
		AppLogger.warn("ProfileHUD", "Failed to remove tmp profile image", {"err": err})


## Il cambio lingua avviene nel pannello Impostazioni; qui basta ricostruire i
## tooltip dei badge, che tr()/Helpers hanno gia` risolto all'apertura.
func _on_language_changed(_lang_code: String) -> void:
	_refresh_badges()


func _on_settings_pressed() -> void:
	# Chiude il profilo HUD e apre settings standalone. Stesso comportamento
	# del bottone Opzioni del HUD principale — cosi il flusso e consistente.
	SignalBus.profile_hud_closed.emit()


func _on_close_pressed() -> void:
	# Re-emit profile_hud_requested: main.gd lo instrada a toggle_panel, che
	# col pannello aperto sullo stesso nome esegue close_current_panel.
	# Identico percorso usato dal bottone icona profilo → un solo code path.
	SignalBus.profile_hud_requested.emit()


func _on_mood_changed(value: float) -> void:
	SignalBus.mood_level_changed.emit(value)
	SignalBus.settings_updated.emit(MOOD_SETTING_KEY, value)


func _refresh_badges() -> void:
	if _badges_row == null:
		return
	# Rimuovi children vecchi
	for child in _badges_row.get_children():
		child.queue_free()
	var catalog: Array = GameManager.badges_catalog.get("badges", [])
	var unlocked_rows: Array = BadgeManager.get_unlocked_badges()
	var unlocked_ids: Dictionary = {}
	for row in unlocked_rows:
		if row is Dictionary:
			unlocked_ids[row.get("badge_id", "")] = true
	for badge in catalog:
		if not (badge is Dictionary):
			continue
		var icon: String = badge.get("icon", "🏅")
		var is_unlocked: bool = unlocked_ids.has(badge.get("id", ""))
		var lbl := Label.new()
		lbl.text = icon
		lbl.add_theme_font_size_override("font_size", 14)
		# Helpers.locale_* e non i campi grezzi: name/description nel catalogo
		# sono le stringhe italiane, quindi leggerli direttamente rendeva i
		# tooltip monolingua in qualunque locale.
		lbl.tooltip_text = "%s — %s" % [Helpers.locale_label(badge), Helpers.locale_description(badge)]
		if not is_unlocked:
			lbl.modulate = Color(0.4, 0.4, 0.4, 0.5)  # locked grey
		_badges_row.add_child(lbl)


func _on_badge_unlocked(_badge_id: String) -> void:
	_refresh_badges()


func _exit_tree() -> void:
	if _settings_btn != null and _settings_btn.pressed.is_connected(_on_settings_pressed):
		_settings_btn.pressed.disconnect(_on_settings_pressed)
	if _close_btn != null and _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.disconnect(_on_close_pressed)
	if _mood_slider != null and _mood_slider.value_changed.is_connected(_on_mood_changed):
		_mood_slider.value_changed.disconnect(_on_mood_changed)
	if _profile_btn != null and _profile_btn.pressed.is_connected(_on_profile_btn_pressed):
		_profile_btn.pressed.disconnect(_on_profile_btn_pressed)
	if _file_dialog != null and is_instance_valid(_file_dialog):
		if _file_dialog.file_selected.is_connected(_on_profile_image_selected):
			_file_dialog.file_selected.disconnect(_on_profile_image_selected)
	if SignalBus.badge_unlocked.is_connected(_on_badge_unlocked):
		SignalBus.badge_unlocked.disconnect(_on_badge_unlocked)
	if SignalBus.load_completed.is_connected(_refresh_badges):
		SignalBus.load_completed.disconnect(_refresh_badges)
