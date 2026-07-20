## SettingsRepo — CRUD per tabelle settings + save_metadata + music_state.
##
## Raggruppate in un unico repo perche` tutte 1:1 per account, tutte
## "UPDATE if exists else INSERT" con pattern identico.
class_name SettingsRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")

# ---- settings ----


static func get_settings(db: SQLite, account_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM settings WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_settings(db: SQLite, account_id: int, data: Dictionary) -> bool:
	var existing := get_settings(db, account_id)
	if not existing.is_empty():
		return (
			DBHelpers
			. execute_bound(
				db,
				(
					"UPDATE settings SET master_volume = ?, music_volume = ?,"
					+ " sfx_volume = ?, display_mode = ?, language = ?,"
					+ " ui_scale = ?, updated_at = datetime('now')"
					+ " WHERE account_id = ?;"
				),
				[
					data.get("master_volume", 1.0),
					data.get("music_volume", 0.8),
					data.get("sfx_volume", 0.8),
					data.get("display_mode", "windowed"),
					data.get("language", "it"),
					data.get("ui_scale", 1.0),
					account_id,
				],
			)
		)
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO settings"
				+ " (account_id, master_volume, music_volume, sfx_volume,"
				+ " display_mode, language, ui_scale)"
				+ " VALUES (?, ?, ?, ?, ?, ?, ?);"
			),
			[
				account_id,
				data.get("master_volume", 1.0),
				data.get("music_volume", 0.8),
				data.get("sfx_volume", 0.8),
				data.get("display_mode", "windowed"),
				data.get("language", "it"),
				data.get("ui_scale", 1.0),
			],
		)
	)


# ---- save_metadata ----


static func get_save_metadata(db: SQLite, account_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM save_metadata WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_save_metadata(db: SQLite, account_id: int, data: Dictionary) -> bool:
	var existing := get_save_metadata(db, account_id)
	if not existing.is_empty():
		return (
			DBHelpers
			. execute_bound(
				db,
				(
					"UPDATE save_metadata SET save_version = ?, save_slot = ?,"
					+ " play_time_sec = ?, last_saved_at = datetime('now')"
					+ " WHERE account_id = ?;"
				),
				[
					data.get("save_version", "1.0"),
					data.get("save_slot", 1),
					data.get("play_time_sec", 0),
					account_id,
				],
			)
		)
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO save_metadata"
				+ " (account_id, save_version, save_slot, play_time_sec)"
				+ " VALUES (?, ?, ?, ?);"
			),
			[
				account_id,
				data.get("save_version", "1.0"),
				data.get("save_slot", 1),
				data.get("play_time_sec", 0),
			],
		)
	)


# ---- music_state ----


static func get_music_state(db: SQLite, account_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM music_state WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_music_state(db: SQLite, account_id: int, data: Dictionary) -> bool:
	var existing := get_music_state(db, account_id)
	if not existing.is_empty():
		return (
			DBHelpers
			. execute_bound(
				db,
				(
					"UPDATE music_state SET current_track_id = ?,"
					+ " track_position_sec = ?, playlist_mode = ?,"
					+ " ambience_enabled = ?, active_ambiences = ?,"
					+ " updated_at = datetime('now')"
					+ " WHERE account_id = ?;"
				),
				[
					data.get("current_track_id", ""),
					data.get("track_position_sec", 0.0),
					data.get("playlist_mode", Constants.DEFAULT_PLAYLIST_MODE),
					_coerce_flag(data.get("ambience_enabled", true), "ambience_enabled"),
					JSON.stringify(data.get("active_ambiences", [])),
					account_id,
				],
			)
		)
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO music_state"
				+ " (account_id, current_track_id, track_position_sec,"
				+ " playlist_mode, ambience_enabled, active_ambiences)"
				+ " VALUES (?, ?, ?, ?, ?, ?);"
			),
			[
				account_id,
				data.get("current_track_id", ""),
				data.get("track_position_sec", 0.0),
				data.get("playlist_mode", Constants.DEFAULT_PLAYLIST_MODE),
				_coerce_flag(data.get("ambience_enabled", true), "ambience_enabled"),
				JSON.stringify(data.get("active_ambiences", [])),
			],
		)
	)


## Coerces an untrusted boolean-ish flag to the 0/1 INTEGER the schema
## expects (audit 4.1.18-L143). Save data arrives from JSON, so numbers may
## parse as floats; anything that is not bool/int/float logs a WARN and
## falls back to enabled (1).
static func _coerce_flag(value: Variant, field: String) -> int:
	if value is bool:
		return 1 if value else 0
	if value is int:
		return clampi(value, 0, 1)
	if value is float:
		return clampi(int(value), 0, 1)
	(
		AppLogger
		. warn(
			"SettingsRepo",
			"Unexpected %s type, defaulting to 1" % field,
			{"type": type_string(typeof(value))},
		)
	)
	return 1
