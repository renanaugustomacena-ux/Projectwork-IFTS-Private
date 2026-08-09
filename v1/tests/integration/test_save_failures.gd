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


# ---- V-021: l'identita` ospite non deve sovrascrivere un account vero ----


## Il fallback con mail segnaposto era incondizionato: bastava che il lookup per
## auth_uid non trovasse la riga (cancellata altrove, migrazione a meta`, DB
## riaperto dopo un crash) perche` il salvataggio di un utente REGISTRATO
## coniasse un account `offline@local` sotto il suo uid. Da quel momento giocava
## su un account fantasma.
func test_authenticated_uid_without_a_row_never_mints_a_guest_account() -> void:
	var was_uid: String = AuthManager.current_auth_uid
	var ghost_uid := "uid_registrato_senza_riga_%d" % Time.get_ticks_usec()
	AuthManager.current_auth_uid = ghost_uid

	var resolved: int = LocalDatabase._resolve_save_account_id()
	var reason := str(LocalDatabase.get("_last_account_error"))
	var minted: Dictionary = LocalDatabase.get_account_by_auth_uid(ghost_uid)

	AuthManager.current_auth_uid = was_uid

	assert_true(resolved < 0, "un uid autenticato senza riga deve fallire, non inventare un account")
	assert_eq(reason, "account_row_missing", "il motivo distinto deve arrivare fino al toast")
	assert_true(minted.is_empty(), "nessuna riga deve nascere sotto l'uid reale del giocatore")


## La guardia non deve rompere il caso per cui il fallback esisteva: chi gioca
## senza registrarsi deve continuare a ottenere il suo account offline.
func test_guest_uid_without_a_row_still_gets_its_offline_account() -> void:
	var was_uid: String = AuthManager.current_auth_uid
	AuthManager.current_auth_uid = ""  # -> Constants.AUTH_GUEST_UID

	var resolved: int = LocalDatabase._resolve_save_account_id()
	var row: Dictionary = LocalDatabase.get_account_by_auth_uid(Constants.AUTH_GUEST_UID)

	AuthManager.current_auth_uid = was_uid

	assert_true(resolved > 0, "l'ospite deve poter salvare senza registrarsi")
	assert_eq(str(row.get("mail", "")), Constants.AUTH_GUEST_EMAIL, "la mail segnaposto vale solo per l'ospite")


## Il fallimento deve essere rumoroso: apply_save aborta e il motivo esce su
## db_error, che main.gd trasforma in un toast rosso.
func test_apply_save_aborts_loudly_when_the_account_row_is_missing() -> void:
	var seen: Array[String] = []
	var probe := func(context: String, reason: String) -> void: seen.append("%s/%s" % [context, reason])
	SignalBus.db_error.connect(probe)
	var was_uid: String = AuthManager.current_auth_uid
	AuthManager.current_auth_uid = "uid_fantasma_%d" % Time.get_ticks_usec()

	var committed: bool = LocalDatabase.apply_save({"settings": {"master_volume": 0.5}})

	AuthManager.current_auth_uid = was_uid
	SignalBus.db_error.disconnect(probe)

	assert_false(committed, "senza un account risolto il salvataggio non deve committare")
	assert_true(seen.has("apply_save/account_row_missing"), "db_error deve dire cosa e` mancato, visto: %s" % str(seen))


## Esito del salvataggio finale quando c'e` un errore di scrittura vero: il
## quit deve restare bloccato (retry, poi stay-alive, poi force-quit).
func test_final_save_blocks_quit_on_a_real_write_failure() -> void:
	var was_loaded: bool = bool(SaveManager.get("_full_state_loaded"))
	var was_open: bool = bool(LocalDatabase.get("_is_open"))
	_save_failed_reasons.clear()
	SaveManager.set("_full_state_loaded", true)
	# Iniezione in memoria (nessun artefatto su disco che possa sopravvivere al
	# processo): con il DB marcato chiuso apply_save rifiuta il mirror e
	# save_game() imbocca _fail_save("db_mirror").
	LocalDatabase.set("_is_open", false)

	var can_quit: bool = SaveManager._run_final_save()
	var outcome: int = int(SaveManager.get("_last_save_outcome"))
	var reasons := _save_failed_reasons.duplicate()

	# Ripristino PRIMA delle asserzioni: un'asserzione che aborta non deve
	# lasciare il DB marcato chiuso per il resto della suite.
	LocalDatabase.set("_is_open", was_open)
	SaveManager.set("_full_state_loaded", was_loaded)
	_save_failed_reasons.clear()

	assert_false(can_quit, "un fallimento di scrittura reale non deve consentire il quit")
	assert_true(reasons.has("db_mirror"), "il fallimento deve emettere save_failed(db_mirror)")
	assert_eq(outcome, int(SaveManager.SaveOutcome.FAILED), "un errore di scrittura resta classificato FAILED")


## Nel main menu load_game() non gira mai, quindi il salvataggio finale viene
## rifiutato by-design (F.7). Il percorso di quit lo leggeva come fallimento,
## ritentava, e restava vivo: chiudere l'app richiedeva due close.
func test_final_save_skipped_for_unloaded_state_allows_quit() -> void:
	var was_loaded: bool = bool(SaveManager.get("_full_state_loaded"))
	_save_failed_reasons.clear()
	SaveManager.set("_full_state_loaded", false)

	var can_quit: bool = SaveManager._run_final_save()
	var outcome: int = int(SaveManager.get("_last_save_outcome"))
	var stayed_dirty: bool = bool(SaveManager.get("_save_dirty"))
	var reasons := _save_failed_reasons.duplicate()

	# Ripristino prima delle asserzioni: il latch lasciato a false spegnerebbe
	# ogni salvataggio dei test successivi.
	SaveManager.set("_full_state_loaded", was_loaded)
	_save_failed_reasons.clear()

	assert_true(can_quit, "niente da salvare deve permettere il quit al primo close")
	assert_eq(reasons.size(), 0, "uno skip by-design non deve emettere save_failed")
	assert_eq(
		outcome, int(SaveManager.SaveOutcome.NOTHING_TO_SAVE), "lo skip va classificato NOTHING_TO_SAVE, mai FAILED"
	)
	assert_true(stayed_dirty, "il dirty flag deve sopravvivere allo skip")


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
