## SaveManager — Handles JSON-based persistence of all game state.
## Auto-saves periodically and on significant state changes.
extends Node

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data.backup.json"
const SAVE_VERSION := "5.0.0"
const AUTO_SAVE_INTERVAL := 60.0

# Room decoration state
var decorations: Array = []

# Music state
var music_state: Dictionary = {
	"current_track_index": 0,
	"playlist_mode": "shuffle",
	"active_ambience": [],
}

# Settings
var settings: Dictionary = {
	"language": "en",
	"display_mode": "windowed",
	"mini_mode_position": "bottom_right",
	"master_volume": 0.8,
	"music_volume": 0.6,
	"ambience_volume": 0.4,
}

# Character data (maps to CHARACTER table)
var character_data: Dictionary = {
	"nome": "",
	"genere": true,
	"colore_occhi": 0,
	"colore_capelli": 0,
	"colore_pelle": 0,
	"livello_stress": 0,
}

# Inventory data (maps to INVENTARIO table)
var inventory_data: Dictionary = {
	"coins": 0,
	"capacita": 50,
	"items": [],
}

var _auto_save_timer: Timer
var _save_dirty: bool = false
var _is_saving: bool = false


func _ready() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)
	SignalBus.save_requested.connect(_mark_dirty)
	SignalBus.settings_updated.connect(_on_settings_updated)
	SignalBus.music_state_updated.connect(_on_music_state_updated)


func _mark_dirty() -> void:
	_save_dirty = true


func _on_settings_updated(key: String, value: Variant) -> void:
	settings[key] = value
	_mark_dirty()


func _on_music_state_updated(state: Dictionary) -> void:
	music_state = state
	_mark_dirty()


func _on_auto_save() -> void:
	if _save_dirty and not _is_saving:
		_save_dirty = false
		save_game()


func save_game() -> void:
	if _is_saving:
		AppLogger.warn("SaveManager", "Salvataggio gia' in corso, skip")
		return

	_is_saving = true

	var save_data := {
		"version": SAVE_VERSION,
		"last_saved": Time.get_datetime_string_from_system(),
		"account":
		{
			"auth_uid": AuthManager.current_auth_uid,
			"account_id": AuthManager.current_account_id,
		},
		"settings": settings,
		"room":
		{
			"current_room_id": GameManager.current_room_id,
			"current_theme": GameManager.current_theme,
			"decorations": decorations,
		},
		"character":
		{
			"character_id": GameManager.current_character_id,
			"outfit_id": GameManager.current_outfit_id,
			"data": character_data,
		},
		"music": music_state,
		"inventory": inventory_data,
	}

	# Backup existing save before overwrite
	if FileAccess.file_exists(SAVE_PATH):
		var src := ProjectSettings.globalize_path(SAVE_PATH)
		var dst := ProjectSettings.globalize_path(BACKUP_PATH)
		var err := DirAccess.copy_absolute(src, dst)
		if err != OK:
			AppLogger.error("SaveManager", "Backup fallito", {"errore": err, "src": src, "dst": dst})

	# Primary: save to JSON file (always works offline)
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write save file (error: %s)" % FileAccess.get_open_error())
		_is_saving = false
		return
	file.store_string(json_string)
	file.close()

	# Secondary: persist character and inventory to SQLite
	_save_to_sqlite()

	_is_saving = false
	SignalBus.save_completed.emit()


func _save_to_sqlite() -> void:
	SignalBus.save_to_database_requested.emit({
		"character": character_data,
		"inventory": inventory_data,
	})


func load_game() -> void:
	var data = _load_from_file(SAVE_PATH)

	if data == null and FileAccess.file_exists(BACKUP_PATH):
		AppLogger.warn("SaveManager", "Primary save corrupt or missing, trying backup")
		data = _load_from_file(BACKUP_PATH)

	if data == null:
		push_warning("SaveManager: no valid save file found, using defaults")
		SignalBus.load_completed.emit()
		return

	data = _migrate_save_data(data)
	_apply_save_data(data)
	SignalBus.load_completed.emit()


func _load_from_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot read file '%s' (error: %s)" % [path, FileAccess.get_open_error()])
		return null

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error(
			(
				"SaveManager: JSON parse error in '%s' at line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()]
			)
		)
		return null

	var data = json.data
	if not data is Dictionary:
		push_error("SaveManager: file '%s' root is not a Dictionary" % path)
		return null

	return data


