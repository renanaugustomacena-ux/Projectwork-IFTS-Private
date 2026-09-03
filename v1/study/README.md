# v1/study — Mappa per l'esame

I 10 documenti di studio tecnico che vivevano qui (Godot engine, scene & nodes,
sprites, tilemaps, isometric, rendering, DB & persistence, game-dev planning,
project deep-dive, build & export) sono stati rimossi dal tree il 2026-04-23 per
consolidare la documentazione nei README canonici. Restano nella git history:

```bash
git log --all --oneline -- v1/study/
git show 3278f0c^:v1/study/README.md            # l'indice originale con l'ordine di lettura
git show 3278f0c^:v1/study/GODOT_ENGINE_STUDY.md > /tmp/godot.md
```

Questo file tiene vive le due parti ancora utili di quell'indice — la mappa
argomenti d'esame ↔ documenti e il glossario — puntando ai documenti attuali.
I numeri non sono ripetuti qui: si misurano nei README a cui si rimanda
(`ci/validate_doc_counts.py` li controlla).

## Mappa Documenti ↔ Argomenti d'Esame

| Argomento d'esame | Documento principale | Sezioni chiave |
|-------------------|----------------------|----------------|
| Architettura software (separazione modulare, 02) | [../README.md](../README.md) | Principi, Autoload, Scene Tree |
| Pattern di design: Singleton, Observer, macchine a stati (14) | [../scripts/README.md](../scripts/README.md) | Autoload singleton, SignalBus, `pet_controller.gd` (FSM 12 stati), `auth_manager.gd` |
| Eventi e messaggi (13) | [../scripts/README.md](../scripts/README.md) | SignalBus, pattern codificati 2 e 7 |
| Data-driven / configurazione (11, 05) | [../data/README.md](../data/README.md) | Cataloghi JSON, `shop.json`, `mess_catalog.json`, `project.godot` |
| Database relazionali (SQL, PK, FK, indici) | [../data/README.md](../data/README.md) | SQLite schema, indici, migrazioni |
| Persistenza dati e salvataggi (resilienza, 20) | [../data/README.md](../data/README.md), [../README.md](../README.md) | Salvataggio JSON v5.1.0, HMAC, ring backup, 10 slot |
| Autenticazione e sicurezza | [../README.md](../README.md), [../data/README.md](../data/README.md) | Sistema account, PBKDF2, lockout, RLS Supabase |
| Programmazione difensiva (23) | [../scripts/README.md](../scripts/README.md), [../../CHANGELOG.md](../../CHANGELOG.md) | Vocabolario dei fallimenti, FK fail-closed, sezione Fixed 1.3.0 |
| Testing e qualita` del software | [../tests/README.md](../tests/README.md) | Runner, isolamento G-053, tabella moduli |
| CI/CD, build system (22) | [../README.md](../README.md) | CI / CD, job `ci.yml`, `build.yml` |
| Filesystem e asset (08) | [../assets/README.md](../assets/README.md), [../addons/README.md](../addons/README.md) | Origini, licenze, import settings, binari GDExtension |
| Versionamento (Git, SemVer, changelog) | [../../CHANGELOG.md](../../CHANGELOG.md), [../README.md](../README.md) | Keep-a-Changelog, Branch + workflow |
| Prestazioni e ottimizzazione | [../README.md](../README.md) | Desktop companion, PerformanceManager |
| Progettazione interfacce utente | [../scenes/README.md](../scenes/README.md), [../scripts/README.md](../scripts/README.md) | Panel UI, focus chain, mouse_filter, toast |
| Gestione progetto e lavoro in team | [../../README.md](../../README.md), [../../MASTER_PLAN_2026-07-20.md](../../MASTER_PLAN_2026-07-20.md) | Contributori, piani (storici) |
| Export e distribuzione software | [../README.md](../README.md), [../addons/README.md](../addons/README.md) | Target export, `exclude_filter`, Web `extensions_support` |
| Grafica 2D e proiezione isometrica | [../scenes/README.md](../scenes/README.md) | Floor polygon, z-order a bande, parallasse |
| Sprite, texture e animazioni 2D | [../assets/README.md](../assets/README.md), [../assets/pets/README.md](../assets/pets/README.md) | Import Nearest, strip, animazioni mancanti |
| Audio (musica, ambience, effetti) | [../README.md](../README.md), [../assets/audio/README.md](../assets/audio/README.md) | Bande mood, `SfxController`, `tools/gen_sfx.py` |
| Audit e revisione del codice | [../../AUDIT_REPORT_2026-04-23.md](../../AUDIT_REPORT_2026-04-23.md), [../../AUDIT_REVERIFICATION_2026-08-09.md](../../AUDIT_REVERIFICATION_2026-08-09.md) | Istantanee storiche; stato corrente nel CHANGELOG |

## Glossario rapido del progetto

| Termine | Significato |
|---------|-------------|
| **SignalBus** | Autoload che fa da "centralino" per tutti i segnali globali. Ogni comunicazione tra sistemi passa da qui; i test osservano il bus |
| **Catalog-driven** | Il contenuto (stanze, decorazioni, personaggi, sporco, negozio) e` definito in JSON in `data/`, non nel codice |
| **Offline-first** | Il gioco funziona offline con JSON + SQLite. Supabase e` un client dormiente: backup progettato, mai una sync |
| **Desktop companion** | Applicazione pensata per restare aperta a lungo in sottofondo, con consumo minimo (FPS 60 / 15) |
| **Autoload** | Script caricato da Godot all'avvio, accessibile ovunque come singleton. Ne abbiamo 13, in ordine di dipendenza |
| **FSM** | Macchina a stati finiti. Il gatto ne ha una a 12 stati; AuthManager a 3 |
| **WAL (Write-Ahead Logging)** | Modalita` SQLite che scrive prima in un journal (`.db-wal`) e poi nel database |
| **Dirty flag** | "Ci sono modifiche non salvate". Il save automatico scrive solo se e` attivo; Menu/Esci salvano comunque |
| **Atomic write** | Scrivi su file temp, poi rinomina. Previene corruzione se il gioco crasha |
| **HMAC** | Firma del save con chiave device-local (`integrity.key`). Un save manomesso viene rifiutato e si carica il backup |
| **Ring di backup** | Tre generazioni di backup ruotate a ogni save riuscito |
| **Slot** | Una delle 10 partite indipendenti (`user://slots/slot_NN/`); slot 1 = percorsi storici |
| **Salvataggio "solo settings"** | Dal menu principale si riscrivono lingua e volumi sul save esistente senza toccare la stanza |
| **Pulizia a tempo** | Lo sporco si pulisce premendo E; la pulizia dura da 7 s a 1 h e finisce anche a gioco chiuso |
| **Fiducia** | Valore 0-100 del gatto, persistito; regola AVOID / FOLLOW / dormire accanto |
| **Cursore atmosfera** | Slider nel profilo: pioggia e buio sotto 0.50, temporale sotto 0.25, gatto WILD sotto 0.10 |
| **Crossfade** | Transizione audio graduale fra due tracce. Gestita da AudioManager |
| **SfxController** | Figlio di AudioManager che riproduce i 29 effetti sintetizzati; `AudioManager.play_sfx(name)` |
| **Tween** | Oggetto Godot che interpola valori nel tempo. Va sempre tracciato e ucciso in `_exit_tree` |
| **`_exit_tree()`** | Callback chiamato quando un nodo sta per uscire dall'albero. Qui si disconnettono i segnali |
| **`queue_free()`** | Distrugge un nodo alla fine del frame corrente |
| **`class_name`** | Registra un nome globale per uno script. Da usare solo se serve: puo` collidere con classi native nuove (caso `VirtualJoystick` in 4.7) |
| **PanelManager** | Gestisce apertura/chiusura dei pannelli UI; "pannello aperto" blocca il movimento |
| **Snap to grid** | Le decorazioni si posizionano su una griglia di 64 px (`Helpers.snap_to_grid`); Shift la disattiva |
| **Floor polygon** | Rombo isometrico misurato dall'arte, sorgente di verita` per ogni clamp |
| **Sync queue** | Tabella SQLite che accoda operazioni per il backup cloud |
| **DevBridge** | API HTTP locale (debug + `--bridge`) per audit e test dinamici |
| **Sandbox dei test** | `deep_test.sh` sposta `user://` in una directory temporanea; senza il sentinella il runner aborta |
| **gdlint / gdformat** | Lint e formattazione GDScript, eseguiti in CI |
| **Keystore** | File che firma un APK Android. Il progetto ne usa solo uno di debug: Android resta sperimentale |

## Documentazione attiva

- [../README.md](../README.md) — stack, autoload chain, scene tree, contenuti, salvataggio, CI
- [../scripts/README.md](../scripts/README.md) — script per dominio, SignalBus, pattern codificati
- [../scenes/README.md](../scenes/README.md) — scene e flusso
- [../data/README.md](../data/README.md) — cataloghi JSON + schema SQLite + save
- [../tests/README.md](../tests/README.md) — harness e moduli
- [../assets/README.md](../assets/README.md) — origini e licenze degli asset
- [../../CHANGELOG.md](../../CHANGELOG.md) — stato corrente (1.3.0) e limiti noti
