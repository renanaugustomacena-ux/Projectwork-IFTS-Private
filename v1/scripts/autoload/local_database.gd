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
	# B-016 dual-write completo: settings, music_state, room+decorations
	if success and data.has("settings") and data["settings"] is Dictionary:
		if not upsert_settings(account_id, data["settings"]):
			success = false
	if success and data.has("music_state") and data["music_state"] is Dictionary:
		if not upsert_music_state(account_id, data["music_state"]):
			success = false
	if success and data.has("room") and data["room"] is Dictionary:
		# upsert_room richiede character_id (rooms table ha FK su characters)
		var char_row := get_character(account_id)
		if not char_row.is_empty():
			var character_id: int = char_row.get("character_id", -1)
			if character_id >= 0:
				if not upsert_room(character_id, data["room"]):
					success = false
	if success:
		_execute("COMMIT;")
	else:
		_execute("ROLLBACK;")
		AppLogger.error(
			"LocalDatabase", "Save rolled back",
			{
				"account_id": account_id,
				"has_settings": data.has("settings"),
				"has_music_state": data.has("music_state"),
				"has_room": data.has("room"),
			}
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
	# Busy timeout 5s: evita blocco main thread Godot se altro processo
	# (es. crash precedente con lock residuo) detiene il DB. (fix B-026)
	_execute("PRAGMA busy_timeout=5000;")
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

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS settings ("
			+ "settings_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "master_volume REAL NOT NULL DEFAULT 1.0,"
			+ "music_volume REAL NOT NULL DEFAULT 0.8,"
			+ "sfx_volume REAL NOT NULL DEFAULT 0.8,"
			+ "display_mode TEXT NOT NULL DEFAULT 'windowed',"
			+ "language TEXT NOT NULL DEFAULT 'it',"
			+ "ui_scale REAL NOT NULL DEFAULT 1.0,"
			+ "updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS save_metadata ("
			+ "save_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "save_version TEXT NOT NULL DEFAULT '1.0',"
			+ "save_slot INTEGER NOT NULL DEFAULT 1,"
			+ "play_time_sec INTEGER NOT NULL DEFAULT 0,"
			+ "last_saved_at TEXT NOT NULL DEFAULT (datetime('now')),"
			+ "created_at TEXT NOT NULL DEFAULT (datetime('now'))"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS music_state ("
			+ "music_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "current_track_id TEXT DEFAULT NULL,"
			+ "track_position_sec REAL NOT NULL DEFAULT 0.0,"
			+ "playlist_mode TEXT NOT NULL DEFAULT 'sequential',"
			+ "ambience_enabled INTEGER NOT NULL DEFAULT 1,"
			+ "active_ambiences TEXT NOT NULL DEFAULT '[]',"
			+ "updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
			+ ");"
		)
	)

	_execute(
		(
			"CREATE TABLE IF NOT EXISTS placed_decorations ("
			+ "placement_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "room_id INTEGER NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,"
			+ "decoration_catalog_id TEXT NOT NULL,"
			+ "pos_x REAL NOT NULL DEFAULT 0.0,"
			+ "pos_y REAL NOT NULL DEFAULT 0.0,"
			+ "rotation_deg REAL NOT NULL DEFAULT 0.0,"
			+ "flip_h INTEGER NOT NULL DEFAULT 0,"
			+ "item_scale REAL NOT NULL DEFAULT 1.0,"
			+ "z_order INTEGER NOT NULL DEFAULT 0,"
			+ "placement_zone TEXT NOT NULL DEFAULT 'floor',"
			+ "placed_at TEXT NOT NULL DEFAULT (datetime('now'))"
			+ ");"
		)
	)

	# T-R-015d badges
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS badges_unlocked ("
			+ "id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "badge_id TEXT NOT NULL,"
			+ "unlocked_at TEXT NOT NULL DEFAULT (datetime('now')),"
			+ "UNIQUE(account_id, badge_id)"
			+ ");"
		)
	)

	# Indexes on foreign key columns for query performance
	_execute("CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_inventario_account ON inventario(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_rooms_character ON rooms(character_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_settings_account ON settings(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_save_metadata_account ON save_metadata(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_music_state_account ON music_state(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_placed_decorations_room ON placed_decorations(room_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_badges_account ON badges_unlocked(account_id);")


