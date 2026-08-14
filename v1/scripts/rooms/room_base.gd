# gdlint: disable=max-file-lines
## TODO post-fase-economia: estrarre la gestione mess (reload/offline)
## RoomBase — Manages modular room: decoration spawning and character display.
extends Node2D

const DecorationScript := preload("res://scripts/rooms/decoration_system.gd")
const MessSpawnerScript := preload("res://scripts/systems/mess_spawner.gd")
# Preload (non class_name) per lo stesso motivo documentato in mess_spawner:
# il class_name cache di Godot puo` andare stale.
const MessNodeScript := preload("res://scripts/rooms/mess_node.gd")
const FoodBowlScript := preload("res://scripts/rooms/food_bowl.gd")
const PetScript := preload("res://scripts/rooms/pet_controller.gd")
const SeatAreaScript := preload("res://scripts/rooms/seat_area.gd")

## Collision footprint ratios — only the bottom portion blocks movement.
const COLLISION_WIDTH_RATIO := 0.7
const COLLISION_HEIGHT_RATIO := 0.3
## Interaction area extends slightly beyond collision so character can reach.
const INTERACTION_PADDING := 8.0
## Distance the character is pushed past a decoration edge when nudged away.
const NUDGE_MARGIN := 20.0

## Fallback: la mappa reale id -> scena arriva dal catalogo
## (data/characters.json, campo "scene"), cosi` un personaggio nuovo si
## aggiunge senza toccare il codice.
const CHARACTER_SCENES := {
	"male_old": "res://scenes/male-old-character.tscn",
	"male_rose": "res://scenes/male-rose-character.tscn",
}

## Pet variants. The active one is selected via SaveManager setting "pet_variant"
## (values: "simple" — original 16x16 strip; "iso" — 32x32 isometric strip).
const PET_SCENES := {
	"simple": "res://scenes/cat_void.tscn",
	"iso": "res://scenes/cat_void_iso.tscn",
}
const PET_VARIANT_DEFAULT := "simple"

var mess_container: Node2D
var mess_spawner: Node  # MessSpawner instance (typed Node to avoid class_name cache staleness)
## True once character_node holds a trustworthy position (V-085 / 4.1.8-L280).
## Replaces the old `position != Vector2.ZERO` sentinel that silently
## redirected the pet to viewport centre for a legal (0,0) spawn.
var _character_pos_ready: bool = false

@onready var decorations_container: Node2D = $Decorations
@onready var character_node: Node2D = $Character
@onready var _floor_bounds_node: CollisionPolygon2D = $RoomBounds/FloorBounds


func _ready() -> void:
	SignalBus.character_changed.connect(_on_character_changed)
	SignalBus.decoration_placed.connect(_on_decoration_placed)
	SignalBus.load_completed.connect(_on_load_completed)
	SignalBus.pet_feed_requested.connect(_on_pet_feed_requested)
	SignalBus.pet_pottied.connect(_on_pet_pottied)
	_setup_floor_bounds()
	_reload_decorations()
	# Apply character chosen in main menu BEFORE spawning pet.
	# Pet uses character_node.position — must be valid. Sync call (no defer) evita
	# che female/outro appaia dopo un frame di ritardo e che pet sia spawned
	# su posizione male_old poi lasciato lì. (fix BUG-B-6 + BUG-B-7)
	if GameManager.current_character_id != "male_old":
		_on_character_changed(GameManager.current_character_id)
	# Whatever branch ran, a valid character_node now carries a real position
	# (editor-set for the default scene, swap-set otherwise) — mark it ready.
	if character_node != null and is_instance_valid(character_node):
		_character_pos_ready = true
	_spawn_pet()
	_setup_mess_spawner()
	_reload_messes()


func _setup_floor_bounds() -> void:
	if _floor_bounds_node == null:
		push_warning("RoomBase: FloorBounds node not found at $RoomBounds/FloorBounds")
		return
	Helpers.set_floor_polygon_from_node(_floor_bounds_node)
	# Zone giardino (fase 3): poligoni data-only in main.tscn (disabled=true,
	# nessuna fisica) registrati nel registro zone. clear prima: gli statici
	# di Helpers sopravvivono ai reload di scena.
	Helpers.clear_zones()
	var zones := get_node_or_null("GardenZones")
	if zones != null:
		for child in zones.get_children():
			if child is CollisionPolygon2D:
				Helpers.register_zone_polygon("garden", (child as CollisionPolygon2D).polygon)


