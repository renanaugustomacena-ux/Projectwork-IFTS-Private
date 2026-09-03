## MessNode — Oggetto sporco con pulizia a tempo (spec 2026-08-14).
##
## FSM minimale sul dato persistito: DIRTY (cleaning_ends_at == 0) →
## CLEANING (ends_at = timestamp Unix reale) → completata. Il timestamp,
## non un timer, e` l'autorita`: al riavvio la barra riprende esatta e una
## pulizia puo` finire a gioco chiuso (room_base accredita al load).
## Il player avvia con E (tasto "interact"); coins e rimozione dello stress
## arrivano SOLO al completamento.
class_name MessNode
extends Area2D

## Layer fisico degli interagibili: la query del personaggio cerca qui.
const INTERACT_LAYER := 4

## Padding extra intorno allo sprite per rendere piu` permissiva l'interazione.
const INTERACTION_PADDING: float = 6.0

## Coin reward di default per pulire un mess (se non override dal catalog).
const DEFAULT_CLEAN_REWARD: int = 2
const DEFAULT_CLEAN_DURATION: float = 7.0

const BAR_SIZE := Vector2(36, 5)

## "Puff" procedurale all'avvio della pulizia (P9): puntini che salgono e
## sfumano, disegnati in _draw() — nessuna texture.
const PUFF_SEC := 0.4
const PUFF_DOTS := 5

var mess_id: String = ""
var stress_weight: float = 0.10
var clean_reward: int = DEFAULT_CLEAN_REWARD
var clean_duration: float = DEFAULT_CLEAN_DURATION
## Entry dentro SaveManager._messes: stessa identita` usata per la rimozione
## (pattern di _decorations). Vuoto solo nei test che non persistono.
var save_entry: Dictionary = {}
var _prompt_released: bool = false
var _last_sec_left: int = -1

var _sprite: Sprite2D
var _cleaning_started_at: float = 0.0
var _last_bar_px: int = -1
# Tempo residuo del puff (> 0 = in corso); decresce in _process, che e` gia`
# attivo durante la pulizia.
var _puff_t: float = 0.0


func setup(entry: Dictionary, world_position: Vector2, persisted: Dictionary = {}) -> void:
	mess_id = entry.get("id", "")
	stress_weight = float(entry.get("stress_weight", 0.10))
	clean_reward = int(entry.get("clean_reward", DEFAULT_CLEAN_REWARD))
	clean_duration = maxf(float(entry.get("clean_duration_sec", DEFAULT_CLEAN_DURATION)), 1.0)
	save_entry = persisted
	position = world_position
	name = "Mess_%s" % mess_id

	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _resolve_texture(entry)
	add_child(_sprite)
	# Depth: a mess lies on the floor — sort by its bottom edge like every
	# other grounded entity (see Helpers z bands).
	var mess_tex := _sprite.texture
	var half_h: float = mess_tex.get_size().y * 0.5 if mess_tex else 16.0
	z_index = Helpers.z_for_foot_y(world_position.y + half_h)

	collision_layer = INTERACT_LAYER
	collision_mask = 1  # Detects character on layer 1
	monitoring = true
	monitorable = true  # la shape-query del personaggio deve poterlo vedere
	set_meta("interaction_type", "clean")
	set_meta("item_id", mess_id)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex := _sprite.texture
	var tex_size: Vector2 = tex.get_size() if tex else Vector2(32, 32)
	rect.size = tex_size + Vector2.ONE * INTERACTION_PADDING * 2.0
	shape.shape = rect
	add_child(shape)

	# Una pulizia gia` in corso nel salvataggio riprende dai suoi timestamp
	# (started_at persistito per una barra fedele anche dopo il riavvio).
	if ends_at() > 0.0:
		_clamp_persisted_deadline()
		_cleaning_started_at = float(save_entry.get("cleaning_started_at", ends_at() - clean_duration))


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(is_cleaning())


