# gdlint: disable=max-public-methods
## LocalDatabase — SQLite local database autoload (facade post B-033 split).
##
## Responsabilita` residue nel root dopo split:
## - Lifecycle: _ready, _exit_tree, close, open
## - Schema delegation: create_all_tables + migrate_schema (via DBSchema)
## - Transaction orchestration: _on_save_requested (dual-write atomico)
## - Public API delegate: ogni metodo delega a un repo (AccountsRepo,
##   CharactersRepo, InventoryRepo, RoomsDecoRepo, SettingsRepo,
##   SyncQueueRepo, BadgesRepo)
##
## Callers esterni NON cambiano: `LocalDatabase.get_account(id)` funziona
## identico a prima del split. Nessuna regressione API.
##
## Facade pattern: 36 metodi pubblici delegate (superiamo il limit di 20
## per il facade pattern intenzionale). Gli effettivi "metodi pubblici
## funzionali" sono distribuiti fra le 7 repo (ognuna < 20 metodi).
extends Node

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")
const DBSchema = preload("res://scripts/autoload/database/schema.gd")
const AccountsRepo = preload("res://scripts/autoload/database/accounts_repo.gd")
const CharactersRepo = preload("res://scripts/autoload/database/characters_repo.gd")
const InventoryRepo = preload("res://scripts/autoload/database/inventory_repo.gd")
const RoomsDecoRepo = preload("res://scripts/autoload/database/rooms_deco_repo.gd")
const SettingsRepo = preload("res://scripts/autoload/database/settings_repo.gd")
const SyncQueueRepo = preload("res://scripts/autoload/database/sync_queue_repo.gd")
const BadgesRepo = preload("res://scripts/autoload/database/badges_repo.gd")

const DB_PATH := "user://cozy_room"

var _db: SQLite = null
var _is_open: bool = false


func _ready() -> void:
	_open_database()
	if _is_open:
		DBSchema.create_all_tables(_db)
		DBSchema.migrate_schema(_db)
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
		(
			AppLogger
			. error(
				"LocalDatabase",
				"Failed to open database",
				{
					"path": DB_PATH,
					"os": OS.get_name(),
					"user_data_dir": OS.get_user_data_dir(),
				},
			)
		)
		var dir := DirAccess.open("user://")
		if dir == null:
			AppLogger.error("LocalDatabase", "Cannot access user:// directory")
		_db = null
		return
	_is_open = true
	DBHelpers.execute(_db, "PRAGMA journal_mode=WAL;")
	DBHelpers.execute(_db, "PRAGMA foreign_keys=ON;")
	# Busy timeout 5s: evita blocco main thread Godot se altro processo
	# (es. crash precedente con lock residuo) detiene il DB. (fix B-026)
	DBHelpers.execute(_db, "PRAGMA busy_timeout=5000;")
	var fk_check := DBHelpers.select(_db, "PRAGMA foreign_keys;", [])
	if fk_check.is_empty() or fk_check[0].get("foreign_keys", 0) != 1:
		AppLogger.warn("LocalDatabase", "Foreign keys not enabled")


func _on_save_requested(data: Dictionary) -> void:
	if not _is_open:
		return
	var auth_uid: String = Constants.AUTH_GUEST_UID
	if AuthManager.current_auth_uid != "":
		auth_uid = AuthManager.current_auth_uid
	var account := AccountsRepo.get_account_by_auth_uid(_db, auth_uid)
	var account_id: int
	if account.is_empty():
		account_id = AccountsRepo.upsert_account(_db, auth_uid, Constants.AUTH_GUEST_EMAIL, "")
	else:
		account_id = account.get("account_id", -1)
	if account_id < 0:
		return
	DBHelpers.execute(_db, "BEGIN TRANSACTION;")
	var success := true
	if data.has("character") and data["character"] is Dictionary:
		if not CharactersRepo.upsert_character(_db, account_id, data["character"]):
			success = false
	if success and data.has("inventory") and data["inventory"] is Dictionary:
		if not InventoryRepo.save_inventory(_db, account_id, data["inventory"]):
			success = false
	# B-016 dual-write completo: settings, music_state, room+decorations
	if success and data.has("settings") and data["settings"] is Dictionary:
		if not SettingsRepo.upsert_settings(_db, account_id, data["settings"]):
			success = false
	if success and data.has("music_state") and data["music_state"] is Dictionary:
		if not SettingsRepo.upsert_music_state(_db, account_id, data["music_state"]):
			success = false
	if success and data.has("room") and data["room"] is Dictionary:
		# upsert_room richiede character_id (rooms table ha FK su characters)
		var char_row := CharactersRepo.get_character(_db, account_id)
		if not char_row.is_empty():
			var character_id: int = char_row.get("character_id", -1)
			if character_id >= 0:
				if not RoomsDecoRepo.upsert_room(_db, character_id, data["room"]):
					success = false
	if success:
		DBHelpers.execute(_db, "COMMIT;")
	else:
		DBHelpers.execute(_db, "ROLLBACK;")
		(
			AppLogger
			. error(
				"LocalDatabase",
				"Save rolled back",
				{
					"account_id": account_id,
					"has_settings": data.has("settings"),
					"has_music_state": data.has("music_state"),
					"has_room": data.has("room"),
				},
			)
		)


