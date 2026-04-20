## AuthManager — Manages authentication state and account lifecycle.
## Supports guest mode, local username+password, and (Phase 4) Supabase.
extends Node

enum AuthState { LOGGED_OUT, GUEST, AUTHENTICATED }

# B-029 PBKDF2 iteration strength
# v3 current: 100_000 iter SHA-256 (OWASP 2023 minimum per PBKDF2-SHA256 ~=
# 600k, ma mantengo 100k come trade-off con avvio login responsivo; l'
# upgrade successivo richiedera` solo bump di questa costante + migration
# chain v3->v4). v2 legacy: 10_000 iter, mantenuta solo per verificare +
# re-hash transparent su login.
const _HASH_ITERATIONS_V3 := 100_000
const _HASH_ITERATIONS_V2_LEGACY := 10_000
const _LEGACY_SALT := "MiniCozyRoom2026"  # legacy pre-v2 fixed-salt hash

var auth_state: int = AuthState.LOGGED_OUT
var current_account_id: int = -1
var current_auth_uid: String = ""
var current_username: String = ""
var has_character: bool = false

var _failed_attempts: int = 0
var _lockout_until: float = 0.0


func _ready() -> void:
	if not try_auto_login():
		play_as_guest()


func try_auto_login() -> bool:
	# Try guest account first (simplest path)
	var account := LocalDatabase.get_account_by_auth_uid(Constants.AUTH_GUEST_UID)
	if not account.is_empty():
		_set_state(AuthState.GUEST, account)
		return true
	return false


func play_as_guest() -> void:
	var account_id := LocalDatabase.upsert_account(Constants.AUTH_GUEST_UID, Constants.AUTH_GUEST_EMAIL, "")
	var account := LocalDatabase.get_account(account_id)
	_set_state(AuthState.GUEST, account)
	SignalBus.account_created.emit(account_id)


func register(username: String, password: String) -> Dictionary:
	var clean_name := username.strip_edges()
	if clean_name.length() < 3:
		return {"error": "Username must be at least 3 characters"}
	if clean_name.length() > Constants.AUTH_MAX_USERNAME_LENGTH:
		return {"error": "Username too long (max %d)" % Constants.AUTH_MAX_USERNAME_LENGTH}
	var min_pw := Constants.AUTH_MIN_PASSWORD_LENGTH
	if password.length() < min_pw:
		return {"error": "Password must be at least %d characters" % min_pw}
	var existing := LocalDatabase.get_account_by_username(clean_name)
	if not existing.is_empty():
		return {"error": "Username already taken"}
	var pw_hash := _hash_password(password)
	var account_id := LocalDatabase.create_account(clean_name, pw_hash)
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
			return {"error": "Too many attempts. Wait %ds" % remaining}
		# Lockout expired
		_failed_attempts = 0

	var account := LocalDatabase.get_account_by_username(username.strip_edges())
	if account.is_empty():
		_record_failed_attempt()
		return {"error": "Invalid credentials"}

	var stored_hash: String = account.get("password_hash", "")
	var pw_ok := false
	var needs_upgrade_to_v3 := false

	if stored_hash.begins_with("v3:"):
		# Current format: v3:iterations:salt_hex:hash_hex
		var parts := stored_hash.split(":")
		if parts.size() == 4:
			var iter_count := int(parts[1])
			var computed := _hash_with_salt_iter(password, parts[2], iter_count)
			pw_ok = (computed == parts[3])
	elif stored_hash.begins_with("v2:"):
		# Legacy format v2: 10k iter, salt_hex:hash_hex
		var parts := stored_hash.split(":")
		if parts.size() == 3:
			var computed := _hash_with_salt_iter(password, parts[1], _HASH_ITERATIONS_V2_LEGACY)
			pw_ok = (computed == parts[2])
			if pw_ok:
				needs_upgrade_to_v3 = true
	else:
		# Pre-v2 fixed-salt legacy — migrate on success
		var legacy := (_LEGACY_SALT + password).sha256_text()
		pw_ok = (stored_hash == legacy)
		if pw_ok:
			needs_upgrade_to_v3 = true

	if not pw_ok:
		_record_failed_attempt()
		return {"error": "Invalid credentials"}

	# B-029: transparent hash migration v1/v2 -> v3. Succede una sola volta
	# al primo login successivo: user digita password, verify OK, ri-hash
	# con 100k iter + prefix v3, UPDATE DB.
	if needs_upgrade_to_v3:
		var new_hash := _hash_password(password)
		LocalDatabase.update_password_hash(account.get("account_id", -1), new_hash)
		AppLogger.info(
			"AuthManager", "hash_migration_applied", {"account_id": account.get("account_id", -1), "to": "v3"}
		)

	_failed_attempts = 0
	_set_state(AuthState.AUTHENTICATED, account)
	return {}


func _record_failed_attempt() -> void:
	_failed_attempts += 1
	if _failed_attempts >= Constants.AUTH_MAX_FAILED_ATTEMPTS:
		_lockout_until = Time.get_unix_time_from_system() + Constants.AUTH_LOCKOUT_SECONDS
		AppLogger.warn("AuthManager", "Account locked out", {"attempts": _failed_attempts})


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
	(
		AppLogger
		. info(
			"AuthManager",
			"Account deleted",
			{
				"account_id": current_account_id,
				"username": current_username,
			}
		)
	)
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
		has_character = not LocalDatabase.get_character(current_account_id).is_empty()
	else:
		has_character = false
	SignalBus.auth_state_changed.emit(new_state)


func _hash_password(password: String) -> String:
	# B-029: emette formato v3 con iter count nel prefix per future migrazioni
	# v3->v4 (bump iter) senza code change ne` ambiguita`.
	var crypto := Crypto.new()
	var salt_bytes := crypto.generate_random_bytes(16)
	var salt_hex := salt_bytes.hex_encode()
	var hash_hex := _hash_with_salt_iter(password, salt_hex, _HASH_ITERATIONS_V3)
	return "v3:%d:%s:%s" % [_HASH_ITERATIONS_V3, salt_hex, hash_hex]


func _hash_with_salt_iter(
	password: String,
	salt_hex: String,
	iter: int,
) -> String:
	# PBKDF2-style iterated SHA-256 using HashingContext.
	# Iter count parametrico: v2 legacy = 10k, v3 = 100k, future = bump.
	var data := (salt_hex + password).to_utf8_buffer()
	var result := _sha256(data)
	for i in range(iter - 1):
		result = _sha256(result + data)
	return result.hex_encode()


static func _sha256(input: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input)
	return ctx.finish()
