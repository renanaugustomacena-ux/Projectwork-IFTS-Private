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
#
# The two polygon edges adjacent to the topmost vertex are also the BASE of the
# two visible wall faces (the room art is a parallelepiped: walls rise straight
# up from those edges for WALL_BAND_HEIGHT px, measured on room.png at display
# scale). Wall-item placement clamps against this band, so wall geometry has
# the same single source of truth as the floor.

## Height of the visible wall faces above their base edge, in world px.
## Measured on room.png (259 px at the 1280/2528 display scale) minus a small
## margin so items never poke over the top edge of the wall.
const WALL_BAND_HEIGHT := 250.0

## Draw-order bands (z_index). Wall items sit behind everything; flat items
## (rugs) lie just above the walls; every standing entity — furniture,
## character, pet, mess — sorts by the y of its ground contact point.
const Z_WALL := 0
const Z_FLAT := 1
const Z_FOOT_MIN := 2

static var _floor_polygon_world: PackedVector2Array = PackedVector2Array()
static var _floor_centroid_world: Vector2 = Vector2.ZERO
# Wall base edges: left edge runs _wall_left..._wall_top, right edge
# _wall_top..._wall_right (world coords, derived from the floor polygon).
static var _wall_top: Vector2 = Vector2.ZERO
static var _wall_left: Vector2 = Vector2.ZERO
static var _wall_right: Vector2 = Vector2.ZERO
static var _wall_ready: bool = false
# placement_type values already warned about (warn once per unknown value).
static var _warned_placements: Dictionary = {}
# Zone nominate (fase giardino): name → Array[PackedVector2Array]. Il gatto
# in ROAM_GARDEN naviga clampato all'unione pavimento+zona.
static var _zones: Dictionary = {}


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
		push_warning("Helpers.set_floor_polygon_from_node: polygon has %d vertices (need >= 3)" % local_poly.size())
		_floor_polygon_world = PackedVector2Array()
		return

	var xform: Transform2D = node.global_transform
	var transformed := PackedVector2Array()
	transformed.resize(local_poly.size())
	for i in local_poly.size():
		transformed[i] = xform * local_poly[i]
	_floor_polygon_world = transformed
	_floor_centroid_world = _polygon_centroid(transformed)
	_derive_wall_edges(transformed)
	AppLogger.info(
		"Helpers", "floor_polygon_initialized", {"vertices": transformed.size(), "centroid": _floor_centroid_world}
	)


## The wall base edges are the two polygon edges adjacent to the topmost
## vertex. Works for any convex room polygon whose "back" is its top corner.
static func _derive_wall_edges(poly: PackedVector2Array) -> void:
	_wall_ready = false
	var n := poly.size()
	if n < 3:
		return
	var top_idx := 0
	for i in n:
		if poly[i].y < poly[top_idx].y:
			top_idx = i
	_wall_top = poly[top_idx]
	var prev := poly[(top_idx - 1 + n) % n]
	var next := poly[(top_idx + 1) % n]
	_wall_left = prev if prev.x < next.x else next
	_wall_right = next if prev.x < next.x else prev
	_wall_ready = _wall_left.x < _wall_top.x and _wall_top.x < _wall_right.x
	if not _wall_ready:
		push_warning("Helpers: cannot derive wall edges from floor polygon")


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
	# Stesso nucleo delle zone (review 2026-08-14: prima il loop era duplicato
	# e un fix al boundary edge-case sarebbe finito in una copia sola).
	return _closest_point_inside(_floor_polygon_world, world_pos, margin)


## Expose the polygon for debug overlays / tests. Empty if not initialized.
static func get_floor_polygon_world() -> PackedVector2Array:
	return _floor_polygon_world


## Bounding box (Rect2) del floor polygon in world coordinates. Rect2() vuoto
## se il polygon non e` stato inizializzato.
static func get_floor_bounds() -> Rect2:
	if _floor_polygon_world.size() < 3:
		return Rect2()
	var bounds := Rect2(_floor_polygon_world[0], Vector2.ZERO)
	for i in range(1, _floor_polygon_world.size()):
		bounds = bounds.expand(_floor_polygon_world[i])
	return bounds


static func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())


# ----------------------------------------------------------------------------
# Named zones (fase giardino, spec 2026-08-14)
#
# Una zona e` un insieme di poligoni world-space con un nome ("garden").
# Il gatto in ROAM_GARDEN naviga clampato all'UNIONE pavimento+zona, cosi`
# puo` attraversare il bordo stanza→piazzale senza geometrie speciali.
# ----------------------------------------------------------------------------


