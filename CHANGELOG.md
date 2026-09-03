# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-09-03

Sessione "studio profondo + migliorare l'esistente": 13 agenti di audit in
sola lettura (codice, documenti, asset, compatibilita` Godot 4.7, playtest
per lettura, giochi comparabili, idiomi Godot, raccolta asset), poi
correzioni guidate dai principi del corso Q3 — 23 programmazione difensiva,
20 resilienza, 14 macchine a stati, 13 eventi/messaggi, 11 data-driven,
02 separazione modulare, 08 filesystem/asset, 22 build system, 05
configurazione. Suite: **250 test in 25 moduli** (moduli nuovi `test_polish` e `test_review`).

### Fixed

- **Godot 4.7**: l'addon `virtual_joystick` dichiarava un `class_name` in
  conflitto col nuovo nodo nativo `VirtualJoystick` e il joystick mobile era
  rotto in silenzio — sostituito dal nodo nativo. Deadzone `ui_*` 0.2 in
  `project.godot`; sezioni `[dotnet]`/`[animation]` residue e azione
  `toggle_music` morta rimosse (`stretch/aspect` resta al default `keep`: l'editor lo toglie dal file).
- **Perdita dati**: "Menu" ed "Esci" ora salvano davvero (prima solo dirty
  flag o quit diretto: fino a 60 s persi); lingua e volumi cambiati dal menu
  principale vengono persistiti con un salvataggio "solo settings" sul file
  esistente; i volumi salvati valgono anche nel menu; la lingua di sistema al
  primo avvio viene adottata (prima al secondo avvio il gioco passava in
  inglese); "Elimina personaggio" in gioco ricostruisce la stanza; "Elimina
  account" cancella davvero tutti gli slot e la riga account (hard delete con
  CASCADE); nessuna scrittura DB in stato LOGGED_OUT.
- **Gatto**: i poligoni giardino erano disgiunti dal pavimento e il gatto
  restava bloccato per sempre sul bordo — ora si sovrappongono e ogni
  attraversamento ha un timeout di 20 s; primo bisogno a 3-6 min (era 6 h);
  cap dei bisogni offline 3 (era 8: serenita` a zero al rientro); fiducia
  iniziale 35 (era 0: scappava per il primo quarto d'ora); PLAY non porta
  piu` a FOLLOW un gatto diffidente; clamp al pavimento unico per tutti gli
  stati; orologio tornato indietro gestito per bisogni e pasti;
  `_potty_indoor` resettato a fine tempesta; ciotola irraggiungibile con
  timeout.
- **Mood**: pioggia, overlay e WILD riapplicati all'ingresso in stanza (la
  pioggia moriva col menu); pioggia disegnata davanti ai mobili; la musica
  segue SOLO il cursore atmosfera (prima lo stress alzava il temporale in
  una stanza soleggiata).
- **Interazione**: rimosso il percorso legacy `interaction_type` (0 voci,
  prompt che E non poteva soddisfare); prompt "Premi E per sederti/pulire"
  su sedie e sporco; E su una pulizia gia` avviata non mima piu` l'azione;
  il prompt non resta acceso dopo il reload.
- **UI**: il focus non viene piu` rubato aprendo Negozio/Opzioni (Invio e
  Spazio compravano, A/D cambiavano il volume); il movimento e` bloccato da
  "pannello aperto" e non da chi ha il focus; popup R/F/S/X solo in Modalita`
  modifica, clampato allo schermo, scala a gradini corretta e profondita`
  ricalcolata; sedia dietro al personaggio da subito; tutorial: step 5
  riscritto (R/F/S/X sono bottoni, S muoveva il personaggio), il dialogo
  non copre piu` il pavimento (drop dello step 4 perso), avviso al timeout;
  toast spostati (coprivano i pannelli), nomi umani al posto degli id,
  "Partita salvata" solo col bottone Salva (prima ogni 60 s); validator del
  focus esteso a slider e OptionButton.
- **Dati**: badge per slot (una partita nuova nasceva con i badge della
  vecchia); tabella `inventario` mai popolata (chiavi `id`/`qty`); 4 indici
  duplicati rimossi; `save_metadata` finalmente scritta (slot, versione);
  FK fail-closed; username fuori dai log; password con tetto 128; username
  case-insensitive (bypass del lockout); `supabase_session.cfg` non piu`
  scritto senza configurazione.
- **Build**: CI su `barichello/godot-ci` 4.7.1; `scripts/**` nei path
  filter; `requirements.txt` pinnato; `lfs: true` rimosso (nessun oggetto
  LFS); export con `exclude_filter` (test, preview, PSD, originali: -7,5 MB
  per build); 283 MB di librerie iOS inutilizzate rimosse; SHA256SUMS
  completo (macOS incluso); linux arm64 (binari inesistenti) tolto dal
  `.gdextension`; export Web con `extensions_support` (variante nothreads).
- **Igiene**: `.uid` orfani, `docs/css` e `docs/js` stale,
  `register_kenney_assets.py`, spec spostata fuori dalla cartella pubblica
  del sito, `~*.dll` e `.vscode/` ignorati, riga APK fantasma nelle note di
  release, CHANGELOG `[Unreleased-pre-1.2]` confluito in 1.2.0.

### Added

- **Effetti sonori**: 29 suoni sintetizzati (`tools/gen_sfx.py`,
  riproducibile byte per byte) + `SfxController` figlio di AudioManager
  (click su ogni bottone, piazzamento, pulizia, monete, acquisto, badge,
  gatto, tuono); slider "Effetti" nelle impostazioni (`sfx_volume`, che
  prima era persistito ma non pilotava nulla).
- Font pixel **Pixel Operator 8** (CC0) come font del tema.
- Musica calma non-pioggia (`calm_lofi_loop.ogg`, "Chill lofi inspired" di
  omfgdude, CC0) e ambience pioggia sul vetro (alxl, CC0): file presenti,
  cablaggio in `tracks.json` ancora da fare (vedi limiti).
- **Catalogo decorazioni bilingue** (`name_it`/`name_en` su 129 voci e 13
  categorie); pannello Decora con griglie pigre, ordinamento per stile,
  memoria dell'ultima categoria, hint Shift=griglia, anteprima drag 1:1.
- Toast di acquisto, "pulizia avviata: pronta tra X", esito del pasto del
  gatto, cambio di fiducia; tempo residuo sopra la barra di pulizia;
  sottotitoli del negozio ("Pulisci ×2 piu` in fretta", velocita` attuale);
  "Compra" grigio senza monete; "Mangia" disabilitato a stress zero; nome
  del personaggio negli slot; ESC e conferma a tempo nella schermata slot;
  "Accedi / Registrati" nel profilo per l'ospite.
- `room.png` a risoluzione nativa 1280×720 (era uno screenshot 2528×1696
  con i bottoni della vecchia UI dipinti dentro, scalato a runtime); layer
  luce della foresta nel menu; `FloorRect` che copre davvero il pavimento.
- Libreria asset `assets-library/` (49 pack CC0/CC-BY/OFL/MIT con licenze e
  `CATALOG.md`, fuori da `v1/`); `v1/assets/ui/fonts`,
  `v1/assets/sprites/emotes`, `v1/assets/sprites/cats_ref`,
  `v1/assets/audio/sfx/kenney`.
- Economia (solo dati): `clean_reward = durata/15 + 2` (rendimento non piu`
  decrescente); attrezzi a 25/60/100 monete.
- Test: modulo `test_polish` (8 regressioni). Versione 1.3.0.

### Changed

- 16 segnali di SignalBus senza controparte rimossi (da 65 a **48
  segnali**); `validate_signal_count --min 45`.
- Ambience: `ambience_toggled` rimosso (mai emesso).

### Known limitations

- Supabase resta un client dormiente: nessun percorso lo attiva. E` un
  backup progettato, non una sincronizzazione.
- `tracks.json` non usa ancora la traccia calma nuova: la musica "calm" e`
  ancora una registrazione di pioggia (AG-1).
- Arte mancante per feature esistenti: personaggio seduto, gatto che mangia
  o accucciato, ciotola (placeholder da codice), icone del negozio (quadrati
  colorati). Il pack `v1/assets/sprites/rooms/bongseng/` non ha una licenza
  tracciabile: da chiarire o sostituire.
- Export Web non collaudato a mano; Android sperimentale e non firmato.

## [1.2.0] - 2026-08-14

Sessione "fondamenta + gameplay": stabilizzazione guidata dai principi del
corso Q3 (data-driven, FSM, valida-ai-confini, accumulatore temporale) e
cinque fasi di gameplay nuove. Suite: **234 test in 23 moduli**, tutti verdi.

### Fixed

- **Geometria della stanza**: il poligono di collisione era 67–128 px piu`
  grande del pavimento visibile e i personaggi usavano capsule a corpo
  intero — ora il poligono e` misurato dall'arte e i collider sono ancorati
  ai piedi. Il personaggio raggiunge la parete di fondo e non esce piu` dai
  bordi bassi (test runtime con input simulato).
- **Regole di piazzamento** applicate su TUTTI i confini (drop, drag, heal
  al load): le finestre non finiscono piu` sul pavimento ne` le piante sui
  muri; fascia muro derivata dal poligono; `placement_type "any"` ritirato;
  rotazione opt-in (solo tappeti) e scala limitata ×0.5–×2.
- **Profondita`**: z_index a bande (muri < tappeti < tutto cio` che sta in
  piedi ordinato per i piedi) su personaggio, gatto, arredi, sporco.
- **Save**: i campi int (coins, stress, traccia musicale) non vengono piu`
  azzerati a ogni load (coercizione float→int mancante in 3 blocchi).
- Ledger stress per-tipo con conteggio: due sporchi uguali pesano due volte.
- Gli oggetti a muro e i tappeti non hanno piu` collisioni invisibili.

### Added

- **Economia** — pulizia a tempo "avvia e lascia" (7 s → 1 h da catalogo,
  barra di progresso, coins al completamento anche a gioco chiuso, sporco
  persistito nel save v5.1.0) + **Negozio** (`data/shop.json`): cibo player
  anti-stress, croccantini con ciotola e stato EAT del gatto, attrezzi
  permanenti ×1.5/×2/×4. Tasto E + prompt HUD (prima non esisteva alcun
  gestore di interazione). 2 tipi di sporco nuovi (macchia ostinata 1 h,
  bisognino del gatto 30 min).
- **Confidenza del gatto** 0–100 persistita: +8 a pasto (se ha fame, ≥4 h),
  +1/10 s vicino al player in tempesta; sotto 20 il gatto scappa (AVOID),
  da 70 follow stretto e conforto nel WILD, da 90 dorme accanto al player.
- **Giardino + bisogni**: zone giardino data-only, uscita 4 volte/giorno
  (6 h ±1 h su orologio reale), in tempesta i bisogni avvengono in stanza,
  accumulo offline con cap (torni e trovi i "disastri").
- **10 slot di partita** con schermata di selezione (anteprima nome/coins/
  data, elimina con conferma), bottone **Salva** in gioco; slot 1 =
  percorsi storici (zero migrazione), pipeline HMAC/backup invariata.
- **Sedie usabili**: E per sedersi/alzarsi; le sedie da ufficio si guidano
  per la stanza (posizione persistita). Polish animazioni procedurale.
- **APK Android** funzionante in locale: ETC2/ASTC abilitato, export
  arm64-only (godot-sqlite non ha librerie arm32), firma debug verificata.
- 28 chiavi i18n nuove (137 per lingua), validatore CI esteso (shop.json,
  campi pulizia, flag sedie), 38 test nuovi.

### Changed

- Progetto su **Godot 4.7** (l'immagine CI resta 4.6: mismatch noto, da
  riallineare al primo run).

### Lavoro dell'8-9 agosto 2026 confluito nella 1.2.0 (DevBridge, i18n, isolamento dei test)

#### Added

- **DevBridge (tooling di sviluppo)**: API HTTP locale debug-only per audit e
  test. Autoload 13, attivo solo con build debug + flag `--bridge`, bind
  esclusivo 127.0.0.1 (default 8080). Endpoint: `/status`, `/tree`, `/events`
  (ring 200 segnali SignalBus), `/logs/tail`, `/screenshot`, `/command` (7
  azioni UI-equivalenti), `/quit` (percorso WM_CLOSE con salvataggio finale).
  Regola architetturale: solo segnali di input o metodi pubblici gia' usati
  dalla UI — mai segnali di output dei sistemi. 21 test di integrazione.
  Spec: `v1/docs/specs/2026-08-08-dev-bridge-design.md`.
- **32 chiavi di traduzione nuove** (IT ed EN, 109 per lingua in totale).
  Parlano finalmente la lingua dell'interfaccia: i dialoghi di conferma che
  cancellano personaggio e account, gli errori di autenticazione (sia le
  validazioni del modulo sia quelli che arrivano da `AuthManager`), le
  etichette del mood, i toast di salvataggio e piazzamento, i tooltip delle
  maniglie di modifica delle decorazioni e le righe del pannello profilo.
  Prima erano stringhe fisse in inglese, o peggio identificativi interni
  mostrati all'utente.
- **Suite di test: 3 moduli nuovi** — `test_logger` (4), `test_mood` (16) e
  l'ampliamento di `test_i18n_assets` (16) e `test_save_failures` (10).
  Totale **196 test su 15 moduli**, da 168 su 14.

#### Fixed

- **La pioggia segue il cursore dell'umore invece di contraddirlo.** Le gocce
  comparivano solo sotto 0.15 mentre la stanza cominciava a scurirsi gia' a
  0.50: in mezzo c'era una fascia larga meta' cursore in cui il giocatore
  vedeva buio senza pioggia, e sentiva pioggia con il sole. Ora visivo e
  ambience condividono la soglia 0.50 — dove si vede piovere si sente
  piovere — la musica da temporale entra sotto 0.25 e il gatto passa in WILD
  sotto 0.10 (PLR-1).
- **Chiudere il gioco dal menu non richiede piu' due tentativi.** Il
  salvataggio finale al menu viene saltato di proposito (non c'e' stato da
  scrivere), ma veniva contato come fallimento: il gioco ritentava e restava
  aperto chiedendo di chiudere di nuovo. "Niente da salvare" ora e' un esito
  di successo (DYN-1).
- **Il logger chiude il proprio file a fine sessione** invece di lasciarlo
  aperto, e la riga stampata a console viene redatta esattamente come quella
  scritta su file: erano due percorsi separati e la console partiva dal
  contesto grezzo, quindi ogni segreto ripulito nel `.jsonl` usciva comunque
  su stdout. La redazione ora scende anche dentro gli Array (V-022, DYN-2).
- **Un catalogo che non si carica arriva all'utente.** Il fallimento viene
  emesso durante l'autoload, quando nessun toast esiste ancora: ora resta in
  coda e la prima UI che si presenta lo ritira (V-019).
- **Bit eseguibile ripristinato** su `preflight.sh`, `build_apk_local.sh`,
  `deep_test.sh`, `godot-validate.sh` e `smoke_test.sh`: erano committati
  senza, quindi il comando `./scripts/preflight.sh` scritto in ogni guida
  usciva 126 (G-026).

#### Changed

- **La suite di test gira in una directory utente usa-e-getta.** Scriveva
  `save_data.json`, `cozy_room.db` e `integrity.key` dentro `user://`, che con
  `use_custom_user_dir` e' la **stessa** cartella del giocatore: ogni run
  distruggeva il profilo reale. `deep_test.sh` crea ora una sandbox per run e
  ci pianta un sentinella che `test_runner.gd` pretende di trovare prima di
  eseguire un solo test. Lanciare Godot a mano sul `test_runner.tscn` **non e'
  piu' supportato**: senza sentinella il runner aborta. Il job CI verifica ad
  ogni build che la user dir vera non esista nemmeno a fine suite (G-053).
- **Android de-classificato a esperimento non supportato.** L'iniezione del
  keystore di release in `build.yml` era un no-op — cercava chiavi
  `keystore/release*` che in `export_presets.cfg` non esistono — e
  `release.yml` gate-ava la pubblicazione su un job che riporta successo anche
  producendo zero APK. Una release poteva quindi presentarsi come completa di
  un APK firmato inesistente. Rimossa l'iniezione, rimosso il gate, tolto
  `*.apk` dagli asset di rilascio; il job resta ma si chiama "sperimentale,
  non firmato" ed esporta solo in debug (G-003).
- **Il cloud e' un backup, non una sincronizzazione.** La documentazione
  prometteva "sync cross-device": il richiamo dei dati dal cloud non e' mai
  stato innescato e i mapper cloud→locale sono stati rimossi tempo fa.
  Riformulato ovunque come "backup cloud in sola scrittura", codice invariato
  (G-007 / V-091).
- **Documentazione riallineata al codice misurando i numeri**: 51 script
  GDScript (~12.325 righe), 56 segnali, 17 scene, 6 cataloghi JSON, 11 tabelle
  SQLite, 13 job CI, tutorial di 8 step. I README degli asset elencavano file
  che sul disco non esistono — la cartella `bed/`, `floor_mess1-3.png`,
  `door.png` e l'intero set `female/` — e omettevano `male_rose`, in catalogo
  da tempo (G-017, G-048, G-063).

#### Security

- **Un uid autenticato senza riga nel database non conia piu' un account
  ospite.** Il fallback creava la riga con la mail segnaposto `offline@local`
  per qualunque uid, non solo per quello ospite: un lookup a vuoto riscriveva
  cosi' l'identita' di un utente registrato. Ora logga un errore, aborta il
  salvataggio ed emette `db_error` (V-021).

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

[Unreleased]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/tag/v1.0.0
