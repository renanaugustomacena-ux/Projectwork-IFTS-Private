## TestSaveManager — Unit tests for SaveManager structure and settings.
##
## Documentation:
## Verifies save data structure constants, settings defaults, and
## music state defaults against the v4.0.0 schema.
class_name TestSaveManager
extends GdUnitTestSuite

# --- Save data structure ---


func test_save_version_is_defined() -> void:
	assert_str(SaveManager.SAVE_VERSION).is_not_empty()


func test_save_path_is_in_user_directory() -> void:
	assert_str(SaveManager.SAVE_PATH).starts_with("user://")


func test_backup_path_is_in_user_directory() -> void:
	assert_str(SaveManager.BACKUP_PATH).starts_with("user://")


func test_auto_save_interval_is_positive() -> void:
	assert_float(SaveManager.AUTO_SAVE_INTERVAL).is_greater(0.0)


# --- Settings defaults ---


func test_settings_has_language() -> void:
	assert_dict(SaveManager.settings).contains_keys(["language"])


func test_settings_language_is_supported() -> void:
	var lang: String = SaveManager.settings["language"]
	assert_bool(Constants.LANGUAGES.has(lang)).is_true()


func test_settings_has_display_mode() -> void:
	assert_dict(SaveManager.settings).contains_keys(["display_mode"])


func test_settings_display_mode_default_is_windowed() -> void:
	var mode: String = SaveManager.settings["display_mode"]
	assert_str(mode).is_equal(Constants.DISPLAY_WINDOWED)


func test_settings_has_mini_mode_position() -> void:
	assert_dict(SaveManager.settings).contains_keys(["mini_mode_position"])


func test_settings_has_volume_controls() -> void:
	assert_dict(SaveManager.settings).contains_keys(["master_volume", "music_volume", "ambience_volume"])


func test_settings_volume_in_valid_range() -> void:
	var master: float = SaveManager.settings["master_volume"]
	var music: float = SaveManager.settings["music_volume"]
	var ambience: float = SaveManager.settings["ambience_volume"]
	assert_float(master).is_greater_equal(0.0)
	assert_float(master).is_less_equal(1.0)
	assert_float(music).is_greater_equal(0.0)
	assert_float(music).is_less_equal(1.0)
	assert_float(ambience).is_greater_equal(0.0)
	assert_float(ambience).is_less_equal(1.0)


# --- Music state defaults ---


func test_music_state_has_required_keys() -> void:
	assert_dict(SaveManager.music_state).contains_keys(["current_track_index", "playlist_mode", "active_ambience"])


func test_music_state_playlist_mode_is_valid() -> void:
	var mode: String = SaveManager.music_state["playlist_mode"]
	var valid_modes := [Constants.PLAYLIST_SEQUENTIAL, Constants.PLAYLIST_SHUFFLE, Constants.PLAYLIST_REPEAT_ONE]
	assert_bool(mode in valid_modes).is_true()


func test_music_state_active_ambience_is_array() -> void:
	assert_array(SaveManager.music_state["active_ambience"]).is_not_null()
