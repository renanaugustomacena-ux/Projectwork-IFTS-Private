# Speech — Cristian Marino

**Ruolo**: Asset Pipeline & CI/CD
**Slide assegnate**: 2 (intro propria), 8, 9 (parte Cifre + Oggi), 10 (chiusura collettiva)

> Legge veloce: **keyword bold** = appigli visivi. Freccia `→` = transizione alla prossima slide.

---

## Slide 2 — Intro personale

- **Apertura**: "Sono Cristian, **Asset Pipeline e CI/CD**."
- **Core** (1 frase): "Ho curato gli **asset pixel art** (personaggi, decorazioni, sfondi), configurato la **pipeline CI a 5 job paralleli** e gestito i **build automatici Windows + Web**."
- **Tempo**: 15 secondi
- **Transizione**: (torna a Renan per filosofia)

---

## Slide 8 — Pipeline Asset + CI/CD + Processo

- **Apertura**: "Pixel art **coerente** + pipeline **automatica** + metodo **disciplinato**."
- **Core — Asset**:
  - **Sprite 32x32** personaggi, 8 direzioni (idle/walk/interact/rotate)
  - **Kenney Pixel UI Pack** "ancient wood"
  - **Audio lo-fi**: 2 tracce, **crossfade automatico**
  - **Parallasse** multi-layer
- **Core — CI/CD 5 job paralleli**: lint / JSON / sprite paths / cross-ref / schema DB
- **Core — Processo**: **audit-driven** 3 passaggi / CI obbligatoria / **118 commit** semantici / runbook per ruolo
- **Impatto**: "Zero codice sul main senza **5 green**. Il codice si scrive una volta, si mantiene cento."
- **Transizione**: → "I numeri parlano."

---

## Slide 9 — Cifre + Funzionalita + Futuro

*(Speaker condiviso con Elia: io porto i numeri e l'Oggi, lei porta il Domani.)*

- **La mia parte — Cifre highlight** (NON leggere tutti e 12):
  - **118** commit — disciplina repository
  - **43** segnali — architettura disaccoppiata
  - **69** decorazioni — contenuto ricco
  - **9+15** tabelle — persistenza duale
  - **5** job CI — automazione completa
  - **~5.300** righe GDScript — scala reale
- **La mia parte — Oggi funziona**: drag-and-drop 69 decorazioni / pet FSM 5 stati / audio crossfade / tutorial 9 step signal-driven
- **Impatto**: "Non e un prototipo. E un prodotto."
- **Transizione**: (Elia prende la parola per il Domani, poi chiudiamo insieme)

---

## Slide 10 — Demo + Chiusura

- **Apertura**: "Un minuto di demo dal vivo."
- **Core demo** (ordine):
  1. Navigazione stanza con decorazioni
  2. Personalizzazione personaggio
  3. Musica lo-fi con crossfade
  4. Pannello impostazioni + profilo
  5. Autenticazione locale
  6. Pet gattino autonomo
- **Chiusura** (tutti e tre insieme): *"In un mondo che corre, abbiamo costruito un **angolo dove fermarsi**."*
- **4 punti finali**: architettura professionale / sviluppo collaborativo / offline-first / codice scalabile
- **Transizione**: → "**Grazie.**"

---

## Note personali

- Slide 9: **NON** leggere tutti e 12 i numeri — solo i 6 highlight.
- Demo: se qualcosa non parte, **passa al prossimo step** senza bloccarti.
- **Collegamento speech esteso**: metodologia + documentazione + preparazione al mantenimento futuro.
