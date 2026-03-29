## AuthManager — Manages authentication state and account lifecycle.
## Phase 2: guest-only mode. Phase 4 adds Supabase online auth.
extends Node

enum AuthState { LOGGED_OUT, GUEST, AUTHENTICATED }

var auth_state: int = AuthState.LOGGED_OUT
var current_account_id: int = -1
var current_auth_uid: String = ""
var has_character: bool = false


func _ready() -> void:
	try_auto_login()


func try_auto_login() -> bool:
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


func _set_state(new_state: int, account: Dictionary) -> void:
	auth_state = new_state
	current_account_id = account.get("account_id", -1)
	current_auth_uid = account.get("auth_uid", "")
	if current_account_id >= 0:
		has_character = not LocalDatabase.get_character(
			current_account_id
		).is_empty()
	else:
		has_character = false
	SignalBus.auth_state_changed.emit(new_state)


# ---- Stubs for Phase 4 (Supabase) ----


func sign_up(_email: String, _password: String) -> Dictionary:
	return {"error": "Not implemented — use guest mode"}


func sign_in(_email: String, _password: String) -> Dictionary:
	return {"error": "Not implemented — use guest mode"}


func sign_out() -> void:
	_set_state(AuthState.LOGGED_OUT, {})
