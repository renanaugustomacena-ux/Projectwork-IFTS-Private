# gdlint: disable=max-file-lines
## PetController — Autonomous pet behavior with state machine.
## Stati: idle/wander/follow/sleep/play + WILD (tempesta), EAT (ciotola),
## AVOID (confidenza bassa), GO_POTTY/POTTY/ROAM_GARDEN/RETURN_HOME
## (giardino e bisogni). TODO post-demo: estrarre bisogni/giardino in un
## modulo per rientrare sotto 500 righe.
extends CharacterBody2D

enum State { IDLE, WANDER, FOLLOW, SLEEP, PLAY, WILD, EAT, AVOID, GO_POTTY, POTTY, ROAM_GARDEN, RETURN_HOME }

const WANDER_SPEED := 30.0
const FOLLOW_SPEED := 80.0
const FOLLOW_DISTANCE := 120.0
const FOLLOW_STOP_DISTANCE := 40.0
const WANDER_RANGE := 200.0
const STATE_CHANGE_MIN := 3.0
const STATE_CHANGE_MAX := 8.0
const SLEEP_COOLDOWN := 120.0  # 2 min before considering sleep
const PLAY_RANGE := 60.0
const WILD_SPEED := 140.0  # T-R-015i: berserk mode quando mood < stormy
const WILD_REDIRECT_INTERVAL := 0.8  # cambia direzione spesso
const EAT_SPEED := 70.0  # corre verso la ciotola (spec 2026-08-14)
const EAT_REACH := 18.0
const EAT_DURATION := 10.0

# --- Confidenza (fase 2, spec 2026-08-14). Valore persistito 0..100 in
# SaveManager.pet_data.trust; le soglie modulano la FSM esistente. ---
const TRUST_AVOID_BELOW := 20.0  # sotto: ti evita, mai FOLLOW spontaneo
const TRUST_CLOSE_AT := 70.0  # da qui: follow frequente e stretto
const TRUST_BONDED_AT := 90.0  # da qui: dorme solo vicino a te
const TRUST_MEAL_GAIN := 8.0
const TRUST_STORM_GAIN := 1.0
const TRUST_STORM_TICK_SEC := 10.0
const TRUST_STORM_RADIUS := 150.0
## Il pasto conta per la confidenza solo se il gatto ha fame (anti-spam).
const HUNGER_COOLDOWN_SEC := 4.0 * 3600.0
const AVOID_TRIGGER_DIST := 100.0
const AVOID_RELEASE_DIST := 160.0
const FOLLOW_DISTANCE_CLOSE := 90.0
const FOLLOW_STOP_CLOSE := 28.0

# --- Giardino e bisogni (fase 3, spec 2026-08-14). 4 volte al giorno il
# gatto va in giardino; con la tempesta li fa in stanza (sporco pesante).
# Orologio su timestamp Unix persistiti (pet_data.next_potty_at). ---
const GARDEN_ZONE := "garden"
const POTTY_INTERVAL_SEC := 6.0 * 3600.0  # 4 volte al giorno
const POTTY_JITTER_SEC := 3600.0
const POTTY_SQUAT_SEC := 3.0
const MAX_OFFLINE_POTTIES := 8
const GARDEN_SPEED := 55.0
const GARDEN_LINGER_MIN := 8.0
const GARDEN_LINGER_MAX := 16.0
const TARGET_REACH := 12.0

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _idle_timer: float = 0.0
var _wander_target := Vector2.ZERO
var _home_position := Vector2.ZERO
var _character_ref: CharacterBody2D = null
var _rng := RandomNumberGenerator.new()
var _wild_mode_active: bool = false
var _wild_redirect_timer: float = 0.0
var _wild_direction: Vector2 = Vector2.RIGHT
var _last_anim: String = ""
# Accumulatore vicinanza-durante-tempesta (fase 2): +1 trust ogni 10s.
var _storm_bond_timer: float = 0.0
# Fase 3: meta corrente del giro (bisogno o passeggiata) e flag indoor.
var _outing_target := Vector2.ZERO
var _potty_indoor: bool = false
var _garden_linger_left: float = 0.0
# Ground-contact point relative to the body origin, read from the collision
# shape (the collider IS the paws — same convention as character_controller).
var _foot_offset := Vector2.ZERO

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_home_position = position
	collision_mask = 1  # Walls only, don't collide with decorations
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		_foot_offset = shape_node.position
	collision_layer = 0  # Don't block anything
	# B-030: seed deterministico in debug per riproducibilita` FSM pet
	if OS.is_debug_build():
		_rng.seed = Constants.DEBUG_RNG_SEED + 2
	else:
		_rng.randomize()
	_find_character()
	_set_state(State.IDLE)
	# T-R-015i: listen for WILD requests from MoodManager when mood < stormy.
	# Direct static reference (V-083 / 4.1.10-L46): a bus-side rename must
	# fail loudly at parse time, not silently disable WILD behind has_signal.
	SignalBus.pet_wild_mode_requested.connect(_on_wild_mode_requested)
	SignalBus.pet_feed_requested.connect(_on_feed_requested)


