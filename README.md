# Projectwork — Mini Cozy Room

> **Work in Progress — Fase 4 (Supabase) in preparazione**
> Il progetto e' in sviluppo attivo. Il sistema account locale (username + password) e' funzionante.
> Prossimo passo: integrazione Supabase per cloud sync cross-device.
> - **Documentazione:** Tutta la documentazione e' nelle cartelle `v1/study` e `v1/guide`.
> - **Branch Renan:** Contiene tutto cio' che trovate nel branch *main* piu' le ultime modifiche.

Desktop companion 2D realizzato con **Godot 4.6** (GDScript, GL Compatibility renderer).

Un ambiente digitale rilassante che combina stanze pixel art personalizzabili, musica lo-fi
e un personaggio interattivo. Pensato per restare aperto in background durante studio o lavoro.

**Pubblico target**: studenti, lavoratori da remoto, chiunque cerchi un ambiente digitale rilassante.

## Avvio Rapido

```bash
# 1. Clona il repository
git clone https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private.git
cd Projectwork-IFTS-Private

# 2. Apri il progetto in Godot Engine 4.6
#    Import -> seleziona v1/project.godot -> Play (F5)
```

> **Nota:** Il gioco funziona completamente offline con JSON + SQLite.
> Integrazione Supabase per cloud sync prevista nella Fase 4.

## Struttura Repository

```
.
├── .github/workflows/     # CI/CD (lint + export)
│   ├── ci.yml             # gdlint + gdformat (solo lint)
│   └── build.yml          # Export Windows (.exe) + HTML5
├── v1/                    # Codice sorgente del progetto Godot
│   ├── addons/            # Plugin (godot-sqlite v4.7, virtual_joystick)
│   ├── assets/            # 1400+ asset (sprite, audio, UI, sfondi)
│   ├── data/              # Cataloghi JSON + schema SQL
│   ├── scenes/            # Scene Godot (.tscn)
│   ├── scripts/           # Script GDScript
│   └── tests/             # Test unitari (attualmente vuota)
└── README.md              # Questo file
```

### Documentazione

| Documento | Percorso | Contenuto |
|-----------|----------|-----------|
| Documentazione Tecnica | [v1/README.md](v1/README.md) | Architettura, autoload, scene tree, contenuti, sviluppo |
| Schema Database | [v1/data/README.md](v1/data/README.md) | JSON/SQLite, tabelle, migrazioni |
| Plugin e Addon | [v1/addons/README.md](v1/addons/README.md) | godot-sqlite GDExtension v4.7, virtual joystick |
| Asset Grafici e Audio | [v1/assets/README.md](v1/assets/README.md) | 1.422 file: sprite, audio, sfondi, UI, licenze |
| Scene Godot | [v1/scenes/README.md](v1/scenes/README.md) | Scene .tscn, struttura nodi, flusso tra scene |
| Script GDScript | [v1/scripts/README.md](v1/scripts/README.md) | Script, autoload, segnali, moduli |
| Test Unitari | [v1/tests/README.md](v1/tests/README.md) | Attualmente vuota (GdUnit4 non installato) |

## Stato dei Sistemi

| Sistema | File | Stato | Note |
|---------|------|-------|------|
| **AuthManager** | `auth_manager.gd` | Funzionante | Autenticazione locale: guest, username+password. Stubs per Supabase (Fase 4). |
| **LocalDatabase** | `local_database.gd` | Funzionante | 9 tabelle SQLite (accounts con password_hash, characters, rooms, sync_queue, ecc.) |
| **SaveManager** | `save_manager.gd` | Funzionante | JSON v5.0.0, migrazione automatica v1→v5, auto-save 60s, backup |
| **SignalBus** | `signal_bus.gd` | Funzionante / Essenziale | 31 segnali: room, character, audio, decoration, UI, save, auth, sync |
| **GameManager** | `game_manager.gd` | Funzionante / Essenziale | Caricamento cataloghi JSON, stato di gioco |
| **AudioManager** | `audio_manager.gd` | Funzionante / Essenziale | Musica auto-play con crossfade |
| **PerformanceManager** | `performance_manager.gd` | Funzionante / Essenziale | FPS cap dinamico (60/15) |
| **Logger** | `logger.gd` | Funzionante / Opzionale | Log strutturati JSON Lines |

## Funzionalita' Implementate

- Stanza pixel art personalizzabile con 3 temi colore
- 69 decorazioni in 11 categorie (drag-and-drop)
- Interazione decorazioni: click → popup con Rotate/Flip/Scale (+ Delete in edit mode)
- Decorazioni impilabili e con 7 livelli di scala (0.25x → 3x)
- Personaggio controllabile (WASD/frecce) con animazioni 8 direzioni
- Sistema account locale: guest mode, registrazione username+password
- Profilo utente con gestione account (elimina personaggio/account)
- Musica lo-fi auto-play con crossfade
- Salvataggio automatico JSON + SQLite
- Auth screen con login/registrazione/guest all'avvio

## Contributori

| Nome | Ruolo |
|------|-------|
| **Renan Augusto Macena** | System Architect, Gameplay & Project Supervisor |
| **Cristian Marino** | CI/CD & Documentation Lead |
| **Elia Zoccatelli** | Database Support |

## Licenza

Progetto accademico IFTS — tutti i diritti riservati.

Copyright (c) 2026 Renan Augusto Macena. Vietata la redistribuzione senza
autorizzazione esplicita dell'autore.
