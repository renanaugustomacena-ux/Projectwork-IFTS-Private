extends TestBase
## Modulo test DevBridge — API HTTP locale debug-only.
##
## NOTA: /screenshot e /quit sono verificati manualmente (viewport reale /
## terminazione processo) — vedi sezione "Verifica manuale" nel piano.
## I test chiamano DevBridge.start(TEST_PORT) direttamente: gli user args
## (--bridge) non sono simulabili in un run headless del runner.

const TEST_PORT := 8123


func test_inert_without_flag() -> void:
	# Il runner gira senza `-- --bridge`: l'autoload deve essere spento.
	assert_false(DevBridge.is_active(), "bridge attivo senza flag --bridge")


func test_start_rejects_invalid_port() -> void:
	DevBridge.stop()
	assert_false(DevBridge.start(80), "porta < 1024 accettata")
	assert_false(DevBridge.start(70000), "porta > 65535 accettata")
	assert_false(DevBridge.is_active(), "bridge attivo dopo start invalido")


func test_start_binds_localhost() -> void:
	assert_true(DevBridge.start(TEST_PORT), "start(%d) fallito" % TEST_PORT)
	assert_true(DevBridge.is_active(), "is_active() falso dopo start riuscito")
	# Idempotente: secondo start non deve fallire ne' ribindare.
	assert_true(DevBridge.start(TEST_PORT), "start idempotente fallito")
	DevBridge.stop()
