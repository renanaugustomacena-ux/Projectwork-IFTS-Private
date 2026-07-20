## RoomsDecoRepo — CRUD for the rooms + placed_decorations tables (B-033 split).
##
## Decoration storage contract (V-058 / audit 4.1.17-L16):
## - The normalized placed_decorations rows are the single source of truth
##   for loading decorations.
## - rooms.decorations (JSON blob column) is a write-through mirror kept only
##   for save-file compatibility; it is never preferred when rows exist.
## - Write order on save (upsert_room):
##   1) upsert the rooms row, including the JSON blob mirror;
##   2) resolve room_id of that row;
##   3) rebuild placed_decorations from the same decorations array
##      (DELETE every row for room_id, then INSERT one row per entry).
##   LocalDatabase.apply_save wraps upsert_room in a transaction, so a failed
##   rebuild rolls back the blob write and the two storages cannot diverge on
##   a failed save. Facade callers outside a transaction lose that atomicity.
## - Load (get_room): when placed_decorations rows exist, the returned
##   decorations field is rebuilt from those rows; if the blob disagrees a
##   WARN with both counts is logged (divergence detection). An empty rows
##   table falls back to the blob (legacy saves predating normalized rows).
class_name RoomsDecoRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_room(db: SQLite, character_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM rooms WHERE character_id = ?;", [character_id])
	if rows.is_empty():
		return {}
	var room: Dictionary = rows[0].duplicate()
	return _reconcile_loaded_room(db, room)


static func upsert_room(db: SQLite, character_id: int, data: Dictionary) -> bool:
	var decorations := _decorations_from_payload(data, character_id)
	var decorations_json: String = JSON.stringify(decorations)
	var id_rows := DBHelpers.select(db, "SELECT room_id FROM rooms WHERE character_id = ?;", [character_id])
	var write_ok: bool
	if id_rows.is_empty():
		write_ok = (
			DBHelpers
			. execute_bound(
				db,
				"INSERT INTO rooms (character_id, room_type, theme, decorations)" + " VALUES (?, ?, ?, ?);",
				[
					character_id,
					data.get("room_type", "cozy_studio"),
					data.get("theme", "modern"),
					decorations_json,
				],
			)
		)
	else:
		write_ok = (
			DBHelpers
			. execute_bound(
				db,
				(
					"UPDATE rooms SET room_type = ?, theme = ?,"
					+ " decorations = ?, updated_at = datetime('now')"
					+ " WHERE character_id = ?;"
				),
				[
					data.get("room_type", "cozy_studio"),
					data.get("theme", "modern"),
					decorations_json,
					character_id,
				],
			)
		)
	if not write_ok:
		return false
	var room_id: int = _resolve_room_id(db, character_id, id_rows)
	if room_id < 0:
		AppLogger.error("LocalDatabase", "upsert_room_id_unresolved", {"character_id": character_id})
		return false
	return _rebuild_placed_decorations(db, room_id, decorations)


static func delete_room(db: SQLite, character_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM rooms WHERE character_id = ?;", [character_id])


static func get_placed_decorations(db: SQLite, room_id: int) -> Array:
	return (
		DBHelpers
		. select(
			db,
			"SELECT * FROM placed_decorations WHERE room_id = ? ORDER BY placement_id;",
			[room_id],
		)
	)


static func add_placed_decoration(db: SQLite, room_id: int, data: Dictionary) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO placed_decorations"
				+ " (room_id, decoration_catalog_id, pos_x, pos_y,"
				+ " rotation_deg, flip_h, item_scale, z_order, placement_zone)"
				+ " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
			),
			[
				room_id,
				data.get("decoration_catalog_id", ""),
				data.get("pos_x", 0.0),
				data.get("pos_y", 0.0),
				data.get("rotation_deg", 0.0),
				1 if data.get("flip_h", false) else 0,
				data.get("item_scale", 1.0),
				data.get("z_order", 0),
				data.get("placement_zone", "floor"),
			],
		)
	)


## Returns true only when a row was actually deleted (V-059 / 4.1.17-L85):
## statement success with zero affected rows means the placement did not
## exist, which is reported as false with a WARN instead of a silent true.
static func remove_placed_decoration(db: SQLite, placement_id: int) -> bool:
	var deleted := DBHelpers.execute_bound(db, "DELETE FROM placed_decorations WHERE placement_id = ?;", [placement_id])
	if not deleted:
		return false
	var rows := DBHelpers.select(db, "SELECT changes() AS n;", [])
	var affected: int = 0 if rows.is_empty() else int(rows[0].get("n", 0))
	if affected == 0:
		AppLogger.warn("LocalDatabase", "remove_placed_decoration_no_row", {"placement_id": placement_id})
		return false
	return true


