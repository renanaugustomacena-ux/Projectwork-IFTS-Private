# Projectwork — Mini Cozy Room

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
│   ├── scenes/            # 9 scene Godot (.tscn)
│   ├── scripts/           # 26 script GDScript
│   └── tests/             # 5 test unitari (GdUnit4)
└── README.md              # Questo file
```

### Documentazione

| Documento | Percorso | Contenuto |
|-----------|----------|-----------|
| Documentazione Tecnica | [v1/README.md](v1/README.md) | Architettura, autoload, scene tree, contenuti, sviluppo |
| Schema Database | [v1/data/README.md](v1/data/README.md) | JSON/SQLite/Supabase, 7 tabelle, RLS, migrazioni |
| Plugin e Addon | [v1/addons/README.md](v1/addons/README.md) | godot-sqlite GDExtension v4.7, piattaforme supportate |
| Asset Grafici e Audio | [v1/assets/README.md](v1/assets/README.md) | 1.422 file: sprite, audio, sfondi, UI, licenze |
| Scene Godot | [v1/scenes/README.md](v1/scenes/README.md) | 9 scene .tscn, struttura nodi, flusso tra scene |
| Script GDScript | [v1/scripts/README.md](v1/scripts/README.md) | 26 script, autoload, 21 segnali, moduli |
| Test Unitari | [v1/tests/README.md](v1/tests/README.md) | 5 test GdUnit4, copertura moduli |

## Contributori

| Nome | Ruolo |
|------|-------|
| **Renan Augusto Macena** | Sviluppatore principale, architettura, implementazione |
| **Mohammed** | Feature personaggio interattivo, movimento top-down, sprite pad |
| **FlowLearn Contributor** | Integrazione asset e risorse |

## Licenza

Progetto accademico IFTS — tutti i diritti riservati.

Copyright (c) 2026 Renan Augusto Macena. Vietata la redistribuzione senza
autorizzazione esplicita dell'autore.
