## ToastManager — Non-blocking toast notifications.
## Displays short messages that auto-dismiss after a timeout.
## Queues multiple toasts and shows them sequentially.
extends CanvasLayer

const MAX_VISIBLE := 3
const TOAST_DURATION := 3.0
const FADE_DURATION := 0.3
const TOAST_HEIGHT := 40
const TOAST_GAP := 8
const TOAST_MARGIN := 20

var _toasts: Array[Control] = []
var _container: VBoxContainer = null


func _ready() -> void:
	layer = 90  # Above game, below tutorial
	_build_container()
	# Refactor da lambda inline a metodi membri (fix B-011). Le lambda con
	# capture implicito di `self` (o di variabili esterne) rimangono zombie
	# dopo queue_free del CanvasLayer perche` i SignalBus segnali sono
	# autoload persistenti. Metodi membri permettono disconnect simmetrico
	# e pulito in _exit_tree.
	SignalBus.toast_requested.connect(_on_toast_requested)
	SignalBus.save_completed.connect(_on_save_completed)
	SignalBus.decoration_placed.connect(_on_decoration_placed_toast)
	SignalBus.decoration_removed.connect(_on_decoration_removed_toast)


func _on_save_completed() -> void:
	show_toast("Partita salvata ✓", "success")


func _on_decoration_placed_toast(item_id: String, _pos: Vector2) -> void:
	show_toast("Posizionato: %s" % item_id, "info")


func _on_decoration_removed_toast(item_id: String) -> void:
	show_toast("Rimosso: %s" % item_id, "warning")


func _build_container() -> void:
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_container.anchor_left = 0.65
	_container.anchor_right = 0.98
	_container.anchor_top = 0.02
	_container.anchor_bottom = 0.4
	_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_container.add_theme_constant_override("separation", TOAST_GAP)
	# CRITICAL: VBoxContainer default mouse_filter is STOP. Since this container
	# occupies the upper-right quadrant (x=[832,1254] y=[14,288] at 1280x720)
	# AND the ToastManager CanvasLayer sits at layer=90 (above UILayer layer=10),
	# a STOP filter here silently absorbs every click in that region — blocking:
	#   - deco_panel items in the upper half (anchor right, full height overlaps)
	#   - profile_hud_panel entirely (anchor top-right)
	#   - any future top-right UI
	# Individual toast panels already have mouse_filter=IGNORE so they don't
	# block. Only this parent container needed correcting. (fix 2026-04-17)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func show_toast(
	message: String, toast_type: String = "info"
) -> void:
	# Drop oldest if at limit
	while _toasts.size() >= MAX_VISIBLE:
		var oldest: Control = _toasts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var toast := _create_toast(message, toast_type)
	_container.add_child(toast)
	_toasts.append(toast)

	# Fade in
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(
		toast, "modulate:a", 1.0, FADE_DURATION
	)
	# Auto-dismiss
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(
		toast, "modulate:a", 0.0, FADE_DURATION
	)
	tween.tween_callback(_remove_toast.bind(toast))


func _create_toast(
	message: String, toast_type: String
) -> PanelContainer:
	var panel := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 3

	match toast_type:
		"success":
			style.bg_color = Color(0.1, 0.18, 0.12, 0.92)
			style.border_color = Color(0.3, 0.8, 0.4, 0.9)
		"warning":
			style.bg_color = Color(0.2, 0.16, 0.08, 0.92)
			style.border_color = Color(0.9, 0.7, 0.2, 0.9)
		"error":
			style.bg_color = Color(0.2, 0.08, 0.08, 0.92)
			style.border_color = Color(0.9, 0.3, 0.3, 0.9)
		_:  # info
			style.bg_color = Color(0.1, 0.1, 0.16, 0.92)
			style.border_color = Color(0.4, 0.5, 0.8, 0.9)

	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override(
		"font_color", Color(0.9, 0.88, 0.82, 1.0)
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)

	panel.custom_minimum_size = Vector2(200, TOAST_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _remove_toast(toast: Control) -> void:
	var idx := _toasts.find(toast)
	if idx >= 0:
		_toasts.remove_at(idx)
	if is_instance_valid(toast):
		toast.queue_free()


func _on_toast_requested(
	message: String, toast_type: String
) -> void:
	show_toast(message, toast_type)


func _exit_tree() -> void:
	# Disconnect simmetrico di tutti 4 segnali connessi in _ready.
	if SignalBus.toast_requested.is_connected(_on_toast_requested):
		SignalBus.toast_requested.disconnect(_on_toast_requested)
	if SignalBus.save_completed.is_connected(_on_save_completed):
		SignalBus.save_completed.disconnect(_on_save_completed)
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed_toast):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed_toast)
	if SignalBus.decoration_removed.is_connected(_on_decoration_removed_toast):
		SignalBus.decoration_removed.disconnect(_on_decoration_removed_toast)
