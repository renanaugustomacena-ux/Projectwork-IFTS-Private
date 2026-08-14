## test_slots — 10 slot di salvataggio (fase 4, spec 2026-08-14).
##
## Contratto: slot 1 = percorsi storici invariati (i profili esistenti sono
## gia' "slot 1"); slot N in user://slots/slot_NN/; cambio slot = stato RAM
## ai default + settings ri-bootstrappati; i file degli altri slot restano
## intoccati. Tutto gira nella sandbox user:// della suite.
extends "res://tests/integration/test_base.gd"

var _original_slot: int = 1


func _setup() -> void:
	_original_slot = SaveManager.active_slot


func _teardown_to_original() -> void:
	SaveManager.set_active_slot(_original_slot)
	SaveManager.load_game()
	await wait_frames(2)


func test_slot_path_mapping() -> void:
	assert_eq(SaveManager.slot_path("user://save_data.json", 1), "user://save_data.json", "slot 1 = legacy path")
	assert_eq(
		SaveManager.slot_path("user://save_data.json", 3),
		"user://slots/slot_03/save_data.json",
		"slot N ha il prefisso directory"
	)
	assert_eq(
		SaveManager.slot_path("user://save_data.backup.2.json", 10), "user://slots/slot_10/save_data.backup.2.json"
	)


func test_switching_slot_isolates_state() -> void:
	_setup()
	# Stato riconoscibile nello slot corrente, salvato su disco.
	SaveManager.inventory_data["coins"] = 77
	SaveManager.save_game()
	await wait_frames(1)
	var here := SaveManager.active_slot
	var target: int = SaveManager.MAX_SLOTS if here != SaveManager.MAX_SLOTS else SaveManager.MAX_SLOTS - 1

	SaveManager.set_active_slot(target)
	assert_eq(SaveManager.active_slot, target)
	assert_eq(int(SaveManager.inventory_data.get("coins", -1)), 0, "il nuovo slot parte dai default in RAM")
	assert_false(SaveManager.slot_has_save(target), "slot di destinazione vuoto")
	assert_true(SaveManager.slot_has_save(here), "il vecchio slot conserva il suo file")

	# Il peek del vecchio slot legge i 77 coins SENZA applicarli.
	var meta := SaveManager.peek_slot(here)
	assert_true(bool(meta.get("exists", false)))
	assert_eq(int(meta.get("coins", -1)), 77, "peek non-distruttivo del vecchio slot")
	assert_eq(int(SaveManager.inventory_data.get("coins", -1)), 0, "peek non tocca la RAM")

	# Salvare nel nuovo slot crea il file nel posto giusto e non tocca l'altro.
	SaveManager.load_game()  # "niente da caricare" sblocca il latch F.7
	await wait_frames(1)
	SaveManager.inventory_data["coins"] = 5
	SaveManager.save_game()
	await wait_frames(1)
	assert_true(FileAccess.file_exists(SaveManager.slot_path(SaveManager.SAVE_PATH, target)), "file dello slot creato")
	assert_eq(int(SaveManager.peek_slot(here).get("coins", -1)), 77, "l'altro slot resta a 77")

	# Pulizia: cancella lo slot di test e torna all'originale.
	SaveManager.delete_slot_files(target)
	assert_false(SaveManager.slot_has_save(target), "delete_slot_files rimuove il save")
	await _teardown_to_original()
	assert_eq(int(SaveManager.inventory_data.get("coins", -1)), 77, "rientro nello slot originale con i suoi dati")


func test_first_empty_slot_and_any_slot() -> void:
	_setup()
	assert_true(SaveManager.any_slot_has_save() or not SaveManager.slot_has_save(1))
	var empty := SaveManager.first_empty_slot()
	if empty > 0:
		assert_false(SaveManager.slot_has_save(empty), "first_empty_slot e` davvero vuoto")


func test_peek_empty_slot() -> void:
	var empty := SaveManager.first_empty_slot()
	if empty < 0:
		assert_true(true, "tutti pieni: niente da verificare")
		return
	var meta := SaveManager.peek_slot(empty)
	assert_false(bool(meta.get("exists", true)), "peek su slot vuoto: exists=false")
