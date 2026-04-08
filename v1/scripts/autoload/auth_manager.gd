## AuthManager — Manages authentication state and account lifecycle.
## Supports guest mode, local username+password, and (Phase 4) Supabase.
extends Node

enum AuthState { LOGGED_OUT, GUEST, AUTHENTICATED }

const _HASH_ITERATIONS := 10000
const _LEGACY_SALT := "MiniCozyRoom2026"  # Only for migrating old hashes

var auth_state: int = AuthState.LOGGED_OUT
var current_account_id: int = -1
var current_auth_uid: String = ""
var current_username: String = ""
var has_character: bool = false

var _failed_attempts: int = 0
var _lockout_until: float = 0.0


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
	var clean_name := username.strip_edges()
	if clean_name.length() < 3:
		return {"error": "Username must be at least 3 characters"}
	if clean_name.length() > Constants.AUTH_MAX_USERNAME_LENGTH:
		return {"error": "Username too long (max %d)" \
			% Constants.AUTH_MAX_USERNAME_LENGTH}
	var min_pw := Constants.AUTH_MIN_PASSWORD_LENGTH
	if password.length() < min_pw:
		return {"error": "Password must be at least %d characters" \
			% min_pw}
	var existing := LocalDatabase.get_account_by_username(clean_name)
	if not existing.is_empty():
		return {"error": "Username already taken"}
	var pw_hash := _hash_password(password)
	var account_id := LocalDatabase.create_account(
		clean_name, pw_hash
	)
	if account_id < 0:
		return {"error": "Failed to create account"}
	var account := LocalDatabase.get_account(account_id)
	_set_state(AuthState.AUTHENTICATED, account)
	SignalBus.account_created.emit(account_id)
	return {}


func login(username: String, password: String) -> Dictionary:
	# Rate limiting
	var now := Time.get_unix_time_from_system()
	if _failed_attempts >= Constants.AUTH_MAX_FAILED_ATTEMPTS:
		var remaining := int(_lockout_until - now)
		if remaining > 0:
			return {"error": "Too many attempts. Wait %ds" \
				% remaining}
		# Lockout expired
		_failed_attempts = 0

	var account := LocalDatabase.get_account_by_username(
		username.strip_edges()
	)
	if account.is_empty():
		_record_failed_attempt()
		return {"error": "Invalid credentials"}

	var stored_hash: String = account.get("password_hash", "")
	var pw_ok := false

	if stored_hash.begins_with("v2:"):
		# New format: v2:salt_hex:hash_hex
		var parts := stored_hash.split(":")
		if parts.size() == 3:
			var computed := _hash_with_salt(password, parts[1])
			pw_ok = (computed == parts[2])
	else:
		# Legacy format — migrate on success
		var legacy := (_LEGACY_SALT + password).sha256_text()
		pw_ok = (stored_hash == legacy)
		if pw_ok:
			var new_hash := _hash_password(password)
			LocalDatabase.update_password_hash(
				account.get("account_id", -1), new_hash
			)

	if not pw_ok:
		_record_failed_attempt()
		return {"error": "Invalid credentials"}

	_failed_attempts = 0
	_set_state(AuthState.AUTHENTICATED, account)
	return {}


func _record_failed_attempt() -> void:
	_failed_attempts += 1
	if _failed_attempts >= Constants.AUTH_MAX_FAILED_ATTEMPTS:
		_lockout_until = Time.get_unix_time_from_system() \
			+ Constants.AUTH_LOCKOUT_SECONDS
		AppLogger.warn("AuthManager", "Account locked out",
			{"attempts": _failed_attempts})


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
	AppLogger.info("AuthManager", "Account deleted", {
		"account_id": current_account_id,
		"username": current_username,
	})
	LocalDatabase.soft_delete_account(current_account_id)
	_set_state(AuthState.LOGGED_OUT, {})
	SignalBus.account_deleted.emit()


func sign_out() -> void:
	_set_state(AuthState.LOGGED_OUT, {})


func _set_state(new_state: int, account: Dictionary) -> void:
	auth_state = new_state
	current_account_id = account.get("account_id", -1)
	current_auth_uid = account.get("auth_uid", "")
	current_username = account.get("display_name", "")
	if current_account_id >= 0 and LocalDatabase.is_open():
		has_character = not LocalDatabase.get_character(
			current_account_id
		).is_empty()
	else:
		has_character = false
	SignalBus.auth_state_changed.emit(new_state)


func _hash_password(password: String) -> String:
	var crypto := Crypto.new()
	var salt_bytes := crypto.generate_random_bytes(16)
	var salt_hex := salt_bytes.hex_encode()
	var hash_hex := _hash_with_salt(password, salt_hex)
	return "v2:%s:%s" % [salt_hex, hash_hex]


func _hash_with_salt(password: String, salt_hex: String) -> String:
	# PBKDF2-style iterated SHA-256 using HashingContext
	var data := (salt_hex + password).to_utf8_buffer()
	var result := _sha256(data)
	for i in range(_HASH_ITERATIONS - 1):
		result = _sha256(result + data)
	return result.hex_encode()


static func _sha256(input: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input)
	return ctx.finish()
