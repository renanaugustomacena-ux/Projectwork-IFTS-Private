# Speech — Renan Augusto Macena

**Ruolo**: Team Lead · Architetto Software
**Slide**: 1 · 2 (intro personale) · 5 (demo) · 6 · 7 · 8 · 11 (chiusura)

---

### [SLIDE 1 — Copertina]

Ogni app oggi compete per la vostra attenzione. Noi abbiamo fatto il contrario.

Buongiorno. Siamo Renan, Elia e Cristian, e abbiamo costruito **Relax Room** — un compagno desktop per il relax e la produttività consapevole. Progetto IFTS 2025/2026. Un anno di lavoro, tre persone, un prodotto che oggi funziona davvero.

---

### [SLIDE 2 — Team + Progetto]

Io sono Renan, Team Lead e Architetto Software. Ho progettato l'architettura signal-driven, sviluppato i sistemi core — SaveManager, AuthManager, GameManager, SupabaseClient, Logger — e tengo il repository.

*(Elia ora introduce se stessa, poi Cristian, poi riprendo per presentare il progetto.)*

Cos'è Relax Room? **Non è un gioco. È un ambiente**. Un luogo dove tornare quando serve un momento di calma. Una stanza pixel art con centoventinove oggetti decorativi. Musica lo-fi con crossfade automatico. Un gattino virtuale con comportamento autonomo. E soprattutto: funziona completamente offline, senza account obbligatorio.

---

### [SLIDE 6 — Flusso Signal-Driven]

**Quarantasei segnali. Zero accoppiamento.**

Nessun manager chiama direttamente un altro. Tutto passa attraverso il SignalBus — quarantasei segnali globali tipizzati. I sistemi sono completamente disaccoppiati, testabili in isolamento, estendibili senza toccare codice esistente.

Un esempio concreto. L'utente posa una decorazione. DropZone emette `decoration_placed`. Cinque sistemi diversi reagiscono in parallelo: RoomBase ridisegna la stanza. SaveManager scrive atomicamente su JSON più mirror SQLite. SupabaseClient accoda la sincronizzazione verso le quindici tabelle cloud. Il Logger traccia tutto con correlation ID end-to-end.

Cinque azioni coordinate. Nessuno conosce gli altri. Zero accoppiamento.

L'impatto pratico: aggiungere una nuova funzionalità significa scrivere un nuovo listener. Non modifichi mai il codice esistente. Il progetto cresce senza spezzarsi.

---

### [SLIDE 7 — Filosofia di Design]

Quattro principi, senza compromessi.

**Community, non competizione**. Nessun punteggio, nessuna classifica. Il focus è la creatività personale.

**Tutto sbloccato**. Niente grind, niente paywall. Tutto è disponibile dal primo avvio.

**Zero pressione**. Nessuna notifica, nessun timer, nessun sistema energetico. Giocate quando volete, chiudete senza sensi di colpa.

**Presenza senza invasione**. Il software esiste sullo sfondo della vostra giornata, non per dominarla.

A chi è destinato? Studenti che cercano un ambiente di studio tranquillo. Lavoratori da remoto che personalizzano il proprio spazio digitale. Creativi che cercano un angolo di ispirazione.

*Il software più utile è quello che vi fa stare bene senza chiedervi nulla in cambio.*

---

### [SLIDE 8 — Architettura Tecnica]

Lo stack. Godot 4.6 come motore — GDScript, viewport 1280×720, filtro Nearest per pixel art nitida. SQLite in WAL mode per il database locale — undici tabelle, chiavi esterne con CASCADE, migrazioni automatiche da versione uno a cinque. Supabase PostgreSQL per il cloud — quindici tabelle con Row-Level Security per utente.

Autenticazione duale: PBKDF2-SHA256 con salt random per gli account locali, Supabase Auth con JWT auto-refresh per quelli cloud. Integrità dei save garantita da firma HMAC-SHA256 — qualsiasi manomissione del file viene rilevata. Osservabilità tramite Logger strutturato a JSON Lines con correlation ID e redazione automatica dei secret.

CI/CD su GitHub Actions — nove job paralleli, niente merge senza verde totale. Deploy automatico su Netlify e GitHub Releases.

Otto autoload singleton. Un SignalBus al centro. Quarantasei segnali. Zero accoppiamento. Rimuovere un sistema non rompe gli altri. Aggiungere una feature non tocca il codice esistente.

---

### [SLIDE 11 — Ringraziamenti]

Un grazie di cuore.

A **Giorgia Chiampan**, la nostra tutor, per la guida costante, la pazienza e la fiducia in ogni fase del progetto. Senza di lei questo percorso non sarebbe stato lo stesso.

A **311-Verona e ai facilitatori**, che hanno reso possibile questo percorso formativo.

A **docenti e compagni**, che hanno condiviso domande e spunti lungo l'anno.

Relax Room non sarebbe esistito senza di voi. **Grazie.**

---

## Note personali

- Slide 1: la frase "Ogni app oggi compete per la vostra attenzione, noi abbiamo fatto il contrario" è il gancio. Pausa dopo.
- Slide 6: se sei in ritardo, taglia l'esempio `decoration_placed`. L'headline "46 segnali, zero accoppiamento" basta.
- Slide 7: i quattro principi vanno scanditi. Una frase per principio, non di più.
- Slide 11: la chiusura "Grazie" la possiamo dire tutti e tre insieme.
