## TutorialManager — Scripted tutorial mission for first-time players.
## Guides the player through room mechanics step-by-step.
extends CanvasLayer

signal tutorial_completed
signal tutorial_skipped

const STEP_TIMEOUT := 30.0
const ARROW_ANIMATE_SPEED := 2.0

## Tutorial steps — each step waits for a specific signal or action.
var _steps: Array[Dictionary] = []
var _current_step: int = -1
var _is_active: bool = false
var _step_timer: float = 0.0

# UI nodes
var _overlay: ColorRect = null
var _dialog_panel: PanelContainer = null
var _dialog_label: RichTextLabel = null
var _progress_label: Label = null
var _skip_btn: Button = null
var _arrow: Label = null
var _tween: Tween = null


func _ready() -> void:
	layer = 100  # On top of everything
	_build_ui()
	_define_steps()


func start() -> void:
	if _is_active:
		return
	_is_active = true
	_current_step = -1
	visible = true
	_advance_step()
	AppLogger.info("Tutorial", "Tutorial started", {})


func _define_steps() -> void:
	_steps = [
		{
			"message": (
				"Welcome to your [b]Mini Cozy Room[/b]! 🏠\n"
				+ "This is your personal space. "
				+ "Let's make it yours!"
			),
			"signal_name": "",
			"auto_advance": 3.0,
		},
		{
			"message": (
				"Use [b]WASD[/b] or [b]Arrow Keys[/b] "
				+ "to walk around.\n"
				+ "Try moving your character now!"
			),
			"signal_name": "",
			"wait_for_input": "movement",
		},
		{
			"message": (
				"Open the [b]Decorations[/b] panel "
				+ "to furnish your room.\n"
				+ "Click the [b]Decor[/b] button below! ⬇"
			),
			"signal_name": "panel_opened",
			"signal_filter": "deco",
			"arrow_target": "DecoButton",
		},
		{
			"message": (
				"Browse the categories and [b]drag[/b] "
				+ "a decoration into your room!\n"
				+ "Try adding a bed or desk."
			),
			"signal_name": "decoration_placed",
		},
		{
			"message": (
				"Excellent! Click on any decoration "
				+ "to select it.\n"
				+ "Then use [b]R[/b] to rotate, "
				+ "[b]+/-[/b] to resize, "
				+ "or [b]Del[/b] to remove it."
			),
			"signal_name": "decoration_selected",
		},
		{
			"message": (
				"Walk up to furniture and press "
				+ "[b]E[/b] to interact!\n"
				+ "Try sitting on a chair "
				+ "or laying on a bed."
			),
			"signal_name": "interaction_started",
		},
		{
			"message": (
				"Open [b]Settings[/b] to adjust volume "
				+ "and language.\n"
				+ "Click the Settings button! ⬇"
			),
			"signal_name": "panel_opened",
			"signal_filter": "settings",
			"arrow_target": "SettingsButton",
		},
		{
			"message": (
				"Check your [b]Profile[/b] to see "
				+ "your account info.\n"
				+ "Click the Profile button! ⬇"
			),
			"signal_name": "panel_opened",
			"signal_filter": "profile",
			"arrow_target": "ProfileButton",
		},
		{
			"message": (
				"Press [b]Escape[/b] to close any panel.\n"
				+ "Try it now!"
			),
			"signal_name": "panel_closed",
		},
		{
			"message": (
				"Your room saves [b]automatically[/b]! ✓\n\n"
				+ "[b]Mission Complete![/b] 🎉\n"
				+ "Enjoy your Mini Cozy Room!"
			),
			"signal_name": "",
			"auto_advance": 4.0,
			"is_final": true,
		},
	]


func _build_ui() -> void:
	# Semi-transparent border overlay (doesn't block center)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Dialog panel at bottom
	_dialog_panel = PanelContainer.new()
	_dialog_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog_panel.anchor_top = 0.75
	_dialog_panel.offset_top = 0
	_dialog_panel.offset_bottom = -50
	_dialog_panel.offset_left = 80
	_dialog_panel.offset_right = -80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.45, 0.35, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_dialog_panel.add_theme_stylebox_override(
		"panel", style
	)
	add_child(_dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_dialog_panel.add_child(vbox)

	# Message text
	_dialog_label = RichTextLabel.new()
	_dialog_label.bbcode_enabled = true
	_dialog_label.fit_content = true
	_dialog_label.scroll_active = false
	_dialog_label.custom_minimum_size = Vector2(0, 60)
	_dialog_label.add_theme_font_size_override(
		"normal_font_size", 16
	)
	_dialog_label.add_theme_color_override(
		"default_color", Color(0.9, 0.85, 0.75, 1.0)
	)
	vbox.add_child(_dialog_label)

	# Bottom row: progress + skip
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override(
		"font_color", Color(0.6, 0.55, 0.5, 0.6)
	)
	_progress_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	hbox.add_child(_progress_label)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip Tutorial"
	_skip_btn.flat = true
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.add_theme_color_override(
		"font_color", Color(0.6, 0.55, 0.5, 0.8)
	)
	_skip_btn.pressed.connect(_on_skip)
	hbox.add_child(_skip_btn)

	# Arrow indicator
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 24)
	_arrow.add_theme_color_override(
		"font_color", Color(1.0, 0.9, 0.4, 0.9)
	)
	_arrow.visible = false
	_arrow.z_index = 101
	add_child(_arrow)

	visible = false


