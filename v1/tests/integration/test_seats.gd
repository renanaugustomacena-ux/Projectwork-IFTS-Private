## test_seats — sedersi e guidare le sedie con rotelle (fase 5).
extends "res://tests/integration/test_base.gd"

const CHAR_SCENE := "res://scenes/male-old-character.tscn"
const SeatAreaScript := preload("res://scripts/rooms/seat_area.gd")

var _room: Node2D = null
var _char: CharacterBody2D = null
var _chair: Sprite2D = null


func _build(rideable: bool) -> void:
	_teardown()
	_room = Node2D.new()
	add_child(_room)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(646, 263), Vector2(974, 434), Vector2(646, 606), Vector2(319, 434)])
	_room.add_child(poly)
	Helpers.set_floor_polygon_from_node(poly)

	_chair = Sprite2D.new()
	_chair.centered = false
	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.4, 0.3))
	_chair.texture = ImageTexture.create_from_image(img)
	_chair.scale = Vector2(2, 2)
	_chair.position = Vector2(600, 400)
	_chair.set_meta("test_chair", true)
	# Contratto del catalogo: il controller legge catalog_data/deco_data.
	_chair.set("catalog_data", {})  # sovrascritto sotto se lo script lo espone
	_room.add_child(_chair)

	_char = (load(CHAR_SCENE) as PackedScene).instantiate() as CharacterBody2D
	_char.position = Vector2(646, 480)
	_room.add_child(_char)
	# Il vero spawner assegna catalog/deco data allo script decorazione; qui
	# la sedia e` uno Sprite2D nudo, quindi passiamo i dati via metadata e
	# usiamo l'API pubblica sit_on con un wrapper minimo.
	_chair.set_script(preload("res://scripts/rooms/decoration_system.gd"))
	_chair.catalog_data = {"sittable": true, "rideable": rideable}
	_chair.deco_data = {"item_id": "test_chair", "position": [600, 400]}


func _teardown() -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)
	if _room != null and is_instance_valid(_room):
		_room.queue_free()
	_room = null
	_char = null
	_chair = null


func test_sit_snaps_to_seat_anchor() -> void:
	await _build(false)
	await wait_frames(2)
	_char.sit_on(_chair)
	await wait_frames(2)
	var tex_size: Vector2 = _chair.texture.get_size() * _chair.scale
	var anchor: Vector2 = _chair.global_position + Vector2(tex_size.x * 0.5, tex_size.y * 0.62)
	var foot: Vector2 = _char.global_position + _char._foot_offset
	assert_true(foot.distance_to(anchor) < 1.0, "piedi sul punto-seduta (dist %f)" % foot.distance_to(anchor))
	assert_eq(_char.collision_mask, 1, "da seduti niente collisione con la propria sedia")
	_char.stand_up()
	await wait_frames(2)
	_teardown()
	await wait_frames(1)


func test_moving_on_plain_chair_stands_up() -> void:
	await _build(false)
	await wait_frames(2)
	_char.sit_on(_chair)
	await wait_frames(2)
	Input.action_press("ui_down", 1.0)
	for _i in range(8):
		await get_tree().physics_frame
	Input.action_release("ui_down")
	assert_null(_char._seat, "sedia normale: il movimento fa alzare")
	assert_eq(_char.collision_mask, 3, "in piedi le collisioni tornano complete")
	_teardown()
	await wait_frames(1)


func test_riding_wheeled_chair_drags_it_along() -> void:
	await _build(true)
	await wait_frames(2)
	_char.sit_on(_chair)
	await wait_frames(2)
	var chair_x_before: float = _chair.global_position.x
	Input.action_press("ui_right", 1.0)
	for _i in range(30):
		await get_tree().physics_frame
	Input.action_release("ui_right")
	assert_non_null(_char._seat, "sulla sedia con rotelle si resta seduti")
	assert_true(
		_chair.global_position.x > chair_x_before + 20.0,
		"la sedia viaggia col personaggio (dx %f)" % (_chair.global_position.x - chair_x_before)
	)
	_char.stand_up()
	await wait_frames(2)
	var saved: Array = _chair.deco_data.get("position", [0, 0])
	assert_approx(float(saved[0]), _chair.position.x, 0.6, "posizione della sedia persistita allo smontaggio")
	_teardown()
	await wait_frames(1)
