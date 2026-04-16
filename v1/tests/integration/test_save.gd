## test_save — roundtrip save/load, HMAC integrity, backup fallback, migrations.
extends "res://tests/integration/test_base.gd"

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data.backup.json"
const TMP_SAVE := "user://test_save_data.json"


# ---- HMAC integrity ----


func test_hmac_deterministic() -> void:
	# Same input → same HMAC (within a session, using same device key)
	var h1: String = SaveManager._compute_hmac("hello world")
	var h2: String = SaveManager._compute_hmac("hello world")
	assert_eq(h1, h2, "HMAC must be deterministic for same input + key")


func test_hmac_differs_for_different_input() -> void:
	var h1: String = SaveManager._compute_hmac("hello world")
	var h2: String = SaveManager._compute_hmac("hello World")  # single char diff
	assert_ne(h1, h2, "HMAC must differ for any input change")


func test_hmac_length_is_64_hex() -> void:
	# SHA-256 outputs 32 bytes → 64 hex chars
	var h: String = SaveManager._compute_hmac("x")
	assert_eq(h.length(), 64)


# ---- Save / Load roundtrip ----


func test_save_then_load_roundtrip_preserves_settings() -> void:
	# Snapshot current state, mutate, save, reset, load, compare.
	var original_master: float = SaveManager.get_setting("master_volume", 0.8)
	SignalBus.settings_updated.emit("master_volume", 0.33)
	await wait_frames(1)
	# Force-save synchronously
	SaveManager.save_game()
	await wait_frames(1)
	# Mutate locally
	SignalBus.settings_updated.emit("master_volume", 0.99)
	await wait_frames(1)
	assert_approx(SaveManager.get_setting("master_volume", 0.0), 0.99)
	# Reload
	SaveManager.load_game()
	await wait_frames(2)
	assert_approx(SaveManager.get_setting("master_volume", 0.0), 0.33,
		0.001, "load should restore the saved 0.33")
	# Restore pre-test state
	SignalBus.settings_updated.emit("master_volume", original_master)
	SaveManager.save_game()


func test_save_file_has_hmac_wrapper() -> void:
	SaveManager.save_game()
	await wait_frames(1)
	assert_true(FileAccess.file_exists(SAVE_PATH))
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_non_null(f)
	var text: String = f.get_as_text()
	f.close()
	var parsed := JSON.new()
	assert_eq(parsed.parse(text), OK)
	var wrapper: Variant = parsed.data
	assert_true(wrapper is Dictionary)
	assert_has(wrapper, "hmac")
	assert_has(wrapper, "data")
	var hmac: String = wrapper.get("hmac", "")
	assert_eq(hmac.length(), 64, "HMAC should be 64 hex chars")


func test_tampered_save_rejected_falls_back() -> void:
	# Write known-good state, copy to backup, corrupt primary, load → must use backup.
	SignalBus.settings_updated.emit("language", "en")
	SaveManager.save_game()
	await wait_frames(1)
	# Force backup copy (SaveManager copies primary→backup on NEXT save only, so do it manually)
	DirAccess.copy_absolute(
		ProjectSettings.globalize_path(SAVE_PATH),
		ProjectSettings.globalize_path(BACKUP_PATH),
	)
	# Now corrupt primary by mutating HMAC
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed := JSON.new()
	parsed.parse(text)
	var wrapper: Dictionary = parsed.data
	wrapper["hmac"] = "0000000000000000000000000000000000000000000000000000000000000000"
	var fw := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	fw.store_string(JSON.stringify(wrapper))
	fw.close()
	# Set in-memory setting to something else to confirm load actually runs
	SignalBus.settings_updated.emit("language", "it")
	# Trigger load — should reject primary, fall back to backup
	SaveManager.load_game()
	await wait_frames(2)
	assert_eq(SaveManager.get_setting("language", ""), "en",
		"tampered primary should be rejected, backup loaded")
	# Cleanup: restore a clean primary
	SaveManager.save_game()


# ---- Migration ----


func test_migrate_v1_to_v5_sets_version() -> void:
	var data := {"version": "1.0.0", "settings": {"language": "en"}}
	var migrated: Dictionary = SaveManager._migrate_save_data(data)
	assert_eq(migrated.get("version", ""), "5.0.0")


func test_migrate_v3_to_v5_strips_obsolete_fields() -> void:
	var data := {
		"version": "3.0.0",
		"tools": {"foo": 1},
		"therapeutic": {},
		"xp": 42,
		"streak": 7,
		"currency": {"coins": 100},
		"unlocks": [],
		"last_active_timestamp": 0,
		"updated_at": "",
	}
	var migrated: Dictionary = SaveManager._migrate_save_data(data)
	assert_eq(migrated.get("version", ""), "5.0.0")
	for key in ["tools", "therapeutic", "xp", "streak", "currency", "unlocks",
		"last_active_timestamp", "updated_at"]:
		assert_false(migrated.has(key), "obsolete field %s must be removed" % key)
	# Coins should be preserved via the currency.coins → inventory.coins path
	assert_true(migrated.has("inventory"))
	assert_eq(int(migrated["inventory"].get("coins", 0)), 100)


func test_migrate_v4_to_v5_adds_account_section() -> void:
	var data := {"version": "4.0.0", "inventory": {"coins": 0, "capacita": 50, "items": []}}
	var migrated: Dictionary = SaveManager._migrate_save_data(data)
	assert_eq(migrated.get("version", ""), "5.0.0")
	assert_has(migrated, "account")
	assert_has(migrated["account"], "auth_uid")


func test_migrate_preserves_newer_version() -> void:
	# If save comes from a future version, don't downgrade
	var data := {"version": "99.0.0", "settings": {}}
	var migrated: Dictionary = SaveManager._migrate_save_data(data)
	assert_eq(migrated.get("version", ""), "99.0.0")


func test_compare_versions() -> void:
	assert_eq(SaveManager._compare_versions("1.0.0", "1.0.0"), 0)
	assert_eq(SaveManager._compare_versions("1.0.0", "2.0.0"), -1)
	assert_eq(SaveManager._compare_versions("5.1.2", "5.1.1"), 1)
	assert_eq(SaveManager._compare_versions("5.0.0", "5.0"), 0)


# ---- Reset behavior ----


func test_reset_all_preserves_pet_variant_in_defaults() -> void:
	# Regression test for fix just applied: reset_all must include pet_variant
	SaveManager.reset_all()
	assert_eq(SaveManager.get_setting("pet_variant", "__missing__"), "simple",
		"reset_all() must set pet_variant default, not lose the key")
	# Restore
	SaveManager.save_game()


func test_reset_character_data_clears_stress() -> void:
	SaveManager.character_data["livello_stress"] = 85
	SaveManager.reset_character_data()
	assert_eq(int(SaveManager.character_data.get("livello_stress", -1)), 0)
