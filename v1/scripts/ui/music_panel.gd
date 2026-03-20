## MusicPanel — Lo-fi music player with transport controls, playlist mode, and ambience toggles.
## Integrates with AudioManager for playback and SignalBus for live updates.
extends PanelContainer

var _track_label: Label
var _play_button: Button
var _mode_button: Button
var _volume_slider: HSlider
var _ambience_container: VBoxContainer


func _ready() -> void:
	_build_ui()
	_update_track_display()
	_update_play_button()
	_update_mode_button()

	SignalBus.track_changed.connect(_on_track_changed)
	SignalBus.track_play_pause_toggled.connect(_on_play_pause_changed)


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
	title.text = "Music Player"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Now playing
	_track_label = Label.new()
	_track_label.text = "No track"
	_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_track_label)

	# Transport controls
	var transport := HBoxContainer.new()
	transport.alignment = BoxContainer.ALIGNMENT_CENTER
	transport.add_theme_constant_override("separation", 8)
	vbox.add_child(transport)

	var prev_btn := Button.new()
	prev_btn.text = "<<"
	prev_btn.custom_minimum_size = Vector2(36, 30)
	prev_btn.pressed.connect(_on_prev)
	transport.add_child(prev_btn)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.custom_minimum_size = Vector2(50, 30)
	_play_button.pressed.connect(_on_play_pause)
	transport.add_child(_play_button)

	var next_btn := Button.new()
	next_btn.text = ">>"
	next_btn.custom_minimum_size = Vector2(36, 30)
	next_btn.pressed.connect(_on_next)
	transport.add_child(next_btn)

	# Playlist mode
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "Mode:"
	mode_row.add_child(mode_label)

	_mode_button = Button.new()
	_mode_button.custom_minimum_size = Vector2(80, 0)
	_mode_button.pressed.connect(_on_mode_cycle)
	mode_row.add_child(_mode_button)

	# Volume slider
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	vbox.add_child(vol_row)

	var vol_label := Label.new()
	vol_label.text = "Vol"
	vol_label.custom_minimum_size = Vector2(30, 0)
	vol_row.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = AudioManager.music_volume
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)

	# Ambience section
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var amb_title := Label.new()
	amb_title.text = "Ambience"
	amb_title.add_theme_font_size_override("font_size", 11)
	amb_title.modulate.a = 0.7
	vbox.add_child(amb_title)

	var amb_scroll := ScrollContainer.new()
	amb_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	amb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(amb_scroll)

	_ambience_container = VBoxContainer.new()
	_ambience_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ambience_container.add_theme_constant_override("separation", 4)
	amb_scroll.add_child(_ambience_container)

	_build_ambience_toggles()

	# Import button
	var import_sep := HSeparator.new()
	vbox.add_child(import_sep)

	var import_btn := Button.new()
	import_btn.text = "Import MP3/WAV"
	import_btn.custom_minimum_size = Vector2(0, 30)
	import_btn.pressed.connect(_on_import_pressed)
	vbox.add_child(import_btn)


func _build_ambience_toggles() -> void:
	var ambience_list: Array = GameManager.tracks_catalog.get("ambience", [])
	for amb_data in ambience_list:
		if amb_data is Dictionary:
			var amb_id: String = amb_data.get("id", "")
			var amb_name: String = amb_data.get("name", amb_id.capitalize())
			if not amb_id.is_empty():
				_add_ambience_toggle(amb_id, amb_name)


func _add_ambience_toggle(amb_id: String, amb_name: String) -> void:
	var check := CheckButton.new()
	check.text = amb_name
	check.button_pressed = amb_id in AudioManager.active_ambience
	check.toggled.connect(_on_ambience_toggle.bind(amb_id))
	_ambience_container.add_child(check)


func _update_track_display() -> void:
	if AudioManager.tracks.is_empty():
		_track_label.text = "No tracks loaded"
		return
	if AudioManager.current_track_index >= AudioManager.tracks.size():
		_track_label.text = "No track"
		return
	var track: Dictionary = AudioManager.tracks[AudioManager.current_track_index]
	var title: String = track.get("title", "Unknown")
	var artist: String = track.get("artist", "")
	if artist.is_empty():
		_track_label.text = title
	else:
		_track_label.text = "%s — %s" % [title, artist]


func _update_play_button() -> void:
	_play_button.text = "Pause" if AudioManager.is_playing else "Play"


func _update_mode_button() -> void:
	match AudioManager.playlist_mode:
		Constants.PLAYLIST_SEQUENTIAL:
			_mode_button.text = "Sequential"
		Constants.PLAYLIST_SHUFFLE:
			_mode_button.text = "Shuffle"
		Constants.PLAYLIST_REPEAT_ONE:
			_mode_button.text = "Repeat"
		_:
			_mode_button.text = AudioManager.playlist_mode


func _on_prev() -> void:
	AudioManager.previous_track()


func _on_next() -> void:
	AudioManager.next_track()


func _on_play_pause() -> void:
	if AudioManager.is_playing:
		AudioManager.pause()
	else:
		AudioManager.play()


func _on_mode_cycle() -> void:
	match AudioManager.playlist_mode:
		Constants.PLAYLIST_SEQUENTIAL:
			AudioManager.playlist_mode = Constants.PLAYLIST_SHUFFLE
		Constants.PLAYLIST_SHUFFLE:
			AudioManager.playlist_mode = Constants.PLAYLIST_REPEAT_ONE
		Constants.PLAYLIST_REPEAT_ONE:
			AudioManager.playlist_mode = Constants.PLAYLIST_SEQUENTIAL
		_:
			AudioManager.playlist_mode = Constants.PLAYLIST_SEQUENTIAL
	_update_mode_button()


func _on_volume_changed(value: float) -> void:
	SignalBus.volume_changed.emit("music", value)


func _on_ambience_toggle(is_active: bool, amb_id: String) -> void:
	SignalBus.ambience_toggled.emit(amb_id, is_active)


func _on_track_changed(_index: int) -> void:
	_update_track_display()


func _on_play_pause_changed(_is_playing: bool) -> void:
	_update_play_button()


func _on_import_pressed() -> void:
	if OS.has_feature("web"):
		AppLogger.warn("MusicPanel", "File import not supported on web")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.mp3 ; MP3 Files", "*.wav ; WAV Files"])
	dialog.title = "Import Audio Track"
	dialog.size = Vector2i(600, 400)
	dialog.file_selected.connect(_on_file_selected)
	add_child(dialog)
	dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	AudioManager.import_external_track(path)
	_update_track_display()


func _exit_tree() -> void:
	if SignalBus.track_changed.is_connected(_on_track_changed):
		SignalBus.track_changed.disconnect(_on_track_changed)
	if SignalBus.track_play_pause_toggled.is_connected(_on_play_pause_changed):
		SignalBus.track_play_pause_toggled.disconnect(_on_play_pause_changed)
