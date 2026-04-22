## PanelManager — Manages panel lifecycle: instantiation, mutual exclusion, open/close.
## Ensures only one panel is open at a time. Handles Escape key to close.
class_name PanelManager
extends Node

const PANEL_SCENES: Dictionary = {
	"deco": "res://scenes/ui/deco_panel.tscn",
	"settings": "res://scenes/ui/settings_panel.tscn",
	"profile": "res://scenes/ui/profile_panel.tscn",
	"profile_hud": "res://scenes/ui/profile_hud_panel.tscn",
}

var _ui_layer: CanvasLayer = null
var _current_panel: PanelContainer = null
var _current_panel_name: String = ""
var _scene_cache: Dictionary = {}
var _tween: Tween = null


func initialize(ui_layer: CanvasLayer) -> void:
	if ui_layer == null:
		AppLogger.error("PanelManager", "UI layer is null")
		return
	_ui_layer = ui_layer


func toggle_panel(panel_name: String) -> void:
	if _current_panel_name == panel_name:
		close_current_panel()
	else:
		if _current_panel != null:
			_close_immediate()
		open_panel(panel_name)


func open_panel(panel_name: String) -> void:
	if _ui_layer == null:
		AppLogger.warn("PanelManager", "UI layer not initialized")
		return

	var scene := _load_panel_scene(panel_name)
	if scene == null:
		return

	_current_panel = scene.instantiate() as PanelContainer
	if _current_panel == null:
		AppLogger.error("PanelManager", "Failed to instantiate panel", {"name": panel_name})
		return

	_current_panel_name = panel_name
	_current_panel.modulate.a = 0.0
	_ui_layer.add_child(_current_panel)
	_grab_focus_recursive(_current_panel)

	# Fade in
	if _tween and _tween.is_running():
		_tween.kill()
		_tween = null
	_tween = create_tween()
	_tween.tween_property(_current_panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)

	SignalBus.panel_opened.emit(panel_name)
	AppLogger.info("PanelManager", "Panel opened", {"name": panel_name})


func _grab_focus_recursive(node: Node) -> bool:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.visible:
		node.grab_focus()
		return true
	for child in node.get_children():
		if _grab_focus_recursive(child):
			return true
	return false


func close_current_panel() -> void:
	if _current_panel == null or not is_instance_valid(_current_panel):
		_current_panel = null
		_current_panel_name = ""
		return

	# Se il panel corrente sta gia` fadendo out, non ri-avviare il tween:
	# l'ulteriore click e` rumore, il panel sta gia` chiudendosi.
	if _current_panel.get_meta("closing", false):
		return

	var closing_name := _current_panel_name
	var closing_panel := _current_panel
	closing_panel.set_meta("closing", true)
	closing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Rilascia focus esplicito se il panel che si sta chiudendo lo aveva grabbato.
	# Godot 4.5 non auto-rilascia il focus al queue_free, e il focus residuo su un
	# Button figlio del panel blocca Input.get_vector() del character_controller
	# (root cause di B-001 movimento personaggio).
	var viewport := closing_panel.get_viewport()
	if viewport != null:
		var focus_owner := viewport.gui_get_focus_owner()
		if focus_owner != null and closing_panel.is_ancestor_of(focus_owner):
			viewport.gui_release_focus()

	if _tween and _tween.is_running():
		_tween.kill()
		_tween = null
	_tween = create_tween()
	_tween.tween_property(closing_panel, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	# Clear state SOLO al termine del tween, cosi` toggle_panel durante il fade
	# vede il panel come ancora corrente e puo` decidere close vs swap coerente.
	_tween.tween_callback(func() -> void:
		if _current_panel == closing_panel:
			_current_panel = null
			_current_panel_name = ""
		closing_panel.queue_free()
		SignalBus.panel_closed.emit(closing_name)
	)
	AppLogger.info("PanelManager", "Panel closing", {"name": closing_name})


func is_panel_open() -> bool:
	return _current_panel != null and is_instance_valid(_current_panel)


func get_current_panel_name() -> String:
	return _current_panel_name


func _close_immediate() -> void:
	if _current_panel == null or not is_instance_valid(_current_panel):
		_current_panel = null
		_current_panel_name = ""
		return

	if _tween and _tween.is_running():
		_tween.kill()
		_tween = null

	var closing_name := _current_panel_name
	_current_panel.queue_free()
	_current_panel = null
	_current_panel_name = ""
	SignalBus.panel_closed.emit(closing_name)


func _load_panel_scene(panel_name: String) -> PackedScene:
	if panel_name in _scene_cache:
		return _scene_cache[panel_name]

	var path: String = PANEL_SCENES.get(panel_name, "")
	if path.is_empty():
		AppLogger.error("PanelManager", "Unknown panel name", {"name": panel_name})
		return null

	if not ResourceLoader.exists(path):
		AppLogger.error("PanelManager", "Panel scene not found", {"path": path})
		return null

	var scene := load(path) as PackedScene
	if scene:
		_scene_cache[panel_name] = scene
	return scene


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if _current_panel and is_instance_valid(_current_panel):
		_current_panel.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_panel_open():
			close_current_panel()
			get_viewport().set_input_as_handled()
