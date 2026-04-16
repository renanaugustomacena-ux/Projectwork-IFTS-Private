# Relax Room — Presentazione Progetto

**Progetto ITS — Anno 2025/2026**
**Data presentazione**: 22 Aprile 2026

---

## Slide 1 — Copertina

**Relax Room**

*Il tuo compagno desktop per il relax e la produttivita consapevole*

Progetto ITS — Anno 2025/2026

Renan Augusto Macena | Elia Zoccatelli | Cristian Marino

---

## Slide 2 — Il Team

### Chi siamo

**Renan Augusto Macena** — Team Lead e Architetto Software
Progettazione dell'architettura signal-driven, sviluppo dei sistemi core
(SaveManager, AuthManager, GameManager, SupabaseClient), coordinamento
del team e gestione del repository Git.

**Elia Zoccatelli** — Database Engineer
Progettazione dello schema dati locale (SQLite, 9 tabelle) e cloud
(Supabase PostgreSQL, 15 tabelle con Row-Level Security). Modellazione
relazionale, politiche di sicurezza per-utente, migrazioni automatiche.

**Cristian Marino** — Asset Pipeline e CI/CD
Creazione degli asset pixel art (personaggi, decorazioni, sfondi),
configurazione della pipeline di integrazione continua a 5 job paralleli,
gestione dei build automatizzati per Windows e Web.

*Tre ruoli complementari, un obiettivo comune.*

---

## Slide 3 — Il Progetto

### Cos'e Relax Room?

Un'applicazione desktop che trasforma il tuo PC in uno spazio
accogliente e personalizzabile.

- Stanza pixel art decorabile con **69 decorazioni** in 11 categorie
- **Musica lo-fi** integrata con crossfade e ambience naturale
- **3 personaggi** selezionabili con animazioni a 8 direzioni
- **Pet virtuale** (gattino) con comportamento autonomo: idle, walk, sleep
- Strumenti organizzativi per la **produttivita consapevole**
- Funziona **completamente offline** — nessuna dipendenza da internet

*Non e un gioco. E un ambiente. Un luogo dove tornare quando hai
bisogno di un momento di calma.*

---

## Slide 4 — Filosofia di Design

### Quattro principi fondamentali

**1. Community, non Competizione**
Nessun punteggio o classifica. Il focus e sulla creativita
personale e sull'espressione di se.

**2. Tutto Sbloccato**
Nessun grind, nessun paywall. Tutti i contenuti sono
disponibili fin dal primo avvio.

**3. Zero Pressione**
Nessuna notifica, nessun timer, nessun sistema energetico.
Gioca quando vuoi, chiudi senza sensi di colpa.

**4. Presenza senza Invasione**
Il gioco esiste sullo sfondo della tua giornata,
non per dominarla.

---

## Slide 5 — Perche Relax Room?

### L'intenzione dietro il progetto

Nel mondo digitale moderno, ogni applicazione compete per la tua
attenzione. Relax Room fa il contrario: crea uno spazio che
ti aiuta a concentrarti e rilassarti.

**A chi e destinato:**
- Studenti che cercano un ambiente di studio tranquillo
- Lavoratori da remoto che vogliono personalizzare il proprio spazio digitale
- Creativi che hanno bisogno di un angolo di ispirazione

**Cosa lo rende diverso:**
- Funziona offline — nessun account obbligatorio
- Leggero — consuma poche risorse, gira in background a 15 FPS
- Personalizzabile — la tua stanza, la tua musica, il tuo ritmo
- I tuoi dati restano sul tuo PC, protetti da crittografia HMAC

*"Il software piu utile e quello che ti fa stare bene senza chiederti
nulla in cambio."*

---

## Slide 6 — Architettura Tecnica

### Come e costruito

| Tecnologia | Ruolo |
|---|---|
| **Godot 4.6** | Motore di gioco (GDScript, 31 script) |
| **SQLite 3** | Database locale offline-first (WAL mode) |
| **Supabase** | Backend cloud (PostgreSQL + Auth + REST API) |
| **GitHub Actions** | CI/CD pipeline a 5 job paralleli |
| **HMAC-SHA256** | Protezione integrita dei salvataggi |

### Architettura a segnali

**31 segnali** dichiarati nel SignalBus per comunicazione completamente
disaccoppiata tra sistemi. Nessun sistema conosce direttamente gli altri —
comunicano solo tramite eventi. Questo rende il codice modulare,
testabile e facile da estendere.

### 9 Autoload Singleton orchestrati

SignalBus → AppLogger → LocalDatabase → AuthManager → GameManager →
SaveManager → SupabaseClient → AudioManager → PerformanceManager

Caricati in ordine preciso per rispettare le dipendenze tra sistemi.

---

## Slide 7 — Persistenza dei Dati

### Tre livelli di protezione

**1. JSON con HMAC**
Salvataggio primario in `save_data.json` con firma crittografica
SHA-256 per rilevare manomissioni. Backup automatico prima di ogni
scrittura. Scrittura atomica (file temporaneo → rinomina) per
resistenza ai crash.

**2. SQLite con WAL**
Database relazionale locale con 9 tabelle, chiavi esterne con CASCADE,
indici sulle foreign key, migrazioni automatiche dalla versione 1.0
alla 5.0. Write-Ahead Logging per operazioni concorrenti sicure.

**3. Supabase Cloud**
Sincronizzazione offline-first con coda di operazioni pendenti.
I dati locali hanno sempre priorita. La coda si svuota automaticamente
quando la connessione torna disponibile. 15 tabelle cloud con
Row-Level Security: ogni utente vede solo i propri dati.

