## RoomGrid — Visual placement guide shown during decoration edit mode.
## Draws the REAL floor polygon and wall band from Helpers (the same geometry
## every placement clamp uses), plus grid lines clipped to the floor. Because
## it renders the authoritative geometry instead of its own constants, any
## drift between collision and visuals is immediately visible in edit mode.
extends Node2D

const CELL_SIZE := 64
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const FLOOR_EDGE_COLOR := Color(0.55, 0.85, 1.0, 0.45)
const WALL_EDGE_COLOR := Color(1.0, 0.85, 0.4, 0.30)


func _ready() -> void:
	visible = false
	SignalBus.decoration_mode_changed.connect(_on_decoration_mode_changed)
	# B-004: ridisegna la griglia se il viewport cambia dimensione (resize
	# finestra, stretch mode). Senza questo i quadrati diventano "giganti"
	# perche` restano ancorati alle coordinate originali mentre il viewport
	# si scala.
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(queue_redraw)


func _on_decoration_mode_changed(active: bool) -> void:
	visible = active
	queue_redraw()


func _exit_tree() -> void:
	if SignalBus.decoration_mode_changed.is_connected(_on_decoration_mode_changed):
		SignalBus.decoration_mode_changed.disconnect(_on_decoration_mode_changed)
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(queue_redraw):
		vp.size_changed.disconnect(queue_redraw)


func _draw() -> void:
	if not visible:
		return
	var poly := Helpers.get_floor_polygon_world()
	if poly.size() < 3:
		return

	_draw_grid_clipped(poly)

	# Floor boundary — where feet (and floor-item anchors) may go.
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, FLOOR_EDGE_COLOR, 2.0)

	_draw_wall_band()


## Grid lines clipped to the floor polygon so the guide never suggests
## placements outside the playable area.
func _draw_grid_clipped(poly: PackedVector2Array) -> void:
	var bounds := Helpers.get_floor_bounds()
	if not bounds.has_area():
		return
	var x := ceilf(bounds.position.x / CELL_SIZE) * CELL_SIZE
	while x <= bounds.end.x:
		_draw_clipped_segment(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), poly)
		x += CELL_SIZE
	var y := ceilf(bounds.position.y / CELL_SIZE) * CELL_SIZE
	while y <= bounds.end.y:
		_draw_clipped_segment(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), poly)
		y += CELL_SIZE


func _draw_clipped_segment(a: Vector2, b: Vector2, poly: PackedVector2Array) -> void:
	var pieces := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly)
	for piece in pieces:
		if piece.size() >= 2:
			draw_polyline(piece, GRID_COLOR, 1.0)


## Wall band outline — the region wall items (windows, paintings) clamp into.
func _draw_wall_band() -> void:
	if not Helpers.has_wall_band():
		return
	var bounds := Helpers.get_floor_bounds()
	var left_x := bounds.position.x
	var right_x := bounds.end.x
	var samples := 24
	var base_line := PackedVector2Array()
	var top_line := PackedVector2Array()
	for i in samples + 1:
		var x := lerpf(left_x, right_x, float(i) / samples)
		var base_y := Helpers.wall_base_y_at(x)
		if base_y == INF:
			continue
		base_line.append(Vector2(x, base_y))
		top_line.append(Vector2(x, base_y - Helpers.WALL_BAND_HEIGHT))
	if base_line.size() >= 2:
		draw_polyline(top_line, WALL_EDGE_COLOR, 1.5)
		draw_line(base_line[0], top_line[0], WALL_EDGE_COLOR, 1.5)
		draw_line(base_line[base_line.size() - 1], top_line[top_line.size() - 1], WALL_EDGE_COLOR, 1.5)
