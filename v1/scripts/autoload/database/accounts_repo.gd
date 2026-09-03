## AccountsRepo — CRUD per tabella accounts (B-033 split).
##
## Tutti i metodi static: primo arg sempre SQLite instance.
## SQL strings preservati 1:1 dall'implementazione pre-split in
## local_database.gd.
class_name AccountsRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_account(db: SQLite, account_id: int) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM accounts WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]


static func get_account_by_auth_uid(db: SQLite, auth_uid: String) -> Dictionary:
	var rows := DBHelpers.select(db, "SELECT * FROM accounts WHERE auth_uid = ?;", [auth_uid])
	if rows.is_empty():
		return {}
	return rows[0]


static func upsert_account(db: SQLite, auth_uid: String, mail: String, data_di_nascita: String = "") -> int:
	var existing := get_account_by_auth_uid(db, auth_uid)
	if not existing.is_empty():
		# Audit 4.1.13-L28: a failed UPDATE must not return a stale id.
		var updated := (
			DBHelpers
			. execute_bound(
				db,
				"UPDATE accounts SET mail = ?, data_di_nascita = ? WHERE auth_uid = ?;",
				[mail, data_di_nascita, auth_uid],
			)
		)
		if not updated:
			return -1
		return existing.get("account_id", -1)

	var inserted := (
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO accounts (auth_uid, mail, data_di_nascita) VALUES (?, ?, ?);",
			[auth_uid, mail, data_di_nascita],
		)
	)
	if not inserted:
		return -1
	var rows := DBHelpers.select(db, "SELECT last_insert_rowid() as id;", [])
	if rows.is_empty():
		return -1
	return rows[0].get("id", -1)


static func get_account_by_username(db: SQLite, username: String) -> Dictionary:
	var rows := (
		DBHelpers
		. select(
			db,
			(
				"SELECT * FROM accounts"
				+ " WHERE display_name = ? COLLATE NOCASE AND auth_uid != ?"
				+ " AND deleted_at IS NULL;"
			),
			[username, Constants.AUTH_GUEST_UID],
		)
	)
	if rows.is_empty():
		return {}
	return rows[0]


static func create_account(db: SQLite, username: String, password_hash: String) -> int:
	# Audit 4.1.13-L66: explicit conflict pre-check — an unchecked INSERT
	# must never fall through to last_insert_rowid() of a previous insert.
	if not get_account_by_username(db, username).is_empty():
		(
			AppLogger
			. warn(
				"LocalDatabase",
				"create_account_username_conflict",
				{"username_len": username.length()},
			)
		)
		return -1
	var auth_uid := "user_%s" % username.to_lower()
	var inserted := (
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO accounts (auth_uid, display_name, password_hash) VALUES (?, ?, ?);",
			[auth_uid, username, password_hash],
		)
	)
	if not inserted:
		return -1
	var rows := DBHelpers.select(db, "SELECT last_insert_rowid() as id;", [])
	if rows.is_empty():
		return -1
	return rows[0].get("id", -1)


static func delete_account(db: SQLite, account_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM accounts WHERE account_id = ?;", [account_id])


static func soft_delete_account(db: SQLite, account_id: int) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"UPDATE accounts SET deleted_at = datetime('now'),"
				+ " display_name = '', password_hash = ''"
				+ " WHERE account_id = ?;"
			),
			[account_id],
		)
	)


static func update_password_hash(db: SQLite, account_id: int, new_hash: String) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"UPDATE accounts SET password_hash = ? WHERE account_id = ?;",
			[new_hash, account_id],
		)
	)


static func update_auth_uid(db: SQLite, account_id: int, new_auth_uid: String) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"UPDATE accounts SET auth_uid = ? WHERE account_id = ?;",
			[new_auth_uid, account_id],
		)
	)


## Phase D (audit 4.4.2): per-username rate-limit state persisted on the
## accounts columns added by schema migration 3 (failed_attempts,
## lockout_until_unix). Returns {} when no matching account row exists.
static func get_rate_limit(db: SQLite, username: String) -> Dictionary:
	var rows := (
		DBHelpers
		. select(
			db,
			(
				"SELECT failed_attempts, lockout_until_unix FROM accounts"
				+ " WHERE display_name = ? COLLATE NOCASE AND auth_uid != ? AND deleted_at IS NULL;"
			),
			[username, Constants.AUTH_GUEST_UID],
		)
	)
	if rows.is_empty():
		return {}
	var attempts: Variant = rows[0].get("failed_attempts", 0)
	var lockout: Variant = rows[0].get("lockout_until_unix", 0)
	return {
		"failed_attempts": attempts if attempts is int else 0,
		"lockout_until_unix": lockout if lockout is int else 0,
	}


static func set_rate_limit(db: SQLite, username: String, attempts: int, lockout_until_unix: int) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			(
				"UPDATE accounts SET failed_attempts = ?, lockout_until_unix = ?"
				+ " WHERE display_name = ? COLLATE NOCASE AND auth_uid != ? AND deleted_at IS NULL;"
			),
			[attempts, lockout_until_unix, username, Constants.AUTH_GUEST_UID],
		)
	)
