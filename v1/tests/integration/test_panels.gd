## test_panels — PanelManager lifecycle, mutual exclusion, Esc handler.
extends "res://tests/integration/test_base.gd"

var _ui_layer: CanvasLayer = null
var _panel_manager: Node = null


func _build_panel_manager() -> void:
	if _panel_manager != null and is_instance_valid(_panel_manager):
		_panel_manager.queue_free()
	if _ui_layer != null and is_instance_valid(_ui_layer):
		_ui_layer.queue_free()
	await wait_frames(1)
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	# PanelManager is a class_name Node, instantiate directly
	var PanelManagerScript: GDScript = load("res://scripts/ui/panel_manager.gd")
	_panel_manager = PanelManagerScript.new()
	add_child(_panel_manager)
	_panel_manager.initialize(_ui_layer)


func test_panel_scenes_exist() -> void:
	# Each registered panel name must map to an existing scene
	var registered: Dictionary = {
		"deco": "res://scenes/ui/deco_panel.tscn",
		"settings": "res://scenes/ui/settings_panel.tscn",
		"profile": "res://scenes/ui/profile_panel.tscn",
		"profile_hud": "res://scenes/ui/profile_hud_panel.tscn",
	}
	for name in registered:
		assert_true(ResourceLoader.exists(registered[name]),
			"panel scene missing: %s" % registered[name])


func test_open_deco_panel() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("deco")
	await wait_frames(2)
	assert_true(_panel_manager.is_panel_open(), "deco should be open")
	assert_eq(_panel_manager.get_current_panel_name(), "deco")


func test_open_settings_panel() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("settings")
	await wait_frames(2)
	assert_true(_panel_manager.is_panel_open())
	assert_eq(_panel_manager.get_current_panel_name(), "settings")


func test_open_profile_panel() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("profile")
	await wait_frames(2)
	assert_true(_panel_manager.is_panel_open())
	assert_eq(_panel_manager.get_current_panel_name(), "profile")


func test_open_profile_hud_panel() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("profile_hud")
	await wait_frames(2)
	assert_true(_panel_manager.is_panel_open())
	assert_eq(_panel_manager.get_current_panel_name(), "profile_hud")


func test_toggle_same_panel_closes_it() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("settings")
	await wait_frames(2)
	assert_true(_panel_manager.is_panel_open())
	_panel_manager.toggle_panel("settings")
	await wait_frames(3)  # allow fade-out tween to complete before checking
	# After the fade-out + queue_free, no panel should be open
	assert_false(_panel_manager.is_panel_open())
	assert_eq(_panel_manager.get_current_panel_name(), "")


func test_mutual_exclusion_switching_panels() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("deco")
	await wait_frames(2)
	assert_eq(_panel_manager.get_current_panel_name(), "deco")
	# Switching to another panel should close deco and open settings
	_panel_manager.toggle_panel("settings")
	await wait_frames(2)
	assert_eq(_panel_manager.get_current_panel_name(), "settings")


func test_unknown_panel_name_does_not_crash() -> void:
	await _build_panel_manager()
	_panel_manager.toggle_panel("does_not_exist")
	await wait_frames(2)
	# Should log error but not crash / not open anything
	assert_false(_panel_manager.is_panel_open())


func test_panel_signals_emitted() -> void:
	await _build_panel_manager()
	var opened_received: Array[String] = []
	var closed_received: Array[String] = []
	var on_opened := func(name: String) -> void: opened_received.append(name)
	var on_closed := func(name: String) -> void: closed_received.append(name)
	SignalBus.panel_opened.connect(on_opened)
	SignalBus.panel_closed.connect(on_closed)
	_panel_manager.toggle_panel("settings")
	await wait_frames(2)
	_panel_manager.toggle_panel("settings")
	await wait_frames(3)
	SignalBus.panel_opened.disconnect(on_opened)
	SignalBus.panel_closed.disconnect(on_closed)
	assert_true("settings" in opened_received, "panel_opened must fire with name")
	assert_true("settings" in closed_received, "panel_closed must fire with name")