func _on_load_completed() -> void:
	_reload_decorations()
	_reload_messes()
	_process_offline_potty()


## Spawna un NUOVO mess (bisogno in stanza, accumulo offline): entry
## persistita + nodo + segnale mess_spawned (che aggiunge lo stress).
func _spawn_new_mess(mess_id: String, pos: Vector2) -> void:
	var catalog_entry := GameManager.get_mess_entry(mess_id)
	if catalog_entry.is_empty():
		AppLogger.warn("RoomBase", "spawn_new_mess_unknown", {"id": mess_id})
		return
	pos = Helpers.clamp_inside_floor(pos, 16.0)
	var persisted := {
		"mess_id": mess_id,
		"position": Helpers.vec2_to_array(pos),
		"spawned_at": Time.get_unix_time_from_system(),
		"cleaning_ends_at": 0.0,
	}
	var before := SaveManager.get_messes().size()
	SaveManager.add_mess(persisted)
	if SaveManager.get_messes().size() == before:
		return  # cap raggiunto: niente nodo orfano
	var mess: Area2D = MessNodeScript.new()
	mess.setup(catalog_entry, pos, persisted)
	mess_container.add_child(mess)
	SignalBus.mess_spawned.emit(mess_id, pos)
	SignalBus.save_requested.emit()


## Bisogno fatto IN STANZA (tempesta): diventa uno sporco pesante dove
## si trova il gatto (fase 3).
func _on_pet_pottied(indoor: bool) -> void:
	if not indoor:
		return
	var pet := get_node_or_null("Pet") as Node2D
	var pos: Vector2 = pet.position if pet != null else Vector2(640, 500)
	_spawn_new_mess("cat_poop", pos)
	SignalBus.toast_requested.emit(tr("TOAST_CAT_POTTY_INDOOR"), "warning")


## Bisogni maturati a gioco chiuso (accumulatore temporale, modulo 12).
## Con mood salvato in tempesta diventano sporchi in stanza; altrimenti il
## gatto se l'e` cavata in giardino e non resta traccia.
func _process_offline_potty() -> void:
	var next := float(SaveManager.pet_data.get("next_potty_at", 0.0))
	var now := Time.get_unix_time_from_system()
	if next <= 0.0:
		return  # primo avvio: lo schedule lo fa il pet controller
	var result: Dictionary = PetScript.accrue_offline_potties(next, now)
	var count := int(result.get("count", 0))
	if count <= 0:
		return
	SaveManager.pet_data["next_potty_at"] = float(result.get("next", 0.0))
	var was_stormy := float(SaveManager.get_setting("mood_level", 1.0)) < Constants.MOOD_STORMY_THRESHOLD
	if was_stormy:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for _i in range(count):
			var offset := Vector2(rng.randf_range(-160.0, 160.0), rng.randf_range(-100.0, 100.0))
			_spawn_new_mess("cat_poop", Vector2(646, 460) + offset)
		SignalBus.toast_requested.emit(tr("TOAST_CAT_POTTY_AWAY") % count, "warning")
	AppLogger.info("RoomBase", "offline_potty", {"count": count, "indoor": was_stormy})
	SignalBus.save_requested.emit()


