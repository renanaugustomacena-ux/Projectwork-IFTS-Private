## ProfilePanel — Account info, actions, and danger zone.
## Built programmatically following the settings_panel.gd pattern.
extends PanelContainer

## Chiede al PanelManager di chiudere questo pannello (bottone Chiudi).
signal close_requested

var _account_type_label: Label
var _email_label: Label
var _coins_label: Label
var _delete_char_btn: Button
var _delete_account_btn: Button
var _confirm_dialog: ConfirmationDialog
var _close_btn: Button = null


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

	_build_header(vbox)

	# Account info section
	var info_label := Label.new()
	info_label.text = tr("UI_PROFILE_ACCOUNT")
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.modulate.a = 0.7
	vbox.add_child(info_label)

	_account_type_label = _create_info_row(vbox, tr("UI_PROFILE_ROW_TYPE"))
	_email_label = _create_info_row(vbox, tr("UI_PROFILE_ROW_USER"))
	_coins_label = _create_info_row(vbox, tr("UI_PROFILE_ROW_COINS"))

	# Separator
	vbox.add_child(HSeparator.new())

	# Actions section
	var actions_label := Label.new()
	actions_label.text = tr("UI_PROFILE_ACTIONS")
	actions_label.add_theme_font_size_override("font_size", 11)
	actions_label.modulate.a = 0.7
	vbox.add_child(actions_label)

	# Delete Character
	_delete_char_btn = Button.new()
	_delete_char_btn.focus_mode = Control.FOCUS_NONE
	_delete_char_btn.text = tr("UI_PROFILE_DELETE_CHARACTER")
	_delete_char_btn.custom_minimum_size = Vector2(0, 32)
	(
		_delete_char_btn
		. pressed
		. connect(
			(
				_confirm_action
				. bind(
					"CONFIRM_DELETE_CHARACTER_TITLE",
					"CONFIRM_DELETE_CHARACTER_BODY",
					_on_delete_character_confirmed,
				)
			)
		)
	)
	vbox.add_child(_delete_char_btn)

	# Delete Account
	_delete_account_btn = Button.new()
	_delete_account_btn.focus_mode = Control.FOCUS_NONE
	_delete_account_btn.text = tr("UI_PROFILE_DELETE_ACCOUNT")
	_delete_account_btn.custom_minimum_size = Vector2(0, 32)
	(
		_delete_account_btn
		. pressed
		. connect(
			(
				_confirm_action
				. bind(
					"CONFIRM_DELETE_ACCOUNT_TITLE",
					"CONFIRM_DELETE_ACCOUNT_BODY",
					_on_delete_account_confirmed,
				)
			)
		)
	)
	vbox.add_child(_delete_account_btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Logout
	var logout_btn := Button.new()
	logout_btn.focus_mode = Control.FOCUS_NONE
	# Per l'ospite il pulsante e` la porta d'ingresso a login/registrazione:
	# la schermata auth non compare mai da sola al primo avvio (PT-01).
	var is_guest := AuthManager.auth_state == AuthManager.AuthState.GUEST
	logout_btn.text = tr("UI_PROFILE_LOGIN") if is_guest else tr("UI_PROFILE_LOGOUT")
	logout_btn.custom_minimum_size = Vector2(0, 32)
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

	# Confirmation dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.min_size = Vector2(300, 100)
	add_child(_confirm_dialog)


## Riga di testa: titolo + Chiudi (stesso schema di settings_panel.gd):
## close_requested viene collegato da PanelManager a close_current_panel.
func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	parent.add_child(header)

	var title := Label.new()
	title.text = tr("UI_PROFILE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = tr("UI_CLOSE")
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.pressed.connect(_on_close_pressed)
	header.add_child(_close_btn)


func _on_close_pressed() -> void:
	close_requested.emit()


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
		_account_type_label.text = tr("UI_PROFILE_GUEST")
		_email_label.text = "—"
	elif AuthManager.auth_state == AuthManager.AuthState.AUTHENTICATED:
		_account_type_label.text = tr("UI_PROFILE_REGISTERED")
		_email_label.text = AuthManager.current_username
	else:
		_account_type_label.text = tr("UI_PROFILE_LOGGED_OUT")
		_email_label.text = "—"

	# Il JSON per-slot e` la verita` (DB-01/PT-52): il DB conosce solo lo
	# slot che ha salvato per ultimo, e per un account nuovo direbbe 0.
	_coins_label.text = str(int(SaveManager.inventory_data.get("coins", 0)))

	_delete_char_btn.disabled = not AuthManager.has_character


## I dialoghi di conferma ricevono CHIAVI di traduzione, non testo gia` risolto:
## la traduzione avviene qui, all'apertura del popup. Un consenso a una
## cancellazione irreversibile deve essere leggibile nella lingua corrente del
## giocatore, e legandolo all'apertura il cambio lingua a pannello gia`
## costruito non lascia indietro un dialogo in un'altra lingua (audit G-036).
func _confirm_action(title_key: String, body_key: String, callback: Callable) -> void:
	_confirm_dialog.title = tr(title_key)
	_confirm_dialog.dialog_text = tr(body_key)
	_confirm_dialog.ok_button_text = tr("CONFIRM_DELETE_OK")
	_confirm_dialog.cancel_button_text = tr("CONFIRM_CANCEL")
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
	AppLogger.info("ProfilePanel", "Character deleted")
	# PT-54: la RAM e` vuota ma la scena mostrava ancora i vecchi mobili, che
	# venivano poi salvati... nel nulla. Persisti e ricostruisci la stanza.
	SaveManager.save_game()
	get_tree().call_deferred("reload_current_scene")


func _on_delete_account_confirmed() -> void:
	# PT-53: il testo promette "tutti i dati": tutti i 10 slot + la riga account.
	SaveManager.delete_all_slots()
	SaveManager.reset_all()
	AuthManager.delete_account()
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
	if _close_btn and _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.disconnect(_on_close_pressed)
	# I pressed callback dei 3 Button (delete_char, delete_account, logout)
	# vengono automaticamente puliti quando il panel e` queue_free: i button
	# sono children di questo PanelContainer, distrutti con esso.
