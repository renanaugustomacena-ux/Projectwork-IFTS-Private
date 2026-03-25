# Projectwork — Mini Cozy Room

> **⚠️ ATTENZIONE COLLEGHI: Work in Progress — Semplificazione in Corso**
> Ciao a tutti! Vi ricordo che il progetto è un work in progress.
> - **Documentazione:** Abbiamo tutta la documentazione necessaria all'interno delle cartelle `v1/study` e `v1/guide`. Dobbiamo tutti leggere e mantenere aggiornati questi documenti man mano che proseguiamo con i lavori.
> - **Semplificazione Codebase:** Stiamo attivamente lavorando per rendere il codice meno avanzato e più accessibile, **senza perdere funzionalità**. Alcuni sistemi nel codebase sono **placeholder** o **over-engineered** rispetto alle necessità reali del gioco. Se trovate qualcosa di ridondante o troppo complesso, è probabilmente intenzionale e in fase di revisione. Consultate la sezione [Stato dei Sistemi](#stato-dei-sistemi) qui sotto.
> - **Eventuali Errori:** Potrebbero esserci dei lievi errori al momento perché il codice generato automaticamente non è sempre perfetto. Tuttavia, abbiamo guide per correggere tutto e ottimi consigli per il lavoro futuro.
> - **Struttura Repository:** Il repository è ora ben strutturato, più facile su cui lavorare e organizzato appositamente per lavorare in team con voi.
> - **Branch Renan:** Il branch *Renan* contiene già tutto ciò che potete trovare nel branch *main* più piccolo.

Desktop companion 2D realizzato con **Godot 4.5** (GDScript, GL Compatibility renderer).

Un ambiente digitale rilassante che combina stanze pixel art personalizzabili, musica lo-fi
e un personaggio interattivo. Pensato per restare aperto in background durante studio o lavoro.

**Pubblico target**: studenti, lavoratori da remoto, chiunque cerchi un ambiente digitale rilassante.

## Avvio Rapido

```bash
# 1. Clona il repository
git clone https://github.com/ZroGP/Projectwork-IFTS.git
cd Projectwork-IFTS

# 2. Checkout del branch di sviluppo
git checkout Renan

# 3. Apri il progetto in Godot Engine 4.5
#    Import -> seleziona v1/project.godot -> Play (F5)
```

> **Nota:** Il gioco funziona completamente offline. La sincronizzazione cloud
> (Supabase) e opzionale e degrada in modo trasparente se non configurata.

## Struttura Repository

```
.
├── .github/workflows/     # CI/CD (lint, test, security, export)
│   ├── ci.yml             # gdlint + gdformat + GdUnit4 + security scan
│   └── build.yml          # Export Windows (.exe) + HTML5
├── v1/                    # Codice sorgente del progetto Godot
│   ├── addons/            # Plugin (godot-sqlite v4.7)
│   ├── assets/            # 1400+ asset (sprite, audio, UI, sfondi)
│   ├── data/              # Cataloghi JSON + schema SQL
│   ├── scenes/            # 8 scene Godot (.tscn)
│   ├── scripts/           # 25 script GDScript
│   └── tests/             # 4 test unitari (GdUnit4)
└── README.md              # Questo file
```

### Documentazione

| Documento | Percorso | Contenuto |
|-----------|----------|-----------|
| Documentazione Tecnica | [v1/README.md](v1/README.md) | Architettura, autoload, scene tree, contenuti, sviluppo |
| Schema Database | [v1/data/README.md](v1/data/README.md) | JSON/SQLite/Supabase, 7 tabelle, RLS, migrazioni |
| Plugin e Addon | [v1/addons/README.md](v1/addons/README.md) | godot-sqlite GDExtension v4.7, piattaforme supportate |
| Asset Grafici e Audio | [v1/assets/README.md](v1/assets/README.md) | 1.422 file: sprite, audio, sfondi, UI, licenze |
| Scene Godot | [v1/scenes/README.md](v1/scenes/README.md) | 8 scene .tscn, struttura nodi, flusso tra scene |
| Script GDScript | [v1/scripts/README.md](v1/scripts/README.md) | 25 script, autoload, 20 segnali, moduli |
| Test Unitari | [v1/tests/README.md](v1/tests/README.md) | 4 test GdUnit4, copertura moduli |

## Stato dei Sistemi

> **Nota per il team:** Il codebase attuale contiene sistemi avanzati che sono stati sviluppati
> come base solida ma che possono essere **semplificati o sostituiti** senza impattare
> il funzionamento del gioco. Ecco la situazione attuale:

| Sistema | File | Stato | Note |
|---------|------|-------|------|
| **SupabaseClient** | `supabase_client.gd` | Placeholder / Sostituibile | Client REST completo con autenticazione e pool HTTP. Il gioco funziona completamente offline — questo modulo puo' essere sostituito con uno stub o rimosso. |
| **LocalDatabase** | `local_database.gd` | Over-engineered / Semplificabile | 7 tabelle SQLite che replicano Supabase. Il salvataggio JSON tramite SaveManager e' sufficiente per tutte le funzionalita' attuali. Puo' essere ridotto a 2-3 tabelle o rimosso. |
| **SaveManager** | `save_manager.gd` | Funzionante / Semplificabile | Sistema di migrazione v1→v2→v3→v4, backup, auto-save. Il sistema di migrazione versioni e' eccessivo per lo stato attuale — un singolo formato senza backward compatibility basterebbe. |
| **Logger** | `logger.gd` | Funzionante / Opzionale | Log strutturati JSON Lines con rotazione file, livello enterprise. Funziona bene ma e' molto piu' di quanto serve per un gioco cozy. |
| **PerformanceManager** | `performance_manager.gd` | Funzionante / Essenziale | FPS cap dinamico. Leggero e utile, da mantenere. |
| **AudioManager** | `audio_manager.gd` | Funzionante / Essenziale | Musica auto-play con crossfade. Da mantenere. |
| **GameManager** | `game_manager.gd` | Funzionante / Essenziale | Caricamento cataloghi JSON. Da mantenere. |
| **SignalBus** | `signal_bus.gd` | Funzionante / Essenziale | Bus eventi globale. Pattern architetturale fondamentale, da mantenere. |

**In sintesi:** I sistemi contrassegnati come "Placeholder" o "Over-engineered" funzionano correttamente
ma sono piu' complessi del necessario. Se durante il vostro lavoro li trovate ridondanti o confusi,
potete proporre semplificazioni. L'obiettivo e' mantenere il codice accessibile a tutto il team.

## Contributori

| Nome | Ruolo |
|------|-------|
| **Renan Augusto Macena** | System Architect & Project Supervisor |
| **Cristian Marino** | CI/CD & Documentation Lead |
| **Mohamed** | Game Assets, Core Logic & Design Lead |
| **Giovanni** | Game Assets, Core Logic & Design Lead |
| **Elia Zoccatelli** | Database Support |

## Licenza

Progetto accademico IFTS — tutti i diritti riservati.

Copyright (c) 2026 Renan Augusto Macena. Vietata la redistribuzione senza
autorizzazione esplicita dell'autore.
