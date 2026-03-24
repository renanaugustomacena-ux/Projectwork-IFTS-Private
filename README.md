# Projectwork — Mini Cozy Room

> **⚠️ ATTENZIONE COLLEGHI: Work in Progress**
> Ciao a tutti! Vi ricordo che il progetto è un work in progress.
> - **Documentazione:** Abbiamo tutta la documentazione necessaria all'interno delle cartelle `v1/study` e `c1/guide`. Dobbiamo tutti leggere e mantenere aggiornati questi documenti man mano che proseguiamo con i lavori.
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
