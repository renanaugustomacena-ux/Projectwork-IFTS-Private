# Projectwork — Relax Room

> **Demo**: 22 Aprile 2026 · IFTS academic project
> **Landing page**: [mini-cozy-room.netlify.app](https://mini-cozy-room.netlify.app)
> Offline-first desktop companion. Account Supabase opzionale per sync cross-device.

Desktop companion 2D scritto in **Godot 4.6** (GDScript, GL Compatibility).
Stanza pixel art personalizzabile, musica lo-fi, pet autonomo, pensata per
restare in background durante studio/lavoro senza distrarre.

Pubblico: studenti, lavoratori da remoto, chiunque voglia un ambiente
digitale calmo senza notifiche, achievement artificiali, o monetizzazione.

## Avvio rapido

```bash
git clone https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private.git
cd Projectwork-IFTS-Private

# Apri il progetto in Godot 4.6 Stable (NON 4.5 — project.godot dichiara 4.6)
#   Import -> v1/project.godot -> Play (F5)
# OPPURE da CLI:
godot4 --path v1/
```

Il gioco funziona completamente **offline** con JSON + SQLite locali.
Opzionale: Supabase config in `user://config.cfg` per sync cloud
(feature pronta ma default-off).

## Struttura repository

```
.
├── .github/workflows/     # CI/CD (7 job: lint, validazioni, smoke, deep tests, build)
│   ├── ci.yml             # gdlint + gdformat + 5 validatori + headless smoke + 112 deep test
│   └── build.yml          # Export Windows (.exe) + HTML5 su godot-ci:4.6
├── ci/                    # Script Python usati dai job CI
├── scripts/               # Script shell (smoke, preflight, godot-validate, deep_test)
├── docs/                  # Landing page (Netlify)
├── v1/                    # Progetto Godot
│   ├── addons/             #   godot-sqlite GDExtension v4.7, virtual_joystick
│   ├── assets/             #   Sprite, audio, backgrounds, UI, palette
│   ├── data/               #   5 cataloghi JSON (129 deco, 1 char, 1 room, 2 track, 6 mess)
│   ├── docs/               #   Presentazione, speech, report tecnici
│   ├── guide/              #   Guide operative per ogni membro team
│   ├── scenes/             #   17 scene Godot (.tscn)
│   ├── scripts/            #   37 script GDScript organizzati per dominio
│   ├── study/              #   10 doc di studio (Godot, isometric, DB, rendering)
│   └── tests/              #   112 test invasivi + runner headless
├── Mini-Cozy-Room-Presentazione-Progetto.pptx
└── README.md               # Questo file
```

## Documentazione per area

| Documento | Contenuto |
|-----------|-----------|
| [v1/README.md](v1/README.md) | Architettura tecnica, autoload, scene tree, contenuti |
| [v1/data/README.md](v1/data/README.md) | Schema JSON + SQLite (9 tabelle), migrazioni v1→v5 |
| [v1/addons/README.md](v1/addons/README.md) | godot-sqlite v4.7, virtual_joystick |
| [v1/assets/README.md](v1/assets/README.md) | Origini asset, licenze, integrazione |
| [v1/scenes/README.md](v1/scenes/README.md) | Scene, struttura nodi, flusso fra scene |
| [v1/scripts/README.md](v1/scripts/README.md) | Script GDScript, autoload, segnali |
| [v1/tests/README.md](v1/tests/README.md) | Test harness deep (112 test, 8 moduli) |
| [v1/guide/README.md](v1/guide/README.md) | Guide operative per team (Renan, Elia, Cristian, Alex) |
| [v1/study/README.md](v1/study/README.md) | Doc di studio (Godot, cozy games, DB, rendering) |
| [v1/docs/CONSOLIDATED_PROJECT_REPORT.md](v1/docs/CONSOLIDATED_PROJECT_REPORT.md) | Audit tecnico completo |
| [v1/docs/DEEP_READ_REGISTRY_2026-04-16.md](v1/docs/DEEP_READ_REGISTRY_2026-04-16.md) | Source-of-truth numerico post-audit |

## Stato dei sistemi

| Sistema | File | Stato | Dettagli |
|---------|------|-------|----------|
| **SignalBus** | `autoload/signal_bus.gd` | Pronto | 46 segnali typed. Nessun sistema conosce gli altri: tutto passa per il bus |
| **AppLogger** | `autoload/logger.gd` | Pronto | JSON Lines rotating 5MB×5, session ID crypto-sicuro, redazione credenziali automatica |
| **LocalDatabase** | `autoload/local_database.gd` | Pronto | SQLite WAL 9 tabelle (accounts, characters, rooms, inventario, sync_queue, settings, save_metadata, music_state, placed_decorations), migrazioni con backup pre-DROP |
| **AuthManager** | `autoload/auth_manager.gd` | Pronto | Guest + username+password PBKDF2 v2 (salt per-account, 10k iter), rate limit 5 tentativi/5min |
| **GameManager** | `autoload/game_manager.gd` | Pronto | Carica 5 cataloghi JSON, orchestra stato |
| **SaveManager** | `autoload/save_manager.gd` | Pronto | Save v5.0.0, atomic write + backup, HMAC-SHA256 integrity, migrazione v1→v5 |
| **SupabaseClient** | `autoload/supabase_client.gd` | Pronto (off di default) | Session token cifrato con chiave device-local, HTTPS obbligatorio, 5 tabelle cloud push |
| **AudioManager** | `autoload/audio_manager.gd` | Pronto | Dual-player crossfade 2s, mood-driven track switch (stress-manager integration) |
| **PerformanceManager** | `systems/performance_manager.gd` | Pronto | FPS cap 60 focused / 15 background. Window position persistence |
| **StressManager** | `systems/stress_manager.gd` | Pronto | Stress continuo 0.0-1.0, 3 livelli (calm/neutral/tense) con isteresi, decay 2%/min |

## Funzionalità demo-ready

- Stanza pixel-art cozy_studio con 3 temi colore (modern / natural / pink)
- **129 decorazioni** drag-and-drop in 13 categorie (pets nascosta)
- Interazione: click → popup con R (rotate 90°) / F (flip horizontal) / S (scale 0.25x→3x) / X (delete in edit mode)
- Shift tenuto durante drag → disabilita snap-to-grid 64px per placement fine
- Personaggio pixel-art `male_old` (Ragazzo Classico) con 8 direzioni + idle/walk/interact/rotate
- Pet gatto void con FSM 5 stati (idle / wander / follow / sleep / play)
- Mess system: oggetti sporchi si accumulano, puliscili → +coins, riduce stress
- Mood sliding (profile HUD): cambia audio track real-time
- Sistema account locale: guest mode + username+password con lockout anti-brute-force
- Tutorial 9 step signal-driven, re-giocabile da settings
- Toast notifications (3 visibili max, auto-dismiss 3s)
- Profile HUD mini panel (nome, mood slider, lang toggle IT/EN, settings button)
- HMAC save integrity: save tampering rilevato, fallback a backup
- Musica lo-fi auto-play con crossfade 2s, ambience multi-stream

## Testing

```bash
./scripts/smoke_test.sh       # Boot headless ~2s
./scripts/preflight.sh        # 8 step: toolchain, integrita, JSON, asset, boot, runtime, deep tests, artefatti. GO/NO-GO exit 0/1
./scripts/godot-validate.sh   # Ciclo completo re-import + runtime 15s ~3min
./scripts/deep_test.sh        # 112 test invasivi in 8 moduli ~7s:
                              #   helpers(16) + catalogs(21) + stress(12) + save(13)
                              #   + spawn(11) + panels(9) + input(14) + ui_events(16)
```

Tutti i test girano anche in CI (GitHub Actions) come job **deep-tests** nel
container `barichello/godot-ci:4.6`, gated dopo `smoke-headless`.

## Contributori

| Nome | Ruolo | Area |
|------|-------|------|
| **Renan Augusto Macena** | System Architect + Project Supervisor | Runtime, UI, gameplay, architettura |
| **Elia Zoccatelli** | Database Engineer | SQLite schema + migrazioni + Supabase cloud |
| **Cristian Marino** | Asset Pipeline + CI/CD | Pixel art, build, GitHub Actions |
| **Alex** (nuovo, 16 Apr 2026) | Pixel Art Artist | Personaggi + cat animations |

## Licenza

Progetto accademico IFTS 2026 — tutti i diritti riservati.
Copyright © 2026 Renan Augusto Macena. Redistribuzione non autorizzata vietata.
Asset esterni (Kenney CC0, SoppyCraft, Thurraya, Eder Muniz, Mixkit, Kenney UI Pack)
rispettano le licenze originali documentate in `v1/assets/*/README.md`.
