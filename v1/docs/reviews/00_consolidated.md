# Consolidated Review — Relax Room (2026-04-16)

5 skill review eseguite in sequenza: design-review, devsecops-gate, correctness-check, resilience-check, complexity-check.
Totale issue aggregate: **68** (3 CRITICAL, 21 HIGH, 27 MEDIUM, 17 LOW).

## Confronto con `CONSOLIDATED_PROJECT_REPORT.md` (audit manuale precedente)

### Conferme (review automatiche confermano audit manuale)

| Bug ID | Area | Conferma review |
|---|---|---|
| B-001 | Movimento char (focus chain) | design-review A, complexity-check #1 (virtual_joystick rischio correlato) |
| B-002 | Drag&drop silent | correctness-check #2 confermato `room_base.gd:94-96` |
| B-003 | Tab DecoPanel | complexity-check (fix gia pronto) |
| B-014 | Dead var `_last_select_error` | correctness-check rivisto: target e `_select()` non `_execute()` |
| B-016 | JSON/SQLite divergenza | devsecops-gate Phase 2 data classification |
| B-018 | Logger buffer unbounded | resilience-check #1 |
| B-019 | Supabase token plaintext | devsecops-gate Phase 3 + design-review C |
| B-020 | HTTPS no validation | devsecops-gate Phase 2 |
| B-021 | Retry no backoff | resilience-check #3 |
| B-022 | `cloud_to_local` dead code | complexity-check sez 4 |

### Nuove findings (non nel tracker originale)

| ID proposto | Area | Severity | Skill |
|---|---|---|---|
| **B-025** | `supabase_http._queue` unbounded in RAM | HIGH | resilience-check |
| **B-026** | SQLite `busy_timeout` pragma mancante | MEDIUM | resilience-check |
| **B-027** | `_select()` silent query fail (reclassified da B-014) | CRITICAL | correctness-check |
| **B-028** | AppLogger **no redaction** context dict | HIGH | devsecops-gate |
| **B-029** | PBKDF2 10k iter (sotto OWASP 600k) | HIGH | devsecops-gate |
| **B-030** | `virtual_joystick` addon + scene dead code + **rischio attivo B-001** | HIGH | complexity-check |
| **B-031** | `.pre-commit-config.yaml` **MANCANTE** (doc dichiara esistente) | HIGH | devsecops-gate |
| **B-032** | Non-determinism pet_controller / audio_manager (no RNG seed) | MEDIUM | correctness-check |
| **B-033** | `local_database.gd` 810 righe viola max 500 dichiarato | MEDIUM | complexity-check |
| **B-034** | Supabase schema cloud (15 tabelle) **non versionato** in `supabase/migrations/` | HIGH | design-review B |

### Correzioni fattuali

- **Numero segnali**: 43 totali (verificato in `signal_bus.gd`). Report originale dice 41, pptx 33, presentazione 43, explore agent 51. **Source of truth = 43**.
- **Numero autoload**: 10 (non 9). `StressManager` e il 10°, non menzionato in `CONSOLIDATED_PROJECT_REPORT.md` sez 3.
- **Test coverage**: 0% (48 test rimossi marzo 2026, GdUnit4 disinstallato).

---

## Piano fix DEMO-READY (presentazione 17 Aprile 2026 ore 9:00)

Tempo disponibile: ~12-14 ore (notte + mattina).

### FASE 1 — Bug gameplay P0 (stimato 45 min)

Fixture gia diagnosticate in `CONSOLIDATED_PROJECT_REPORT.md` sez. 12.7, mai applicate. Applicare ora.

**Fix A — Focus chain (risolve B-001 + B-003)**:
1. `panel_manager.gd:86-88` aggiungere `gui_release_focus()` nel close
2. `deco_panel.gd:36` `_mode_button.focus_mode = Control.FOCUS_NONE`
3. `deco_panel.gd:83` `header.focus_mode = Control.FOCUS_NONE` (risolve B-003)
4. `decoration_system.gd:104-137` 4 popup button `.focus_mode = Control.FOCUS_NONE`
5. `main.tscn` HUD 4 Button `focus_mode = 0`
6. `tutorial_manager.gd:202` `_skip_btn.focus_mode = Control.FOCUS_NONE`

**Fix B — Drag&drop silent (risolve B-002)**:
7. `room_base.gd:94-96` aggiungere `AppLogger.warn` + `SignalBus.toast_requested.emit` prima di `return`
8. `room_base.gd:141-143` stesso pattern
9. `room_base.gd:144-145` log + toast su sprite_path empty

### FASE 2 — Elimina dead code pericoloso (5 min)

10. Rimuovere `v1/addons/virtual_joystick/` e `v1/scenes/ui/virtual_joystick.tscn` (B-030 — rischio attivo B-001)

### FASE 3 — Log silent failure critico (10 min)

11. `local_database._select()` righe 803-809 aggiungere `AppLogger.error` prima di `return []` (B-027)

### FASE 4 — Smoke test (tu in Godot, 10-20 min)

Aprire Godot, `F5`, verificare:
- [ ] Movimento char WASD/arrow keys ✓
- [ ] Drag&drop decorazione → spawn ✓
- [ ] Tab DecoPanel cliccabili con mouse ✓
- [ ] Pet animato autonomo ✓
- [ ] Musica playthrough + crossfade ✓
- [ ] Settings/Profile panel open/close + esc ✓
- [ ] Auto-save 60s funzionante (modifica → wait → restart → stato preserved) ✓

### FASE 5 — Transparency slide (15 min)

Aggiungere 1 slide "Tech Debt Dichiarato" alla presentazione per mostrare maturita ingegneristica. Elementi:
- Test coverage 0% (pianificato Fase 5)
- Supabase cloud: 6 attive, 9 predisposte
- Security roadmap: PBKDF2 upgrade, token encryption, redaction
- Code size: 2 file sforano 500 righe (debt monitored)

Questo converte debolezze in forza narrativa: "sappiamo dove siamo, sappiamo dove andiamo".

---

## NON fare pre-demo

Per rispetto del principio "no over-engineering":
- NO refactor `local_database.gd` split
- NO circuit breaker Supabase
- NO test re-introduction
- NO Supabase schema versioning (solo documentare la mancanza)
- NO PBKDF2 upgrade (troppo rischio regressione login)
- NO redaction logger (fine-tuning, non blocker)

Accumula debito **dichiarato**. Fix post-demo secondo backlog in file review individuali.

---

## File review

- `01_design_review.md` — 7 sezioni A-G
- `02_devsecops_gate.md` — 7 fasi DevSecOps
- `03_correctness_check.md` — silent failure + non-determinism
- `04_resilience_check.md` — timeout/retry/backpressure
- `05_complexity_check.md` — over-engineering + dead code
