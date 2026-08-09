## AuthManager — Manages authentication state and account lifecycle.
## Supports guest mode, local username+password, and (Phase 4) Supabase.
extends Node

enum AuthState { LOGGED_OUT, GUEST, AUTHENTICATED }

# C.7 password hashing (fix V-001)
# v4 current: real RFC 8018 §5.2 PBKDF2-HMAC-SHA256 via Crypto.hmac_digest,
# 100_000 iterations (measured ~0.12 s per login on desktop), 16 B random
# salt, 32 B derived key. Stored as v4$pbkdf2$<iter>$<salt_hex>$<dk_hex> —
# iteration count in the prefix so a future bump needs no migration
# ambiguity. Legacy verify-only formats, transparently re-hashed to v4 on
# the first successful login: v3 (100k-iter salted SHA-256 loop), v2
# (10k-iter loop), v1 (fixed-salt single SHA-256). The legacy loop is NOT
# PBKDF2 (no HMAC, no XOR accumulator) and is never used for new hashes.
const _PBKDF2_ITERATIONS := 100_000
const _PBKDF2_MAX_ITERATIONS := 1_000_000
const _PBKDF2_SALT_BYTES := 16
const _PBKDF2_KEY_BYTES := 32
const _HASH_ITERATIONS_V2_LEGACY := 10_000
const _LEGACY_SALT := "MiniCozyRoom2026"  # legacy pre-v2 fixed-salt hash
const _USERNAME_MIN_LENGTH := 3

var auth_state: int = AuthState.LOGGED_OUT
var current_account_id: int = -1
var current_auth_uid: String = ""
var current_username: String = ""
var has_character: bool = false

# D.7 (audit 4.4.2): per-username rate-limit state. In-memory dict is the
# fast path; the accounts columns failed_attempts/lockout_until_unix
# (schema migration 3) are authoritative across restarts.
var _rate_limit_cache: Dictionary = {}

# Audit 4.4.3: username whitelist — ASCII letters, digits, underscore, dot,
# hyphen. Length bounds honor Constants.AUTH_MAX_USERNAME_LENGTH. The
# ASCII-only class makes Unicode (NFC) normalization a no-op: any non-ASCII
# input is rejected outright.
var _username_regex := RegEx.create_from_string(
	"^[A-Za-z0-9_.-]{%d,%d}$" % [_USERNAME_MIN_LENGTH, Constants.AUTH_MAX_USERNAME_LENGTH]
)

# Audit 4.4.4 prep: counts pre-v2 fixed-salt verifications still occurring;
# a later phase turns this path into a hard refusal.
var _legacy_v1_verify_count: int = 0

# Injectable clock seam (audit 4.2-L72/L133): tests assign a Callable
# returning an int unix timestamp to fake time without real waits.
var _now_unix_override: Callable = Callable()


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


## Esito di errore come CHIAVE di traduzione + argomenti di formato, mai come
## testo gia` tradotto (audit G-011). L'autoload gira per tutta la sessione e
## non sa in che lingua sara` mostrato il messaggio: se traducesse qui,
## congelerebbe la lingua al momento della chiamata e ogni altro front-end
## (test, dev bridge, un futuro schermo mobile) erediterebbe quella scelta.
## Traduce chi disegna: auth_screen.gd (_show_error_result).
static func _error(key: String, args: Array = []) -> Dictionary:
	return {"error": key, "error_args": args}


