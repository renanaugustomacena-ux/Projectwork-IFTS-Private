# Espansione gameplay — pulizia a tempo, negozio, gatto vivo, slot, sedie

> Data: 2026-08-14 · Stato: approvato in chat (fasi 1-5, ordine confermato)
> Principi guida: corso "Ingegneria del Software Elite" — modulo 11 (data-driven),
> 14 (FSM), 23 (valida ai confini), 12 (accumulatore temporale). Vincolo del
> corso IFTS: niente over-engineering — ogni fase piccola, finita, dimostrabile.

## Fase 1 — Economia: pulizia a tempo + negozio

**Modello scelto: "avvia e lascia".** Il player preme E sullo sporco → un
secondo di animazione interact → parte la pulizia con `cleaning_ends_at =
now + durata / moltiplicatore_attrezzo` (timestamp reale Unix, NON un timer:
sopravvive al riavvio ricalcolando dall'orologio). Barra di progresso
disegnata sopra lo sporco. Coins e sollievo stress al completamento, con
toast. Pulizie parallele consentite.

**Dati.** `mess_catalog.json` per-voce: `clean_duration_sec`, `clean_reward`
riscalato (briciole 7s/+2 → piatto 600s/+12) + nuova voce rara
`stubborn_stain` 3600s/+40. Nuovo `data/shop.json`:
- `food_player`: id, prezzo, `stress_relief` (punti 0-100 → /100 interno).
  tisana 8/−10, zuppa 15/−25, torta 25/−40.
- `food_cat`: croccantini, 10 coins/porzione.
- `tools`: `speed_multiplier` permanente — straccio ×1.5/30, scopa ×2/80,
  aspirapolvere ×4/200. A mani nude ×1. Vale il migliore posseduto.

**Persistenza.** SAVE_VERSION 5.0.0 → **5.1.0**; migrazione aggiunge
`room.messes: []` e `pet: {trust: 0, next_potty_at: 0, last_meal_at: 0}`.
SaveManager tiene `_messes` come `_decorations` (add/remove + dirty).
Al load: mess sconosciuti scartati con warning, posizioni clampate,
`ends_at` nel passato → sporco già pulito, coins accreditati con toast
"pulizia completata mentre eri via". Il mirror SQLite NON include i mess
(stato effimero locale, nessun valore cloud) — documentato qui.

**Negozio.** Pannello "Negozio" nel PanelManager (`shop` →
`scenes/ui/shop_panel.tscn`), bottone HUD accanto a Decora. Acquisto =
prima sottrazione di coins del gioco: ricontrollo saldo al click, rifiuto
con toast se insufficiente, "Acquistato" sugli attrezzi posseduti.
`inventory.items` = `[{id, qty}]`. Cibo player: bottone "Mangia" nel
pannello → segnale `player_ate` → animazione interact + `StressManager.
apply_delta(-relief/100)` + qty−1.

**Ciotola gatto.** "Dai da mangiare" (qty>0) → `pet_feed_requested(pos)` →
room_base posa una ciotola (placeholder generato, clampata nel pavimento,
z per piedi; una sola alla volta) → stato `EAT` del gatto: cammina alla
ciotola, mangia ~10s, ciotola via, `pet_fed` emesso. Hook esplicito
commentato per la fase 2.

**Difese.** Catalogo shop rotto → warn + negozio vuoto, mai crash.
`ends_at` assurdo → clamp alla durata massima da catalogo.

## Fase 2 — Confidenza del gatto (trust 0..100, persistita in `pet.trust`)

**Fonti.** (a) Pasto consumato: +8, ma solo se il gatto "ha fame" (≥4h
dall'ultimo pasto, `pet.last_meal_at` — anti-spam ed è tematico). (b)
Tempesta: player entro 150px dal gatto con mood ≤ soglia stormy → +1 ogni
10s ("impara che con te è al sicuro").

**Effetti sulla FSM esistente (parametri, non stati nuovi salvo AVOID).**
- trust < 20: stato `AVOID` — se il player si avvicina sotto 100px, il
  gatto si allontana. Niente FOLLOW spontaneo.
- 20-69: comportamento attuale.
- ≥ 70: FOLLOW più frequente e più stretto (stop distance ridotta); durante
  WILD ogni tanto corre DAL player e si calma finché gli è vicino.
- ≥ 90: SLEEP sceglie un punto vicino al player; FOLLOW quasi costante.
`pet_trust_changed(value)` per l'HUD futuro (non UI in questa fase, solo log).

## Fase 3 — Giardino + bisogni fisiologici

**Zone.** Helpers generalizza il poligono: registro zone nominate
(`register_zone/clamp_inside_zone/is_inside_zone`); `floor` resta l'API
esistente. main.tscn aggiunge `GardenZones` (CollisionPolygon2D data-only,
NON fisica): fascia frontale + fasce laterali del piazzale — mai sopra i
muri dipinti (limite superiore = base visiva dei muri esterni).

**Uscita.** Stato `ROAM_GARDEN`: il gatto disattiva la collisione coi muri
(mask 0), cammina fino a un punto della zona giardino (clamp di zona in
codice, come WANDER), gironzola, poi rientra e riattiva mask 1. Le pareti
del confine stanza valgono solo per chi è "dentro".

**Bisogni.** `pet.next_potty_at` (unix): ogni 6h ±1h. Alla scadenza:
- mood > soglia stormy → va in giardino, si accuccia 3s, nessuno sporco.
- tempesta (mood ≤ stormy) → la fa IN STANZA: nuova voce mess `cat_poop`
  (1800s/+20, stress_weight alto, sprite placeholder).
**Offline (accumulatore temporale, modulo 12).** Al load: bisogni maturati
da `last_saved` (cap 4/giorno, max 8 accumulati). Se il mood salvato era
stormy → diventano sporchi in stanza in posizioni casuali; altrimenti
giardino (nessuna traccia). Con le pulizie-offline della fase 1, il rientro
dopo ore racconta una storia: sporco nuovo, pulizie finite.

## Fase 4 — 10 slot di salvataggio + bottone salva

**Struttura.** `user://slots/slot_NN/` (NN=01..10) contiene save_data.json,
ring di backup, quarantena — TUTTA la logica HMAC/ring esistente, solo con
prefisso directory risolto una volta al boot. `user://active_slot.cfg`
(testo semplice) ricorda lo slot attivo; `user://integrity.key` resta
globale (chiave per-installazione). Migrazione: al primo boot con slot,
il vecchio save + ring viene spostato in slot_01.

**UI.** "Carica Partita" → schermata slot: 10 righe con anteprima (nome
personaggio, data ultimo salvataggio, coins — letti via _peek_save_payload,
mai applicati), Carica / Elimina (con conferma); righe vuote → "Nuova
partita". "Nuova Partita" dal menu usa il primo slot libero. In gioco:
bottone "Salva" nell'HUD → save_game() + toast "Salvato".

**Limite documentato.** Il mirror SQLite e la sync cloud restano sullo
slot attivo (il DB si riscrive al cambio slot via apply_save). I salvataggi
JSON per-slot sono l'autorità.

## Fase 5 — Sedie (sedersi/guidare) + polish animazioni

**Dati.** Catalogo: `sittable: true` (tutte le sedie/poltrone),
`rideable: true` solo sedie da ufficio con rotelle (OfficeChair_1..4,
kenney_chair_desk). `seat_offset` opzionale.

**SIT.** E vicino a una sedia sittable → il personaggio si aggancia al
punto seduta (piedi sull'ancora, z sopra la sedia), animazione idle_down
(illusione: lo schienale copre le gambe — senza sprite dedicati è il
compromesso possibile). Input di movimento: sedia normale → si alza;
sedia con rotelle → SEDIA+personaggio si muovono insieme a velocità
ridotta (80), la posizione della sedia si salva allo smontaggio. E → alzati.

**Polish procedurale (nessuna arte nuova).** Velocità walk-anim
proporzionale alla velocità reale; respiro sottile in idle; squash del
gatto al cambio direzione; interact all'avvio pulizia e quando mangia;
head-bob del gatto su EAT.

**Lista arte per il team (sbloccherebbe):** personaggio seduto 4 direzioni,
gatto che mangia (3-4 frame), gatto accucciato bisogni, loop "pulisce",
ciotola e croccantini disegnati, cacca stilizzata carina.

## Trasversali

- Segnali nuovi in SignalBus (gruppo Economia/Pet): `mess_cleaning_started`,
  `shop_item_purchased`, `player_ate`, `pet_feed_requested`, `pet_fed`,
  `pet_trust_changed`, `pet_pottied(indoor)`, `save_slot_changed`.
- i18n: chiavi nuove in locale/it.po + en.po per negozio, toast, slot.
- CI: validate_json_catalogs esteso a shop.json e ai campi nuovi dei mess.
- Test: nuovi moduli test_shop, test_cleaning, test_trust, test_needs,
  test_slots (+ estensioni dove serve). Suite sempre verde tra le fasi.
- Versione finale: 1.2.0 sincronizzata (project.godot, constants, preset).

## Fuori scope (YAGNI, esplicito)

Fame/energia del player, attrezzi consumabili, sporco che cresce, negozio
per decorazioni (restano gratis), effetti meteo reali (la "tempesta" è il
mood slider come oggi), multiplayer/cloud per-slot, arte nuova.