## La ciotola attira il gatto da qualsiasi stato: il cibo calma persino il
## WILD (al termine, se la tempesta continua, il WILD riprende).
func _on_feed_requested(_world_position: Vector2) -> void:
	_set_state(State.EAT)


func _on_wild_mode_requested(active: bool) -> void:
	_wild_mode_active = active
	if active:
		# In giardino niente scatto WILD immediato (il clamp lo teletraspor-
		# terebbe dentro): accorcia la passeggiata, il WILD parte al rientro.
		if _state in [State.GO_POTTY, State.POTTY, State.ROAM_GARDEN, State.RETURN_HOME]:
			_garden_linger_left = 0.0
			return
		_set_state(State.WILD)
	elif _state == State.WILD:
		# Tempesta finita: se una ciotola era rimasta abbandonata (il WILD
		# interrompe il pasto), il gatto torna a finirla.
		var has_bowl := not get_tree().get_nodes_in_group("pet_bowl").is_empty()
		_set_state(State.EAT if has_bowl else State.IDLE)


func _physics_process(delta: float) -> void:
	_state_timer += delta
	_idle_timer += delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.FOLLOW:
			_process_follow(delta)
		State.SLEEP:
			_process_sleep(delta)
		State.PLAY:
			_process_play(delta)
		State.WILD:
			_process_wild(delta)
		State.EAT:
			_process_eat(delta)
		State.AVOID:
			_process_avoid(delta)
		State.GO_POTTY:
			_process_go_potty(delta)
		State.POTTY:
			_process_potty(delta)
		State.ROAM_GARDEN:
			_process_roam_garden(delta)
		State.RETURN_HOME:
			_process_return_home(delta)

	_check_potty_due()
	_accrue_storm_bond(delta)
	# Maschera collisioni autoritativa per-frame: fuori dalla stanza (o in
	# uscita) i muri del bordo non valgono, altrimenti bloccherebbero il
	# rientro; dentro tornano solidi. Nessuno stato deve ricordarsi di
	# ripristinarla a mano (fase 3).
	var outing := _state in [State.GO_POTTY, State.POTTY, State.ROAM_GARDEN, State.RETURN_HOME]
	collision_mask = 0 if outing or not Helpers.is_inside_floor(position + _foot_offset) else 1
	# Depth: sort by paw contact y, same band as character and furniture.
	z_index = Helpers.z_for_foot_y(global_position.y + _foot_offset.y)


# ---- Confidenza -------------------------------------------------------------


## Livello di confidenza corrente (0..100, persistito).
func _trust() -> float:
	return clampf(float(SaveManager.pet_data.get("trust", 0.0)), 0.0, 100.0)


## Fascia comportamentale per un valore di trust. Statica e pura: testabile.
static func trust_tier(value: float) -> String:
	if value < TRUST_AVOID_BELOW:
		return "avoid"
	if value >= TRUST_BONDED_AT:
		return "bonded"
	if value >= TRUST_CLOSE_AT:
		return "close"
	return "neutral"


## Guadagno di confidenza per un pasto: pieno se il gatto aveva fame
## (>= 4h dall'ultimo pasto), zero altrimenti. Statica e pura: testabile.
static func meal_trust_gain(last_meal_at: float, now: float) -> float:
	return TRUST_MEAL_GAIN if now - last_meal_at >= HUNGER_COOLDOWN_SEC else 0.0


