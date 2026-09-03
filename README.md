# Projectwork — Relax Room

[![ci](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/ci.yml/badge.svg)](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/ci.yml)
[![build](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/build.yml/badge.svg)](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/build.yml)
[![release](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/release.yml/badge.svg)](https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions/workflows/release.yml)

> **Versione**: 1.3.0 (2026-09-03) · IFTS academic project · Demo pubblica: 22 Aprile 2026 (v1.0.0)
> **Landing page**: [mini-cozy-room.netlify.app](https://mini-cozy-room.netlify.app)
> Offline-first desktop companion 2D. Account Supabase opzionale per backup cloud
> (solo in scrittura: i dati salgono, non tornano giu`).

Scritto in **Godot 4.7.1** (GDScript, GL Compatibility). Stanza pixel art personalizzabile,
musica lo-fi, gatto autonomo, pensata per restare in background durante studio/lavoro.

Pubblico: studenti, lavoratori da remoto, chiunque voglia un ambiente digitale calmo
senza notifiche, achievement artificiali o monetizzazione.

## Il gioco in 10 minuti

Il loop del giocatore, nell'ordine in cui lo incontra:

1. **Decora.** Dal pannello *Decora* trascini una delle **129 decorazioni**
   (13 categorie, tutte gratuite dal primo avvio) nella stanza. Le specchi (F),
   le scali (S), i tappeti li ruoti (R). Shift durante il drag disattiva la
   griglia da 64 px.
2. **La stanza si sporca.** Ogni 1-3 minuti compare uno degli **8 tipi di sporco**
   (briciole, caffe`, polvere, carta, piatto, calzino, macchia ostinata,
   bisognino del gatto). Ogni sporco pesa sulla barra della serenita`.
3. **Pulisci con E.** Ti avvicini, premi E e la pulizia parte **a tempo reale**
   (da 7 s a 1 h a seconda del tipo). Non e` un timer da presidiare: si avvia
   e si lascia, finisce anche a gioco chiuso e le monete arrivano al
   completamento.
4. **Monete → Negozio.** Con le monete compri cibo per te (abbassa lo stress),
   croccantini per il gatto (compare la ciotola, il gatto va a mangiare) e
   attrezzi permanenti che accelerano le pulizie (straccio ×1.5, scopa ×2,
   aspirapolvere ×4).
5. **Il gatto cresce di fiducia.** Parte diffidente (35/100): mangia se ha fame,
   sta vicino a te durante i temporali e la fiducia sale. Sotto 20 ti evita,
   da 70 ti segue da vicino, da 90 dorme accanto a te. Esce in giardino per i
   bisogni; in tempesta li fa in casa.

Attorno al loop: il cursore **atmosfera** nel profilo (sotto 0.50 piove e la
stanza si scurisce, sotto 0.25 entra il temporale, sotto 0.10 il gatto va in
WILD), le sedie usabili (E per sedersi; le sedie con le rotelle si guidano),
**6 badge**, il tutorial in 10 step, **10 slot** di partita e i pochi toast che
servono (acquisto, pulizia avviata, pasto del gatto, "Partita salvata" solo col
bottone Salva). Effetti sonori su ogni azione, volume a parte.

Le quattro decisioni architetturali che reggono tutto:

| Decisione | In pratica |
|-----------|------------|
| **SignalBus** | Un solo autoload con **48 segnali** tipizzati. Nessun sistema conosce gli altri: la UI emette, i sistemi ascoltano, i test osservano il bus |
| **Catalog-driven** | **7 cataloghi** JSON in `v1/data/` (decorazioni, personaggi, stanze, tracce, badge, sporco, negozio). Aggiungere contenuto = editare JSON |
| **Offline-first** | JSON + SQLite (**11 tabelle**, WAL) sono la sorgente di verita`. Il cloud e` un client dormiente: un backup progettato, mai una sync |
| **Save HMAC + ring** | Save JSON v5.1.0 firmato HMAC-SHA256 con chiave device-local, scrittura atomica, ring di 3 backup; manomissione rilevata → fallback |

## Avvio rapido

```bash
git clone https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private.git
cd Projectwork-IFTS-Private

# Apri in Godot 4.7.1 Stable (project.godot dichiara 4.7)
#   Import -> v1/project.godot -> Play (F5)
# OPPURE da CLI (binario console 4.7.1, es. Godot_v4.7.1-stable_win64_console.exe):
godot --path v1/
```

Il gioco funziona **offline** con JSON + SQLite locali. Opzionale:
Supabase config in `user://config.cfg` per il **backup cloud push-only**
(default-off). Il percorso di lettura dal cloud esiste come funzione
(`fetch_table`) ma non e` innescato da nulla: accedere su un secondo computer
non scarica la stanza, la riscrive dal locale. Vedi
[supabase/README.md](supabase/README.md).

## Filosofia di design

- **Community, non ranking.** Nessun punteggio, nessun "migliore".
- **Tutto disponibile dal giorno 1.** Le 129 decorazioni sono gratuite e
  disponibili subito: le monete servono solo per cibo, croccantini e attrezzi,
  cioe` per il gatto e per la stanza, mai per sbloccare contenuto.
- **Rilassante, non banale.** Il cursore atmosfera cambia audio, luce e
  comportamento del gatto in tempo reale; lo sporco e il gatto danno un motivo
  per tornare, senza punire chi non torna.
- **A tempo reale, non a timer.** Le pulizie si avviano e si lasciano: finiscono
  anche a gioco chiuso. Niente energia, niente countdown da presidiare.
- **Presente, non invadente.** Niente notifiche di sistema; i toast in gioco
  sono pochi (acquisto, pulizia avviata, esito del pasto, badge) e mai a
  cadenza fissa. Il salvataggio automatico ogni 60 s e` silenzioso; "Partita
  salvata" compare solo col bottone Salva.
- **Achievement umani.** I 6 badge sono ricordi, non ricompense.

## Struttura repository

```
.
├── .github/workflows/     # CI/CD: ci.yml, build.yml, release.yml, pages.yml
├── ci/                    # Python validator (10) + 3 tool asset + requirements.txt pinnato
├── scripts/               # deep_test, preflight, bump_version, build_apk_local (vedi scripts/README.md)
│   └── ci/                # extract_changelog.py, verify_binary.sh
├── tools/                 # gen_sfx.py: sintetizza i 29 effetti sonori (deterministico)
├── assets-library/        # 49 pack CC0/CC-BY/OFL/MIT con licenze + CATALOG.md (fuori da v1/)
├── docs/                  # Landing page statica (Netlify / GitHub Pages)
│   ├── index.html · style.css · main.js
│   └── team/              # Sottopagine per-membro
├── supabase/              # Schema cloud push-only (5 tabelle, schema.sql versionato)
├── v1/                    # Progetto Godot
│   ├── addons/            #   godot-sqlite 4.7 (GDExtension) — unico addon
│   ├── assets/            #   Sprite, audio (musica, ambience, sfx), font, UI, palette
│   ├── data/              #   7 cataloghi JSON (129 deco, char, room, track, badge, mess, shop)
│   ├── docs/specs/        #   Spec di design (DevBridge, espansione gameplay)
│   ├── locale/            #   .po Italiano + Inglese (160 chiavi per lingua)
│   ├── scenes/            #   18 scene Godot (.tscn) + 1 TRES theme
│   ├── scripts/           #   57 script GDScript (~15.5k righe)
│   └── tests/             #   250 test invasivi in 25 moduli + runner headless custom
├── AUDIT_REPORT_2026-04-23.md          # istantanea storica
├── MASTER_PLAN_2026-07-20.md           # istantanea storica
├── AUDIT_REVERIFICATION_2026-08-09.md  # istantanea storica
├── CHANGELOG.md
└── README.md              # Questo file
```

Conteggi misurati sul repository (li ricontrolla `ci/validate_doc_counts.py`): **57 script** GDScript, **48 segnali**, **18 scene**, **7 cataloghi**, **250 test** in **25 moduli**, **11 tabelle** SQLite, **13 autoload**, **129 decorazioni**, **8 tipi di sporco**, **2 personaggi**.

## Documentazione per area

| Documento | Contenuto |
|-----------|-----------|
| [v1/README.md](v1/README.md) | Architettura tecnica, autoload chain, scene tree, contenuti |
| [v1/data/README.md](v1/data/README.md) | Schema JSON + SQLite (11 tabelle), save v5.1.0, 10 slot |
| [v1/addons/README.md](v1/addons/README.md) | godot-sqlite 4.7 (piattaforme reali in `bin/`) |
| [v1/assets/README.md](v1/assets/README.md) | Origini asset, licenze, integrazione |
| [v1/scenes/README.md](v1/scenes/README.md) | Scene, struttura nodi, flusso fra scene |
| [v1/scripts/README.md](v1/scripts/README.md) | GDScript organizzato per dominio, 13 autoload |
| [v1/tests/README.md](v1/tests/README.md) | Test harness deep (250 test, 25 moduli) |
| [scripts/README.md](scripts/README.md) | Tooling: script, validator CI, pre-commit, workflow, export locale |
| [v1/study/README.md](v1/study/README.md) | Mappa documenti ↔ argomenti d'esame, glossario |
| [supabase/README.md](supabase/README.md) | Backup cloud push-only, stato schema |
| [CHANGELOG.md](CHANGELOG.md) | Release notes Keep-a-Changelog + SemVer |
| [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md) | Audit integrita` + stabilita` (13 skill) — storico |
| [AUDIT_REVERIFICATION_2026-08-09.md](AUDIT_REVERIFICATION_2026-08-09.md) | Re-verifica delle rilevazioni — storico |

## Stato dei sistemi (13 autoload singleton)

Chain di inizializzazione in ordine da `v1/project.godot` (**13 autoload**, invariati dalla 1.2):

| # | Autoload | File | Ruolo |
|---|----------|------|-------|
| 1 | **SignalBus** | `autoload/signal_bus.gd` | 48 segnali tipizzati. Tutti i sistemi passano per il bus |
| 2 | **AppLogger** | `autoload/logger.gd` | JSONL rotating 5 MB × 5. Session id, redact su chiavi sensibili (username incluso) |
| 3 | **LocalDatabase** | `autoload/local_database.gd` | SQLite WAL, 11 tabelle, 9 repo modulari; FK fail-closed |
| 4 | **AuthManager** | `autoload/auth_manager.gd` | Guest + user/password PBKDF2-HMAC-SHA256 RFC 8018 (v4, 100 k iter, salt 128 bit); username case-insensitive, password ≤ 128 |
| 5 | **GameManager** | `autoload/game_manager.gd` | Carica 7 cataloghi JSON, orchestra stato, acquisti del negozio |
| 6 | **SaveManager** | `autoload/save_manager.gd` | Save v5.1.0, 10 slot, atomic write + ring 3 backup, HMAC-SHA256, salvataggio "solo settings" dal menu |
| 7 | **SupabaseClient** | `autoload/supabase_client.gd` | Client dormiente: token cifrato device-local, HTTPS, push di 5 tabelle cloud (nessuna lettura, nessun percorso lo attiva) |
| 8 | **AudioManager** | `autoload/audio_manager.gd` | Dual-player crossfade 2 s, mood-driven; figli `AmbienceController` + **`SfxController`** (29 effetti, `play_sfx`) |
| 9 | **PerformanceManager** | `systems/performance_manager.gd` | FPS cap 60 focused / 15 background |
| 10 | **StressManager** | `systems/stress_manager.gd` | Stress 0.0–1.0, 3 livelli con isteresi, decay 2%/min |
| 11 | **MoodManager** | `autoload/mood_manager.gd` | Overlay gloomy + pioggia sotto 0.50, pet WILD sotto 0.10; riapplicato all'ingresso in stanza |
| 12 | **BadgeManager** | `autoload/badge_manager.gd` | Badge catalog, sblocchi per slot nel save + tabella `badges_unlocked` |
| 13 | **DevBridge** | `autoload/dev_bridge.gd` | API HTTP locale debug-only (127.0.0.1, `--bridge`, porta 8080). Audit e test |

## Funzionalita`

- Stanza pixel-art cozy_studio (`room.png` 1280×720 nativa) con 3 temi colore (modern / natural / pink)
- **129 decorazioni** drag-and-drop in 13 categorie, nomi IT/EN dal catalogo
- Interazione: click → popup con R (solo tappeti) / F (flip) / S (scale 0.5×–2×) / X (delete), solo in Modalita` modifica; regole di piazzamento data-driven (muro/pavimento) su drop, drag e load
- Shift durante drag → disabilita snap-to-grid 64 px
- **2 personaggi** pixel-art (`male_old`, `male_rose`) con 8 direzioni + idle/walk/interact/rotate
- Gatto con FSM 12 stati (idle/wander/follow/sleep/play, WILD in tempesta, EAT alla ciotola, AVOID a fiducia bassa, giro in giardino con bisogni) e fiducia 0-100 persistita
- Sporco: **8 tipi di sporco** persistiti nel save; pulizia a tempo reale (7 s → 1 h, attrezzi la accelerano), monete al completamento anche a gioco chiuso
- Cursore atmosfera nel profilo: sotto **0.50** overlay + pioggia (davanti ai mobili); sotto **0.25** temporale; sotto **0.10** gatto WILD. La musica segue solo il cursore, mai lo stress
- **Negozio** (`data/shop.json`): cibo player, croccantini, attrezzi 25/60/100
- **10 slot di partita** con anteprima (nome personaggio, monete, data), Nuova/Carica/Elimina, bottone Salva in gioco; badge per slot
- Sedie usabili: E per sedersi; le sedie da ufficio si guidano e la posizione si salva
- Account locale guest + username/password con lockout anti-brute-force; "Elimina account" cancella davvero tutti gli slot
- Tutorial 10 step signal-driven (movimento, decora, pulisci con E, negozio, profilo), re-giocabile da Opzioni
- Toast (3 visibili max, auto-dismiss 3 s), nomi umani al posto degli id
- HMAC save integrity: manomissione rilevata, fallback ai backup
- 6 badge sbloccabili via eventi di gioco
- i18n IT/EN via `.po` + `TranslationServer.set_locale()` — 160 chiavi per lingua; lingua di sistema adottata al primo avvio
- Effetti sonori sintetizzati (29) con slider "Effetti"; font pixel Pixel Operator 8
- Mobile-ready: joystick virtuale = nodo nativo `VirtualJoystick` di Godot 4.7, gated `OS.has_feature("mobile")`

## Testing

```bash
export GODOT_BIN="$HOME/Downloads/Godot_v4.7.1-stable_win64_console.exe"   # nessun godot in PATH su Windows
./scripts/deep_test.sh --timeout 300   # 250 test invasivi in 25 moduli, ~20-30 s (user:// isolato)
./scripts/preflight.sh                 # GO/NO-GO: gli stessi validator della CI, lint, boot headless, suite
```

Tutto il tooling (script, validator, pre-commit, workflow, export locale desktop
e APK) e` documentato in [scripts/README.md](scripts/README.md).

> La suite gira **solo** tramite `./scripts/deep_test.sh`. Il wrapper redirige
> `user://` su una directory temporanea unica per run, altrimenti i test
> riscriverebbero il profilo reale del giocatore (`save_data.json`,
> `cozy_room.db`, `integrity.key`). Lanciare Godot a mano sul `test_runner.tscn`
> non e` supportato: il runner se ne accorge e aborta. Vedi
> [v1/tests/README.md](v1/tests/README.md#isolamento-dal-profilo-giocatore-g-053).

Dev bridge (solo build debug, mai attivo senza flag):

```bash
"$GODOT_BIN" --path v1/ -- --bridge    # avvia il gioco con l'API su 127.0.0.1:8080
curl http://127.0.0.1:8080/status      # stato: versione, fps, mood, stress, coins
curl -X POST http://127.0.0.1:8080/command -d '{"action":"set_mood","value":0.5}'
```

CI su GitHub Actions in `barichello/godot-ci` **4.7.1** (immagine pinnata per
digest), gated: `smoke-headless` → `deep-tests` → `build-*`. I validator Python
girano in parallelo; `validate-doc-counts` confronta i numeri di questo README e
di `v1/README.md` con quelli misurati sul repository.

## Audit e piani (storico)

Le tre istantanee — [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md)
(13 skill, 5 CRITICAL + 34 HIGH + 44 MEDIUM + 22 LOW),
[MASTER_PLAN_2026-07-20.md](MASTER_PLAN_2026-07-20.md) e
[AUDIT_REVERIFICATION_2026-08-09.md](AUDIT_REVERIFICATION_2026-08-09.md)
(ri-giudizio contro il codice + sessione dinamica via DevBridge) — restano nel
repo come documenti storici. Lo stato corrente e` nel
[CHANGELOG 1.3.0](CHANGELOG.md), inclusa la sezione "Known limitations".

## Contributori

| Nome | Ruolo | Area |
|------|-------|------|
| **Renan Augusto Macena** | System Architect + Project Supervisor | Runtime, UI, gameplay, architettura, audit |
| **Elia Zoccatelli** | Database Engineer | SQLite schema + migrazioni + Supabase cloud |
| **Cristian Marino** | Asset Pipeline + CI/CD | Pixel art, build, GitHub Actions |
| **Alex** (dal 16 Apr 2026) | Pixel Art Artist | Personaggi + animazioni del gatto |

## Licenza

Progetto accademico IFTS 2026 — tutti i diritti riservati.
Copyright © 2026 Renan Augusto Macena. Redistribuzione non autorizzata vietata.

Asset esterni, documentati per pack in `v1/assets/*/README.md`:

| Pack | Autore | Licenza |
|------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Custom (credito richiesto, no redistribuzione) |
| Indoor Plants Pack | SoppyCraft | Custom (no redistribuzione, no AI training) |
| Isometric Room Builder | Thurraya | Custom (no redistribuzione, no AI/NFT) |
| Furniture Kit, Pixel UI Pack, SFX (interface/ui/impact/rpg/jingles), Emotes | Kenney | CC0 1.0 |
| Rain loop + rain & thunder (musica) | Mixkit | Free license |
| Pixel Operator / Pixel Operator 8 (font) | Jayvee Enaguas | CC0 1.0 |
| Pixelify Sans, VT323 (font) | Stefie Justprince, Peter Hull | SIL OFL 1.1 |
| "Chill lofi inspired" (`calm_lofi_loop.ogg`) | omfgdude | CC0 |
| "Rain on Window Loop" (`rain_window_loop.wav`) | alxl | CC0 |
| LPC Cats and Dogs (riferimento) | bluecarrot16 | OGA-BY 3.0 (attribuzione richiesta) |
| Tiny RPG Emoji Pack I | Gabriel "tiopalada" Lima | CC0 |
| Cat sprites (riferimento) | Shepardskin | CC0 |
| Effetti sonori sintetizzati, ambience `fireplace`/`rain_soft`, personaggi, stanza, gatto | Team IFTS | Progetto accademico |
| `v1/assets/sprites/rooms/bongseng/` | bongseng | **Licenza non tracciata**: da chiarire o sostituire |
