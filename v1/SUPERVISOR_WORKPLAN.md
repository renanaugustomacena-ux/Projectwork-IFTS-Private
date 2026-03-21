# Piano Operativo — Renan Augusto Macena (Supervisor)

**Data**: 21 Marzo 2026
**Stato**: COMPLETATO (tutte le operazioni autonome)
**Basato su**: AUDIT_REPORT.md — Sezioni 6.3, 6.5, 6.6, 11 (Fasi 1-4)

---

## Indice Operazioni

| # | Fase | File | Problema | Severita' | Stato |
|---|------|------|----------|-----------|-------|
| OP-01 | A | save_manager.gd | Race condition auto-save (manca `_is_saving`) | CRITICO | COMPLETATA |
| OP-02 | A | save_manager.gd | Backup copy senza error checking (C2) | CRITICO | COMPLETATA |
| OP-03 | A | save_manager.gd | `_compare_versions()` non robusta per formati complessi (A8) | ALTO | COMPLETATA |
| OP-04 | A | save_manager.gd | Migrazione v3->v4 non valida struttura inventario (A9) | ALTO | COMPLETATA |
| OP-05 | B | audio_manager.gd | Crossfade tween kill non ferma vecchio player | ALTO | COMPLETATA |
| OP-06 | B | audio_manager.gd | Memory leak ambience player (A4) | ALTO | COMPLETATA |
| OP-07 | B | audio_manager.gd | playlist_mode non validato | MEDIO | COMPLETATA |
| OP-08 | C | supabase_client.gd | Token auth salvati in plaintext (A10) | ALTO | COMPLETATA |
| OP-09 | C | supabase_client.gd | HTTP pool crescita illimitata (A11) | ALTO | COMPLETATA |
| OP-10 | C | supabase_client.gd | Validazione email/password mancante | MEDIO | COMPLETATA |
| OP-11 | D | signal_bus.gd | Aggiungere 3 nuovi segnali architetturali | ARCHITETTURALE | COMPLETATA |
| OP-12 | D | audio_manager.gd | Eliminare scrittura diretta in SaveManager (AR4, AR5) | ARCHITETTURALE | COMPLETATA |
| OP-13 | D | performance_manager.gd | Eliminare scrittura diretta in SaveManager (AR6) | ARCHITETTURALE | COMPLETATA |
| OP-14 | D | save_manager.gd + local_database.gd | Ascoltare nuovi segnali + disaccoppiare da LocalDatabase (AR1, AR2, AR3) | ARCHITETTURALE | COMPLETATA |

---

## OPERAZIONE BLOCCATA (da completare DOPO il lavoro di Elia)

| # | File | Problema | Dipende da |
|---|------|----------|------------|
| OP-BLK-01 | save_manager.gd | C1 — Inventario MAI salvato su SQLite | Elia deve completare C3 (schema characters) e C4 (schema inventario) |

---

## Fase A — SaveManager: Integrita' Dati

### OP-01: Race condition auto-save

**File**: `v1/scripts/autoload/save_manager.gd`
**Righe coinvolte**: 48, 64-67, 70-107
**Problema**: Il timer auto-save (ogni 60s) puo' chiamare `save_game()` mentre un salvataggio manuale e' gia' in corso. Due scritture simultanee sullo stesso file = potenziale corruzione dati.

**Istruzioni**:

1. Aggiungere variabile `_is_saving` dopo riga 48:

```gdscript
# Dopo: var _save_dirty: bool = false (riga 48)
# Aggiungere:
var _is_saving: bool = false
```

2. Proteggere `save_game()` con il flag — wrappare il corpo della funzione (riga 70):

```gdscript
func save_game() -> void:
	if _is_saving:
		AppLogger.warn("SaveManager", "Salvataggio gia' in corso, skip")
		return

	_is_saving = true

	# ... tutto il corpo esistente della funzione (righe 71-107) ...

	_is_saving = false
```

3. Proteggere anche `_on_auto_save()` — resettare dirty PRIMA di chiamare save (riga 64):

```gdscript
func _on_auto_save() -> void:
	if _save_dirty:
		_save_dirty = false
		save_game()
```

