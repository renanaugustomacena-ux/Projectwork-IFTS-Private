## SyncQueueRepo — CRUD per tabella sync_queue (B-033 split).
##
## Coda FIFO per push entity verso Supabase. Ogni row: table_name,
## operation, payload (JSON), retry_count.
## Phase D additions: 64 KB payload cap, retry increment, dead-letter move.
class_name SyncQueueRepo

const DBHelpers = preload("res://scripts/autoload/database/db_helpers.gd")

## Serialized-payload hard cap (audit 4.1.19): oversized payloads are
## rejected at enqueue time instead of poisoning the queue.
const MAX_PAYLOAD_CHARS := 65536


static func enqueue_sync(db: SQLite, table_name: String, operation: String, payload: Dictionary) -> bool:
	var payload_str := JSON.stringify(payload)
	if payload_str.length() > MAX_PAYLOAD_CHARS:
		(
			AppLogger
			. warn(
				"LocalDatabase",
				"sync_payload_too_large",
				{
					"table": table_name,
					"operation": operation,
					"payload_len": payload_str.length(),
					"cap": MAX_PAYLOAD_CHARS,
				}
			)
		)
		return false
	return (
		DBHelpers
		. execute_bound(
			db,
			"INSERT INTO sync_queue (table_name, operation, payload) VALUES (?, ?, ?);",
			[table_name, operation, payload_str],
		)
	)


static func get_pending_sync(db: SQLite) -> Array:
	# queue_id tiebreaker (audit 4.1.19): created_at has second resolution,
	# so same-second rows would otherwise dequeue in undefined order.
	return DBHelpers.select(db, "SELECT * FROM sync_queue ORDER BY created_at ASC, queue_id ASC;", [])


static func clear_sync_item(db: SQLite, queue_id: int) -> bool:
	return DBHelpers.execute_bound(db, "DELETE FROM sync_queue WHERE queue_id = ?;", [queue_id])


static func increment_retry(db: SQLite, queue_id: int) -> bool:
	return (
		DBHelpers
		. execute_bound(
			db,
			"UPDATE sync_queue SET retry_count = retry_count + 1 WHERE queue_id = ?;",
			[queue_id],
		)
	)


static func move_to_dead_letter(db: SQLite, queue_id: int, reason: String) -> bool:
	# SAVEPOINT-wrapped copy + delete (audit 4.1.1-L422): the payload either
	# lands in sync_dead_letter or stays queued — it is never plain-deleted.
	# SAVEPOINT (not BEGIN) so the move also composes with an outer
	# transaction if one is ever active.
	if not DBHelpers.execute(db, "SAVEPOINT sync_dlq;"):
		return false
	var copied := (
		DBHelpers
		. execute_bound(
			db,
			(
				"INSERT INTO sync_dead_letter "
				+ "(original_queue_id, table_name, operation, payload, reason) "
				+ "SELECT queue_id, table_name, operation, payload, ? "
				+ "FROM sync_queue WHERE queue_id = ?;"
			),
			[reason, queue_id],
		)
	)
	var deleted := copied and DBHelpers.execute_bound(db, "DELETE FROM sync_queue WHERE queue_id = ?;", [queue_id])
	if not deleted:
		DBHelpers.execute(db, "ROLLBACK TO sync_dlq;")
		DBHelpers.execute(db, "RELEASE sync_dlq;")
		return false
	return DBHelpers.execute(db, "RELEASE sync_dlq;")
