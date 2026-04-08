## AudioManager — Handles lo-fi music playback, playlists, and ambient sound mixing.
## Supports dual-player crossfade, simultaneous music + multiple ambience streams.
extends Node

const VOLUME_DB_FLOOR := -80.0
const MAX_AUDIO_FILE_SIZE := 52_428_800  # 50 MB limit for external audio imports

var tracks: Array = []
var current_track_index: int = 0
var is_playing: bool = false
var playlist_mode: String = "shuffle":  # "sequential", "shuffle", "repeat_one"
	set(value):
		if value not in ["sequential", "shuffle", "repeat_one"]:
			push_warning("AudioManager: playlist_mode invalido '%s', fallback 'shuffle'" % value)
			value = "shuffle"
		playlist_mode = value
		_sync_music_state()

# Active ambience sound IDs (private — use get_active_ambience() to read)
var _active_ambience: Array = []

# Volume levels (0.0 to 1.0, converted to dB for AudioStreamPlayer)
var master_volume: float = 0.8
var music_volume: float = 0.6
var ambience_volume: float = 0.4

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _crossfade_tween: Tween
var _ambience_players: Dictionary = {}


func _ready() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Master"
	_music_player_a.finished.connect(_on_track_finished.bind(_music_player_a))
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Master"
	_music_player_b.finished.connect(_on_track_finished.bind(_music_player_b))
	add_child(_music_player_b)

	_active_player = _music_player_a

	SignalBus.volume_changed.connect(_on_volume_changed)
	SignalBus.ambience_toggled.connect(_on_ambience_toggled)
	SignalBus.load_completed.connect(_on_load_completed)

	_load_tracks()
	call_deferred("_auto_start_music")


func _load_tracks() -> void:
	if GameManager.tracks_catalog.has("tracks"):
		tracks = GameManager.tracks_catalog["tracks"]


func _on_load_completed() -> void:
	var state: Dictionary = SaveManager.get_music_state()
	current_track_index = state.get("current_track_index", 0)
	playlist_mode = state.get("playlist_mode", "shuffle")
	_active_ambience = state.get("active_ambience", [])

	if not tracks.is_empty():
		current_track_index = clampi(current_track_index, 0, tracks.size() - 1)

	master_volume = SaveManager.get_setting("master_volume", 0.8)
	music_volume = SaveManager.get_setting("music_volume", 0.6)
	ambience_volume = SaveManager.get_setting("ambience_volume", 0.4)

	_apply_music_volume()

	for amb_id in _active_ambience:
		_start_ambience(amb_id)


func play() -> void:
	if tracks.is_empty():
		push_warning("AudioManager: no tracks loaded")
		return

	if current_track_index >= tracks.size():
		current_track_index = 0

	var raw = tracks[current_track_index]
	if raw is not Dictionary:
		push_error("AudioManager: track at index %d is not a Dictionary" % current_track_index)
		return
	var track_data: Dictionary = raw
	var path: String = track_data.get("path", "")
	if path.is_empty():
		push_warning("AudioManager: track at index %d has no path" % current_track_index)
		return

	var stream: AudioStream = _load_audio_stream(path)
	if stream == null:
		push_error("AudioManager: failed to load audio stream: %s" % path)
		return

	_crossfade_to(stream)
	is_playing = true
	SignalBus.track_changed.emit(current_track_index)
	SignalBus.track_play_pause_toggled.emit(true)


func pause() -> void:
	_active_player.stream_paused = not _active_player.stream_paused
	is_playing = not _active_player.stream_paused
	SignalBus.track_play_pause_toggled.emit(is_playing)


func stop() -> void:
	_music_player_a.stop()
	_music_player_b.stop()
	is_playing = false
	SignalBus.track_play_pause_toggled.emit(false)


func next_track() -> void:
	if tracks.is_empty():
		return
	match playlist_mode:
		"sequential":
			current_track_index = (current_track_index + 1) % tracks.size()
		"shuffle":
			var new_index := current_track_index
			while new_index == current_track_index and tracks.size() > 1:
				new_index = randi() % tracks.size()
			current_track_index = new_index
		"repeat_one":
			pass  # Same track
	play()


func previous_track() -> void:
	if tracks.is_empty():
		return
	current_track_index = (current_track_index - 1 + tracks.size()) % tracks.size()
	play()


func _auto_start_music() -> void:
	if not tracks.is_empty() and not is_playing:
		play()


func _load_audio_stream(path: String) -> AudioStream:
	# Only allow res:// and user:// paths to prevent path traversal
	if not path.begins_with("res://") and not path.begins_with("user://"):
		AppLogger.error("AudioManager", "Blocked non-resource audio path", {"path": path})
		return null

	# user:// MP3 files need manual loading
	if path.begins_with("user://"):
		var ext := path.get_extension().to_lower()
		if ext == "mp3":
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				AppLogger.error("AudioManager", "Cannot open audio file", {"path": path})
				return null
			if file.get_length() > MAX_AUDIO_FILE_SIZE:
				file.close()
				AppLogger.error("AudioManager", "Audio file too large", {"path": path, "size": file.get_length(), "max": MAX_AUDIO_FILE_SIZE})
				return null
			var buffer := file.get_buffer(file.get_length())
			file.close()
			var mp3_stream := AudioStreamMP3.new()
			mp3_stream.data = buffer
			return mp3_stream

	# Resource paths (res:// and user:// wav/ogg)
	return load(path) as AudioStream


