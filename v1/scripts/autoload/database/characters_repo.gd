## CharactersRepo — CRUD per tabella characters (B-033 split).
class_name CharactersRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_character(db: SQLite, account_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM characters WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_character(db: SQLite, account_id: int, data: Dictionary) -> bool:
	var existing := get_character(db, account_id)
	if not existing.is_empty():
		var char_id: int = existing.get("character_id", -1)
		if char_id < 0:
			return false
		return (
			DBHelpers
			. execute_bound(
				db,
				(
					"UPDATE characters SET nome = ?, genere = ?, colore_occhi = ?,"
					+ " colore_capelli = ?, colore_pelle = ?, livello_stress = ?"
					+ " WHERE character_id = ?;"
				),
				[
					data.get("nome", ""),
					1 if data.get("genere", true) else 0,
					data.get("colore_occhi", 0),
					data.get("colore_capelli", 0),
					data.get("colore_pelle", 0),
					data.get("livello_stress", 0),
					char_id,
				],
			)
		)

	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO characters (account_id, nome, genere, colore_occhi,"
				+ " colore_capelli, colore_pelle, livello_stress)"
				+ " VALUES (?, ?, ?, ?, ?, ?, ?);"
			),
			[
				account_id,
				data.get("nome", ""),
				1 if data.get("genere", true) else 0,
				data.get("colore_occhi", 0),
				data.get("colore_capelli", 0),
				data.get("colore_pelle", 0),
				data.get("livello_stress", 0),
			],
		)
	)


static func delete_character(db: SQLite, account_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM characters WHERE account_id = ?;", [account_id])
