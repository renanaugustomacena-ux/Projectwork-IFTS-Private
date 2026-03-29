## AuthScreen — Full-screen overlay for first-launch welcome.
## Phase 2: guest-only. Phase 4 will add login/register forms.
extends Control

signal auth_completed


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.18, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Mini Cozy Room"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Your cozy desktop companion"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate.a = 0.6
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Play button (primary action)
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(0, 48)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# Future: login hint (disabled until Supabase)
	var login_hint := Label.new()
	login_hint.text = "Account sync coming soon"
	login_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_hint.add_theme_font_size_override("font_size", 10)
	login_hint.modulate.a = 0.35
	vbox.add_child(login_hint)


func _on_play_pressed() -> void:
	AuthManager.play_as_guest()
	var tween := create_tween()
	tween.tween_property(
		self, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION
	)
	tween.tween_callback(
		func() -> void:
			auth_completed.emit()
			queue_free()
	)
