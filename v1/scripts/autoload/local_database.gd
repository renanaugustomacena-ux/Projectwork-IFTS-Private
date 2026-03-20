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
		AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		close()


func is_open() -> bool:
	return _is_open


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
		AppLogger.error("LocalDatabase", "Failed to open database", {"path": DB_PATH})
		_db = null
		return
	_is_open = true
	_execute("PRAGMA journal_mode=WAL;")
	_execute("PRAGMA foreign_keys=ON;")


func _create_tables() -> void:
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS accounts ("
			+ "account_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "auth_uid TEXT UNIQUE,"
			+ "data_di_iscrizione TEXT NOT NULL DEFAULT (date('now')),"
			+ "data_di_nascita TEXT NOT NULL DEFAULT '',"
			+ "mail TEXT NOT NULL DEFAULT ''"
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
			+ "account_id INTEGER REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "item_id INTEGER,"
			+ "capacita INTEGER DEFAULT 50,"
			+ "coins INTEGER DEFAULT 0"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS characters ("
			+ "account_id INTEGER PRIMARY KEY REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "nome TEXT,"
			+ "genere INTEGER DEFAULT 1,"
			+ "colore_occhi INTEGER DEFAULT 0,"
			+ "colore_capelli INTEGER DEFAULT 0,"
			+ "colore_pelle INTEGER DEFAULT 0,"
			+ "livello_stress INTEGER DEFAULT 0,"
			+ "inventario INTEGER REFERENCES inventario(inventario_id)"
			+ ");"
		)
	)


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
		return _execute_bound(
			(
				"UPDATE characters SET nome = ?, genere = ?, colore_occhi = ?,"
				+ " colore_capelli = ?, colore_pelle = ?, livello_stress = ? WHERE account_id = ?;"
			),
			[
				data.get("nome", ""),
				1 if data.get("genere", true) else 0,
				data.get("colore_occhi", 0),
				data.get("colore_capelli", 0),
				data.get("colore_pelle", 0),
				data.get("livello_stress", 0),
				account_id,
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


func add_inventory_item(account_id: int, item_id: int, coins: int = 0, capacita: int = 50) -> bool:
	return _execute_bound(
		"INSERT INTO inventario (account_id, item_id, coins, capacita) VALUES (?, ?, ?, ?);",
		[account_id, item_id, coins, capacita]
	)


func update_inventory_coins(inventario_id: int, coins: int) -> bool:
	return _execute_bound("UPDATE inventario SET coins = ? WHERE inventario_id = ?;", [coins, inventario_id])


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
