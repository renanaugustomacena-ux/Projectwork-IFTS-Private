extends Node
## DevBridge — API HTTP locale debug-only per audit e test.
##
## Spec: v1/docs/specs/2026-08-08-dev-bridge-design.md
## Tre gate indipendenti: build debug + flag `--bridge` + bind 127.0.0.1.
## Regola architetturale: il bridge fa SOLO cio' che la UI puo' fare —
## emette segnali di input o chiama metodi pubblici gia' usati dalla UI.
## Mai emettere segnali di output dei sistemi (save_completed, mess_spawned...).

const SOURCE := "dev_bridge"
const BRIDGE_VERSION := "1.0.0"
const DEFAULT_PORT := 8080
const PORT_MIN := 1024
const PORT_MAX := 65535
const MAX_BODY_BYTES := 65536
const MAX_HEADER_BYTES := 8192
const RING_CAP := 200
const REQUEST_TIMEOUT_MS := 5000
const MAX_ACCEPTS_PER_FRAME := 2

var _server: TCPServer = null
var _active := false
var _start_ms := 0
var _events: Array[Dictionary] = []
var _events_dropped := 0
# Connessioni in corso: {peer: StreamPeerTCP, buf: PackedByteArray, deadline_ms: int}
var _conns: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	if not args.has("--bridge"):
		return
	var port := DEFAULT_PORT
	for arg in args:
		if arg.begins_with("--bridge-port="):
			var raw := arg.trim_prefix("--bridge-port=")
			if not raw.is_valid_int():
				AppLogger.error(SOURCE, "bridge_port_not_numeric", {"raw": raw})
				return
			port = raw.to_int()
	start(port)


func is_active() -> bool:
	return _active


## Avvia il server sulla porta data. Pubblico: i test lo chiamano direttamente
## perche' gli user args non sono simulabili in un run del test runner.
func start(port: int) -> bool:
	if _active:
		return true
	if port < PORT_MIN or port > PORT_MAX:
		AppLogger.error(SOURCE, "port_out_of_range", {"port": port})
		return false
	var server := TCPServer.new()
	var err := server.listen(port, "127.0.0.1")
	if err != OK:
		AppLogger.error(SOURCE, "listen_failed", {"port": port, "err": err})
		return false
	_server = server
	_active = true
	_start_ms = Time.get_ticks_msec()
	set_process(true)
	AppLogger.info(SOURCE, "listening", {"port": port})
	return true


func stop() -> void:
	if not _active:
		return
	for conn in _conns:
		conn.peer.disconnect_from_host()
	_conns.clear()
	_server.stop()
	_server = null
	_active = false
	set_process(false)
	AppLogger.info(SOURCE, "stopped")
