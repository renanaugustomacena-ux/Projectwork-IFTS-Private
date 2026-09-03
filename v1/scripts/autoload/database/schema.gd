## DBSchema — creazione tabelle + migrazioni SQLite (B-033 split out).
##
## Preserva 1:1 gli SQL CREATE TABLE e le migration steps gia` in
## local_database.gd pre-split. Cambi allo schema devono passare da qui.
class_name DBSchema

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func create_all_tables(db: SQLite) -> bool:
	# C.4: every statement return is checked; callers can gate on the result.
	var ok := true
	for stmt in _all_schema_statements():
		ok = DBHelpers.execute(db, stmt) and ok
	return ok


static func _all_schema_statements() -> Array[String]:
	var stmts: Array[String] = [
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
		),
		(
			"CREATE TABLE IF NOT EXISTS inventario ("
			+ "inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "item_id INTEGER NOT NULL,"
			+ "quantita INTEGER DEFAULT 1"
			+ ");"
		),
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
		),
		(
			"CREATE TABLE IF NOT EXISTS rooms ("
			+ "room_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "character_id INTEGER NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,"
			+ "room_type TEXT NOT NULL DEFAULT 'cozy_studio',"
			+ "theme TEXT NOT NULL DEFAULT 'modern',"
			+ "decorations TEXT DEFAULT '[]',"
			+ "updated_at TEXT DEFAULT (datetime('now'))"
			+ ");"
		),
		(
			"CREATE TABLE IF NOT EXISTS sync_queue ("
			+ "queue_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "table_name TEXT NOT NULL,"
			+ "operation TEXT NOT NULL,"
			+ "payload TEXT NOT NULL,"
			+ "created_at TEXT DEFAULT (datetime('now')),"
			+ "retry_count INTEGER DEFAULT 0"
			+ ");"
		),
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
		),
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
		),
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
		),
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
		),
		# T-R-015d badges
		(
			"CREATE TABLE IF NOT EXISTS badges_unlocked ("
			+ "id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "badge_id TEXT NOT NULL,"
			+ "unlocked_at TEXT NOT NULL DEFAULT (datetime('now')),"
			+ "UNIQUE(account_id, badge_id)"
			+ ");"
		),
	]
	# Indici sulle FK senza vincolo UNIQUE (DB-19: settings/save_metadata/
	# music_state/badges hanno gia` l'autoindex UNIQUE su account_id).
	stmts.append("CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id);")
	stmts.append("CREATE INDEX IF NOT EXISTS idx_inventario_account ON inventario(account_id);")
	stmts.append("CREATE INDEX IF NOT EXISTS idx_rooms_character ON rooms(character_id);")
	stmts.append("CREATE INDEX IF NOT EXISTS idx_placed_decorations_room ON placed_decorations(room_id);")
	return stmts


static func migrate_schema(db: SQLite) -> void:
	_migration_1_characters_schema(db)
	_migration_2_accounts_columns(db)
	_migration_3_sync_dlq_and_rate_limit(db)


static func _table_has_column(db: SQLite, table: String, column: String) -> bool:
	# C.4: exact column-name check via PRAGMA table_info (replaces the old
	# substring match on raw sqlite_master DDL, which false-positived on any
	# DDL text containing the column name, e.g. foo_character_id).
	var cols := DBHelpers.select(db, "PRAGMA table_info('%s');" % table, [])
	for col in cols:
		if col.get("name", "") == column:
			return true
	return false


static func _count_rows(db: SQLite, table: String) -> int:
	var rows := DBHelpers.select(db, "SELECT COUNT(*) AS cnt FROM %s;" % table, [])
	if rows.is_empty():
		return -1
	return int(rows[0].get("cnt", -1))


static func _migration_1_characters_schema(db: SQLite) -> void:
	# Migration 1: characters table without character_id column
	var rows := DBHelpers.select(db, "SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", [])
	if rows.is_empty():
		return
	if _table_has_column(db, "characters", "character_id"):
		return
	AppLogger.info("LocalDatabase", "Migrating characters to new schema")
	# C.4: whole migration in a checked transaction; backup row counts are
	# verified against the source BEFORE any destructive DROP executes.
	if not DBHelpers.execute(db, "BEGIN TRANSACTION;"):
		AppLogger.error("LocalDatabase", "migration_1_begin_failed")
		return
	if not _migration_1_body(db):
		DBHelpers.execute(db, "ROLLBACK;")
		AppLogger.error("LocalDatabase", "migration_1_rolled_back")
		return
	if not DBHelpers.execute(db, "COMMIT;"):
		DBHelpers.execute(db, "ROLLBACK;")
		AppLogger.error("LocalDatabase", "migration_1_commit_failed_rolled_back")


static func _migration_1_body(db: SQLite) -> bool:
	# Safety net (fix B-015 + C.4): verified backup PRIMA di DROP distruttivo.
	# Le tabelle *_bak sopravvivono al crash e permettono recovery manuale.
	if not _migration_1_backup_verified(db):
		return false
	if not DBHelpers.execute(db, "DROP TABLE IF EXISTS characters;"):
		return false
	if not DBHelpers.execute(db, "DROP TABLE IF EXISTS inventario;"):
		return false
	return create_all_tables(db)


