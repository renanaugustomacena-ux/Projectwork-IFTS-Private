## GameManager — Central orchestrator for game state and lifecycle.
## Manages current room, character, display mode, and coordinates subsystems.
extends Node

# Current game state
var current_room_id: String = "cozy_studio"
var current_theme: String = "modern"
var current_character_id: String = "female_red_shirt"
var current_outfit_id: String = ""
var is_decoration_mode: bool = false

# References to data catalogs (loaded from JSON in data/)
var rooms_catalog: Dictionary = {}
var decorations_catalog: Dictionary = {}
var characters_catalog: Dictionary = {}
var tracks_catalog: Dictionary = {}


func _ready() -> void:
	_load_catalogs()
	_validate_catalogs()
	SignalBus.load_completed.connect(_on_load_completed)
	call_deferred("_deferred_load")


func _deferred_load() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://scenes/menu/main_menu.tscn":
		return
	SaveManager.load_game()


func _load_catalogs() -> void:
	rooms_catalog = _load_json("res://data/rooms.json")
	decorations_catalog = _load_json("res://data/decorations.json")
	characters_catalog = _load_json("res://data/characters.json")
	tracks_catalog = _load_json("res://data/tracks.json")


func _validate_catalogs() -> void:
	var counts := {
		"rooms": rooms_catalog.get("rooms", []).size(),
		"decorations": decorations_catalog.get("decorations", []).size(),
		"characters": characters_catalog.get("characters", []).size(),
		"tracks": tracks_catalog.get("tracks", []).size(),
	}
	AppLogger.info("GameManager", "Catalogs loaded", counts)

	if counts["rooms"] == 0:
		push_warning("GameManager: rooms catalog is empty — no rooms available")
	if counts["decorations"] == 0:
		push_warning("GameManager: decorations catalog is empty — no items available")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("GameManager: catalog file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameManager: failed to open catalog: %s (error: %s)" % [path, FileAccess.get_open_error()])
		return {}
	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error(
			(
				"GameManager: JSON parse error in %s at line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()]
			)
		)
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data
	push_error("GameManager: expected Dictionary from %s, got %s" % [path, typeof(data)])
	return {}


func change_room(room_id: String, theme: String = "") -> void:
	if _find_room(room_id).is_empty():
		push_warning("GameManager: unknown room_id '%s'" % room_id)
		return
	current_room_id = room_id
	if theme != "":
		current_theme = theme
	SignalBus.room_changed.emit(current_room_id, current_theme)
	_request_save()


func get_theme_colors(room_id: String, theme_id: String) -> Dictionary:
	var room := _find_room(room_id)
	for theme_data in room.get("themes", []):
		if theme_data is Dictionary and theme_data.get("id", "") == theme_id:
			return theme_data
	return {}


func _find_room(room_id: String) -> Dictionary:
	for room in rooms_catalog.get("rooms", []):
		if room is Dictionary and room.get("id", "") == room_id:
			return room
	return {}


# TODO: Phase 5 — add character selection UI and outfit system
func change_character(character_id: String, outfit_id: String = "") -> void:
	current_character_id = character_id
	if outfit_id != "":
		current_outfit_id = outfit_id
	SignalBus.character_changed.emit(current_character_id)
	if outfit_id != "":
		SignalBus.outfit_changed.emit(current_outfit_id)
	_request_save()


func toggle_decoration_mode() -> void:
	is_decoration_mode = not is_decoration_mode
	SignalBus.decoration_mode_changed.emit(is_decoration_mode)


func _on_load_completed() -> void:
	SignalBus.room_changed.emit(current_room_id, current_theme)
	SignalBus.character_changed.emit(current_character_id)


func _request_save() -> void:
	SignalBus.save_requested.emit()