func register(username: String, password: String) -> Dictionary:
	var clean_name := username.strip_edges()
	var name_error := _validate_username(clean_name)
	if not name_error.is_empty():
		return name_error
	var min_pw := Constants.AUTH_MIN_PASSWORD_LENGTH
	if password.length() < min_pw:
		return _error("UI_AUTH_ERR_PASSWORD_TOO_SHORT", [min_pw])
	var existing := LocalDatabase.get_account_by_username(clean_name)
	if not existing.is_empty():
		return _error("UI_AUTH_ERR_USERNAME_TAKEN")
	var pw_hash := _hash_password(password)
	var account_id := LocalDatabase.create_account(clean_name, pw_hash)
	if account_id < 0:
		return _error("UI_AUTH_ERR_ACCOUNT_CREATE_FAILED")
	var account := LocalDatabase.get_account(account_id)
	# Phase D (audit 4.4.2): failed login attempts against a not-yet-existing
	# username live ONLY in _rate_limit_cache (the DB UPDATE matched zero
	# rows). The fresh account row starts clean, so the stale cache entry must
	# be invalidated here — otherwise the first legitimate login after
	# registration is rejected by a lockout the account never earned.
	_reset_rate_limit(clean_name)
	_set_state(AuthState.AUTHENTICATED, account)
	SignalBus.account_created.emit(account_id)
	return {}


func login(username: String, password: String) -> Dictionary:
	var clean_name := username.strip_edges()
	# Phase E: length bounds only — the charset whitelist is enforced at
	# registration. Pre-E.3 accounts (spaces, non-ASCII names) predate the
	# regex and must stay reachable; applying it here would permanently lock
	# them out of their own saves.
	var name_error := _validate_username_length(clean_name)
	if not name_error.is_empty():
		return name_error
	# Rate limiting (audit 4.4.2): per-username, persisted across restarts.
	var limit := _load_rate_limit(clean_name)
	if limit.get("failed_attempts", 0) >= Constants.AUTH_MAX_FAILED_ATTEMPTS:
		var remaining: int = limit.get("lockout_until_unix", 0) - _now_unix()
		if remaining > 0:
			return _error("UI_AUTH_ERR_TOO_MANY_ATTEMPTS", [remaining])
		# Lockout expired
		_reset_rate_limit(clean_name)

	var account := LocalDatabase.get_account_by_username(clean_name)
	if account.is_empty():
		_record_failed_attempt(clean_name)
		return _error("UI_AUTH_ERR_INVALID_CREDENTIALS")

	var stored_hash: String = account.get("password_hash", "")
	var pw_ok := false
	var needs_rehash_to_v4 := false

	if stored_hash.begins_with("v4$"):
		# Current format: v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>
		pw_ok = _verify_v4_hash(password, stored_hash)
	elif stored_hash.begins_with("v3:"):
		# Legacy format v3: iterations:salt_hex:hash_hex (salted SHA-256 loop)
		var parts := stored_hash.split(":")
		if parts.size() == 4 and parts[1].is_valid_int():
			var v3_iter := int(parts[1])
			if v3_iter >= 1 and v3_iter <= _PBKDF2_MAX_ITERATIONS:
				var computed := _legacy_salted_sha256_loop(password, parts[2], v3_iter)
				pw_ok = (computed == parts[3])
				needs_rehash_to_v4 = pw_ok
	elif stored_hash.begins_with("v2:"):
		# Legacy format v2: 10k iter, salt_hex:hash_hex
		var parts := stored_hash.split(":")
		if parts.size() == 3:
			var computed := _legacy_salted_sha256_loop(password, parts[1], _HASH_ITERATIONS_V2_LEGACY)
			pw_ok = (computed == parts[2])
			needs_rehash_to_v4 = pw_ok
	else:
		# Pre-v2 fixed-salt legacy — migrate on success. Deprecated (audit
		# 4.4.4): WARN-counted here; a later phase hard-refuses this path.
		_legacy_v1_verify_count += 1
		(
			AppLogger
			. warn(
				"AuthManager",
				"deprecated_legacy_v1_verify",
				{
					"count": _legacy_v1_verify_count,
					"account_id": account.get("account_id", -1),
				},
			)
		)
		var legacy := (_LEGACY_SALT + password).sha256_text()
		pw_ok = (stored_hash == legacy)
		needs_rehash_to_v4 = pw_ok

	if not pw_ok:
		_record_failed_attempt(clean_name)
		return _error("UI_AUTH_ERR_INVALID_CREDENTIALS")

	# C.7: transparent hash migration v1/v2/v3 -> v4 (real PBKDF2). Happens
	# once at the first successful login: password verified with the legacy
	# routine, then re-hashed with PBKDF2-HMAC-SHA256 and UPDATEd in the DB.
	if needs_rehash_to_v4:
		var new_hash := _hash_password(password)
		LocalDatabase.update_password_hash(account.get("account_id", -1), new_hash)
		AppLogger.info(
			"AuthManager", "hash_migration_applied", {"account_id": account.get("account_id", -1), "to": "v4"}
		)

	_reset_rate_limit(clean_name)
	_set_state(AuthState.AUTHENTICATED, account)
	return {}


