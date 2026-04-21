## BadgesRepo — CRUD per tabella badges_unlocked (T-R-015d, B-033 split).
class_name BadgesRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func get_unlocked_badges(db: SQLite, account_id: int) -> Array:
	return (
		DBHelpers
		. select(
			db,
			"SELECT badge_id, unlocked_at FROM badges_unlocked WHERE account_id = ?;",
			[account_id],
		)
	)


static func is_badge_unlocked(db: SQLite, account_id: int, badge_id: String) -> bool:
	var rows := (
		DBHelpers
		. select(
			db,
			"SELECT 1 FROM badges_unlocked WHERE account_id = ? AND badge_id = ?;",
			[account_id, badge_id],
		)
	)
	return not rows.is_empty()


static func unlock_badge(db: SQLite, account_id: int, badge_id: String) -> bool:
	# INSERT OR IGNORE evita duplicati grazie a UNIQUE(account_id, badge_id)
	return (
		DBHelpers
		. execute_bound(
			db,
			"INSERT OR IGNORE INTO badges_unlocked (account_id, badge_id) VALUES (?, ?);",
			[account_id, badge_id],
		)
	)
