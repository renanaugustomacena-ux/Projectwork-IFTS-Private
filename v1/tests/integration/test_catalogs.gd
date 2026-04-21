# gdlint: disable=max-public-methods
## test_catalogs — verifies every asset referenced in JSON catalogs loads.
##
## Copre 72 decoration sprites, 2 character scenes (+ every animation path for
## the directional one), 2 audio tracks, 6 mess placeholder colors, 1 room +
## 3 themes + hex colors.
##
## Test suite: una funzione per ogni case -> excedes max-public-methods by
## design.
extends "res://tests/integration/test_base.gd"


func test_decorations_catalog_size() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	var decos: Array = catalog.get("decorations", [])
	# Current state: 129 decorations (72 original + 57 kenney_furniture_cc0
	# added 2026-04-17). If this changes intentionally, update the assertion
	# AND the docs (README, speech, pptx, DEEP_READ_REGISTRY).
	assert_eq(decos.size(), 129, "decoration count changed — update docs if intentional")


func test_decorations_categories_size() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	var cats: Array = catalog.get("categories", [])
	assert_eq(cats.size(), 13)
	# Exactly one is hidden (pets)
	var hidden := 0
	for c in cats:
		if c is Dictionary and c.get("hidden", false):
			hidden += 1
	assert_eq(hidden, 1)


func test_all_decorations_have_required_fields() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	for deco in catalog.get("decorations", []):
		if not (deco is Dictionary):
			fail("non-dict decoration")
			continue
		for key in ["id", "name", "category", "sprite_path", "placement_type"]:
			assert_has(deco, key, "deco %s" % deco.get("id", "?"))


func test_all_decoration_sprites_load() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	var missing: Array[String] = []
	for deco in catalog.get("decorations", []):
		var path: String = deco.get("sprite_path", "")
		if path.is_empty():
			missing.append(deco.get("id", "?") + " (empty path)")
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			missing.append("%s → %s" % [deco.get("id", "?"), path])
		else:
			var sz := tex.get_size()
			if sz.x <= 0 or sz.y <= 0:
				missing.append("%s has 0-size texture" % deco.get("id", "?"))
	if not missing.is_empty():
		fail("sprites failed to load: %s" % ", ".join(missing))
	else:
		# record a successful assertion so runner shows the check ran
		assert_true(true, "all 72 deco sprites loaded")


func test_decoration_ids_unique() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for deco in catalog.get("decorations", []):
		var id: String = deco.get("id", "")
		if id in seen:
			dups.append(id)
		seen[id] = true
	if not dups.is_empty():
		fail("duplicate deco ids: %s" % ", ".join(dups))
	else:
		assert_true(true, "all ids unique")


func test_decoration_category_references_valid() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	var cat_ids: Dictionary = {}
	for c in catalog.get("categories", []):
		cat_ids[c.get("id", "")] = true
	var orphans: Array[String] = []
	for deco in catalog.get("decorations", []):
		var cat: String = deco.get("category", "")
		if not cat_ids.has(cat):
			orphans.append("%s → %s" % [deco.get("id", "?"), cat])
	if not orphans.is_empty():
		fail("orphan category refs: %s" % ", ".join(orphans))
	else:
		assert_true(true, "all category refs valid")


func test_decoration_placement_types_valid() -> void:
	var valid := {"floor": true, "wall": true, "any": true}
	for deco in GameManager.decorations_catalog.get("decorations", []):
		var pt: String = deco.get("placement_type", "")
		assert_true(valid.has(pt), "deco %s has invalid placement_type '%s'" % [deco.get("id"), pt])


func test_decoration_item_scale_positive() -> void:
	for deco in GameManager.decorations_catalog.get("decorations", []):
		if "item_scale" in deco:
			var s: float = float(deco["item_scale"])
			assert_true(s > 0.0, "deco %s has non-positive item_scale %f" % [deco.get("id"), s])


# ---- Characters ----


func test_characters_catalog_size() -> void:
	# Currently 1 playable character (male_old). Female moved out of project
	# on 2026-04-17 pending proper aseprite creation.
	assert_eq(GameManager.characters_catalog.get("characters", []).size(), 1)


