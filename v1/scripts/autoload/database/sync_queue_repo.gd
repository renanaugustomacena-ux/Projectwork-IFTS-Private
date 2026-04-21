## SyncQueueRepo — CRUD per tabella sync_queue (B-033 split).
##
## Coda FIFO per push entity verso Supabase. Ogni row: table_name,
## operation, payload (JSON), retry_count.
class_name SyncQueueRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")


static func enqueue_sync(db: SQLite, table_name: String, operation: String, payload: Dictionary) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO sync_queue (table_name, operation, payload) VALUES (?, ?, ?);",
			[table_name, operation, JSON.stringify(payload)],
		)
	)


static func get_pending_sync(db: SQLite) -> Array:
	return DBHelpers.select(db, "SELECT * FROM sync_queue ORDER BY created_at ASC;", [])


static func clear_sync_item(db: SQLite, queue_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM sync_queue WHERE queue_id = ?;", [queue_id])