static func clear_room_decorations(db: SQLite, room_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM placed_decorations WHERE room_id = ?;", [room_id])


static func _decorations_from_payload(data: Dictionary, character_id: int) -> Array:
	var raw: Variant = data.get("decorations", [])
	if raw is Array:
		return raw
	AppLogger.warn("LocalDatabase", "upsert_room_bad_decorations_type", {"character_id": character_id})
	return []


static func _resolve_room_id(db: SQLite, character_id: int, id_rows: Array) -> int:
	if not id_rows.is_empty():
		return int(id_rows[0].get("room_id", -1))
	var rows := DBHelpers.select(db, "SELECT room_id FROM rooms WHERE character_id = ?;", [character_id])
	if rows.is_empty():
		return -1
	return int(rows[0].get("room_id", -1))


static func _rebuild_placed_decorations(db: SQLite, room_id: int, decorations: Array) -> bool:
	if not clear_room_decorations(db, room_id):
		return false
	for entry in decorations:
		if not entry is Dictionary:
			AppLogger.warn("LocalDatabase", "placed_decoration_entry_not_dict", {"room_id": room_id})
			continue
		if not add_placed_decoration(db, room_id, _save_entry_to_row(entry)):
			return false
	return true


## Maps a save-file decoration entry (item_id / position / rotation / flip_h /
## item_scale / z_order / placement_type) to placed_decorations column keys.
## Row-shaped keys are accepted as fallback so row dicts pass through intact.
static func _save_entry_to_row(entry: Dictionary) -> Dictionary:
	var pos_x: float = float(entry.get("pos_x", 0.0))
	var pos_y: float = float(entry.get("pos_y", 0.0))
	var pos: Variant = entry.get("position")
	if pos is Array and (pos as Array).size() >= 2:
		pos_x = float(pos[0])
		pos_y = float(pos[1])
	return {
		"decoration_catalog_id": str(entry.get("item_id", entry.get("decoration_catalog_id", ""))),
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": float(entry.get("rotation", entry.get("rotation_deg", 0.0))),
		"flip_h": bool(entry.get("flip_h", false)),
		"item_scale": float(entry.get("item_scale", 1.0)),
		"z_order": int(entry.get("z_order", 0)),
		"placement_zone": str(entry.get("placement_type", entry.get("placement_zone", "floor"))),
	}


## Maps a placed_decorations row back to the save-file entry shape consumed by
## SaveManager / room_base (bool flip_h, position array, placement_type key).
static func _row_to_save_entry(row: Dictionary) -> Dictionary:
	return {
		"item_id": str(row.get("decoration_catalog_id", "")),
		"position": [float(row.get("pos_x", 0.0)), float(row.get("pos_y", 0.0))],
		"rotation": float(row.get("rotation_deg", 0.0)),
		"flip_h": int(row.get("flip_h", 0)) != 0,
		"item_scale": float(row.get("item_scale", 1.0)),
		"z_order": int(row.get("z_order", 0)),
		"placement_type": str(row.get("placement_zone", "floor")),
	}


static func _reconcile_loaded_room(db: SQLite, room: Dictionary) -> Dictionary:
	var room_id: int = int(room.get("room_id", -1))
	if room_id < 0:
		return room
	var placed := get_placed_decorations(db, room_id)
	if placed.is_empty():
		return room
	var authoritative: Array = []
	for row in placed:
		authoritative.append(_row_to_save_entry(row))
	var blob_entries := _parse_blob_entries(str(room.get("decorations", "[]")))
	if _storages_diverge(authoritative, blob_entries):
		(
			AppLogger
			. warn(
				"LocalDatabase",
				"room_decorations_divergence",
				{
					"room_id": room_id,
					"placed_rows": authoritative.size(),
					"blob_entries": blob_entries.size(),
				},
			)
		)
	room["decorations"] = JSON.stringify(authoritative)
	return room


static func _parse_blob_entries(blob_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(blob_text)
	if parsed is Array:
		return parsed
	return []


## Divergence check compares both storages through the same canonical mapping
## so key-shape differences (missing z_order / placement_type defaults in old
## blob entries) do not raise false positives.
static func _storages_diverge(rows_entries: Array, blob_entries: Array) -> bool:
	if rows_entries.size() != blob_entries.size():
		return true
	for i in range(rows_entries.size()):
		if not blob_entries[i] is Dictionary:
			return true
		var canonical_row := _save_entry_to_row(rows_entries[i])
		var canonical_blob := _save_entry_to_row(blob_entries[i])
		if not _entries_match(canonical_row, canonical_blob):
			return true
	return false


static func _entries_match(a: Dictionary, b: Dictionary) -> bool:
	if a.get("decoration_catalog_id") != b.get("decoration_catalog_id"):
		return false
	if a.get("flip_h") != b.get("flip_h"):
		return false
	if int(a.get("z_order", 0)) != int(b.get("z_order", 0)):
		return false
	if a.get("placement_zone") != b.get("placement_zone"):
		return false
	for key in ["pos_x", "pos_y", "rotation_deg", "item_scale"]:
		if not is_equal_approx(float(a.get(key, 0.0)), float(b.get(key, 0.0))):
			return false
	return true
