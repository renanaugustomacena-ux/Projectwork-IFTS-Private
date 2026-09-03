## test_review — regressioni della rilettura integrale del 2026-09-03.
## Il dialogo del tutorial non deve intercettare i click sul pavimento (A3),
## i toast non intercettano il mouse, il prompt "Premi E per pulire" tace su
## una pulizia gia` avviata, lo step "pulisci" del tutorial filtra per tipo,
## reset_all conserva le preferenze dell'installazione (F1), touch_size e`
## l'identita` su desktop, PanelManager conosce i 5 pannelli.
extends "res://tests/integration/test_base.gd"

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TutorialScript := preload("res://scripts/menu/tutorial_manager.gd")
const MessNodeScript := preload("res://scripts/rooms/mess_node.gd")
const PanelManagerScript := preload("res://scripts/ui/panel_manager.gd")

var _main_root: Node = null


func _setup_main_scene() -> void:
	if _main_root != null and is_instance_valid(_main_root):
		_main_root.queue_free()
		await wait_frames(1)
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	if scene == null:
		fail("main.tscn failed to load")
		return
	_main_root = scene.instantiate()
	add_child(_main_root)
	await wait_frames(3)


func _teardown_main_scene() -> void:
	if _main_root != null and is_instance_valid(_main_root):
		_main_root.queue_free()
		_main_root = null
		await wait_frames(1)


## Riproduce l'hit-test della GUI (Viewport._gui_find_control_at_pos): dal
## figlio piu` in alto verso il basso, il Control visibile piu` profondo che
## contiene il punto e non ha mouse_filter IGNORE. Cosi` il test dipende solo
## dalla configurazione dei nodi, non dall'hover del mouse in headless.
func _control_under(root: Node, pos: Vector2) -> Control:
	var children := root.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if child is Control:
			var c := child as Control
			if not c.visible or not c.get_global_rect().has_point(pos):
				continue
			var deeper := _control_under(c, pos)
			if deeper != null:
				return deeper
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return c
		elif child is Node:
			var deeper := _control_under(child, pos)
			if deeper != null:
				return deeper
	return null


func test_tutorial_dialog_does_not_swallow_floor_clicks() -> void:
	await _setup_main_scene()
	# Il tutorial parte solo se non completato: nel dubbio lo si istanzia qui,
	# come fa main._check_tutorial, per avere sempre un dialogo attivo.
	var tutorial: CanvasLayer = _main_root.get_node_or_null("TutorialManager") as CanvasLayer
	if tutorial == null:
		tutorial = CanvasLayer.new()
		tutorial.set_script(TutorialScript)
		tutorial.name = "TutorialManager"
		_main_root.add_child(tutorial)
		tutorial.call("start")
	await wait_frames(3)
	var dialog: Control = tutorial.get("_dialog_panel")
	assert_true(dialog != null and dialog.visible, "dialogo del tutorial visibile")
	var rect := dialog.get_global_rect()
	# Un punto del pavimento coperto dal rettangolo del dialogo (y ~560 e` nel
	# rombo del pavimento, main.tscn) non deve risolvere a un figlio del dialogo.
	var probe := Vector2(640.0, clampf(560.0, rect.position.y + 4.0, rect.end.y - 4.0))
	assert_true(rect.has_point(probe), "il punto sondato e` dentro il dialogo")
	var hit := _control_under(tutorial, probe)
	assert_true(
		hit == null,
		"nessun Control del tutorial intercetta il click a %s (colpito: %s)" % [probe, hit.name if hit else "nessuno"]
	)
	# Il bottone "Salta" invece deve restare cliccabile.
	var skip: Button = tutorial.get("_skip_btn")
	var skip_center := skip.get_global_rect().get_center()
	var skip_hit := _control_under(tutorial, skip_center)
	assert_eq(skip_hit, skip, "Salta e` il Control sotto il suo centro")
	await _teardown_main_scene()


func test_toast_container_ignores_mouse() -> void:
	await _setup_main_scene()
	var toasts: Node = _main_root.get_node_or_null("ToastManager")
	assert_true(toasts != null, "ToastManager presente nella scena")
	if toasts != null:
		var container: Control = toasts.get("_container")
		assert_eq(
			container.mouse_filter, Control.MOUSE_FILTER_IGNORE, "il contenitore dei toast non intercetta il mouse"
		)
	await _teardown_main_scene()


