# Guide Operative per il Team — Mini Cozy Room

> **Aggiornamento 31 Marzo 2026**:
> - **Team**: 3 membri — Renan (Gameplay/UI/Architect), Cristian (CI/CD + Asset), Elia (Database + Supabase)
> - **Supabase**: reintrodotto come servizio cloud. Elia prepara il progetto, Renan implementa il client
> - **CI/CD**: branch `main`, job lint unico (gdlint + gdformat). Task 1-2 di Cristian GIA' FATTI
> - **Asset**: tutti integrati in v1/ (Tasks 8-11 di Renan GIA' FATTI). README creati per ogni sottocartella
> - **Schema DB**: C3/C4 completati (27 Mar). Restano 4 fix per Elia (A24-A27)
> - **Branch**: si lavora SOLO su `main`

---

## PRIMA DI TUTTO — Cosa Fare Adesso

**Tutti**: leggere [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare Godot 4.5.2+, Git, VS Code.

Poi aprite la vostra guida e seguite i task nell'ordine indicato qui sotto.

### Renan — Gameplay, UI & Asset

| Ordine | Task | Cosa Fare | Tempo | File |
|:------:|------|-----------|-------|------|
| 1 | Task 1 | Correggere typo `sxt` → `sx` in characters.json | 5 min | `data/characters.json` |
| 2 | Task 2 | Rimuovere 3 costanti personaggi inutilizzati | 10 min | `scripts/utils/constants.gd` |
| 3 | Task 3 | Correggere array mismatch in window_background.gd | 20 min | `scripts/rooms/window_background.gd` |
| 4 | Task 4 | Race condition swap personaggio → `call_deferred` | 15 min | `scripts/rooms/room_base.gd` |
| 5 | Task 5 | Null check su caricamento texture in drop_zone.gd | 15 min | `scripts/ui/drop_zone.gd` |
| 6 | Task 6 | Aggiungere `_exit_tree()` a 6 script (il piu' lungo) | 1.5 ore | 6 file diversi |
| 7 | Task 7 | Null check su `_anim` in character_controller.gd | 15 min | `scripts/rooms/character_controller.gd` |
| — | Task 8-11 | ~~Integrazione asset~~ | — | **GIA' FATTO** |
| 8 | Task 12-13 | Popup decorazioni + persistenza rotazione/scala | 1 ora | `scripts/rooms/decoration_system.gd` |

**Puoi iniziare subito**: nessuna dipendenza da Cristian o Elia.
**Guida**: [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md)

### Cristian — CI/CD, Logger & Asset

| Ordine | Task | Cosa Fare | Tempo | File |
|:------:|------|-----------|-------|------|
| — | Task 1-2 | ~~CI branch + lint test~~ | — | **GIA' FATTO** |
| 1 | Task 3 | Logger: session ID con `Crypto` (anti-collisione) | 30 min | `scripts/autoload/logger.gd` |
| 2 | Task 4 | Logger: buffer mantiene ultimi 100 msg se file non disponibile | 20 min | `scripts/autoload/logger.gd` |
| 3 | Task 5 | `_exit_tree()` al PerformanceManager (3 segnali) | 20 min | `scripts/systems/performance_manager.gd` |
| 4 | **Task 7** | **Trovare/creare nuovo personaggio pixel art** (8 direzioni, 32x32) | 2-3 ore | `assets/charachters/male/old/` |
| 5 | Task 8 | Trovare asset grafici aggiuntivi (loading screen, decorazioni, icone) | 1-2 ore | `assets/` |
| 6 | Task 6 | Aggiornare documentazione (DOPO che tutti finiscono) | 1 ora | Vari README |

**Puoi iniziare subito** con Task 3-5 e **Task 7** (indipendenti).
**Task 6** (documentazione): farlo **per ultimo**, dopo che Renan e Elia hanno finito.
**Guida**: [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md)
**Riferimento asset personaggio**: [`assets/charachters/README.md`](../assets/charachters/README.md)

### Elia — Database & Supabase

| Ordine | Task | Cosa Fare | Tempo | File |
|:------:|------|-----------|-------|------|
| 1 | Task 1 | Studiare le correzioni gia' fatte da Renan (C3/C4/C1/A17/A18) | 20 min | `scripts/autoload/local_database.gd` |
| 2 | Task 2 | A24: Aggiungere ROLLBACK alle transazioni | 15 min | `scripts/autoload/local_database.gd` |
| 3 | Task 3 | A25: `_save_inventory()` ritorna `bool` | 10 min | `scripts/autoload/local_database.gd` |
| 4 | Task 4 | A26: Check `is_open()` in `_set_state()` | 5 min | `scripts/autoload/auth_manager.gd` |
| 5 | Task 5 | A27: Validare `create_account()` in `register()` | 5 min | `scripts/autoload/auth_manager.gd` |
| 6 | **Task 6** | **Supabase**: creare progetto, 3 tabelle, RLS | 1.5 ore | Dashboard Supabase |

**Puoi iniziare subito**: nessuna dipendenza da Renan o Cristian.
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
| [GUIDA_RENAN_GAMEPLAY_UI.md](GUIDA_RENAN_GAMEPLAY_UI.md) | **Renan** | Bug fix gameplay, `_exit_tree()` x6, popup decorazioni | 9 |
| [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md) | **Cristian** | Logger fix, PerformanceManager, **nuovo personaggio**, asset grafici | 6 |
| [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md) | **Elia** | ROLLBACK transazioni, fix auth_manager, **setup Supabase** | 6 |

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
- [ ] characters.json: nessun typo nei percorsi sprite (Task 1 Renan)
- [ ] constants.gd: solo costanti per personaggi esistenti (Task 2 Renan)
- [x] Database: schema characters con character_id PRIMARY KEY (GIA' FATTO 27 Mar)
- [x] Database: schema inventario normalizzato (GIA' FATTO 27 Mar)
- [ ] Database: transazioni con ROLLBACK su errore (Task 2 Elia)
- [ ] Database: _save_inventory() propaga errori (Task 3 Elia)
- [ ] Database: is_open() check prima di query (Task 4 Elia)
- [ ] Database: create_account() validato in register() (Task 5 Elia)

STABILITA' E LIFECYCLE (Renan + Cristian)
- [ ] _exit_tree() presente in tutti e 7 gli script (Task 5 Cristian + Task 6 Renan)
- [ ] Nessun memory leak (Profiler stabile dopo 10 cicli menu->stanza->menu)
- [ ] Race condition swap personaggio risolto con call_deferred (Task 4 Renan)
- [ ] Null check su AnimatedSprite2D e Texture2D (Task 5+7 Renan)
- [ ] Logger: session ID con Crypto (Task 3 Cristian)
- [ ] Logger: buffer non perso se file non disponibile (Task 4 Cristian)

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
