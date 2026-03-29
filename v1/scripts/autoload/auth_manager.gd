## AuthManager — Manages authentication state and account lifecycle.
## Supports guest mode, local username+password, and (Phase 4) Supabase.
extends Node

enum AuthState { LOGGED_OUT, GUEST, AUTHENTICATED }

const SALT := "MiniCozyRoom2026"

var auth_state: int = AuthState.LOGGED_OUT
var current_account_id: int = -1
var current_auth_uid: String = ""
var current_username: String = ""
var has_character: bool = false


func _ready() -> void:
	try_auto_login()


func try_auto_login() -> bool:
	# Try guest account first (simplest path)
	var account := LocalDatabase.get_account_by_auth_uid(
		Constants.AUTH_GUEST_UID
	)
	if not account.is_empty():
		_set_state(AuthState.GUEST, account)
		return true
	return false


func play_as_guest() -> void:
	var account_id := LocalDatabase.upsert_account(
		Constants.AUTH_GUEST_UID, Constants.AUTH_GUEST_EMAIL, ""
	)
	var account := LocalDatabase.get_account(account_id)
	_set_state(AuthState.GUEST, account)
	SignalBus.account_created.emit(account_id)


func register(username: String, password: String) -> Dictionary:
	if username.strip_edges().length() < 3:
		return {"error": "Username must be at least 3 characters"}
	if password.length() < Constants.AUTH_MIN_PASSWORD_LENGTH:
		return {"error": "Password must be at least %d characters" % Constants.AUTH_MIN_PASSWORD_LENGTH}
	var existing := LocalDatabase.get_account_by_username(username.strip_edges())
	if not existing.is_empty():
		return {"error": "Username already taken"}
	var pw_hash := _hash_password(password)
	var account_id := LocalDatabase.create_account(
		username.strip_edges(), pw_hash
	)
	if account_id < 0:
		return {"error": "Failed to create account"}
	var account := LocalDatabase.get_account(account_id)
	_set_state(AuthState.AUTHENTICATED, account)
	SignalBus.account_created.emit(account_id)
	return {}


func login(username: String, password: String) -> Dictionary:
	var account := LocalDatabase.get_account_by_username(username.strip_edges())
	if account.is_empty():
		return {"error": "Username not found"}
	var pw_hash := _hash_password(password)
	if account.get("password_hash", "") != pw_hash:
		return {"error": "Wrong password"}
	_set_state(AuthState.AUTHENTICATED, account)
	return {}


func is_authenticated() -> bool:
	return auth_state == AuthState.AUTHENTICATED


func is_logged_in() -> bool:
	return auth_state != AuthState.LOGGED_OUT


func delete_character() -> void:
	if current_account_id < 0:
		return
	LocalDatabase.delete_character(current_account_id)
	has_character = false
	SignalBus.character_deleted.emit()


func delete_account() -> void:
	if current_account_id < 0:
		return
	LocalDatabase.delete_account(current_account_id)
	_set_state(AuthState.LOGGED_OUT, {})
	SignalBus.account_deleted.emit()


func sign_out() -> void:
	_set_state(AuthState.LOGGED_OUT, {})


func _set_state(new_state: int, account: Dictionary) -> void:
	auth_state = new_state
	current_account_id = account.get("account_id", -1)
	current_auth_uid = account.get("auth_uid", "")
	current_username = account.get("display_name", "")
	if current_account_id >= 0:
		has_character = not LocalDatabase.get_character(
			current_account_id
		).is_empty()
	else:
		has_character = false
	SignalBus.auth_state_changed.emit(new_state)


func _hash_password(password: String) -> String:
	return (SALT + password).sha256_text()
