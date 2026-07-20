## TutorialManager — Scripted tutorial mission for first-time players.
## Guides the player through room mechanics step-by-step.
extends CanvasLayer

signal tutorial_completed
signal tutorial_skipped

const STEP_TIMEOUT := 30.0

## Tutorial steps — each step waits for a specific signal or action.
var _steps: Array[Dictionary] = []
var _current_step: int = -1
var _is_active: bool = false
var _step_timer: float = 0.0

## Stateful per-step SignalBus connection handle. Exactly one connection is
## alive at a time; it is created in _advance_step and torn down in
## _disconnect_step_signal on accept, step change, skip, finish or exit.
var _step_signal_name: String = ""
var _step_callable: Callable = Callable()

# UI nodes
var _overlay: ColorRect = null
var _dialog_panel: PanelContainer = null
var _dialog_label: RichTextLabel = null
var _progress_label: Label = null
var _skip_btn: Button = null
var _arrow: Label = null
var _tween: Tween = null
## Anchor y set once per target by _show_arrow; the bob in _process writes an
## absolute offset from it (V-104 / 4.2-L300-arrow-drift — no cumulative +=).
var _arrow_base_y: float = 0.0


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
			"message":
			"Benvenuto nella tua [b]Relax Room[/b]! 🏠\n" + "Questo è il tuo spazio personale. " + "Rendilo tuo!",
			"signal_name": "",
			"auto_advance": 3.0,
		},
		{
			"message":
			(
				"Usa [b]WASD[/b] o le [b]frecce direzionali[/b] "
				+ "per muoverti.\n"
				+ "Prova a muovere il personaggio ora!"
			),
			"signal_name": "",
			"wait_for_input": "movement",
		},
		{
			"message":
			(
				"Apri il pannello [b]Decorazioni[/b] "
				+ "per arredare la stanza.\n"
				+ "Clicca il pulsante [b]Decora[/b] in basso! ⬇"
			),
			"signal_name": "panel_opened",
			"signal_filter": "deco",
			"arrow_target": "DecoButton",
		},
		{
			"message":
			(
				"Sfoglia le categorie e [b]trascina[/b] "
				+ "una decorazione nella stanza!\n"
				+ "Prova con una pianta o una scrivania."
			),
			"signal_name": "decoration_placed",
		},
		{
			"message":
			(
				"Ottimo! Clicca su qualsiasi decorazione "
				+ "per selezionarla.\n"
				+ "Premi [b]R[/b] per ruotare, "
				+ "[b]F[/b] per specchiare, "
				+ "[b]S[/b] per ridimensionare, "
				+ "[b]X[/b] per eliminare."
			),
			"signal_name": "decoration_selected",
		},
		{
			"message":
			"Apri il [b]Profilo[/b] per vedere " + "le info del tuo account.\n" + "Clicca il pulsante Profilo! ⬇",
			"signal_name": "panel_opened",
			"signal_filter": "profile",
			"arrow_target": "ProfileButton",
		},
		{
			"message": "Premi [b]Esc[/b] per chiudere un pannello.\n" + "Provalo ora!",
			"signal_name": "panel_closed",
		},
		{
			"message":
			(
				"La tua stanza si salva [b]automaticamente[/b]! ✓\n\n"
				+ "[b]Missione completata![/b] 🎉\n"
				+ "Buon relax nella tua Relax Room!"
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
	_dialog_panel.add_theme_stylebox_override("panel", style)
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
	_dialog_label.add_theme_font_size_override("normal_font_size", 16)
	_dialog_label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.75, 1.0))
	vbox.add_child(_dialog_label)

	# Bottom row: progress + skip
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.6))
	_progress_label.size_flags_horizontal = (Control.SIZE_EXPAND_FILL)
	hbox.add_child(_progress_label)

	_skip_btn = Button.new()
	_skip_btn.text = tr("TUTORIAL_SKIP")
	_skip_btn.flat = true
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.8))
	_skip_btn.pressed.connect(_on_skip)
	hbox.add_child(_skip_btn)

	# Arrow indicator
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 24)
	_arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.9))
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
	_progress_label.text = tr("TUTORIAL_PROGRESS") % [_current_step + 1, _steps.size()]
	_step_timer = 0.0
	_arrow.visible = false

	# Disconnect the previous step's signal listener
	_disconnect_step_signal()

	# Final step — bottone di chiusura
	if step.get("is_final", false):
		_skip_btn.text = tr("TUTORIAL_DONE")

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

	# Signal-based step — single stateful connection per step. The filter is
	# checked inside _on_signal_received: a non-matching event simply returns,
	# keeping the connection alive (no disconnect/reconnect churn).
	var sig_name: String = step.get("signal_name", "")
	if not sig_name.is_empty() and SignalBus.has_signal(sig_name):
		var sig: Signal = SignalBus.get(sig_name)
		_step_signal_name = sig_name
		_step_callable = _on_signal_received
		sig.connect(_step_callable)

	# Show arrow pointing to a specific button
	var arrow_target: String = step.get("arrow_target", "")
	if not arrow_target.is_empty():
		_show_arrow(arrow_target)

	# Fade in dialog
	_animate_dialog_in()


