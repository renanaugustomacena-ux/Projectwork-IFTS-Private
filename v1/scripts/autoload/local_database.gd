## LocalDatabase — SQLite local database for offline-first persistence.
## Uses godot-sqlite GDExtension to store game data in user://cozy_room.db.
## Schema mirrors Supabase tables (7 tables).
extends Node

const DB_PATH := "user://cozy_room"

var _db: SQLite = null
var _is_open: bool = false


func _ready() -> void:
	_open_database()
	if _is_open:
		_create_tables()
		_migrate_schema()
		AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})
	SignalBus.save_to_database_requested.connect(_on_save_requested)


func _exit_tree() -> void:
	if SignalBus.save_to_database_requested.is_connected(_on_save_requested):
		SignalBus.save_to_database_requested.disconnect(_on_save_requested)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		close()


func is_open() -> bool:
	return _is_open


func _on_save_requested(data: Dictionary) -> void:
	if not _is_open:
		return
	var account := get_account_by_auth_uid("local")
	var account_id: int
	if account.is_empty():
		account_id = upsert_account("local", "offline@local", "")
	else:
		account_id = account.get("account_id", -1)
	if account_id < 0:
		return
	if data.has("character") and data["character"] is Dictionary:
		upsert_character(account_id, data["character"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		_save_inventory(account_id, data["inventory"])


func close() -> void:
	if _db != null and _is_open:
		_db.close_db()
		_is_open = false
		AppLogger.info("LocalDatabase", "Database closed")


func _open_database() -> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = SQLite.QUIET
	if not _db.open_db():
		AppLogger.error("LocalDatabase", "Failed to open database", {
			"path": DB_PATH,
			"os": OS.get_name(),
			"user_data_dir": OS.get_user_data_dir(),
		})
		var dir := DirAccess.open("user://")
		if dir == null:
			AppLogger.error("LocalDatabase", "Cannot access user:// directory")
		_db = null
		return
	_is_open = true
	_execute("PRAGMA journal_mode=WAL;")
	_execute("PRAGMA foreign_keys=ON;")
	var fk_check := _select("PRAGMA foreign_keys;", [])
	if fk_check.is_empty() or fk_check[0].get("foreign_keys", 0) != 1:
		AppLogger.warn("LocalDatabase", "Foreign keys not enabled")


func _create_tables() -> void:
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS accounts ("
			+ "account_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "auth_uid TEXT UNIQUE,"
			+ "data_di_iscrizione TEXT NOT NULL DEFAULT (date('now')),"
			+ "data_di_nascita TEXT NOT NULL DEFAULT '',"
			+ "mail TEXT NOT NULL DEFAULT '',"
			+ "coins INTEGER DEFAULT 0,"
			+ "inventario_capacita INTEGER DEFAULT 50"
			+ ");"
		)
	)

	_execute("CREATE TABLE IF NOT EXISTS colore (" + "colore_id INTEGER PRIMARY KEY AUTOINCREMENT" + ");")

	_execute("CREATE TABLE IF NOT EXISTS categoria (" + "categoria_id INTEGER PRIMARY KEY AUTOINCREMENT" + ");")

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS shop ("
			+ "shop_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "prezzo_item INTEGER"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS items ("
			+ "item_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "shop_id INTEGER REFERENCES shop(shop_id),"
			+ "categoria_id INTEGER REFERENCES categoria(categoria_id),"
			+ "prezzo INTEGER,"
			+ "disponibilita INTEGER DEFAULT 1,"
			+ "colore_id INTEGER REFERENCES colore(colore_id)"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS inventario ("
			+ "inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "item_id INTEGER NOT NULL,"
			+ "quantita INTEGER DEFAULT 1"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS characters ("
			+ "character_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "nome TEXT DEFAULT '',"
			+ "genere INTEGER DEFAULT 1,"
			+ "colore_occhi INTEGER DEFAULT 0,"
			+ "colore_capelli INTEGER DEFAULT 0,"
			+ "colore_pelle INTEGER DEFAULT 0,"
			+ "livello_stress INTEGER DEFAULT 0"
			+ ");"
		)
	)


func _migrate_schema() -> void:
	var rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", []
	)
	if rows.is_empty():
		return
	var schema: String = rows[0].get("sql", "")
	if "character_id" in schema:
		return
	AppLogger.info("LocalDatabase", "Migrating database to new schema")
	_execute("DROP TABLE IF EXISTS characters;")
	_execute("DROP TABLE IF EXISTS inventario;")
	_create_tables()
	AppLogger.info("LocalDatabase", "Schema migration completed")


# ---- CRUD: Accounts ----


func get_account(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM accounts WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


func get_account_by_auth_uid(auth_uid: String) -> Dictionary:
	var rows := _select("SELECT * FROM accounts WHERE auth_uid = ?;", [auth_uid])
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_account(auth_uid: String, mail: String, data_di_nascita: String = "") -> int:
	var existing := get_account_by_auth_uid(auth_uid)
	if not existing.is_empty():
		_execute_bound(
			"UPDATE accounts SET mail = ?, data_di_nascita = ? WHERE auth_uid = ?;", [mail, data_di_nascita, auth_uid]
		)
		return existing.get("account_id", -1)

	_execute_bound(
		"INSERT INTO accounts (auth_uid, mail, data_di_nascita) VALUES (?, ?, ?);", [auth_uid, mail, data_di_nascita]
	)
	var rows := _select("SELECT last_insert_rowid() as id;", [])
	if rows.is_empty():
		return -1
	return rows[0].get("id", -1)


# ---- CRUD: Characters ----


func get_character(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM characters WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_character(account_id: int, data: Dictionary) -> bool:
	var existing := get_character(account_id)
	if not existing.is_empty():
		var char_id: int = existing.get("character_id", -1)
		if char_id < 0:
			return false
		return _execute_bound(
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
			]
		)

	return _execute_bound(
		(
			"INSERT INTO characters (account_id, nome, genere, colore_occhi,"
			+ " colore_capelli, colore_pelle, livello_stress) VALUES (?, ?, ?, ?, ?, ?, ?);"
		),
		[
			account_id,
			data.get("nome", ""),
			1 if data.get("genere", true) else 0,
			data.get("colore_occhi", 0),
			data.get("colore_capelli", 0),
			data.get("colore_pelle", 0),
			data.get("livello_stress", 0),
		]
	)


# ---- CRUD: Inventario ----


func get_inventory(account_id: int) -> Array:
	return _select("SELECT * FROM inventario WHERE account_id = ?;", [account_id])


func add_inventory_item(account_id: int, item_id: int, quantita: int = 1) -> bool:
	return _execute_bound(
		"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
		[account_id, item_id, quantita]
	)


func remove_inventory_item(account_id: int, item_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM inventario WHERE account_id = ? AND item_id = ?;",
		[account_id, item_id]
	)


func update_coins(account_id: int, coins: int) -> bool:
	return _execute_bound(
		"UPDATE accounts SET coins = ? WHERE account_id = ?;", [coins, account_id]
	)


func get_coins(account_id: int) -> int:
	var rows := _select("SELECT coins FROM accounts WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return 0
	return rows[0].get("coins", 0)


func _save_inventory(account_id: int, inv_data: Dictionary) -> void:
	var coins: int = inv_data.get("coins", 0)
	var capacita: int = inv_data.get("capacita", 50)
	_execute_bound(
		"UPDATE accounts SET coins = ?, inventario_capacita = ? WHERE account_id = ?;",
		[coins, capacita, account_id]
	)
	var items: Array = inv_data.get("items", [])
	_execute_bound("DELETE FROM inventario WHERE account_id = ?;", [account_id])
	for item in items:
		if item is Dictionary and item.has("item_id"):
			_execute_bound(
				"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
				[account_id, item.get("item_id", 0), item.get("quantita", 1)]
			)


# ---- CRUD: Items ----


func get_all_items() -> Array:
	return _select("SELECT * FROM items WHERE disponibilita = 1;", [])


func get_item(item_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM items WHERE item_id = ?;", [item_id])
	if rows.is_empty():
		return {}
	return rows[0]


# ---- CRUD: Shop ----


func get_all_shops() -> Array:
	return _select("SELECT * FROM shop;", [])


# ---- CRUD: Colore ----


func get_all_colors() -> Array:
	return _select("SELECT * FROM colore;", [])


# ---- CRUD: Categoria ----


func get_all_categories() -> Array:
	return _select("SELECT * FROM categoria;", [])


# ---- Internal helpers ----


func _execute(sql: String) -> bool:
	if _db == null or not _is_open:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return false
	if not _db.query(sql):
		AppLogger.error("LocalDatabase", "Query failed", {"sql": sql.left(80)})
		return false
	return true


func _execute_bound(sql: String, bindings: Array) -> bool:
	if _db == null or not _is_open:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return false
	if not _db.query_with_bindings(sql, bindings):
		AppLogger.error("LocalDatabase", "Bound query failed", {"sql": sql.left(80)})
		return false
	return true


func _select(sql: String, bindings: Array) -> Array:
	if _db == null or not _is_open:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return []
	if bindings.is_empty():
		if not _db.query(sql):
			return []
	else:
		if not _db.query_with_bindings(sql, bindings):
			return []
	return _db.query_result
