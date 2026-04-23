# Projectwork — Relax Room

> **Demo**: 22 Aprile 2026 · IFTS academic project
> **Landing page**: [mini-cozy-room.netlify.app](https://mini-cozy-room.netlify.app)
> Offline-first desktop companion 2D. Account Supabase opzionale per sync cross-device.

Scritto in **Godot 4.6** (GDScript, GL Compatibility). Stanza pixel art personalizzabile,
musica lo-fi, pet autonomo, pensata per restare in background durante studio/lavoro.

Pubblico: studenti, lavoratori da remoto, chiunque voglia un ambiente digitale calmo
senza notifiche, achievement artificiali o monetizzazione.

## Avvio rapido

```bash
git clone https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private.git
cd Projectwork-IFTS-Private

# Apri in Godot 4.6 Stable (NON 4.5 — project.godot dichiara 4.6)
#   Import -> v1/project.godot -> Play (F5)
# OPPURE da CLI:
godot4 --path v1/
```

Il gioco funziona **offline** con JSON + SQLite locali. Opzionale:
Supabase config in `user://config.cfg` per sync cloud (feature pronta, default-off).

## Struttura repository

```
.
├── .github/workflows/     # CI/CD: ci.yml, build.yml, release.yml, pages.yml
├── ci/                    # Python validators (10 script)
├── scripts/               # Shell scripts: smoke, preflight, deep_test, godot-validate
│   └── ci/                # extract_changelog.py
├── docs/                  # Landing page statica (Netlify / GitHub Pages)
│   ├── index.html · style.css · main.js
│   └── team/              # Sottopagine per-membro
├── supabase/              # Schema cloud (push-only, stub)
├── v1/                    # Progetto Godot
│   ├── addons/            #   godot-sqlite 4.7 (GDExtension), virtual_joystick 1.0.0
│   ├── assets/            #   Sprite, audio, backgrounds, UI, palette
│   ├── data/              #   5 cataloghi JSON (129 deco, char, room, track, badge, mess)
│   ├── locale/            #   .po Italian + English
│   ├── scenes/            #   22 scene Godot (.tscn) + 1 TRES theme
│   ├── scripts/           #   49 script GDScript (~8.7k LOC)
│   └── tests/             #   112 test invasivi + runner headless custom
├── AUDIT_REPORT_2026-04-23.md
├── CHANGELOG.md
├── Mini-Cozy-Room-Presentazione-Progetto.pptx
└── README.md              # Questo file
```

## Documentazione per area

| Documento | Contenuto |
|-----------|-----------|
| [v1/README.md](v1/README.md) | Architettura tecnica, autoload chain, scene tree, contenuti |
| [v1/data/README.md](v1/data/README.md) | Schema JSON + SQLite (9 tabelle), migrazioni v1→v5 |
| [v1/addons/README.md](v1/addons/README.md) | godot-sqlite 4.7, virtual_joystick 1.0.0 |
| [v1/assets/README.md](v1/assets/README.md) | Origini asset, licenze, integrazione |
| [v1/scenes/README.md](v1/scenes/README.md) | Scene, struttura nodi, flusso fra scene |
| [v1/scripts/README.md](v1/scripts/README.md) | GDScript organizzato per dominio, 12 autoload |
| [v1/tests/README.md](v1/tests/README.md) | Test harness deep (112 test, 8 moduli) |
| [supabase/README.md](supabase/README.md) | Cloud sync push-only, stato schema |
| [CHANGELOG.md](CHANGELOG.md) | Release notes Keep-a-Changelog + SemVer |
| [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md) | Audit integrità + stabilità (13 skill) |

## Stato dei sistemi (12 autoload singleton)

Chain di inizializzazione in ordine da `v1/project.godot`:

| # | Autoload | File | Ruolo |
|---|----------|------|-------|
| 1 | **SignalBus** | `autoload/signal_bus.gd` | 48 signal typed. Tutti i sistemi passano per il bus |
| 2 | **AppLogger** | `autoload/logger.gd` | JSONL rotating 5 MB × 5. Session id, redact su chiavi sensibili |
| 3 | **LocalDatabase** | `autoload/local_database.gd` | SQLite WAL, 9 tabelle, 9 repo modulari (B-033) |
| 4 | **AuthManager** | `autoload/auth_manager.gd` | Guest + user/password iterated-SHA-256 v3, 100 k iter, salt 128 bit |
| 5 | **GameManager** | `autoload/game_manager.gd` | Carica cataloghi JSON, orchestra stato |
| 6 | **SaveManager** | `autoload/save_manager.gd` | Save v5.0.0, atomic write + backup, HMAC-SHA256 |
| 7 | **SupabaseClient** | `autoload/supabase_client.gd` | Token cifrato device-local, HTTPS, 5 tabelle cloud push |
| 8 | **AudioManager** | `autoload/audio_manager.gd` | Dual-player crossfade 2 s, mood-driven track switch |
| 9 | **PerformanceManager** | `systems/performance_manager.gd` | FPS cap 60 focused / 15 background |
| 10 | **StressManager** | `systems/stress_manager.gd` | Stress 0.0–1.0, 3 livelli con isteresi, decay 2%/min |
| 11 | **MoodManager** | `autoload/mood_manager.gd` | Overlay gloomy, rain particles, pet WILD FSM, audio crossfade |
| 12 | **BadgeManager** | `autoload/badge_manager.gd` | Badge catalog + SQLite table `badges_unlocked` |

## Funzionalità demo-ready

- Stanza pixel-art cozy_studio con 3 temi colore (modern / natural / pink)
- **129 decorazioni** drag-and-drop in 13 categorie
- Interazione: click → popup con R (rotate 90°) / F (flip) / S (scale 0.25×–3×) / X (delete)
- Shift durante drag → disabilita snap-to-grid 64 px per placement fine
- Personaggio pixel-art `male_old` con 8 direzioni + idle/walk/interact/rotate
- Pet gatto void con FSM 5 stati (idle/wander/follow/sleep/play, + WILD con mood stormy)
- Mess system: oggetti sporchi si accumulano, pulisci → +coins, riduce stress
- Mood slider profile HUD: cambia audio track + overlay + pet behavior real-time
- Account locale guest + username+password con lockout anti-brute-force
- Tutorial 9 step signal-driven, re-giocabile da settings
- Toast notifications (3 visibili max, auto-dismiss 3 s)
- Profile HUD mini panel (nome, mood slider, lang toggle IT/EN, settings)
- HMAC save integrity: save tampering rilevato, fallback backup
- 6 badge sbloccabili via eventi di gioco
- i18n IT/EN via `.po` + `TranslationServer.set_locale()`
- Mobile-ready: virtual joystick gated `OS.has_feature("mobile")`

## Testing

```bash
./scripts/smoke_test.sh       # Boot headless ~2 s
./scripts/preflight.sh        # 7 step: toolchain, integrità, JSON, asset, boot, runtime, deep tests. GO/NO-GO exit 0/1
./scripts/godot-validate.sh   # Full re-import + runtime ~3 min
./scripts/deep_test.sh        # 112 test invasivi in 8 moduli ~7 s:
                              #   helpers (16) + catalogs (21) + stress (12) + save (13)
                              #   + spawn (11) + panels (9) + input (14) + ui_events (16)
```

CI su GitHub Actions in `barichello/godot-ci:4.6`, gated: `smoke-headless` → `deep-tests` → `build-*`.

## Audit + integrità

Ultima audit: **2026-04-23** → [AUDIT_REPORT_2026-04-23.md](AUDIT_REPORT_2026-04-23.md).
13 skill applicate: deep-audit, correctness-check, silent-failure-hunter, security-review,
resilience-check, complexity-check, db-review, state-audit, observability-audit,
api-contract-review, dependency-audit, change-impact, data-lifecycle-review.

Trovate 5 CRITICAL + 34 HIGH + 44 MEDIUM + 22 LOW. Top priorità pre-v1.1 listate in
§ 5.2 del report.

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
