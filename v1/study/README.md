# Study Documents — Mini Cozy Room

Reference documents for understanding the project, Godot Engine, game development practices, and the build process.

---

## Documents

| Document | Topics Covered | Size |
|----------|---------------|------|
| [PROJECT_DEEP_DIVE.md](PROJECT_DEEP_DIVE.md) | Project vision, architecture, signal-driven design, data flow, scene hierarchies, save system, content inventory | ~600 lines |
| [GODOT_ENGINE_STUDY.md](GODOT_ENGINE_STUDY.md) | Engine architecture, GDScript language, scene system, signals, resources, UI, audio, autoloads, tweens, performance, debugging | ~800 lines |
| [ISOMETRIC_GAMES.md](ISOMETRIC_GAMES.md) | Isometric projection math, tile systems, depth sorting, character movement, pixel art, camera, famous games, room-based design | ~700 lines |
| [GAME_DEV_PLANNING.md](GAME_DEV_PLANNING.md) | Pre-modification checklist, version control, architecture patterns, testing, common mistakes, refactoring, technical debt, project management | ~750 lines |
| [BUILD_AND_EXPORT.md](BUILD_AND_EXPORT.md) | Compilation, Godot export system, platform builds, CI/CD pipelines, distribution (Steam/itch.io), optimization, versioning, legal requirements | ~750 lines |

## Suggested Reading Order

1. **PROJECT_DEEP_DIVE.md** — Start here to understand what we're building and why
2. **GODOT_ENGINE_STUDY.md** — Learn the engine that powers our project
3. **ISOMETRIC_GAMES.md** — Understand the game genre and rendering techniques
4. **GAME_DEV_PLANNING.md** — Learn how to plan changes without breaking things
5. **BUILD_AND_EXPORT.md** — Understand how the game reaches players

## Glossario Rapido del Progetto

Termini specifici di Mini Cozy Room che troverete nei documenti e nel codice:

| Termine | Significato |
|---------|-------------|
| **SignalBus** | Autoload che fa da "centralino" per tutti i segnali globali del gioco. Ogni comunicazione tra sistemi passa da qui |
| **Catalog-Driven** | Approccio in cui il contenuto del gioco (stanze, decorazioni, personaggi) e' definito in file JSON, non nel codice |
| **Offline-First** | Il gioco funziona completamente senza internet. Supabase e' opzionale e degrada gracefully |
| **Desktop Companion** | Genere di applicazione progettata per restare aperta a lungo in sottofondo, con consumo minimo di risorse |
| **WAL (Write-Ahead Logging)** | Modalita' di SQLite che scrive prima in un journal (.db-wal) e poi nel database. Piu' sicuro e veloce |
| **Dirty Flag** | Flag booleano che indica "ci sono modifiche non salvate". SaveManager salva solo quando il flag e' attivo |
| **Crossfade** | Transizione audio graduale: una traccia si abbassa mentre la nuova sale. Gestita da AudioManager |
| **Tween** | Oggetto Godot che interpola valori nel tempo (animazioni, transizioni, fade). Va sempre tracciato e ucciso in _exit_tree |
| **_exit_tree()** | Funzione callback di Godot chiamata quando un nodo sta per essere rimosso dall'albero. Usata per pulizia risorse |
| **queue_free()** | Metodo Godot per distruggere un nodo alla fine del frame corrente (non immediatamente) |
| **Autoload** | Script caricato automaticamente da Godot all'avvio del gioco, accessibile ovunque come singleton globale |
| **GdUnit4** | Framework di testing per Godot 4. Usato per i test unitari del progetto |
| **gdlint / gdformat** | Strumenti di linting e formattazione automatica per GDScript. Eseguiti nella pipeline CI |
| **PanelManager** | Classe che gestisce il ciclo di vita di tutti i pannelli UI (apertura, chiusura, animazioni) |
| **Snap to Grid** | Le decorazioni si posizionano su una griglia di 64px. `Helpers.snap_to_grid()` arrotonda la posizione |

## Quick Reference Cards

### Ordine Autoload (chi dipende da chi)

