## RoomGrid — Visual grid overlay shown during decoration edit mode.
## Draws subtle grid lines in the floor zone to guide item placement.
extends Node2D

const CELL_SIZE := 64
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const WALL_ZONE_RATIO := 0.4
# Room.png 180x155 at scale 4, centered (640,360) → x=280..1000, y=50..670
const ROOM_LEFT := 280.0
const ROOM_RIGHT := 1000.0
const ROOM_BOTTOM := 670.0


func _ready() -> void:
	visible = false
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)


func _on_decoration_mode_changed(active: bool) -> void:
	visible = active
	queue_redraw()


func _exit_tree() -> void:
	if SignalBus.decoration_mode_changed.is_connected(_on_decoration_mode_changed):
		SignalBus.decoration_mode_changed.disconnect(_on_decoration_mode_changed)


func _draw() -> void:
	if not visible:
		return

	var vp := Vector2(Constants.VIEWPORT_WIDTH, Constants.VIEWPORT_HEIGHT)
	var floor_top := vp.y * WALL_ZONE_RATIO

	var x := ROOM_LEFT
	while x <= ROOM_RIGHT:
		draw_line(Vector2(x, floor_top), Vector2(x, ROOM_BOTTOM), GRID_COLOR)
		x += CELL_SIZE

	var y := floor_top
	while y <= ROOM_BOTTOM:
		draw_line(Vector2(ROOM_LEFT, y), Vector2(ROOM_RIGHT, y), GRID_COLOR)
		y += CELL_SIZE
