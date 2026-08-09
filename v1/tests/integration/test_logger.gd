## test_logger — redazione del context e ciclo di vita del file di log.
##
## Copre due difetti confermati dall'audit di shutdown:
##   V-022 — il filtro di redazione non entrava negli Array, quindi ogni valore
##           sensibile annidato in un array (o in un dict dentro un array)
##           finiva in chiaro nel file .jsonl che l'utente condivide per il
##           debug.
##   DYN-2 — il logger chiudeva il file su NOTIFICATION_WM_CLOSE_REQUEST, cioe`
##           prima che gli autoload registrati dopo di lui (SaveManager) avessero
##           finito di loggare lo shutdown.
extends TestBase

const LoggerScript := preload("res://scripts/autoload/logger.gd")

# ---- V-022: redazione dentro gli Array ----


func test_redaction_scrubs_secrets_nested_in_arrays() -> void:
	var device_path := OS.get_user_data_dir() + "/logs/probe.jsonl"
	var context := {
		"accounts":
		[
			{"name": "renan", "password": "hunter2"},
			{"session": {"access_token": "eyJhbGciOiJIUzI1NiJ9"}},
		],
		"nested": [[{"hmac_key": "deadbeefcafe"}]],
		"paths": [device_path],
		# Chiave sensibile con valore Array: la semantica per chiave vince
		# comunque, l'intero valore sparisce a prescindere dal tipo.
		"tokens": ["super-secret-token"],
		"note": "keep me",
	}

	var out: Dictionary = AppLogger._redact_context(context)
	var serialized := JSON.stringify(out)

	assert_false(serialized.contains("hunter2"), "password dentro un array di dict")
	assert_false(serialized.contains("eyJhbGciOiJIUzI1NiJ9"), "access_token in un dict annidato dentro un array")
	assert_false(serialized.contains("deadbeefcafe"), "hmac_key dentro un array di array")
	assert_false(serialized.contains("super-secret-token"), "valore Array sotto una chiave sensibile")

	# Struttura e dati non sensibili devono sopravvivere intatti.
	var accounts: Array = out["accounts"]
	assert_array_size(accounts, 2, "l'array deve conservare la sua forma")
	assert_eq(str((accounts[0] as Dictionary)["name"]), "renan", "i campi non sensibili restano leggibili")
	assert_eq(str((accounts[0] as Dictionary)["password"]), AppLogger.REDACTED, "il segreto e` sostituito, non rimosso")
	assert_eq(str(out["note"]), "keep me", "le stringhe semplici non vengono toccate")
	assert_eq(str(out["tokens"]), AppLogger.REDACTED, "la redazione per chiave vale anche sugli Array")

	# Lo scrub del path di device deve valere anche dentro un array.
	var paths: Array = out["paths"]
	assert_true(str(paths[0]).begins_with("user://"), "i path assoluti dentro un array vanno normalizzati")
	assert_false(str(paths[0]).contains(OS.get_user_data_dir()), "nessun path di device deve sopravvivere")


func test_secret_inside_array_never_reaches_the_log_file() -> void:
	# Stesso difetto visto dall'API pubblica: quello che conta e` il byte scritto
	# nel file .jsonl, non solo il valore di ritorno del filtro.
	(
		AppLogger
		. info(
			"TestLogger",
			"array redaction probe",
			{
				"accounts": [{"password": "disk-secret-42"}],
				"marker": "array-redaction-probe-marker",
			}
		)
	)
	AppLogger._flush_buffer()

	var content := FileAccess.get_file_as_string(AppLogger.get_log_file_path())
	assert_true(content.contains("array-redaction-probe-marker"), "la riga di log deve essere stata scritta")
	assert_false(content.contains("disk-secret-42"), "il segreto annidato nell'array non deve raggiungere il disco")


# ---- DYN-2: il file resta aperto fino al teardown ----


func test_wm_close_flushes_but_keeps_the_log_file_open() -> void:
	# Istanza dedicata: chiudere il file dell'AppLogger reale zittirebbe i test
	# successivi.
	var probe: Node = LoggerScript.new()
	probe.name = "ProbeLogger"
	add_child(probe)
	await wait_frames(1)
	var path: String = probe.get_log_file_path()

	probe.info("ProbeLogger", "before-close-marker")
	probe._notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# AppLogger e` l'autoload #2, SaveManager il #6, e propagate_notification li
	# visita in ordine di registrazione: chiudere qui lasciava ogni log di
	# shutdown successivo a scrivere su un handle morto (`Parameter "f" is
	# null`) e perdeva le ultime righe della sessione.
	assert_non_null(probe.get("_log_file"), "WM_CLOSE non deve chiudere il file")
	assert_true(FileAccess.get_file_as_string(path).contains("before-close-marker"), "WM_CLOSE deve comunque flushare")

	# Una riga scritta dopo WM_CLOSE (il quit-save di SaveManager) deve ancora
	# arrivare su disco.
	probe.info("ProbeLogger", "after-close-marker")
	probe._flush_buffer()
	assert_true(
		FileAccess.get_file_as_string(path).contains("after-close-marker"),
		"i log emessi dopo WM_CLOSE devono finire nel file"
	)

	# Il close vero avviene al teardown, ed e` idempotente: WM_CLOSE + _exit_tree
	# + queue_free non devono mai produrre un doppio close.
	probe._exit_tree()
	assert_null(probe.get("_log_file"), "_exit_tree deve rilasciare l'handle")
	probe._exit_tree()
	assert_null(probe.get("_log_file"), "il secondo close deve essere un no-op")

	probe.queue_free()
	await wait_frames(1)
