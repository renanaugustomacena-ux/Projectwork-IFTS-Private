## AudioManager — Handles lo-fi music playback, playlists, and ambient sound mixing.
## Supports dual-player crossfade, simultaneous music + multiple ambience streams.
extends Node

const AmbienceControllerScript := preload("res://scripts/systems/ambience_controller.gd")

const VOLUME_DB_FLOOR := -80.0
const MAX_AUDIO_FILE_SIZE := 52_428_800  # 50 MB limit for external audio imports

# ---- Public state (gdlint order: pubvars before prvvars) ----
var tracks: Array = []
var current_track_index: int = 0
var is_playing: bool = false
var playlist_mode: String = Constants.DEFAULT_PLAYLIST_MODE:  # "sequential", "shuffle", "repeat_one"
	set(value):
		if value not in ["sequential", "shuffle", "repeat_one"]:
			push_warning("AudioManager: invalid playlist_mode '%s', using default" % value)
			value = Constants.DEFAULT_PLAYLIST_MODE
		playlist_mode = value
		_sync_music_state()
# Volume levels (0.0 to 1.0, converted to dB for AudioStreamPlayer)
var master_volume: float = 0.8
var music_volume: float = 0.6
var ambience_volume: float = 0.4
# Stato mood per il crossfade dinamico pilotato da StressManager
var current_mood: String = "calm"

# ---- Private state ----
# Mood volume scalar (1.0 full, 0.5 at mood 0); folded into _get_music_volume_db (Phase D).
var _mood_volume_scale: float = 1.0
# Ambience: macchina separata (F.5) — vedi systems/ambience_controller.gd
var _ambience: Node = null  # AmbienceControllerScript instance
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _crossfade_tween: Tween
var _mood_rng := RandomNumberGenerator.new()


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

	_ambience = AmbienceControllerScript.new()
	_ambience.name = "AmbienceController"
	_ambience.setup(func() -> float: return master_volume * ambience_volume)
	add_child(_ambience)

	SignalBus.volume_changed.connect(_on_volume_changed)
	SignalBus.ambience_toggled.connect(_on_ambience_toggled)
	SignalBus.load_completed.connect(_on_load_completed)
	SignalBus.mood_changed.connect(_on_mood_changed)
	# G-054: release streams during teardown so the AudioServer drops its
	# active AudioStreamPlayback before the ObjectDB exit-leak check.
	# tree_exiting is a Node signal (SceneTree has none): connect this
	# autoload's own, which fires just before _exit_tree at quit.
	tree_exiting.connect(_release_streams)

	# B-030: seed deterministico in debug per riproducibilita` bug report
	if OS.is_debug_build():
		_mood_rng.seed = Constants.DEBUG_RNG_SEED
	else:
		_mood_rng.randomize()
	_load_tracks()
	call_deferred("_auto_start_music")


func _load_tracks() -> void:
	# Validate once at load so hot-path play()/_on_mood_changed never see
	# malformed entries: Dictionary shape, unique non-empty id, existing
	# path, non-empty moods array. Malformed entries are skipped with a WARN.
	var raw_tracks: Array = GameManager.tracks_catalog.get("tracks", [])
	var validated: Array = []
	var seen_ids: Dictionary = {}
	for entry in raw_tracks:
		if entry is not Dictionary:
			push_warning("AudioManager: skipping non-Dictionary track entry")
			continue
		var track: Dictionary = entry
		var track_id := String(track.get("id", ""))
		if track_id.is_empty():
			push_warning("AudioManager: skipping track with empty id")
			continue
		if seen_ids.has(track_id):
			push_warning("AudioManager: skipping track with duplicate id '%s'" % track_id)
			continue
		var path := String(track.get("path", ""))
		if path.is_empty():
			push_warning("AudioManager: skipping track '%s' with empty path" % track_id)
			continue
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			push_warning("AudioManager: skipping track '%s', file not found: '%s'" % [track_id, path])
			continue
		var moods: Variant = track.get("moods", [])
		if moods is not Array or (moods as Array).is_empty():
			push_warning("AudioManager: skipping track '%s' with empty moods array" % track_id)
			continue
		seen_ids[track_id] = true
		validated.append(track)
	tracks = validated