*I dati dell'utente non si perdono mai.*

---

## Slide 8 — Processo di Sviluppo

### Come abbiamo lavorato

**Sviluppo audit-driven:**
3 passaggi di audit sistematico che hanno guidato ogni ciclo di
fix e refactoring. Ogni bug trovato e stato classificato per severita
(critico, alto, medio) e risolto in ordine di priorita.

**Continuous Integration:**
Pipeline CI/CD a 5 job paralleli su GitHub Actions:
1. GDScript Lint e Format (gdtoolkit)
2. Validazione JSON dei cataloghi
3. Verifica percorsi sprite
4. Cross-reference costanti vs cataloghi
5. Validazione schema database

Ogni push viene validato automaticamente. Nessun codice raggiunge
il branch principale senza superare tutti i controlli.

**Gestione del Repository:**
- 118 commit strutturati con messaggi semantici (feat/fix/chore/docs)
- Sprint iterativi con task tracciati
- Sviluppo collaborativo su branch main con CI obbligatoria
- Documentazione completa: guide operative per ogni membro del team

---

## Slide 9 — Il Gioco in Cifre

### Relax Room in numeri

| Metrica | Valore |
|---|---|
| Commit nel repository | **118** |
| Script GDScript | **31** |
| Segnali nel SignalBus | **31** |
| Decorazioni disponibili | **69** (11 categorie) |
| Personaggi giocabili | **3** |
| Tracce musicali lo-fi | **2** |
| Tabelle SQLite locali | **9** |
| Tabelle Supabase cloud | **15** |
| Job CI/CD paralleli | **5** |
| Versioni save-data migrate | **5** (v1.0 → v5.0) |
| Passaggi di audit | **3** |
| Righe di codice GDScript | **~5.300** |

---

## Slide 10 — Funzionalita Principali

### Decorazione drag-and-drop
69 decorazioni trascinabili nella stanza. Rotazione (90 gradi),
ribaltamento, ridimensionamento (0.25x → 3x), eliminazione.
Salvataggio persistente della posizione di ogni oggetto.

### Personaggio animato
3 personaggi con sprite 32x32 e animazioni a 8 direzioni
(idle, walk, interact, rotate). Movimento fluido con WASD o frecce.

### Pet virtuale
Gattino autonomo con macchina a stati: idle, wander, follow, sleep, play.
Animazioni dedicate per ogni stato, effetto respirazione durante il sonno.

### Audio lo-fi
2 tracce ambient con crossfade automatico. 3 modalita playlist:
sequenziale, shuffle, ripeti. Volumi indipendenti per musica e ambience.

### Tutorial interattivo
Missione guidata in 9 passi che insegna tutte le meccaniche del gioco.
Avanzamento basato su segnali: il tutorial aspetta che il giocatore
completi l'azione prima di procedere.

---

## Slide 11 — Miglioramenti Futuri

### Dove puo andare Relax Room

L'architettura e stata progettata per crescere. Il database cloud ha
gia **15 tabelle**: 6 sono in uso attivo, **9 sono pronte** per le
funzionalita future.

**Sincronizzazione cloud completa**
Accedi alla tua stanza da qualsiasi PC tramite Supabase Auth.

**Sistema amicizie e visite**
Visita le stanze dei tuoi amici in tempo reale.
*(Tabelle `friends` e `room_visits` gia predisposte nel database)*

**Chat integrata**
Messaggi tra utenti durante le visite.
*(Tabella `chat_messages` pronta)*

**Pomodoro Timer**
Sessioni di studio con tracking e statistiche.
*(Tabella `pomodoro_sessions` pronta)*

**Diario dell'umore**
Traccia il tuo umore nel tempo con grafici e riflessioni.
*(Tabelle `journal_entries`, `mood_entries`, `memos` pronte)*


**Supporto mobile**
Godot 4.6 compila nativamente per Android e iOS.

---

## Slide 12 — Demo

### Vediamolo in azione

*(Spazio per demo dal vivo o screenshot)*

- Navigazione nella stanza con decorazioni posizionate
- Selezione e personalizzazione del personaggio
- Musica lo-fi con crossfade tra tracce
- Pannello impostazioni e profilo
- Sistema di autenticazione locale
- Pet gattino con animazioni autonome

---

## Slide 13 — Chiusura

### Relax Room

*"In un mondo che corre, abbiamo costruito un angolo dove fermarsi."*

Un progetto che dimostra:

- **Architettura software professionale** in un contesto creativo
- **Sviluppo collaborativo** con pipeline CI/CD reale
- **Design offline-first** che mette l'utente al centro
- **Codice pulito e testabile**, pronto per scalare

---

**Grazie.**

Renan Augusto Macena | Elia Zoccatelli | Cristian Marino
ITS 2025/2026

---

## Frasi d'Effetto

*Da usare come transizioni tra le slide o come sottotitoli:*

1. "Il tuo angolo di calma, a un click di distanza."
2. "Non un gioco. Un ambiente. Il tuo."
3. "31 segnali, zero accoppiamento. Architettura che respira."
4. "I tuoi dati non si perdono mai: tre livelli di protezione, zero compromessi."
5. "Costruito per restare. Progettato per crescere."
6. "118 commit di cura artigianale."
7. "Pixel art, lo-fi e codice pulito: gli ingredienti del benessere digitale."
8. "Offline-first: funziona sempre, sincronizza quando vuoi."
9. "Il tuo spazio personale, ovunque tu sia."
10. "Meno stress, piu pixel."
