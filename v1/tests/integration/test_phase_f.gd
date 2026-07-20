## test_phase_f — regressioni della Fase F confermate dalla review avversariale.
##
## Ogni test qui sotto fallisce sul codice pre-fix. Coprono i tre modi in cui la
## Fase F poteva perdere dati (salvataggio prima del load, chiavi settings non
## dichiarate, contatori vita non azzerati dal reset profilo), il doppio
## conteggio del tempo di gioco, il loop ambience troncato e la rinomina del
## nodo Character che staccava il gatto dal personaggio.
extends "res://tests/integration/test_base.gd"

const AmbienceControllerScript := preload("res://scripts/systems/ambience_controller.gd")
const RoomBaseScript := preload("res://scripts/rooms/room_base.gd")
const SAVE_PATH := "user://save_data.json"

# ---- Settings: chiavi dichiarate, reset completo, roundtrip ----


func test_default_settings_declare_every_persisted_key() -> void:
	# Ogni chiave scritta via settings_updated DEVE avere un default: la
	# whitelist di _apply_save_data ammette solo chiavi gia` presenti, quindi
	# una chiave non dichiarata viene silenziosamente persa a ogni load.
	var persisted := [
		"ambience_enabled",
		"tutorial_completed",
		"mood_level",
		"profile_image_path",
		"stat_decos_placed_total",
		"stat_coins_earned_total",
		"stat_play_time_total",
	]
	for key: String in persisted:
		assert_true(
			SaveManager.DEFAULT_SETTINGS.has(key),
			"'%s' e` persistita ma non dichiarata nei default: il load la scarta" % key
		)


func test_reset_all_restores_every_default_key() -> void:
	# Generalizza il vecchio test su pet_variant: dopo un reset profilo NESSUNA
	# chiave dei default puo` mancare, o il valore caricato viene scartato.
	SaveManager.reset_all()
	var live: Dictionary = SaveManager.get("_settings")
	for key: String in SaveManager.DEFAULT_SETTINGS:
		assert_true(live.has(key), "reset_all() ha perso la chiave '%s'" % key)
	SaveManager.save_game()
	await wait_frames(1)


func test_ambience_enabled_roundtrips_through_save_and_load() -> void:
	var original: bool = bool(SaveManager.get_setting("ambience_enabled", true))
	SignalBus.settings_updated.emit("ambience_enabled", false)
	await wait_frames(1)
	SaveManager.save_game()
	await wait_frames(1)
	# Sporca il valore in memoria: se il load non lo ripristina, il default
	# vince e la preferenza risulta persa a ogni riavvio.
	SignalBus.settings_updated.emit("ambience_enabled", true)
	await wait_frames(1)
	SaveManager.load_game()
	await wait_frames(2)
	assert_eq(
		bool(SaveManager.get_setting("ambience_enabled", true)), false, "ambience_enabled deve sopravvivere a save+load"
	)
	SignalBus.settings_updated.emit("ambience_enabled", original)
	SaveManager.save_game()
	await wait_frames(1)


# ---- Latch: nessun salvataggio prima del load ----


func test_save_refused_before_state_is_loaded() -> void:
	# Riproduce il difetto CRITICAL: nel main menu load_game() non gira mai,
	# quindi _decorations/inventory/character_data sono ancora i default degli
	# autoload. Un auto-save in quella finestra sostituiva il profilo con monete
	# 0 e zero decorazioni, e dopo 4 giri il ring dei backup non conservava piu`
	# nemmeno una copia buona.
	SaveManager.add_decoration({"item_id": "phase_f_probe", "position": [1.0, 2.0]})
	SaveManager.save_game()
	await wait_frames(1)
	var decos_on_disk := _saved_decoration_count()
	assert_true(decos_on_disk > 0, "il profilo di partenza deve contenere una decorazione")

	var completed := {"ok": false}
	var on_completed := func() -> void: completed["ok"] = true
	SignalBus.save_completed.connect(on_completed)
	# Stato "come al boot nel main menu": niente load, memoria ai default.
	SaveManager.set("_full_state_loaded", false)
	SaveManager.set("_decorations", [])
	SaveManager.save_game()
	await wait_frames(1)
	SignalBus.save_completed.disconnect(on_completed)

	assert_false(completed["ok"], "save_game() non deve completare prima che uno stato reale sia caricato")
	assert_eq(_saved_decoration_count(), decos_on_disk, "il save rifiutato non deve azzerare le decorazioni su disco")
	assert_true(bool(SaveManager.get("_save_dirty")), "il dirty flag deve sopravvivere al rifiuto")

	# Ripristino: ricarica lo stato vero e togli la decorazione sonda.
	SaveManager.set("_full_state_loaded", true)
	SaveManager.load_game()
	await wait_frames(2)
	for deco in SaveManager.get_decorations().duplicate():
		if deco is Dictionary and deco.get("item_id", "") == "phase_f_probe":
			SaveManager.remove_decoration(deco)
	SaveManager.save_game()
	await wait_frames(1)