**Razionale del cambio a `_on_auto_save()`**: Se `_save_dirty = false` viene eseguito DOPO `save_game()` (come nel codice originale), e `save_game()` viene skippato dal flag `_is_saving`, il dirty flag resterebbe `true` per sempre, ritentando ogni ciclo del timer inutilmente. Resettandolo PRIMA, si evita questo loop.

---

### OP-02: Backup copy senza error checking (C2)

**File**: `v1/scripts/autoload/save_manager.gd`
**Righe coinvolte**: 92-93
**Problema**: `DirAccess.copy_absolute()` non controlla il risultato. Se il disco e' pieno o i permessi sono insufficienti, il backup non viene creato e nessuno lo sa.

**Codice attuale** (riga 92-93):
```gdscript
if FileAccess.file_exists(SAVE_PATH):
    DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
```

**Sostituzione**:
```gdscript
if FileAccess.file_exists(SAVE_PATH):
    var src := ProjectSettings.globalize_path(SAVE_PATH)
    var dst := ProjectSettings.globalize_path(BACKUP_PATH)
    var err := DirAccess.copy_absolute(src, dst)
    if err != OK:
        AppLogger.error("SaveManager", "Backup fallito", {"errore": err, "src": src, "dst": dst})
```

---

### OP-03: Version comparison non robusta (A8)

**File**: `v1/scripts/autoload/save_manager.gd`
**Righe coinvolte**: 275-284
**Problema**: `int()` su stringhe non numeriche (es. "0-beta") ritorna 0 silenziosamente, rendendo la comparazione inaffidabile.

**Codice attuale** (riga 275-284):
```gdscript
func _compare_versions(a: String, b: String) -> int:
    var parts_a := a.split(".")
    var parts_b := b.split(".")
    var max_len := maxi(parts_a.size(), parts_b.size())
    for i in range(max_len):
        var num_a: int = int(parts_a[i]) if i < parts_a.size() else 0
        var num_b: int = int(parts_b[i]) if i < parts_b.size() else 0
        if num_a != num_b:
            return 1 if num_a > num_b else -1
    return 0
```

**Sostituzione**:
```gdscript
func _compare_versions(a: String, b: String) -> int:
	var parts_a := a.split(".")
	var parts_b := b.split(".")
	var max_len := maxi(parts_a.size(), parts_b.size())
	for i in range(max_len):
		var raw_a: String = parts_a[i] if i < parts_a.size() else "0"
		var raw_b: String = parts_b[i] if i < parts_b.size() else "0"
		var num_a: int = int(raw_a) if raw_a.is_valid_int() else 0
		var num_b: int = int(raw_b) if raw_b.is_valid_int() else 0
		if num_a != num_b:
			return 1 if num_a > num_b else -1
	return 0
```

**Differenza chiave**: Aggiunto `is_valid_int()` come guardia prima di `int()`. Versioni come "1.0.0-beta" vengono gestite senza comportamento silenzioso scorretto.

---

### OP-04: Migrazione v3->v4 non valida struttura inventario (A9)

**File**: `v1/scripts/autoload/save_manager.gd`
**Righe coinvolte**: 245-271
**Problema**: La migrazione da v3 a v4 aggiunge la sezione "inventory" se mancante, ma non valida che i dati dell'inventario (se gia' presenti) abbiano la struttura corretta. Dati malformati passano silenziosamente.

**Dopo riga 262 (`data.erase("updated_at")`)**, aggiungere validazione:
```gdscript
		# Validazione inventario esistente prima della migrazione
		if "inventory" in data and data["inventory"] is Dictionary:
			var inv: Dictionary = data["inventory"]
			if not inv.has("coins") or not inv.has("items"):
				AppLogger.warn(
					"SaveManager",
					"Inventario corrotto durante migrazione v3->v4, reset",
					{"inventory_keys": inv.keys()}
				)
				data["inventory"] = {
					"coins": inv.get("coins", old_coins),
					"capacita": inv.get("capacita", 50),
					"items": [],
				}
			elif inv["items"] is not Array:
				data["inventory"]["items"] = []
```

---

## Fase B — AudioManager: Memoria e Stabilita'

### OP-05: Crossfade tween kill non ferma vecchio player

**File**: `v1/scripts/autoload/audio_manager.gd`
**Righe coinvolte**: 190-219
**Problema**: Quando un nuovo crossfade inizia mentre uno e' in corso (riga 192-194), il tween viene killato, ma il callback `old_player.stop` (riga 215) non viene mai eseguito. Il vecchio player continua a suonare in background a volume -80dB, sprecando risorse.