func _advance_step() -> void:
	_current_step += 1
	if _current_step >= _steps.size():
		_finish()
		return

	var step: Dictionary = _steps[_current_step]
	_dialog_label.text = step.get("message", "")
	_progress_label.text = "Step %d / %d" % [
		_current_step + 1, _steps.size()
	]
	_step_timer = 0.0
	_arrow.visible = false

	# Disconnect previous signal listeners
	_disconnect_all_signals()

	# Auto-advance step (timed, no signal)
	var auto_time: float = step.get("auto_advance", 0.0)
	if auto_time > 0.0:
		if _tween and _tween.is_running():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_interval(auto_time)
		_tween.tween_callback(_advance_step)
		return

	# Movement detection step
	if step.has("wait_for_input"):
		# Handled in _process, just wait for input
		return

	# Signal-based step
	var sig_name: String = step.get("signal_name", "")
	if not sig_name.is_empty() and SignalBus.has_signal(sig_name):
		var sig: Signal = SignalBus.get(sig_name)
		if sig.get_connections().size() < 10:
			sig.connect(
				_on_signal_received.bind(sig_name),
				CONNECT_ONE_SHOT
			)

	# Show arrow pointing to a specific button
	var arrow_target: String = step.get("arrow_target", "")
	if not arrow_target.is_empty():
		_show_arrow(arrow_target)

	# Fade in dialog
	_animate_dialog_in()


## Variadic-style signal handler. The signal can emit 0..2 args; the bind()
## appends `sig_name` always as the LAST arg. So the callable is invoked as:
##   0-arg signal -> (sig_name)
##   1-arg signal -> (a, sig_name)
##   2-arg signal -> (a, b, sig_name)
## Accept up to 3 args with defaults so any signal arity works without crash.
func _on_signal_received(
	a: Variant = null,
	b: Variant = null,
	c: Variant = null,
) -> void:
	var step: Dictionary = _steps[_current_step]
	var filter: String = step.get("signal_filter", "")
	if not filter.is_empty():
		var received: String = ""
		if a is String:
			received = a
		if filter not in received:
			var sig_name: String = step.get("signal_name", "")
			if SignalBus.has_signal(sig_name):
				var sig: Signal = SignalBus.get(sig_name)
				sig.connect(
					_on_signal_received.bind(sig_name),
					CONNECT_ONE_SHOT
				)
			return
	var _unused := [a, b, c]
	_advance_step()


func _process(delta: float) -> void:
	if not _is_active:
		return

	_step_timer += delta

	# Movement detection
	if _current_step >= 0 and _current_step < _steps.size():
		var step: Dictionary = _steps[_current_step]
		if step.has("wait_for_input"):
			var dir := Input.get_vector(
				"ui_left", "ui_right", "ui_up", "ui_down"
			)
			if dir.length() > 0.1:
				_advance_step()
				return

	# Step timeout — auto-advance with help message
	if _step_timer > STEP_TIMEOUT:
		_advance_step()

	# Animate arrow
	if _arrow.visible:
		_arrow.position.y += sin(
			Time.get_ticks_msec() / 300.0
		) * 0.3


func _show_arrow(target_name: String) -> void:
	# Find the target button in the scene tree
	var target := _find_node_by_name(get_tree().root, target_name)
	if target is Control:
		var pos: Vector2 = target.global_position
		_arrow.position = Vector2(
			pos.x + target.size.x / 2.0 - 12,
			pos.y - 30
		)
		_arrow.visible = true


func _find_node_by_name(
	root: Node, node_name: String
) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _animate_dialog_in() -> void:
	if _dialog_panel == null:
		return
	_dialog_panel.modulate.a = 0.0
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(
		_dialog_panel, "modulate:a", 1.0, 0.3
	)


func _on_skip() -> void:
	_is_active = false
	visible = false
	_disconnect_all_signals()
	tutorial_skipped.emit()
	AppLogger.info("Tutorial", "Tutorial skipped", {
		"step": _current_step
	})
	queue_free()


func _finish() -> void:
	_is_active = false
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.0)
	_tween.tween_property(_dialog_panel, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(_on_tutorial_done)


func _on_tutorial_done() -> void:
	visible = false
	_disconnect_all_signals()
	tutorial_completed.emit()
	AppLogger.info("Tutorial", "Tutorial completed", {})
	queue_free()


func _disconnect_all_signals() -> void:
	for step in _steps:
		var sig_name: String = step.get("signal_name", "")
		if sig_name.is_empty():
			continue
		if not SignalBus.has_signal(sig_name):
			continue
		var sig: Signal = SignalBus.get(sig_name)
		for conn in sig.get_connections():
			if conn["callable"].get_object() == self:
				sig.disconnect(conn["callable"])


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_disconnect_all_signals()
	if _skip_btn and _skip_btn.pressed.is_connected(_on_skip):
		_skip_btn.pressed.disconnect(_on_skip)