func _gain_trust(amount: float, reason: String) -> void:
	if amount <= 0.0:
		return
	var new_value := clampf(_trust() + amount, 0.0, 100.0)
	SaveManager.pet_data["trust"] = new_value
	SignalBus.pet_trust_changed.emit(new_value)
	SignalBus.save_requested.emit()
	AppLogger.info("PetController", "trust_gained", {"amount": amount, "reason": reason, "trust": new_value})


## Vicinanza durante la tempesta: il gatto impara che con te e` al sicuro.
func _accrue_storm_bond(delta: float) -> void:
	if not _wild_mode_active or _character_ref == null or not is_instance_valid(_character_ref):
		return
	if position.distance_to(_character_ref.global_position) > TRUST_STORM_RADIUS:
		return
	_storm_bond_timer += delta
	if _storm_bond_timer >= TRUST_STORM_TICK_SEC:
		_storm_bond_timer -= TRUST_STORM_TICK_SEC
		_gain_trust(TRUST_STORM_GAIN, "storm_proximity")


## Sotto la soglia di fiducia il gatto scappa quando ti avvicini troppo.
func _process_avoid(_delta: float) -> void:
	if _character_ref == null or not is_instance_valid(_character_ref):
		_set_state(State.IDLE)
		return
	var away := position - _character_ref.global_position
	if away.length() > AVOID_RELEASE_DIST:
		_set_state(State.IDLE)
		return
	var dir := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	velocity = dir * WANDER_SPEED * 1.3
	move_and_slide()
	var paw := position + _foot_offset
	var clamped := Helpers.clamp_inside_floor(paw)
	if clamped != paw:
		position = clamped - _foot_offset
	if _anim:
		_anim.flip_h = dir.x < 0
	_play_anim("walk")


# ---- Giardino e bisogni (fase 3) -------------------------------------------


## Quanti bisogni sono maturati tra next_at e now, e il nuovo next. Pura e
## statica: e` l'accumulatore temporale del modulo 12, con cap difensivo.
static func accrue_offline_potties(next_at: float, now: float, cap: int = MAX_OFFLINE_POTTIES) -> Dictionary:
	if next_at <= 0.0 or now < next_at:
		return {"count": 0, "next": next_at}
	var count := 0
	var next := next_at
	while next <= now:
		if count < cap:
			count += 1
		next += POTTY_INTERVAL_SEC
	return {"count": count, "next": next}


func _schedule_next_potty() -> void:
	var now := Time.get_unix_time_from_system()
	var jitter := _rng.randf_range(-POTTY_JITTER_SEC, POTTY_JITTER_SEC)
	SaveManager.pet_data["next_potty_at"] = now + POTTY_INTERVAL_SEC + jitter
	SignalBus.save_requested.emit()


## Alla scadenza dell'orologio: con la tempesta il bisogno avviene IN STANZA
## (diventa uno sporco pesante via room_base), altrimenti si esce in giardino.
func _check_potty_due() -> void:
	if _state in [State.GO_POTTY, State.POTTY, State.ROAM_GARDEN, State.RETURN_HOME, State.EAT]:
		return
	var next := float(SaveManager.pet_data.get("next_potty_at", 0.0))
	if next <= 0.0:
		_schedule_next_potty()
		return
	if Time.get_unix_time_from_system() < next:
		return
	_potty_indoor = _wild_mode_active  # tempesta = stessa soglia del WILD
	if _potty_indoor or not Helpers.has_zone(GARDEN_ZONE):
		_potty_indoor = true
		_outing_target = Helpers.clamp_inside_floor(_home_position + _random_offset(120.0))
	else:
		_outing_target = Helpers.random_point_in_zone(GARDEN_ZONE, _rng)
	_set_state(State.GO_POTTY)


func _random_offset(radius: float) -> Vector2:
	return Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))


## Cammina verso `target` clampato all'unione pavimento+giardino.
## Ritorna true quando la meta e` raggiunta.
func _walk_outing(target: Vector2, speed: float) -> bool:
	var dir := target - position
	if dir.length() <= TARGET_REACH:
		velocity = Vector2.ZERO
		return true
	velocity = dir.normalized() * speed
	move_and_slide()
	var paw := position + _foot_offset
	var clamped := Helpers.clamp_inside_floor_or_zone(GARDEN_ZONE, paw)
	if clamped != paw:
		position = clamped - _foot_offset
	if _anim:
		_anim.flip_h = dir.x < 0
	_play_anim("walk")
	return false


