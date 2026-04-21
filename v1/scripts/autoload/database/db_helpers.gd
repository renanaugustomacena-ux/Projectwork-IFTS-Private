## DBHelpers — SQL execution primitives condivise da tutte le repo.
##
## Static methods: ogni caller passa il SQLite instance come primo arg.
## Logging via AppLogger con prefix identificante "LocalDatabase" per
## preservare continuity di log parsing (stesso tag pre-B-033-split).
class_name DBHelpers


static func execute(db: SQLite, sql: String) -> bool:
	if db == null:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return false
	if not db.query(sql):
		AppLogger.error("LocalDatabase", "Query failed", {"sql": sql.left(80)})
		return false
	return true


static func execute_bound(db: SQLite, sql: String, bindings: Array) -> bool:
	if db == null:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return false
	if not db.query_with_bindings(sql, bindings):
		AppLogger.error("LocalDatabase", "Bound query failed", {"sql": sql.left(80)})
		return false
	return true


static func select(db: SQLite, sql: String, bindings: Array) -> Array:
	if db == null:
		AppLogger.error("LocalDatabase", "Database not open", {"sql": sql.left(80)})
		return []
	if bindings.is_empty():
		if not db.query(sql):
			AppLogger.error("LocalDatabase", "select_failed", {"sql": sql.left(80)})
			return []
	else:
		if not db.query_with_bindings(sql, bindings):
			(
				AppLogger
				. error(
					"LocalDatabase",
					"select_bound_failed",
					{"sql": sql.left(80), "bindings": bindings},
				)
			)
			return []
	return db.query_result