static func _migration_1_backup_verified(db: SQLite) -> bool:
	var src_chars := _count_rows(db, "characters")
	var src_inv := _count_rows(db, "inventario")
	if src_chars < 0 or src_inv < 0:
		AppLogger.error("LocalDatabase", "migration_1_source_count_failed")
		return false
	var ok := DBHelpers.execute(db, "DROP TABLE IF EXISTS characters_bak;")
	ok = DBHelpers.execute(db, "DROP TABLE IF EXISTS inventario_bak;") and ok
	ok = DBHelpers.execute(db, "CREATE TABLE characters_bak AS SELECT * FROM characters;") and ok
	ok = DBHelpers.execute(db, "CREATE TABLE inventario_bak AS SELECT * FROM inventario;") and ok
	if not ok:
		return false
	var bak_chars := _count_rows(db, "characters_bak")
	var bak_inv := _count_rows(db, "inventario_bak")
	if bak_chars != src_chars or bak_inv != src_inv:
		(
			AppLogger
			. error(
				"LocalDatabase",
				"migration_1_backup_count_mismatch",
				{
					"src_characters": src_chars,
					"bak_characters": bak_chars,
					"src_inventario": src_inv,
					"bak_inventario": bak_inv,
				},
			)
		)
		return false
	(
		AppLogger
		. info(
			"LocalDatabase",
			"migration_1_backup_created",
			{"characters_backed_up": bak_chars, "inventario_backed_up": bak_inv},
		)
	)
	return true


static func _migration_2_accounts_columns(db: SQLite) -> void:
	# Migration 2: add columns to accounts if missing (exact-name check, C.4)
	var acc_rows := DBHelpers.select(db, "SELECT sql FROM sqlite_master WHERE type='table' AND name='accounts';", [])
	if acc_rows.is_empty():
		return
	var stmts: Array[String] = []
	if not _table_has_column(db, "accounts", "display_name"):
		stmts.append("ALTER TABLE accounts ADD COLUMN display_name TEXT DEFAULT '';")
	if not _table_has_column(db, "accounts", "updated_at"):
		# SQLite vieta DEFAULT non-costanti in ALTER TABLE ADD COLUMN.
		# Aggiungiamo la colonna con default vuoto e poi popoliamo le righe esistenti.
		stmts.append("ALTER TABLE accounts ADD COLUMN updated_at TEXT DEFAULT '';")
		stmts.append("UPDATE accounts SET updated_at = datetime('now') WHERE updated_at = '';")
	if not _table_has_column(db, "accounts", "password_hash"):
		stmts.append("ALTER TABLE accounts ADD COLUMN password_hash TEXT DEFAULT '';")
	if not _table_has_column(db, "accounts", "deleted_at"):
		stmts.append("ALTER TABLE accounts ADD COLUMN deleted_at TEXT DEFAULT NULL;")
	if not _table_has_column(db, "accounts", "coins"):
		stmts.append("ALTER TABLE accounts ADD COLUMN coins INTEGER DEFAULT 0;")
	if not _table_has_column(db, "accounts", "inventario_capacita"):
		stmts.append("ALTER TABLE accounts ADD COLUMN inventario_capacita INTEGER DEFAULT 50;")
	if stmts.is_empty():
		return
	_run_statements_in_transaction(db, "migration_2", stmts)


static func _migration_3_sync_dlq_and_rate_limit(db: SQLite) -> void:
	# Migration 3 (Phase D): dead-letter table for corrupt/exhausted sync
	# payloads (audit 4.1.1-L422 — deleted-not-preserved queue items) and
	# persisted per-account rate-limit state (audit 4.4.2 — in-memory-only
	# lockout trivially reset by process restart).
	var stmts: Array[String] = []
	stmts.append(
		(
			"CREATE TABLE IF NOT EXISTS sync_dead_letter ("
			+ "dlq_id INTEGER PRIMARY KEY AUTOINCREMENT, "
			+ "original_queue_id INTEGER, "
			+ "table_name TEXT NOT NULL, "
			+ "operation TEXT NOT NULL, "
			+ "payload TEXT, "
			+ "reason TEXT NOT NULL, "
			+ "created_at TEXT DEFAULT (datetime('now')));"
		)
	)
	if not _table_has_column(db, "accounts", "failed_attempts"):
		stmts.append("ALTER TABLE accounts ADD COLUMN failed_attempts INTEGER DEFAULT 0;")
	if not _table_has_column(db, "accounts", "lockout_until_unix"):
		stmts.append("ALTER TABLE accounts ADD COLUMN lockout_until_unix INTEGER DEFAULT 0;")
	_run_statements_in_transaction(db, "migration_3", stmts)


static func _run_statements_in_transaction(db: SQLite, context: String, stmts: Array[String]) -> void:
	# C.4: per-statement checks inside a checked BEGIN/COMMIT envelope.
	if not DBHelpers.execute(db, "BEGIN TRANSACTION;"):
		AppLogger.error("LocalDatabase", context + "_begin_failed")
		return
	for stmt in stmts:
		if not DBHelpers.execute(db, stmt):
			DBHelpers.execute(db, "ROLLBACK;")
			AppLogger.error("LocalDatabase", context + "_rolled_back", {"stmt": stmt.left(80)})
			return
	if not DBHelpers.execute(db, "COMMIT;"):
		DBHelpers.execute(db, "ROLLBACK;")
		AppLogger.error("LocalDatabase", context + "_commit_failed_rolled_back")