func _process_go_potty(_delta: float) -> void:
	if _walk_outing(_outing_target, GARDEN_SPEED if not _potty_indoor else WANDER_SPEED):
		_set_state(State.POTTY)


func _process_potty(_delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("sleep")  # accucciato: il frame piu` vicino senza arte dedicata
	if _anim:
		_anim.scale = Vector2(absf(_anim.scale.x), absf(_anim.scale.x) * 0.85)
	if _state_timer < POTTY_SQUAT_SEC:
		return
	_reset_anim_scale()
	SignalBus.pet_pottied.emit(_potty_indoor)
	_schedule_next_potty()
	AppLogger.info("PetController", "potty_done", {"indoor": _potty_indoor})
	if _potty_indoor:
		_potty_indoor = false
		_set_state(State.WILD if _wild_mode_active else State.IDLE)
	else:
		_garden_linger_left = _rng.randf_range(GARDEN_LINGER_MIN, GARDEN_LINGER_MAX)
		_outing_target = Helpers.random_point_in_zone(GARDEN_ZONE, _rng)
		_set_state(State.ROAM_GARDEN)


func _process_roam_garden(delta: float) -> void:
	_garden_linger_left -= delta
	if _garden_linger_left <= 0.0:
		_outing_target = Helpers.clamp_inside_floor(_home_position + _random_offset(80.0))
		_set_state(State.RETURN_HOME)
		return
	if _walk_outing(_outing_target, GARDEN_SPEED):
		_play_anim("idle")
		if _state_timer > 3.0:
			_state_timer = 0.0
			_outing_target = Helpers.random_point_in_zone(GARDEN_ZONE, _rng)


func _process_return_home(_delta: float) -> void:
	if _walk_outing(_outing_target, GARDEN_SPEED):
		collision_mask = 1  # di nuovo dentro: i muri tornano solidi
		_set_state(State.WILD if _wild_mode_active else State.IDLE)


## True se il gatto diffida e il player e` troppo vicino.
func _should_flee() -> bool:
	if _trust() >= TRUST_AVOID_BELOW:
		return false
	if _character_ref == null or not is_instance_valid(_character_ref):
		return false
	return position.distance_to(_character_ref.global_position) < AVOID_TRIGGER_DIST


func _process_eat(_delta: float) -> void:
	var bowls := get_tree().get_nodes_in_group("pet_bowl")
	if bowls.is_empty():
		_set_state(State.WILD if _wild_mode_active else State.IDLE)
		return
	var bowl := bowls[0] as Node2D
	var dist := position.distance_to(bowl.position)
	if dist > EAT_REACH:
		var dir := (bowl.position - position).normalized()
		velocity = dir * EAT_SPEED
		move_and_slide()
		if _anim:
			_anim.flip_h = dir.x < 0
		_play_anim("walk")
		return
	# Mangia: fermo sulla ciotola, piccolo head-bob procedurale.
	velocity = Vector2.ZERO
	_play_anim("idle")
	if _anim:
		_anim.position.y = -absf(sin(_state_timer * 6.0)) * 2.0
	if _state_timer >= EAT_DURATION:
		_reset_anim_position()
		if is_instance_valid(bowl):
			bowl.queue_free()
		SignalBus.pet_fed.emit()
		# Fase 2: il pasto nutre la confidenza solo se il gatto aveva fame
		# (>= 4h dall'ultimo pasto) — anti spam di croccantini.
		var now := Time.get_unix_time_from_system()
		var gain := meal_trust_gain(float(SaveManager.pet_data.get("last_meal_at", 0.0)), now)
		SaveManager.pet_data["last_meal_at"] = now
		if gain > 0.0:
			_gain_trust(gain, "meal")
		else:
			SignalBus.save_requested.emit()
		_set_state(State.WILD if _wild_mode_active else State.IDLE)


func _process_wild(delta: float) -> void:
	# T-R-015i: movimento erratico veloce finche` mood < stormy threshold.
	_wild_redirect_timer += delta
	if _wild_redirect_timer >= WILD_REDIRECT_INTERVAL:
		_wild_redirect_timer = 0.0
		# Fase 2: da "close" in su, meta` delle corse puntano verso il player —
		# il gatto cerca conforto da chi si e` guadagnato la sua fiducia.
		var seek_player := (
			_trust() >= TRUST_CLOSE_AT
			and _character_ref != null
			and is_instance_valid(_character_ref)
			and _rng.randf() < 0.5
		)
		if seek_player:
			_wild_direction = (_character_ref.global_position - position).normalized()
		else:
			var angle := _rng.randf_range(0.0, TAU)
			_wild_direction = Vector2(cos(angle), sin(angle))
	var speed := WILD_SPEED
	if (
		_trust() >= TRUST_CLOSE_AT
		and _character_ref != null
		and is_instance_valid(_character_ref)
		and position.distance_to(_character_ref.global_position) < 70.0
	):
		speed = WILD_SPEED * 0.25  # vicino a te trema ma si calma
	velocity = _wild_direction * speed
	move_and_slide()
	# Clamp inside the floor polygon (V-043 / 4.1.10-L77) — same helper WANDER
	# uses for its target. The clamp runs on the PAW point, not the origin, so
	# the visible cat stays on the wood. Reflect the direction only when the
	# clamp actually moved the pet, so it bounces off the boundary instead of
	# grinding on it.
	var paw := position + _foot_offset
	var clamped := Helpers.clamp_inside_floor(paw)
	if clamped != paw:
		position = clamped - _foot_offset
		_wild_direction = -_wild_direction
	if _anim != null:
		_anim.flip_h = _wild_direction.x < 0
		_play_anim("walk")


func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("idle")

	# Confidenza bassa: scappa se il player si avvicina troppo (fase 2).
	if _should_flee():
		_set_state(State.AVOID)
		return

	if _state_timer > _random_duration():
		var roll := _rng.randf()
		var tier := trust_tier(_trust())
		# Priorita` 1: dopo cooldown lungo, chance di dormire. Da "bonded" il
		# gatto dorme SOLO vicino al player: se e` lontano prima lo raggiunge.
		if _idle_timer > SLEEP_COOLDOWN and roll < 0.3:
			if tier == "bonded" and _character_ref and _is_far_from_character():
				_set_state(State.FOLLOW)
				return
			_set_state(State.SLEEP)
			return
		# Priorita` 2: se il personaggio si e` allontanato, vai a seguirlo —
		# ma mai sotto la soglia di fiducia, e piu` spesso da "close" in su.
		if _character_ref and _is_far_from_character() and _trust() >= TRUST_AVOID_BELOW:
			var follow_chance := 0.9 if tier == "close" or tier == "bonded" else 0.5
			if roll < follow_chance:
				_set_state(State.FOLLOW)
				return
		# Priorita` 3: altrimenti ~55% di probabilita` di iniziare a vagare
		# nella stanza (fix del gap pre-esistente: senza questa transizione
		# il gatto restava bloccato in idle fino al cooldown di 2 minuti).
		if roll < 0.55:
			_set_state(State.WANDER)
			return
		# Fallback: resetta il timer e resta idle ancora un momento
		_state_timer = 0.0


func _process_wander(_delta: float) -> void:
	if _should_flee():
		_set_state(State.AVOID)
		return
	if _wander_target == Vector2.ZERO:
		_pick_wander_target()

	var dir := (_wander_target - position).normalized()
	velocity = dir * WANDER_SPEED
	move_and_slide()

	_anim.flip_h = dir.x < 0
	_play_anim("walk")

	# Reached target or timeout
	if position.distance_to(_wander_target) < 8.0:
		_set_state(State.IDLE)
	elif _state_timer > 6.0:
		_set_state(State.IDLE)


func _process_follow(_delta: float) -> void:
	if _character_ref == null or not is_instance_valid(_character_ref):
		_find_character()
		if _character_ref == null:
			_set_state(State.IDLE)
			return

	var char_pos := _character_ref.global_position
	var dist := position.distance_to(char_pos)

	var stop_dist := FOLLOW_STOP_CLOSE if _trust() >= TRUST_CLOSE_AT else FOLLOW_STOP_DISTANCE
	if dist < stop_dist:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_state(State.IDLE)
		_idle_timer = 0.0  # Reset sleep timer when near character
		return

	var dir := (char_pos - position).normalized()
	velocity = dir * FOLLOW_SPEED
	move_and_slide()

	_anim.flip_h = dir.x < 0
	_play_anim("walk")

	if _state_timer > 10.0:
		_set_state(State.IDLE)


func _process_sleep(_delta: float) -> void:
	velocity = Vector2.ZERO
	# No move_and_slide — sleeping pet must not drift
	_play_anim("sleep")

	# Gentle breathing scale pulse
	if _anim:
		var breath := 1.0 + sin(_state_timer * 1.5) * 0.03
		var base := absf(_anim.scale.x)
		_anim.scale = Vector2(base, base * breath)

	# Wake up after a while or if character is nearby
	if _state_timer > 15.0:
		_set_state(State.IDLE)
	elif _character_ref and _is_close_to_character():
		_set_state(State.PLAY)
		_idle_timer = 0.0


func _process_play(_delta: float) -> void:
	velocity = Vector2.ZERO
	# No move_and_slide — playing pet stays in place

	# Bounce animation
	if _anim:
		var bounce := absf(sin(_state_timer * 4.0)) * 3.0
		_anim.position.y = -bounce

	_play_anim("idle")

	if _state_timer > 3.0:
		_reset_anim_position()
		_set_state(State.FOLLOW)


func _set_state(new_state: State) -> void:
	if _state == State.SLEEP and new_state != State.SLEEP:
		_reset_anim_scale()
	_state = new_state
	_state_timer = 0.0
	if new_state == State.WANDER:
		_pick_wander_target()


func _pick_wander_target() -> void:
	var offset := Vector2(
		_rng.randf_range(-WANDER_RANGE, WANDER_RANGE),
		_rng.randf_range(-WANDER_RANGE * 0.3, WANDER_RANGE * 0.3),
	)
	_wander_target = _home_position + offset
	# Clamp to floor polygon instead of hardcoded rect (on the paw point, so
	# the sprite never overhangs the floor edge when it arrives).
	_wander_target = Helpers.clamp_inside_floor(_wander_target + _foot_offset) - _foot_offset


func _find_character() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var char_node: Node = parent.get_node_or_null("Character")
	if not (char_node is CharacterBody2D):
		# Fallback sulla proprieta` della stanza: dipendere solo dal nome del
		# nodo rendeva il gatto inerte per tutta la sessione ogni volta che il
		# personaggio veniva ricreato con un nome diverso.
		var from_room: Variant = parent.get("character_node")
		char_node = from_room if from_room is CharacterBody2D else null
	if char_node != null and is_instance_valid(char_node):
		_character_ref = char_node


func _is_far_from_character() -> bool:
	if _character_ref == null:
		return false
	var trigger := FOLLOW_DISTANCE_CLOSE if _trust() >= TRUST_CLOSE_AT else FOLLOW_DISTANCE
	return position.distance_to(_character_ref.global_position) > trigger


func _is_close_to_character() -> bool:
	if _character_ref == null:
		return false
	return position.distance_to(_character_ref.global_position) < PLAY_RANGE


func _random_duration() -> float:
	return _rng.randf_range(STATE_CHANGE_MIN, STATE_CHANGE_MAX)


func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	if anim_name != _last_anim:
		_last_anim = anim_name
		if _anim.sprite_frames and _anim.sprite_frames.has_animation(anim_name):
			_anim.play(anim_name)
		elif _anim.sprite_frames and _anim.sprite_frames.has_animation("default"):
			_anim.play("default")


func _reset_anim_scale() -> void:
	if _anim:
		var base_scale := absf(_anim.scale.x)
		_anim.scale = Vector2(base_scale, base_scale)


func _reset_anim_position() -> void:
	if _anim:
		_anim.position.y = 0.0


func _exit_tree() -> void:
	# T-R-015i: disconnect WILD mode signal to avoid zombies on scene reload
	if SignalBus.pet_wild_mode_requested.is_connected(_on_wild_mode_requested):
		SignalBus.pet_wild_mode_requested.disconnect(_on_wild_mode_requested)
	if SignalBus.pet_feed_requested.is_connected(_on_feed_requested):
		SignalBus.pet_feed_requested.disconnect(_on_feed_requested)
