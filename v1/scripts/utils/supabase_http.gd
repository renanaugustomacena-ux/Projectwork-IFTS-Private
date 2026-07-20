## SupabaseHttp — Async HTTP request pool for Supabase REST calls.
## Pools HTTPRequest nodes to handle Godot's one-request-per-node limit.
class_name SupabaseHttp

signal request_completed(response: Dictionary)

const MAX_CONCURRENT := 3
const REQUEST_TIMEOUT := 15.0
const MAX_QUEUE_SIZE := 500  # cap per prevenire unbounded growth in RAM (fix B-025)
# Preview length for non-JSON bodies surfaced in the error field (audit 4.5.3).
const BODY_PREVIEW_CHARS := 100

var _pool: Array[HTTPRequest] = []
var _busy: Array[HTTPRequest] = []
var _queue: Array[Dictionary] = []
var _parent: Node


func initialize(parent: Node) -> void:
	_parent = parent
	for i in range(MAX_CONCURRENT):
		var http := HTTPRequest.new()
		http.timeout = REQUEST_TIMEOUT
		http.use_threads = false
		_parent.add_child(http)
		_pool.append(http)


func request(
	url: String,
	method: int,
	headers: PackedStringArray,
	body: String = "",
	request_id: String = "",
) -> void:
	var req_data := {
		"url": url,
		"method": method,
		"headers": headers,
		"body": body,
		"request_id": request_id,
	}
	if _pool.is_empty():
		if _queue.size() >= MAX_QUEUE_SIZE:
			# Drop oldest per prevenire OOM (fix B-025). L'utente avra` comunque
			# il SQLite sync_queue come backup persistente per retry.
			var dropped: Dictionary = _queue.pop_front()
			push_warning(
				(
					"SupabaseHttp: queue full (%d), dropped oldest request_id=%s"
					% [MAX_QUEUE_SIZE, dropped.get("request_id", "")]
				)
			)
			# Every request() call must produce exactly one request_completed
			# emission (Phase D): without this the dropped rid stays orphaned
			# in the caller's pending map and its sync cycle can only end via
			# the watchdog timeout.
			_emit_request_error.call_deferred(dropped.get("request_id", ""), ERR_BUSY)
		_queue.append(req_data)
		return
	_send(req_data)


func _send(req_data: Dictionary) -> void:
	var http: HTTPRequest = _pool.pop_back()
	_busy.append(http)
	var rid: String = req_data.get("request_id", "")
	var on_done := _on_http_done.bind(http, rid)
	http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	var err := (
		http
		. request(
			req_data["url"],
			req_data["headers"],
			req_data["method"],
			req_data.get("body", ""),
		)
	)
	if err != OK:
		# Disconnect the SAME bound callable (audit 4.5.1): the node signal
		# never fires for a rejected request, so ONE_SHOT would not consume
		# the stale binding and it would fire on the next pooled request.
		http.request_completed.disconnect(on_done)
		_return_to_pool(http)
		# Deferred emit (audit 4.8.4): callers must never observe a response
		# synchronously inside their own dispatch call.
		_emit_request_error.call_deferred(rid, err)


func _emit_request_error(rid: String, err: int) -> void:
	(
		request_completed
		. emit(
			{
				"status": 0,
				"body": null,
				"error": "HTTPRequest.request() failed: %d" % err,
				"request_id": rid,
			}
		)
	)


func _on_http_done(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body_bytes: PackedByteArray,
	http: HTTPRequest,
	request_id: String,
) -> void:
	_return_to_pool(http)
	if result != HTTPRequest.RESULT_SUCCESS:
		(
			request_completed
			. emit(
				{
					"status": 0,
					"body": null,
					"error": "HTTP result: %d" % result,
					"request_id": request_id,
				}
			)
		)
		return
	var body_text := body_bytes.get_string_from_utf8()
	var parsed: Variant = null
	var error_msg := ""
	if response_code < 200 or response_code >= 300:
		error_msg = "HTTP %d" % response_code
	if body_text.length() > 0:
		var json := JSON.new()
		if json.parse(body_text) == OK:
			parsed = json.data
		else:
			# Body stays null (audit 4.5.3): consumers rely on a
			# Dictionary-or-null contract — never a raw String body.
			# A short preview lands in the error field instead.
			var preview := "non-JSON body: %s" % body_text.left(BODY_PREVIEW_CHARS)
			error_msg = preview if error_msg.is_empty() else error_msg + "; " + preview
	(
		request_completed
		. emit(
			{
				"status": response_code,
				"body": parsed,
				"error": error_msg,
				"request_id": request_id,
			}
		)
	)


func _return_to_pool(http: HTTPRequest) -> void:
	_busy.erase(http)
	_pool.append(http)
	if not _queue.is_empty():
		_send(_queue.pop_front())


func cancel_all() -> void:
	_queue.clear()
	for http in _busy:
		http.cancel_request()


func cleanup() -> void:
	cancel_all()
	for http in _pool + _busy:
		if is_instance_valid(http):
			http.queue_free()
	_pool.clear()
	_busy.clear()