static func clear_zones() -> void:
	_zones.clear()


static func register_zone_polygon(zone_name: String, poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		push_warning("Helpers.register_zone_polygon: polygon needs >= 3 vertices")
		return
	if not _zones.has(zone_name):
		_zones[zone_name] = []
	(_zones[zone_name] as Array).append(poly)


static func has_zone(zone_name: String) -> bool:
	return _zones.has(zone_name) and not (_zones[zone_name] as Array).is_empty()


static func is_inside_zone(zone_name: String, world_pos: Vector2) -> bool:
	for poly: PackedVector2Array in _zones.get(zone_name, []):
		if Geometry2D.is_point_in_polygon(world_pos, poly):
			return true
	return false


## Punto piu` vicino dentro uno dei poligoni della zona (o il punto stesso
## se gia` dentro). Permissivo se la zona non esiste, come is_inside_floor.
static func clamp_inside_zone(zone_name: String, world_pos: Vector2, margin: float = 4.0) -> Vector2:
	if not has_zone(zone_name):
		return world_pos
	if is_inside_zone(zone_name, world_pos):
		return world_pos
	var best := world_pos
	var best_dist := INF
	for poly: PackedVector2Array in _zones[zone_name]:
		var candidate := _closest_point_inside(poly, world_pos, margin)
		var d := world_pos.distance_squared_to(candidate)
		if d < best_dist:
			best_dist = d
			best = candidate
	return best


## Clamp all'unione pavimento + zona: dentro una delle due → invariato,
## altrimenti il piu` vicino tra i due clamp. E` il percorso di ROAM_GARDEN.
static func clamp_inside_floor_or_zone(zone_name: String, world_pos: Vector2, margin: float = 4.0) -> Vector2:
	if is_inside_floor(world_pos) and has_floor_polygon():
		return world_pos
	if is_inside_zone(zone_name, world_pos):
		return world_pos
	var floor_pt := clamp_inside_floor(world_pos, margin)
	if not has_zone(zone_name):
		return floor_pt
	var zone_pt := clamp_inside_zone(zone_name, world_pos, margin)
	if not has_floor_polygon():
		return zone_pt
	var use_floor := world_pos.distance_squared_to(floor_pt) <= world_pos.distance_squared_to(zone_pt)
	return floor_pt if use_floor else zone_pt


## Punto casuale dentro la zona (rejection sampling sul bbox, poi clamp).
static func random_point_in_zone(zone_name: String, rng: RandomNumberGenerator) -> Vector2:
	if not has_zone(zone_name):
		return Vector2.ZERO
	var polys: Array = _zones[zone_name]
	var poly: PackedVector2Array = polys[rng.randi_range(0, polys.size() - 1)]
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bounds = bounds.expand(p)
	for _i in range(24):
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y),
		)
		if Geometry2D.is_point_in_polygon(candidate, poly):
			return candidate
	return _polygon_centroid(poly)


## Nucleo condiviso: punto sul bordo del poligono, spinto `margin` px verso
## il centroide (stessa strategia di clamp_inside_floor).
static func _closest_point_inside(poly: PackedVector2Array, world_pos: Vector2, margin: float) -> Vector2:
	var best := world_pos
	var best_dist_sq := INF
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var p := Geometry2D.get_closest_point_to_segment(world_pos, a, b)
		var d := world_pos.distance_squared_to(p)
		if d < best_dist_sq:
			best_dist_sq = d
			best = p
	var to_center := _polygon_centroid(poly) - best
	if to_center.length_squared() > 0.0001:
		best += to_center.normalized() * margin
	return best


# ----------------------------------------------------------------------------
# Wall band API (derived from the floor polygon — see header comment)
# ----------------------------------------------------------------------------


static func has_wall_band() -> bool:
	return _wall_ready


## Y of the wall base at horizontal position `x` (piecewise over the two base
## edges). INF when x is outside the wall span or the band is uninitialized.
static func wall_base_y_at(x: float) -> float:
	if not _wall_ready:
		return INF
	if x < _wall_left.x or x > _wall_right.x:
		return INF
	var a := _wall_left
	var b := _wall_top
	if x > _wall_top.x:
		a = _wall_top
		b = _wall_right
	var t := (x - a.x) / (b.x - a.x) if b.x != a.x else 0.0
	return lerpf(a.y, b.y, t)


