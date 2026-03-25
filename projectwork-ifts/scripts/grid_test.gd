extends StaticBody2D



# ----------------------------
# SETTINGS
# ----------------------------

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var cell_size: Vector2 = Vector2(16, 8)

@export var show_grid: bool = true
@export var preview_size: Vector2i = Vector2i(1, 1)

# ----------------------------
# INTERNAL DATA
# ----------------------------

var grid = []
var hover_cell: Vector2i = Vector2i(-1, -1)
var flipped: bool = false  # flips the decoration horizontally

var preview_sprite: Sprite2D = null
var item_texture: Texture2D = preload("res://assets/room/door.png")


# ----------------------------
# INIT
# ----------------------------

func _ready():
	_create_grid()
	_create_preview_sprite()

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	hover_cell = world_to_grid(mouse_pos)
	_update_preview_sprite()
	queue_redraw()

# ----------------------------
# GRID SETUP
# ----------------------------

func _create_grid():
	grid.clear()
	for x in range(grid_width):
		grid.append([])
		for y in range(grid_height):
			grid[x].append(null)

# ----------------------------
# GRID <-> WORLD
# ----------------------------

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * (cell_size.x / 2)
	var y = (grid_pos.x + grid_pos.y) * (cell_size.y / 2)
	return Vector2(x, y)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var x = (world_pos.x / (cell_size.x / 2) + world_pos.y / (cell_size.y / 2)) / 2
	var y = (world_pos.y / (cell_size.y / 2) - world_pos.x / (cell_size.x / 2)) / 2
	return Vector2i(floor(x), floor(y))

# ----------------------------
# PLACEMENT LOGIC
# ----------------------------

func can_place(grid_pos: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in range(size.x):
		for y in range(size.y):
			var gx = grid_pos.x + x
			var gy = grid_pos.y + y

			if gx < 0 or gy < 0 or gx >= grid_width or gy >= grid_height:
				return false

			if grid[gx][gy] != null:
				return false

	return true

func place_item(grid_pos: Vector2i, item: Node2D, size: Vector2i = Vector2i(1,1)) -> bool:
	if not can_place(grid_pos, size):
		return false

	for x in range(size.x):
		for y in range(size.y):
			grid[grid_pos.x + x][grid_pos.y + y] = item

	item.position = grid_to_world(grid_pos)
	item.z_index = grid_pos.x + grid_pos.y
	add_child(item)

	queue_redraw()
	return true

func remove_item(grid_pos: Vector2i, size: Vector2i = Vector2i(1,1)):
	var item = grid[grid_pos.x][grid_pos.y]

	for x in range(size.x):
		for y in range(size.y):
			grid[grid_pos.x + x][grid_pos.y + y] = null

	if item:
		item.queue_free()

	queue_redraw()

# ----------------------------
# PREVIEW SPRITE
# ----------------------------

func _create_preview_sprite():
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = item_texture
	preview_sprite.modulate = Color(1, 1, 1, 0.5)
	preview_sprite.z_index = 1000
	add_child(preview_sprite)

func _update_preview_sprite():
	if hover_cell.x < 0 or hover_cell.y < 0:
		preview_sprite.visible = false
		return

	var valid = can_place(hover_cell, preview_size)

	preview_sprite.visible = true
	preview_sprite.position = grid_to_world(hover_cell)
	preview_sprite.flip_h = flipped

	if valid:
		preview_sprite.modulate = Color(1, 1, 1, 0.5)
	else:
		preview_sprite.modulate = Color(1, 0.3, 0.3, 0.5)

# ----------------------------
# ROTATION
# ----------------------------

func flip_preview():
	flipped = !flipped
	queue_redraw()

# ----------------------------
# INPUT (CLICK TO PLACE / R TO ROTATE)
# ----------------------------

func _input(event):
	# R key to flip
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		flip_preview()

	# Click to place
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_place(hover_cell, preview_size):
			var item = Sprite2D.new()
			item.texture = item_texture
			item.flip_h = flipped
			place_item(hover_cell, item, preview_size)

# ----------------------------
# DRAWING
# ----------------------------

func _draw():
	if not show_grid:
		return

	# draw base grid
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			var world_pos = grid_to_world(pos)

			var color = Color(0, 1, 0, 0.15)

			if grid[x][y] != null:
				color = Color(1, 0, 0, 0.25)

			draw_diamond(world_pos, color)
			draw_diamond_outline(world_pos, Color(0, 0, 0, 0.4))

	# draw placement preview
	draw_preview()

# ----------------------------
# PREVIEW (GREEN / RED)
# ----------------------------

func draw_preview():
	if hover_cell.x < 0 or hover_cell.y < 0:
		return

	var valid = can_place(hover_cell, preview_size)

	var color = Color(0, 1, 0, 0.4)
	if not valid:
		color = Color(1, 0, 0, 0.4)

	for x in range(preview_size.x):
		for y in range(preview_size.y):
			var cell = hover_cell + Vector2i(x, y)
			var world_pos = grid_to_world(cell)

			draw_diamond(world_pos, color)
			draw_diamond_outline(world_pos, Color(0, 0, 0, 0.8))

# ----------------------------
# DRAW HELPERS
# ----------------------------

func draw_diamond(center: Vector2, color: Color):
	var hw = cell_size.x / 2
	var hh = cell_size.y / 2

	var points = [
		center + Vector2(0, -hh),
		center + Vector2(hw, 0),
		center + Vector2(0, hh),
		center + Vector2(-hw, 0)
	]

	draw_polygon(points, [color])

func draw_diamond_outline(center: Vector2, color: Color):
	var hw = cell_size.x / 2
	var hh = cell_size.y / 2

	var points = [
		center + Vector2(0, -hh),
		center + Vector2(hw, 0),
		center + Vector2(0, hh),
		center + Vector2(-hw, 0),
		center + Vector2(0, -hh)
	]

	draw_polyline(points, color, 1.5)
