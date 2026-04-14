## MessNode — Oggetto sporco che si accumula sul pavimento della stanza.
##
## Viene istanziato dal MessSpawner su una posizione casuale dentro il floor
## polygon. Il personaggio ripulisce il mess avvicinandosi e premendo E
## (sistema interact esistente). Alla pulizia emette mess_cleaned e reward
## coin, poi si distrugge.
class_name MessNode
extends Area2D

## Padding extra intorno allo sprite per rendere piu` permissiva l'interazione.
const INTERACTION_PADDING: float = 6.0

## Coin reward di default per pulire un mess (se non override dal catalog).
const DEFAULT_CLEAN_REWARD: int = 2

var mess_id: String = ""
var stress_weight: float = 0.10
var clean_reward: int = DEFAULT_CLEAN_REWARD

var _sprite: Sprite2D


func setup(entry: Dictionary, world_position: Vector2) -> void:
	mess_id = entry.get("id", "")
	stress_weight = float(entry.get("stress_weight", 0.10))
	clean_reward = int(entry.get("clean_reward", DEFAULT_CLEAN_REWARD))
	position = world_position
	name = "Mess_%s" % mess_id

	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _resolve_texture(entry)
	add_child(_sprite)

	collision_layer = 0
	collision_mask = 1  # Detects character on layer 1
	monitoring = true
	monitorable = false
	set_meta("interaction_type", "clean")
	set_meta("item_id", mess_id)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex := _sprite.texture
	var tex_size: Vector2 = tex.get_size() if tex else Vector2(32, 32)
	rect.size = tex_size + Vector2.ONE * INTERACTION_PADDING * 2.0
	shape.shape = rect
	add_child(shape)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Invocata dal sistema di interazione esistente (room_base / character)
## quando il giocatore preme E vicino al mess.
func on_interact(_player: Node) -> void:
	clean()


func clean() -> void:
	SignalBus.mess_cleaned.emit(mess_id)
	SignalBus.coins_changed.emit(clean_reward, SaveManager.inventory_data.get("coins", 0) + clean_reward)
	SaveManager.inventory_data["coins"] = SaveManager.inventory_data.get("coins", 0) + clean_reward
	SignalBus.save_requested.emit()
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_available.emit(mess_id, "clean")


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_unavailable.emit()


func _resolve_texture(entry: Dictionary) -> Texture2D:
	var path: String = entry.get("sprite_path", "")
	if not path.is_empty():
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D

	# Placeholder runtime: disegna un cerchio pieno con outline scuro nel colore
	# del catalog. Serve come segnaposto finche` l'arte originale non viene
	# disegnata e l'entry non riceve un sprite_path valido.
	var size: int = int(entry.get("size_px", 32))
	size = clampi(size, 12, 96)
	var color_hex: String = entry.get("placeholder_color", "#b8a892")
	return _make_placeholder_texture(size, Color(color_hex))


func _make_placeholder_texture(size: int, fill: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var radius: float = float(size) * 0.5 - 1.0
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var outline := fill.darkened(0.45)
	for y in range(size):
		for x in range(size):
			var dist := center.distance_to(Vector2(x, y))
			if dist <= radius - 1.5:
				img.set_pixel(x, y, fill)
			elif dist <= radius:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)
