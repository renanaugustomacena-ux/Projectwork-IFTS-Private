# gdlint: disable=max-file-lines
## SaveManager — Handles JSON-based persistence of all game state.
## Auto-saves periodically and on significant state changes.
##
## TODO B-033 post-demo: split helpers (_migrate, _apply_save_data,
## HMAC utils) in save_manager/*.gd moduli per rientrare sotto 500 righe.
extends Node

const SAVE_PATH := "user://save_data.json"
const TEMP_PATH := "user://save_data.tmp.json"
const BACKUP_PATH := "user://save_data.backup.json"
const SECRET_PATH := "user://integrity.key"
const SAVE_VERSION := "5.0.0"
const AUTO_SAVE_INTERVAL := 60.0

# Character data (maps to CHARACTER table) — public per accesso esterno
var character_data: Dictionary = {
	"nome": "",
	"genere": true,
	"colore_occhi": 0,
	"colore_capelli": 0,
	"colore_pelle": 0,
	"livello_stress": 0,
}

# Inventory data (maps to INVENTARIO table) — public per accesso esterno
var inventory_data: Dictionary = {
	"coins": 0,
	"capacita": 50,
	"items": [],
}

# Room decoration state
var _decorations: Array = []

# Music state
var _music_state: Dictionary = {
	"current_track_index": 0,
	"playlist_mode": "shuffle",
	"active_ambience": [],
}

# Settings
var _settings: Dictionary = {
	"language": "en",
	"display_mode": "windowed",
	"mini_mode_position": "bottom_right",
	"master_volume": 0.8,
	"music_volume": 0.6,
	"ambience_volume": 0.4,
	"pet_variant": "simple",
}

var _auto_save_timer: Timer
var _save_dirty: bool = false
var _is_saving: bool = false


func get_decorations() -> Array:
	return _decorations


func add_decoration(data: Dictionary) -> void:
	_decorations.append(data)
	_mark_dirty()


func remove_decoration(data: Dictionary) -> bool:
	var idx := _decorations.find(data)
	if idx >= 0:
		_decorations.remove_at(idx)
		_mark_dirty()
		return true
	return false


func get_setting(key: String, default: Variant = null) -> Variant:
	return _settings.get(key, default)


func get_music_state() -> Dictionary:
	return _music_state


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
	_settings[key] = value
	_mark_dirty()


func _on_music_state_updated(state: Dictionary) -> void:
	_music_state = state
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
		"settings": _settings,
		"room":
		{
			"current_room_id": GameManager.current_room_id,
			"current_theme": GameManager.current_theme,
			"decorations": _decorations,
		},
		"character":
		{
			"character_id": GameManager.current_character_id,
			"outfit_id": GameManager.current_outfit_id,
			"data": character_data,
		},
		"music": _music_state,
		"inventory": inventory_data,
	}

	# Atomic write: write to temp file first, then rename
	var json_string := JSON.stringify(save_data, "\t")
	var hmac := _compute_hmac(json_string)
	var wrapper := {"data": json_string, "hmac": hmac}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write temp file (error: %s)" % FileAccess.get_open_error())
		_is_saving = false
		return
	file.store_string(JSON.stringify(wrapper, "\t"))
	file.close()

	# Backup existing save before overwrite
	if FileAccess.file_exists(SAVE_PATH):
		var src := ProjectSettings.globalize_path(SAVE_PATH)
		var dst := ProjectSettings.globalize_path(BACKUP_PATH)
		var err := DirAccess.copy_absolute(src, dst)
		if err != OK:
			AppLogger.error("SaveManager", "Backup fallito", {"errore": err, "src": src, "dst": dst})

	# Rename temp → primary (atomic operation)
	var rename_err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)
	)
	if rename_err != OK:
		AppLogger.error("SaveManager", "Rename fallito, copia temp → save", {"errore": rename_err})
		DirAccess.copy_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))

	# Secondary: persist character and inventory to SQLite
	_save_to_sqlite()

	_is_saving = false
	SignalBus.save_completed.emit()


