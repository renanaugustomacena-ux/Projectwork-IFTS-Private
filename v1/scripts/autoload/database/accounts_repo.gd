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
		(
			DBHelpers
			. execute_bound(
				db,
				"UPDATE accounts SET mail = ?, data_di_nascita = ? WHERE auth_uid = ?;",
				[mail, data_di_nascita, auth_uid],
			)
		)
		return existing.get("account_id", -1)

	(
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO accounts (auth_uid, mail, data_di_nascita) VALUES (?, ?, ?);",
			[auth_uid, mail, data_di_nascita],
		)
	)
	var rows := DBHelpers.select(db, "SELECT last_insert_rowid() as id;", [])
	if rows.is_empty():
		return -1
	return rows[0].get("id", -1)


static func get_account_by_username(db: SQLite, username: String) -> Dictionary:
	var rows := (
		DBHelpers
		. select(
			db,
			"SELECT * FROM accounts" + " WHERE display_name = ? AND auth_uid != ?" + " AND deleted_at IS NULL;",
			[username, Constants.AUTH_GUEST_UID],
		)
	)
	if rows.is_empty():
		return {}
	return rows[0]


static func create_account(db: SQLite, username: String, password_hash: String) -> int:
	var auth_uid := "user_%s" % username.to_lower()
	(
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO accounts (auth_uid, display_name, password_hash) VALUES (?, ?, ?);",
			[auth_uid, username, password_hash],
		)
	)
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
