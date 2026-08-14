# Projectwork — Relax Room

> **Demo**: 22 Aprile 2026 · IFTS academic project
> **Landing page**: [mini-cozy-room.netlify.app](https://mini-cozy-room.netlify.app)
> Offline-first desktop companion 2D. Account Supabase opzionale per backup cloud
> (solo in scrittura: i dati salgono, non tornano giu`).

Scritto in **Godot 4.7** (GDScript, GL Compatibility). Stanza pixel art personalizzabile,
musica lo-fi, pet autonomo, pensata per restare in background durante studio/lavoro.

Pubblico: studenti, lavoratori da remoto, chiunque voglia un ambiente digitale calmo
senza notifiche, achievement artificiali o monetizzazione.

## Avvio rapido

```bash
git clone https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private.git
cd Projectwork-IFTS-Private

# Apri in Godot 4.7 Stable (project.godot dichiara 4.7)
#   Import -> v1/project.godot -> Play (F5)
# OPPURE da CLI:
godot4 --path v1/
```

Il gioco funziona **offline** con JSON + SQLite locali. Opzionale:
Supabase config in `user://config.cfg` per il **backup cloud push-only**
(default-off). Il percorso di lettura dal cloud esiste come funzione
(`fetch_table`) ma non e` innescato da nulla: accedere su un secondo computer
non scarica la stanza, la riscrive dal locale. Vedi
[supabase/README.md](supabase/README.md).

## Struttura repository

```
.
├── .github/workflows/     # CI/CD: ci.yml, build.yml, release.yml, pages.yml
├── ci/                    # Python validators (9 validator + 3 tool asset)
├── scripts/               # Shell scripts: smoke, preflight, deep_test, godot-validate
│   └── ci/                # extract_changelog.py
├── docs/                  # Landing page statica (Netlify / GitHub Pages)
│   ├── index.html · style.css · main.js
│   └── team/              # Sottopagine per-membro
├── supabase/              # Schema cloud push-only (5 tabelle, schema.sql versionato)
├── v1/                    # Progetto Godot
│   ├── addons/            #   godot-sqlite 4.7 (GDExtension), virtual_joystick 1.0.0
│   ├── assets/            #   Sprite, audio, backgrounds, UI, palette
│   ├── data/              #   7 cataloghi JSON (129 deco, char, room, track, badge, mess, shop)
│   ├── locale/            #   .po Italian + English (137 chiavi per lingua)
│   ├── scenes/            #   18 scene Godot (.tscn) + 1 TRES theme
│   ├── scripts/           #   55 script GDScript (~14.4k LOC)
│   └── tests/             #   234 test invasivi + runner headless custom
├── AUDIT_REPORT_2026-04-23.md
├── CHANGELOG.md
├── Mini-Cozy-Room-Presentazione-Progetto.pptx
└── README.md              # Questo file
```

## Documentazione per area

| Documento | Contenuto |
|-----------|-----------|
| [v1/README.md](v1/README.md) | Architettura tecnica, autoload chain, scene tree, contenuti |
| [v1/data/README.md](v1/data/README.md) | Schema JSON + SQLite (11 tabelle), migrazioni v1→v5 |
| [v1/addons/README.md](v1/addons/README.md) | godot-sqlite 4.7, virtual_joystick 1.0.0 |
| [v1/assets/README.md](v1/assets/README.md) | Origini asset, licenze, integrazione |
| [v1/scenes/README.md](v1/scenes/README.md) | Scene, struttura nodi, flusso fra scene |
| [v1/scripts/README.md](v1/scripts/README.md) | GDScript organizzato per dominio, 13 autoload |
| [v1/tests/README.md](v1/tests/README.md) | Test harness deep (234 test, 23 moduli) |
| [supabase/README.md](supabase/README.md) | Backup cloud push-only, stato schema |
| [CHANGELOG.md](CHANGELOG.md) | Release notes Keep-a-Changelog + SemVer |
| [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md) | Audit integrità + stabilità (13 skill) |
| [AUDIT_REVERIFICATION_2026-08-09.md](AUDIT_REVERIFICATION_2026-08-09.md) | Re-verifica delle rilevazioni contro il codice attuale |

## Stato dei sistemi (13 autoload singleton)

Chain di inizializzazione in ordine da `v1/project.godot`:

| # | Autoload | File | Ruolo |
|---|----------|------|-------|
| 1 | **SignalBus** | `autoload/signal_bus.gd` | 65 signal typed. Tutti i sistemi passano per il bus |
| 2 | **AppLogger** | `autoload/logger.gd` | JSONL rotating 5 MB × 5. Session id, redact su chiavi sensibili |
| 3 | **LocalDatabase** | `autoload/local_database.gd` | SQLite WAL, 11 tabelle, 9 repo modulari (B-033) |
| 4 | **AuthManager** | `autoload/auth_manager.gd` | Guest + user/password PBKDF2-HMAC-SHA256 RFC 8018 (v4, 100 k iter, salt 128 bit; build storiche: SHA-256 iterato con salt, re-hash a v4 al login) |
| 5 | **GameManager** | `autoload/game_manager.gd` | Carica 7 cataloghi JSON, orchestra stato |
| 6 | **SaveManager** | `autoload/save_manager.gd` | Save v5.1.0, atomic write + backup, HMAC-SHA256 |
| 7 | **SupabaseClient** | `autoload/supabase_client.gd` | Token cifrato device-local, HTTPS, push di 5 tabelle cloud (nessuna lettura) |
| 8 | **AudioManager** | `autoload/audio_manager.gd` | Dual-player crossfade 2 s, mood-driven track switch |
| 9 | **PerformanceManager** | `systems/performance_manager.gd` | FPS cap 60 focused / 15 background |
| 10 | **StressManager** | `systems/stress_manager.gd` | Stress 0.0–1.0, 3 livelli con isteresi, decay 2%/min |
| 11 | **MoodManager** | `autoload/mood_manager.gd` | Overlay gloomy + pioggia sotto 0.50, pet WILD sotto 0.10, audio crossfade |
| 12 | **BadgeManager** | `autoload/badge_manager.gd` | Badge catalog + SQLite table `badges_unlocked` |
| 13 | **DevBridge** | `autoload/dev_bridge.gd` | API HTTP locale debug-only (127.0.0.1, `--bridge`, porta 8080). Audit e test |

## Funzionalità demo-ready

- Stanza pixel-art cozy_studio con 3 temi colore (modern / natural / pink)
- **129 decorazioni** drag-and-drop in 13 categorie
- Interazione: click → popup con R (solo tappeti) / F (flip) / S (scale 0.5×–2× della misura d'autore) / X (delete); regole di piazzamento data-driven (muro/pavimento) su drop, drag e load
- Shift durante drag → disabilita snap-to-grid 64 px per placement fine
- Personaggio pixel-art `male_old` con 8 direzioni + idle/walk/interact/rotate
- Pet gatto void con FSM 12 stati (idle/wander/follow/sleep/play, WILD in tempesta, EAT alla ciotola, AVOID a confidenza bassa, giro in giardino con bisogni)
- Mess system: 8 tipi di sporco persistiti nel save; pulizia A TEMPO (7 s → 1 h, attrezzi del negozio la accelerano), coins al completamento — anche a gioco chiuso
- Mood slider profile HUD: cambia audio track + overlay + pet behavior real-time.
  Sotto **0.50** la stanza si scurisce **e** inizia a piovere (visivo e ambience
  sulla stessa soglia); sotto **0.25** entra la musica da temporale; sotto
  **0.10** il gatto passa in WILD
- Account locale guest + username+password con lockout anti-brute-force
- Tutorial 8 step signal-driven, re-giocabile da settings
- Toast notifications (3 visibili max, auto-dismiss 3 s)
- Profile HUD mini panel (nome, immagine profilo, badge, mood slider, lang toggle IT/EN, settings)
- HMAC save integrity: save tampering rilevato, fallback backup
- 6 badge sbloccabili via eventi di gioco
- i18n IT/EN via `.po` + `TranslationServer.set_locale()` — 137 chiavi per lingua,
  incluse conferme distruttive, errori di autenticazione, etichette del mood,
  toast e tooltip delle maniglie di modifica
- **Negozio** (v1.2): cibo per il player (riduce lo stress), croccantini per il
  gatto (ciotola + pasto animato), attrezzi permanenti che accelerano le pulizie
  (straccio ×1.5, scopa ×2, aspirapolvere ×4) — catalogo `data/shop.json`
- **Confidenza del gatto** (v1.2): 0→100 persistita; cresce coi pasti (se ha fame)
  e standogli vicino in tempesta; da "ti evita" a "dorme accanto a te"
- **Giardino + bisogni** (v1.2): il gatto esce nel piazzale 4 volte al giorno;
  in tempesta la fa in casa (sporco pesante); accumulo offline via `last_saved`
- **10 slot di partita** (v1.2): schermata slot con anteprima, Nuova/Carica/Elimina,
  bottone Salva in gioco; slot 1 = profili storici, zero migrazione
- **Sedie usabili** (v1.2): E per sedersi; le 5 sedie da ufficio (rotelle) si
  guidano per la stanza e la posizione si salva allo smontaggio
- Mobile-ready: virtual joystick gated `OS.has_feature("mobile")`

## Testing

```bash
./scripts/smoke_test.sh       # Boot headless ~2 s
./scripts/preflight.sh        # 8 step: toolchain, integrità, JSON, asset, boot, runtime,
                              #   deep tests, artefatti di presentazione. GO/NO-GO exit 0/1
./scripts/godot-validate.sh   # Full re-import + runtime ~3 min
./scripts/deep_test.sh        # 234 test invasivi in 23 moduli ~30 s (user:// isolato):
                              #   i 15 moduli storici + placement (6) + movement_bounds (4)
                              #   + shop (5) + cleaning (5) + trust (5) + needs (5)
                              #   + slots (4) + seats (3)
```

> La suite gira **solo** tramite `./scripts/deep_test.sh`. Il wrapper redirige
> `user://` su una directory temporanea unica per run, altrimenti i test
> riscriverebbero il profilo reale del giocatore (`save_data.json`,
> `cozy_room.db`, `integrity.key`). Lanciare Godot a mano sul `test_runner.tscn`
> non e` supportato: il runner se ne accorge e aborta. Vedi
> [v1/tests/README.md](v1/tests/README.md#isolamento-dal-profilo-giocatore-g-053).

Dev bridge (solo build debug, mai attivo senza flag):

```bash
godot4 --path v1/ -- --bridge          # avvia il gioco con l'API su 127.0.0.1:8080
curl http://127.0.0.1:8080/status      # stato: versione, fps, mood, stress, coins
curl -X POST http://127.0.0.1:8080/command -d '{"action":"set_mood","value":0.5}'
```

CI su GitHub Actions in `barichello/godot-ci:4.6`, gated: `smoke-headless` → `deep-tests` → `build-*`.

## Audit + integrità

Ultima audit: **2026-04-23** → [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md).
13 skill applicate: deep-audit, correctness-check, silent-failure-hunter, security-review,
resilience-check, complexity-check, db-review, state-audit, observability-audit,
api-contract-review, dependency-audit, change-impact, data-lifecycle-review.

Trovate 5 CRITICAL + 34 HIGH + 44 MEDIUM + 22 LOW. Top priorità pre-v1.1 listate in
§ 5.2 del report.

Re-verifica del **2026-08-09** →
[AUDIT_REVERIFICATION_2026-08-09.md](AUDIT_REVERIFICATION_2026-08-09.md): ogni
rilevazione ri-giudicata contro il codice attuale invece che contro lo stato
registrato, piu` una sessione dinamica via DevBridge e i riscontri di un
giocatore reale.

## Contributori

| Nome | Ruolo | Area |
|------|-------|------|
| **Renan Augusto Macena** | System Architect + Project Supervisor | Runtime, UI, gameplay, architettura, audit |
| **Elia Zoccatelli** | Database Engineer | SQLite schema + migrazioni + Supabase cloud |
| **Cristian Marino** | Asset Pipeline + CI/CD | Pixel art, build, GitHub Actions |
| **Alex** (joined 16 Apr 2026) | Pixel Art Artist | Personaggi + cat animations |

## Licenza

Progetto accademico IFTS 2026 — tutti i diritti riservati.
Copyright © 2026 Renan Augusto Macena. Redistribuzione non autorizzata vietata.
Asset esterni (Kenney CC0, SoppyCraft, Thurraya, Eder Muniz, Mixkit, Kenney UI Pack)
rispettano le licenze originali, documentate in `v1/assets/*/README.md`.
