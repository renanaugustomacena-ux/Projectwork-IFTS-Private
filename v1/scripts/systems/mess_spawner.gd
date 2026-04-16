## MessSpawner — Spawner ciclico di MessNode dentro il floor polygon della stanza.
##
## Non e` un autoload: viene istanziato da RoomBase come figlio. Usa un Timer
## interno con intervallo casuale tra MIN_INTERVAL e MAX_INTERVAL secondi.
## Rispetta un limite massimo di mess simultanei e seleziona la variante via
## weighted random sampling sul campo `spawn_weight` del catalog.
class_name MessSpawner
extends Node

const MessNodeScript := preload("res://scripts/rooms/mess_node.gd")

const MIN_INTERVAL: float = 60.0
const MAX_INTERVAL: float = 180.0
const MAX_CONCURRENT: int = 5
const MAX_PLACEMENT_ATTEMPTS: int = 20
const FLOOR_MARGIN: float = 16.0

var mess_container: Node2D
var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_schedule_next()


func _exit_tree() -> void:
	# Stop + disconnect timer per evitare zombie spawn se lo spawner viene
	# free durante scene reload (fix B-013).
	if _timer != null and is_instance_valid(_timer):
		_timer.stop()
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)


func set_container(container: Node2D) -> void:
	mess_container = container


func _schedule_next() -> void:
	_timer.wait_time = _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	_timer.start()


func _on_timer_timeout() -> void:
	if _count_active_mess() < MAX_CONCURRENT:
		_spawn_random_mess()
	_schedule_next()


func _count_active_mess() -> int:
	if mess_container == null:
		return 0
	var n := 0
	# Usa confronto script preloadato invece di `is MessNode` perche` il
	# class_name cache di Godot puo` andare stale e causare parse error
	# "Could not find type MessNode" (stesso pattern gia fixato per MessSpawner).
	for child in mess_container.get_children():
		if child.get_script() == MessNodeScript:
			n += 1
	return n


func _spawn_random_mess() -> void:
	if mess_container == null:
		push_warning("MessSpawner: no container set, cannot spawn")
		return
	var entries: Array = GameManager.mess_catalog.get("mess", [])
	if entries.is_empty():
		return
	var entry := _weighted_pick(entries)
	if entry.is_empty():
		return
	var pos := _random_floor_position()
	if pos == Vector2.INF:
		return  # No valid floor position found this cycle

	var mess := MessNodeScript.new()
	mess.setup(entry, pos)
	mess_container.add_child(mess)
	SignalBus.mess_spawned.emit(entry.get("id", ""), pos)


func _weighted_pick(entries: Array) -> Dictionary:
	var total: float = 0.0
	for e in entries:
		if e is Dictionary:
			total += float(e.get("spawn_weight", 1.0))
	if total <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total)
	var acc: float = 0.0
	for e in entries:
		if not (e is Dictionary):
			continue
		acc += float(e.get("spawn_weight", 1.0))
		if roll <= acc:
			return e
	return entries.back() if not entries.is_empty() else {}


func _random_floor_position() -> Vector2:
	if not Helpers.has_floor_polygon():
		return Vector2.INF
	var bbox := Helpers.get_floor_bounds()
	if bbox.size == Vector2.ZERO:
		return Vector2.INF
	for _i in range(MAX_PLACEMENT_ATTEMPTS):
		var candidate := Vector2(
			_rng.randf_range(bbox.position.x + FLOOR_MARGIN, bbox.end.x - FLOOR_MARGIN),
			_rng.randf_range(bbox.position.y + FLOOR_MARGIN, bbox.end.y - FLOOR_MARGIN),
		)
		var clamped := Helpers.clamp_inside_floor(candidate, FLOOR_MARGIN)
		if clamped == candidate:
			return candidate
	return Vector2.INF
