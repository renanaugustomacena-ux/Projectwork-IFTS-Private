## PanelManager — Manages panel lifecycle: instantiation, mutual exclusion, open/close.
## Ensures only one panel is open at a time. Handles Escape key to close.
class_name PanelManager
extends Node

const PANEL_SCENES: Dictionary = {
	"deco": "res://scenes/ui/deco_panel.tscn",
	"settings": "res://scenes/ui/settings_panel.tscn",
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

	# Fade in
	if _tween and _tween.is_running():
		_tween.kill()
		_tween = null
	_tween = create_tween()
	_tween.tween_property(_current_panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)

	SignalBus.panel_opened.emit(panel_name)
	AppLogger.info("PanelManager", "Panel opened", {"name": panel_name})


func close_current_panel() -> void:
	if _current_panel == null or not is_instance_valid(_current_panel):
		_current_panel = null
		_current_panel_name = ""
		return

	var closing_name := _current_panel_name
	var closing_panel := _current_panel

	_current_panel = null
	_current_panel_name = ""

	if _tween and _tween.is_running():
		_tween.kill()
		_tween = null
	_tween = create_tween()
	_tween.tween_property(closing_panel, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	_tween.tween_callback(closing_panel.queue_free)

	SignalBus.panel_closed.emit(closing_name)
	AppLogger.info("PanelManager", "Panel closed", {"name": closing_name})


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_panel_open():
			close_current_panel()
			get_viewport().set_input_as_handled()
