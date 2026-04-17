# Speech — Renan Augusto Macena

**Ruolo**: Team Lead · Architetto Software
**Slide**: 1 · 3 · 4 · 5 · 7

---

### [SLIDE 1 — Copertina]

Buongiorno. Siamo il team che ha costruito **Relax Room**: un desktop companion pensato per farvi stare bene, non per rubare la vostra attenzione. Tre persone, un anno di lavoro, un prodotto che oggi funziona davvero. Partiamo.

---

### [SLIDE 3 — Filosofia & Perché]

Il mondo digitale oggi compete per la vostra attenzione. Notifiche, badge rossi, dark pattern, algoritmi che vi trattengono. Noi abbiamo fatto il contrario.

Quattro principi, senza compromessi. **Community prima del profitto**. **Tutto sbloccato dal primo minuto** — niente paywall, niente loot box. **Zero pressione** — non c'è un punteggio, non c'è un livello da raggiungere. **Presenza, non invasione** — l'app c'è quando vi serve, sparisce quando non la guardate.

Leggera — sessanta frame al secondo su hardware di cinque anni fa. Offline-first — i vostri dati restano sul vostro PC, firmati con HMAC. Il software più utile è quello che vi fa stare bene senza chiedervi nulla in cambio.

Ora vediamo come l'abbiamo costruito per mantenere ognuna di queste promesse.

---

### [SLIDE 4 — Architettura Tecnica]

Abbiamo scelto lo stack per due motivi: **robustezza** e **autonomia dell'utente**.

Godot 4.6 per il motore. SQLite in WAL mode per la persistenza locale. Supabase per il cloud, quando serve, con Row Level Security. Autenticazione duale: PBKDF2 con SHA-256 per gli account locali, JWT per quelli cloud. Integrità dei save garantita da HMAC-SHA256. Pipeline CI a nove job. Distribuzione via Netlify e GitHub Releases.

Dentro il motore abbiamo una catena di dieci singleton che si avviano in un ordine preciso: SignalBus, Logger, Database, Auth, Game, Save, Supabase, Audio, Performance, Stress. Ogni anello fa una cosa sola e la fa bene.

Il risultato è un'app resiliente. Funziona completamente offline, scrive i file in modo atomico — prima un temporaneo, poi rename — così non perdete mai dati se si spegne il PC. Se il cloud restituisce un errore, saltiamo e andiamo avanti, mai crash.

Il cuore di tutta questa architettura è il **SignalBus**.

---

### [SLIDE 5 — Signal Bus Topology]

Quarantasei segnali. Zero accoppiamento.

Abbiamo sei domini che non si parlano tra loro: Room, Character, Audio, UI, Save, Auth. Ognuno parla solo con il SignalBus. Nessun modulo conosce gli altri.

Un esempio concreto. L'utente posa una decorazione nella stanza. Viene emesso il segnale `decoration_placed`. Lo SaveManager lo sente e salva. Il SupabaseClient lo accoda per la sincronizzazione. L'AppLogger scrive l'evento nel log. Tre sistemi diversi, tre azioni coordinate, e nessuno di loro si conosce.

L'impatto è questo: aggiungere una funzionalità significa scrivere un nuovo listener. Non devi mai modificare il codice esistente. Il progetto cresce senza spezzarsi.

Passo la parola a Elia, che vi racconta come questi eventi diventano dati permanenti.

---

### [SLIDE 7 — Osservabilità: AppLogger]

Quando qualcosa si rompe, sapere dove guardare fa la differenza tra un bug fix in dieci minuti e un post-mortem di una settimana.

Abbiamo costruito un logger che scrive JSON strutturato, una riga per evento. Ogni riga ha un session ID — così tracciate l'intero flusso dell'utente da quando apre l'app a quando la chiude. Quattro livelli — debug, info, warn, error — filtrabili. File che ruotano: cinque da cinque megabyte ciascuno, venticinque totali, mai oltre. Scrittura asincrona ogni due secondi, zero impatto sul frame rate.

Risultato pratico: se un utente ci segnala un problema, ci manda il file `.jsonl` del giorno. Apriamo il log e capiamo esattamente cos'è successo, anche se il bug è su un PC offline che non abbiamo mai visto.

Ora Cristian vi racconta la pipeline di asset e la CI che rende tutto questo possibile.

---

## Note personali

- Se il tempo stringe sulla slide 5, tagliate l'esempio vivo di `decoration_placed`.
- Se vi avanza tempo sulla slide 4, aggiungete lo schema-resilient: errore HTTP 404 sul cloud → skip silenzioso, niente crash.
- Collegamento speech esteso: genesi del progetto, scelta del signal bus, offline-first.
