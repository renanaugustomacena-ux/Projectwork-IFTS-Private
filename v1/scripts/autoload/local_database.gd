# gdlint: disable=max-public-methods
## LocalDatabase — SQLite local database autoload (facade post B-033 split).
##
## Responsabilita` residue nel root dopo split:
## - Lifecycle: _ready, _exit_tree, close, open
## - Schema delegation: create_all_tables + migrate_schema (via DBSchema)
## - Transaction orchestration: apply_save (dual-write atomico, C.6)
## - Public API delegate: ogni metodo delega a un repo (AccountsRepo,
##   CharactersRepo, InventoryRepo, RoomsDecoRepo, SettingsRepo,
##   SyncQueueRepo, BadgesRepo)
##
## Callers esterni NON cambiano: `LocalDatabase.get_account(id)` funziona
## identico a prima del split. Nessuna regressione API.
##
## Facade pattern: 38 metodi pubblici delegate (superiamo il limit di 20
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
## Motivo distinto impostato da _resolve_save_account_id quando torna il
## sentinella -1; apply_save lo rilancia come db_error, cosi` il toast non dice
## sempre la stessa cosa (stessa convenzione di GameManager._last_catalog_error).
var _last_account_error: String = ""


func _ready() -> void:
	_open_database()
	if _is_open:
		if not DBSchema.create_all_tables(_db):
			AppLogger.error("LocalDatabase", "Schema creation reported failures at startup")
		DBSchema.migrate_schema(_db)
		AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})


func _exit_tree() -> void:
	# Close in _exit_tree, NOT on NOTIFICATION_WM_CLOSE_REQUEST: autoloads are
	# torn down in reverse registration order, so SaveManager (registered after
	# this singleton) runs its quit-save while the DB is still open. Closing on
	# WM_CLOSE would race the quit-save and fail every apply_save at shutdown.
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
		# V-062: senza FK ogni ON DELETE CASCADE dello schema smette di
		# funzionare in silenzio. Fail-closed: meglio nessun mirror che uno
		# incoerente (modulo 23, valida ai confini).
		AppLogger.error("LocalDatabase", "foreign_keys_unavailable_db_closed")
		_db.close_db()
		_is_open = false
		return


## C.6 synchronous facade for the dual-write mirror (replaces the old
## fire-and-forget save_to_database_requested signal path — SaveManager was
## its only emitter). Returns true ONLY when the whole transaction committed;
## SaveManager gates save_completed on this return value.
func apply_save(data: Dictionary) -> bool:
	if not _is_open:
		SignalBus.db_error.emit("apply_save", "db_not_open")
		return false
	var account_id := _resolve_save_account_id()
	if account_id < 0:
		SignalBus.db_error.emit("apply_save", _last_account_error)
		return false
	# C.3 transaction honesty: BEGIN/COMMIT returns checked, failure surfaced.
	if not DBHelpers.execute(_db, "BEGIN TRANSACTION;"):
		AppLogger.error("LocalDatabase", "BEGIN failed, save skipped", {"account_id": account_id})
		SignalBus.db_error.emit("begin", "begin_failed")
		return false
	if not _apply_save_writes(account_id, data):
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
		SignalBus.db_error.emit("apply_save", "repo_write_failed")
		return false
	if not DBHelpers.execute(_db, "COMMIT;"):
		DBHelpers.execute(_db, "ROLLBACK;")
		AppLogger.error("LocalDatabase", "COMMIT failed, forced rollback", {"account_id": account_id})
		SignalBus.db_error.emit("commit", "commit_failed")
		return false
	return true


