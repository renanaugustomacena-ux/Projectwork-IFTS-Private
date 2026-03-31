## WindowBackground — Parallax forest view behind the wall zone.
## Responds to mouse position for subtle depth movement.
extends Node2D

const PARALLAX_STRENGTH := 8.0
const LAYER_BASE_PATH := "res://assets/backgrounds/Free Pixel Art Forest/PNG/Background layers/"
const SCALE_FACTOR := 1.38  # 1280 / 928 to fill viewport width

var _layers: Array[Sprite2D] = []
var _parallax_factors: Array[float] = []


func _ready() -> void:
	_build_layers()


func _process(_delta: float) -> void:
	_update_parallax()


func _build_layers() -> void:
	var layer_files: Array[String] = [
		"Layer_0011_0.png",
		"Layer_0010_1.png",
		"Layer_0009_2.png",
		"Layer_0008_3.png",
		"Layer_0006_4.png",
		"Layer_0005_5.png",
		"Layer_0003_6.png",
		"Layer_0000_9.png",
	]

	# First pass: collect only valid textures (skip missing files entirely)
	var valid_textures: Array[Texture2D] = []
	for file_name in layer_files:
		var path := LAYER_BASE_PATH + file_name
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("WindowBackground: layer mancante, saltato: %s" % path)
			continue
		valid_textures.append(tex)

	# Second pass: create sprites with correctly aligned parallax factors
	var valid_count := valid_textures.size()
	for i in valid_count:
		var sprite := Sprite2D.new()
		sprite.texture = valid_textures[i]
		sprite.centered = false
		sprite.scale = Vector2(SCALE_FACTOR, SCALE_FACTOR)
		sprite.position.y = -505.0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers.append(sprite)
		_parallax_factors.append(float(i) / float(valid_count))


func _update_parallax() -> void:
	if _layers.is_empty():
		return

	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var mouse := get_viewport().get_mouse_position()
	var center := vp_size * 0.5
	var offset := (mouse - center) / center

	for i in _layers.size():
		var shift := offset * PARALLAX_STRENGTH * _parallax_factors[i]
		_layers[i].position.x = -shift.x