func _on_load_completed() -> void:
	var state: Dictionary = SaveManager.get_music_state()
	current_track_index = state.get("current_track_index", 0)
	playlist_mode = state.get("playlist_mode", Constants.DEFAULT_PLAYLIST_MODE)
	var saved_ambience: Array = state.get("active_ambience", [])

	if not tracks.is_empty():
		current_track_index = clampi(current_track_index, 0, tracks.size() - 1)

	master_volume = SaveManager.get_setting("master_volume", 0.8)
	music_volume = SaveManager.get_setting("music_volume", 0.6)
	ambience_volume = SaveManager.get_setting("ambience_volume", 0.4)

	_apply_music_volume()

	if _ambience != null:
		if saved_ambience.is_empty():
			_ambience.refresh_for_mood(current_mood)
		else:
			for amb_id in saved_ambience:
				_ambience.start(String(amb_id))


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
				new_index = _mood_rng.randi_range(0, tracks.size() - 1)
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
				var ctx := {"path": path, "size": file.get_length(), "max": MAX_AUDIO_FILE_SIZE}
				file.close()
				AppLogger.error("AudioManager", "Audio file too large", ctx)
				return null
			var buffer := file.get_buffer(file.get_length())
			file.close()
			var mp3_stream := AudioStreamMP3.new()
			mp3_stream.data = buffer
			return mp3_stream

	# Resource paths (res:// and user:// wav/ogg)
	return load(path) as AudioStream


## Reacts to StressManager mood changes: picks a track for the new mood via
## _pick_mood_track_index and crossfades to it (no-op when none matches).
func _on_mood_changed(mood: String) -> void:
	if mood == current_mood:
		return
	current_mood = mood
	# F.5: l'ambience segue il mood anche a musica ferma — e` un tappeto
	# sonoro indipendente dalla playlist.
	if _ambience != null:
		_ambience.refresh_for_mood(mood)
	# Phase D: never resume music the user explicitly paused/stopped.
	if not is_playing:
		return
	var choice := _pick_mood_track_index(mood)
	if choice < 0:
		return
	var chosen_track: Dictionary = tracks[choice]
	var stream := _load_audio_stream(String(chosen_track.get("path", "")))
	if stream == null:
		return
	current_track_index = choice
	is_playing = true
	_crossfade_to(stream)
	SignalBus.track_changed.emit(current_track_index)
	_sync_music_state()


## Track index to swap to for `mood`, or -1 for no swap: no match, or the
## only match is already playing (no self-crossfade restart — Phase D fix).
func _pick_mood_track_index(mood: String) -> int:
	var current_path: String = ""
	if current_track_index >= 0 and current_track_index < tracks.size():
		var curr: Variant = tracks[current_track_index]
		if curr is Dictionary:
			current_path = String(curr.get("path", ""))
	var candidates: Array = []
	for i in range(tracks.size()):
		var t = tracks[i]
		if not (t is Dictionary):
			continue
		var moods: Array = t.get("moods", [])
		if moods is Array and mood in moods:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	# Prova a escludere la traccia gia` in riproduzione per aumentare varieta`
	var filtered: Array = []
	for idx in candidates:
		var t = tracks[idx]
		if t is Dictionary and String(t.get("path", "")) != current_path:
			filtered.append(idx)
	if filtered.is_empty() and _active_player != null and _active_player.playing:
		return -1  # only match is already audible: keep it running
	if not filtered.is_empty():
		candidates = filtered
	return candidates[_mood_rng.randi_range(0, candidates.size() - 1)]


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


func _on_ambience_toggled(ambience_id: String, is_active: bool) -> void:
	if _ambience == null:
		return
	if is_active:
		_ambience.start(ambience_id)
	else:
		_ambience.stop(ambience_id)
	_sync_music_state()