## Numero di decorazioni realmente presenti nel file di salvataggio.
## -1 quando il file manca o non e` leggibile.
func _saved_decoration_count() -> int:
	var count := -1
	if FileAccess.file_exists(SAVE_PATH):
		var wrapper := JSON.new()
		if wrapper.parse(FileAccess.get_file_as_string(SAVE_PATH)) == OK and wrapper.data is Dictionary:
			var payload := JSON.new()
			var inner := str((wrapper.data as Dictionary).get("data", ""))
			if payload.parse(inner) == OK and payload.data is Dictionary:
				var room: Variant = (payload.data as Dictionary).get("room", {})
				var decos: Variant = (room as Dictionary).get("decorations", []) if room is Dictionary else []
				count = (decos as Array).size() if decos is Array else -1
	return count


func test_load_reenables_saving() -> void:
	SaveManager.set("_full_state_loaded", false)
	SaveManager.load_game()
	await wait_frames(2)
	assert_true(
		bool(SaveManager.get("_full_state_loaded")), "dopo un load riuscito il salvataggio deve tornare possibile"
	)


# ---- BadgeManager: tempo di gioco e reset profilo ----


func test_play_time_is_not_double_counted_on_reload() -> void:
	var saved_base: int = int(BadgeManager.get("_play_time_base_sec"))
	var saved_start: int = int(BadgeManager.get("_session_start_ms"))
	var saved_setting: Variant = SaveManager.get_setting("stat_play_time_total", 0)

	# 7200 s in banca + 300 s di sessione corrente = 7500 s.
	BadgeManager.set("_play_time_base_sec", 7200)
	BadgeManager.set("_session_start_ms", Time.get_ticks_msec() - 300000)
	assert_in_range(float(BadgeManager.get_total_play_time_sec()), 7499.0, 7501.0, "totale iniziale")

	# Un tick persiste base+sessione; il load rilegge quel valore come nuova
	# base. Senza il rebase del clock di sessione i 300 s vengono contati due
	# volte a ogni ciclo e night_owl (1800 s) si sblocca in anticipo.
	BadgeManager._on_time_check()
	BadgeManager._on_load_completed()
	assert_in_range(
		float(BadgeManager.get_total_play_time_sec()),
		7499.0,
		7501.0,
		"il tempo di sessione non deve essere sommato due volte dopo un load"
	)

	BadgeManager.set("_play_time_base_sec", saved_base)
	BadgeManager.set("_session_start_ms", saved_start)
	SignalBus.settings_updated.emit("stat_play_time_total", saved_setting)
	await wait_frames(1)


func test_profile_reset_zeroes_lifetime_counters() -> void:
	var saved_decos: int = int(BadgeManager.get("_decorations_placed_total"))
	var saved_coins: int = int(BadgeManager.get("_coins_earned_total"))
	var saved_base: int = int(BadgeManager.get("_play_time_base_sec"))

	BadgeManager.set("_decorations_placed_total", 87)
	BadgeManager.set("_coins_earned_total", 9000)
	BadgeManager.set("_play_time_base_sec", 7200)
	SignalBus.profile_reset.emit()
	await wait_frames(1)

	# Senza questo, il primo arredo del profilo nuovo scriveva 88 nei settings
	# appena resettati e sbloccava cozy_collector (soglia 25) alla decorazione 1.
	assert_eq(int(BadgeManager.get_lifetime_decorations_placed()), 0, "decorazioni vita azzerate")
	assert_eq(int(BadgeManager.get_lifetime_coins_earned()), 0, "monete vita azzerate")
	assert_in_range(float(BadgeManager.get_total_play_time_sec()), 0.0, 2.0, "tempo di gioco azzerato")

	BadgeManager.set("_decorations_placed_total", saved_decos)
	BadgeManager.set("_coins_earned_total", saved_coins)
	BadgeManager.set("_play_time_base_sec", saved_base)


# ---- AmbienceController ----


func test_ambience_loop_spans_the_whole_file() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	var path: String = controller.resolve_path("ambience_fireplace")
	assert_false(path.is_empty(), "il catalogo deve risolvere ambience_fireplace")
	var wav := (load(path) as AudioStream).duplicate() as AudioStreamWAV
	assert_non_null(wav, "l'ambience deve essere un AudioStreamWAV")
	controller._apply_loop(wav)
	# I file sono importati QOA: data.size()/4 non e` il numero di frame e
	# tagliava il loop di 29 s a 5.85 s, con la giunzione crossfadata mai usata.
	var expected := int(wav.get_length() * float(wav.mix_rate))
	assert_eq(int(wav.loop_mode), int(AudioStreamWAV.LOOP_FORWARD), "il loop deve essere attivo")
	assert_in_range(float(wav.loop_end), float(expected) * 0.99, float(expected) * 1.01, "loop_end sull'intero file")
	assert_true(wav.loop_end > wav.data.size() / 4, "loop_end non deve derivare da data.size()")
	controller.queue_free()
	await wait_frames(1)


