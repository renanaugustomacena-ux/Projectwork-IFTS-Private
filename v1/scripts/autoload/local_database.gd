## LocalDatabase — SQLite local database for offline-first persistence.
## Uses godot-sqlite GDExtension to store game data in user://cozy_room.db.
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
	var auth_uid: String = Constants.AUTH_GUEST_UID
	if AuthManager.current_auth_uid != "":
		auth_uid = AuthManager.current_auth_uid
	var account := get_account_by_auth_uid(auth_uid)
	var account_id: int
	if account.is_empty():
		account_id = upsert_account(
			auth_uid, Constants.AUTH_GUEST_EMAIL, ""
		)
	else:
		account_id = account.get("account_id", -1)
	if account_id < 0:
		return
	_execute("BEGIN TRANSACTION;")
	var success := true
	if data.has("character") and data["character"] is Dictionary:
		if not upsert_character(account_id, data["character"]):
			success = false
	if success and data.has("inventory") and data["inventory"] is Dictionary:
		if not _save_inventory(account_id, data["inventory"]):
			success = false
	if success:
		_execute("COMMIT;")
	else:
		_execute("ROLLBACK;")
		AppLogger.error(
			"LocalDatabase", "Save rolled back",
			{"account_id": account_id}
		)


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
			+ "display_name TEXT DEFAULT '',"
			+ "password_hash TEXT DEFAULT '',"
			+ "coins INTEGER DEFAULT 0,"
			+ "inventario_capacita INTEGER DEFAULT 50,"
			+ "updated_at TEXT DEFAULT (datetime('now'))"
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

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS rooms ("
			+ "room_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "character_id INTEGER NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,"
			+ "room_type TEXT NOT NULL DEFAULT 'cozy_studio',"
			+ "theme TEXT NOT NULL DEFAULT 'modern',"
			+ "decorations TEXT DEFAULT '[]',"
			+ "updated_at TEXT DEFAULT (datetime('now'))"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS sync_queue ("
			+ "queue_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "table_name TEXT NOT NULL,"
			+ "operation TEXT NOT NULL,"
			+ "payload TEXT NOT NULL,"
			+ "created_at TEXT DEFAULT (datetime('now')),"
			+ "retry_count INTEGER DEFAULT 0"
			+ ");"
		)
	)


func _migrate_schema() -> void:
	# Migration 1: characters table without character_id column
	var rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", []
	)
	if not rows.is_empty():
		var schema: String = rows[0].get("sql", "")
		if "character_id" not in schema:
			AppLogger.info("LocalDatabase", "Migrating characters to new schema")
			_execute("DROP TABLE IF EXISTS characters;")
			_execute("DROP TABLE IF EXISTS inventario;")
			_create_tables()

	# Migration 2: add columns to accounts if missing
	var acc_rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='accounts';", []
	)
	if not acc_rows.is_empty():
		var acc_schema: String = acc_rows[0].get("sql", "")
		if "display_name" not in acc_schema:
			_execute("ALTER TABLE accounts ADD COLUMN display_name TEXT DEFAULT '';")
		if "updated_at" not in acc_schema:
			_execute(
				"ALTER TABLE accounts ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));"
			)
		if "password_hash" not in acc_schema:
			_execute(
				"ALTER TABLE accounts"
				+ " ADD COLUMN password_hash TEXT DEFAULT '';"
			)
		if "deleted_at" not in acc_schema:
			_execute(
				"ALTER TABLE accounts"
				+ " ADD COLUMN deleted_at TEXT DEFAULT NULL;"
			)

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


func get_account_by_username(username: String) -> Dictionary:
	var rows := _select(
		"SELECT * FROM accounts"
		+ " WHERE display_name = ? AND auth_uid != ?"
		+ " AND deleted_at IS NULL;",
		[username, Constants.AUTH_GUEST_UID]
	)
	if rows.is_empty():
		return {}
	return rows[0]


func create_account(
	username: String, password_hash: String
) -> int:
	var auth_uid := "user_%s" % username.to_lower()
	_execute_bound(
		(
			"INSERT INTO accounts (auth_uid, display_name, password_hash)"
			+ " VALUES (?, ?, ?);"
		),
		[auth_uid, username, password_hash]
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


func _save_inventory(account_id: int, inv_data: Dictionary) -> bool:
	var coins: int = inv_data.get("coins", 0)
	var capacita: int = inv_data.get("capacita", 50)
	if not _execute_bound(
		"UPDATE accounts SET coins = ?, inventario_capacita = ? WHERE account_id = ?;",
		[coins, capacita, account_id]
	):
		return false
	var items: Array = inv_data.get("items", [])
	if not _execute_bound("DELETE FROM inventario WHERE account_id = ?;", [account_id]):
		return false
	for item in items:
		if item is Dictionary and item.has("item_id"):
			if not _execute_bound(
				"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
				[account_id, item.get("item_id", 0), item.get("quantita", 1)]
			):
				return false
	return true


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


# ---- Account: delete + auth_uid update ----


func delete_account(account_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM accounts WHERE account_id = ?;",
		[account_id]
	)


func soft_delete_account(account_id: int) -> bool:
	return _execute_bound(
		"UPDATE accounts SET deleted_at = datetime('now'),"
		+ " display_name = '', password_hash = ''"
		+ " WHERE account_id = ?;",
		[account_id]
	)


func delete_character(account_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM characters WHERE account_id = ?;",
		[account_id]
	)


func update_password_hash(account_id: int, new_hash: String) -> bool:
	return _execute_bound(
		"UPDATE accounts SET password_hash = ? WHERE account_id = ?;",
		[new_hash, account_id]
	)


func update_auth_uid(account_id: int, new_auth_uid: String) -> bool:
	return _execute_bound(
		"UPDATE accounts SET auth_uid = ? WHERE account_id = ?;",
		[new_auth_uid, account_id]
	)


# ---- CRUD: Rooms ----


func get_room(character_id: int) -> Dictionary:
	var rows := _select(
		"SELECT * FROM rooms WHERE character_id = ?;",
		[character_id]
	)
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_room(character_id: int, data: Dictionary) -> bool:
	var existing := get_room(character_id)
	var decorations_json: String = JSON.stringify(
		data.get("decorations", [])
	)
	if not existing.is_empty():
		return _execute_bound(
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
			]
		)
	return _execute_bound(
		(
			"INSERT INTO rooms"
			+ " (character_id, room_type, theme, decorations)"
			+ " VALUES (?, ?, ?, ?);"
		),
		[
			character_id,
			data.get("room_type", "cozy_studio"),
			data.get("theme", "modern"),
			decorations_json,
		]
	)


func delete_room(character_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM rooms WHERE character_id = ?;",
		[character_id]
	)


# ---- CRUD: Sync Queue ----


func enqueue_sync(
	table_name: String, operation: String, payload: Dictionary
) -> bool:
	return _execute_bound(
		(
			"INSERT INTO sync_queue"
			+ " (table_name, operation, payload)"
			+ " VALUES (?, ?, ?);"
		),
		[table_name, operation, JSON.stringify(payload)]
	)


func get_pending_sync() -> Array:
	return _select(
		"SELECT * FROM sync_queue ORDER BY created_at ASC;", []
	)


func clear_sync_item(queue_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM sync_queue WHERE queue_id = ?;", [queue_id]
	)


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
