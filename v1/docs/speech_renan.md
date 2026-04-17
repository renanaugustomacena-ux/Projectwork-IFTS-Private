# Speech — Renan Augusto Macena

**Ruolo**: Team Lead · Architetto Software · **Slide**: 1, 3, 4, 5, 7

> **keyword bold** = appigli visivi · `→` = transizione.

---

## Slide 1 — Copertina (20s)

- **Apertura**: "Buongiorno, siamo il team che ha costruito **Relax Room**."
- **Core**: desktop companion · IFTS 2025-2026 · tre nomi
- **→** "Partiamo presentandoci e presentando il prodotto."

---

## Slide 3 — Filosofia & Perche

- **Apertura**: "Il mondo digitale **compete per la tua attenzione**. Noi facciamo il contrario."
- **Core**: **4 principi** (community, tutto sbloccato, zero pressione, presenza non invasione) → **target** (studenti, remote worker, creativi) → **leggero 60/15 FPS** → **HMAC** dati tuoi sul PC
- **Impatto**: "Il software piu utile e quello che ti fa stare bene senza chiederti nulla."
- **Transizione**: → "Ora vediamo **come lo abbiamo costruito** per rispettare queste promesse."

---

## Slide 4 — Architettura Tecnica

- **Apertura**: "Stack scelto per **robustezza** e **autonomia**."
- **Core**: **Godot 4.6** · **SQLite WAL** locale · **Supabase** cloud con RLS · **auth duale** (PBKDF2-SHA256 + JWT) · **HMAC-SHA256** integrità · **CI 9 job** · **Netlify + GitHub Releases**
- **10 autoload chain**: SignalBus → AppLogger → LocalDatabase → Auth → Game → Save → Supabase → Audio → Performance → Stress
- **Resilienza**: offline-first · scrittura atomica · sync queue exp backoff · schema-resilient (404 cloud → skip senza crash)
- **→** "Il cuore di tutto questo è il **SignalBus**."

---

## Slide 5 — Signal Bus Topology *(NEW)*

- **Apertura**: "**46 segnali**, zero accoppiamento."
- **Core** (diagramma Figma): 6 domini (**Room, Character, Audio, UI, Save/Auth, Cloud/Economy**) parlano **solo con il bus**, mai tra loro
- **Esempio vivo**: "Quando l'utente posa una decorazione → `decoration_placed` → **SaveManager** salva, **SupabaseClient** accoda sync, **AppLogger** scrive l'evento. Nessuno si conosce."
- **Impatto**: "Aggiungere una feature = **nuovo listener**, **zero modifica** al codice esistente."
- **Transizione**: → "Elia ora racconta come i dati diventano persistenti."

---

## Slide 7 — Osservabilita: AppLogger *(NEW)*

- **Apertura**: "Quando si rompe, sai **dove guardare**."
- **Core**: **JSON Lines** strutturato / **session_id** per correlation end-to-end / **rotating 5MB x 5 file = 25 MB** / **4 livelli** DEBUG-INFO-WARN-ERROR / **flush async 2s**, zero impatto frame
- **Impatto**: "L'utente ci manda il `.jsonl`, **capiamo tutto** — debug post-mortem anche offline."
- **Transizione**: → "Passo a Cristian per la pipeline di asset e CI/CD."

---

## Note personali

- Se sforo: taglia l'esempio vivo della slide 5.
- Se avanzo tempo: aggiungi dettaglio su `schema-resilient` (HTTP 404 → skip senza crash) alla slide 4.
- **Collegamento speech esteso**: genesi progetto + scelta signal bus + offline-first.
