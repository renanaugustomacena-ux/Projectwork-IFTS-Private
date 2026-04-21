## DBSchema — creazione tabelle + migrazioni SQLite (B-033 split out).
##
## Preserva 1:1 gli SQL CREATE TABLE e le migration steps gia` in
## local_database.gd pre-split. Cambi allo schema devono passare da qui.
class_name DBSchema

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func create_all_tables(db: SQLite) -> void:
	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
		(
			"CREATE TABLE IF NOT EXISTS inventario ("
			+ "inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "item_id INTEGER NOT NULL,"
			+ "quantita INTEGER DEFAULT 1"
			+ ");"
		)
	)

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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

	DBHelpers.execute(
		db,
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
	DBHelpers.execute(
		db,
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
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_inventario_account ON inventario(account_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_rooms_character ON rooms(character_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_settings_account ON settings(account_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_save_metadata_account ON save_metadata(account_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_music_state_account ON music_state(account_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_placed_decorations_room ON placed_decorations(room_id);")
	DBHelpers.execute(db, "CREATE INDEX IF NOT EXISTS idx_badges_account ON badges_unlocked(account_id);")


static func migrate_schema(db: SQLite) -> void:
	_migration_1_characters_schema(db)
	_migration_2_accounts_columns(db)


static func _migration_1_characters_schema(db: SQLite) -> void:
	# Migration 1: characters table without character_id column
	var rows := DBHelpers.select(db, "SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", [])
	if rows.is_empty():
		return
	var schema: String = rows[0].get("sql", "")
	if "character_id" in schema:
		return
	AppLogger.info("LocalDatabase", "Migrating characters to new schema")
	# Safety net (fix B-015): backup dei dati PRIMA di DROP distruttivo.
	# Salva snapshot characters + inventario in tabelle *_bak prima di
	# droppare. Se migration fallisce o utente vuole rollback, recover
	# e possibile. Tabelle bak sopravvivono al crash.
	DBHelpers.execute(db, "DROP TABLE IF EXISTS characters_bak;")
	DBHelpers.execute(db, "DROP TABLE IF EXISTS inventario_bak;")
	DBHelpers.execute(db, "CREATE TABLE characters_bak AS SELECT * FROM characters;")
	DBHelpers.execute(db, "CREATE TABLE inventario_bak AS SELECT * FROM inventario;")
	var bak_rows := DBHelpers.select(db, "SELECT COUNT(*) as cnt FROM characters_bak;", [])
	var bak_cnt: int = bak_rows[0].get("cnt", 0) if not bak_rows.is_empty() else 0
	AppLogger.info("LocalDatabase", "migration_1_backup_created", {"characters_backed_up": bak_cnt})
	DBHelpers.execute(db, "DROP TABLE IF EXISTS characters;")
	DBHelpers.execute(db, "DROP TABLE IF EXISTS inventario;")
	create_all_tables(db)


static func _migration_2_accounts_columns(db: SQLite) -> void:
	# Migration 2: add columns to accounts if missing
	var acc_rows := DBHelpers.select(db, "SELECT sql FROM sqlite_master WHERE type='table' AND name='accounts';", [])
	if acc_rows.is_empty():
		return
	var acc_schema: String = acc_rows[0].get("sql", "")
	if "display_name" not in acc_schema:
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN display_name TEXT DEFAULT '';")
	if "updated_at" not in acc_schema:
		# SQLite vieta DEFAULT non-costanti in ALTER TABLE ADD COLUMN.
		# Aggiungiamo la colonna con default vuoto e poi popoliamo le righe esistenti.
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN updated_at TEXT DEFAULT '';")
		DBHelpers.execute(db, "UPDATE accounts SET updated_at = datetime('now') WHERE updated_at = '';")
	if "password_hash" not in acc_schema:
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN password_hash TEXT DEFAULT '';")
	if "deleted_at" not in acc_schema:
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN deleted_at TEXT DEFAULT NULL;")
	if "coins" not in acc_schema:
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN coins INTEGER DEFAULT 0;")
	if "inventario_capacita" not in acc_schema:
		DBHelpers.execute(db, "ALTER TABLE accounts ADD COLUMN inventario_capacita INTEGER DEFAULT 50;")
