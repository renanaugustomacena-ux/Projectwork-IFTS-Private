# Guide Operative per il Team — Mini Cozy Room

> **⚠️ Nota Importante: Semplificazione in Corso**
> Il codebase contiene sistemi avanzati (SupabaseClient, LocalDatabase, SaveManager, Logger)
> che sono **placeholder** o **over-engineered** rispetto alle necessita' del gioco.
> Funzionano correttamente, ma sono piu' complessi del necessario.
> Le correzioni proposte nelle guide restano valide sia come esercizio che come miglioramento,
> ma sappiate che alcuni di questi sistemi potrebbero essere semplificati o sostituiti in futuro.
> Per la lista completa dei sistemi e il loro stato, consultate il [README principale](../../README.md#stato-dei-sistemi).

Questa cartella contiene le guide operative personalizzate per ogni membro del team.
Ogni guida e' pensata per essere seguita dall'inizio alla fine, passo dopo passo.

## Da Dove Iniziare

**Tutti** devono leggere per prima cosa la guida di setup dell'ambiente:

1. [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) — Installazione di Godot, Git, VS Code e configurazione del progetto

Dopo aver completato il setup, aprite la vostra guida personale:

## Guide Personali

| Guida | Per Chi | Contenuto |
|-------|---------|-----------|
| [GUIDA_CRISTIAN_CICD.md](GUIDA_CRISTIAN_CICD.md) | **Cristian Marino** | Pipeline CI/CD, linting test, Logger, PerformanceManager, configurazione test |
| [GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md](GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md) | **Mohamed & Giovanni** | Correzione characters.json, aggiunta `_exit_tree()` a 12 script, fix UI panels, tracks.json |
| [GUIDA_ELIA_DATABASE.md](GUIDA_ELIA_DATABASE.md) | **Elia Zoccatelli** | Ridisegno schema database, foreign keys, seed data, allineamento Supabase |

## Relazione con l'Audit Report

Queste guide sono la versione operativa (il "come fare") del documento [AUDIT_REPORT.md](../AUDIT_REPORT.md) (il "cosa fare e perche'"). L'audit report contiene l'analisi completa di tutti i problemi trovati; le guide qui presenti vi dicono esattamente come risolverli, passo dopo passo.

Se avete dubbi sul *perche'* di una correzione, consultate la sezione dell'audit report indicata all'inizio di ogni task.

## Mappa delle Dipendenze tra Task

Non tutti i task possono essere iniziati contemporaneamente. Alcuni task **bloccano** altri.
Seguite questo ordine per evitare conflitti e lavoro inutile:

```text
SETTIMANA 1 — Fondamenta (tutti lavorano in parallelo)
│
├── Cristian: Task 1-2 (CI branch + lint test)     ← SUBITO, sblocca validazione push
├── Elia: Task 1-3 (schema DB characters + inventario + FK)  ← SUBITO, sblocca test DB
└── Mohamed/Giovanni: Task 1-2 (typo sprite + costanti)      ← SUBITO, sblocca gameplay test
│
SETTIMANA 2 — Correzioni Core
│
├── Mohamed/Giovanni: Task 3-5 (array mismatch, race condition, texture cast)
├── Cristian: Task 3-4 (Logger session ID + buffer)
└── Elia: Task 4-5 (seed data + errori DB)
│
SETTIMANA 3 — Pulizia e Lifecycle
│
├── Mohamed/Giovanni: Task 6-7 (_exit_tree per 6 script + null check)  ← il task piu' grande
├── Cristian: Task 5 (_exit_tree PerformanceManager)
└── Elia: Task 6 (allineamento Supabase — opzionale)
│
SETTIMANA 4 — Integrazione e Verifica
│
├── Cristian: Task 6-7 (configurare test CI + documentazione)  ← DIPENDE dai test degli altri
└── TUTTI: Test manuale completo, verifica profiler, revisione finale
```

**Dipendenze critiche**:

- Cristian Task 6 (test nella CI) → dipende dai file test creati da Mohamed/Giovanni/Elia
- Mohamed/Giovanni Task 6 (_exit_tree) → puo' iniziare solo dopo aver capito i segnali (Task 3-5)
- Elia Task 3 (FK item_id) → dipende da Elia Task 2 (ristrutturazione inventario)

---

## Protocollo di Comunicazione — Cosa Fare se Sei Bloccato

| Tipo di Blocco | Chi Contattare | Come |
|----------------|----------------|------|
| Non riesco a configurare l'ambiente | Renan | Messaggio nel gruppo Teams/WhatsApp con screenshot dell'errore |
| Conflitto Git (merge conflict) | Renan o Cristian | Messaggio + output di `git status` e `git diff` |
| Godot non apre la scena / crash | Mohamed o Giovanni | Messaggio + pannello Output di Godot (screenshot) |
| Dubbio su schema database / SQL | Elia o Renan | Messaggio con la query che non funziona + errore |
| Non capisco cosa devo fare in un task | Renan | Messaggio citando il numero del task e la riga che non capite |
| Ho rotto qualcosa e non so come annullare | **Renan SUBITO** | NON fate `git reset --hard`. Chiedete prima |

**Regola d'oro**: meglio chiedere e aspettare 10 minuti che fare un pasticcio che richiede 2 ore per essere corretto.

**Tempo di risposta atteso**: durante l'orario di lavoro, entro 30 minuti. Se urgente, chiamata diretta.

---

## Timeline del Progetto — Scadenza: 22 Aprile 2026

**Obiettivo**: il gioco deve **funzionare** e **essere presentabile** entro il 22 aprile.
Non deve essere perfetto — deve essere stabile, senza crash, e con le funzionalita' core operative.

| Periodo | Obiettivo | Chi | Ore Stimate |
| ------- | --------- | --- | ----------- |
| **28 Mar - 4 Apr** | Setup ambiente + task CRITICI (CI, schema DB, typo sprite) | Tutti | 4-6h ciascuno |
| **5 Apr - 11 Apr** | Correzioni core (array, race condition, Logger, seed data) | Tutti | 3-4h ciascuno |
| **12 Apr - 18 Apr** | Pulizia lifecycle (_exit_tree), null check, test manuale | Tutti | 3-5h ciascuno |
| **19 Apr - 22 Apr** | Test finale, fix urgenti, documentazione, preparazione presentazione | Tutti | 2-3h ciascuno |

**Totale stimato per persona**: ~12-18 ore distribuite su ~4 settimane.

**Priorita' assoluta**: concentratevi sui task CRITICI e ALTI. I task MEDI e BASSI sono bonus se avanzate tempo.

---

## Checklist di Validazione Finale (per TUTTO il team)

Quando tutti i task sono completati, verificate **insieme** che tutto funzioni:

```text
INTEGRITA' DATI (Elia + Mohamed/Giovanni)
- [ ] characters.json: nessun typo nei percorsi sprite
- [ ] constants.gd: solo costanti per personaggi esistenti
- [ ] Database: schema characters con character_id PRIMARY KEY
- [ ] Database: schema inventario senza coins/capacita duplicati
- [ ] Database: foreign keys attive e funzionanti
- [ ] Database: seed data presente (14 categorie, 10 colori, 1 account)

STABILITA' E LIFECYCLE (Mohamed/Giovanni + Cristian)
- [ ] _exit_tree() presente in tutti e 7 gli script indicati
- [ ] Nessun memory leak (Profiler stabile dopo 10 cicli menu->stanza->menu)
- [ ] Nessun crash dopo 5 minuti di gioco continuo
- [ ] Race condition swap personaggio risolto
- [ ] Null check su AnimatedSprite2D e Texture2D

PIPELINE CI/CD (Cristian)
- [ ] CI attiva su branch Renan (non piu' proto)
- [ ] gdlint + gdformat controllano anche v1/tests/
- [ ] Tutti i test passano nella pipeline (verde su GitHub Actions)
- [ ] Logger: session ID univoci, buffer non perso

GIOCO FUNZIONANTE (TUTTI)
- [ ] Menu principale: si carica senza errori
- [ ] Stanza: personaggio si muove con animazioni corrette
- [ ] Decorazioni: drag-and-drop funziona, snap a griglia
- [ ] Sfondo foresta: parallax scrolling fluido (8 layer)
- [ ] Salvataggio/caricamento: funziona senza perdita dati
- [ ] Pannello Output: ZERO errori rossi durante gameplay completo
```

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
*Ultimo aggiornamento: 27 Marzo 2026*
