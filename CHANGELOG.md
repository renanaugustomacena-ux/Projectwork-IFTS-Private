# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **DevBridge (tooling di sviluppo)**: API HTTP locale debug-only per audit e
  test. Autoload 13, attivo solo con build debug + flag `--bridge`, bind
  esclusivo 127.0.0.1 (default 8080). Endpoint: `/status`, `/tree`, `/events`
  (ring 200 segnali SignalBus), `/logs/tail`, `/screenshot`, `/command` (7
  azioni UI-equivalenti), `/quit` (percorso WM_CLOSE con salvataggio finale).
  Regola architetturale: solo segnali di input o metodi pubblici gia' usati
  dalla UI — mai segnali di output dei sistemi. 21 test di integrazione.
  Spec: `v1/docs/specs/2026-08-08-dev-bridge-design.md`.

## [1.1.0] - 2026-07-20

Release di consolidamento: riverifica completa delle 127 rilevazioni
dell'audit del 2026-04-23 piu' 70 lacune nuove emerse da una campagna di
analisi su otto dimensioni (test, asset, i18n, scene, funzionalita', CI,
cataloghi, avvio a runtime). Dettaglio con ancoraggi riga per riga in
`MASTER_PLAN_2026-07-20.md`.

### Security

- **Hashing password v4: PBKDF2-HMAC-SHA256 reale** secondo RFC 8018 par. 5.2
  (100.000 iterazioni, salt 16 byte, chiave derivata 32 byte), verificato
  contro tre vettori di `hashlib.pbkdf2_hmac`. Il costrutto precedente era
  SHA-256 iterato con salt concatenato, privo di HMAC e di accumulo XOR, ma
  veniva descritto come PBKDF2 in README e CHANGELOG. Gli hash v1/v2/v3
  restano verificabili e vengono migrati a v4 al primo accesso riuscito.
- **Rate limit anti-brute-force persistito** per username (colonne
  `accounts.failed_attempts` e `lockout_until_unix`): prima viveva solo in
  memoria e bastava riavviare il processo per azzerare i tentativi.
- **Password vuota e conteggi di iterazione fuori scala** falliscono subito:
  entrambi bloccavano il thread principale in modo permanente.
- **I binding SQL non finiscono piu' nei log**: in caso di query fallita
  venivano scritti in chiaro, hash delle password compresi.
- **Immagine profilo validata** (tetto 10 MB e controllo dei magic byte)
  prima del caricamento.
- Landing page: sfondi serviti dal repository invece che da una CDN di terze
  parti fuori controllo, Lucide fissato a versione precisa su tutte le
  pagine, hash SRI su ogni risorsa CDN.
- Azioni GitHub di terze parti e container CI ancorati a SHA/digest; i
  binari dell'addon SQLite hanno un file SHA256SUMS verificato in CI.

### Fixed

- **Il salvataggio non mente piu'**: `save_completed` viene emesso solo dopo
  una scrittura verificata (errore controllato dopo il flush, backup
  obbligatorio, rename con tre tentativi, fallback a copia con confronto
  HMAC). Ogni percorso di errore emette `save_failed` una volta sola e
  l'utente vede un avviso.
- **File di salvataggio manomesso** messo in quarantena con nome univoco e
  segnalato, invece di far ripartire il giocatore dai valori di default in
  silenzio. Una chiave di integrita' corrotta viene trattata come "firma non
  disponibile" e non come primo avvio, cosi' i salvataggi validi non vengono
  piu' accusati di manomissione.
- **Scritture SQLite realmente transazionali**: BEGIN, COMMIT e ROLLBACK
  hanno il valore di ritorno controllato, l'inventario e' protetto da un
  SAVEPOINT e le migrazioni verificano il conteggio delle righe di backup
  prima di qualunque DROP.
- **Sincronizzazione cloud non piu' bloccabile**: gli identificativi di
  richiesta erano incoerenti fra tracciamento e livello HTTP, quindi dopo il
  primo push lo stato "sincronizzazione in corso" non si liberava mai.
  Aggiunti watchdog, ripetizione singola dopo 401 e coda di lettere morte
  per i payload corrotti, che prima venivano cancellati senza traccia.