func _migrate_schema() -> void:
	# Migration 1: characters table without character_id column
	var rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", []
	)
	if not rows.is_empty():
		var schema: String = rows[0].get("sql", "")
		if "character_id" not in schema:
			AppLogger.info("LocalDatabase", "Migrating characters to new schema")
			# Safety net (fix B-015): backup dei dati PRIMA di DROP distruttivo.
			# Salva snapshot characters + inventario in tabelle *_bak prima di
			# droppare. Se migration fallisce o utente vuole rollback, recover
			# e possibile. Tabelle bak sopravvivono al crash.
			_execute("DROP TABLE IF EXISTS characters_bak;")
			_execute("DROP TABLE IF EXISTS inventario_bak;")
			_execute("CREATE TABLE characters_bak AS SELECT * FROM characters;")
			_execute("CREATE TABLE inventario_bak AS SELECT * FROM inventario;")
			var bak_rows := _select(
				"SELECT COUNT(*) as cnt FROM characters_bak;", []
			)
			var bak_cnt: int = bak_rows[0].get("cnt", 0) if not bak_rows.is_empty() else 0
			AppLogger.info(
				"LocalDatabase",
				"migration_1_backup_created",
				{"characters_backed_up": bak_cnt}
			)
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
			# SQLite vieta DEFAULT non-costanti in ALTER TABLE ADD COLUMN.
			# Aggiungiamo la colonna con default vuoto e poi popoliamo le righe esistenti.
			_execute("ALTER TABLE accounts ADD COLUMN updated_at TEXT DEFAULT '';")
			_execute("UPDATE accounts SET updated_at = datetime('now') WHERE updated_at = '';")
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
		if "coins" not in acc_schema:
			_execute("ALTER TABLE accounts ADD COLUMN coins INTEGER DEFAULT 0;")
		if "inventario_capacita" not in acc_schema:
			_execute(
				"ALTER TABLE accounts ADD COLUMN inventario_capacita INTEGER DEFAULT 50;"
			)

	# Migration 3: add extra columns to inventario if missing
	var inv_rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='inventario';", []
	)
	if not inv_rows.is_empty():
		var inv_schema: String = inv_rows[0].get("sql", "")
		if "item_type" not in inv_schema:
			_execute("ALTER TABLE inventario ADD COLUMN item_type TEXT DEFAULT '';")
		if "is_unlocked" not in inv_schema:
			_execute("ALTER TABLE inventario ADD COLUMN is_unlocked INTEGER DEFAULT 1;")
		if "acquired_at" not in inv_schema:
			_execute("ALTER TABLE inventario ADD COLUMN acquired_at TEXT DEFAULT '';")
			_execute("UPDATE inventario SET acquired_at = datetime('now') WHERE acquired_at = '';")

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


# ---- CRUD: Settings ----


func get_settings(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM settings WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_settings(account_id: int, data: Dictionary) -> bool:
	var existing := get_settings(account_id)
	if not existing.is_empty():
		return _execute_bound(
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
			]
		)
	return _execute_bound(
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
		]
	)


# ---- CRUD: Save Metadata ----


func get_save_metadata(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM save_metadata WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_save_metadata(account_id: int, data: Dictionary) -> bool:
	var existing := get_save_metadata(account_id)
	if not existing.is_empty():
		return _execute_bound(
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
			]
		)
	return _execute_bound(
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
		]
	)


# ---- CRUD: Music State ----


func get_music_state(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM music_state WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


func upsert_music_state(account_id: int, data: Dictionary) -> bool:
	var existing := get_music_state(account_id)
	if not existing.is_empty():
		return _execute_bound(
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
				data.get("playlist_mode", "sequential"),
				1 if data.get("ambience_enabled", true) else 0,
				JSON.stringify(data.get("active_ambiences", [])),
				account_id,
			]
		)
	return _execute_bound(
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
			data.get("playlist_mode", "sequential"),
			1 if data.get("ambience_enabled", true) else 0,
			JSON.stringify(data.get("active_ambiences", [])),
		]
	)


# ---- CRUD: Placed Decorations ----


func get_placed_decorations(room_id: int) -> Array:
	return _select("SELECT * FROM placed_decorations WHERE room_id = ?;", [room_id])


func add_placed_decoration(room_id: int, data: Dictionary) -> bool:
	return _execute_bound(
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
		]
	)


func remove_placed_decoration(placement_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM placed_decorations WHERE placement_id = ?;",
		[placement_id]
	)


func clear_room_decorations(room_id: int) -> bool:
	return _execute_bound(
		"DELETE FROM placed_decorations WHERE room_id = ?;",
		[room_id]
	)


# ---- CRUD: Badges unlocked (T-R-015d) ----


func get_unlocked_badges(account_id: int) -> Array:
	return _select(
		"SELECT badge_id, unlocked_at FROM badges_unlocked WHERE account_id = ?;",
		[account_id]
	)


func is_badge_unlocked(account_id: int, badge_id: String) -> bool:
	var rows := _select(
		"SELECT 1 FROM badges_unlocked WHERE account_id = ? AND badge_id = ?;",
		[account_id, badge_id]
	)
	return not rows.is_empty()


func unlock_badge(account_id: int, badge_id: String) -> bool:
	# INSERT OR IGNORE evita duplicati grazie a UNIQUE(account_id, badge_id)
	return _execute_bound(
		(
			"INSERT OR IGNORE INTO badges_unlocked"
			+ " (account_id, badge_id) VALUES (?, ?);"
		),
		[account_id, badge_id]
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
			AppLogger.error("LocalDatabase", "select_failed", {"sql": sql.left(80)})
			return []
	else:
		if not _db.query_with_bindings(sql, bindings):
			AppLogger.error(
				"LocalDatabase",
				"select_bound_failed",
				{"sql": sql.left(80), "bindings": bindings}
			)
			return []
	return _db.query_result
