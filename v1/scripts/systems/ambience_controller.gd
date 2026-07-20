## AmbienceController — tappeto sonoro ambientale, separato dalla playlist.
##
## Estratto da audio_manager.gd (F.5): la gestione ambience e` una macchina a
## se`, con i suoi player e la selezione per mood, e teneva AudioManager oltre
## il limite di 500 righe. AudioManager istanzia questo nodo come figlio e gli
## delega; l'API pubblica del manager non cambia.
##
## Ogni voce di ambience vive in data/tracks.json (array "ambience") con id,
## path e moods; se il catalogo non copre il mood corrente non si forza nulla.

extends Node

## Player attivi per id ambience.
var _players: Dictionary = {}
## Id ambience attualmente attive (ordine di avvio).
var _active: Array = []

var _volume_provider: Callable = Callable()


## AudioManager passa una Callable che restituisce il volume lineare corrente
## (master * ambience), cosi` il controller non duplica lo stato dei volumi.
func setup(volume_provider: Callable) -> void:
	_volume_provider = volume_provider


func get_active() -> Array:
	return _active.duplicate()


func is_playing() -> bool:
	for player in _players.values():
		if is_instance_valid(player) and player.playing:
			return true
	return false


func is_enabled() -> bool:
	return bool(SaveManager.get_setting("ambience_enabled", true))


## Attiva/disattiva il tappeto ambientale e persiste la preferenza.
func set_enabled(enabled: bool, current_mood: String) -> void:
	SignalBus.settings_updated.emit("ambience_enabled", enabled)
	if enabled:
		refresh_for_mood(current_mood)
		return
	stop_all()


## Allinea l'ambience attiva al mood: ferma quelle che non lo coprono piu` e
## avvia la prima adatta. No-op se disattivata o se il catalogo non copre il
## mood (meglio silenzio che una traccia fuori tono).
func refresh_for_mood(mood: String) -> void:
	if not is_enabled():
		return
	var wanted := pick_for_mood(mood)
	if wanted.is_empty():
		return
	for amb_id in _active.duplicate():
		if String(amb_id) != wanted:
			stop(String(amb_id))
	if wanted not in _players:
		start(wanted)


func pick_for_mood(mood: String) -> String:
	for amb in GameManager.tracks_catalog.get("ambience", []):
		if not (amb is Dictionary):
			continue
		var amb_id: String = String(amb.get("id", ""))
		if amb_id.is_empty():
			continue
		var moods: Array = amb.get("moods", [])
		if moods.is_empty() or mood in moods:
			return amb_id
	return ""


func start(ambience_id: String) -> void:
	if ambience_id in _players:
		return
	var amb_path := resolve_path(ambience_id)
	if amb_path.is_empty():
		push_warning("AmbienceController: ambience file not found for '%s'" % ambience_id)
		return
	var cached: AudioStream = load(amb_path) as AudioStream
	if cached == null:
		return
	# load() restituisce l'istanza condivisa della cache risorse: applicare il
	# loop direttamente la muterebbe per chiunque altro carichi lo stesso file
	# (un id presente sia in tracks[] sia in ambience[] si ritroverebbe
	# LOOP_FORWARD sul player musica, e AudioStreamPlayer.finished non
	# scatterebbe mai). La copia e` a buon mercato: i sample sono CoW.
	var stream: AudioStream = cached.duplicate() as AudioStream
	if stream == null:
		return
	_apply_loop(stream)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = linear_to_db(maxf(_current_volume(), 0.0001))
	player.autoplay = true
	add_child(player)
	_players[ambience_id] = player
	if ambience_id not in _active:
		_active.append(ambience_id)


func stop(ambience_id: String) -> void:
	# _active viene ripulito PRIMA della guardia su _players: se le due
	# collezioni divergono (un release_streams a meta` strada), uscire subito
	# lascerebbe l'id in _active per sempre, e get_active_ambience()
	# continuerebbe a dichiarare attiva un'ambience senza player.
	_active.erase(ambience_id)
	if ambience_id not in _players:
		return
	var player: AudioStreamPlayer = _players[ambience_id]
	_players.erase(ambience_id)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()


func stop_all() -> void:
	for amb_id in _active.duplicate():
		stop(String(amb_id))


## Riallinea il volume dei player attivi (chiamato quando cambiano i volumi).
func apply_volume() -> void:
	var db := linear_to_db(maxf(_current_volume(), 0.0001))
	for player in _players.values():
		if is_instance_valid(player):
			player.volume_db = db


## Rilascia gli stream in fase di teardown (stessa ragione di G-054 lato
## musica: l'AudioServer deve mollare i playback prima del check di leak).
## Libera i nodi e azzera ENTRAMBE le collezioni: lasciare _active popolato
## faceva mentire get_active_ambience(), e quello stato finto veniva poi
## persistito in music_state.active_ambience (e nella colonna SQLite
## ambience_enabled) per ambience che non avevano piu` un solo player.
func release_streams() -> void:
	for player in _players.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_players.clear()
	_active.clear()


func resolve_path(ambience_id: String) -> String:
	for amb_data in GameManager.tracks_catalog.get("ambience", []):
		if amb_data is Dictionary and amb_data.get("id", "") == ambience_id:
			return String(amb_data.get("path", ""))
	var ogg_path := "res://assets/audio/ambience/%s.ogg" % ambience_id
	if FileAccess.file_exists(ogg_path):
		return ogg_path
	var wav_path := "res://assets/audio/ambience/%s.wav" % ambience_id
	if FileAccess.file_exists(wav_path):
		return wav_path
	return ""


## I WAV importati non hanno loop di default: il tappeto ambientale deve
## ripetersi senza buchi, e i file sono generati con crossfade di giunzione.
##
## loop_end si ricava dalla durata dichiarata dallo stream, mai da data.size():
## quel calcolo dava per scontato PCM 16 bit stereo (4 byte per frame), ma i
## due ambience sono importati QOA (compress/mode=2), dove `data` sono byte
## compressi. Il risultato era un loop di 5.85 s su 29 s di file, con il taglio
## a meta` contenuto invece che sulla giunzione con crossfade.
func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var frames := int(wav.get_length() * float(wav.mix_rate))
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = frames
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


func _current_volume() -> float:
	if _volume_provider.is_valid():
		return float(_volume_provider.call())
	return 0.4