**Codice attuale** (riga 190-194):
```gdscript
func _crossfade_to(stream: AudioStream) -> void:
    # Kill any running crossfade
    if _crossfade_tween != null and _crossfade_tween.is_running():
        _crossfade_tween.kill()
        _crossfade_tween = null
```

**Sostituzione** (riga 190-194):
```gdscript
func _crossfade_to(stream: AudioStream) -> void:
	# Kill any running crossfade and stop the player that was fading out
	if _crossfade_tween != null and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		_crossfade_tween = null
		# Fermare entrambi i player non-attivi per evitare suoni fantasma
		if _active_player == _music_player_a and _music_player_b.playing:
			_music_player_b.stop()
		elif _active_player == _music_player_b and _music_player_a.playing:
			_music_player_a.stop()
```

---

### OP-06: Memory leak ambience player (A4)

**File**: `v1/scripts/autoload/audio_manager.gd`
**Righe coinvolte**: 270-278
**Problema**: In `_stop_ambience()`, il player viene fermato e schedulato per la distruzione con `queue_free()`, ma se un altro pezzo di codice accede a `_ambience_players[key]` prima della distruzione effettiva (fine frame), ottiene un riferimento a un nodo in via di eliminazione.

**Codice attuale** (riga 270-278):
```gdscript
func _stop_ambience(ambience_id: String) -> void:
    if ambience_id not in _ambience_players:
        return
    var player: AudioStreamPlayer = _ambience_players[ambience_id]
    player.stop()
    player.queue_free()
    _ambience_players.erase(ambience_id)
    active_ambience.erase(ambience_id)
    _sync_music_state()
```

**Sostituzione**:
```gdscript
func _stop_ambience(ambience_id: String) -> void:
	if ambience_id not in _ambience_players:
		return
	var player: AudioStreamPlayer = _ambience_players[ambience_id]
	_ambience_players.erase(ambience_id)
	active_ambience.erase(ambience_id)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_sync_music_state()
```

**Differenza chiave**: `_ambience_players.erase()` viene PRIMA di `queue_free()`, cosi' nessun codice puo' ottenere un riferimento stale. Aggiunto `is_instance_valid()` come guardia.

---

### OP-07: playlist_mode non validato

**File**: `v1/scripts/autoload/audio_manager.gd`
**Righe coinvolte**: 10-13
**Problema**: Il setter di `playlist_mode` accetta qualsiasi stringa. Valori invalidi passano silenziosamente e causano nessuna azione nel `match` di `next_track()` (riga 119).

**Codice attuale** (riga 10-13):
```gdscript
var playlist_mode: String = "shuffle":
    set(value):
        playlist_mode = value
        _sync_music_state()
```

**Sostituzione**:
```gdscript
var playlist_mode: String = "shuffle":
	set(value):
		if value not in ["sequential", "shuffle", "repeat_one"]:
			push_warning("AudioManager: playlist_mode invalido '%s', fallback 'shuffle'" % value)
			value = "shuffle"
		playlist_mode = value
		_sync_music_state()
```

---

## Fase C — SupabaseClient: Sicurezza e Stabilita'

### OP-08: Token auth salvati in plaintext (A10)

**File**: `v1/scripts/autoload/supabase_client.gd`
**Righe coinvolte**: 289-297, 224-250
**Problema**: I token di refresh vengono salvati come JSON in chiaro in `user://auth.cfg`. Chiunque acceda al file system dell'utente puo' leggere il token e impersonare l'utente.

**Soluzione**: Usare `ConfigFile` con `save_encrypted_pass()` di Godot, che cifra il file con una passphrase derivata.

**Codice attuale `_save_auth_tokens()`** (riga 289-297):
```gdscript
func _save_auth_tokens() -> void:
    if _refresh_token.is_empty():
        return
    var data := {"refresh_token": _refresh_token}
    var file := FileAccess.open(AUTH_TOKEN_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        file.close()
```

**Sostituzione `_save_auth_tokens()`**:
```gdscript
func _save_auth_tokens() -> void:
	if _refresh_token.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", _refresh_token)
	var err := cfg.save_encrypted_pass(AUTH_TOKEN_PATH, _get_encryption_key())
	if err != OK:
		AppLogger.error("SupabaseClient", "Salvataggio token fallito", {"errore": err})
```

