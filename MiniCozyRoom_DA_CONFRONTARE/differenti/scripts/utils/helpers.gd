## Helpers — Utility functions used across the project.
class_name Helpers


# ----------------------------------------------------------------------------
# Floor polygon (single source of truth for the playable room area)
# ----------------------------------------------------------------------------
#
# The room floor is an iso-projected quadrilateral, not a rectangle. Clamping
# anything (player movement, decoration drop, decoration drag) against the
# viewport rect produces visual bugs (objects placed outside the visible
# floor, player walking off the room).
#
# RoomBase reads its `RoomBounds/FloorBounds` CollisionPolygon2D node at
# _ready and calls `Helpers.set_floor_polygon_from_node()`. This stores the
# polygon transformed into world coordinates. Any system that needs to
# validate or clamp a position calls `Helpers.is_inside_floor(world_pos)` or
# `Helpers.clamp_inside_floor(world_pos)`.
#
# All coordinates are world (== viewport, since the project has no Camera2D).

static var _floor_polygon_world: PackedVector2Array = PackedVector2Array()
static var _floor_centroid_world: Vector2 = Vector2.ZERO


## Convert a Vector2 to an Array for JSON serialization.
static func vec2_to_array(v: Vector2) -> Array:
	return [v.x, v.y]


## Convert an Array [x, y] back to Vector2.
static func array_to_vec2(arr: Array) -> Vector2:
	if arr.size() < 2:
		push_warning("Helpers: array_to_vec2 received array with size %d" % arr.size())
		return Vector2.ZERO
	return Vector2(float(arr[0]), float(arr[1]))


## Clamp a Vector2 position within viewport bounds.
##
## DEPRECATED for room placement: use `clamp_inside_floor` instead — the
## viewport rect is much larger than the visible iso floor, so this clamp
## happily lets decorations and the player land outside the playable area.
## Kept around for fullscreen UI use cases that genuinely want viewport space.
static func clamp_to_viewport(
	pos: Vector2,
	margin: float = 0.0,
	viewport_size: Vector2 = Vector2(Constants.VIEWPORT_WIDTH, Constants.VIEWPORT_HEIGHT),
) -> Vector2:
	return Vector2(
		clampf(pos.x, margin, viewport_size.x - margin),
		clampf(pos.y, margin, viewport_size.y - margin),
	)


## Format seconds into MM:SS string for timer display.
static func format_time(total_seconds: int) -> String:
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


## Snap a position to the nearest grid cell.
static func snap_to_grid(pos: Vector2, cell_size: int = 64) -> Vector2:
	return Vector2(
		roundf(pos.x / cell_size) * cell_size,
		roundf(pos.y / cell_size) * cell_size,
	)


## Get current date as ISO string (YYYY-MM-DD).
static func get_date_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


# ----------------------------------------------------------------------------
# Floor polygon API
# ----------------------------------------------------------------------------


## Capture the floor polygon from a CollisionPolygon2D node, transformed
## into world coordinates so subsequent queries are space-agnostic.
static func set_floor_polygon_from_node(node: CollisionPolygon2D) -> void:
	if node == null:
		push_warning("Helpers.set_floor_polygon_from_node: node is null")
		_floor_polygon_world = PackedVector2Array()
		return

	var local_poly: PackedVector2Array = node.polygon
	if local_poly.size() < 3:
		push_warning(
			"Helpers.set_floor_polygon_from_node: polygon has %d vertices (need >= 3)"
			% local_poly.size()
		)
		_floor_polygon_world = PackedVector2Array()
		return

	var xform: Transform2D = node.global_transform
	var transformed := PackedVector2Array()
	transformed.resize(local_poly.size())
	for i in local_poly.size():
		transformed[i] = xform * local_poly[i]
	_floor_polygon_world = transformed
	_floor_centroid_world = _polygon_centroid(transformed)


## True if the floor polygon has been initialized.
static func has_floor_polygon() -> bool:
	return _floor_polygon_world.size() >= 3


## True if `world_pos` lies inside the floor polygon.
## Returns true (permissive) if the polygon hasn't been initialized — this
## prevents the game from soft-locking if RoomBase failed to wire the polygon.
static func is_inside_floor(world_pos: Vector2) -> bool:
	if not has_floor_polygon():
		return true
	return Geometry2D.is_point_in_polygon(world_pos, _floor_polygon_world)


## Return `world_pos` if it's inside the floor, otherwise the closest point on
## the polygon edge, nudged `margin` pixels toward the centroid so the result
## is strictly inside (avoids `is_point_in_polygon` boundary edge cases —
## see godotengine/godot#81042).
static func clamp_inside_floor(world_pos: Vector2, margin: float = 4.0) -> Vector2:
	if not has_floor_polygon():
		return world_pos
	if Geometry2D.is_point_in_polygon(world_pos, _floor_polygon_world):
		return world_pos

	var best := world_pos
	var best_dist_sq := INF
	var n := _floor_polygon_world.size()
	for i in n:
		var a := _floor_polygon_world[i]
		var b := _floor_polygon_world[(i + 1) % n]
		var p := Geometry2D.get_closest_point_to_segment(world_pos, a, b)
		var d := world_pos.distance_squared_to(p)
		if d < best_dist_sq:
			best_dist_sq = d
			best = p

	# Nudge `margin` pixels toward the centroid so the point is strictly inside
	var to_center := _floor_centroid_world - best
	if to_center.length_squared() > 0.0001:
		best += to_center.normalized() * margin
	return best


## Expose the polygon for debug overlays / tests. Empty if not initialized.
static func get_floor_polygon_world() -> PackedVector2Array:
	return _floor_polygon_world


static func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())
