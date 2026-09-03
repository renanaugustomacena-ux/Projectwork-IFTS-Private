## test_polish — regressioni della sessione di rifinitura 2026-09-03 (v1.3.0).
## Copre i difetti trovati dallo studio del codice: lingua che cambiava da
## sola al secondo avvio (PT-09), impostazioni perse nel menu (SM-02), badge
## per slot (DB-02), password senza tetto (DB-14), prompt delle sedie
## (GP-08), segnali morti (SM-27), tempo residuo delle pulizie (PT-29).
extends "res://tests/integration/test_base.gd"

const SeatAreaScript := preload("res://scripts/rooms/seat_area.gd")
const MessNodeScript := preload("res://scripts/rooms/mess_node.gd")
const PetScript := preload("res://scripts/rooms/pet_controller.gd")


func test_adopt_language_becomes_explicit_choice() -> void:
	var before_explicit := SaveManager.has_explicit_language()
	var before_lang := str(SaveManager.get_setting("language", ""))
	SaveManager.adopt_language("it")
	assert_true(SaveManager.has_explicit_language(), "la lingua risolta dal sistema diventa esplicita")
	assert_eq(str(SaveManager.get_setting("language", "")), "it")
	# Ripristino (settings_updated marca esplicita comunque: e` il default del gioco reale).
	SignalBus.settings_updated.emit("language", before_lang)
	if not before_explicit:
		SaveManager.set("_language_explicit", false)


func test_settings_only_save_keeps_room_state_from_menu() -> void:
	# Stato "menu": latch F.7 spento, RAM ai default. Un cambio di volume da
	# Opzioni deve finire su disco SENZA toccare le decorazioni salvate.
	SaveManager.add_decoration({"item_id": "polish_probe", "position": [3.0, 4.0]})
	SaveManager.save_game()
	await wait_frames(1)
	var path: String = SaveManager.call("_p", SaveManager.SAVE_PATH)
	var on_disk: Dictionary = SaveManager.call("_peek_save_payload", path)
	var decos_before: int = (on_disk.get("room", {}) as Dictionary).get("decorations", []).size()
	assert_true(decos_before > 0, "profilo di partenza con almeno una decorazione")

	var completed := {"ok": false}
	var on_completed := func() -> void: completed["ok"] = true
	SignalBus.save_completed.connect(on_completed)
	SaveManager.set("_full_state_loaded", false)
	SaveManager.set("_decorations", [])
	SignalBus.settings_updated.emit("master_volume", 0.33)
	SaveManager.save_game()
	await wait_frames(1)
	SignalBus.save_completed.disconnect(on_completed)

	on_disk = SaveManager.call("_peek_save_payload", path)
	var decos_after: int = (on_disk.get("room", {}) as Dictionary).get("decorations", []).size()
	assert_eq(decos_after, decos_before, "le decorazioni su disco non cambiano")
	assert_approx(float((on_disk.get("settings", {}) as Dictionary).get("master_volume", 0.0)), 0.33, 0.001)
	assert_false(completed["ok"], "nessun save_completed: non e` un salvataggio di partita")

	# Ripristino dello stato reale.
	SaveManager.set("_full_state_loaded", true)
	SaveManager.load_game()
	await wait_frames(2)
	for deco in SaveManager.get_decorations().duplicate():
		if deco is Dictionary and deco.get("item_id", "") == "polish_probe":
			SaveManager.remove_decoration(deco)
	SignalBus.settings_updated.emit("master_volume", 0.8)
	SaveManager.save_game()
	await wait_frames(1)


func test_badges_live_in_the_slot_save() -> void:
	SignalBus.settings_updated.emit(BadgeManager.STAT_BADGES, [])
	BadgeManager.call("_on_profile_reset")
	BadgeManager.call("_try_unlock", "first_decor")
	var stored: Array = SaveManager.get_setting(BadgeManager.STAT_BADGES, [])
	assert_true("first_decor" in stored, "lo sblocco finisce nei settings per-slot")
	assert_eq(BadgeManager.get_unlocked_badges().size(), 1)
	BadgeManager.call("_try_unlock", "first_decor")
	assert_eq(BadgeManager.get_unlocked_badges().size(), 1, "idempotente")
	BadgeManager.call("_on_profile_reset")
	assert_eq(BadgeManager.get_unlocked_badges().size(), 0, "profile_reset azzera i badge in RAM")
	SignalBus.settings_updated.emit(BadgeManager.STAT_BADGES, [])


func test_password_length_has_a_ceiling() -> void:
	var too_long := "a".repeat(Constants.AUTH_MAX_PASSWORD_LENGTH + 1)
	var reg: Dictionary = AuthManager.register("polish_user_zz", too_long)
	assert_eq(str(reg.get("error", "")), "UI_AUTH_ERR_PASSWORD_TOO_LONG")
	var login: Dictionary = AuthManager.login("polish_user_zz", too_long)
	assert_eq(str(login.get("error", "")), "UI_AUTH_ERR_INVALID_CREDENTIALS", "rifiuto prima di qualsiasi hashing")


func test_seat_area_announces_interaction_prompt() -> void:
	var seat := Sprite2D.new()
	seat.texture = PlaceholderTexture2D.new()
	add_child(seat)
	var area: Area2D = SeatAreaScript.new()
	area.seat = seat
	area.item_id = "chair_1"
	add_child(area)
	var received := {"available": 0, "type": "", "unavailable": 0}
	var on_avail := func(_id: String, itype: String) -> void:
		received["available"] += 1
		received["type"] = itype
	var on_unavail := func() -> void: received["unavailable"] += 1
	SignalBus.interaction_available.connect(on_avail)
	SignalBus.interaction_unavailable.connect(on_unavail)
	var body := CharacterBody2D.new()
	area.call("_on_body_entered", body)
	area.call("_on_body_entered", body)
	area.call("_on_body_exited", body)
	SignalBus.interaction_available.disconnect(on_avail)
	SignalBus.interaction_unavailable.disconnect(on_unavail)
	assert_eq(received["available"], 1, "un solo prompt per ingresso")
	assert_eq(received["type"], "sit")
	assert_eq(received["unavailable"], 1)
	body.free()
	area.free()
	seat.free()


func test_mess_time_left_format() -> void:
	assert_eq(MessNodeScript.format_time_left(90.0), "1:30")
	assert_eq(MessNodeScript.format_time_left(7.0), "0:07")
	assert_eq(MessNodeScript.format_time_left(3700.0), "1:01 h")


func test_first_potty_is_demo_friendly() -> void:
	assert_true(PetScript.FIRST_POTTY_MAX_SEC <= 600.0, "primo bisogno entro 10 minuti (PT-24)")
	assert_true(PetScript.MAX_OFFLINE_POTTIES <= 3, "rientro senza punizioni (PT-25)")
	assert_eq(PetScript.trust_tier(35.0), "neutral", "un gatto nuovo non scappa (PT-20)")


func test_dead_signals_are_gone() -> void:
	for dead: String in ["pet_fed", "pet_trust_changed", "shop_item_purchased", "decoration_moved", "outfit_changed"]:
		assert_false(SignalBus.has_signal(dead), "%s era emesso nel vuoto (SM-27)" % dead)
	assert_true(SignalBus.has_signal("panel_opened"), "i segnali consumati dal tutorial restano")
