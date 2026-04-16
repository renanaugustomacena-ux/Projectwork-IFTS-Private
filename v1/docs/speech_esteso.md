# Speech Esteso — Relax Room

**Target**: ~800 parole, 6-8 minuti di lettura, tono professionale-caldo.
**Uso**: approfondimento per domande, oppure introduzione esteso prima della demo.

---

## 1. Genesi dell'idea (~120 parole)

Relax Room nasce da una domanda semplice: *perche ogni software che usiamo sembra chiederci qualcosa?* Notifiche, badge, timer, streak. Ogni app e costruita per **vincere la lotta per la nostra attenzione**. In quel rumore abbiamo voluto costruire il contrario: un **ambiente**, non un gioco. Un luogo che vive sullo sfondo della giornata, che non chiede nulla, che non ti fa sentire in colpa se lo chiudi. Abbiamo pensato a chi studia con dieci tab aperte, a chi lavora da casa e vuole un angolo personale nel proprio desktop, a chi semplicemente ha bisogno di un posto tranquillo dove tornare. Da qui il concetto di **desktop companion**: un'app che sta li, che puoi decorare, in cui c'e un gattino che dorme, in cui la musica suona piano.

## 2. Scelte architetturali (~210 parole)

Ogni decisione tecnica l'abbiamo presa con una domanda fissa: *come manteniamo questo software vivo a sei, dodici, ventiquattro mesi?*

- **SignalBus come cuore**: **43 segnali tipizzati**, un event bus centralizzato. Nessun manager conosce gli altri. Questo perche — in un progetto di team — l'accoppiamento e il primo nemico della manutenibilita. Oggi `decoration_placed` fa scattare tre listener; domani ne fara cinque, senza toccare nessun `if` nel codice esistente.

- **Offline-first come valore**: l'utente non deve dipendere da un nostro server per rilassarsi. Tutto gira localmente. Il cloud e un **bonus** (sync multi-PC), mai una dipendenza. Questa scelta ha cambiato l'ordine di priorita: prima scrivi in locale, **sempre**; poi accoda al cloud; poi prova a flushare quando torna la rete.

- **Doppio DB SQLite + Supabase**: SQLite con WAL mode ci da **robustezza su disco**; Supabase con **Row-Level Security** ci da **scalabilita futura senza rifare il backend**. Le **migrazioni v1.0→v5.0** sono idempotenti: riparte ogni volta, nessun crash.

- **HMAC-SHA256 sui salvataggi**: integrita senza cloud obbligatorio. Anche se qualcuno modifica `save_data.json` a mano, il gioco lo rileva. Scrittura atomica (temp → rename) = zero corruzione su crash.

## 3. Metodologia di lavoro (~190 parole)

Non abbiamo improvvisato. Il progetto ha seguito tre principi operativi:

- **Audit-driven development**: **tre passaggi di audit sistematico** sul codice. Ogni bug trovato e classificato per severita (critico, alto, medio) e risolto per priorita — non per chi lo trovava o chi aveva piu voglia.

- **CI come cancello obbligatorio**: **5 job paralleli** (lint GDScript, JSON validation, sprite paths, cross-reference costanti, schema DB). Nessun codice finisce sul branch `main` senza **tutti i 5 green**. Questo ha eliminato intere classi di bug prima ancora che arrivassero in review.

- **Runbook per ruolo**: abbiamo scritto **tre guide operative** (`GUIDE_RENAN_SUPERVISOR.md`, `GUIDE_ELIA_DATABASE.md`, `GUIDE_CRISTIAN_ASSETS_CICD.md`). Ognuna documenta cosa fare, come farlo, dove sta la cosa. L'obiettivo: **chiunque entra nel progetto domani deve poter lavorare senza chiederci nulla**. **118 commit semantici** (feat/fix/chore/docs) completano il quadro — la cronologia del repo si legge come una storia, non come un disastro.

## 4. Team e ruoli (~100 parole)

Tre persone, **tre ruoli complementari**, interfacce nette.

- **Renan** — architettura, sistemi core, runtime. Scrive il signal bus, il save manager, l'auth, la sincronizzazione.
- **Elia** — tutto cio che tocca i dati. Schema SQLite, schema Supabase, RLS policies, migrazioni, sync queue semantics.
- **Cristian** — tutto cio che entra nel gioco e tutto cio che ne esce. Asset pixel art, pipeline CI/CD, build Windows + Web.

Le interfacce tra noi non sono riunioni: sono **segnali** nel SignalBus e **schemi** nel database. Questo ci ha permesso di lavorare in parallelo, quasi senza blocchi reciproci.

## 5. Manutenzione futura (~140 parole)

Un progetto si giudica anche dopo la consegna. Abbiamo preparato il terreno:

- **9 tabelle cloud gia predisposte** per feature future: `friends`, `room_visits`, `chat_messages`, `pomodoro_sessions`, `journal_entries`, `mood_entries`, `memos`, `outfits_cloud`, `notifications`. Nessuna migrazione al lancio di una nuova funzione.
- **Architettura estensibile by design**: aggiungere una feature = aggiungere un listener a un segnale esistente, oppure dichiarare un nuovo segnale. **Mai rompere** codice che gia funziona.
- **Documentazione operativa** in `v1/docs/`: tre guide + un report consolidato del progetto. Un nuovo membro del team puo leggere, capire, contribuire — senza sessioni di onboarding.
- **AppLogger strutturato**: se qualcosa si rompe in produzione, l'utente ci manda un `.jsonl` e noi, **anche senza accesso al suo PC**, ricostruiamo il flusso completo dall'inizio della sessione.

## 6. Chiusura (~40 parole)

> *"Il software si giudica anche da quanto e facile tenerlo vivo."*

Relax Room e **pronto per essere usato oggi** e **pronto per crescere domani**, senza che qualcuno debba riaprire un nodo architetturale. Questo, per noi, e il risultato.

**Grazie.**
