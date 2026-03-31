## MenuCharacter — Picks a random character and animates walk-in from offscreen.
extends Node2D

signal walk_in_completed

const WALK_DURATION := 2.0
const FRAME_INTERVAL := 0.15

const WALKABLE_CHARACTERS := [
	{
		"id": "male_old",
		"walk_path": "res://assets/charachters/male/old/male_walk/male_walk_side.png",
		"hframes": 4,
		"vframes": 1,
		"walk_row": 0,
		"flip_h": false,
		"char_scale": 4.0,
	},
]

var _sprite: Sprite2D
var _frame_timer: Timer
var _hframes: int = 4
var _walk_row: int = 0
var _current_frame: int = 0


func walk_in() -> void:
	var char_data: Dictionary = WALKABLE_CHARACTERS[0]

	var texture := load(char_data["walk_path"]) as Texture2D
	if texture == null:
		push_warning("MenuCharacter: failed to load walk sprite")
		walk_in_completed.emit()
		return

	_hframes = char_data["hframes"]
	_walk_row = char_data["walk_row"]
	_current_frame = 0

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = char_data["hframes"]
	_sprite.vframes = char_data["vframes"]
	_sprite.frame = _walk_row * _hframes
	_sprite.flip_h = char_data["flip_h"]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(char_data["char_scale"], char_data["char_scale"])
	add_child(_sprite)

	var start_pos := Vector2(-100, 530)
	var end_pos := Vector2(640, 530)
	position = start_pos

	_frame_timer = Timer.new()
	_frame_timer.wait_time = FRAME_INTERVAL
	_frame_timer.timeout.connect(_next_frame)
	add_child(_frame_timer)
	_frame_timer.start()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", end_pos, WALK_DURATION)
	tween.tween_callback(_on_walk_finished)


func _next_frame() -> void:
	_current_frame = (_current_frame + 1) % _hframes
	_sprite.frame = _walk_row * _hframes + _current_frame


func _on_walk_finished() -> void:
	if _frame_timer:
		_frame_timer.stop()
	walk_in_completed.emit()


func _exit_tree() -> void:
	if _frame_timer != null:
		if _frame_timer.timeout.is_connected(_next_frame):
			_frame_timer.timeout.disconnect(_next_frame)
		_frame_timer.stop()
		_frame_timer.queue_free()
		_frame_timer = null
