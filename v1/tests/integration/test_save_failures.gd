## Test dei percorsi di fallimento del salvataggio (Fase C.2 / E.2).
##
## Il punto dell'audit era che un salvataggio fallito emetteva comunque
## save_completed: qui si verifica che i segnali dicano la verita` e che i
## file di recupero (quarantena, anello di backup, save piu` recente
## dell'app) vengano prodotti davvero.
extends TestBase

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data.backup.json"
const NEWER_PATH := "user://save_data.newer.json"

var _save_failed_reasons: Array[String] = []
var _integrity_violations: Array[String] = []


func _ready() -> void:
	SignalBus.save_failed.connect(_on_save_failed)
	SignalBus.save_integrity_violation.connect(_on_integrity_violation)


func _exit_tree() -> void:
	if SignalBus.save_failed.is_connected(_on_save_failed):
		SignalBus.save_failed.disconnect(_on_save_failed)
	if SignalBus.save_integrity_violation.is_connected(_on_integrity_violation):
		SignalBus.save_integrity_violation.disconnect(_on_integrity_violation)


func _on_save_failed(reason: String) -> void:
	_save_failed_reasons.append(reason)


func _on_integrity_violation(path: String) -> void:
	_integrity_violations.append(path)


func test_error_signals_exist_with_expected_arity() -> void:
	# La vocabolario di errore e` il contratto su cui si appoggiano i toast:
	# se un segnale sparisce o cambia forma, il fallimento torna invisibile.
	var expected := {
		"save_failed": 1,
		"save_integrity_violation": 1,
		"save_integrity_unavailable": 0,
		"sync_error": 2,
		"sync_payload_corrupted": 2,
		"catalog_load_failed": 2,
		"db_error": 2,
	}
	for signal_name: String in expected:
		assert_true(SignalBus.has_signal(signal_name), "SignalBus must declare %s" % signal_name)
		for signal_info in SignalBus.get_signal_list():
			if signal_info.get("name", "") == signal_name:
				var args: Array = signal_info.get("args", [])
				assert_eq(args.size(), expected[signal_name], "%s argument count" % signal_name)
				break


func test_successful_save_reports_success_only() -> void:
	_save_failed_reasons.clear()
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(SAVE_PATH), "save file written")
	assert_eq(_save_failed_reasons.size(), 0, "healthy save must not report a failure")


func test_tampered_save_is_quarantined_not_silently_dropped() -> void:
	_integrity_violations.clear()
	SaveManager.save_game()
	# Manomissione: payload cambiato lasciando l'HMAC originale.
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_non_null(file, "save file readable")
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	assert_eq(json.parse(raw), OK, "save file is valid JSON")
	var wrapper: Dictionary = json.data
	assert_true(wrapper.has("hmac"), "save uses the HMAC wrapper")
	wrapper["data"] = '{"version":"5.0.0","inventory":{"coins":999999,"items":[]}}'
	var out := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(wrapper))
	out.flush()
	out.close()

	SaveManager.load_game()
	assert_true(_integrity_violations.size() >= 1, "tampering must raise save_integrity_violation")
	assert_false(FileAccess.file_exists(SAVE_PATH), "tampered file must be moved aside, not left in place")
	assert_true(_find_quarantine_file() != "", "a quarantine copy must exist for forensics")
	_cleanup_quarantine()


func test_backup_ring_keeps_previous_generations() -> void:
	SaveManager.save_game()
	SaveManager.save_game()
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(SAVE_PATH), "primary save present")
	assert_true(FileAccess.file_exists(BACKUP_PATH), "first backup generation present")


func test_save_from_newer_version_is_parked_not_applied() -> void:
	_save_failed_reasons.clear()
	_write_signed_save({"version": "99.0.0", "inventory": {"coins": 4242, "items": []}})
	SaveManager.load_game()
	assert_ne(SaveManager.inventory_data.get("coins", 0), 4242, "a newer save must not be applied blindly")
	assert_true(FileAccess.file_exists(NEWER_PATH), "the newer save is parked for recovery")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NEWER_PATH))
	_integrity_violations.clear()


## Scrive un save firmato con la chiave di integrita` corrente: serve un file
## valido a tutti gli effetti, l'unica anomalia deve essere la versione.
func _write_signed_save(payload: Dictionary) -> void:
	var inner := JSON.stringify(payload)
	var wrapper := {"hmac": SaveManager._compute_hmac(inner), "data": inner}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(wrapper))
	f.flush()
	f.close()


func _find_quarantine_file() -> String:
	var dir := DirAccess.open("user://")
	if dir == null:
		return ""
	for file_name in dir.get_files():
		if file_name.contains("quarantine"):
			return file_name
	return ""


func _cleanup_quarantine() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.contains("quarantine"):
			dir.remove(file_name)
