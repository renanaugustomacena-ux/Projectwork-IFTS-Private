## RoomGrid — Visual grid overlay shown during decoration edit mode.
## Draws subtle grid lines to guide item placement.
extends Node2D

const CELL_SIZE := 64
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.12)


func _ready() -> void:
	visible = false
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)


func _on_decoration_mode_changed(active: bool) -> void:
	visible = active
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var vp := Vector2(Constants.VIEWPORT_WIDTH, Constants.VIEWPORT_HEIGHT)

	var x := 0.0
	while x <= vp.x:
		draw_line(Vector2(x, 0), Vector2(x, vp.y), GRID_COLOR)
		x += CELL_SIZE

	var y := 0.0
	while y <= vp.y:
		draw_line(Vector2(0, y), Vector2(vp.x, y), GRID_COLOR)
		y += CELL_SIZE
