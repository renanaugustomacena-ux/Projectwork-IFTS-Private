# Guide Operative per il Team — Mini Cozy Room

> **Aggiornamento 31 Marzo 2026**:
> - **Team**: 3 membri — Renan (Gameplay/UI/Architect), Cristian (CI/CD + Asset), Elia (Database + Supabase)
> - **Supabase**: reintrodotto come servizio cloud. Elia prepara il progetto, Renan implementa il client
> - **CI/CD**: pipeline unificata 5 job (lint, JSON, sprites, crossrefs, DB). Task 1-5 di Cristian FATTI
> - **Asset**: tutti integrati in v1/ (Tasks 8-11 di Renan GIA' FATTI). README creati per ogni sottocartella
> - **Schema DB**: C3/C4 completati (27 Mar). A24-A27 completati (31 Mar). Resta solo Supabase
> - **Branch**: si lavora SOLO su `main`

---

## PRIMA DI TUTTO — Cosa Fare Adesso

**Tutti**: leggere [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare Godot 4.5.2+, Git, VS Code.

Poi aprite la vostra guida e seguite i task nell'ordine indicato qui sotto.

### Renan — Gameplay, UI & Asset — COMPLETATO

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

**Tutti i 18 task completati.** Nessun problema aperto per Renan.
**Guida**: [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md)

### Cristian — CI/CD, Logger & Asset

| Ordine | Task | Cosa Fare | Tempo | File | Stato |
|:------:|------|-----------|-------|------|:-----:|
| — | Task 1-2 | ~~CI branch + lint test~~ | — | `.github/workflows/ci.yml` | **GIA' FATTO** |
| — | Task 3 | ~~Logger: session ID con Crypto~~ | — | `scripts/autoload/logger.gd` | **FATTO (31 Mar)** |
| — | Task 4 | ~~Logger: buffer mantiene ultimi 100 msg~~ | — | `scripts/autoload/logger.gd` | **FATTO (31 Mar)** |
| — | Task 5 | ~~`_exit_tree()` al PerformanceManager~~ | — | `scripts/systems/performance_manager.gd` | **FATTO (31 Mar)** |
| — | CI+ | ~~Pipeline unificata 5 job + 4 script Python~~ | — | `ci/`, `.github/workflows/ci.yml` | **FATTO (31 Mar)** |
| 1 | **Task 7** | **Trovare/creare nuovo personaggio pixel art** (8 direzioni, 32x32) | 2-3 ore | `assets/charachters/male/old/` | DA FARE |
| 2 | Task 8 | Trovare asset grafici aggiuntivi (loading screen, decorazioni, icone) | 1-2 ore | `assets/` | DA FARE |
| 3 | Task 6 | Aggiornare documentazione (DOPO che tutti finiscono) | 1 ora | Vari README | DA FARE |

**Task 3-5 completati + CI espansa con 4 validatori Python.** Restano Task 6-8.
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
| 1 | **Task 6** | **Supabase**: creare progetto, 3 tabelle, RLS | 1.5 ore | Dashboard Supabase | DA FARE |

**Task 1-5 completati.** Resta solo Task 6 (Supabase).
**Dopo Task 6**: consegnare URL e anon key a Renan per implementazione client.
**Guida**: [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md)
**Riferimento asset menu**: [`assets/menu/README.md`](../assets/menu/README.md)

---

## Mappa delle Dipendenze — Chi Aspetta Chi

```text
NESSUNO BLOCCA NESSUNO per i task iniziali — tutti possono partire subito!

  Renan Task 1-7 ──────────────────────────────────┐
  (gameplay fix, indipendenti)                      │
                                                    │
  Cristian Task 3-5 ────────────────────────────────┤
  (Logger + PerformanceManager, indipendenti)       │
                                                    ├──► Cristian Task 6 (documentazione)
  Cristian Task 7-8 ────────────────────────────────┤    Farlo SOLO quando tutti
  (asset personaggio, indipendente)                 │    hanno finito i loro task
                                                    │
  Elia Task 1-5 ────────────────────────────────────┤
  (fix database, indipendenti)                      │
                                                    │
  Elia Task 6 (Supabase setup) ─────────────────────┘
       │
       └──► Consegna URL + anon key a Renan
            └──► Renan implementa client GDScript (fase futura)
```

**Unica dipendenza vera**: Cristian NON deve fare il Task 6 (documentazione) finche'
gli altri non hanno finito. Tutto il resto si fa in parallelo.

**Attenzione ai conflitti Git**: Renan e Elia modificano entrambi `local_database.gd`
e `auth_manager.gd`. Coordinarsi per non lavorare sullo stesso file contemporaneamente:
- **Consiglio**: Elia fa prima i suoi Task 2-5 (database), poi Renan lavora su quei file se serve

---

## Guide Personali

| Guida | Per Chi | Contenuto | Task Rimasti |
|-------|---------|-----------|:------------:|
| [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md) | **Renan** | ~~Bug fix gameplay, `_exit_tree()` x8, popup decorazioni, tween fix, viewport clamp~~ | **0 — TUTTI 18 COMPLETATI** |
| [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md) | **Cristian** | ~~Logger fix, PerformanceManager, CI 5 job~~, **nuovo personaggio**, asset grafici, documentazione | 3 |
| [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md) | **Elia** | ~~ROLLBACK, _save_inventory, is_open(), create_account~~, **setup Supabase** | 1 |

## Relazione con l'Audit Report

Queste guide sono la versione operativa (il "come fare") del documento [AUDIT_REPORT.md](../AUDIT_REPORT.md) (il "cosa fare e perche'"). Se avete dubbi sul *perche'* di una correzione, consultate la sezione dell'audit report indicata all'inizio di ogni task.

---

## Timeline del Progetto — Scadenza: 22 Aprile 2026

**Obiettivo**: il gioco deve **funzionare** e **essere presentabile** entro il 22 aprile.
Non deve essere perfetto — deve essere stabile, senza crash, e con le funzionalita' core operative.

| Periodo | Obiettivo | Chi | Ore |
|---------|-----------|-----|:---:|
| **31 Mar - 6 Apr** | Setup ambiente + task CRITICI (typo sprite, costanti, ROLLBACK DB) | Tutti | 3-4h |
| **7 Apr - 13 Apr** | Correzioni core (array mismatch, race condition, Logger, auth_manager) | Tutti | 3-4h |
| **14 Apr - 18 Apr** | `_exit_tree()` x7, nuovo personaggio (Cristian), Supabase setup (Elia) | Tutti | 4-6h |
| **19 Apr - 22 Apr** | Test finale, fix urgenti, documentazione (Cristian Task 6), presentazione | Tutti | 2-3h |

**Totale stimato per persona**: ~12-18 ore distribuite su ~3.5 settimane.
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

ASSET (Cristian)
- [x] Asset integrati: joystick, loading screen, bottoni, letti, mobili, piante (GIA' FATTO)
- [ ] Nuovo personaggio pixel art trovato/creato e sostituito (Task 7 Cristian)
- [ ] Asset grafici aggiuntivi trovati (Task 8 Cristian)

CLOUD (Elia → Renan)
- [ ] Supabase: progetto creato con 3 tabelle + RLS (Task 6 Elia)
- [ ] URL e anon key consegnati a Renan
- [ ] Client GDScript implementato da Renan (fase futura)

PIPELINE CI/CD (Cristian)
- [x] CI attiva su branch main (GIA' FATTO)
- [x] gdlint + gdformat controllano v1/scripts/ e v1/tests/ (GIA' FATTO)

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

*Queste guide fanno parte del progetto Mini Cozy Room — Audit Pre-Rilascio.*
*Scadenza progetto: 22 Aprile 2026.*
*Ultimo aggiornamento: 31 Marzo 2026*
