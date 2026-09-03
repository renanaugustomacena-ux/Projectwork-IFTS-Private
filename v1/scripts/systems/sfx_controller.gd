## SfxController — effetti sonori one-shot e loop nominati (v1.3).
## Figlio di AudioManager come AmbienceController: un pool di player, una
## cache degli stream, il volume "sfx" persistito nei settings. Un effetto
## assente e` silenzio, mai un errore: gli SFX sono rifinitura, non logica.
## Ogni Button dell'albero fa "click" da solo (aggancio su node_added), cosi`
## nessun pannello deve ricordarsene.
extends Node

const SFX_DIR := "res://assets/audio/sfx/synth/"
const POOL_SIZE := 6
const PITCH_JITTER := 0.06  # varianti minime: lo stesso click non suona mai identico
const LOOP_OFFSET_DB := -6.0
const CLICK_OFFSET_DB := -4.0
const VOLUME_DB_FLOOR := -80.0

var sfx_volume: float = 0.8

var _master_volume_provider: Callable = Callable()
var _players: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}  # nome -> AudioStreamPlayer
var _cache: Dictionary = {}  # nome -> AudioStream (o null se assente)
var _rng := RandomNumberGenerator.new()


func setup(master_volume_provider: Callable, initial_volume: float) -> void:
	_master_volume_provider = master_volume_provider
	sfx_volume = clampf(initial_volume, 0.0, 1.0)


func _ready() -> void:
	_rng.randomize()
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func set_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	for loop_player: AudioStreamPlayer in _loops.values():
		loop_player.volume_db = _db(LOOP_OFFSET_DB)


## Suona un effetto one-shot da SFX_DIR (nome senza estensione).
func play(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var stream := _stream(sfx_name)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = _db(volume_offset_db)
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()


## Loop nominato (fusa del gatto): idempotente, si ferma con stop_loop.
func play_loop(sfx_name: String) -> void:
	if _loops.has(sfx_name):
		return
	var stream := _stream(sfx_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	player.volume_db = _db(LOOP_OFFSET_DB)
	player.finished.connect(_on_loop_finished.bind(sfx_name))
	add_child(player)
	_loops[sfx_name] = player
	player.play()


func stop_loop(sfx_name: String) -> void:
	if not _loops.has(sfx_name):
		return
	var player: AudioStreamPlayer = _loops[sfx_name]
	_loops.erase(sfx_name)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()


## Rilascia gli stream al teardown (G-054: niente risorse vive all'uscita).
func release() -> void:
	for loop_name: String in _loops.keys():
		stop_loop(loop_name)
	for player in _players:
		player.stop()
		player.stream = null
	_cache.clear()


func _on_loop_finished(sfx_name: String) -> void:
	var player: AudioStreamPlayer = _loops.get(sfx_name)
	if player != null and is_instance_valid(player):
		player.play()


func _stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream: AudioStream = null
	for ext: String in ["ogg", "wav"]:
		var path := SFX_DIR + sfx_name + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_cache[sfx_name] = stream
	return stream


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	if _players.size() < POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
		return player
	return _players[0]


func _db(offset: float) -> float:
	var master: float = _master_volume_provider.call() if _master_volume_provider.is_valid() else 1.0
	var linear := master * sfx_volume
	if linear <= 0.0001:
		return VOLUME_DB_FLOOR
	return linear_to_db(linear) + offset


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_on_any_button_pressed):
		(node as BaseButton).pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play("ui_click", CLICK_OFFSET_DB)
