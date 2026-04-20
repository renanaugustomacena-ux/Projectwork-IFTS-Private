## AuthScreen — Full-screen overlay for login, register, or guest play.
extends Control

signal auth_completed

var _username_input: LineEdit = null
var _password_input: LineEdit = null
var _confirm_input: LineEdit = null
var _error_label: Label = null
var _login_form: VBoxContainer = null
var _register_form: VBoxContainer = null
var _finish_tween: Tween = null
var _finishing: bool = false


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
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Relax Room"
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

	# Error label (hidden by default)
	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", 11)
	_error_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_error_label.visible = false
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_error_label)

	# Login form
	_login_form = VBoxContainer.new()
	_login_form.add_theme_constant_override("separation", 8)
	vbox.add_child(_login_form)
	_build_login_form(_login_form)

	# Register form (hidden by default)
	_register_form = VBoxContainer.new()
	_register_form.add_theme_constant_override("separation", 8)
	_register_form.visible = false
	vbox.add_child(_register_form)
	_build_register_form(_register_form)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Guest play button
	var guest_btn := Button.new()
	guest_btn.focus_mode = Control.FOCUS_ALL  # form keyboard nav
	guest_btn.text = "Play as Guest"
	guest_btn.custom_minimum_size = Vector2(0, 40)
	guest_btn.pressed.connect(_on_guest_pressed)
	vbox.add_child(guest_btn)


func _build_login_form(container: VBoxContainer) -> void:
	_username_input = LineEdit.new()
	_username_input.placeholder_text = "Username"
	_username_input.custom_minimum_size = Vector2(0, 36)
	container.add_child(_username_input)

	_password_input = LineEdit.new()
	_password_input.placeholder_text = "Password"
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 36)
	_password_input.text_submitted.connect(func(_t: String) -> void: _on_login_pressed())
	container.add_child(_password_input)

	var login_btn := Button.new()
	login_btn.focus_mode = Control.FOCUS_ALL  # form keyboard nav
	login_btn.text = "Login"
	login_btn.custom_minimum_size = Vector2(0, 42)
	login_btn.pressed.connect(_on_login_pressed)
	container.add_child(login_btn)

	var switch_btn := Button.new()
	switch_btn.focus_mode = Control.FOCUS_ALL  # form keyboard nav
	switch_btn.text = "Don't have an account? Register"
	switch_btn.flat = true
	switch_btn.add_theme_font_size_override("font_size", 11)
	switch_btn.pressed.connect(_show_register)
	container.add_child(switch_btn)


func _build_register_form(container: VBoxContainer) -> void:
	var reg_user := LineEdit.new()
	reg_user.placeholder_text = "Choose a username"
	reg_user.custom_minimum_size = Vector2(0, 36)
	reg_user.name = "RegUsername"
	container.add_child(reg_user)

	var reg_pass := LineEdit.new()
	reg_pass.placeholder_text = "Choose a password"
	reg_pass.secret = true
	reg_pass.custom_minimum_size = Vector2(0, 36)
	reg_pass.name = "RegPassword"
	container.add_child(reg_pass)

	_confirm_input = LineEdit.new()
	_confirm_input.placeholder_text = "Confirm password"
	_confirm_input.secret = true
	_confirm_input.custom_minimum_size = Vector2(0, 36)
	_confirm_input.text_submitted.connect(func(_t: String) -> void: _on_register_pressed())
	container.add_child(_confirm_input)

	var reg_btn := Button.new()
	reg_btn.focus_mode = Control.FOCUS_ALL  # form keyboard nav
	reg_btn.text = "Register"
	reg_btn.custom_minimum_size = Vector2(0, 42)
	reg_btn.pressed.connect(_on_register_pressed)
	container.add_child(reg_btn)

	var switch_btn := Button.new()
	switch_btn.focus_mode = Control.FOCUS_ALL  # form keyboard nav
	switch_btn.text = "Already have an account? Login"
	switch_btn.flat = true
	switch_btn.add_theme_font_size_override("font_size", 11)
	switch_btn.pressed.connect(_show_login)
	container.add_child(switch_btn)


func _show_register() -> void:
	_login_form.visible = false
	_register_form.visible = true
	_error_label.visible = false


func _show_login() -> void:
	_register_form.visible = false
	_login_form.visible = true
	_error_label.visible = false


func _on_login_pressed() -> void:
	var username := _username_input.text.strip_edges()
	var password := _password_input.text
	if username.is_empty() or password.is_empty():
		_show_error("Please enter username and password")
		return
	var result := AuthManager.login(username, password)
	if result.has("error"):
		_show_error(result["error"])
		return
	_finish()


func _on_register_pressed() -> void:
	var reg_user := _register_form.get_node_or_null("RegUsername") as LineEdit
	var reg_pass := _register_form.get_node_or_null("RegPassword") as LineEdit
	if reg_user == null or reg_pass == null:
		_show_error("Internal error: form not ready")
		return
	var username := reg_user.text.strip_edges()
	var password := reg_pass.text
	var confirm := _confirm_input.text
	if username.is_empty() or password.is_empty():
		_show_error("Please fill in all fields")
		return
	if password != confirm:
		_show_error("Passwords don't match")
		return
	var result := AuthManager.register(username, password)
	if result.has("error"):
		_show_error(result["error"])
		return
	_finish()


func _on_guest_pressed() -> void:
	AuthManager.play_as_guest()
	_finish()


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	if _finish_tween and _finish_tween.is_running():
		_finish_tween.kill()
	_finish_tween = create_tween()
	_finish_tween.tween_property(self, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	_finish_tween.tween_callback(
		func() -> void:
			auth_completed.emit()
			queue_free()
	)


func _exit_tree() -> void:
	if _finish_tween and _finish_tween.is_running():
		_finish_tween.kill()