func _validate_username(clean_name: String) -> Dictionary:
	# Audit 4.4.3: full validation for register() only. Length checks run
	# first so their specific messages are preserved; the whitelist regex
	# after them can only fail on a character violation. login() must NOT use
	# this (see _validate_username_length): legacy accounts created before the
	# whitelist existed would fail the regex on every attempt.
	var length_error := _validate_username_length(clean_name)
	if not length_error.is_empty():
		return length_error
	if _username_regex.search(clean_name) == null:
		return _error("UI_AUTH_ERR_USERNAME_CHARSET")
	return {}


func _validate_username_length(clean_name: String) -> Dictionary:
	if clean_name.length() < _USERNAME_MIN_LENGTH:
		return _error("UI_AUTH_ERR_USERNAME_TOO_SHORT", [_USERNAME_MIN_LENGTH])
	if clean_name.length() > Constants.AUTH_MAX_USERNAME_LENGTH:
		return _error("UI_AUTH_ERR_USERNAME_TOO_LONG", [Constants.AUTH_MAX_USERNAME_LENGTH])
	return {}


func _now_unix() -> int:
	if _now_unix_override.is_valid():
		return int(_now_unix_override.call())
	return int(Time.get_unix_time_from_system())


func _load_rate_limit(username: String) -> Dictionary:
	# In-memory fast path; the DB row is authoritative on first touch after
	# boot (audit 4.4.2 — a restart no longer resets the counters).
	if _rate_limit_cache.has(username):
		return _rate_limit_cache[username]
	var persisted := LocalDatabase.get_rate_limit(username)
	var limit := {
		"failed_attempts": persisted.get("failed_attempts", 0),
		"lockout_until_unix": persisted.get("lockout_until_unix", 0),
	}
	_rate_limit_cache[username] = limit
	return limit


func _store_rate_limit(username: String, attempts: int, lockout_until_unix: int) -> void:
	_rate_limit_cache[username] = {
		"failed_attempts": attempts,
		"lockout_until_unix": lockout_until_unix,
	}
	# Unknown usernames have no accounts row: the UPDATE matches zero rows
	# and the in-memory cache alone throttles them for this session.
	LocalDatabase.set_rate_limit(username, attempts, lockout_until_unix)


func _reset_rate_limit(username: String) -> void:
	_store_rate_limit(username, 0, 0)


func _record_failed_attempt(username: String) -> void:
	var limit := _load_rate_limit(username)
	var attempts: int = limit.get("failed_attempts", 0) + 1
	var lockout_until: int = limit.get("lockout_until_unix", 0)
	if attempts >= Constants.AUTH_MAX_FAILED_ATTEMPTS:
		lockout_until = _now_unix() + Constants.AUTH_LOCKOUT_SECONDS
		AppLogger.warn("AuthManager", "Account locked out", {"attempts": attempts})
	_store_rate_limit(username, attempts, lockout_until)


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
	# Audit 4.8.2: reject values outside AuthState — a bad cast upstream must
	# not corrupt auth_state or emit a bogus auth_state_changed.
	if new_state not in AuthState.values():
		push_error("AuthManager: _set_state rejected invalid state %d" % new_state)
		return
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
	# C.7: real RFC 8018 PBKDF2-HMAC-SHA256, emitted as v4$pbkdf2$iter$salt$dk.
	var crypto := Crypto.new()
	var salt := crypto.generate_random_bytes(_PBKDF2_SALT_BYTES)
	var dk := _pbkdf2_hmac_sha256(password, salt, _PBKDF2_ITERATIONS, _PBKDF2_KEY_BYTES)
	return "v4$pbkdf2$%d$%s$%s" % [_PBKDF2_ITERATIONS, salt.hex_encode(), dk.hex_encode()]