## Ricostruisce i mess dal salvataggio (spec 2026-08-14). Tre casi per voce:
## id sconosciuto → scartata con warning; pulizia gia` finita (anche a gioco
## chiuso) → coins accreditati subito con toast, mai rispawnata; altrimenti
## → nodo ricreato con posizione clampata nel pavimento. Lo stress dei mess
## ricaricati NON viene ri-aggiunto (e` gia` dentro livello_stress salvato):
## si registra solo la contabilita` per lo scarico alla pulizia.
func _reload_messes() -> void:
	if mess_container == null:
		return
	for child in mess_container.get_children():
		child.queue_free()
	var now := Time.get_unix_time_from_system()
	var offline_coins := 0
	for entry: Dictionary in SaveManager.get_messes().duplicate():
		var mess_id := str(entry.get("mess_id", ""))
		var catalog_entry := GameManager.get_mess_entry(mess_id)
		if catalog_entry.is_empty():
			AppLogger.warn("RoomBase", "saved_mess_unknown", {"id": mess_id})
			SaveManager.remove_mess(entry)
			continue
		var ends := float(entry.get("cleaning_ends_at", 0.0))
		if ends > 0.0 and ends <= now:
			var reward := int(catalog_entry.get("clean_reward", 2))
			offline_coins += reward
			SaveManager.remove_mess(entry)
			SignalBus.mess_cleaned.emit(mess_id)
			continue
		var pos := Helpers.clamp_inside_floor(Helpers.array_to_vec2(entry.get("position", [640, 450])))
		entry["position"] = Helpers.vec2_to_array(pos)
		var mess: Area2D = MessNodeScript.new()
		mess.setup(catalog_entry, pos, entry)
		mess_container.add_child(mess)
		StressManager.track_mess(mess_id, false)
	if offline_coins > 0:
		var total: int = SaveManager.inventory_data.get("coins", 0) + offline_coins
		SaveManager.inventory_data["coins"] = total
		SignalBus.coins_changed.emit(offline_coins, total)
		SignalBus.toast_requested.emit(tr("TOAST_CLEAN_DONE_AWAY") % offline_coins, "info")
		SignalBus.save_requested.emit()


