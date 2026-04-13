## SupabaseHttp — Async HTTP request pool for Supabase REST calls.
## Pools HTTPRequest nodes to handle Godot's one-request-per-node limit.
class_name SupabaseHttp

signal request_completed(response: Dictionary)

const MAX_CONCURRENT := 3
const REQUEST_TIMEOUT := 15.0

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
		_queue.append(req_data)
		return
	_send(req_data)


func _send(req_data: Dictionary) -> void:
	var http: HTTPRequest = _pool.pop_back()
	_busy.append(http)
	var rid: String = req_data.get("request_id", "")
	http.request_completed.connect(
		_on_http_done.bind(http, rid), CONNECT_ONE_SHOT
	)
	var err := http.request(
		req_data["url"],
		req_data["headers"],
		req_data["method"],
		req_data.get("body", ""),
	)
	if err != OK:
		http.request_completed.disconnect(_on_http_done)
		_return_to_pool(http)
		request_completed.emit({
			"status": 0,
			"body": null,
			"error": "HTTPRequest.request() failed: %d" % err,
			"request_id": rid,
		})


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
		request_completed.emit({
			"status": 0,
			"body": null,
			"error": "HTTP result: %d" % result,
			"request_id": request_id,
		})
		return
	var body_text := body_bytes.get_string_from_utf8()
	var parsed: Variant = null
	if body_text.length() > 0:
		var json := JSON.new()
		if json.parse(body_text) == OK:
			parsed = json.data
		else:
			parsed = body_text
	request_completed.emit({
		"status": response_code,
		"body": parsed,
		"error": "" if response_code >= 200 and response_code < 300 else "HTTP %d" % response_code,
		"request_id": request_id,
	})


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