func _verify_v4_hash(password: String, stored_hash: String) -> bool:
	# Format: v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>
	var parts := stored_hash.split("$")
	if parts.size() != 5 or parts[1] != "pbkdf2":
		return false
	# Fail closed on malformed iteration fields: int() saturates huge numeric
	# strings to INT64_MAX, which would turn a corrupt hash into a permanent
	# main-thread hang instead of a clean "invalid credentials".
	# Il campo iterazioni deve essere numerico E di lunghezza plausibile:
	# int() satura silenziosamente a INT64_MAX sulle cifre lunghe (con tanto
	# di errore di motore), quindi si taglia prima della conversione.
	if not parts[2].is_valid_int() or parts[2].length() > 9:
		return false
	var iterations := int(parts[2])
	var salt := parts[3].hex_decode()
	var expected := parts[4]
	if iterations < 1 or iterations > _PBKDF2_MAX_ITERATIONS:
		return false
	if salt.size() != _PBKDF2_SALT_BYTES or expected.length() != _PBKDF2_KEY_BYTES * 2:
		return false
	var dk := _pbkdf2_hmac_sha256(password, salt, iterations, _PBKDF2_KEY_BYTES)
	if dk.size() != _PBKDF2_KEY_BYTES:
		return false
	return dk.hex_encode() == expected


## RFC 8018 §5.2 PBKDF2-HMAC-SHA256: per block i,
## U_1 = HMAC(pw, salt || INT_32_BE(i)); U_j = HMAC(pw, U_{j-1});
## T_i = U_1 XOR ... XOR U_c. DK = T_1 || T_2 || ... truncated to dk_len.
## Validated 2026-07-20 against Python hashlib.pbkdf2_hmac ground truth —
## Phase H will embed these as regression test vectors:
##   ("password", "salt", 1, 32) ->
##     120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b
##   ("password", "salt", 4096, 32) ->
##     c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a
##   ("passwordPASSWORDpassword", "saltSALTsaltSALTsaltSALTsaltSALTsalt", 4096, 40) ->
##     348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9
func _pbkdf2_hmac_sha256(
	password: String,
	salt: PackedByteArray,
	iterations: int,
	dk_len: int,
) -> PackedByteArray:
	# Godot's hmac_digest rejects an empty key and returns an empty array,
	# which would make the block loop below spin forever appending 0 bytes.
	# Fail closed: callers treat an empty return as "derivation unavailable".
	if password.is_empty():
		return PackedByteArray()
	var crypto := Crypto.new()
	var pw := password.to_utf8_buffer()
	var derived := PackedByteArray()
	var block_index := 1
	while derived.size() < dk_len:
		var msg := salt.duplicate()
		msg.append((block_index >> 24) & 0xFF)
		msg.append((block_index >> 16) & 0xFF)
		msg.append((block_index >> 8) & 0xFF)
		msg.append(block_index & 0xFF)
		var u := crypto.hmac_digest(HashingContext.HASH_SHA256, pw, msg)
		if u.is_empty():
			return PackedByteArray()
		var t := u.duplicate()
		for _j in range(iterations - 1):
			u = crypto.hmac_digest(HashingContext.HASH_SHA256, pw, u)
			for k in range(t.size()):
				t[k] ^= u[k]
		derived.append_array(t)
		block_index += 1
	return derived.slice(0, dk_len)


func _legacy_salted_sha256_loop(
	password: String,
	salt_hex: String,
	iter: int,
) -> String:
	# Legacy iterated salted SHA-256 (NOT PBKDF2: no HMAC, no XOR
	# accumulator). Kept ONLY to verify stored v2/v3 hashes before their
	# transparent re-hash to v4. Never used to produce new hashes.
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