## Account che riceve il salvataggio, o -1 se non e` possibile stabilirlo.
##
## V-021: la riga con mail segnaposto da ospite puo` nascere SOLO per l'uid
## ospite. Prima il fallback era incondizionato, quindi un lookup a vuoto su un
## uid autenticato vero (riga cancellata altrove, migrazione a meta`, DB
## riaperto dopo un crash) coniava un account `offline@local` sotto l'identita`
## reale del giocatore: da li` in poi il salvataggio viveva su un account
## fantasma e quello vero restava indietro. Meglio abortire rumorosamente — il
## sentinella fa fallire apply_save, che emette `db_error` e quindi un toast —
## che riscrivere di nascosto l'identita` di chi un account ce l'ha davvero.
func _resolve_save_account_id() -> int:
	_last_account_error = "account_resolve_failed"
	var auth_uid: String = Constants.AUTH_GUEST_UID
	if AuthManager.current_auth_uid != "":
		auth_uid = AuthManager.current_auth_uid
	var account := AccountsRepo.get_account_by_auth_uid(_db, auth_uid)
	if not account.is_empty():
		return int(account.get("account_id", -1))
	if auth_uid == Constants.AUTH_GUEST_UID:
		return AccountsRepo.upsert_account(_db, auth_uid, Constants.AUTH_GUEST_EMAIL, "")
	_last_account_error = "account_row_missing"
	# L'uid non finisce nel log: e` l'identificatore di sessione dell'utente.
	(
		AppLogger
		. error(
			"LocalDatabase",
			"No account row for an authenticated uid, refusing to mint a guest account",
			{"auth_uid_len": auth_uid.length()},
		)
	)
	return -1


func _apply_save_writes(account_id: int, data: Dictionary) -> bool:
	# Fail-fast per blocco: `ok and X` non chiama X dopo il primo fallimento.
	var ok := true
	if data.has("character") and data["character"] is Dictionary:
		ok = ok and CharactersRepo.upsert_character(_db, account_id, data["character"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		ok = ok and InventoryRepo.save_inventory(_db, account_id, data["inventory"])
	# B-016 dual-write completo: settings, music_state, save_metadata, room+decorazioni
	if data.has("settings") and data["settings"] is Dictionary:
		ok = ok and SettingsRepo.upsert_settings(_db, account_id, data["settings"])
	if data.has("music_state") and data["music_state"] is Dictionary:
		ok = ok and SettingsRepo.upsert_music_state(_db, account_id, data["music_state"])
	if data.has("save_metadata") and data["save_metadata"] is Dictionary:
		ok = ok and SettingsRepo.upsert_save_metadata(_db, account_id, data["save_metadata"])
	if ok and data.has("room") and data["room"] is Dictionary:
		# upsert_room richiede character_id (rooms table ha FK su characters)
		var char_row := CharactersRepo.get_character(_db, account_id)
		var character_id: int = int(char_row.get("character_id", -1)) if not char_row.is_empty() else -1
		if character_id >= 0:
			ok = RoomsDecoRepo.upsert_room(_db, character_id, data["room"])
		else:
			# DB-11: era l'unico ramo che saltava lo specchio senza dirlo.
			AppLogger.warn("LocalDatabase", "room_mirror_skipped_no_character", {"account_id": account_id})
	return ok


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


## Phase D rate-limit persistence facade (audit 4.4.2).
func get_rate_limit(username: String) -> Dictionary:
	return AccountsRepo.get_rate_limit(_db, username)


func set_rate_limit(username: String, attempts: int, lockout_until_unix: int) -> bool:
	return AccountsRepo.set_rate_limit(_db, username, attempts, lockout_until_unix)


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


func increment_retry(queue_id: int) -> bool:
	return SyncQueueRepo.increment_retry(_db, queue_id)


## Phase D dead-letter facade (audit 4.1.1-L422): corrupt or retry-exhausted
## sync payloads move to sync_dead_letter instead of being plain-deleted.
func move_sync_item_to_dead_letter(queue_id: int, reason: String) -> bool:
	return SyncQueueRepo.move_to_dead_letter(_db, queue_id, reason)


# ---- Badges (T-R-015d) ----


func get_unlocked_badges(account_id: int) -> Array:
	return BadgesRepo.get_unlocked_badges(_db, account_id)


func is_badge_unlocked(account_id: int, badge_id: String) -> bool:
	return BadgesRepo.is_badge_unlocked(_db, account_id, badge_id)


func unlock_badge(account_id: int, badge_id: String) -> bool:
	return BadgesRepo.unlock_badge(_db, account_id, badge_id)