## Variadic-style signal handler. SignalBus signals emit 0..2 args; accept up
## to 3 args with defaults so any signal arity works without crash. The
## connection is stateful (one per step): a filter miss just logs and returns,
## keeping the connection alive — no disconnect/reconnect churn.
func _on_signal_received(
	a: Variant = null,
	b: Variant = null,
	c: Variant = null,
) -> void:
	if _current_step < 0 or _current_step >= _steps.size():
		return
	var step: Dictionary = _steps[_current_step]
	var filter: String = step.get("signal_filter", "")
	if not filter.is_empty():
		var received: String = ""
		if a is String:
			received = a
		if filter not in received:
			var miss_ctx := {
				"step": _current_step,
				"signal": _step_signal_name,
				"got": received,
				"want": filter,
			}
			AppLogger.debug("Tutorial", "Step filter miss", miss_ctx)
			return
	# a, b, c are the variadic signal parameters: consume them this way to
	# silence gdlint (varargs cannot be prefixed with _)
	var unused_sig_args := [a, b, c]
	unused_sig_args.clear()
	_advance_step()


func _process(delta: float) -> void:
	if not _is_active:
		return

	_step_timer += delta

	# Movement detection
	if _current_step >= 0 and _current_step < _steps.size():
		var step: Dictionary = _steps[_current_step]
		if step.has("wait_for_input"):
			var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			if dir.length() > 0.1:
				_advance_step()
				return

	# Step timeout — auto-advance with help message
	if _step_timer > STEP_TIMEOUT:
		_advance_step()

	# Animate arrow — absolute write from the stored anchor: frame-rate
	# independent, no floating-point drift over long steps.
	if _arrow.visible:
		_arrow.position.y = _arrow_base_y + sin(Time.get_ticks_msec() / 300.0) * 0.3


func _show_arrow(target_name: String) -> void:
	# Godot does not enforce node-name uniqueness across branches, so collect
	# EVERY match in the walked tree (V-082 / 4.1.6-L305): warn on duplicates
	# instead of silently trusting the first depth-first hit, and warn on a
	# missing target instead of the old silent no-arrow no-op.
	var matches: Array[Node] = []
	_collect_nodes_by_name(get_tree().root, target_name, matches)
	if matches.is_empty():
		AppLogger.warn("Tutorial", "Arrow target not found", {"target": target_name})
		return
	if matches.size() > 1:
		var dup_ctx := {"target": target_name, "count": matches.size()}
		AppLogger.warn("Tutorial", "Arrow target name not unique", dup_ctx)
	# Prefer the first VISIBLE match — a hidden duplicate must not steal the
	# arrow. Fall back to the first match when none is visible.
	var target: Node = matches[0]
	for candidate: Node in matches:
		if candidate is Control and (candidate as Control).is_visible_in_tree():
			target = candidate
			break
	if target is Control:
		var pos: Vector2 = target.global_position
		_arrow_base_y = pos.y - 30.0
		_arrow.position = Vector2(pos.x + target.size.x / 2.0 - 12.0, _arrow_base_y)
		_arrow.visible = true


func _collect_nodes_by_name(root: Node, node_name: String, matches: Array[Node]) -> void:
	if root.name == node_name:
		matches.append(root)
	for child in root.get_children():
		_collect_nodes_by_name(child, node_name, matches)


func _animate_dialog_in() -> void:
	if _dialog_panel == null:
		return
	_dialog_panel.modulate.a = 0.0
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dialog_panel, "modulate:a", 1.0, 0.3)


func _on_skip() -> void:
	_is_active = false
	visible = false
	_disconnect_step_signal()
	tutorial_skipped.emit()
	AppLogger.info("Tutorial", "Tutorial skipped", {"step": _current_step})
	queue_free()


func _finish() -> void:
	_is_active = false
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dialog_panel, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(_on_tutorial_done)


func _on_tutorial_done() -> void:
	visible = false
	_disconnect_step_signal()
	tutorial_completed.emit()
	AppLogger.info("Tutorial", "Tutorial completed", {})
	queue_free()


func _disconnect_step_signal() -> void:
	if _step_signal_name.is_empty():
		return
	if SignalBus.has_signal(_step_signal_name):
		var sig: Signal = SignalBus.get(_step_signal_name)
		if not _step_callable.is_null() and sig.is_connected(_step_callable):
			sig.disconnect(_step_callable)
	_step_signal_name = ""
	_step_callable = Callable()


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_disconnect_step_signal()
	if _skip_btn and _skip_btn.pressed.is_connected(_on_skip):
		_skip_btn.pressed.disconnect(_on_skip)
