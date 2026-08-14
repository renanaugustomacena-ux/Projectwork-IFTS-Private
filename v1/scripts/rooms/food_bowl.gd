## FoodBowl — ciotola di croccantini transitoria (spec 2026-08-14).
## Posata da room_base su pet_feed_requested; il gatto (stato EAT) la
## raggiunge, mangia e la libera. Non persistita: la porzione e` gia` stata
## scalata dall'inventario al momento della richiesta.
extends Node2D

const BOWL_SIZE := Vector2i(26, 14)


func _ready() -> void:
	add_to_group("pet_bowl")
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _make_bowl_texture()
	add_child(sprite)


## Placeholder disegnato a runtime (stesso approccio dei mess): ciotola
## marrone con croccantini, in attesa di arte dedicata.
func _make_bowl_texture() -> ImageTexture:
	var w := BOWL_SIZE.x
	var h := BOWL_SIZE.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bowl := Color("#8a5a3a")
	var rim := bowl.darkened(0.35)
	var kibble := Color("#c9a15f")
	var cx := w * 0.5
	var cy := h * 0.62
	for y in range(h):
		for x in range(w):
			var dx := (x - cx) / (w * 0.5)
			var dy := (y - cy) / (h * 0.48)
			var d := dx * dx + dy * dy
			if d <= 0.75:
				img.set_pixel(x, y, bowl)
			elif d <= 1.0:
				img.set_pixel(x, y, rim)
	for k in [[9, 4], [13, 3], [16, 4], [11, 5], [15, 5]]:
		if k[0] < w and k[1] < h:
			img.set_pixel(k[0], k[1], kibble)
	return ImageTexture.create_from_image(img)