## Clamp the CENTER of a wall-mounted item (half_size = half its scaled rect)
## so the whole rect stays on a wall face. Permissive when the band is not
## initialized (same philosophy as is_inside_floor). Items taller than the
## band are pinned to the band's middle instead of oscillating.
static func clamp_wall_anchor(center: Vector2, half_size: Vector2, margin: float = 4.0) -> Vector2:
	if not _wall_ready:
		return center
	var x := clampf(center.x, _wall_left.x + half_size.x + margin, _wall_right.x - half_size.x - margin)
	var base := wall_base_y_at(x)
	if base == INF:
		return center
	var y_max := base - half_size.y - margin
	var y_min := base - WALL_BAND_HEIGHT + half_size.y + margin
	var y := clampf(center.y, y_min, y_max) if y_min <= y_max else (y_min + y_max) * 0.5
	return Vector2(x, y)


## True when a wall-item rect centered at `center` already lies on a wall face
## (within `tolerance` px of where the clamp would put it).
static func is_on_wall(center: Vector2, half_size: Vector2, tolerance: float = 1.0) -> bool:
	if not _wall_ready:
		return true
	return center.distance_to(clamp_wall_anchor(center, half_size)) <= tolerance


# ----------------------------------------------------------------------------
# Placement rules (data-driven — the catalog entry is the contract)
# ----------------------------------------------------------------------------


## Normalized placement type of a catalog/save entry. Unknown values (e.g. the
## retired "any") fall back to "floor" with a once-per-value warning — the
## NameTo* pattern: warn, fallback, keep running (never crash on bad data).
static func placement_type_of(entry: Dictionary) -> String:
	var raw := str(entry.get("placement_type", "floor"))
	if raw == "floor" or raw == "wall":
		return raw
	if not _warned_placements.has(raw):
		_warned_placements[raw] = true
		push_warning("Helpers: unknown placement_type '%s', treated as 'floor'" % raw)
	return "floor"


## Whether the item may be rotated by the player. Default false: 90° rotations
## of perspective-drawn furniture produce nonsense; flat items (rugs) opt in
## via "rotatable": true in the catalog.
static func is_rotatable(entry: Dictionary) -> bool:
	return bool(entry.get("rotatable", false))


## Whether the item lies flat on the floor (rugs): drawn under everything that
## stands, never blocks movement.
static func is_flat(entry: Dictionary) -> bool:
	return bool(entry.get("flat", false))


## Allowed scale range as MULTIPLIERS of the catalog item_scale, so every item
## stays near its authored proportion. Overridable per entry via "scale_min" /
## "scale_max"; defaults keep furniture between half and double size.
static func scale_bounds_of(entry: Dictionary) -> Vector2:
	var lo := clampf(float(entry.get("scale_min", 0.5)), 0.05, 10.0)
	var hi := clampf(float(entry.get("scale_max", 2.0)), lo, 10.0)
	return Vector2(lo, hi)


## Draw order for an entity standing on the floor: its ground-contact y.
static func z_for_foot_y(foot_y: float) -> int:
	return clampi(int(foot_y), Z_FOOT_MIN, RenderingServer.CANVAS_ITEM_Z_MAX - 1)


## Etichetta localizzata di una entry di catalogo. Cerca prima i campi
## specifici per lingua (label_it/label_en, name_it/name_en), poi ricade su
## label, name e infine id: cosi` un catalogo monolingua continua a funzionare
## mentre quelli bilingui seguono la lingua attiva.
static func locale_label(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var suffix := "_en"
	if TranslationServer.get_locale().begins_with("it"):
		suffix = "_it"
	for base in ["label", "name", "title"]:
		var localized: String = str(entry.get(base + suffix, ""))
		if not localized.is_empty():
			return localized
	for base in ["label", "name", "title"]:
		var generic: String = str(entry.get(base, ""))
		if not generic.is_empty():
			return generic
	return str(entry.get("id", ""))


## Descrizione localizzata (stessa strategia di locale_label).
static func locale_description(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var suffix := "_en"
	if TranslationServer.get_locale().begins_with("it"):
		suffix = "_it"
	var localized: String = str(entry.get("description" + suffix, ""))
	if not localized.is_empty():
		return localized
	return str(entry.get("description", ""))