**Codice attuale `_try_restore_session()`** (riga 224-250): Legge JSON plaintext.

**Sostituzione `_try_restore_session()`**:
```gdscript
func _try_restore_session() -> void:
	if not is_configured():
		return
	if not FileAccess.file_exists(AUTH_TOKEN_PATH):
		return

	var cfg := ConfigFile.new()
	var err := cfg.load_encrypted_pass(AUTH_TOKEN_PATH, _get_encryption_key())
	if err != OK:
		# Tentativo fallback per file vecchio formato plaintext (migrazione)
		_try_restore_legacy_session()
		return

	_refresh_token = cfg.get_value("auth", "refresh_token", "")
	if not _refresh_token.is_empty():
		AppLogger.debug("SupabaseClient", "Found saved session, attempting refresh")
		call_deferred("_deferred_refresh")
```

**Aggiungere nuova funzione** (dopo `_try_restore_session`):
```gdscript
func _try_restore_legacy_session() -> void:
	var file := FileAccess.open(AUTH_TOKEN_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return
	_refresh_token = data.get("refresh_token", "")
	if not _refresh_token.is_empty():
		AppLogger.info("SupabaseClient", "Migrating legacy auth tokens to encrypted format")
		_save_auth_tokens()
		call_deferred("_deferred_refresh")


func _get_encryption_key() -> String:
	return "MCR_%s_%s" % [OS.get_unique_id(), _anon_key.left(16)]
```

**Nota sulla chiave**: `OS.get_unique_id()` lega la cifratura al dispositivo fisico. `_anon_key.left(16)` aggiunge un componente specifico al progetto. Non e' crittografia di livello militare, ma e' enormemente meglio del plaintext ed e' appropriato per un'app desktop locale.

---

### OP-09: HTTP pool crescita illimitata (A11)

**File**: `v1/scripts/autoload/supabase_client.gd`
**Righe coinvolte**: 337-348
**Problema**: `_get_available_http()` crea un nuovo `HTTPRequest` quando tutti sono occupati e lo aggiunge al pool, ma non lo rimuove mai. Sessioni lunghe = crescita illimitata.

**Codice attuale `_get_available_http()`** (riga 337-348):
```gdscript
func _get_available_http() -> HTTPRequest:
    for http in _http_pool:
        if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
            return http
    # All busy — create a temporary one
    var http := HTTPRequest.new()
    http.timeout = REQUEST_TIMEOUT
    add_child(http)
    _http_pool.append(http)
    AppLogger.debug("SupabaseClient", "HTTP pool expanded", {"size": _http_pool.size()})
    return http
```

**Sostituzione**:
```gdscript
const MAX_POOL_SIZE := 8

func _get_available_http() -> HTTPRequest:
	# Prima: cercare un client libero nel pool esistente
	for http in _http_pool:
		if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return http

	# Pool pieno: espandere solo se sotto il limite
	if _http_pool.size() < MAX_POOL_SIZE:
		var http := HTTPRequest.new()
		http.timeout = REQUEST_TIMEOUT
		add_child(http)
		_http_pool.append(http)
		AppLogger.debug("SupabaseClient", "HTTP pool expanded", {"size": _http_pool.size()})
		return http

	# Limite raggiunto: attendere che un client si liberi
	AppLogger.warn("SupabaseClient", "HTTP pool al limite, attesa client libero", {"max": MAX_POOL_SIZE})
	while true:
		await get_tree().process_frame
		for http in _http_pool:
			if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				return http

	# Unreachable, ma necessario per il type checker
	return _http_pool[0]
```

**Aggiungere anche** la costante `MAX_POOL_SIZE := 8` dopo riga 14 (`POOL_SIZE := 4`).

---

### OP-10: Validazione email/password mancante

**File**: `v1/scripts/autoload/supabase_client.gd`
**Righe coinvolte**: 77-89, 93-109
**Problema**: `sign_up()` e `sign_in_email()` non validano input vuoti prima di inviare la richiesta al server.