- **Il cursore del mood cambia davvero la musica**: la funzione di crossfade
  assegnava il mood prima di emettere il segnale, cosi' l'unico ascoltatore
  scartava il proprio evento. Il mood "stormy" non aveva alcuna traccia
  associata.
- **Secondo click sul pulsante HUD** richiude il pannello: la chiusura
  differiva stato e segnale alla fine della dissolvenza.
- **Lingua salvata applicata all'avvio** (prima veniva ignorata fino al
  primo cambio manuale) e cambio a runtime che aggiorna menu, HUD e
  impostazioni senza riavvio.
- Log senza perdite silenziose: file aperto in append, righe scartate
  dichiarate, anello dedicato agli ERROR che sopravvive alle tempeste.
- Limiti della stanza rispettati da personaggio e pet anche in stato WILD.

### Added

- **Suoni ambientali**: due loop sintetizzati (pioggia leggera e camino) con
  crossfade di giunzione, selezione guidata dal mood e interruttore nelle
  impostazioni. Il sottosistema esisteva ma non aveva ne' asset ne' innesco.
- **Sprite originali per i sei tipi di disordine**, prima disegnati come
  cerchi a runtime.
- **Icone dei sei badge**, segnaposto profilo, icona applicazione e icone
  adattive Android: prima l'icona era il robot di Godot.
- **Secondo personaggio selezionabile** (male_rose) e schermata di selezione
  guidata dal catalogo: con un solo personaggio era codice irraggiungibile.
  Aggiungere il terzo e' un'operazione di soli dati.
- **Texture del joystick virtuale** ricreate: la scena mobile puntava a due
  file inesistenti.
- **Contatori a vita per i badge** (decorazioni, monete, tempo di gioco) e
  timer che rivaluta le condizioni a tempo: "Nottambulo" si sbloccava solo
  se per caso arrivava un evento non correlato.
- **Sezione crediti in gioco** con l'attribuzione a Eder Muniz richiesta
  dalla licenza del pack foresta.
- **Vocabolario di segnali di errore** su SignalBus, collegato ai toast:
  prima 48 segnali e uno solo portava un errore.
- **Schema Supabase riproducibile** (`supabase/schema.sql`) con RLS.
- **19 test di regressione** (suite da 111 a 130) su crittografia, percorsi
  di fallimento del salvataggio, parita' delle traduzioni e presenza degli
  asset; i validator dei cataloghi coprono anche badge e disordine.
- `ci/recolor_character.py`: generatore riproducibile del set derivato, con
  modalita' di verifica per accorgersi se i fogli versionati divergono.

### Changed

- L'anello di backup conserva tre generazioni; un salvataggio prodotto da
  una versione futura viene messo da parte invece che applicato.
- Le decorazioni hanno una sola fonte di verita' (righe normalizzate), con
  il blob JSON mantenuto allineato per compatibilita' dei salvataggi.
- Chiusura del database spostata in `_exit_tree`: il salvataggio di uscita
  trovava il database gia' chiuso e falliva a ogni chiusura del gioco.
- I binari GDExtension non sono piu' dichiarati LFS (il repository non ha
  oggetti LFS): risolto il diff fantasma permanente su venti file.

### Known limitations

- La sincronizzazione cloud resta solo in scrittura: il richiamo dei dati
  dal cloud non e' implementato e la documentazione ora lo dice.
- Il sistema di outfit resta fuori ambito.
- L'export Android nel container CI fallisce per un problema noto del
  container; l'esito e' ora riportato esplicitamente nel summary invece di
  essere inghiottito. Windows e HTML5 non sono interessati.

## [1.0.0] - 2026-04-22

### Added
- **Prima release pubblica** di Relax Room
- Build Windows x64 (.exe standalone, `embed_pck=true`, no console wrapper)
- Build Android APK multi-arch (arm64-v8a + armeabi-v7a, Android 7.0+)
- Build HTML5 Web per browser moderni (zipped distribution)
- **Profile HUD** con immagine profilo locale (mai cloud, privacy-first)
- **Mood slider** 0-1 con effetti graduali: overlay gloomy, rain particles,
  pet berserk WILD state, audio crossfade