func _save_to_sqlite() -> void:
	# B-016: payload completo dual-write JSON+SQLite. Prima solo character +
	# inventory andavano al mirror; settings/music_state/room+deco erano su
	# JSON soltanto causando divergenza silente fra i due storage.
	var room_payload: Dictionary = {
		"room_type": GameManager.current_room_id,
		"theme": GameManager.current_theme,
		"decorations": _decorations,
	}
	(
		SignalBus
		. save_to_database_requested
		. emit(
			{
				"character": character_data,
				"inventory": inventory_data,
				"settings": _settings,
				"music_state": _music_state,
				"room": room_payload,
			}
		)
	)


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
	# Refactor (max-returns): parse + HMAC extraction estratti in helper.
	var wrapper: Variant = _load_wrapper_from_disk(path)
	if not wrapper is Dictionary:
		return null
	var wrapper_dict: Dictionary = wrapper
	# New HMAC-wrapped format
	if wrapper_dict.has("hmac") and wrapper_dict.has("data"):
		return _extract_hmac_inner(wrapper_dict, path)
	# Legacy format (no HMAC wrapper) — accept but will re-save with HMAC
	return wrapper_dict


func _load_wrapper_from_disk(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		AppLogger.error("SaveManager", "Cannot read file", {"path": path})
		return null
	var raw_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		AppLogger.error("SaveManager", "JSON parse error", {"path": path, "line": json.get_error_line()})
		return null
	var wrapper = json.data
	if not wrapper is Dictionary:
		AppLogger.error("SaveManager", "Root is not Dictionary", {"path": path})
		return null
	return wrapper


func _extract_hmac_inner(wrapper: Dictionary, path: String) -> Variant:
	var stored_hmac: String = wrapper.get("hmac", "")
	var json_string: String = wrapper.get("data", "")
	var expected := _compute_hmac(json_string)
	if stored_hmac != expected:
		AppLogger.warn("SaveManager", "HMAC mismatch — save file may be tampered", {"path": path})
		return null
	var inner := JSON.new()
	if inner.parse(json_string) != OK:
		return null
	if inner.data is Dictionary:
		return inner.data
	return null


func _apply_save_data(data: Dictionary) -> void:
	# Settings — validate types match defaults
	if "settings" in data and data["settings"] is Dictionary:
		for key in data["settings"]:
			if key in _settings:
				var loaded = data["settings"][key]
				if typeof(loaded) == typeof(_settings[key]):
					_settings[key] = loaded
				else:
					AppLogger.warn("SaveManager", "Type mismatch in settings", {"key": key})
	# Clamp volume ranges
	_settings["master_volume"] = clampf(float(_settings.get("master_volume", 0.8)), 0.0, 1.0)
	_settings["music_volume"] = clampf(float(_settings.get("music_volume", 0.6)), 0.0, 1.0)
	_settings["ambience_volume"] = clampf(float(_settings.get("ambience_volume", 0.4)), 0.0, 1.0)

	# Room state
	if "room" in data and data["room"] is Dictionary:
		var room_data: Dictionary = data["room"]
		if "current_room_id" in room_data and room_data["current_room_id"] is String:
			GameManager.current_room_id = room_data["current_room_id"]
		if "current_theme" in room_data and room_data["current_theme"] is String:
			GameManager.current_theme = room_data["current_theme"]
		if "decorations" in room_data and room_data["decorations"] is Array:
			_decorations = room_data["decorations"]

	# Character state
	if "character" in data and data["character"] is Dictionary:
		var char_data: Dictionary = data["character"]
		if "character_id" in char_data and char_data["character_id"] is String:
			GameManager.current_character_id = char_data["character_id"]
		if "outfit_id" in char_data and char_data["outfit_id"] is String:
			GameManager.current_outfit_id = char_data["outfit_id"]
		if "data" in char_data and char_data["data"] is Dictionary:
			for key in char_data["data"]:
				if key in character_data:
					var loaded = char_data["data"][key]
					if typeof(loaded) == typeof(character_data[key]):
						character_data[key] = loaded
	# Clamp stress level
	character_data["livello_stress"] = clampi(int(character_data.get("livello_stress", 0)), 0, 100)

	# Music state
	if "music" in data and data["music"] is Dictionary:
		for key in data["music"]:
			if key in _music_state:
				var loaded = data["music"][key]
				if typeof(loaded) == typeof(_music_state[key]):
					_music_state[key] = loaded

	# Inventory data — validate types and clamp values
	if "inventory" in data and data["inventory"] is Dictionary:
		for key in data["inventory"]:
			if key in inventory_data:
				var loaded = data["inventory"][key]
				if typeof(loaded) == typeof(inventory_data[key]):
					inventory_data[key] = loaded
	inventory_data["coins"] = maxi(int(inventory_data.get("coins", 0)), 0)
	inventory_data["capacita"] = clampi(int(inventory_data.get("capacita", 50)), 1, 999)


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
	_decorations = []
	GameManager.current_character_id = "male_old"
	GameManager.current_outfit_id = ""
	GameManager.current_room_id = "cozy_studio"
	GameManager.current_theme = "modern"
	_mark_dirty()


func reset_all() -> void:
	reset_character_data()
	_music_state = {
		"current_track_index": 0,
		"playlist_mode": "shuffle",
		"active_ambience": [],
	}
	inventory_data = {
		"coins": 0,
		"capacita": 50,
		"items": [],
	}
	_settings = {
		"language": "en",
		"display_mode": "windowed",
		"mini_mode_position": "bottom_right",
		"master_volume": 0.8,
		"music_volume": 0.6,
		"ambience_volume": 0.4,
		"pet_variant": "simple",
	}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))