```text
1. SignalBus        ← nessuna dipendenza (caricato per primo)
2. AppLogger        ← nessuna dipendenza
3. GameManager      ← usa SignalBus
4. SaveManager      ← usa SignalBus, GameManager
5. LocalDatabase    ← usa SignalBus, AppLogger
6. AudioManager     ← usa SignalBus, GameManager, SaveManager
7. SupabaseClient   ← usa SignalBus, AppLogger (opzionale)
8. PerformanceManager ← usa SignalBus, SaveManager
```

### Domini dei Segnali SignalBus

```text
STANZA / GAMEPLAY           AUDIO                    SISTEMA
- room_changed              - track_changed          - save_requested
- decoration_placed         - playlist_changed       - save_completed
- decoration_removed        - ambience_toggled       - save_to_database_requested
- character_changed         - volume_changed         - settings_updated
- character_swapped                                  - music_state_updated

UI / PANNELLI               DATI
- panel_opened              - catalog_loaded
- panel_closed              - inventory_changed
```

### Percorsi File Importanti

```text
Codice:
  v1/scripts/autoload/       — Singleton (SignalBus, GameManager, SaveManager, ecc.)
  v1/scripts/rooms/          — Logica stanza, decorazioni, personaggi, sfondo
  v1/scripts/ui/             — Pannelli UI, PanelManager, drop zone
  v1/scripts/utils/          — Constants, Helpers, EnvLoader

Dati:
  v1/data/characters.json    — Catalogo personaggi (sprite, animazioni)
  v1/data/decorations.json   — Catalogo decorazioni (sprite, categorie, scale)
  v1/data/rooms.json         — Catalogo stanze (temi, colori)
  v1/data/tracks.json        — Catalogo tracce musicali

Scene:
  v1/scenes/main/            — Scena principale (stanza di gioco)
  v1/scenes/menu/            — Menu principale
  v1/scenes/ui/              — Scene dei pannelli UI (.tscn)

Test:
  v1/tests/unit/             — Test GdUnit4
```

## Mappa Documenti ↔ Argomenti d'Esame

Per prepararvi all'esame, ecco quali documenti coprono quali potenziali argomenti:

| Argomento d'Esame | Documento Principale | Sezioni Chiave |
|--------------------|---------------------|----------------|
| Architettura software | PROJECT_DEEP_DIVE.md | Sez. 2 (Architecture), Sez. 5 (Singletons) |
| Pattern di design (Singleton, Observer) | PROJECT_DEEP_DIVE.md + GODOT_ENGINE_STUDY.md | Sez. 2 + Sez. 6 (Signals) |
| Database relazionali (SQL, PK, FK) | GUIDA_ELIA_DATABASE.md | Concetti Database, Task 1-3 |
| Testing e qualita' del software | GAME_DEV_PLANNING.md | Sez. 5 (Testing), Sez. 6 (Common Mistakes) |
| CI/CD e automazione | BUILD_AND_EXPORT.md + GUIDA_CRISTIAN_CICD.md | Sez. 8 (CI/CD) + Task 1-2 |
| Versionamento (Git) | GAME_DEV_PLANNING.md | Sez. 3 (Version Control), Sez. 4 (Commit Workflow) |
| Sicurezza informatica | AUDIT_REPORT.md | Sez. 6.6 (SupabaseClient), Sez. 10 (Security) |
| Prestazioni e ottimizzazione | GODOT_ENGINE_STUDY.md | Sez. 16 (Performance), Sez. 17 (Debugging) |
| Progettazione interfacce utente | GODOT_ENGINE_STUDY.md | Sez. 10-11 (UI, Themes) |
| Gestione progetto e lavoro in team | GAME_DEV_PLANNING.md | Sez. 8-9 (Quality vs Scope, Pipeline) |
| Export e distribuzione software | BUILD_AND_EXPORT.md | Sez. 3-7 (Export, Platform, Distribution) |
| Grafica 2D e proiezione isometrica | ISOMETRIC_GAMES.md | Tutto il documento |

## Related Resources

- [../guide/](../guide/) — Operational guides for each team member
- [../AUDIT_REPORT.md](../AUDIT_REPORT.md) — Technical audit with bug tracking
- [../TECHNICAL_GUIDE.md](../TECHNICAL_GUIDE.md) — Developer reference

---

*IFTS Projectwork 2026 — Renan Augusto Macena (System Architect & Project Supervisor)*