## API pubblica ambience (delegata al controller, F.5).
func get_active_ambience() -> Array:
	return _ambience.get_active() if _ambience != null else []


func set_ambience_enabled(enabled: bool) -> void:
	if _ambience != null:
		_ambience.set_enabled(enabled, current_mood)
		_sync_music_state()


func is_ambience_enabled() -> bool:
	return _ambience.is_enabled() if _ambience != null else true


func is_ambience_playing() -> bool:
	return _ambience.is_playing() if _ambience != null else false


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
	var linear := master_volume * music_volume * _mood_volume_scale
	if linear <= 0.0001:
		return VOLUME_DB_FLOOR
	return linear_to_db(linear)


func _apply_music_volume() -> void:
	var db := _get_music_volume_db()
	if _active_player != null and _active_player.playing:
		_active_player.volume_db = db


# T-R-015i: reacts to the continuous mood_level slider (0..1).
#  - Scales music volume with gloom (50% at minimum) via _mood_volume_scale
#    in _get_music_volume_db() so every volume path applies it (Phase D).
#  - When a threshold band is crossed, emits the discrete mood_changed so
#    _on_mood_changed reuses the catalog-based track selection + crossfade.
# IMPORTANT: never pre-assign current_mood here — _on_mood_changed owns that
# state, and pre-assigning would trip its dedupe guard and suppress the swap.
func apply_mood_scalar(mood: float) -> void:
	var clamped: float = clampf(mood, 0.0, 1.0)
	# Volume scale: mood 1.0 -> normal volume, mood 0.0 -> 50% volume
	_mood_volume_scale = 0.5 + 0.5 * clamped
	_apply_music_volume()
	var target_mood := "calm"
	if clamped < Constants.MOOD_STORMY_THRESHOLD:
		target_mood = "stormy"
	elif clamped < Constants.MOOD_GLOOMY_THRESHOLD:
		target_mood = "tense"
	if target_mood != current_mood:
		SignalBus.mood_changed.emit(target_mood)


func _apply_ambience_volume() -> void:
	if _ambience != null:
		_ambience.apply_volume()


func _sync_music_state() -> void:
	(
		SignalBus
		. music_state_updated
		. emit(
			{
				"current_track_index": current_track_index,
				"playlist_mode": playlist_mode,
				"active_ambience": get_active_ambience(),
			}
		)
	)


func _notification(what: int) -> void:
	# NOTIFICATION_WM_CLOSE_REQUEST deliberately does NOT release here: a close
	# request is a request, not a quit. SaveManager disables auto_accept_quit
	# and stays alive when the final save fails twice, and releasing on the
	# request left that still-interactive app permanently silent. The real
	# teardown is already covered by tree_exiting/_exit_tree (both wired in
	# _ready), which run before the engine's leak check.
	if what == NOTIFICATION_PREDELETE:
		_release_streams()


func _release_streams() -> void:
	if _music_player_a and is_instance_valid(_music_player_a):
		_music_player_a.stop()
		_music_player_a.stream = null
	if _music_player_b and is_instance_valid(_music_player_b):
		_music_player_b.stop()
		_music_player_b.stream = null
	if _ambience != null and is_instance_valid(_ambience):
		_ambience.release_streams()


func _exit_tree() -> void:
	_release_streams()
	if tree_exiting.is_connected(_release_streams):
		tree_exiting.disconnect(_release_streams)
	if SignalBus.volume_changed.is_connected(_on_volume_changed):
		SignalBus.volume_changed.disconnect(_on_volume_changed)
	if SignalBus.ambience_toggled.is_connected(_on_ambience_toggled):
		SignalBus.ambience_toggled.disconnect(_on_ambience_toggled)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
	if SignalBus.mood_changed.is_connected(_on_mood_changed):
		SignalBus.mood_changed.disconnect(_on_mood_changed)
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		_crossfade_tween = null
	if _ambience != null and is_instance_valid(_ambience):
		_ambience.stop_all()
