# Speech Esteso — Relax Room

**Target**: ~800 parole, 6-8 minuti di lettura, tono professionale-caldo.
**Uso**: approfondimento per domande, oppure introduzione esteso prima della demo.

---

## 1. Genesi dell'idea (~120 parole)

Relax Room nasce da una domanda semplice: *perche ogni software che usiamo sembra chiederci qualcosa?* Notifiche, badge, timer, streak. Ogni app e costruita per **vincere la lotta per la nostra attenzione**. In quel rumore abbiamo voluto costruire il contrario: un **ambiente**, non un gioco. Un luogo che vive sullo sfondo della giornata, che non chiede nulla, che non ti fa sentire in colpa se lo chiudi. Abbiamo pensato a chi studia con dieci tab aperte, a chi lavora da casa e vuole un angolo personale nel proprio desktop, a chi semplicemente ha bisogno di un posto tranquillo dove tornare. Da qui il concetto di **desktop companion**: un'app che sta li, che puoi decorare, in cui c'e un gattino che dorme, in cui la musica suona piano.

## 2. Scelte architetturali (~200 parole)

Ogni decisione tecnica l'abbiamo presa con una domanda fissa: *come manteniamo questo software vivo a sei, dodici, ventiquattro mesi?*

- **SignalBus come cuore**: **46 segnali tipizzati**, event bus centralizzato. Nessun manager conosce gli altri. L'accoppiamento è il primo nemico della manutenibilità. Oggi `decoration_placed` fa scattare tre listener; domani cinque, senza toccare codice esistente.

- **Offline-first come valore**: l'utente non deve dipendere dal nostro server per rilassarsi. Tutto gira localmente. Il cloud è un **bonus** (sync multi-PC), mai dipendenza. Priorità: scrivi in locale **sempre**, accoda al cloud, flush al reconnect.

- **Doppio DB SQLite + Supabase**: SQLite con WAL ci dà **robustezza su disco**; Supabase con **Row-Level Security** ci dà **scalabilità futura senza rifare il backend**. Le **migrazioni v1→v5** sono idempotenti con backup pre-DROP.

- **HMAC-SHA256 sui salvataggi**: integrità senza cloud obbligatorio. Se qualcuno modifica `save_data.json` a mano, il gioco lo rileva e carica il backup. Scrittura atomica (temp → rename) = zero corruzione su crash.

## 3. Metodologia di lavoro (~180 parole)

Non abbiamo improvvisato. Il progetto ha seguito tre principi operativi:

- **Audit-driven development**: **tre passaggi di audit sistematico** sul codice. Ogni bug classificato per severità (critico/alto/medio) e risolto per priorità — non per chi lo trovava. Deep read integrale di **84 file / ~25k righe** prima dello sprint finale.

- **CI come cancello obbligatorio**: **9 job paralleli** (lint GDScript, JSON, sprite paths, cross-reference, schema DB, signal count, pixel-art deliverables, smoke headless, 112 deep test). Nessun codice sul `main` senza **tutti e 9 green**. Questo ha eliminato intere classi di bug prima della review.

- **Runbook per ruolo**: **4 guide operative** (Renan runtime/UI, Elia database, Cristian CI/asset, Alex pixel art 1148 righe). Ognuna documenta cosa fare, come, dove. Obiettivo: **chiunque entra nel progetto domani deve poter lavorare senza chiederci nulla**. Commit semantici (feat/fix/chore/docs) — la cronologia del repo si legge come una storia, non come un disastro.

## 4. Team e ruoli (~100 parole)

Tre persone, **tre ruoli complementari**, interfacce nette.

- **Renan** — architettura, sistemi core, runtime. Scrive il signal bus, il save manager, l'auth, la sincronizzazione.
- **Elia** — tutto cio che tocca i dati. Schema SQLite, schema Supabase, RLS policies, migrazioni, sync queue semantics.
- **Cristian** — tutto cio che entra nel gioco e tutto cio che ne esce. Asset pixel art, pipeline CI/CD, build Windows + Web.

Le interfacce tra noi non sono riunioni: sono **segnali** nel SignalBus e **schemi** nel database. Questo ci ha permesso di lavorare in parallelo, quasi senza blocchi reciproci.

## 5. Manutenzione futura (~130 parole)

Un progetto si giudica anche dopo la consegna. Abbiamo preparato il terreno:

- **10 tabelle cloud già predisposte** per feature future: `friends`, `room_visits`, `chat_messages`, `pomodoro_sessions`, `journal_entries`, `mood_entries`, `memos`, `outfits_cloud`, `notifications`, `audit_log`. Nessuna migrazione al lancio.
- **Architettura estensibile by design**: aggiungere una feature = un listener in più su un segnale esistente o un nuovo segnale. **Mai rompere** codice che già funziona.
- **Documentazione operativa** in `v1/docs/` + `v1/guide/` + `v1/study/`: 4 guide + report consolidato 3195 righe + registry numerico post deep-read. Nuovo membro: legge, capisce, contribuisce senza onboarding.
- **AppLogger strutturato**: l'utente ci manda un `.jsonl` e noi ricostruiamo il flusso completo dalla prima riga — anche senza accesso al suo PC.

## 6. Chiusura (~40 parole)

> *"Il software si giudica anche da quanto e facile tenerlo vivo."*

Relax Room e **pronto per essere usato oggi** e **pronto per crescere domani**, senza che qualcuno debba riaprire un nodo architetturale. Questo, per noi, e il risultato.

**Grazie.**
