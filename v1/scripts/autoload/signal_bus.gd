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
signal outfit_changed(outfit_id: String)

# Music/Audio signals
signal track_changed(track_index: int)
signal track_play_pause_toggled(is_playing: bool)
signal ambience_toggled(ambience_id: String, is_active: bool)
signal volume_changed(bus_name: String, volume: float)

# Decoration mode
signal decoration_mode_changed(active: bool)

# UI signals
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
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