func _exit_tree() -> void:
	# GP-16: un mess liberato da _reload_messes con il personaggio sopra non
	# emette body_exited (i segnali vengono staccati qui sotto) e il prompt
	# "Premi E" restava acceso per sempre. _complete() ha gia` pareggiato.
	if not _prompt_released and monitoring and is_inside_tree():
		for body in get_overlapping_bodies():
			if body is CharacterBody2D:
				_prompt_released = true
				SignalBus.interaction_unavailable.emit()
				break
	# Disconnect esplicito per evitare zombie signal se il mess viene free
	# durante un'interazione in corso (fix B-012).
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)


func ends_at() -> float:
	return float(save_entry.get("cleaning_ends_at", 0.0))


func is_cleaning() -> bool:
	return ends_at() > 0.0


## Invocata dal sistema di interazione (tasto E del personaggio). False se
## la pulizia era gia` in corso: il personaggio non deve mimare un'azione
## che non e` partita (PT-28).
func on_interact(_player: Node) -> bool:
	return start_cleaning()


## Avvia la pulizia: durata dal catalogo divisa per il miglior attrezzo
## posseduto AL momento dell'avvio (un attrezzo comprato dopo non retro-
## agisce sulle pulizie gia` in corso).
func start_cleaning() -> bool:
	if is_cleaning():
		return false
	var mult: float = maxf(GameManager.best_tool_multiplier(), 1.0)
	var duration := clean_duration / mult
	var now := Time.get_unix_time_from_system()
	_cleaning_started_at = now
	save_entry["cleaning_started_at"] = now
	save_entry["cleaning_ends_at"] = now + duration
	SignalBus.save_requested.emit()
	_puff_t = PUFF_SEC
	set_process(true)
	queue_redraw()
	AudioManager.play_sfx("clean_start")
	AppLogger.info("MessNode", "cleaning_started", {"id": mess_id, "duration_s": duration})
	# Le pulizie lunghe vanno annunciate: una barra di 36 px che non si muove
	# per un'ora sembrava un gioco rotto (PT-29). Corte = solo la barra.
	if duration >= 60.0:
		SignalBus.toast_requested.emit(tr("TOAST_CLEAN_STARTED") % format_time_left(duration), "info")
	return true


func _process(delta: float) -> void:
	if not is_cleaning():
		set_process(false)
		return
	if Time.get_unix_time_from_system() >= ends_at():
		_complete()
		return
	if _puff_t > 0.0:
		_puff_t = maxf(_puff_t - delta, 0.0)
		queue_redraw()
	# Ridisegna solo quando la barra avanza di un pixel (review 2026-08-14):
	# su una pulizia da 1h il redraw a 60Hz dipingeva pixel identici per il
	# 99.98% dei frame.
	var px := _bar_fill_px()
	var sec_left := int(ceili(ends_at() - Time.get_unix_time_from_system()))
	if px != _last_bar_px or sec_left != _last_sec_left:
		_last_bar_px = px
		_last_sec_left = sec_left
		queue_redraw()


func _bar_fill_px() -> int:
	var total := ends_at() - _cleaning_started_at
	if total <= 0.0:
		return int(BAR_SIZE.x)
	var ratio := clampf((Time.get_unix_time_from_system() - _cleaning_started_at) / total, 0.0, 1.0)
	return int((BAR_SIZE.x - 2.0) * ratio)


func _complete() -> void:
	# Review 2026-08-14: se il personaggio e` SOPRA il mess al completamento,
	# il body_exited non arriva mai (nodo liberato) e il prompt "Premi E"
	# resterebbe acceso per sempre — pareggia il contatore esplicitamente.
	if monitoring:
		for body in get_overlapping_bodies():
			if body is CharacterBody2D:
				_prompt_released = true
				SignalBus.interaction_unavailable.emit()
				break
	SaveManager.credit_coins(clean_reward)
	if not save_entry.is_empty():
		SaveManager.remove_mess(save_entry)
	SignalBus.mess_cleaned.emit(mess_id)
	AudioManager.play_sfx("clean_done")
	SignalBus.toast_requested.emit(tr("TOAST_CLEAN_DONE") % clean_reward, "info")
	SignalBus.save_requested.emit()
	queue_free()


## Pulizia istantanea legacy (usata dai test pre-fase-economia).
func clean() -> void:
	_complete()


