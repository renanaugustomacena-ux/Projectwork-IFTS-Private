## AuthScreen — Full-screen overlay for login, registration, and guest mode.
## Built programmatically. Shown on first launch when no account exists.
extends Control

signal auth_completed

var _login_form: VBoxContainer
var _register_form: VBoxContainer
var _error_label: Label

var _login_email: LineEdit
var _login_password: LineEdit
var _register_email: LineEdit
var _register_password: LineEdit
var _register_confirm: LineEdit
var _register_name: LineEdit


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
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Mini Cozy Room"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Welcome"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate.a = 0.6
	vbox.add_child(subtitle)

	# ---- Login Form ----
	_login_form = VBoxContainer.new()
	_login_form.add_theme_constant_override("separation", 8)
	vbox.add_child(_login_form)

	_login_email = _create_line_edit(_login_form, "Email")
	_login_password = _create_line_edit(
		_login_form, "Password", true
	)

	var login_btn := Button.new()
	login_btn.text = "Login"
	login_btn.custom_minimum_size = Vector2(0, 36)
	login_btn.pressed.connect(_on_login_pressed)
	_login_form.add_child(login_btn)

	var switch_to_register := Button.new()
	switch_to_register.text = "Create an account"
	switch_to_register.flat = true
	switch_to_register.add_theme_font_size_override("font_size", 11)
	switch_to_register.pressed.connect(_show_register_form)
	_login_form.add_child(switch_to_register)

	# ---- Register Form (hidden) ----
	_register_form = VBoxContainer.new()
	_register_form.add_theme_constant_override("separation", 8)
	_register_form.visible = false
	vbox.add_child(_register_form)

	_register_email = _create_line_edit(_register_form, "Email")
	_register_name = _create_line_edit(_register_form, "Name (optional)")
	_register_password = _create_line_edit(
		_register_form, "Password", true
	)
	_register_confirm = _create_line_edit(
		_register_form, "Confirm Password", true
	)

	var register_btn := Button.new()
	register_btn.text = "Register"
	register_btn.custom_minimum_size = Vector2(0, 36)
	register_btn.pressed.connect(_on_register_pressed)
	_register_form.add_child(register_btn)

	var switch_to_login := Button.new()
	switch_to_login.text = "Already have an account"
	switch_to_login.flat = true
	switch_to_login.add_theme_font_size_override("font_size", 11)
	switch_to_login.pressed.connect(_show_login_form)
	_register_form.add_child(switch_to_login)

	# ---- Separator ----
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ---- Guest Button ----
	var guest_btn := Button.new()
	guest_btn.text = "Play as Guest"
	guest_btn.custom_minimum_size = Vector2(0, 40)
	guest_btn.pressed.connect(_on_guest_pressed)
	vbox.add_child(guest_btn)

	# ---- Error Label ----
	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override(
		"font_color", Color(0.9, 0.3, 0.3)
	)
	_error_label.add_theme_font_size_override("font_size", 11)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_error_label.visible = false
	vbox.add_child(_error_label)


func _create_line_edit(
	parent: VBoxContainer, placeholder: String, secret: bool = false
) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.secret = secret
	input.custom_minimum_size = Vector2(0, 32)
	parent.add_child(input)
	return input


func _show_login_form() -> void:
	_login_form.visible = true
	_register_form.visible = false
	_hide_error()


func _show_register_form() -> void:
	_login_form.visible = false
	_register_form.visible = true
	_hide_error()


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _hide_error() -> void:
	_error_label.visible = false


func _on_login_pressed() -> void:
	_hide_error()
	var email := _login_email.text.strip_edges()
	var password := _login_password.text

	if email.is_empty() or password.is_empty():
		_show_error("Please fill in all fields")
		return

	var result := AuthManager.sign_in(email, password)
	if result.has("error"):
		_show_error(result["error"])
		return

	_on_auth_success()


func _on_register_pressed() -> void:
	_hide_error()
	var email := _register_email.text.strip_edges()
	var password := _register_password.text
	var confirm := _register_confirm.text

	if email.is_empty() or password.is_empty():
		_show_error("Please fill in all fields")
		return

	if password.length() < Constants.AUTH_MIN_PASSWORD_LENGTH:
		_show_error(
			"Password must be at least %d characters"
			% Constants.AUTH_MIN_PASSWORD_LENGTH
		)
		return

	if password != confirm:
		_show_error("Passwords do not match")
		return

	var result := AuthManager.sign_up(email, password)
	if result.has("error"):
		_show_error(result["error"])
		return

	_on_auth_success()


func _on_guest_pressed() -> void:
	AuthManager.play_as_guest()
	_on_auth_success()


func _on_auth_success() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	tween.tween_callback(
		func() -> void:
			auth_completed.emit()
			queue_free()
	)