## Percorso scena del personaggio: prima il catalogo (dato), poi la mappa
## di fallback nel codice. Restituisce "" se nessuna delle due ha una scena
## caricabile, cosi` il chiamante puo` segnalare l'errore invece di crashare.
func _resolve_character_scene(character_id: String) -> String:
	for entry in GameManager.characters_catalog.get("characters", []):
		if entry is Dictionary and str(entry.get("id", "")) == character_id:
			var path: String = str(entry.get("scene", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				return path
			break
	var fallback: String = CHARACTER_SCENES.get(character_id, "")
	if not fallback.is_empty() and ResourceLoader.exists(fallback):
		return fallback
	return ""


func _on_character_changed(character_id: String) -> void:
	var scene_path: String = _resolve_character_scene(character_id)
	if scene_path.is_empty():
		push_warning("RoomBase: no scene for character '%s'" % character_id)
		return
	# Idempotency guard: se il character_node attuale e' gia' istanza della
	# scena richiesta, NON re-istanziare. Senza questo guard, il segnale
	# character_changed emesso da game_manager._on_load_completed dopo il
	# save load duplicava il character (si creava un secondo CharacterBody2D
	# alla stessa posizione, le due capsule collidevano, e move_and_slide
	# spingeva uno dei due a circa (608, 448) — invisibile sotto/dietro
	# l'originale. L'utente vedeva un character fermo mentre l'altro
	# rispondeva all'input. Root cause documentata in detail nel log
	# diagnostico del 2026-04-15.
	if character_node != null and is_instance_valid(character_node) and character_node.scene_file_path == scene_path:
		_character_pos_ready = true
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("RoomBase: failed to load scene '%s'" % scene_path)
		return
	# Swap guard (V-044 / 4.1.8-L80): a null or freed character_node must not
	# be dereferenced. Fall back to the default spawn position (same viewport
	# centre used by _spawn_pet) instead of hard-faulting.
	var old_pos := Vector2(640, 360)
	if character_node != null and is_instance_valid(character_node):
		old_pos = character_node.position
		# remove_child PRIMA di add_child: queue_free() e` differito, quindi il
		# vecchio nodo resterebbe figlio con nome "Character" per tutto il
		# frame e Godot rinominerebbe il nuovo in "@CharacterBody2D@N".
		# pet_controller cerca il personaggio per nome: dopo la rinomina si
		# agganciava al nodo in via di distruzione e il gatto non seguiva piu`
		# nessuno per tutta la sessione (regressione emersa col 2o personaggio).
		var old_char := character_node
		remove_child(old_char)
		old_char.queue_free()
	else:
		AppLogger.warn("RoomBase", "character_swap_invalid_node", {"id": character_id})
	var new_char := scene.instantiate()
	new_char.name = "Character"
	new_char.position = old_pos
	# Preserva la scala intrinseca della scena del nuovo personaggio:
	# male_old.tscn usa Vector2(3,3) perche` sprite 32x32, female-character.tscn
	# usa Vector2(4,4) perche` sprite 23x23. Override con old_scale rendeva
	# la female molto piu` piccola del previsto (fix extra BUG-B-6).
	add_child(new_char)
	if new_char.name != "Character":
		# Difesa esplicita: se il nome non e` libero il pet perde il bersaglio
		# in silenzio. Meglio un errore diagnosticabile di un gatto apatico.
		AppLogger.error("RoomBase", "character_name_collision", {"id": character_id, "name": str(new_char.name)})
	character_node = new_char
	_character_pos_ready = true
	AppLogger.info("RoomBase", "character_changed", {"id": character_id, "pos": old_pos, "scale": new_char.scale})


func _on_decoration_placed(item_id: String, pos: Vector2) -> void:
	var item_data := _find_item_data(item_id)
	if item_data.is_empty():
		AppLogger.warn("RoomBase", "decoration_placed_unknown_item", {"item_id": item_id, "pos": pos})
		SignalBus.toast_requested.emit(tr("TOAST_UNKNOWN_DECORATION") % item_id, "error")
		return
	AppLogger.info("RoomBase", "decoration_placed_accepted", {"item_id": item_id, "pos": pos})
	var item_scale: float = item_data.get("item_scale", 1.0)
	var deco_data := {
		"item_id": item_id,
		"position": Helpers.vec2_to_array(pos),
		"item_scale": item_scale,
		"rotation": 0.0,
		"flip_h": false,
		# Phase E: persisted so decoration_system's edit-mode drag keeps wall
		# items on the wall — without it the default "floor" re-clamps every
		# wall decoration into the floor polygon on the first drag.
		"placement_type": item_data.get("placement_type", "floor"),
	}
	# Check if placement would overlap with character and nudge if needed.
	# Only blocking furniture nudges: rugs and wall items never trap anyone.
	var char_pos := character_node.position
	var tex_data := _get_texture_for_id(item_id)
	var blocks := Helpers.placement_type_of(item_data) == "floor" and not Helpers.is_flat(item_data)
	if tex_data != null and blocks:
		var deco_rect := Rect2(pos, tex_data.get_size() * item_scale)
		if deco_rect.has_point(char_pos):
			# Nudge character out of overlap. Each edge candidate is clamped
			# inside the floor polygon (V-084 / 4.1.8-L110) AND re-checked
			# against the rect: for an edge-spanning decoration the clamp can
			# push the target straight back inside the footprint (Phase D).
			character_node.position = _find_nearest_free_position(char_pos, deco_rect)
	SaveManager.add_decoration(deco_data)
	_spawn_decoration(item_id, pos, item_scale, 0.0, false, deco_data)
	SignalBus.save_requested.emit()


func _reload_decorations() -> void:
	for child in decorations_container.get_children():
		child.queue_free()

	for deco_data in SaveManager.get_decorations():
		var item_id: String = deco_data.get("item_id", "")
		var item_data := _find_item_data(item_id)
		if item_data.is_empty():
			push_warning("RoomBase: skipping unknown decoration '%s'" % item_id)
			continue
		if not deco_data.has("placement_type"):
			# Phase E backfill: entries saved before placement_type was
			# persisted inherit the catalog value (in-place: the entry lives
			# inside SaveManager._decorations, so the next save keeps it).
			deco_data["placement_type"] = item_data.get("placement_type", "floor")
		var pos: Array = deco_data.get("position", [0, 0])
		var item_scale: float = deco_data.get("item_scale", 1.0)
		var rot: float = deco_data.get("rotation", 0.0)
		var flipped: bool = deco_data.get("flip_h", false)
		var pos_vec := Helpers.array_to_vec2(pos)
		# One-time heal: saves written while the collision polygon was larger
		# than the visual floor (or while wall items had no constraint at all)
		# carry positions outside the legal zones. Validate at the boundary —
		# a save file is input, not gospel — and write the correction back into
		# the entry (in place, same mechanism as the placement_type backfill)
		# so the next save persists the healed value. Entries already valid
		# pass through unchanged, so healthy saves never drift.
		var healed := _heal_saved_entry(deco_data, item_data, pos_vec, item_scale, rot)
		pos_vec = healed["pos"]
		item_scale = healed["scale"]
		rot = healed["rot"]
		_spawn_decoration(item_id, pos_vec, item_scale, rot, flipped, deco_data)


## Clamp a saved entry back into its legal placement zone, rotation and scale
## range. Mutates deco_data in place when something was actually corrected.
func _heal_saved_entry(
	deco_data: Dictionary, item_data: Dictionary, pos_vec: Vector2, item_scale: float, rot: float
) -> Dictionary:
	var item_id: String = deco_data.get("item_id", "")
	var placement := Helpers.placement_type_of(deco_data)
	if str(deco_data.get("placement_type", "")) != placement:
		# Persist the normalization too (retired "any" values in old saves).
		deco_data["placement_type"] = placement
	var tex := _get_texture_for_id(item_id)
	var size := tex.get_size() * item_scale if tex != null else Vector2.ZERO

	var fixed_pos := pos_vec
	if placement == "wall":
		var center := pos_vec + size * 0.5
		var clamped_center := Helpers.clamp_wall_anchor(center, size * 0.5)
		fixed_pos = clamped_center - size * 0.5
	else:
		var anchor := pos_vec + Vector2(size.x * 0.5, size.y)
		fixed_pos = Helpers.clamp_inside_floor(anchor) - Vector2(size.x * 0.5, size.y)

	var fixed_rot := rot if Helpers.is_rotatable(item_data) else 0.0
	var bounds := Helpers.scale_bounds_of(item_data)
	var base_scale: float = item_data.get("item_scale", 1.0)
	var fixed_scale := clampf(item_scale, base_scale * bounds.x, base_scale * bounds.y)

	if fixed_pos.distance_to(pos_vec) > 1.0 or fixed_rot != rot or not is_equal_approx(fixed_scale, item_scale):
		AppLogger.warn(
			"RoomBase",
			"saved_decoration_healed",
			{
				"item_id": item_id,
				"from": pos_vec,
				"to": fixed_pos,
				"rot": [rot, fixed_rot],
				"scale": [item_scale, fixed_scale]
			}
		)
		deco_data["position"] = Helpers.vec2_to_array(fixed_pos)
		deco_data["rotation"] = fixed_rot
		deco_data["item_scale"] = fixed_scale
	return {"pos": fixed_pos, "scale": fixed_scale, "rot": fixed_rot}


func _spawn_decoration(
	item_id: String,
	pos: Vector2,
	item_scale: float,
	rot: float = 0.0,
	flipped: bool = false,
	deco_data: Dictionary = {}
) -> void:
	var item_data := _find_item_data(item_id)
	if item_data.is_empty():
		AppLogger.warn("RoomBase", "spawn_deco_unknown_item", {"item_id": item_id})
		return
	var sprite_path: String = item_data.get("sprite_path", "")
	if sprite_path.is_empty():
		AppLogger.error("RoomBase", "spawn_deco_no_sprite_path", {"item_id": item_id})
		return

	var texture := load(sprite_path) as Texture2D
	if texture == null:
		AppLogger.error("RoomBase", "spawn_deco_texture_load_fail", {"item_id": item_id, "sprite_path": sprite_path})
		return

	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(item_scale, item_scale)
	sprite.position = pos
	sprite.rotation_degrees = rot
	sprite.flip_h = flipped
	sprite.name = item_id

	if DecorationScript:
		sprite.set_script(DecorationScript)
		sprite.item_id = item_id
		# Phase E: the scale-step base is ALWAYS the catalog scale, never the
		# saved absolute scale — rebasing on the saved value made the S-button
		# ladder compound across sessions (3.0 -> 4.5 -> ... unbounded).
		sprite.base_item_scale = item_data.get("item_scale", 1.0)
		sprite.deco_data = deco_data
		sprite.catalog_data = item_data

	# --- Draw order: wall band < flat (rugs) < everything standing by foot-y.
	var placement := Helpers.placement_type_of(item_data)
	var tex_size := texture.get_size()
	if placement == "wall":
		sprite.z_index = Helpers.Z_WALL
	elif Helpers.is_flat(item_data):
		sprite.z_index = Helpers.Z_FLAT
	else:
		sprite.z_index = Helpers.z_for_foot_y(pos.y + tex_size.y * item_scale)

	# --- Collision: footprint-based (bottom portion only) ---
	# Only STANDING floor furniture blocks movement. Wall items hang above the
	# floor (their old footprint body was an invisible wall in the middle of
	# the room) and flat items (rugs) are walked over by definition.
	var foot_w := tex_size.x * COLLISION_WIDTH_RATIO
	var foot_h := tex_size.y * COLLISION_HEIGHT_RATIO
	var blocks_movement := placement == "floor" and not Helpers.is_flat(item_data)
	if blocks_movement:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(foot_w, foot_h)
		# Position at bottom-center of the texture (sprites are non-centered)
		shape.shape = rect
		shape.position = Vector2(tex_size.x * 0.5, tex_size.y - foot_h * 0.5)
		body.add_child(shape)
		sprite.add_child(body)

	# --- Seduta (fase 5): le sedie espongono un'area sul layer interagibili
	# che delega a sit_on() del personaggio. ---
	if bool(item_data.get("sittable", false)):
		var seat_area: Area2D = SeatAreaScript.new()
		seat_area.seat = sprite
		seat_area.collision_layer = 4
		seat_area.collision_mask = 0
		seat_area.monitorable = true
		seat_area.monitoring = false
		var seat_shape := CollisionShape2D.new()
		var seat_rect := RectangleShape2D.new()
		seat_rect.size = tex_size + Vector2.ONE * INTERACTION_PADDING * 2.0
		seat_shape.shape = seat_rect
		seat_shape.position = tex_size * 0.5
		seat_area.add_child(seat_shape)
		sprite.add_child(seat_area)

	# --- Interaction Area2D for interactable furniture ---
	var interaction_type: String = item_data.get("interaction_type", "")
	if not interaction_type.is_empty() and blocks_movement:
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1  # Detect character (layer 1)
		area.monitoring = true
		area.monitorable = false
		area.set_meta("interaction_type", interaction_type)
		area.set_meta("item_id", item_id)
		var area_shape := CollisionShape2D.new()
		var area_rect := RectangleShape2D.new()
		# Interaction zone slightly larger than collision footprint
		area_rect.size = Vector2(foot_w + INTERACTION_PADDING * 2.0, foot_h + INTERACTION_PADDING * 2.0)
		area_shape.shape = area_rect
		area_shape.position = Vector2(tex_size.x * 0.5, tex_size.y - foot_h * 0.5)
		area.add_child(area_shape)
		area.body_entered.connect(_on_interaction_body_entered.bind(area))
		area.body_exited.connect(_on_interaction_body_exited.bind(area))
		sprite.add_child(area)

	decorations_container.add_child(sprite)


func _on_interaction_body_entered(body: Node2D, area: Area2D) -> void:
	if body is CharacterBody2D:
		var itype: String = area.get_meta("interaction_type", "")
		var iid: String = area.get_meta("item_id", "")
		SignalBus.interaction_available.emit(iid, itype)


func _on_interaction_body_exited(body: Node2D, _area: Area2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_unavailable.emit()


## Returns a position outside `blocked` AND inside the floor polygon, trying
## the four edge exits nearest-first. A candidate that the floor clamp pushes
## back inside the rect is discarded (Phase D: an edge-spanning decoration
## made the old single-candidate clamp re-embed the character in the new
## collider). Falls back toward the floor centre, then to the floor-clamped
## original position (physics resolves the residual overlap).
func _find_nearest_free_position(char_pos: Vector2, blocked: Rect2) -> Vector2:
	var cx: float = clampf(char_pos.x, blocked.position.x, blocked.end.x)
	var cy: float = clampf(char_pos.y, blocked.position.y, blocked.end.y)
	var candidates: Array[Vector2] = [
		Vector2(blocked.position.x - NUDGE_MARGIN, char_pos.y),
		Vector2(blocked.end.x + NUDGE_MARGIN, char_pos.y),
		Vector2(char_pos.x, blocked.position.y - NUDGE_MARGIN),
		Vector2(char_pos.x, blocked.end.y + NUDGE_MARGIN),
	]
	var distances: Array[float] = [
		absf(cx - blocked.position.x),
		absf(cx - blocked.end.x),
		absf(cy - blocked.position.y),
		absf(cy - blocked.end.y),
	]
	var order: Array = [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return distances[a] < distances[b])
	for idx: int in order:
		var clamped: Vector2 = Helpers.clamp_inside_floor(candidates[idx])
		if not blocked.has_point(clamped):
			return clamped
	var floor_bounds: Rect2 = Helpers.get_floor_bounds()
	if floor_bounds.has_area():
		var centre: Vector2 = Helpers.clamp_inside_floor(floor_bounds.get_center())
		if not blocked.has_point(centre):
			return centre
	return Helpers.clamp_inside_floor(char_pos)


func _get_texture_for_id(item_id: String) -> Texture2D:
	var item_data := _find_item_data(item_id)
	var path: String = item_data.get("sprite_path", "")
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _setup_mess_spawner() -> void:
	mess_container = Node2D.new()
	mess_container.name = "Mess"
	add_child(mess_container)

	mess_spawner = MessSpawnerScript.new()
	mess_spawner.name = "MessSpawner"
	add_child(mess_spawner)
	mess_spawner.set_container(mess_container)


func _spawn_pet() -> void:
	var variant: String = SaveManager.get_setting("pet_variant", PET_VARIANT_DEFAULT)
	var scene_path: String = PET_SCENES.get(variant, PET_SCENES[PET_VARIANT_DEFAULT])
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("RoomBase: pet scene not found (%s)" % scene_path)
		AppLogger.error("RoomBase", "pet_scene_missing", {"path": scene_path, "variant": variant})
		return
	var pet := scene.instantiate()
	pet.name = "Pet"
	# Spawn near the character. Readiness flag instead of the Vector2.ZERO
	# sentinel (V-085 / 4.1.8-L280): a legal (0,0) character spawn is trusted;
	# only a null/invalid/not-yet-ready character falls back to viewport
	# centre (fix BUG-B-7).
	var char_pos: Vector2 = Vector2(640, 360)  # viewport centre 1280x720
	if _character_pos_ready and character_node != null and is_instance_valid(character_node):
		char_pos = character_node.position
	# The fixed offset can land outside the floor polygon when the character
	# sits near an edge: clamp the spawn like every other placement.
	pet.position = Helpers.clamp_inside_floor(Vector2(char_pos.x + 60.0, char_pos.y + 20.0), 24.0)
	add_child(pet)
	AppLogger.info("RoomBase", "pet_spawned", {"variant": variant, "pos": pet.position})


## Posa la ciotola per il gatto (spec 2026-08-14). Una sola alla volta: la
## porzione e` gia` stata scalata dall'inventario dal pannello negozio, quindi
## il rifiuto qui restituisce... niente — per questo il pannello controlla
## PRIMA se una ciotola esiste (get_tree().get_nodes_in_group("pet_bowl")).
func _on_pet_feed_requested(world_position: Vector2) -> void:
	if not get_tree().get_nodes_in_group("pet_bowl").is_empty():
		SignalBus.toast_requested.emit(tr("TOAST_BOWL_ALREADY"), "warning")
		return
	# Vector2.INF (o comunque non finito) = "davanti al personaggio".
	if not world_position.is_finite():
		var char_pos := Vector2(640, 450)
		if character_node != null and is_instance_valid(character_node):
			char_pos = character_node.position
		world_position = char_pos + Vector2(46, 30)
	var bowl: Node2D = FoodBowlScript.new()
	bowl.position = Helpers.clamp_inside_floor(world_position, 24.0)
	bowl.z_index = Helpers.z_for_foot_y(bowl.position.y)
	add_child(bowl)
	AppLogger.info("RoomBase", "bowl_placed", {"pos": bowl.position})


func _exit_tree() -> void:
	if SignalBus.character_changed.is_connected(_on_character_changed):
		SignalBus.character_changed.disconnect(_on_character_changed)
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
	if SignalBus.pet_feed_requested.is_connected(_on_pet_feed_requested):
		SignalBus.pet_feed_requested.disconnect(_on_pet_feed_requested)
	if SignalBus.pet_pottied.is_connected(_on_pet_pottied):
		SignalBus.pet_pottied.disconnect(_on_pet_pottied)


func _find_item_data(item_id: String) -> Dictionary:
	var catalog: Dictionary = GameManager.decorations_catalog
	for deco in catalog.get("decorations", []):
		if deco is Dictionary and deco.get("id", "") == item_id:
			return deco
	return {}
