## RoomsDecoRepo — CRUD per tabelle rooms + placed_decorations (B-033 split).
class_name RoomsDecoRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_room(db: SQLite, character_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM rooms WHERE character_id = ?;", [character_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_room(db: SQLite, character_id: int, data: Dictionary) -> bool:
	var existing := get_room(db, character_id)
	var decorations_json: String = JSON.stringify(data.get("decorations", []))
	if not existing.is_empty():
		return (
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
	return (
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


static func delete_room(db: SQLite, character_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM rooms WHERE character_id = ?;", [character_id])


static func get_placed_decorations(db: SQLite, room_id: int) -> Array:
	return DBHelpers.select(db, "SELECT * FROM placed_decorations WHERE room_id = ?;", [room_id])


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


static func remove_placed_decoration(db: SQLite, placement_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM placed_decorations WHERE placement_id = ?;", [placement_id])


static func clear_room_decorations(db: SQLite, room_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM placed_decorations WHERE room_id = ?;", [room_id])
