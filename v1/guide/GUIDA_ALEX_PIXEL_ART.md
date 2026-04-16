# Guida Operativa — Alex (Pixel Art & Animazioni)

**Data**: 16 Aprile 2026
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) (parti **1**, **2**, **5** — Git, clone del repo e workflow Git quotidiano). Le altre parti (Godot, VS Code) **non ti servono**: tu non scrivi codice, disegni solo.
**Riferimenti**: [v1/assets/charachters/README.md](../assets/charachters/README.md), [v1/assets/pets/README.md](../assets/pets/README.md)

---

## Benvenuto

Questa guida ti porta da "non ho mai aperto Aseprite" a "ho consegnato 2 personaggi completi e 9 animazioni del gatto". Non saltare sezioni: ogni paragrafo risponde a una domanda che ti verrebbe in mente dopo, se lo saltassi.

La guida e' volutamente dettagliata. Non leggerla tutta in una volta: usa l'indice, vai alla sezione del task che stai per affrontare, e torna qui quando hai finito.

Regola unica: **se una cosa non e' scritta qui, chiedi a Renan prima di inventartela**.

---

## Indice

1. [Le Tue Responsabilita'](#1-le-tue-responsabilita)
2. [Cosa Consegni Alla Fine](#2-cosa-consegni-alla-fine)
3. [Concetti di Base che Devi Sapere](#3-concetti-di-base-che-devi-sapere)
4. [Le 10 Regole d'Oro della Pixel Art](#4-le-10-regole-doro-della-pixel-art)
5. [Setup del Computer (30 min)](#5-setup-del-computer-30-min)
6. [Configurazione di Aseprite (15 min)](#6-configurazione-di-aseprite-15-min)
7. [Task 1 — Preparazione della Palette (20 min)](#7-task-1--preparazione-della-palette-20-min)
8. [Task 2 — Personaggio 1 (6-10 ore)](#8-task-2--personaggio-1-6-10-ore)
9. [Task 3 — Personaggio 2 (6-10 ore)](#9-task-3--personaggio-2-6-10-ore)
10. [Task 4 — Gatto: Rifinitura Idle/Walk/Sleep (2-3 ore)](#10-task-4--gatto-rifinitura-idlewalksleep-2-3-ore)
11. [Task 5 — Gatto: 6 Nuove Animazioni (4-5 ore)](#11-task-5--gatto-6-nuove-animazioni-4-5-ore)
12. [Breakdown Pixel-per-Pixel delle Animazioni del Gatto](#12-breakdown-pixel-per-pixel-delle-animazioni-del-gatto)
13. [Checklist Finale (prima di pushare)](#13-checklist-finale-prima-di-pushare)
14. [Workflow Git per Alex (GitHub Desktop)](#14-workflow-git-per-alex-github-desktop)
15. [Cosa Puo' Andare Storto (24 Trappole)](#15-cosa-puo-andare-storto-24-trappole)
16. [Protocollo di Comunicazione](#16-protocollo-di-comunicazione)
17. [Risorse Utili (studia questi prima di disegnare)](#17-risorse-utili-studia-questi-prima-di-disegnare)

---

## 1. Le Tue Responsabilita'

Queste sono le tre cose che devi produrre. In questo ordine, **dal piu' al meno importante** (se finisci il tempo, i task finali si possono rimandare, quelli iniziali no).

| # | Task | Cartella di output | Priorita' | Tempo stimato | Stato |
|---|------|---------------------|-----------|----------------|-------|
| 1 | **Personaggio 1** (nome da concordare con Renan) | `v1/assets/charachters/female/<nome1>/` — 4 PNG + 4 `.aseprite` | **ALTO** | 8-12 ore | DA FARE |
| 2 | **Personaggio 2** (nome da concordare) | `v1/assets/charachters/male/<nome2>/` — 4 PNG + 4 `.aseprite` | **ALTO** | 8-12 ore | DA FARE |
| 3 | **Gatto**: rifinitura esistenti + 6 nuove animazioni | `v1/assets/pets/` — 9 PNG + 9 `.aseprite` | MEDIO | 6-8 ore | DA FARE |

**Tempo totale stimato**: 20-30 ore di lavoro effettivo (non calendario — vai al tuo ritmo).

> **Nota sul typo storico**: la cartella `charachters` ha una "h" in piu' rispetto alla parola inglese corretta "characters". **Non correggerla**. Il codice del gioco punta a questo nome: se lo cambi, si rompe tutto. E' un errore voluto (= non voluto, ma ormai conservato).

---

## 2. Cosa Consegni Alla Fine

Al termine di tutti i task, la tua consegna deve contenere **esattamente questi file**:

**Personaggi** (2 persone × 4 animazioni):
- 8 file `.png` (4 per personaggio)
- 8 file `.aseprite` (sorgenti, uno per ogni PNG)

**Gatto** (9 animazioni totali):
- 9 file `.png` (3 rifiniti + 6 nuovi)
- 9 file `.aseprite` (sorgenti)

**Palette condivisa**:
- 1 file `.gpl` con la tavolozza di colori del progetto

**Totale finale**: **17 PNG + 17 `.aseprite` + 1 palette**.

> **Regola non negoziabile**: i `.aseprite` (sorgenti) sono importanti quanto i `.png`. Se consegni solo i PNG, Renan non puo' modificare nulla in futuro. **Ogni volta che esporti un PNG, salva anche il sorgente.**

---

## 3. Concetti di Base che Devi Sapere

Queste sono le idee che servono per capire tutto quello che viene dopo. Leggi con calma. Non c'e' fretta.

### 3.1 Cos'e' un Pixel

Un pixel e' un singolo quadratino colorato. La pixel art non e' "disegno a bassa risoluzione": e' un'arte in cui **ogni singolo quadratino viene deciso a mano, con intenzione**.

Per darti un ordine di grandezza:
- Un frame del nostro personaggio e' 23×23 pixel = **529 quadratini totali**.
- Un frame del gatto e' 16×16 pixel = **256 quadratini totali**.

Ogni pixel che sposti, aggiungi o togli **si nota**. Non c'e' sfocatura che copra gli errori: a questa risoluzione ogni decisione e' visibile.

### 3.2 Cos'e' un Frame

Un frame e' un singolo fotogramma di un'animazione, come la pagina di un cartone animato sfogliato velocemente. Mettendo in sequenza 4 frame leggermente diversi di un personaggio che cammina, il cervello dello spettatore "riempie" lo spazio tra un frame e l'altro e vede il movimento.

Nel nostro progetto:
- Una camminata completa = **4 frame** (standard industriale minimo).
- Un'animazione "idle" (fermo che respira) = **4 o 5 frame**.

### 3.3 Cos'e' uno Spritesheet

Uno spritesheet e' un'unica immagine che contiene tutti i frame di un'animazione, disposti a griglia. Invece di salvare 20 file separati, ne salvi uno solo con dentro tutti i frame in ordine.

Esempio: il nostro spritesheet del personaggio e' un'immagine di **92×115 pixel**, con dentro una griglia di **4 colonne × 5 righe = 20 celle** da 23×23 pixel ciascuna.

Il gioco (Godot) legge lo spritesheet e "ritaglia" la cella giusta al momento giusto.

### 3.4 FPS vs Millisecondi (leggi con attenzione)

**Trappola principianti n.1**: quando la gente parla di animazione dice "8 FPS" (frames per second), ma Aseprite ti chiede **millisecondi per frame**. Sono due modi di dire la stessa cosa.

Formula: `millisecondi = 1000 / FPS`

Tabella di conversione (tienila a portata, userai questi valori):

| FPS | Millisecondi per frame | Uso tipico |
|-----|------------------------|------------|
| 2 | 500 ms | Animazione molto lenta (sonno profondo) |
| 3 | 333 ms | Sonno |
| 4 | 250 ms | Idle calmo, respiro |
| 5 | 200 ms | Idle medio, rotate del personaggio |
| 6 | 166 ms | Interact, annoyed |
| 8 | 125 ms | Walk del personaggio, walk del gatto |
| 10 | 100 ms | Play, roll |
| 12 | 83 ms | Jump (rapido) |
| 15 | 66 ms | Surprised (rapidissimo) |

### 3.5 Direzione vs Rotazione

Il personaggio puo' guardare in **8 direzioni** (su, giu', destra, sinistra e le 4 diagonali). Ma tu ne disegnerai solo **5**: le versioni "sinistra" le genera automaticamente il motore facendo lo **specchio orizzontale** (flip horizontal) delle versioni "destra".

Riepilogo:
- **Disegni**: `down`, `vertical_down` (diagonale giu'-destra), `side` (destra), `vertical_up` (diagonale su-destra), `up`.
- **Il motore specchia**: `vertical_down_sx` (diagonale giu'-sinistra), `side_sx` (sinistra), `vertical_up_sx` (diagonale su-sinistra).

Risultato: **per te e' meta' del lavoro**. Lavoro felice.

> **Regola ferrea**: **non disegnare mai** le versioni sinistre. Se lo fai stai sprecando ore e peggiorando il risultato, perche' lo specchio automatico produce un ciclo di camminata piu' coerente.

### 3.6 Cos'e' una Palette

Una palette e' una lista fissa di colori (tipicamente 16-32) che tutti i personaggi e le scene del gioco condividono. Tenere una palette fissa:
- Fa sembrare tutto il gioco "dello stesso mondo" (coerenza visiva).
- Ti impedisce di perdere tempo a scegliere colori sempre diversi.
- Evita il "drift" di tonalita' (due rossi quasi uguali ma non proprio).

Per il nostro progetto la palette e' gia' definita nei PNG del personaggio `male/old`. **Tu la caricherai, e da quel momento in poi usi solo quei colori**, mai il selettore di colori libero.

### 3.7 Il Test della Sagoma (Silhouette Test)

La sagoma (silhouette) di un personaggio e' la sua forma esterna, vista come un'unica macchia scura su sfondo chiaro. E' la prima cosa che l'occhio riconosce, anche prima degli occhi e dei vestiti.

**Test**: seleziona tutto il tuo disegno e riempilo di nero (in Aseprite: `Ctrl+A`, poi `Edit → Fill`, scegli colore nero). Ora guardalo:
- Riconosci che e' un personaggio umanoide? **Si' / No**.
- Capisci in che direzione sta guardando? **Si' / No**.

Se uno dei due e' "No", la sagoma non funziona e nessun dettaglio di vestiti o capelli la salvera'. Torna indietro e lavora sulla silhouette.

A 23×23 pixel, la silhouette fa **100% del lavoro di riconoscimento**. Scegli 2-3 tratti silhouette esagerati (un cappello, un ciuffo di capelli, un mantello) e difendi quelli.

### 3.8 Squash & Stretch

"Squash" (compressione) e "stretch" (allungamento) sono le due deformazioni base dell'animazione. Per il nostro gatto di 16×16 pixel:

- **Squash**: altezza da 16 a 11-12 (si schiaccia), larghezza aumenta di 1-2 px (il volume si conserva).
- **Stretch**: altezza a 18-20 (si allunga), larghezza diminuisce di 1-2 px.

Regola: **il volume si conserva**. Se schiacci verticalmente, devi allargare orizzontalmente. Non togliere semplicemente pixel dall'alto.

A 23×23 del personaggio, invece, le deformazioni sono piu' piccole: **±1 pixel sempre**. Zero = personaggio morto. Due o piu' = personaggio di gomma.

---

## 4. Le 10 Regole d'Oro della Pixel Art

Queste sono le 10 regole che separano pixel art amatoriale da pixel art professionale. Leggile prima di disegnare. Rileggile quando qualcosa ti sembra "strano" e non sai perche'.

1. **Pencil, non Brush.** In Aseprite premi `B` (matita). Controlla la barra di contesto in alto: deve dire "Pencil". Non usare mai il Brush: ha bordi sfumati, non va bene per pixel art.

2. **Pixel-Perfect attivo.** Quando la Pencil e' selezionata, nella Context Bar in alto c'e' una casella "Pixel-perfect". **Mettila sempre.** Senza questa casella, quando disegni una linea a mano libera, Aseprite mette doppi pixel agli angoli, brutti da vedere.

3. **Simple Ink.** Context Bar, dropdown "Ink": deve stare su `Simple Ink`. Se per errore e' su "Shading", "Alpha Compositing" o "Dither", il pennello si comporta in modo strano.

4. **3 toni per materiale.** Ogni "materiale" del personaggio (pelle, maglia, capelli) usa **3 colori della palette**: ombra, mid-tone (quello principale), highlight. Raramente 4. Mai 2 o 5.

5. **Niente anti-alias (salvo casi rari).** A 23×23 non usare anti-aliasing. Le linee diagonali a 45° (tipo `/` o `\`) devono essere pixel neri pieni, senza sfumature intermedie. L'unico anti-alias "manuale" ammesso e' su curve che altrimenti sembrerebbero troppo a scalini — e in quel caso usi 1 solo colore intermedio della palette, non un colore inventato.

6. **Niente banding.** Banding = quando due linee parallele di colori diversi hanno la **stessa identica lunghezza**. Risultato: l'occhio vede una "striscia piatta" invece di una forma. Soluzione: spezza una delle due linee di ±1 pixel in un punto.

7. **Silhouette leggibile.** Fai il test della silhouette (sezione 3.7) dopo ogni frame importante. Se non passa, ferma tutto e lavora sulla sagoma.

8. **Bob ±1 px sempre (idle/walk).** Il corpo del personaggio deve oscillare di ±1 pixel in verticale durante le animazioni fluide. Zero oscillazione = personaggio morto. Due o piu' pixel = trampolino elastico.

9. **Testa bob col torso.** Se il torso sale di 1 pixel, la testa sale di 1 pixel insieme a lui. Lo stesso per la discesa. Decoupling (testa che rimane ferma mentre il corpo si muove) e' il segnale numero uno di pixel art amatoriale.

10. **Solo palette caricata.** Dopo aver caricato la palette (Task 1), **clicca solo sui colori che vedi nel pannello palette a sinistra**. Mai il selettore di colori libero a ruota. Se devi riprendere un colore che hai gia' usato sulla tela, usa `Alt+click` sul pixel (contagocce).

---

## 5. Setup del Computer (30 min)

Prima di disegnare serve installare i programmi. Uno per volta.

### 5.1 Aseprite (il programma con cui disegni)

**Cos'e'**: Aseprite e' il programma standard dell'industria per fare pixel art e animazioni sprite. Lo comprano praticamente tutti gli sviluppatori indie che fanno pixel art.

**Opzioni di installazione**:
- **A pagamento ufficiale**: $19.99 una tantum (circa 19 euro, pagamento unico, non abbonamento). Sito: https://www.aseprite.org/ → bottone "Buy".
- **Su Steam**: stesso prezzo, stesso programma, si aggiorna automaticamente via Steam. https://store.steampowered.com/app/431730/Aseprite/
- **Alternativa gratuita (LibreSprite)**: se davvero non vuoi spendere, esiste una versione gratuita "fork" di Aseprite vecchio. Sito: https://libresprite.github.io/. Ha meno funzionalita' ma per questo progetto va bene. L'interfaccia e' quasi identica: quando la guida dice "Aseprite" puoi leggere "LibreSprite" senza problemi, salvo dove specificato.
- **Trial gratis ufficiale**: https://www.aseprite.org/trial/. Puoi usarlo per cliccare in giro e vedere com'e' fatto, ma **non salva file**. Inutile per lavorarci davvero — compra la versione completa o usa LibreSprite.

**Consiglio di Renan**: compra Aseprite. Sono 19 euro una volta sola, e' lo strumento migliore per questo tipo di lavoro.

### 5.2 Git + GitHub Desktop (per caricare i file)

Per inviare i tuoi file al progetto, ti serve **GitHub Desktop** (un programma con bottoni, non il terminale — piu' facile).

Segui le istruzioni di [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) sezione **1** (per installare Git) e sezione **2** (per clonare il repository).

In aggiunta, scarica **GitHub Desktop** da: https://desktop.github.com/

Durante l'installazione:
1. Accedi con il tuo account GitHub (Renan ti ha gia' invitato al repo).
2. Clicca "Clone a repository from the Internet".
3. Scegli il repo `Projectwork-IFTS-Private`.
4. Scegli una cartella locale (es: `C:\Progetti\Projectwork` su Windows, `~/Progetti/Projectwork` su Mac/Linux).
5. Aspetta il clone (5-10 minuti la prima volta).

### 5.3 Verifica del Clone

Dopo il clone, apri la cartella locale e controlla che esistano questi percorsi:
- `v1/assets/charachters/female/female_red_shirt/` (la ragazza di riferimento)
- `v1/assets/charachters/male/old/` (il personaggio attivo — sorgente della palette)
- `v1/assets/pets/` (il gatto)
- `v1/guide/` (dove c'e' questa guida)

Se uno manca, il clone non e' andato a buon fine. Rifallo o chiedi a Renan.

---

## 6. Configurazione di Aseprite (15 min)

Apri Aseprite una prima volta e fai queste 5 cose **prima di iniziare a disegnare**. Le fai una sola volta, poi valgono per sempre.

### 6.1 Impostazioni Generali

Menu: `Edit → Preferences`.

- Tab **General**: "Screen Scale" a `100%` (salvo che tu abbia un 4K, allora `200%`). "Ui Scale" lasciato su `100%`.
- Tab **Files → Data Recovery**: **spunta** "Enable data recovery". Impostalo su ogni `2 minutes`. Se Aseprite crasha, non perdi ore di lavoro.
- Tab **Experimental**: lascia tutto invariato.

Clicca OK.

### 6.2 Come Creare un Nuovo Sprite (esempio)

Menu: `File → New` (shortcut: `Ctrl+N`).

Nel dialogo:
- **Width**: `92` (per ora, per test — cambierai valore in base al task)
- **Height**: `115`
- **Color Mode**: `RGB Color` (= RGBA, 8 bit per canale con trasparenza)
- **Background**: `Transparent`
- **Advanced Options**: lascia valori predefiniti (Pixel Aspect Ratio 1:1).

Clicca OK. Ti si apre una tela vuota trasparente 92×115.

> **Trappola**: se metti `Indexed` come Color Mode, ogni pixel diventa un numero che punta a un colore della palette. Puo' causare perdite di colori silenti. **Usa sempre `RGB Color`.**

### 6.3 Configurare la Griglia (23×23 per i personaggi)

Menu: `View → Grid → Grid Settings`.

- **X**: `0`
- **Y**: `0`
- **Width**: `23`
- **Height**: `23`

Clicca OK.

Ora per mostrare/nascondere la griglia: `Ctrl+'` (Ctrl + apostrofo). Deve apparire una griglia di quadrati 23×23 sovrapposta alla tela.

**Per il gatto** useremo invece griglia `16×16`: cambierai questi valori quando lavorerai sul gatto.

### 6.4 Shortcut Essenziali (tabella da stampare e tenere accanto)

| Shortcut | Cosa fa |
|----------|---------|
| `B` | Pencil (matita — lo strumento principale) |
| `E` | Eraser (gomma) |
| `G` | Paint Bucket (secchio per riempimento) |
| `I` | Eyedropper / contagocce (preleva colore) |
| `Alt+click` | Eyedropper rapido (senza cambiare strumento) |
| `H` | Hand (sposta visuale) |
| `Z` | Zoom |
| `L` | Line (linea dritta) |
| `M` | Rectangular Marquee (selezione rettangolare) |
| `Ctrl+A` | Seleziona tutto |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo / Redo |
| `Ctrl+N` | Nuovo sprite |
| `Ctrl+S` / `Ctrl+Shift+S` | Salva / Salva come |
| `Ctrl+'` | Mostra/nascondi griglia |
| `Tab` | Mostra/nascondi timeline |
| `F3` | Mostra/nascondi onion skin |
| `F7` | Mostra/nascondi finestra preview |
| `Enter` | Play/pause animazione |
| `,` | Frame precedente |
| `.` | Frame successivo |
| `Alt+N` | Nuovo frame (copia del corrente) |
| `Alt+B` | Nuovo frame vuoto |
| `F2` (due volte di fila) | Crea tag sulla selezione di frame |
| `X` | Scambia colore foreground/background |
| `+` / `-` | Aumenta/riduci dimensione pennello (tienilo a 1 per ora!) |

**Dimensione pennello**: deve stare **sempre a 1** per pixel art. Se per errore diventa 2+, le tue linee diventano grosse e brutte.

### 6.5 Verifica Pencil Corretta

Prima di iniziare a disegnare, fai questo controllo:
1. Premi `B`. Nella Context Bar in alto controlla:
   - Strumento: **Pencil** (non Brush).
   - Size: **1 px** (casella numerica).
   - Ink: **Simple Ink** (dropdown).
   - **Pixel-perfect**: casella **SPUNTATA**.
2. Se qualcosa non corrisponde, sistemalo ora.

---

## 7. Task 1 — Preparazione della Palette (20 min)

Questo e' il primo task perche' tutti i task successivi dipendono da lui.

### 7.1 Cosa Dobbiamo Fare

Il personaggio esistente `male/old` ha una palette di colori definita (i rossi della maglietta, il beige della pelle, i marroni dei capelli, eccetera). I due nuovi personaggi e il gatto devono usare **la stessa palette**, altrimenti sembrano di mondi diversi.

Quello che faremo:
1. Aprire un PNG del personaggio esistente in Aseprite.
2. Far estrarre ad Aseprite tutti i colori unici del PNG.
3. Salvarli come file palette `.gpl`.
4. Committare quel file in `v1/assets/palette/`.

Da quel momento in poi, ogni volta che apri un nuovo sprite, caricherai la palette da quel file.

### 7.2 Passo 1 — Apri il PNG Sorgente

In Aseprite: `File → Open`. Apri il file:

```
v1/assets/charachters/male/old/male_idle/male_idle_down.png
```

Vedrai uno sprite 128×32 con 4 frame di un personaggio maschile fermo che guarda verso il basso. (Non usare questo formato — lo vediamo solo per estrarre la palette.)

### 7.3 Passo 2 — Estrai la Palette

A sinistra vedi il **Palette Panel** (pannello colori). Sopra il pannello c'e' un'icona piccola con 3 linee orizzontali o un ingranaggio — e' il menu **Palette Options**.

Clicca su Palette Options → scegli **"Load Palette from Current Sprite"**.

Aseprite estrae tutti i colori unici del PNG (saranno circa 15-20) e li mette nel pannello palette, rimpiazzando quelli default.

### 7.4 Passo 3 — Salva la Palette

Palette Options → **"Save Palette As..."**.

Prima di salvare:
1. Crea la cartella `v1/assets/palette/` (in Esplora risorse / Finder, naviga fino a `v1/assets/` e crea una nuova cartella chiamata `palette`).
2. In Aseprite, nel dialogo Save Palette, naviga fino a quella cartella.
3. Nome file: `palette_projectwork.gpl` (estensione `.gpl`, formato GIMP-compatibile — e' lo standard).

Clicca Save.

### 7.5 Passo 4 — Verifica

Chiudi il PNG del personaggio senza salvarlo (`File → Close`, "Don't Save" se chiede).

Apri un nuovo sprite di prova (`Ctrl+N`, qualsiasi dimensione). Nel pannello palette vedrai ancora i colori estratti — ma questi sono temporanei, associati allo sprite corrente.

Ora testa il caricamento: Palette Options → **"Load..."** → naviga a `v1/assets/palette/palette_projectwork.gpl`. I colori devono caricarsi identici a prima.

Se funziona, hai completato il Task 1.

### 7.6 Commit Task 1

Apri GitHub Desktop. Vedrai un nuovo file elencato: `v1/assets/palette/palette_projectwork.gpl`.

Commit:
- Summary: `feat(assets): palette condivisa del progetto estratta da male/old`
- Clicca "Commit to main" (o al branch corrente).
- Clicca "Push origin" in alto.

Task 1 completato.

---

## 8. Task 2 — Personaggio 1 (6-10 ore)

Questo e' il task piu' grande. Lo divido in sub-passi. Segui l'ordine, non saltare.

### 8.1 Prima di Aprire Aseprite: Concept Sketch

Prima di disegnare in Aseprite, fai **2-3 schizzi rapidi** del personaggio su carta (o con una tavoletta grafica, o anche con una matita in una foto). Non devono essere belli: servono solo a decidere silhouette e outfit.

Criteri:
- Silhouette riconoscibile (vedi regola d'oro #7).
- Outfit distintivo (una maglia di un colore forte, un cappello, una treccia — qualcosa che lo distingua da `male/old`).
- Palette coerente: usa solo mentalmente i colori che sai essere nella palette (rossi, beige, marroni, bianchi, grigi).
- Genere del personaggio: da concordare con Renan prima di iniziare.

Manda gli schizzi a Renan (Telegram / Discord / WhatsApp). Renan sceglie uno dei 2-3, poi passi al digitale.

### 8.2 Passo 1 — Canvas Setup

In Aseprite: `File → New` (`Ctrl+N`).

- **Width**: `92`
- **Height**: `115`
- **Color Mode**: `RGB Color`
- **Background**: `Transparent`

OK.

> **Attenzione — canvas 92×115 e NON 93×116**: il personaggio di riferimento (`female_red_shirt`) ha canvas 93×116, ma con una griglia 23×23 questo lascia 1 pixel morto per lato (4×23=92, 5×23=115; il 93° e 116° pixel non appartiene a nessuna cella). Noi usiamo **92×115** per avere una griglia pulita e zero pixel morti. Se fai 93×116 per errore, i tuoi frame saranno leggermente disallineati nel gioco.

### 8.3 Passo 2 — Carica la Palette

Palette Options → **"Load..."** → `v1/assets/palette/palette_projectwork.gpl`.

Da ora in poi: **clicca solo sui colori del pannello palette**. Mai il color wheel.

### 8.4 Passo 3 — Configura la Griglia 23×23

Menu: `View → Grid → Grid Settings`.
- Width: `23`, Height: `23`.

Attiva la griglia: `Ctrl+'`.

Vedrai il canvas diviso in 4 colonne × 5 righe di celle 23×23. Ogni cella sara' un frame/direzione del personaggio.

### 8.5 Passo 4 — Layer Strategy

A destra (o in basso) c'e' il pannello **Layers**. All'inizio c'e' un solo layer chiamato "Layer 1".

Crea **2 layer separati** (doppio click sul nome per rinominarli):
1. `sagoma` — per la silhouette nera del corpo (la userai come base per lavorare).
2. `dettagli` — per volto, vestiti, occhi, capelli.

**Perche'**: quando lavori la sagoma prima, e' piu' facile correggerla senza distruggere i dettagli. Quando poi aggiungi i dettagli sopra, la sagoma rimane intatta.

### 8.6 Passo 5 — Mappa dei Frame

Il canvas 92×115 si divide in questa griglia:

```
Colonne (frame dell'animazione, da 1 a 4):

           Col 0      Col 1      Col 2      Col 3
           X=0-22     X=23-45    X=46-68    X=69-91
         +---------+---------+---------+---------+
Riga 0   | frame1  | frame2  | frame3  | frame4  |   Direzione: DOWN
Y=0-22   | down    | down    | down    | down    |
         +---------+---------+---------+---------+
Riga 1   | frame1  | frame2  | frame3  | frame4  |   Direzione: VERTICAL_DOWN (giu'-destra)
Y=23-45  |  vdown  |  vdown  |  vdown  |  vdown  |
         +---------+---------+---------+---------+
Riga 2   | frame1  | frame2  | frame3  | frame4  |   Direzione: SIDE (destra)
Y=46-68  |  side   |  side   |  side   |  side   |
         +---------+---------+---------+---------+
Riga 3   | frame1  | frame2  | frame3  | frame4  |   Direzione: VERTICAL_UP (su-destra)
Y=69-91  |  vup    |  vup    |  vup    |  vup    |
         +---------+---------+---------+---------+
Riga 4   | frame1  | frame2  | frame3  | frame4  |   Direzione: UP
Y=92-114 |  up     |  up     |  up     |  up     |
         +---------+---------+---------+---------+
```

Ogni cella e' **23×23 pixel** (una cella = un frame del personaggio in una direzione).

### 8.7 Passo 6 — Animazione `idle` (personaggio fermo che respira)

Questo e' il primo PNG che produci: `<nome1>_idle.png`.

**Concept dell'animazione idle**: il personaggio sta fermo, ma respira leggermente — sale e scende di 1 pixel, ogni tanto sbatte le palpebre.

**Procedura consigliata** (disegna prima il frame 1 di tutte le direzioni, poi il frame 2, ecc. — aiuta a mantenere coerenza tra direzioni):

1. **Frame 1 di tutte le 5 direzioni** (colonna X=0, tutte le 5 righe):
   - Cella riga 0: personaggio che guarda in basso (verso la camera), pose neutra.
   - Cella riga 1: personaggio in diagonale giu'-destra.
   - Cella riga 2: personaggio che guarda a destra (di profilo).
   - Cella riga 3: personaggio in diagonale su-destra.
   - Cella riga 4: personaggio che guarda in alto (di spalle).
   
   Fai il **test della silhouette** su ogni cella prima di procedere.

2. **Frame 2 di tutte le 5 direzioni** (colonna X=23):
   - Copia dal frame 1 e modifica di 1 pixel: **corpo sale di 1 pixel** (inspira).
   - Head bob: anche la testa sale di 1 pixel insieme al torso.

3. **Frame 3** (colonna X=46): peak dell'inspirazione.
   - Corpo ancora alzato di 1 px, e in aggiunta pancia/torso **si allarga di 1 px** (width +1 px temporaneo).

4. **Frame 4** (colonna X=69): ritorno alla base.
   - Come frame 1, ma con **occhi chiusi per un frame** (eye-blink). Basta togliere i 1-2 pixel degli occhi e rimetterli di colore pelle.

**Timing**: 5 fps = 200 ms per frame (vedi tabella sezione 3.4).

**Onion skin**: attivalo con `F3` dopo il frame 1, cosi' vedi sempre il frame precedente in trasparenza rosa e puoi allineare i pixel.

### 8.8 Passo 7 — Animazione `walk` (ciclo di camminata)

Il piu' impegnativo tecnicamente. **Leggi tutta questa sezione prima di iniziare**.

**Concept del walk cycle**: 4 keypose canoniche dell'animazione:

- **Contact** (frame 1): un piede tocca il suolo, l'altro e' in aria. Il pixel piu' basso del piede d'appoggio **tocca la riga 22 del frame** (l'ultima riga). **Zero aria sotto.**
- **Down** (frame 2): il corpo "schiaccia" verso il basso — peso scaricato sulla gamba anteriore. Altezza del corpo: 1 px piu' in basso del frame Contact. Ginocchia piegate.
- **Passing** (frame 3): momento in cui la gamba arretrata passa accanto all'altra. Corpo **1 px piu' in alto** rispetto a Contact (il passo "solleva"). Gambe incrociate: una davanti, una dietro allo stesso livello verticale.
- **Up** (frame 4): il corpo riscende verso Contact, l'altra gamba sta per toccare il suolo.

**Regole del walk cycle**:
1. **Braccia in opposizione alle gambe**: quando la gamba sinistra e' avanti, il braccio destro e' avanti. Quando la gamba destra e' avanti, il braccio sinistro e' avanti. Questo e' il modo in cui cammina un umano vero (il tuo cervello lo riconosce subito, anche senza accorgersene).
2. **Head bob con torso**: testa segue torso di +1 px in Passing, -1 px in Down.
3. **Piede d'appoggio non trasla**: nel Contact e nel Down, il piede che tocca il suolo **non si muove orizzontalmente**. Se si muove, sembra che il personaggio scivoli sul ghiaccio (errore: "feet glide").
4. **Braccio lontano occluso nelle diagonali**: nei frame diagonali (vertical_down e vertical_up), il braccio piu' lontano dalla camera e' parzialmente nascosto dal torso. Mostra solo la mano, o nascondilo del tutto.

**Onion skin obbligatorio**: accendi `F3` e controlla frame per frame.

**Timing**: 8 fps = 125 ms per frame.

**Test qualita'**: quando hai finito una direzione, premi `Enter` per far girare l'animazione in loop. Se il personaggio sembra "scivolare" invece di camminare, hai un feet-glide. Se sembra "rigido", mancano i ±1 px di bob.

### 8.9 Passo 8 — Animazione `interact` (gesto di interazione)

**Concept**: il personaggio fa un gesto per interagire con un oggetto (apre una porta, raccoglie qualcosa, preme un bottone). Il braccio anteriore si solleva e si abbassa.

4 frame per direzione:
- **F1 baseline**: pose come idle frame 1.
- **F2 braccio sale**: il braccio anteriore (rivolto verso l'oggetto davanti) si solleva verso l'alto di 2-3 pixel.
- **F3 peak**: braccio al massimo in alto. Questo e' il momento "importante" — l'oggetto viene toccato/preso/premuto.
- **F4 braccio rientra**: torna a baseline.

**Timing**: 6 fps = 166 ms per frame.

**Trucco diagonali**: per i frame `vertical_down`/`vertical_up`, il braccio che si muove e' quello verso la camera (il piu' vicino, visibile per intero).

### 8.10 Passo 9 — Frame Tagging (necessario per l'export)

Una volta disegnati tutti i 20 frame (4 per direzione × 5 direzioni) per idle, **devi taggare** i 5 gruppi di frame con i nomi delle direzioni, altrimenti l'export non sapra' come organizzarli.

Per ogni direzione:
1. Nella timeline (pannello in basso), clicca sul frame 1 della riga 0, poi `Shift+click` sul frame 4 della riga 0 (seleziona 4 frame contigui).
2. Premi `F2` due volte di fila. Si apre una finestra di tag.
3. Name: `idle_down` (primo gruppo), `idle_vertical_down`, `idle_side`, `idle_vertical_up`, `idle_up`.
4. Animation Direction: `Forward`.
5. Repeat: `0` (infinito).
6. OK.

Ripeti per tutti e 5 i gruppi.

### 8.11 Passo 10 — Export in PNG

`File → Export Sprite Sheet`.

Si apre un dialogo con 4 tab. **Controlla ogni impostazione**:

**Tab Layout**:
- Sheet Type: `By Rows` (importante!)
- Constraints → Fixed # of Columns: `4`
- Merge Duplicates: **UNCHECK** (togli la spunta)
- Ignore Empty: **UNCHECK**

**Tab Sprite**:
- Source: `Visible Layers`
- Frames: `All Frames`

**Tab Borders**:
- Border Padding: `0`
- Shape Padding: `0`
- Inner Padding: `0`
- Trim Sprite: **UNCHECK**
- Trim Cels: **UNCHECK**

**Tab Output**:
- Output File: **SPUNTA**
- Nome file: `<nome1>_idle.png`
- Directory: `v1/assets/charachters/female/<nome1>/` (crea prima la cartella! — in GitHub Desktop, o da Esplora risorse)
- JSON Data: opzionale, se vuoi metti spunta, formato `Array` (Renan puo' usarlo se vuole).
- Split Layers: **UNCHECK**.
- Split Tags: **UNCHECK**.

Clicca **Export**.

### 8.12 Passo 11 — Verifica Dimensione PNG Esportato

**Questo passaggio e' critico.** Apri il PNG appena esportato (`File → Open`, seleziona il file).

Aseprite mostra la dimensione in basso a destra. Deve essere esattamente **92×115 pixel**.

Se vedi **372×580** o altri numeri grandi: hai un problema. Probabile causa: nell'export "Source" hai lasciato "All frames" ma Aseprite ha esportato l'intero canvas invece delle celle. Riapri il .aseprite, controlla che i frame siano 23×23 (non 92×115), e riesporta.

Se tutto e' ok (92×115), prosegui.

### 8.13 Passo 12 — Salva il Sorgente .aseprite

`File → Save As` (`Ctrl+Shift+S`). Naviga a:
```
v1/assets/charachters/female/<nome1>/aseprite_<nome1>/
```

(Crea la sottocartella `aseprite_<nome1>` se non esiste.)

Nome file: `<nome1>_idle.aseprite`.

Clicca Save.

> **Ripeto perche' e' importante**: il `.aseprite` e' il tuo file "sorgente" — tiene layer, tag, frame timing. Il PNG e' la versione "piatta" esportata. Senza il `.aseprite`, Renan non puo' piu' modificare nulla. **Salva sempre entrambi.**

### 8.14 Passo 13 — Ripeti per Walk, Interact, Rotate

Ripeti i passi 2-12 per le altre 3 animazioni:
- `<nome1>_walk.png` (canvas 92×115, 4 frame × 5 direzioni, timing 8 fps = 125 ms)
- `<nome1>_interact.png` (canvas 92×115, 4 frame × 5 direzioni, timing 6 fps = 166 ms)
- `<nome1>_rotate.png` (canvas diverso — vedi sotto)

### 8.15 Passo 14 — Rotate (animazione speciale)

Il rotate e' diverso: e' **un'unica striscia orizzontale** con 8 frame, uno per ogni direzione (mostra il personaggio che ruota su se stesso).

**Canvas**: `File → New` → Width `160`, Height `20`. Color Mode RGB, Background Transparent.

**Griglia**: `View → Grid → Grid Settings` → Width `20`, Height `20`.

**Layout**: 8 colonne × 1 riga = 8 frame da 20×20.

**Ordine delle direzioni (orario, partendo da `down`)**:

| Frame | X (px) | Direzione |
|-------|--------|-----------|
| 1 | 0-19 | down |
| 2 | 20-39 | down_side (diagonale giu'-destra) |
| 3 | 40-59 | side (destra) |
| 4 | 60-79 | up_side (diagonale su-destra) |
| 5 | 80-99 | up |
| 6 | 100-119 | up_side_sx (diagonale su-sinistra) |
| 7 | 120-139 | side_sx (sinistra) |
| 8 | 140-159 | down_side_sx (diagonale giu'-sinistra) |

> **Nota**: in questo caso **disegni anche le sinistre** (a differenza dei altri PNG), perche' questa animazione specifica mostra tutte e 8 le direzioni in sequenza nel rotate — il motore non puo' specchiare in un'animazione unica.

**Regola rotate**: ogni frame e' una pose statica, **hard cut** tra un frame e l'altro (niente pose intermedie di transizione).

**Timing**: 5 fps = 200 ms per frame.

**Export**:
- Sheet Type: `Horizontal Strip`
- Tutti gli altri settings Borders/Trim come sopra (tutto a zero, trim off).
- Output: `<nome1>_rotate.png` — dimensione finale **160×20**.

Salva sorgente: `<nome1>_rotate.aseprite`.

### 8.16 Passo 15 — Struttura Finale delle Cartelle

Alla fine del Task 2, la cartella del Personaggio 1 deve assomigliare a questa:

```
v1/assets/charachters/female/<nome1>/
├── aseprite_<nome1>/
│   ├── <nome1>_idle.aseprite
│   ├── <nome1>_walk.aseprite
│   ├── <nome1>_interact.aseprite
│   └── <nome1>_rotate.aseprite
├── <nome1>_idle.png         (92×115)
├── <nome1>_walk.png         (92×115)
├── <nome1>_interact.png     (92×115)
└── <nome1>_rotate.png       (160×20)
```

Se qualche file manca, il task non e' completo.

### 8.17 Passo 16 — Commit e Push

Apri GitHub Desktop. Vedrai tutti i nuovi file elencati.

**Commit**:
- Summary: `feat(assets): personaggio <nome1> - sprite completi (idle, walk, interact, rotate)`
- Description (opzionale): breve descrizione del personaggio.
- Clicca "Commit to main" (o al branch che hai creato — vedi sezione 14).
- Clicca "Push origin".

---

## 9. Task 3 — Personaggio 2 (6-10 ore)

Stesso identico procedimento del Task 2, con queste differenze:

| Dettaglio | Task 2 (Personaggio 1) | Task 3 (Personaggio 2) |
|-----------|------------------------|------------------------|
| Cartella | `v1/assets/charachters/female/<nome1>/` | `v1/assets/charachters/male/<nome2>/` |
| Sottocartella sorgenti | `aseprite_<nome1>/` | `aseprite_<nome2>/` |
| Nome file | `<nome1>_*.png` | `<nome2>_*.png` |
| Gender (per convenzione) | da concordare con Renan | da concordare — tipicamente opposto del primo |

Tutto il resto (canvas 92×115, griglia 23×23, 5 righe di direzioni, 4 frame, rotate 160×20, palette, export settings, frame tagging) e' identico al Task 2.

**Tempo di consiglio**: non fare entrambi i personaggi in parallelo. Finisci il primo, fai confermare a Renan che va bene, poi inizia il secondo. Cosi' se c'e' un problema sistemico (es: dimensione sbagliata) non lo replichi due volte.

**Commit finale**: `feat(assets): personaggio <nome2> - sprite completi (idle, walk, interact, rotate)`.

---

## 10. Task 4 — Gatto: Rifinitura Idle/Walk/Sleep (2-3 ore)

Il gatto esiste gia' nel progetto in formato 16×16 con 3 animazioni: idle, walk, sleep. Funzionano ma sono **statiche e poco vive**. Le rifiniamo.

### 10.1 Apri il Sorgente Esistente

In Aseprite: `File → Open` →
```
v1/assets/pets/aseprite_pets/cat_void_simple.aseprite
```

Verifica che il canvas sia **80×16** (5 frame da 16×16 in strip orizzontale).

### 10.2 Configura la Griglia per il Gatto

`View → Grid → Grid Settings` → Width `16`, Height `16`, X `0`, Y `0`.

### 10.3 Palette del Gatto

Il gatto "void" usa **solo 2 colori**: nero puro (`#0a0a0a` o simili) per il corpo + un colore chiaro (bianco o giallo tenue) per gli occhi.

> **Regola assoluta**: **zero grigio intermedio**. Il gatto e' una sagoma nera monolitica. Se aggiungi un secondo grigio per "sfumatura" o "ombra", rompi l'estetica. L'unico colore non-nero sul gatto sono i pixel degli occhi.

### 10.4 Rifinisci le 3 Animazioni

Per ogni animazione (idle / walk / sleep), applica le specifiche della sezione **12. Breakdown Pixel-per-Pixel** (sotto).

Lavora un'animazione alla volta:
1. Apri il sorgente o crea un nuovo sprite 80×16 se preferisci partire da zero.
2. Modifica i 5 frame seguendo le specifiche.
3. `Enter` per preview in Aseprite, controlla che il timing sia giusto.
4. Export → strip orizzontale, padding 0, trim off → sovrascrivi `cat_idle.png` / `cat_walk.png` / `cat_sleep.png` in `v1/assets/pets/`.
5. Salva sorgente: `v1/assets/pets/aseprite_pets/cat_idle.aseprite` (consiglio: separali in 3 file invece di uno unico — piu' facile gestire dopo).

### 10.5 Commit Task 4

GitHub Desktop → commit message: `fix(pets): rifinite animazioni idle/walk/sleep del gatto void`.

---

## 11. Task 5 — Gatto: 6 Nuove Animazioni (4-5 ore)

Ora crei 6 animazioni nuove, una per ogni file da zero.

Per ciascuna:
1. `File → New` → Width `80`, Height `16`, RGB Color, Transparent.
2. Carica palette (o prendi colore nero dai PNG del gatto esistenti).
3. Disegna 5 frame seguendo il breakdown della sezione 12.
4. Timeline: seleziona tutti i frame, `Frame Properties`, imposta durata in ms come specificato.
5. Export → strip orizzontale, padding 0, trim off → `cat_<anim>.png`.
6. Salva sorgente: `cat_<anim>.aseprite` in `v1/assets/pets/aseprite_pets/`.

Le 6 animazioni da creare:
- `cat_jump.png` + `cat_jump.aseprite`
- `cat_roll.png` + `cat_roll.aseprite`
- `cat_play.png` + `cat_play.aseprite`
- `cat_annoyed.png` + `cat_annoyed.aseprite`
- `cat_surprised.png` + `cat_surprised.aseprite`
- `cat_licking.png` + `cat_licking.aseprite`

**Ordine consigliato**: jump per primo (insegna squash/stretch, poi riusi la stessa tecnica negli altri). Roll per ultimo (e' il piu' difficile concettualmente).

### 11.1 Commit Task 5

GitHub Desktop → commit message: `feat(pets): aggiunte 6 nuove animazioni del gatto (jump, roll, play, annoyed, surprised, licking)`.

---

## 12. Breakdown Pixel-per-Pixel delle Animazioni del Gatto

**Legenda**:
- "Altezza" = distanza dal pixel piu' alto (orecchie) al pixel piu' basso (zampe) del gatto.
- "Larghezza" = distanza orizzontale tra i pixel piu' estremi del corpo.
- "Floor-anchor" = il pixel piu' basso centrale del gatto. Durante idle/walk/sleep **non deve muoversi orizzontalmente** (altrimenti il gatto sembra scivolare).
- Default baseline: altezza 14, larghezza 12 (lascia 1-2 px di margine nel canvas 16×16).

### 12.1 IDLE (cat_idle.png) — 4 fps, 250 ms/frame — LOOP

**Vibe**: vivo ma fermo. Il gatto respira.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Baseline. Occhi 1 px ciascuno. |
| F2 | 15 | 12 | Inspira: +1 px alto della testa. Orecchie invariate. |
| F3 | 15 | 13 | Peak inspira: +1 px pancia (width 13). |
| F4 | 14 | 12 | Ritorno. Orecchia sinistra scende 1 px (twitch). |
| F5 | 14 | 12 | Baseline. **Occhi dash** per 1 frame (blink). Poi loop a F1. |

**Evita**: movimento orizzontale del body; tail flick a ogni loop (fa troppo — metti tail flick solo 1 loop su 3).

### 12.2 WALK (cat_walk.png) — 8 fps, 125 ms/frame — LOOP

**Vibe**: gatto in top-down che cammina. Le zampe non si vedono come zampe intere — sono "nub" di 1 pixel che escono alternativamente dalla silhouette.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Contact: nub 1 px in basso-sinistra + nub 1 px in alto-destra (coppia diagonale A). |
| F2 | 13 | 12 | Passing: mid-swing, nub rientrati nella silhouette. |
| F3 | 14 | 12 | Contact: coppia diagonale B — nub 1 px in basso-destra + nub 1 px in alto-sinistra. |
| F4 | 13 | 12 | Passing: nub rientrati, tail spostata 1 px nel lato opposto del body bob. |
| F5 | 14 | 12 | Come F1 ma tail spostata dall'altro lato (cosi' il ciclo tail ha periodo 2× del ciclo gambe). |

**Evita**: 4 gambe tutte visibili nello stesso frame (gatto mutante); F2 e F4 identici (tail deve differire); floor-anchor che salta orizzontalmente di 2+ px.

### 12.3 SLEEP (cat_sleep.png) — 2-3 fps, 333-500 ms/frame — LOOP

**Vibe**: palla arrotolata, respiro lento, occhi spenti.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 10 | 14 | Palla schiacciata. **Occhi OFF** (pixel neri). Coda avvolta (aggiunge 1-2 px su un lato). |
| F2 | 10 | 14 | Come F1, +1 px pancia (inspira). |
| F3 | 10 | 15 | Peak inspira: width 15. Opzionale: pixel "Z" (2 pixel bianchi sopra la testa). |
| F4 | 10 | 14 | Pancia torna a 14, "Z" dissolve. |
| F5 | 10 | 14 | Come F1. |

**Evita**: occhi aperti (errore da principianti #1); posa eretta; fps veloce (il sonno e' LENTO); movimento della coda (coda dorme anche lei).

### 12.4 JUMP (cat_jump.png) — 12-15 fps, 66-83 ms/frame — NON-LOOP (torna a idle dopo)

**Vibe**: anticipazione netta, stacco aereo, atterraggio schiacciato.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Crouch neutro (come idle baseline). |
| F2 | 11 | 14 | **ANTICIPATION squash**: compressione verticale, width spread. Occhi **2×2 wide**. Orecchie schiacciate -1 px. |
| F3 | 16 (clip) | 10 | **PEAK stretch aereo**. Stretch verticale massimo: ideale height 20 ma noi siamo limitati al canvas 16×16 — **clip a 16** e **solleva il floor-anchor di 1 px** (unica animazione dove e' permesso). Narrow width 10. |
| F4 | 11 | 15 | **LANDING squash**: schiacciato largo. Frame piu' largo del ciclo. Occhi tornano a 1 px. |
| F5 | 13 | 12 | Recovery: altezza intermedia. Occhi normali. Poi engine torna a idle. |

**Evita**: stretch e squash con stessa altezza (azzera il contrasto = morto); occhi 1 px costanti (widen su F2!); floor-anchor piantato in F3 (il gatto DEVE staccare da terra).

### 12.5 ROLL (cat_roll.png) — 10-12 fps, 83-100 ms/frame — NON-LOOP o loop 2×

**Vibe**: rotolamento top-down (il gatto si gira su se stesso 360°, vista dall'alto). 72° per frame se fai full 360 in 5 frame; 45° se fai mezzo giro.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Idle-forward: orecchie in alto, coda in basso. |
| F2 | ~14 | ~13 | 45° ruotato: orecchie in alto-destra, coda in basso-sinistra. **Occhi OFF** (faccia verso il pavimento). |
| F3 | 13 | 14 | 90° (di lato): sagoma orizzontale. Un'orecchia visibile a destra, coda a sinistra. **Occhi OFF**. |
| F4 | ~14 | ~13 | 135° (mirror di F2). **Occhi OFF**. |
| F5 | 14 | 12 | 180° rovesciato: orecchie in basso, coda in alto. **Occhi riappaiono** (la faccia torna verso l'alto). |

**Evita**: deformazione body durante rotazione (tienilo circolare — nessun squash/stretch durante il roll, altrimenti si confonde); occhi visibili in ogni frame (devono sparire quando la faccia e' verso il basso).

### 12.6 PLAY (cat_play.png) — 10-12 fps, 83-100 ms/frame — LOOP 2-3× poi idle

**Vibe**: gatto giocoso che si avventa su qualcosa. Zampata anteriore che esce.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 13 | 12 | Idle leggermente accucciato. |
| F2 | 14 | 12 | Wind-up: parte posteriore si alza (tail +1 px), occhi a **dash** (strizzati in concentrazione). |
| F3 | 13 | 14 | **STRIKE**: body si allunga avanti 2 px orizz, un pixel "paw" esce dal fronte-sinistra. Occhi **2×2 wide**. Hold 2 tick (durata doppia del normale). |
| F4 | 13 | 12 | Retract: paw rientra, body torna. |
| F5 | 13 | 12 | Wiggle: body shifta 1 px destra, coda flicka 2 px sinistra. Poi loop a F2. |

**Evita**: paw fuori in entrambi i frame 2 e 3 (uccide l'impatto dello strike — paw DENTRO su wind-up, FUORI su strike, DENTRO su retract); F2 e F4 identici.

### 12.7 ANNOYED (cat_annoyed.png) — 6-8 fps, 125-166 ms/frame — LOOP o single-shot

**Vibe**: orecchie schiacciate, occhi stretti, coda che sbatte. Corpo FERMO (non si sposta).

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Baseline con occhi = **dash orizzontale 1 px** (strizzati). Orecchie schiacciate -1 px. |
| F2 | 14 | 12 | Coda lashing sinistra: pixel coda si sposta 2 px a sinistra, body si tilta 1 px a destra in compensazione. |
| F3 | 14 | 12 | Coda lashing destra: mirror di F2. Hold 1 tick extra. |
| F4 | 14 | 12 | Coda lashing sinistra di nuovo (ma 1 px invece di 2). Orecchie ancora piu' piatte (-1 px ulteriore). |
| F5 | 15 | 12 | Body "puff up" +1 px altezza per 1 frame (spavento/tensione). |

**Evita**: occhi wide (quello e' surprise, non annoyed); locomozione (annoyed = fermo); body deformation grandi ogni frame.

### 12.8 SURPRISED (cat_surprised.png) — 14-16 fps, 60-70 ms/frame — NON-LOOP

**Vibe**: startle acuto. Pop di 1 frame, poi settling. Il piu' veloce.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Baseline idle. |
| F2 | 16 (clip) | 10 | **STARTLE pop**: altezza +3 px teorici (clip a 16, lift floor-anchor 1 px), narrow width 10. Occhi **2×2 wide** con 1 px bianco highlight al centro. Orecchie dritte in su +1 px. |
| F3 | 16 | 10 | Hold dello startle: floor torna a terra, altezza 16. Occhi ancora wide. (Il frame "il gatto vede il fantasma".) |
| F4 | 12 | 13 | Recoil: si schiaccia basso. Occhi ancora wide (2×2) ma senza highlight. |
| F5 | 14 | 12 | Settle: torna baseline, occhi 1 px ma posizionati 1 px piu' alti sulla testa (vigile). |

**Evita**: fps lento (distrugge lo startle — DEVE essere veloce); occhi 1 px costanti (il wide e' tutta l'anima dell'anim); body stessa altezza in tutti i frame (senza silhouette change non c'e' sorpresa).

### 12.9 LICKING / GROOMING (cat_licking.png) — 4-5 fps, 200-250 ms/frame — LOOP 2-3× poi idle

**Vibe**: lento, ripetitivo. Testa si piega verso il corpo. Pacifico.

| Frame | Altezza | Larghezza | Note |
|-------|---------|-----------|------|
| F1 | 14 | 12 | Idle pose, occhi **semichiusi** (1 px a Y=8 invece che Y=7 — aspetto assonnato). |
| F2 | 14 | 12 | Head-tilt: top della testa si sposta 1 px verso un lato (es: destra). Orecchia destra scende 1 px. Occhi OFF. |
| F3 | 13 | 12 | **LICK peak**: testa "giu'" contro il corpo. Silhouette compatta, un'orecchia visibile. Opzionale pixel "lingua" (1 px in color off-white) sul lato leccato; in alternativa un **indent** 1 px nella silhouette al posto della bocca. Hold 1 tick extra. |
| F4 | 14 | 12 | Head-retract: come F2 ma senza lingua. |
| F5 | 14 | 12 | Testa torna al centro, occhi sempre semichiusi. Loop. |

**Evita**: occhi wide aperti (rompe la vibe serena); fps veloce (licking e' lento); animazione simmetrica (la testa si piega in UN lato, non alternati).

---

## 13. Checklist Finale (prima di pushare)

Prima di fare il commit definitivo di un task, controlla **tutti** questi punti sul tuo lavoro. Almeno uno di questi salva un'ora di re-work.

### 13.1 Checklist Generale (personaggi e gatto)

- [ ] **Test silhouette**: riempi di nero il frame, si riconosce il personaggio e la direzione?
- [ ] **Dimensioni PNG corrette**: trascinalo in Aseprite e controlla — `92×115` per idle/walk/interact personaggi, `160×20` per rotate personaggi, `80×16` per tutti i gatti.
- [ ] **Salvato anche il `.aseprite`**, non solo il PNG?
- [ ] **Palette**: zero colori fuori dalla palette caricata?
- [ ] **Nome file** rispetta la convenzione (`<nome>_<anim>.png`, lowercase, underscore)?
- [ ] **Cartelle nei percorsi giusti**?

### 13.2 Checklist Personaggi Specifici

- [ ] Ho disegnato **solo 5 direzioni** (down, vertical_down, side, vertical_up, up)? Non ho disegnato le versioni `_sx`?
- [ ] **Piede anteriore in Contact**: pixel piu' basso tocca la riga 22 della cella (zero aria sotto)?
- [ ] **Onion Skin Contact→Down**: il piede d'appoggio resta sulla stessa Y (zero glide)?
- [ ] **Lunghezza gambe costante** tra i 4 frame (±1 px solo ginocchio piegato in Down)?
- [ ] **Head bob** +1 px in Passing, -1 px in Down (sincronizzato col torso)?
- [ ] **Braccia in opposizione** con le gambe (destra-sinistra, sinistra-destra)?
- [ ] **Frame diagonali**: braccio lontano parzialmente occluso (o nascosto)?
- [ ] **3 toni per materiale** (ombra/midtone/highlight — no 2, no 5)?
- [ ] **Zero AA** su diagonali 45° e linee dritte?
- [ ] **Zero banding**?
- [ ] **Rotate**: ordine **orario partendo da down**? Hard cut tra frame?
- [ ] **Durata frame**: 200 ms per idle (5 fps), 125 ms per walk (8 fps), 166 ms per interact (6 fps), 200 ms per rotate?

### 13.3 Checklist Gatto Specifico

- [ ] Body = **1 solo colore nero**, zero grigio intermedio?
- [ ] Eyes = **1-2 px**, forma coerente con l'emotion richiesta (dot/dash/2×2)?
- [ ] **Floor-anchor** (pixel piu' basso centrale) non si muove orizzontalmente durante idle/walk/sleep?
- [ ] **Sleep**: eyes OFF (neri)?
- [ ] **Roll**: eyes OFF in F2/F3/F4 (pancia in su)?
- [ ] **Jump**: F3 ha floor-anchor sollevato 1 px (in aria)?
- [ ] **Surprised / Jump**: occhi 2×2 wide su F2?
- [ ] **Annoyed**: zero locomozione, body fermo, coda lashing?

Se anche un solo punto non e' verificato, **torna a lavorare** prima di committare.

---

## 14. Workflow Git per Alex (GitHub Desktop)

Hai installato GitHub Desktop (sezione 5.2). Ecco come usarlo giorno per giorno.

### 14.1 Prima di Iniziare a Lavorare (ogni sessione)

Apri GitHub Desktop → click `Fetch origin` in alto. Poi se ci sono aggiornamenti appare `Pull origin`: clicca anche quello.

**Perche'**: altri del team (Renan, Elia, Cristian) potrebbero aver committato modifiche — tu parti dall'ultima versione.

### 14.2 Lavora in Aseprite

Disegna. Esporta. Salva `.aseprite`. Ripeti.

### 14.3 Opzione A: Push Diretto su Main (progetti piccoli)

Dato che siamo in 4 e il progetto e' piccolo, Renan ha ok-ato il push diretto su `main` per i tuoi asset (non e' codice, non puoi causare bug di runtime).

Quando hai completato **un task intero** (es: personaggio 1 completo), in GitHub Desktop:

1. Pannello "Changes" in alto a sinistra: vedi tutti i file nuovi/modificati. **Controlla**: devono esserci solo file in `v1/assets/`, niente di piu'.
2. Casella "Summary" in basso: scrivi il commit message con la convention:
   - `feat(assets): ...` per file nuovi.
   - `fix(pets): ...` per rifiniture del gatto.
   - `docs(guide): ...` se mai modifichi questa guida.
3. Casella "Description" (opzionale): 1-2 righe di contesto.
4. Clicca `Commit to main`.
5. In alto appare `Push origin`: cliccaci.

Fatto. Il tuo lavoro e' online.

### 14.4 Opzione B: Branch + Pull Request (se preferisci prudenza)

Se non ti senti sicuro di pushare direttamente su main, usa un branch:

1. In alto: `Current branch: main` → dropdown → `New Branch`.
2. Nome: `assets/<task>` (es: `assets/char-maria-idle`, `assets/cat-jump`).
3. OK → `Publish branch`.
4. Lavora, committa sul branch (stessi passaggi di sopra ma su branch invece di main).
5. Clicca `Create Pull Request`: ti apre la pagina GitHub nel browser.
6. Titolo PR: come il commit.
7. Descrizione: elenco file e animazioni.
8. Clicca "Create pull request".
9. Renan riceve notifica, guarda il lavoro, approva e merge.

### 14.5 Convention dei Commit Message

Usa questi prefissi:

| Prefisso | Quando | Esempio |
|----------|--------|---------|
| `feat(assets):` | Nuovi asset | `feat(assets): personaggio Maria - idle e walk` |
| `fix(pets):` | Correzioni / rifiniture | `fix(pets): rifinita idle del gatto (ear twitch + blink)` |
| `feat(pets):` | Nuove animazioni gatto | `feat(pets): aggiunta animazione jump del gatto` |
| `docs(guide):` | Modifiche a questa guida | `docs(guide): corretto passo 8.11 export sprite sheet` |

### 14.6 Cosa NON Committare

- File temporanei di Aseprite (tipo `~nomefile.aseprite` con tilde davanti — backup automatici).
- File di altri progetti dentro la cartella per errore.
- File enormi (>10 MB per `.aseprite` — se ti capita, chiedi a Renan come gestirlo).

GitHub Desktop in genere ignora i temporanei automaticamente.

---

## 15. Cosa Puo' Andare Storto (24 Trappole)

Raccolta di tutti gli errori che potresti fare, organizzata per fonte. Se qualcosa non ti torna durante il lavoro, cerca qui la spiegazione.

### 15.1 Trappole Aseprite (10)

1. **Color Mode Indexed per sbaglio** → aprendo un PNG in Indexed, colori troncati silenziosamente. **Fix**: `Sprite → Color Mode → RGB Color` sempre.
2. **Pencil non attivo (Brush al suo posto)** → bordi anti-aliased automatici. **Fix**: premi `B`, controlla Context Bar dice "Pencil".
3. **Pixel-Perfect disattivato** → doppi pixel agli angoli delle linee. **Fix**: checkbox "Pixel-perfect" in Context Bar quando Pencil e' attivo.
4. **Ink non Simple** → dither accidentale o comportamento strano. **Fix**: Context Bar → Ink dropdown → `Simple Ink`.
5. **Anti-alias attivo in Marquee/Wand** → selezioni sfumate. **Fix**: tutte le opzioni "Anti-alias" off.
6. **Color wheel invece di palette** → drift colori nel tempo. **Fix**: clicca SOLO i colori nel Palette Panel a sinistra. Per riprendere un colore usato: `Alt+click` sul pixel.
7. **Export con Trim attivo** → celle non piu' uniformi, Godot non sa dove tagliare. **Fix**: Export Sprite Sheet → tab Borders → Trim Sprite/Cels UNCHECK entrambi.
8. **Export con padding >0** → Rect2 Godot shiftati, sprite rotti in gioco. **Fix**: tutti i padding a `0`.
9. **Dimenticato `Ctrl+S` sull'aseprite** → esportato PNG ma sorgente mai salvato. Modifiche future impossibili. **Fix**: dopo ogni export, sempre `Ctrl+S`.
10. **Canvas 93×116 invece di 92×115** → 1 px "morto" per lato nel PNG finale. **Fix**: canvas 92×115 (4×23=92, 5×23=115, matematica pulita).

### 15.2 Trappole Personaggi (5)

11. **Disegnate versioni `_sx` (sinistra)** → ore sprecate, il motore le mirror-a automaticamente. **Fix**: solo 5 direzioni (down, vertical_down, side, vertical_up, up). Escluso il rotate che richiede tutte e 8.
12. **Feet glide** → piede d'appoggio si muove orizzontalmente tra Contact e Down. Risultato: sembra scivolare sul ghiaccio. **Fix**: onion skin (F3), piede d'appoggio stesse coordinate X,Y nei due frame.
13. **Testa statica mentre il corpo bobba** → decoupling visibile, aspetto da manichino. **Fix**: testa sale/scende insieme al torso, ±1 px sincronizzato.
14. **Diagonali con entrambe le braccia visibili** → rompe la prospettiva top-down. **Fix**: nelle vertical_*, il braccio lontano e' parzialmente o totalmente occluso dal torso.
15. **Rotate con ordine sbagliato** → il gioco ruota "a scatti" invece che fluido. **Fix**: ordine **orario partendo da down**: down → down_side → side → up_side → up → up_side_sx → side_sx → down_side_sx.

### 15.3 Trappole Gatto Void (9)

16. **Strobe outline** → il bordo del body cresce 1 px random tra frame, lampeggia invece di animare. **Fix**: i cambi di outline seguono una curva chiara (es: 16-14-12-14-16), non oscillazioni casuali.
17. **4 gambe tutte visibili in top-down walk** → gatto mutante. **Fix**: gambe come "nub" di 1 px che escono alternate (coppia diagonale A frame 1, coppia B frame 3, rientrate in F2 e F4).
18. **Eyes aperti durante sleep** → classico errore primo giorno. **Fix**: sleep = occhi pixel nero (OFF), i cat-pixel-artists a volte mettono anche una "Z" sopra la testa per leggibilita'.
19. **F2 e F4 identici** (walk, play, qualsiasi loop) → il ciclo sembra meccanico come un GIF 2-frame. **Fix**: differenzia di almeno 1 px (tail position, ear twitch).
20. **Eye pixel wandering** → occhi che si spostano di 1 px random ad ogni frame. Sembra rumore. **Fix**: occhi a posizione fissa salvo blink/wide/closed intenzionali.
21. **Over-animated idle** → body deformation grosse in idle. Il gatto sembra in convulsione. **Fix**: idle = ±1 px altezza max, tail flick solo ogni 2-3 loop.
22. **Niente hold frame sui peak** → jump e surprise passano troppo velocemente sul frame piu' espressivo. **Fix**: F3 di jump e F2/F3 di surprised hanno durata DOPPIA (es: 130 ms invece di 66 ms).
23. **Secondo grigio aggiunto per shading** → rompe l'estetica void. **Fix**: solo nero puro + occhi. Nessun grigio intermedio.
24. **Floor-anchor sliding** → pixel centrale-basso del gatto trasla orizzontalmente durante idle/sleep. Il gatto "galleggia". **Fix**: blocca quel pixel: non deve spostarsi in X tra frame (salvo walk, dove comunque si muove poco e solo avanti).

---

## 16. Protocollo di Comunicazione

Se sei bloccato o in dubbio:

1. **Prima rilleggi la sezione specifica** di questa guida (c'e' un indice all'inizio).
2. **Controlla le trappole** (sezione 15).
3. Se il problema persiste: **scrivi a Renan** su Telegram / Discord / WhatsApp con:
   - **Screenshot della finestra Aseprite** (o del problema in gioco).
   - **Cosa stavi facendo** (1-2 righe).
   - **Cosa ti aspettavi** vs **cosa vedi** (1 riga ciascuno).

Esempio messaggio perfetto:
> Ciao Renan, sto esportando l'idle del personaggio 1 ma il PNG esce 372×580 invece che 92×115. [screenshot]
> Stavo in Export Sprite Sheet, Sheet Type By Rows, Fixed Columns 4, tutti i padding a 0.
> Mi aspettavo 92×115.

Con un messaggio cosi' Renan ti risponde in 3 minuti. Senza contesto, in 30.

**Niente panico**: ogni bug pixel-art ha una spiegazione pixel-level. Si trova sempre.

---

## 17. Risorse Utili (studia questi prima di disegnare)

Ti raccomando **caldamente** di aprire almeno 3-4 di questi link prima di iniziare il Task 2. Non serve "studiare tutto": basta 30-60 minuti a sfogliare le immagini e i GIF per farti entrare nella testa come si muovono le cose a questa scala.

### 17.1 Pixel Art Fundamentals

Le migliori guide in circolazione. Iniziare da Slynyrd Pixelblog Catalogue e leggere i post #22 e #50.

- https://www.slynyrd.com/pixelblog-catalogue — indice completo di tutti i Pixelblog (start here)
- https://www.slynyrd.com/blog/2019/10/21/pixelblog-22-top-down-character-sprites — personaggi top-down (fondamentale)
- https://www.slynyrd.com/blog/2024/5/24/pixelblog-50-human-walk-cycle — walk cycle umano
- https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation — animazione top-down
- https://saint11.art/pixel_articles/ — serie tutorial Pedro Medeiros (legendary)
- https://lospec.com/pixel-art-tutorials/walk-cycle-by-pedro-medeiros
- https://lospec.com/pixel-art-tutorials/8-directional-turn-around-by-sandy-gordon

### 17.2 Aseprite (documentazione ufficiale)

Se ti si incastra qualcosa in Aseprite, la risposta e' quasi sempre qui.

- https://www.aseprite.org/docs/ — indice documentazione
- https://www.aseprite.org/docs/animation/ — come fare animazioni
- https://www.aseprite.org/docs/tags/ — come usare i tag
- https://www.aseprite.org/docs/sprite-sheet/ — export sprite sheet (leggi con attenzione)
- https://www.aseprite.org/quickref/ — cheat-sheet shortcut completa

### 17.3 Asset Pack di Riferimento — Personaggi 8 Direzioni

Asset gia' pronti (gratuiti) che puoi scaricare, importare in Aseprite e **studiare pixel per pixel** per capire come sono fatti.

- https://maytch.itch.io/free-16x16-pixel-art-8-directional-characters — personaggi 16×16 multi-direzione (free)
- https://cainos.itch.io/pixel-art-top-down-basic — pacchetto top-down base
- https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles — LPC: la "bibbia" del top-down, centinaia di personaggi compatibili

### 17.4 Asset Pack di Riferimento — Gatto Void 16×16

Per il gatto **apri questi due** prima di ogni animazione gatto:

- https://bowpixel.itch.io/cat-anim-16x16-black — gatto nero 16×16, stile quasi identico al nostro (perfetto per studiare idle/walk)
- https://carysaurus.itch.io/black-cat-sprites — 32×32 ma con 12 animazioni complete (jump, pounce, sleep, hurt, eat, meow) — scale-down mentalmente. **Fonte #1 per jump/pounce/sleep.**

Altri pack utili:
- https://seethingswarm.itch.io/catset
- https://opengameart.org/content/cat-sprites (CC0, libero)
- https://opengameart.org/content/cat-fighter-sprite-sheet (32×32, keypose jump/attack — ottimo per capire squash/stretch a scala maggiore)

### 17.5 Video Tutorial (YouTube)

Cerca questi canali:
- **MortMort** — pixel art tutorials brevi e pratici.
- **Pedro Medeiros** (Saint11) — master tutorial, alcuni anche in portoghese.
- **AdamCYounis** — corso gratuito ultra completo su pixel art.

---

**Fine della guida.**

Se hai dubbi prima ancora di iniziare, **scrivi a Renan**. Se qualcosa non funziona durante il lavoro, cerca nella sezione 15 (trappole) — quasi sicuramente il problema e' li'.

Grazie, Alex — il lavoro che farai entrera' nel gioco che vedono gli altri. Non e' scontato, e te ne siamo grati.