- **6 badge** sbloccabili via eventi di gioco (decorations_placed,
  mood_changes, stormy_mood, play_time)
- **i18n IT/EN** via .po files + `TranslationServer.set_locale()`
- **MoodManager** autoload (layer=5 overlay, rain.tscn scene, pet WILD FSM
  state, AudioManager.crossfade_to_mood_track)
- **BadgeManager** autoload + SQLite `badges_unlocked` table + catalog
  `badges.json`
- **Virtual joystick** gated `OS.has_feature("mobile")` (attivo solo
  Android/Web, dead-code su desktop)
- **Password hashing v3** 100k iter salted SHA-256 + migration trasparente
  v1/v2→v3 al login (storicamente etichettato "PBKDF2": NON era RFC 8018;
  il vero PBKDF2-HMAC-SHA256 arriva con il formato v4 in v1.1.0)

### Changed
- **Save format v5.0.0** con dual-write atomico JSON + SQLite
- **Supabase client** exponential backoff su HTTP 429 (cap 5 min)
- **Autoload chain** 12 singleton: SignalBus → AppLogger → LocalDatabase →
  AuthManager → GameManager → SaveManager → SupabaseClient → AudioManager
  → PerformanceManager → StressManager → MoodManager → BadgeManager
- **local_database.gd** splittato in 9 moduli (repo pattern, B-033):
  db_helpers + schema + 7 repo (accounts/characters/inventory/rooms_deco/
  settings/sync_queue/badges). API pubblica 1:1 preservata
- **CI validators** 12 job green: lint + format + 8 validator + smoke +
  deep tests + button-focus + version sync + no-keystore guard

### Fixed
- **B-001** Movimento character bloccato (focus chain Godot 4.5/4.6)
- **B-002** Drag & drop decorazioni silent fail (DecoButton TextureRect)
- **B-003** Tab DecoPanel non cliccabili (focus_mode explicit)
- **B-004** Grid quadrati giganti in edit mode (viewport dinamico +
  `size_changed` redraw)
- **B-016** JSON/SQLite divergence (dual-write completo settings/music/
  room/decorations in transaction atomica)
- **B-021** Supabase 429 no-backoff (exponential `min(2^attempts*1000,
  300000)` ms reset su 2xx)
- **B-023** virtual_joystick dead code (mobile-gated)
- **B-024** CI no focus_mode check (new validator + fix 13 existing
  Button.new())
- **B-029** password hash 10k→100k iter salted SHA-256 + v2→v3 migration
  chain (vero RFC 8018 PBKDF2-HMAC-SHA256 dal formato v4, v1.1.0)
- **B-030** RNG non deterministico in debug build
- **B-033** local_database 894-line monolith splittato in 9 moduli

### Security
- Password hash 100k iter salted SHA-256 (storico: NON RFC 8018 PBKDF2;
  dal formato v4 in v1.1.0 le password usano vero PBKDF2-HMAC-SHA256
  100k iter — trade-off OWASP per UX login responsiva)
- Migration trasparente v1/v2→v3 al primo login successful
- Profile image locale only (privacy-first, mai upload Supabase)
- Supabase publishable key: safe in repo pubblico (RLS-protected)
- Keystore release mai in repo: CI validator `validate_no_keystore.py`
  blocca commit accidentali
- Git commit author fixed: `Renan Augusto Macena` (no AI attribution)

### Known limitations (post-1.0.0 backlog)
- Storm ambient track non presente (`AudioManager.crossfade_to_mood_track`
  modula solo volume, no swap track)
- Badge icons: emoji unicode (pixel art PNG 24×24 post-demo)
- i18n refactor incompleto: solo ProfileHUDPanel in .po, resto UI
  hardcoded
- 63 Kenney PNG bathroom/kitchen/tiles non registrati in
  `decorations.json`

[Unreleased]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/tag/v1.0.0
