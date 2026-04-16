## ProfilePanel — Account info, actions, and danger zone.
## Built programmatically following the settings_panel.gd pattern.
extends PanelContainer

var _account_type_label: Label
var _email_label: Label
var _coins_label: Label
var _delete_char_btn: Button
var _delete_account_btn: Button
var _confirm_dialog: ConfirmationDialog


func _ready() -> void:
	_build_ui()
	_update_info()
	SignalBus.auth_state_changed.connect(_on_auth_state_changed)
	# Sottoscrivi cambio monete invece di polling LocalDatabase ogni refresh
	# (fix B-010). coins_changed viene emesso da GameManager/SaveManager
	# ogni volta che il contatore locale cambia.
	SignalBus.coins_changed.connect(_on_coins_changed)


func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Profilo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Account info section
	var info_label := Label.new()
	info_label.text = "Account"
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.modulate.a = 0.7
	vbox.add_child(info_label)

	_account_type_label = _create_info_row(vbox, "Tipo")
	_email_label = _create_info_row(vbox, "Utente")
	_coins_label = _create_info_row(vbox, "Monete")

	# Separator
	vbox.add_child(HSeparator.new())

	# Actions section
	var actions_label := Label.new()
	actions_label.text = "Azioni"
	actions_label.add_theme_font_size_override("font_size", 11)
	actions_label.modulate.a = 0.7
	vbox.add_child(actions_label)

	# Delete Character
	_delete_char_btn = Button.new()
	_delete_char_btn.text = "Elimina Personaggio"
	_delete_char_btn.custom_minimum_size = Vector2(0, 32)
	_delete_char_btn.pressed.connect(
		_confirm_action.bind(
			"Eliminare il personaggio?",
			"Il personaggio e la stanza verranno rimossi. Account e monete restano.",
			_on_delete_character_confirmed,
		)
	)
	vbox.add_child(_delete_char_btn)

	# Delete Account
	_delete_account_btn = Button.new()
	_delete_account_btn.text = "Elimina Account"
	_delete_account_btn.custom_minimum_size = Vector2(0, 32)
	_delete_account_btn.pressed.connect(
		_confirm_action.bind(
			"Eliminare l'account?",
			"Tutti i dati verranno eliminati permanentemente.",
			_on_delete_account_confirmed,
		)
	)
	vbox.add_child(_delete_account_btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Logout
	var logout_btn := Button.new()
	logout_btn.text = "Esci dall'account"
	logout_btn.custom_minimum_size = Vector2(0, 32)
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

	# Confirmation dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.min_size = Vector2(300, 100)
	add_child(_confirm_dialog)


func _create_info_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var value := Label.new()
	value.text = "—"
	value.add_theme_font_size_override("font_size", 12)
	value.modulate.a = 0.8
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	return value


func _update_info() -> void:
	if AuthManager.auth_state == AuthManager.AuthState.GUEST:
		_account_type_label.text = "Ospite"
		_email_label.text = "—"
	elif AuthManager.auth_state == AuthManager.AuthState.AUTHENTICATED:
		_account_type_label.text = "Registrato"
		_email_label.text = AuthManager.current_username
	else:
		_account_type_label.text = "Non connesso"
		_email_label.text = "—"

	var coins := LocalDatabase.get_coins(AuthManager.current_account_id)
	_coins_label.text = str(coins)

	_delete_char_btn.disabled = not AuthManager.has_character


func _confirm_action(
	title: String, message: String, callback: Callable
) -> void:
	_confirm_dialog.title = title
	_confirm_dialog.dialog_text = message
	# Disconnect previous confirmations
	if _confirm_dialog.confirmed.is_connected(_on_delete_character_confirmed):
		_confirm_dialog.confirmed.disconnect(_on_delete_character_confirmed)
	if _confirm_dialog.confirmed.is_connected(_on_delete_account_confirmed):
		_confirm_dialog.confirmed.disconnect(_on_delete_account_confirmed)
	_confirm_dialog.confirmed.connect(callback, CONNECT_ONE_SHOT)
	_confirm_dialog.popup_centered()


func _on_delete_character_confirmed() -> void:
	AuthManager.delete_character()
	SaveManager.reset_character_data()
	_update_info()
	AppLogger.info("ProfilePanel", "Character deleted")


func _on_delete_account_confirmed() -> void:
	AuthManager.delete_account()
	SaveManager.reset_all()
	AppLogger.info("ProfilePanel", "Account deleted")
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_logout_pressed() -> void:
	AuthManager.sign_out()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_auth_state_changed(_state: int) -> void:
	_update_info()


func _on_coins_changed(_delta: int, total: int) -> void:
	if is_instance_valid(_coins_label):
		_coins_label.text = str(total)


func _exit_tree() -> void:
	# Disconnect espliciti per evitare signal leak su panel recreate (fix B-009).
	if SignalBus.auth_state_changed.is_connected(_on_auth_state_changed):
		SignalBus.auth_state_changed.disconnect(_on_auth_state_changed)
	if SignalBus.coins_changed.is_connected(_on_coins_changed):
		SignalBus.coins_changed.disconnect(_on_coins_changed)
	# I pressed callback dei 3 Button (delete_char, delete_account, logout)
	# vengono automaticamente puliti quando il panel e` queue_free: i button
	# sono children di questo PanelContainer, distrutti con esso.