**In `sign_up()` — dopo riga 79** (`return _offline_error()`), aggiungere:
```gdscript
	if email.strip_edges().is_empty() or password.is_empty():
		AppLogger.warn("SupabaseClient", "Sign up: email o password vuoti")
		return {"error": "validation_failed", "message": "Email and password are required"}
```

**In `sign_in_email()` — dopo riga 95** (`return _offline_error()`), aggiungere lo stesso blocco:
```gdscript
	if email.strip_edges().is_empty() or password.is_empty():
		AppLogger.warn("SupabaseClient", "Sign in: email o password vuoti")
		return {"error": "validation_failed", "message": "Email and password are required"}
```

---

## Fase D — Allineamento Architetturale (SignalBus)

### OP-11: Aggiungere 3 nuovi segnali al SignalBus

**File**: `v1/scripts/autoload/signal_bus.gd`
**Posizione**: Dopo riga 32 (sezione Save/Load signals)

**Aggiungere**:
```gdscript
# Settings update signal (replaces direct writes to SaveManager.settings)
signal settings_updated(key: String, value: Variant)

# Music state signal (replaces direct write to SaveManager.music_state)
signal music_state_updated(state: Dictionary)

# Database persistence signal (replaces direct calls to LocalDatabase)
signal save_to_database_requested(data: Dictionary)
```

---

### OP-12: AudioManager — eliminare scrittura diretta in SaveManager

**File**: `v1/scripts/autoload/audio_manager.gd`
**Violazioni**: AR4 (riga 292, 295, 298), AR5 (riga 324)

**12a — `_on_volume_changed()`**: Sostituire scritture dirette con emissione segnale.

**Codice attuale** (riga 288-301):
```gdscript
func _on_volume_changed(bus_name: String, volume: float) -> void:
    match bus_name:
        "master":
            master_volume = volume
            SaveManager.settings["master_volume"] = volume
        "music":
            music_volume = volume
            SaveManager.settings["music_volume"] = volume
        "ambience":
            ambience_volume = volume
            SaveManager.settings["ambience_volume"] = volume
    _apply_music_volume()
    _apply_ambience_volume()
    SignalBus.save_requested.emit()
```

**Sostituzione**:
```gdscript
func _on_volume_changed(bus_name: String, volume: float) -> void:
	match bus_name:
		"master":
			master_volume = volume
		"music":
			music_volume = volume
		"ambience":
			ambience_volume = volume
		_:
			push_warning("AudioManager: bus_name sconosciuto '%s'" % bus_name)
			return
	SignalBus.settings_updated.emit("%s_volume" % bus_name, volume)
	_apply_music_volume()
	_apply_ambience_volume()
```

**Nota**: `SignalBus.save_requested.emit()` non serve piu' qui perche' sara' il SaveManager, alla ricezione di `settings_updated`, a marcarsi dirty.

**12b — `_sync_music_state()`**: Sostituire scrittura diretta con emissione segnale.

**Codice attuale** (riga 323-329):
```gdscript
func _sync_music_state() -> void:
    SaveManager.music_state = {
        "current_track_index": current_track_index,
        "playlist_mode": playlist_mode,
        "active_ambience": active_ambience.duplicate(),
    }
    SignalBus.save_requested.emit()
```

**Sostituzione**:
```gdscript
func _sync_music_state() -> void:
	SignalBus.music_state_updated.emit({
		"current_track_index": current_track_index,
		"playlist_mode": playlist_mode,
		"active_ambience": active_ambience.duplicate(),
	})
```

**12c — `_on_load_completed()`**: Sostituire lettura diretta da SaveManager (riga 55-66).

**Codice attuale** (riga 55-66):
```gdscript
func _on_load_completed() -> void:
    var state: Dictionary = SaveManager.music_state
    current_track_index = state.get("current_track_index", 0)
    playlist_mode = state.get("playlist_mode", "shuffle")
    active_ambience = state.get("active_ambience", [])
    if not tracks.is_empty():
        current_track_index = clampi(current_track_index, 0, tracks.size() - 1)
    master_volume = SaveManager.settings.get("master_volume", 0.8)
    music_volume = SaveManager.settings.get("music_volume", 0.6)
    ambience_volume = SaveManager.settings.get("ambience_volume", 0.4)
```