func _get_integrity_key() -> PackedByteArray:
	if FileAccess.file_exists(SECRET_PATH):
		var f := FileAccess.open(SECRET_PATH, FileAccess.READ)
		if f != null:
			var hex := f.get_as_text().strip_edges()
			f.close()
			if hex.length() == 64:
				return hex.hex_decode()
	# Generate new key on first run
	var crypto := Crypto.new()
	var key := crypto.generate_random_bytes(32)
	var f := FileAccess.open(SECRET_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(key.hex_encode())
		f.close()
	return key


func _compute_hmac(message: String) -> String:
	var key := _get_integrity_key()
	var msg_bytes := message.to_utf8_buffer()
	# HMAC-SHA256: H((key ^ opad) || H((key ^ ipad) || message))
	var block_size := 64
	var padded_key := PackedByteArray()
	padded_key.resize(block_size)
	padded_key.fill(0)
	for i in range(mini(key.size(), block_size)):
		padded_key[i] = key[i]
	var ipad := PackedByteArray()
	ipad.resize(block_size)
	var opad := PackedByteArray()
	opad.resize(block_size)
	for i in range(block_size):
		ipad[i] = padded_key[i] ^ 0x36
		opad[i] = padded_key[i] ^ 0x5c
	var inner_hash := _sha256(ipad + msg_bytes)
	var outer_hash := _sha256(opad + inner_hash)
	return outer_hash.hex_encode()


static func _sha256(input: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input)
	return ctx.finish()


func _exit_tree() -> void:
	if SignalBus.save_requested.is_connected(_mark_dirty):
		SignalBus.save_requested.disconnect(_mark_dirty)
	if SignalBus.settings_updated.is_connected(_on_settings_updated):
		SignalBus.settings_updated.disconnect(_on_settings_updated)
	if SignalBus.music_state_updated.is_connected(_on_music_state_updated):
		SignalBus.music_state_updated.disconnect(_on_music_state_updated)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
