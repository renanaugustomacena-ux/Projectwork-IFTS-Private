## InventoryRepo — CRUD per tabelle inventario + coins in accounts (B-033 split).
class_name InventoryRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_inventory(db: SQLite, account_id: int) -> Array:
	return DBHelpers.select(db, "SELECT * FROM inventario WHERE account_id = ?;", [account_id])


static func add_inventory_item(db: SQLite, account_id: int, item_id: int, quantita: int = 1) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
			[account_id, item_id, quantita],
		)
	)


static func remove_inventory_item(db: SQLite, account_id: int, item_id: int) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"DELETE FROM inventario WHERE account_id = ? AND item_id = ?;",
			[account_id, item_id],
		)
	)


static func update_coins(db: SQLite, account_id: int, coins: int) -> bool:
	return DBHelpers.execute_bound(db, "UPDATE accounts SET coins = ? WHERE account_id = ?;", [coins, account_id])


static func get_coins(db: SQLite, account_id: int) -> int:
	var rows := DBHelpers.select(db, "SELECT coins FROM accounts WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return 0
	return rows[0].get("coins", 0)


static func save_inventory(db: SQLite, account_id: int, inv_data: Dictionary) -> bool:
	var coins: int = inv_data.get("coins", 0)
	var capacita: int = inv_data.get("capacita", 50)
	var items: Array = inv_data.get("items", [])
	# C.5: the SAVEPOINT wraps the WHOLE mirror write (coins UPDATE included)
	# so the function is atomic both inside and outside the caller's outer
	# transaction (savepoints nest safely). A mid-loop failure can no longer
	# leave coins committed with the item rows half-rewritten in autocommit.
	if not DBHelpers.execute(db, "SAVEPOINT inventory_save;"):
		return false
	var ok := (
		DBHelpers
		. execute_bound(
			db,
			"UPDATE accounts SET coins = ?, inventario_capacita = ? WHERE account_id = ?;",
			[coins, capacita, account_id],
		)
	)
	if not ok or not _replace_items(db, account_id, items):
		DBHelpers.execute(db, "ROLLBACK TO inventory_save;")
		DBHelpers.execute(db, "RELEASE inventory_save;")
		return false
	return DBHelpers.execute(db, "RELEASE inventory_save;")


static func _replace_items(db: SQLite, account_id: int, items: Array) -> bool:
	if not DBHelpers.execute_bound(db, "DELETE FROM inventario WHERE account_id = ?;", [account_id]):
		return false
	for item in items:
		if item is Dictionary and item.has("item_id"):
			if not (
				DBHelpers
				. execute_bound(
					db,
					"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
					[account_id, item.get("item_id", 0), item.get("quantita", 1)],
				)
			):
				return false
	return true
