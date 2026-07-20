## GameManager — Central orchestrator for game state and lifecycle.
## Manages current room, character, display mode, and coordinates subsystems.
extends Node

# Current game state
var current_room_id: String = "cozy_studio"
var current_theme: String = "modern"
var current_character_id: String = "male_old"
var current_outfit_id: String = ""
var is_decoration_mode: bool = false

# References to data catalogs (loaded from JSON in data/)
var rooms_catalog: Dictionary = {}
var decorations_catalog: Dictionary = {}
var characters_catalog: Dictionary = {}
var tracks_catalog: Dictionary = {}
var mess_catalog: Dictionary = {}
var badges_catalog: Dictionary = {}  # T-R-015d

# Character selected in character_select but not yet applied (load would overwrite).
var _pending_character: String = ""
var _pending_outfit: String = ""

# Distinct failure reason set by _load_json when it returns null (V-019).
var _last_catalog_error: String = ""


func _ready() -> void:
	_load_catalogs()
	_validate_catalogs()
	_apply_saved_locale()
	SignalBus.load_completed.connect(_on_load_completed)
	call_deferred("_deferred_load")


## F.1: la lingua salvata va applicata prima che la UI si costruisca,
## altrimenti il gioco parte sempre nel locale di fallback e la scelta
## dell'utente sembra ignorata fino al primo cambio manuale.
## Catena: impostazione salvata -> lingua di sistema se supportata -> "it".
func _apply_saved_locale() -> void:
	var saved: String = str(SaveManager.get_setting("language", ""))
	if saved.is_empty() or not Constants.LANGUAGES.has(saved):
		var system_lang := OS.get_locale_language()
		saved = system_lang if Constants.LANGUAGES.has(system_lang) else "it"
	TranslationServer.set_locale(saved)
	AppLogger.info("GameManager", "locale_applied", {"locale": saved})


func _deferred_load() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://scenes/menu/main_menu.tscn":
		return
	# If a character was chosen in character_select, remember it before load
	# overwrites current_character_id with the old save value.
	if current_character_id != "male_old":
		_pending_character = current_character_id
		_pending_outfit = current_outfit_id
	SaveManager.load_game()


func _load_catalogs() -> void:
	rooms_catalog = _load_catalog_or_empty("res://data/rooms.json")
	decorations_catalog = _load_catalog_or_empty("res://data/decorations.json")
	characters_catalog = _load_catalog_or_empty("res://data/characters.json")
	tracks_catalog = _load_catalog_or_empty("res://data/tracks.json")
	mess_catalog = _load_catalog_or_empty("res://data/mess_catalog.json")
	badges_catalog = _load_catalog_or_empty("res://data/badges.json")


## Load one catalog; on failure log ERROR, emit SignalBus.catalog_load_failed
## and fall back to {} so boot continues (V-019 / 4.2-gamemanager-catalog).
## main.gd's _wire_error_toasts (Phase C) subscribes to catalog_load_failed and
## surfaces it as a toast once the gameplay scene is up; during autoload boot,
## before any listener exists, the AppLogger ERROR is the surviving record.
func _load_catalog_or_empty(path: String) -> Dictionary:
	var data: Variant = _load_json(path)
	if data is Dictionary:
		return data
	AppLogger.error("GameManager", "catalog_load_failed", {"path": path, "reason": _last_catalog_error})
	SignalBus.catalog_load_failed.emit(path, _last_catalog_error)
	return {}


func _validate_catalogs() -> void:
	var counts := {
		"rooms": rooms_catalog.get("rooms", []).size(),
		"decorations": decorations_catalog.get("decorations", []).size(),
		"characters": characters_catalog.get("characters", []).size(),
		"tracks": tracks_catalog.get("tracks", []).size(),
		"mess": mess_catalog.get("mess", []).size(),
		"badges": badges_catalog.get("badges", []).size(),
	}
	AppLogger.info("GameManager", "Catalogs loaded", counts)

	# Warn on every empty catalog, not just rooms/decorations (V-019).
	for key in counts:
		if counts[key] == 0:
			push_warning("GameManager: %s catalog is empty" % key)


## Returns the parsed root Dictionary, or null on any failure ({} is returned
## only for a genuinely empty JSON object). When null is returned,
## _last_catalog_error holds a distinct machine-readable reason.
func _load_json(path: String) -> Variant:
	_last_catalog_error = ""
	if not FileAccess.file_exists(path):
		_last_catalog_error = "file_not_found"
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_last_catalog_error = "open_failed: %s" % error_string(FileAccess.get_open_error())
		return null
	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		_last_catalog_error = ("parse_error: line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	var data: Variant = json.data
	if data is Dictionary:
		return data
	_last_catalog_error = "wrong_root_type: %s" % type_string(typeof(data))
	return null


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


# La selezione personaggio e` implementata (menu/character_select.gd, guidata
# dal catalogo data/characters.json). Il sistema outfit resta fuori ambito per
# v1.1: il parametro e` accettato e propagato ma nessun catalogo lo popola.
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
	# If user just selected a character, override what the save loaded.
	if _pending_character != "":
		current_character_id = _pending_character
		current_outfit_id = _pending_outfit
		_pending_character = ""
		_pending_outfit = ""
	# Il save appena caricato puo` portare una lingua diversa da quella
	# applicata al boot (profilo diverso): riallinea e notifica chi ricostruisce.
	var saved_lang: String = str(SaveManager.get_setting("language", ""))
	if not saved_lang.is_empty() and Constants.LANGUAGES.has(saved_lang):
		if TranslationServer.get_locale() != saved_lang:
			TranslationServer.set_locale(saved_lang)
			SignalBus.language_changed.emit(saved_lang)
	SignalBus.room_changed.emit(current_room_id, current_theme)
	SignalBus.character_changed.emit(current_character_id)


func _request_save() -> void:
	SignalBus.save_requested.emit()


## Restituisce l'entry del mess catalog associata all'id, o un Dictionary vuoto.
func get_mess_entry(mess_id: String) -> Dictionary:
	for entry in mess_catalog.get("mess", []):
		if entry is Dictionary and entry.get("id", "") == mess_id:
			return entry
	return {}


## Peso di stress per un mess (default 0.10 se id sconosciuto).
func get_mess_stress_weight(mess_id: String) -> float:
	var entry := get_mess_entry(mess_id)
	if entry.is_empty():
		return 0.10
	return float(entry.get("stress_weight", 0.10))


func _exit_tree() -> void:
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