func test_ambience_start_does_not_mutate_the_cached_resource() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	controller.setup(func() -> float: return 0.0)
	controller.start("ambience_fireplace")
	await wait_frames(1)
	var path: String = controller.resolve_path("ambience_fireplace")
	var cached := load(path) as AudioStreamWAV
	# load() restituisce l'istanza condivisa: mutarla propagherebbe il loop a
	# ogni altro consumatore dello stesso file (playlist musicale inclusa).
	assert_eq(int(cached.loop_mode), int(AudioStreamWAV.LOOP_DISABLED), "la risorsa in cache non va mutata")
	controller.release_streams()
	controller.queue_free()
	await wait_frames(1)


func test_ambience_release_clears_active_ids() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	controller.setup(func() -> float: return 0.0)
	controller.start("ambience_fireplace")
	await wait_frames(1)
	assert_array_size(controller.get_active(), 1, "l'ambience avviata deve risultare attiva")
	controller.release_streams()
	# _active lasciato pieno faceva mentire get_active_ambience(), e quello
	# stato finto veniva persistito in music_state.active_ambience.
	assert_array_size(controller.get_active(), 0, "release_streams deve azzerare anche gli id attivi")
	assert_false(controller.is_playing(), "nessun player deve restare in riproduzione")
	controller.queue_free()
	await wait_frames(1)


func test_ambience_stop_erases_id_without_player() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	controller.setup(func() -> float: return 0.0)
	controller.start("ambience_fireplace")
	await wait_frames(1)
	controller.release_streams()
	# Divergenza forzata: se stop() uscisse prima di ripulire _active, l'id
	# resterebbe attivo per sempre e nemmeno stop_all() potrebbe recuperarlo.
	controller.get("_active").append("ambience_fireplace")
	controller.stop_all()
	assert_array_size(controller.get_active(), 0, "stop() deve ripulire _active anche senza player")
	controller.queue_free()
	await wait_frames(1)


# ---- RoomBase: swap personaggio ----


func test_character_swap_keeps_node_named_character() -> void:
	var room := _build_room_with_character()
	await wait_frames(1)
	var pet := _spawn_probe_pet(room)
	await wait_frames(1)

	room._on_character_changed("male_rose")
	await wait_frames(1)

	# queue_free() e` differito: senza remove_child il vecchio nodo occupava
	# ancora il nome e Godot rinominava il nuovo in "@CharacterBody2D@N".
	var found: Node = room.get_node_or_null("Character")
	assert_non_null(found, "dopo lo swap deve esistere un nodo chiamato 'Character'")
	assert_eq(str(room.character_node.name), "Character", "il nuovo personaggio deve conservare il nome")
	assert_true(is_instance_valid(room.character_node), "il personaggio attivo non deve essere liberato")

	# Il pet risolve il bersaglio per nome: se lo swap lo rinomina, l'FSM resta
	# muta (niente FOLLOW, niente reazione di prossimita`) per tutta la sessione.
	pet._find_character()
	var target: Variant = pet.get("_character_ref")
	assert_true(target != null and is_instance_valid(target), "il pet deve ritrovare il personaggio dopo lo swap")
	assert_eq(target, room.character_node, "il pet deve puntare al personaggio attivo, non a quello liberato")

	room.queue_free()
	await wait_frames(1)


func _build_room_with_character() -> Node2D:
	# Struttura minima attesa dagli @onready di room_base.gd (come main.tscn).
	var room := Node2D.new()
	room.name = "TestRoom"

	var decorations := Node2D.new()
	decorations.name = "Decorations"
	room.add_child(decorations)

	var character: Node = (load("res://scenes/male-old-character.tscn") as PackedScene).instantiate()
	character.name = "Character"
	character.position = Vector2(640, 480)
	room.add_child(character)

	var bounds := StaticBody2D.new()
	bounds.name = "RoomBounds"
	var floor_poly := CollisionPolygon2D.new()
	floor_poly.name = "FloorBounds"
	floor_poly.polygon = PackedVector2Array(
		[Vector2(640, 265), Vector2(1100, 480), Vector2(640, 685), Vector2(180, 480)]
	)
	bounds.add_child(floor_poly)
	room.add_child(bounds)

	room.set_script(RoomBaseScript)
	add_child(room)
	return room


func _spawn_probe_pet(room: Node2D) -> Node:
	var pet: Node = (load("res://scenes/cat_void.tscn") as PackedScene).instantiate()
	pet.name = "ProbePet"
	room.add_child(pet)
	return pet
