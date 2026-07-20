## Test crittografia password (Fase C.7).
##
## L'hashing v4 e` PBKDF2-HMAC-SHA256 secondo RFC 8018 par. 5.2. I vettori
## qui sotto vengono da Python hashlib.pbkdf2_hmac e sono la sola prova che
## l'implementazione GDScript segue davvero lo standard e non una variante
## "PBKDF2-style" come quella storica.
extends TestBase

## (password, salt, iterazioni, lunghezza chiave, atteso hex)
const VECTORS := [
	["password", "salt", 1, 32, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"],
	["password", "salt", 4096, 32, "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"],
	[
		"passwordPASSWORDpassword",
		"saltSALTsaltSALTsaltSALTsaltSALTsalt",
		4096,
		40,
		"348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9",
	],
]


func test_pbkdf2_matches_rfc_vectors() -> void:
	for vector in VECTORS:
		var password: String = vector[0]
		var salt: PackedByteArray = (vector[1] as String).to_utf8_buffer()
		var iterations: int = vector[2]
		var key_len: int = vector[3]
		var expected: String = vector[4]
		var derived: PackedByteArray = AuthManager._pbkdf2_hmac_sha256(password, salt, iterations, key_len)
		assert_eq(derived.size(), key_len, "derived key length for %d iterations" % iterations)
		assert_eq(derived.hex_encode(), expected, "RFC vector for %d iterations" % iterations)


func test_empty_password_fails_closed() -> void:
	# hmac_digest rifiuta una chiave vuota: senza guardia il ciclo a blocchi
	# non terminerebbe mai e il thread principale resterebbe bloccato.
	var derived: PackedByteArray = AuthManager._pbkdf2_hmac_sha256("", "salt".to_utf8_buffer(), 10, 32)
	assert_eq(derived.size(), 0, "empty password must derive nothing")


func test_v4_hash_roundtrip() -> void:
	var stored: String = AuthManager._hash_password("correct horse battery staple")
	assert_true(stored.begins_with("v4$pbkdf2$"), "new hashes must use the v4 PBKDF2 format")
	var parts: PackedStringArray = stored.split("$")
	assert_eq(parts.size(), 5, "v4 format has 5 fields")
	assert_true(AuthManager._verify_v4_hash("correct horse battery staple", stored), "correct password verifies")
	assert_false(AuthManager._verify_v4_hash("wrong password", stored), "wrong password rejected")


func test_malformed_v4_hash_is_rejected_fast() -> void:
	# Un conteggio di iterazioni assurdo deve fallire subito: int() satura a
	# INT64_MAX e senza il limite la verifica non tornerebbe mai.
	var salt_hex := "ab".repeat(16)
	var dk_hex := "cd".repeat(32)
	var absurd := "v4$pbkdf2$99999999999999999999$%s$%s" % [salt_hex, dk_hex]
	var started := Time.get_ticks_msec()
	assert_false(AuthManager._verify_v4_hash("x", absurd), "absurd iteration count rejected")
	assert_true(Time.get_ticks_msec() - started < 500, "rejection must be immediate")
	assert_false(
		AuthManager._verify_v4_hash("x", "v4$pbkdf2$notanumber$%s$%s" % [salt_hex, dk_hex]),
		"non-numeric iterations rejected"
	)
	assert_false(AuthManager._verify_v4_hash("x", "v4$pbkdf2$1000$abcd$%s" % dk_hex), "short salt rejected")
	assert_false(AuthManager._verify_v4_hash("x", "garbage"), "garbage rejected")


func test_hashes_are_salted_per_account() -> void:
	var first: String = AuthManager._hash_password("same password")
	var second: String = AuthManager._hash_password("same password")
	assert_ne(first, second, "same password must not produce the same stored hash")
	assert_true(AuthManager._verify_v4_hash("same password", first), "first hash verifies")
	assert_true(AuthManager._verify_v4_hash("same password", second), "second hash verifies")