func _crossfade_to(stream: AudioStream) -> void:
	# Kill any running crossfade and stop the player that was fading out
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		_crossfade_tween = null
		if _active_player == _music_player_a and _music_player_b.playing:
			_music_player_b.stop()
		elif _active_player == _music_player_b and _music_player_a.playing:
			_music_player_a.stop()

	var next_player: AudioStreamPlayer
	if _active_player == _music_player_a:
		next_player = _music_player_b
	else:
		next_player = _music_player_a

	next_player.stream = stream
	next_player.volume_db = VOLUME_DB_FLOOR
	next_player.play()

	var target_db := _get_music_volume_db()

	if _active_player.playing:
		var old_player := _active_player
		_crossfade_tween = create_tween()
		_crossfade_tween.set_parallel(true)
		_crossfade_tween.tween_property(old_player, "volume_db", VOLUME_DB_FLOOR, Constants.CROSSFADE_DURATION)
		_crossfade_tween.tween_property(next_player, "volume_db", target_db, Constants.CROSSFADE_DURATION)
		_crossfade_tween.set_parallel(false)
		_crossfade_tween.tween_callback(old_player.stop)
	else:
		next_player.volume_db = target_db

	_active_player = next_player


func _on_track_finished(player: AudioStreamPlayer) -> void:
	# Only advance if the player that finished is the active one.
	# During crossfade, the old player's stop() fires finished — ignore it.
	if player == _active_player:
		next_track()


func get_active_ambience() -> Array:
	return _active_ambience.duplicate()


func _start_ambience(ambience_id: String) -> void:
	if ambience_id in _ambience_players:
		return  # Already playing

	var amb_path := _find_ambience_path(ambience_id)
	if amb_path.is_empty():
		push_warning("AudioManager: ambience file not found for '%s'" % ambience_id)
		return

	var stream: AudioStream = _load_audio_stream(amb_path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = linear_to_db(maxf(master_volume * ambience_volume, 0.0001))
	player.autoplay = true
	add_child(player)
	_ambience_players[ambience_id] = player

	if ambience_id not in _active_ambience:
		_active_ambience.append(ambience_id)
	_sync_music_state()


func _find_ambience_path(ambience_id: String) -> String:
	# Check tracks catalog first
	var ambience_list: Array = GameManager.tracks_catalog.get("ambience", [])
	for amb_data in ambience_list:
		if amb_data is Dictionary and amb_data.get("id", "") == ambience_id:
			return amb_data.get("path", "")

	# Fallback: try standard paths
	var ogg_path := "res://assets/audio/ambience/%s.ogg" % ambience_id
	if FileAccess.file_exists(ogg_path):
		return ogg_path
	var wav_path := "res://assets/audio/ambience/%s.wav" % ambience_id
	if FileAccess.file_exists(wav_path):
		return wav_path
	return ""


func _stop_ambience(ambience_id: String) -> void:
	if ambience_id not in _ambience_players:
		return
	var player: AudioStreamPlayer = _ambience_players[ambience_id]
	_ambience_players.erase(ambience_id)
	_active_ambience.erase(ambience_id)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_sync_music_state()


func _on_ambience_toggled(ambience_id: String, is_active: bool) -> void:
	if is_active:
		_start_ambience(ambience_id)
	else:
		_stop_ambience(ambience_id)


func _on_volume_changed(bus_name: String, volume: float) -> void:
	match bus_name:
		"master":
			master_volume = volume
		"music":
			music_volume = volume
		"ambience":
			ambience_volume = volume
		_:
			push_warning("AudioManager: bus_name sconosciuto '%s'" % bus_name)
			return
	SignalBus.settings_updated.emit("%s_volume" % bus_name, volume)
	_apply_music_volume()
	_apply_ambience_volume()


func _get_music_volume_db() -> float:
	var linear := master_volume * music_volume
	if linear <= 0.0001:
		return VOLUME_DB_FLOOR
	return linear_to_db(linear)


func _apply_music_volume() -> void:
	var db := _get_music_volume_db()
	if _active_player != null and _active_player.playing:
		_active_player.volume_db = db


func _apply_ambience_volume() -> void:
	var db := linear_to_db(maxf(master_volume * ambience_volume, 0.0001))
	for player: AudioStreamPlayer in _ambience_players.values():
		player.volume_db = db


func _sync_music_state() -> void:
	SignalBus.music_state_updated.emit({
		"current_track_index": current_track_index,
		"playlist_mode": playlist_mode,
		"active_ambience": _active_ambience.duplicate(),
	})


func _exit_tree() -> void:
	if SignalBus.volume_changed.is_connected(_on_volume_changed):
		SignalBus.volume_changed.disconnect(_on_volume_changed)
	if SignalBus.ambience_toggled.is_connected(_on_ambience_toggled):
		SignalBus.ambience_toggled.disconnect(_on_ambience_toggled)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		_crossfade_tween = null
	for amb_id in _ambience_players.keys():
		var player: AudioStreamPlayer = _ambience_players[amb_id]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_ambience_players.clear()
	_active_ambience.clear()


