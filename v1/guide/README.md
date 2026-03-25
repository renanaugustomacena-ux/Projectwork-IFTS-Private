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

## Convenzioni Usate nelle Guide

- **Percorsi file**: sempre relativi alla cartella `v1/` del progetto
- **Codice**: ogni riga non ovvia ha un commento in italiano che spiega cosa fa
- **Prima/Dopo**: per ogni correzione, viene mostrato il codice problematico e poi il codice corretto
- **Come Verificare**: alla fine di ogni task, una lista di passi per verificare che la correzione funzioni
- **Cosa Puo' Andare Storto**: errori comuni e come risolverli
- **Tempo stimato**: ogni task ha una stima del tempo necessario

---

*Queste guide fanno parte del progetto Mini Cozy Room — Audit Pre-Rilascio.*
*Ultimo aggiornamento: 21 Marzo 2026*