func _apply_save_data(data: Dictionary) -> void:
	# Settings
	if "settings" in data and data["settings"] is Dictionary:
		for key in data["settings"]:
			if key in settings:
				settings[key] = data["settings"][key]

	# Room state
	if "room" in data and data["room"] is Dictionary:
		var room_data: Dictionary = data["room"]
		if "current_room_id" in room_data:
			GameManager.current_room_id = room_data["current_room_id"]
		if "current_theme" in room_data:
			GameManager.current_theme = room_data["current_theme"]
		if "decorations" in room_data and room_data["decorations"] is Array:
			decorations = room_data["decorations"]

	# Character state
	if "character" in data and data["character"] is Dictionary:
		var char_data: Dictionary = data["character"]
		if "character_id" in char_data:
			GameManager.current_character_id = char_data["character_id"]
		if "outfit_id" in char_data:
			GameManager.current_outfit_id = char_data["outfit_id"]
		if "data" in char_data and char_data["data"] is Dictionary:
			for key in char_data["data"]:
				if key in character_data:
					character_data[key] = char_data["data"][key]

	# Music state
	if "music" in data and data["music"] is Dictionary:
		for key in data["music"]:
			if key in music_state:
				music_state[key] = data["music"][key]

	# Inventory data
	if "inventory" in data and data["inventory"] is Dictionary:
		for key in data["inventory"]:
			if key in inventory_data:
				inventory_data[key] = data["inventory"][key]


func _migrate_save_data(data: Dictionary) -> Dictionary:
	var version: String = data.get("version", "1.0.0")
	if version == SAVE_VERSION:
		return data

	# Forward-compatibility: save from a newer app version
	if _compare_versions(version, SAVE_VERSION) > 0:
		AppLogger.warn("SaveManager", "Save from newer version", {"save": version, "app": SAVE_VERSION})
		return data

	(
		AppLogger
		. info(
			"SaveManager",
			"Migrating save data",
			{
				"from": version,
				"to": SAVE_VERSION,
			}
		)
	)

	# v1.0.0 -> v2.0.0 -> v3.0.0 (chain through old migrations)
	if version == "1.0.0":
		data["version"] = "2.0.0"
		version = "2.0.0"

	if version == "2.0.0":
		data["version"] = "3.0.0"
		version = "3.0.0"

	# v3.0.0 -> v4.0.0: Remove obsolete fields, add new schema
	if version == "3.0.0":
		# Preserve coins from old currency if available
		var old_coins: int = 0
		if "currency" in data and data["currency"] is Dictionary:
			old_coins = data["currency"].get("coins", 0)

		# Remove obsolete sections
		data.erase("tools")
		data.erase("therapeutic")
		data.erase("xp")
		data.erase("streak")
		data.erase("currency")
		data.erase("unlocks")
		data.erase("last_active_timestamp")
		data.erase("updated_at")

		# Validazione inventario esistente prima della migrazione
		if "inventory" in data and data["inventory"] is Dictionary:
			var inv: Dictionary = data["inventory"]
			if not inv.has("coins") or not inv.has("items"):
				AppLogger.warn(
					"SaveManager",
					"Inventario corrotto durante migrazione v3->v4, reset",
					{"inventory_keys": inv.keys()}
				)
				data["inventory"] = {
					"coins": inv.get("coins", old_coins),
					"capacita": inv.get("capacita", 50),
					"items": [],
				}
			elif inv["items"] is not Array:
				data["inventory"]["items"] = []

		# Add new sections
		if "inventory" not in data:
			data["inventory"] = {
				"coins": old_coins,
				"capacita": 50,
				"items": [],
			}

		data["version"] = "4.0.0"
		version = "4.0.0"

	# v4.0.0 -> v5.0.0: Add account section
	if version == "4.0.0":
		data["account"] = {
			"auth_uid": Constants.AUTH_GUEST_UID,
			"account_id": -1,
		}
		data["version"] = "5.0.0"

	return data


func _compare_versions(a: String, b: String) -> int:
	var parts_a := a.split(".")
	var parts_b := b.split(".")
	var max_len := maxi(parts_a.size(), parts_b.size())
	for i in range(max_len):
		var raw_a: String = parts_a[i] if i < parts_a.size() else "0"
		var raw_b: String = parts_b[i] if i < parts_b.size() else "0"
		var num_a: int = int(raw_a) if raw_a.is_valid_int() else 0
		var num_b: int = int(raw_b) if raw_b.is_valid_int() else 0
		if num_a != num_b:
			return 1 if num_a > num_b else -1
	return 0


func reset_character_data() -> void:
	character_data = {
		"nome": "",
		"genere": true,
		"colore_occhi": 0,
		"colore_capelli": 0,
		"colore_pelle": 0,
		"livello_stress": 0,
	}
	decorations = []
	GameManager.current_character_id = "male_old"
	GameManager.current_outfit_id = ""
	GameManager.current_room_id = "cozy_studio"
	GameManager.current_theme = "modern"
	_mark_dirty()


func reset_all() -> void:
	reset_character_data()
	music_state = {
		"current_track_index": 0,
		"playlist_mode": "shuffle",
		"active_ambience": [],
	}
	inventory_data = {
		"coins": 0,
		"capacita": 50,
		"items": [],
	}
	settings = {
		"language": "en",
		"display_mode": "windowed",
		"mini_mode_position": "bottom_right",
		"master_volume": 0.8,
		"music_volume": 0.6,
		"ambience_volume": 0.4,
	}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(BACKUP_PATH)
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
