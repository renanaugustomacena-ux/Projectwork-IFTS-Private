## SignalBus — Global signal hub for decoupled communication between systems.
## All cross-system signals are declared here to avoid tight coupling.
extends Node

# Room signals
signal room_changed(room_id: String, theme: String)
signal decoration_placed(item_id: String, position: Vector2)
signal decoration_removed(item_id: String)
signal decoration_moved(item_id: String, new_position: Vector2)

# Character signals
signal character_changed(character_id: String)
signal interaction_available(item_id: String, interaction_type: String)
signal interaction_unavailable
signal interaction_started(item_id: String, interaction_type: String)
signal outfit_changed(outfit_id: String)

# Music/Audio signals
signal track_changed(track_index: int)
signal track_play_pause_toggled(is_playing: bool)
signal ambience_toggled(ambience_id: String, is_active: bool)
signal volume_changed(bus_name: String, volume: float)

# Decoration mode
signal decoration_mode_changed(active: bool)
signal decoration_selected(item_id: String)
signal decoration_deselected
signal decoration_rotated(item_id: String, rotation_deg: float)
signal decoration_scaled(item_id: String, new_scale: float)

# UI signals
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal toast_requested(message: String, toast_type: String)
# Save/Load signals
signal save_requested
signal save_completed
signal load_completed

# Settings update signal (replaces direct writes to SaveManager.settings)
signal settings_updated(key: String, value: Variant)

# Music state signal (replaces direct write to SaveManager.music_state)
signal music_state_updated(state: Dictionary)

# Database persistence signal (replaces direct calls to LocalDatabase)
signal save_to_database_requested(data: Dictionary)

# Settings signals
signal language_changed(lang_code: String)

# Auth lifecycle
signal auth_state_changed(state: int)
signal auth_error(message: String)
signal account_created(account_id: int)
signal account_deleted
signal character_deleted

# Cloud sync
signal sync_started
signal sync_completed(success: bool)
signal cloud_auth_completed(success: bool)
signal cloud_connection_changed(state: int)

# Stress / Mood (stress_value is continuous 0.0-1.0; level is calm/neutral/tense)
signal stress_changed(stress_value: float, level: String)
signal stress_threshold_crossed(level: String)
signal mood_changed(mood: String)

# Mess / Cleanup
signal mess_spawned(mess_id: String, mess_position: Vector2)
signal mess_cleaned(mess_id: String)

# Economy
signal coins_changed(delta: int, total: int)

# Profile HUD (feature T-R-015 — minipanel in alto con profilo + mood bar)
signal profile_hud_requested
signal profile_hud_closed
signal mood_level_changed(mood: float)  # 0.0=gloomy/stormy, 1.0=cozy original

# Mood effects pipeline (T-R-015i)
signal pet_wild_mode_requested(active: bool)  # cat berserk quando mood < 0.10
signal badge_unlocked(badge_id: String)  # T-R-015d