# ==========================================================================
# ==== Public API facade — delega a repo dedicate (B-033 split) ============
# ==========================================================================
# Firme preservate 1:1 con pre-split. Ogni caller LocalDatabase.foo(args)
# continua a funzionare senza modifiche. Refactor trasparente.

# ---- Accounts ----


func get_account(account_id: int) -> Dictionary:
	return AccountsRepo.get_account(_db, account_id)


func get_account_by_auth_uid(auth_uid: String) -> Dictionary:
	return AccountsRepo.get_account_by_auth_uid(_db, auth_uid)


func upsert_account(auth_uid: String, mail: String, data_di_nascita: String = "") -> int:
	return AccountsRepo.upsert_account(_db, auth_uid, mail, data_di_nascita)


func get_account_by_username(username: String) -> Dictionary:
	return AccountsRepo.get_account_by_username(_db, username)


func create_account(username: String, password_hash: String) -> int:
	return AccountsRepo.create_account(_db, username, password_hash)


func delete_account(account_id: int) -> bool:
	return AccountsRepo.delete_account(_db, account_id)


func soft_delete_account(account_id: int) -> bool:
	return AccountsRepo.soft_delete_account(_db, account_id)


func update_password_hash(account_id: int, new_hash: String) -> bool:
	return AccountsRepo.update_password_hash(_db, account_id, new_hash)


func update_auth_uid(account_id: int, new_auth_uid: String) -> bool:
	return AccountsRepo.update_auth_uid(_db, account_id, new_auth_uid)


# ---- Characters ----


func get_character(account_id: int) -> Dictionary:
	return CharactersRepo.get_character(_db, account_id)


func upsert_character(account_id: int, data: Dictionary) -> bool:
	return CharactersRepo.upsert_character(_db, account_id, data)


func delete_character(account_id: int) -> bool:
	return CharactersRepo.delete_character(_db, account_id)


# ---- Inventory ----


func get_inventory(account_id: int) -> Array:
	return InventoryRepo.get_inventory(_db, account_id)


func add_inventory_item(account_id: int, item_id: int, quantita: int = 1) -> bool:
	return InventoryRepo.add_inventory_item(_db, account_id, item_id, quantita)


func remove_inventory_item(account_id: int, item_id: int) -> bool:
	return InventoryRepo.remove_inventory_item(_db, account_id, item_id)


func update_coins(account_id: int, coins: int) -> bool:
	return InventoryRepo.update_coins(_db, account_id, coins)


func get_coins(account_id: int) -> int:
	return InventoryRepo.get_coins(_db, account_id)


# ---- Rooms + placed decorations ----


func get_room(character_id: int) -> Dictionary:
	return RoomsDecoRepo.get_room(_db, character_id)


func upsert_room(character_id: int, data: Dictionary) -> bool:
	return RoomsDecoRepo.upsert_room(_db, character_id, data)


func delete_room(character_id: int) -> bool:
	return RoomsDecoRepo.delete_room(_db, character_id)


func get_placed_decorations(room_id: int) -> Array:
	return RoomsDecoRepo.get_placed_decorations(_db, room_id)


func add_placed_decoration(room_id: int, data: Dictionary) -> bool:
	return RoomsDecoRepo.add_placed_decoration(_db, room_id, data)


func remove_placed_decoration(placement_id: int) -> bool:
	return RoomsDecoRepo.remove_placed_decoration(_db, placement_id)


func clear_room_decorations(room_id: int) -> bool:
	return RoomsDecoRepo.clear_room_decorations(_db, room_id)


# ---- Settings / save_metadata / music_state ----


func get_settings(account_id: int) -> Dictionary:
	return SettingsRepo.get_settings(_db, account_id)


func upsert_settings(account_id: int, data: Dictionary) -> bool:
	return SettingsRepo.upsert_settings(_db, account_id, data)


func get_save_metadata(account_id: int) -> Dictionary:
	return SettingsRepo.get_save_metadata(_db, account_id)


func upsert_save_metadata(account_id: int, data: Dictionary) -> bool:
	return SettingsRepo.upsert_save_metadata(_db, account_id, data)


func get_music_state(account_id: int) -> Dictionary:
	return SettingsRepo.get_music_state(_db, account_id)


func upsert_music_state(account_id: int, data: Dictionary) -> bool:
	return SettingsRepo.upsert_music_state(_db, account_id, data)


# ---- Sync queue ----


func enqueue_sync(table_name: String, operation: String, payload: Dictionary) -> bool:
	return SyncQueueRepo.enqueue_sync(_db, table_name, operation, payload)


func get_pending_sync() -> Array:
	return SyncQueueRepo.get_pending_sync(_db)


func clear_sync_item(queue_id: int) -> bool:
	return SyncQueueRepo.clear_sync_item(_db, queue_id)


# ---- Badges (T-R-015d) ----


func get_unlocked_badges(account_id: int) -> Array:
	return BadgesRepo.get_unlocked_badges(_db, account_id)


func is_badge_unlocked(account_id: int, badge_id: String) -> bool:
	return BadgesRepo.is_badge_unlocked(_db, account_id, badge_id)


func unlock_badge(account_id: int, badge_id: String) -> bool:
	return BadgesRepo.unlock_badge(_db, account_id, badge_id)