func test_mess_prompt_silent_while_cleaning() -> void:
	var persisted := {"mess_id": "crumbs_spot", "position": [640, 450], "spawned_at": 0.0, "cleaning_ends_at": 0.0}
	var entry := {
		"id": "crumbs_spot",
		"stress_weight": 0.06,
		"clean_reward": 2,
		"clean_duration_sec": 30.0,
		"placeholder_color": "#c2a677",
		"size_px": 16,
	}
	var mess: Area2D = MessNodeScript.new()
	mess.setup(entry, Vector2(640, 450), persisted)
	add_child(mess)
	await wait_frames(1)
	var counts := {"available": 0, "unavailable": 0}
	var on_avail := func(_id: String, _type: String) -> void: counts["available"] += 1
	var on_unavail := func() -> void: counts["unavailable"] += 1
	SignalBus.interaction_available.connect(on_avail)
	SignalBus.interaction_unavailable.connect(on_unavail)
	var body := CharacterBody2D.new()
	mess.call("_on_body_entered", body)
	mess.call("_on_body_entered", body)
	assert_eq(counts["available"], 1, "un solo prompt per ingresso su un mess sporco")
	mess.start_cleaning()
	assert_eq(counts["unavailable"], 1, "avviare la pulizia spegne il prompt")
	mess.call("_on_body_exited", body)
	assert_eq(counts["unavailable"], 1, "l'uscita non emette due volte")
	mess.call("_on_body_entered", body)
	assert_eq(counts["available"], 1, "nessun prompt su una pulizia gia` avviata")
	SignalBus.interaction_available.disconnect(on_avail)
	SignalBus.interaction_unavailable.disconnect(on_unavail)
	SaveManager.remove_mess(persisted)
	body.free()
	mess.free()


func test_tutorial_clean_step_filters_by_interaction_type() -> void:
	var tutorial := CanvasLayer.new()
	tutorial.set_script(TutorialScript)
	add_child(tutorial)
	await wait_frames(1)
	var steps: Array = tutorial.get("_steps")
	var clean_index := -1
	for i in steps.size():
		if str(steps[i].get("message", "")) == "TUTORIAL_STEP_CLEAN":
			clean_index = i
	assert_true(clean_index >= 0, "lo step TUTORIAL_STEP_CLEAN esiste")
	assert_eq(str(steps[clean_index].get("type_filter", "")), "clean", "lo step filtra per tipo 'clean'")
	tutorial.set("_current_step", clean_index)
	tutorial.set("_is_active", true)
	tutorial.call("_on_signal_received", "chair_1", "sit")
	assert_eq(int(tutorial.get("_current_step")), clean_index, "una sedia vicina non avanza lo step")
	tutorial.call("_on_signal_received", "crumbs_spot", "clean")
	assert_eq(int(tutorial.get("_current_step")), clean_index + 1, "un mess vicino avanza lo step")
	tutorial.set("_is_active", false)
	tutorial.queue_free()
	await wait_frames(1)


func test_reset_all_keeps_install_preferences() -> void:
	SignalBus.settings_updated.emit("language", "it")
	SignalBus.settings_updated.emit("master_volume", 0.41)
	SaveManager.inventory_data["coins"] = 12
	SignalBus.settings_updated.emit(BadgeManager.STAT_BADGES, ["first_decor"])
	SaveManager.reset_all()
	assert_eq(str(SaveManager.get_setting("language", "")), "it", "la lingua sopravvive al reset del profilo")
	assert_approx(float(SaveManager.get_setting("master_volume", 0.0)), 0.41, 0.001, "il volume sopravvive")
	assert_eq(int(SaveManager.inventory_data.get("coins", -1)), 0, "le monete ripartono da zero")
	var badges: Array = SaveManager.get_setting(BadgeManager.STAT_BADGES, [])
	assert_true(badges.is_empty(), "i badge dello slot vengono azzerati")
	SignalBus.settings_updated.emit("master_volume", 0.8)
	SaveManager.save_game()
	await wait_frames(1)


func test_touch_size_is_identity_on_desktop() -> void:
	if OS.has_feature("mobile"):
		assert_true(true, "su mobile il minimo e` 72x48: non testabile qui")
		return
	assert_eq(Helpers.touch_size(Vector2(72, 30)), Vector2(72, 30))
	assert_eq(Helpers.touch_size(Vector2.ZERO), Vector2.ZERO)


func test_panel_manager_knows_the_five_panels() -> void:
	var expected := ["deco", "profile", "profile_hud", "settings", "shop"]
	var keys: Array = PanelManagerScript.PANEL_SCENES.keys()
	keys.sort()
	assert_eq(keys, expected, "PANEL_SCENES ha esattamente i 5 pannelli documentati")
	for key: String in expected:
		assert_true(ResourceLoader.exists(PanelManagerScript.PANEL_SCENES[key]), "scena del pannello %s" % key)