func _draw() -> void:
	if _puff_t > 0.0:
		_draw_puff()
	if not is_cleaning():
		return
	var now := Time.get_unix_time_from_system()
	var total := ends_at() - _cleaning_started_at
	var ratio := clampf((now - _cleaning_started_at) / total, 0.0, 1.0) if total > 0.0 else 1.0
	var tex := _sprite.texture if _sprite else null
	var top_y: float = -(tex.get_size().y * 0.5 if tex else 16.0) - 10.0
	var origin := Vector2(-BAR_SIZE.x * 0.5, top_y)
	draw_rect(Rect2(origin, BAR_SIZE), Color(0, 0, 0, 0.55))
	draw_rect(
		Rect2(origin + Vector2.ONE, Vector2((BAR_SIZE.x - 2.0) * ratio, BAR_SIZE.y - 2.0)), Color(0.55, 0.85, 1.0, 0.9)
	)
	# Tempo residuo sopra la barra: per le pulizie da minuti/ore e` l'unica
	# cosa che dice al giocatore che il gioco sta lavorando (PT-29).
	var left := maxf(ends_at() - now, 0.0)
	if left >= 10.0:
		var label := format_time_left(left)
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(
			font, Vector2(-width * 0.5, top_y - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9)
		)


## Cinque puntini a ventaglio che salgono e sfumano in PUFF_SEC (P9): il
## progresso e` derivato da _puff_t, quindi il disegno e` puro e senza stato.
func _draw_puff() -> void:
	var progress := 1.0 - clampf(_puff_t / PUFF_SEC, 0.0, 1.0)
	var alpha := (1.0 - progress) * 0.9
	var dot_radius := 2.0 - progress
	for i in range(PUFF_DOTS):
		var angle := -PI * 0.5 + (float(i) - (PUFF_DOTS - 1) * 0.5) * 0.55
		var start := Vector2(cos(angle) * 8.0, -4.0)
		var drift := Vector2(cos(angle) * 6.0, -14.0) * progress
		draw_circle(start + drift, dot_radius, Color(1, 1, 1, alpha))


## "mm:ss" sotto l'ora, "h:mm" oltre. Statica: usabile dai toast.
static func format_time_left(seconds: float) -> String:
	var total := int(ceili(seconds))
	if total >= 3600:
		return "%d:%02d h" % [total / 3600, (total % 3600) / 60]
	return "%d:%02d" % [total / 60, total % 60]


## Difesa (void, solo side-effect dichiarato nel nome — review 2026-08-14):
## un ends_at assurdo (orologio spostato in avanti di giorni) viene clampato
## alla durata massima possibile del catalogo per questo mess.
func _clamp_persisted_deadline() -> void:
	var now := Time.get_unix_time_from_system()
	if ends_at() - now > clean_duration:
		save_entry["cleaning_ends_at"] = now + clean_duration
		# SM-19: anche l'inizio, altrimenti la barra parte quasi piena.
		save_entry["cleaning_started_at"] = now
		AppLogger.warn("MessNode", "ends_at_clamped", {"id": mess_id})


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_available.emit(mess_id, "clean")


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		SignalBus.interaction_unavailable.emit()


func _resolve_texture(entry: Dictionary) -> Texture2D:
	var path: String = entry.get("sprite_path", "")
	if not path.is_empty():
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D

	# Placeholder runtime: disegna un cerchio pieno con outline scuro nel colore
	# del catalog. Serve come segnaposto finche` l'arte originale non viene
	# disegnata e l'entry non riceve un sprite_path valido.
	var size: int = int(entry.get("size_px", 32))
	size = clampi(size, 12, 96)
	var color_hex: String = entry.get("placeholder_color", "#b8a892")
	return _make_placeholder_texture(size, Color(color_hex))


func _make_placeholder_texture(size: int, fill: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var radius: float = float(size) * 0.5 - 1.0
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var outline := fill.darkened(0.45)
	for y in range(size):
		for x in range(size):
			var dist := center.distance_to(Vector2(x, y))
			if dist <= radius - 1.5:
				img.set_pixel(x, y, fill)
			elif dist <= radius:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)