**Nota**: La lettura dei dati da SaveManager durante `load_completed` e' accettabile architetturalmente — il segnale `load_completed` e' il meccanismo previsto per sincronizzare lo stato dopo il caricamento. Le letture qui restano invariate. Il problema architetturale erano le SCRITTURE dirette (AR4, AR5), che sono risolte nei punti 12a e 12b.

---

### OP-13: PerformanceManager — eliminare scrittura diretta in SaveManager

**File**: `v1/scripts/systems/performance_manager.gd`
**Violazione**: AR6 (riga 53-54)

**Codice attuale `_notification()`** (riga 50-54):
```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        var pos := get_window().position
        SaveManager.settings["window_pos_x"] = pos.x
        SaveManager.settings["window_pos_y"] = pos.y
```

**Sostituzione**:
```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var pos := get_window().position
		SignalBus.settings_updated.emit("window_pos_x", pos.x)
		SignalBus.settings_updated.emit("window_pos_y", pos.y)
```

**Nota**: La lettura in `_on_load_completed()` (riga 23-24) da `SaveManager.settings` resta invariata — e' una lettura legittima post-caricamento.

---

### OP-14: SaveManager — ascoltare nuovi segnali e disaccoppiare da LocalDatabase

**File**: `v1/scripts/autoload/save_manager.gd`
**Violazioni**: AR1, AR2, AR3

**14a — Connettere i nuovi segnali in `_ready()`** (dopo riga 57):
```gdscript
	SignalBus.settings_updated.connect(_on_settings_updated)
	SignalBus.music_state_updated.connect(_on_music_state_updated)
```

**14b — Aggiungere i handler** (dopo `_mark_dirty()`):
```gdscript
func _on_settings_updated(key: String, value: Variant) -> void:
	settings[key] = value
	_mark_dirty()


func _on_music_state_updated(state: Dictionary) -> void:
	music_state = state
	_mark_dirty()
```

**14c — Disaccoppiare `_save_to_sqlite()` via segnale** (riga 110-121):

**Codice attuale**:
```gdscript
func _save_to_sqlite() -> void:
    if not LocalDatabase.is_open():
        return
    var account := LocalDatabase.get_account_by_auth_uid("local")
    ...
    LocalDatabase.upsert_character(account_id, character_data)
```

**Sostituzione**:
```gdscript
func _save_to_sqlite() -> void:
	SignalBus.save_to_database_requested.emit({
		"character": character_data,
		"inventory": inventory_data,
	})
```

**ATTENZIONE**: Questa modifica richiede che `local_database.gd` si connetta al segnale `save_to_database_requested` nel proprio `_ready()`. Dato che `local_database.gd` e' nel perimetro di Elia, **comunicare a Elia** che deve aggiungere nella sua `_ready()`:
```gdscript
SignalBus.save_to_database_requested.connect(_on_save_requested)
```
E implementare `_on_save_requested(data: Dictionary)` con la logica di account lookup + upsert attualmente in `save_manager.gd:110-121`.

Se Elia non ha ancora iniziato il suo lavoro, possiamo **posticipare OP-14c** e fare solo OP-14a e OP-14b (che sono autonomi).

---

## Checklist di Verifica Post-Implementazione

Per ogni operazione completata, verificare:

- [ ] `gdlint v1/scripts/` passa senza errori
- [ ] `gdformat --check v1/scripts/` passa senza errori
- [ ] Il gioco si avvia senza errori nella console di Godot
- [ ] Il salvataggio automatico funziona (aspettare 60s, verificare `user://save_data.json`)
- [ ] Il backup viene creato correttamente
- [ ] La musica fa crossfade senza player fantasma
- [ ] I suoni ambientali si avviano e si fermano correttamente
- [ ] Il volume cambia correttamente per tutti i bus (master, music, ambience)

---

## Note per le Operazioni Bloccate

### OP-BLK-01: Inventario su SQLite (C1)

**Precondizione**: Elia deve completare:
1. **C3** — Ridisegnare tabella `characters` (character_id come PK al posto di account_id)
2. **C4** — Ristrutturare tabella `inventario` (coins/capacita spostati in accounts, FK su item_id)

**Quando Elia avra' completato**, aggiungere in `_save_to_sqlite()` (o nel handler del segnale `save_to_database_requested`) il salvataggio dell'inventario. Il codice e' gia' descritto nella Sezione 12 dell'AUDIT_REPORT.md sotto "C1".
