## PerformanceManager — Dynamic FPS cap and window position persistence.
## Reduces GPU usage when the app is not focused (desktop companion pattern).
extends Node


func _ready() -> void:
	Engine.max_fps = Constants.FPS_FOCUSED
	get_viewport().focus_entered.connect(_on_focus_entered)
	get_viewport().focus_exited.connect(_on_focus_exited)
	SignalBus.load_completed.connect(_on_load_completed)
	AppLogger.info("PerformanceManager", "Initialized", {"fps": Engine.max_fps})


func _on_focus_entered() -> void:
	Engine.max_fps = Constants.FPS_FOCUSED


func _on_focus_exited() -> void:
	Engine.max_fps = Constants.FPS_UNFOCUSED


func _on_load_completed() -> void:
	var win_pos_x: int = SaveManager.get_setting("window_pos_x", -1)
	var win_pos_y: int = SaveManager.get_setting("window_pos_y", -1)
	if win_pos_x >= 0 and win_pos_y >= 0:
		var pos := Vector2i(win_pos_x, win_pos_y)
		if _is_position_on_screen(pos):
			get_window().position = pos
		else:
			(
				AppLogger
				. warn(
					"PerformanceManager",
					"Saved window position off-screen, using default",
					{
						"saved_pos": [win_pos_x, win_pos_y],
					}
				)
			)


func _is_position_on_screen(pos: Vector2i) -> bool:
	for i in DisplayServer.get_screen_count():
		var screen_rect := Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i))
		if screen_rect.has_point(pos):
			return true
	return false


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport:
		if viewport.focus_entered.is_connected(_on_focus_entered):
			viewport.focus_entered.disconnect(_on_focus_entered)
		if viewport.focus_exited.is_connected(_on_focus_exited):
			viewport.focus_exited.disconnect(_on_focus_exited)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var pos := get_window().position
		SignalBus.settings_updated.emit("window_pos_x", pos.x)
		SignalBus.settings_updated.emit("window_pos_y", pos.y)
