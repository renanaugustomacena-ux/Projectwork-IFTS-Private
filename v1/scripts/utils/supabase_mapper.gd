## SupabaseMapper — Transforms data between local SQLite schema and Supabase.
## Single point of truth for local-to-cloud field mapping.
## Uses .get(key, default) everywhere so missing fields never crash.
class_name SupabaseMapper


# ---- Local -> Cloud ----


static func profile_to_cloud(
	account: Dictionary, character: Dictionary, supabase_uid: String,
) -> Dictionary:
	return {
		"user_id": supabase_uid,
		"display_name": account.get("display_name", ""),
		"avatar_character_id": character.get("character_id", "male_old"),
		"avatar_outfit_id": character.get("outfit_id", ""),
		"current_room_id": GameManager.current_room_id,
		"current_theme": GameManager.current_theme,
		"locale": SaveManager.get_setting("language", "en"),
		"updated_at": Time.get_datetime_string_from_system(),
	}


static func decorations_to_cloud(
	decorations: Array, supabase_uid: String,
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for d in decorations:
		if d is not Dictionary:
			continue
		rows.append({
			"user_id": supabase_uid,
			"room_id": d.get("room_id", "cozy_studio"),
			"theme": d.get("theme", "modern"),
			"item_id": d.get("item_id", ""),
			"position_x": d.get("position_x", d.get("pos_x", 0.0)),
			"position_y": d.get("position_y", d.get("pos_y", 0.0)),
			"z_index": d.get("z_index", d.get("z_order", 0)),
			"rotation_deg": d.get("rotation_deg", 0.0),
			"flipped": d.get("flipped", d.get("flip_h", false)),
			"updated_at": Time.get_datetime_string_from_system(),
		})
	return rows


static func currency_to_cloud(
	account: Dictionary, supabase_uid: String,
) -> Dictionary:
	return {
		"user_id": supabase_uid,
		"coins": account.get("coins", 0),
		"total_earned": account.get("coins", 0),  # TODO: track lifetime earnings separately (needs DB column)
		"updated_at": Time.get_datetime_string_from_system(),
	}


static func settings_to_cloud(
	settings: Dictionary, supabase_uid: String,
) -> Dictionary:
	return {
		"user_id": supabase_uid,
		"display_mode": settings.get("display_mode", "windowed"),
		"mini_mode_position": settings.get("mini_mode_position", "bottom_right"),
		"master_volume": settings.get("master_volume", 0.8),
		"music_volume": settings.get("music_volume", 0.6),
		"ambience_volume": settings.get("ambience_volume", 0.4),
		"updated_at": Time.get_datetime_string_from_system(),
	}


static func music_to_cloud(
	music_state: Dictionary, supabase_uid: String,
) -> Dictionary:
	return {
		"user_id": supabase_uid,
		"current_track_index": music_state.get("current_track_index", 0),
		"playlist_mode": music_state.get("playlist_mode", "shuffle"),
		"active_ambience": music_state.get("active_ambience", []),
		"updated_at": Time.get_datetime_string_from_system(),
	}


static func inventory_to_cloud(
	items: Array, supabase_uid: String,
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item in items:
		if item is not Dictionary:
			continue
		rows.append({
			"user_id": supabase_uid,
			"item_id": str(item.get("item_id", "")),
			"unlock_type": "currency",
			"unlocked_at": Time.get_datetime_string_from_system(),
		})
	return rows


# ---- Cloud -> Local ----


static func cloud_profile_to_local(profile: Dictionary) -> Dictionary:
	return {
		"display_name": profile.get("display_name", ""),
		"character_id": profile.get("avatar_character_id", "male_old"),
		"outfit_id": profile.get("avatar_outfit_id", ""),
		"room_id": profile.get("current_room_id", "cozy_studio"),
		"theme": profile.get("current_theme", "modern"),
	}


static func cloud_decorations_to_local(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		if row is not Dictionary:
			continue
		result.append({
			"item_id": row.get("item_id", ""),
			"pos_x": row.get("position_x", 0.0),
			"pos_y": row.get("position_y", 0.0),
			"z_order": row.get("z_index", 0),
			"rotation_deg": row.get("rotation_deg", 0.0),
			"flip_h": row.get("flipped", false),
		})
	return result


static func cloud_settings_to_local(settings: Dictionary) -> Dictionary:
	return {
		"display_mode": settings.get("display_mode", "windowed"),
		"mini_mode_position": settings.get("mini_mode_position", "bottom_right"),
		"master_volume": settings.get("master_volume", 0.8),
		"music_volume": settings.get("music_volume", 0.6),
		"ambience_volume": settings.get("ambience_volume", 0.4),
	}