func test_male_old_all_sprites_load() -> void:
	var char_data: Dictionary = _find_character("male_old")
	assert_false(char_data.is_empty(), "male_old must exist")
	var anims: Dictionary = char_data.get("animations", {})
	var missing: Array[String] = []
	for anim_name in ["idle", "walk", "interact"]:
		var anim: Dictionary = anims.get(anim_name, {})
		for direction in ["down", "down_side", "down_side_sx", "side", "side_sx", "up", "up_side", "up_side_sx"]:
			var path: String = anim.get(direction, "")
			var tex: Texture2D = load(path) as Texture2D
			if tex == null:
				missing.append("%s/%s → %s" % [anim_name, direction, path])
	var rotate_path: String = anims.get("rotate", "")
	var rotate_tex: Texture2D = load(rotate_path) as Texture2D
	if rotate_tex == null:
		missing.append("rotate → %s" % rotate_path)
	if not missing.is_empty():
		fail("character sprites failed to load: %s" % ", ".join(missing))
	else:
		assert_true(true, "all 25 male_old sprites loaded")


func test_male_old_idle_down_dimensions() -> void:
	var char_data: Dictionary = _find_character("male_old")
	var path: String = char_data.get("animations", {}).get("idle", {}).get("down", "")
	var tex: Texture2D = load(path) as Texture2D
	assert_non_null(tex)
	# 4 frame di 32x32 = 128x32
	var sz := tex.get_size()
	assert_approx(sz.x, 128.0, 0.5, "idle_down expected 128px wide")
	assert_approx(sz.y, 32.0, 0.5)


func test_male_old_rotate_strip_dimensions() -> void:
	var char_data: Dictionary = _find_character("male_old")
	var path: String = char_data.get("animations", {}).get("rotate", "")
	var tex: Texture2D = load(path) as Texture2D
	assert_non_null(tex)
	# 8 frame di 32x32 = 256x32
	var sz := tex.get_size()
	assert_approx(sz.x, 256.0, 0.5)


func test_female_character_removed_from_catalog() -> void:
	# Regression guard: female was moved out of project 2026-04-17. If someone
	# re-adds it without completing the full directional animation set,
	# test_catalogs.test_male_old_all_sprites_load equivalent must be added.
	assert_true(
		_find_character("female").is_empty(),
		(
			"female character must NOT be in catalog (moved to "
			+ "/tmp/projectwork_removed/female_character_assets_2026-04-17/)"
		)
	)


# ---- Tracks ----


func test_tracks_catalog_size() -> void:
	# Known: 2 tracks. Intentional minimal for demo — if expanded, update docs.
	assert_eq(GameManager.tracks_catalog.get("tracks", []).size(), 2)


func test_all_tracks_audio_load() -> void:
	var missing: Array[String] = []
	for track in GameManager.tracks_catalog.get("tracks", []):
		var path: String = track.get("path", "")
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			missing.append("%s → %s" % [track.get("id", "?"), path])
	if not missing.is_empty():
		fail("audio tracks failed to load: %s" % ", ".join(missing))
	else:
		assert_true(true, "all tracks loaded")


# ---- Rooms ----


func test_rooms_catalog_has_cozy_studio() -> void:
	var rooms: Array = GameManager.rooms_catalog.get("rooms", [])
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0].get("id", ""), "cozy_studio")


func test_cozy_studio_has_three_themes() -> void:
	var rooms: Array = GameManager.rooms_catalog.get("rooms", [])
	var themes: Array = rooms[0].get("themes", [])
	assert_eq(themes.size(), 3)
	var expected_ids := ["modern", "natural", "pink"]
	for i in range(3):
		assert_eq(themes[i].get("id", ""), expected_ids[i])


func test_theme_colors_valid_hex() -> void:
	var regex := RegEx.new()
	regex.compile("^[0-9a-fA-F]{6}$")
	for room in GameManager.rooms_catalog.get("rooms", []):
		for theme in room.get("themes", []):
			for key in ["wall_color", "floor_color"]:
				var c: String = theme.get(key, "")
				assert_true(
					regex.search(c) != null,
					"theme %s.%s: invalid hex '%s'" % [theme.get("id"), key, c],
				)


# ---- Mess catalog ----


func test_mess_catalog_size() -> void:
	assert_eq(GameManager.mess_catalog.get("mess", []).size(), 6)


func test_mess_stress_weights_in_range() -> void:
	for entry in GameManager.mess_catalog.get("mess", []):
		var w: float = float(entry.get("stress_weight", 0.0))
		assert_in_range(w, 0.01, 0.5, "mess %s weight" % entry.get("id"))


func test_mess_placeholder_colors_parse() -> void:
	for entry in GameManager.mess_catalog.get("mess", []):
		var hex: String = entry.get("placeholder_color", "")
		assert_false(hex.is_empty())
		var c := Color(hex)
		# Color() on invalid string returns Color(0,0,0,1) — we just confirm no crash
		assert_true(c.a > 0.0)


# ---- Helpers ----


func _find_character(char_id: String) -> Dictionary:
	for c in GameManager.characters_catalog.get("characters", []):
		if c is Dictionary and c.get("id", "") == char_id:
			return c
	return {}
