## DBHelpers — SQL execution primitives condivise da tutte le repo.
##
## Static methods: ogni caller passa il SQLite instance come primo arg.
## Logging via AppLogger con prefix identificante "LocalDatabase" per
## preservare continuity di log parsing (stesso tag pre-B-033-split).
##
## Phase D (audit 4.1.12-L44/L13, 4.3-db-error): every failure logs
## db.error_message plus a 400-char SQL preview, bindings are summarised
## as {count, types} (never raw values — PII / password hashes), and
## SignalBus.db_error is emitted with a stable per-helper context tag.
class_name DBHelpers

const SQL_PREVIEW_CHARS := 400


static func execute(db: SQLite, sql: String) -> bool:
	if db == null:
		_report_failure("execute", db, sql, [])
		return false
	if not db.query(sql):
		_report_failure("execute", db, sql, [])
		return false
	return true


static func execute_bound(db: SQLite, sql: String, bindings: Array) -> bool:
	if db == null:
		_report_failure("execute_bound", db, sql, bindings)
		return false
	if not db.query_with_bindings(sql, bindings):
		_report_failure("execute_bound", db, sql, bindings)
		return false
	return true


static func select(db: SQLite, sql: String, bindings: Array) -> Array:
	if db == null:
		_report_failure("select", db, sql, bindings)
		return []
	if bindings.is_empty():
		if not db.query(sql):
			_report_failure("select", db, sql, bindings)
			return []
	else:
		if not db.query_with_bindings(sql, bindings):
			_report_failure("select", db, sql, bindings)
			return []
	return db.query_result


static func _report_failure(context: String, db: SQLite, sql: String, bindings: Array) -> void:
	var reason := "db_not_open"
	if db != null:
		reason = db.error_message
		if reason.is_empty():
			reason = "unknown_db_error"
	(
		AppLogger
		. error(
			"LocalDatabase",
			"%s_failed" % context,
			{
				"error": reason,
				"sql": sql.left(SQL_PREVIEW_CHARS),
				"bindings": _summarize_bindings(bindings),
			},
		)
	)
	SignalBus.db_error.emit(context, reason)


static func _summarize_bindings(bindings: Array) -> Dictionary:
	# Audit 4.1.12-L44: raw binding values must never reach the logs.
	var types: Array[String] = []
	for value in bindings:
		types.append(type_string(typeof(value)))
	return {"count": bindings.size(), "types": types}
