# Guide Operative per il Team — Mini Cozy Room

> **Aggiornamento 10 Aprile 2026**:
> - **Report consolidato**: i 5 documenti originali (AUDIT_REPORT, SPRINT_AUDIT_REPORT, architecture-review, SPRINT_TASKS, SPRINT_UX_PERFECTION_PLAN) sono stati unificati in [CONSOLIDATED_PROJECT_REPORT.md](../docs/CONSOLIDATED_PROJECT_REPORT.md)
> - **Sprint 6-11 Aprile**: completati 39 task sprint (character selection, tutorial 10 step, pet controller, toast system, keyboard nav, ecc.)
> - **Task Renan 19-21**: COMPLETATI (fix clean_name, auth_screen _exit_tree, settings_panel SignalBus)
> - **Task Cristian 9-11**: COMPLETATI (build.yml 4.6, icona app, versione 1.0.0)
> - **Task Elia 7-8**: COMPLETATI (indici FK, tabelle morte rimosse)
> - **Nuovi bug runtime**: floor bounds inesistenti (CRITICO), pet animation singola, character flicker — vedi Parte V del report
> - **Branch**: si lavora SOLO su `main`

---

## PRIMA DI TUTTO — Cosa Fare Adesso

**Tutti**: leggere [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare Godot 4.6, Git, VS Code.

Poi aprite la vostra guida e seguite i task nell'ordine indicato qui sotto.

### Renan — Gameplay, UI & Asset

| Ordine | Task | Cosa Fare | Stato |
|:------:|------|-----------|:-----:|
| 1 | Task 1 | ~~Correggere typo `sxt` → `sx` in characters.json~~ | **FATTO** |
| 2 | Task 2 | ~~Rimuovere 3 costanti personaggi inutilizzati~~ | **FATTO** |
| 3 | Task 3 | ~~Correggere array mismatch in window_background.gd~~ | **FATTO** |
| 4 | Task 4 | ~~Race condition swap personaggio → `call_deferred`~~ | **FATTO** |
| 5 | Task 5 | ~~Null check su caricamento texture in drop_zone.gd~~ | **FATTO** |
| 6 | Task 6 | ~~Aggiungere `_exit_tree()` a 6 script~~ | **FATTO** |
| 7 | Task 7 | ~~Null check su `_anim` in character_controller.gd~~ | **FATTO** |
| — | Task 8-11 | ~~Integrazione asset~~ | **FATTO** |
| 8 | Task 12-13 | ~~Popup decorazioni + persistenza rotazione/scala~~ | **FATTO** |
| 9 | Task 14 | ~~`_exit_tree()` per panel_manager.gd e room_grid.gd~~ | **FATTO** |
| 10 | Task 15 | ~~Riferimento diretto Dictionary per decorazioni (A15)~~ | **FATTO** |
| 11 | Task 16 | ~~Tween orfani in main_menu.gd (A19)~~ | **FATTO** |
| 12 | Task 17 | ~~Clamp posizione decorazioni al viewport (A28)~~ | **FATTO** |
| 13 | Task 18 | ~~Null check dopo scene.instantiate() (A29)~~ | **FATTO** |
| 14 | Task 19 | ~~Fix `clean_name` in auth_manager.gd:60 (N-Q3)~~ | **FATTO** (commit 953ad1e) |
| 15 | Task 20 | ~~Aggiungere `_exit_tree()` + tween tracciato in auth_screen.gd (N-Q1)~~ | **FATTO** (3 Apr) |
| 16 | Task 21 | ~~Fix settings_panel.gd: usare SignalBus.settings_updated (N-AR7)~~ | **FATTO** (commit 953ad1e) |

**21 task completati su 21.** Tutti i task audit v2.0.0 completati.

**Nuovi task post-sprint** (vedi Parte VIII del report consolidato):
| Ordine | Task | Cosa Fare | Stato |
|:------:|------|-----------|:-----:|
| **17** | **PR 1** | **CRITICO — Floor bounds unificate (risolve bug decor invisibili + player fuori stanza)** | **DA FARE** |
| **18** | **PR 2** | **Pet animations separate per stato (risolve pet che slitta dormendo)** | **DA FARE** |
| 19 | PR 3 | Investigare character flicker (bug #4) | DA FARE |
| 20 | PR 4 | Decor categories UX (bug #3 — da chiarire) | DA FARE |
**Guida**: [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md)

### Cristian — CI/CD, Logger & Asset

| Ordine | Task | Cosa Fare | Tempo | File | Stato |
|:------:|------|-----------|-------|------|:-----:|
| — | Task 1-2 | ~~CI branch + lint test~~ | — | `.github/workflows/ci.yml` | **GIA' FATTO** |
| — | Task 3 | ~~Logger: session ID con Crypto~~ | — | `scripts/autoload/logger.gd` | **FATTO (31 Mar)** |
| — | Task 4 | ~~Logger: buffer mantiene ultimi 100 msg~~ | — | `scripts/autoload/logger.gd` | **FATTO (31 Mar)** |
| — | Task 5 | ~~`_exit_tree()` al PerformanceManager~~ | — | `scripts/systems/performance_manager.gd` | **FATTO (31 Mar)** |
| — | CI+ | ~~Pipeline unificata 5 job + 4 script Python~~ | — | `ci/`, `.github/workflows/ci.yml` | **FATTO (31 Mar)** |
| — | Task 9 | ~~CRITICO — Fix build.yml: Godot 4.5 → 4.6 (N-BD1)~~ | — | `.github/workflows/build.yml` | **FATTO** (3 Apr) |
| — | Task 10 | ~~Icona applicazione Windows (N-BD4)~~ | — | `export_presets.cfg` | **FATTO** (3 Apr) |
| — | Task 11 | ~~Versione applicazione 1.0.0 (N-BD5)~~ | — | `export_presets.cfg` | **FATTO** (3 Apr) |
| **1** | Task 7 | **Trovare/creare nuovo personaggio pixel art** (8 direzioni, 32x32) | 2-3 ore | `assets/charachters/male/old/` | **DA FARE** |
| **2** | Task 8 | **Trovare asset grafici aggiuntivi** (loading screen, decorazioni, icone) | 1-2 ore | `assets/` | **DA FARE** |
| **3** | **Task 12** | **Trovare/creare sprite pet** (idle, walk, sleep — almeno 3 animazioni) | 1-2 ore | `assets/pets/` | **DA FARE** |
| 4 | Task 6 | Aggiornare documentazione (DOPO che tutti finiscono) | 1 ora | Vari README | DA FARE |

**Task 3-5 + 9-11 completati.** Restano Task 6-8 + nuovo Task 12 (sprite pet).
**PRIORITA'**: Task 7 (personaggio) e Task 12 (pet sprites) — servono per risolvere i bug runtime.
**Guida**: [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md)
**Riferimento asset personaggio**: [`assets/charachters/README.md`](../assets/charachters/README.md)

### Elia — Database & Supabase

| Ordine | Task | Cosa Fare | Tempo | File | Stato |
|:------:|------|-----------|-------|------|:-----:|
| — | Task 1 | ~~Studiare le correzioni gia' fatte~~ | — | `scripts/autoload/local_database.gd` | **FATTO (31 Mar)** |
| — | Task 2 | ~~A24: ROLLBACK alle transazioni~~ | — | `scripts/autoload/local_database.gd` | **FATTO (31 Mar)** |
| — | Task 3 | ~~A25: `_save_inventory()` ritorna bool~~ | — | `scripts/autoload/local_database.gd` | **FATTO (31 Mar)** |
| — | Task 4 | ~~A26: Check `is_open()` in `_set_state()`~~ | — | `scripts/autoload/auth_manager.gd` | **FATTO (31 Mar)** |
| — | Task 5 | ~~A27: Validare `create_account()` in `register()`~~ | — | `scripts/autoload/auth_manager.gd` | **GIA' FATTO** |
| — | Task 7 | ~~N-DB2: Aggiungere indici FK al database~~ | — | `scripts/autoload/local_database.gd` | **FATTO** (3 Apr) |
| — | Task 8 | ~~N-DB1: Tabelle morte rimosse~~ | — | `scripts/autoload/local_database.gd` | **FATTO** (3 Apr) |
| **1** | **Task 6** | **Supabase**: creare progetto, 3 tabelle, RLS | 1.5 ore | Dashboard Supabase | **DA FARE** |

**Task 1-5 + 7-8 completati.** Resta Task 6 (Supabase).
**Dopo Task 6**: consegnare URL e anon key a Renan per implementazione client.
**Guida**: [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md)
**Riferimento asset menu**: [`assets/menu/README.md`](../assets/menu/README.md)

---

## Mappa delle Dipendenze — Chi Aspetta Chi

```text
NESSUNO BLOCCA NESSUNO per i task iniziali — tutti possono partire subito!

  Cristian Task 9 (CRITICO N-BD1) ─────────────────┐ ← PRIMA PRIORITA'
  (fix build.yml 4.5→4.6)                          │
                                                    │
  Renan Task 19-21 ────────────────────────────────┤
  (fix audit v2, indipendenti)                      │
                                                    ├──► Cristian Task 6 (documentazione)
  Cristian Task 7-8 ───────────────────────────────┤    Farlo SOLO quando tutti
  (asset personaggio, indipendente)                 │    hanno finito i loro task
                                                    │
  Cristian Task 10-11 ─────────────────────────────┤
  (icona + versione app, indipendenti)              │
                                                    │
  Elia Task 7-8 ───────────────────────────────────┤
  (indici FK + tabelle morte, indipendenti)         │
                                                    │
  Elia Task 6 (Supabase setup) ────────────────────┘
       │
       └──► Consegna URL + anon key a Renan
            └──► Renan implementa client GDScript (fase futura)
```

**Unica dipendenza vera**: Cristian NON deve fare il Task 6 (documentazione) finche'
gli altri non hanno finito. Tutto il resto si fa in parallelo.

**Attenzione ai conflitti Git**: Renan e Elia modificano entrambi `local_database.gd`
e `auth_manager.gd`. Coordinarsi per non lavorare sullo stesso file contemporaneamente:
- **Consiglio**: Elia fa prima i suoi Task 7-8 (database), poi Renan lavora su quei file se serve

---

## Guide Personali

| Guida | Per Chi | Contenuto | Task Rimasti |
|-------|---------|-----------|:------------:|
| [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md) | **Renan** | ~~21 task audit completati~~, **PR 1 floor bounds (CRITICO)**, PR 2 pet animations, PR 3-4 bug fix | 4 |
| [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md) | **Cristian** | ~~Logger, PerformanceManager, CI, build.yml, icona, versione~~, **personaggio pixel art**, **sprite pet**, asset, documentazione | 4 |
| [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md) | **Elia** | ~~ROLLBACK, _save_inventory, is_open(), create_account, indici FK, tabelle morte~~, **setup Supabase** | 1 |

## Relazione con l'Audit Report

Queste guide sono la versione operativa (il "come fare") del [CONSOLIDATED_PROJECT_REPORT.md](../docs/CONSOLIDATED_PROJECT_REPORT.md) (il "cosa fare e perche'").

**Versione report**: **v3.0.0** — Consolidamento completo (10 Aprile 2026). Il report ha 12 parti:
- Parte I: Panoramica progetto + metodologia audit
- Parte II: Architettura (diagrammi, flussi, segnali)
- Parte III-IV: Stato componenti + analisi codice riga per riga
- Parte V: Diagnosi bug runtime (floor bounds, pet, character flicker)
- Parte VI: Registro audit completo 12 pass
- Parte VII: Piano UX con acceptance criteria
- Parte VIII: Sprint tasks + piano PR post-sprint
- Parte IX-X: Build/deployment + troubleshooting
- Parte XI-XII: Statistiche + guide operative (Godot Editor, frontend)
- Appendici A-K: Glossario, schema DB, segnali, comandi utili, link Godot

Se avete dubbi sul *perche'* di una correzione, consultate la parte del report indicata all'inizio di ogni task.

---

## Timeline del Progetto — Scadenza: 22 Aprile 2026

**Obiettivo**: il gioco deve **funzionare** e **essere presentabile** entro il 22 aprile.
Non deve essere perfetto — deve essere stabile, senza crash, e con le funzionalita' core operative.

| Periodo | Obiettivo | Chi | Ore |
|---------|-----------|-----|:---:|
| **1 Apr - 6 Apr** | **CRITICO**: Fix build.yml 4.5→4.6 (Cristian Task 9). Fix codice audit v2 (Renan Task 19-21). Indici FK (Elia Task 7) | Tutti | 2-3h |
| **7 Apr - 13 Apr** | Tabelle morte DB (Elia Task 8), Icona+Versione app (Cristian Task 10-11), Supabase setup (Elia Task 6) | Elia, Cristian | 3-4h |
| **14 Apr - 18 Apr** | Nuovo personaggio (Cristian Task 7), asset grafici (Cristian Task 8), test manuale completo | Cristian, Tutti | 4-6h |
| **19 Apr - 22 Apr** | Test finale, fix urgenti, documentazione (Cristian Task 6), presentazione | Tutti | 2-3h |

**Totale stimato per persona**: ~12-18 ore distribuite su ~3 settimane.
**Priorita'**: task CRITICI e ALTI prima. I task MEDI e BASSI sono bonus.

---

## Protocollo di Comunicazione — Cosa Fare se Sei Bloccato

| Tipo di Blocco | Chi Contattare | Come |
|----------------|----------------|------|
| Non riesco a configurare l'ambiente | Renan | Messaggio nel gruppo con screenshot dell'errore |
| Conflitto Git (merge conflict) | Renan o Cristian | Messaggio + output di `git status` e `git diff` |
| Godot non apre la scena / crash | Renan | Messaggio + pannello Output di Godot (screenshot) |
| Dubbio su schema database / SQL | Elia o Renan | Messaggio con la query + errore |
| Non capisco cosa devo fare in un task | Renan | Messaggio citando il numero del task |
| Ho rotto qualcosa e non so come annullare | **Renan SUBITO** | NON fare `git reset --hard`. Chiedere prima |

**Regola d'oro**: meglio chiedere e aspettare 10 minuti che fare un pasticcio che richiede 2 ore per essere corretto.

---

## Checklist di Validazione Finale (per TUTTO il team)

Quando tutti i task sono completati, verificare **insieme** che tutto funzioni:

```text
INTEGRITA' DATI (Elia + Renan)
- [x] characters.json: corretto typo sxt->sx + rinominato file (Task 1 Renan — FATTO)
- [x] constants.gd: rimosse 3 costanti orfane (Task 2 Renan — FATTO)
- [x] Database: schema characters con character_id PRIMARY KEY (GIA' FATTO 27 Mar)
- [x] Database: schema inventario normalizzato (GIA' FATTO 27 Mar)
- [x] Database: transazioni con ROLLBACK su errore (Task 2 Elia — FATTO 31 Mar)
- [x] Database: _save_inventory() propaga errori (Task 3 Elia — FATTO 31 Mar)
- [x] Database: is_open() check prima di query (Task 4 Elia — FATTO 31 Mar)
- [x] Database: create_account() validato in register() (Task 5 Elia — GIA' FATTO)
- [x] Database: indici su colonne FK (Task 7 Elia — N-DB2) — FATTO 3 Apr
- [x] Database: tabelle morte rimosse (Task 8 Elia — N-DB1) — FATTO 3 Apr

STABILITA' E LIFECYCLE (Renan + Cristian)
- [x] _exit_tree() in 8 script di Renan (Task 6+14 Renan — FATTO) + PerformanceManager (Cristian — FATTO 31 Mar)
- [ ] Nessun memory leak (Profiler stabile dopo 10 cicli menu->stanza->menu)
- [x] Race condition swap personaggio risolto con call_deferred (Task 4 Renan — FATTO)
- [x] Null check su AnimatedSprite2D e Texture2D (Task 5+7+18 Renan — FATTO)
- [x] Tween orfani in main_menu.gd risolti (Task 16 Renan — FATTO)
- [x] Decorazioni: riferimento diretto Dictionary, no duplicati (Task 15 Renan — FATTO)
- [x] Decorazioni: posizioni clampate al viewport al reload (Task 17 Renan — FATTO)
- [x] Logger: session ID con Crypto (Task 3 Cristian — FATTO 31 Mar)
- [x] Logger: buffer non perso se file non disponibile (Task 4 Cristian — FATTO 31 Mar)
- [x] Fix clean_name in auth_manager.gd (Task 19 Renan — N-Q3) — FATTO commit 953ad1e
- [x] _exit_tree() + tween in auth_screen.gd (Task 20 Renan — N-Q1) — FATTO 3 Apr
- [x] settings_panel.gd usa SignalBus (Task 21 Renan — N-AR7) — FATTO commit 953ad1e

BUILD & CI/CD (Cristian)
- [x] build.yml usa Godot 4.6 (Task 9 Cristian — N-BD1) — FATTO 3 Apr
- [x] Icona applicazione Windows configurata (Task 10 Cristian — N-BD4) — FATTO 3 Apr
- [x] Versione applicazione 1.0.0 impostata (Task 11 Cristian — N-BD5) — FATTO 3 Apr
- [x] CI attiva su branch main (GIA' FATTO)
- [x] gdlint + gdformat controllano v1/scripts/ e v1/tests/ (GIA' FATTO)

ASSET (Cristian)
- [x] Asset integrati: joystick, loading screen, bottoni, letti, mobili, piante (GIA' FATTO)
- [ ] Nuovo personaggio pixel art trovato/creato e sostituito (Task 7 Cristian)
- [ ] Asset grafici aggiuntivi trovati (Task 8 Cristian)

CLOUD (Elia → Renan)
- [ ] Supabase: progetto creato con 3 tabelle + RLS (Task 6 Elia)
- [ ] URL e anon key consegnati a Renan
- [ ] Client GDScript implementato da Renan (fase futura)

GIOCO FUNZIONANTE (TUTTI — test finale)
- [ ] Menu principale: si carica senza errori
- [ ] Stanza: personaggio si muove con animazioni corrette in 8 direzioni
- [ ] Decorazioni: drag-and-drop funziona, snap a griglia
- [ ] Sfondo foresta: parallax scrolling fluido
- [ ] Salvataggio/caricamento: funziona senza perdita dati
- [ ] Pannello Output: ZERO errori rossi durante gameplay completo
```

---

## Documentazione Asset

Ogni sottocartella di `assets/` ha un proprio README con origine, licenza e istruzioni di integrazione:

| README | Contenuto |
|--------|-----------|
| [`assets/README.md`](../assets/README.md) | Mappa origini (creato vs scaricato), licenze, integrazione |
| [`assets/charachters/README.md`](../assets/charachters/README.md) | Formato sprite 32x32, 8 direzioni, come sostituire il personaggio |
| [`assets/audio/README.md`](../assets/audio/README.md) | 2 tracce Mixkit, come aggiungere nuova musica |
| [`assets/backgrounds/README.md`](../assets/backgrounds/README.md) | 12 layer parallasse Eder Muniz |
| [`assets/menu/README.md`](../assets/menu/README.md) | Bottoni, loading screen, joystick |
| [`assets/pets/README.md`](../assets/pets/README.md) | Void Cat, come aggiungere nuovi pet |
| [`assets/room/README.md`](../assets/room/README.md) | Stanza base, porte, finestre, 8 letti |
| [`assets/sprites/README.md`](../assets/sprites/README.md) | SoppyCraft piante + Thurraya mobili, come aggiungere decorazioni |
| [`assets/ui/README.md`](../assets/ui/README.md) | Kenney UI Pack CC0, tema cozy_theme.tres |

---

## Convenzioni Usate nelle Guide

- **Percorsi file**: sempre relativi alla cartella `v1/` del progetto
- **Codice**: ogni riga non ovvia ha un commento in italiano che spiega cosa fa
- **Prima/Dopo**: per ogni correzione, viene mostrato il codice problematico e poi il codice corretto
- **Come Verificare**: alla fine di ogni task, una lista di passi per verificare che la correzione funzioni
- **Cosa Puo' Andare Storto**: errori comuni e come risolverli
- **Tempo stimato**: ogni task ha una stima del tempo necessario

---

*Queste guide fanno parte del progetto Mini Cozy Room — Consolidated Project Report v3.0.0.*
*Scadenza progetto: 22 Aprile 2026.*
*Ultimo aggiornamento: 10 Aprile 2026*
