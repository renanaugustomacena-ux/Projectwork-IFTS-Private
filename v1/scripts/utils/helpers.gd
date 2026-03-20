## Helpers — Utility functions used across the project.
class_name Helpers


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
