# Design Review — Relax Room (stato 2026-04-16)

**Scope**: review pre-demo dell'architettura corrente contro 7 dimensioni del design review skill.

## A. Failure Mode Analysis — **WARNING**

- **SPOF identificati**:
  - `SignalBus` autoload: singolo punto di orchestrazione per 43 segnali; se parse-error nel file → tutto il gioco non boot
  - `LocalDatabase` autoload: inizializzato 3° in catena; se apertura fallisce, `_db = null` ma sistemi downstream non sanno (silent failure, `v1/scripts/autoload/local_database.gd:81-90`)
  - `SaveManager` HMAC: se `integrity.key` corrotta, save_data.json valido viene rigettato come "manomissione"
- **Blast radius se fallisce singolo sistema**:
  - SupabaseClient down → degrada a offline-first (OK, graceful)
  - SaveManager backup chain: primary → backup → default → **tutto l'inventario utente perso** (recovery OK ma RPO = ultima sessione)
  - LocalDatabase down → characters, rooms, settings non persistiti (gioco usa state in-memory, ma reset a prossimo avvio)
- **Recovery strategy**: automatica via backup SaveManager. RTO = restart app. RPO = 60s (auto-save timer) o ultima azione save_requested
- **Silent failures CRITICI** (violano principio "fail loud"):
  - `local_database.gd:519` `_execute()` wrapper non logga errori SQL
  - `save_manager.gd:149-155` fallback chain senza toast UI all'utente
  - `supabase_mapper.gd:53` TODO non gestito (lifetime earnings)
- **Blocker noto B-001**: focus chain Godot 4.5 — gameplay bloccato (vedi `CONSOLIDATED_PROJECT_REPORT.md` sez 7)

## B. Data Impact — **WARNING**

- **Schema changes**: nessuna variazione proposta pre-demo. Schema locale 9 tabelle stabile, `schema_version` tracciata
- **Migration risk**:
  - `local_database.gd:242-299` Migration 1 **DROP TABLE characters** + **DROP TABLE inventario** distruttivo se legacy schema (B-015). No backup pre-migration. Idempotenza non garantita su edge case
- **Cloud schema**: `supabase/migrations/` **NON ESISTE** nel repo. Le 15 tabelle cloud sono dichiarate solo in documentazione e presentazione, nessun DDL versionato. Impossibile ricostruire DB cloud da zero
- **Retention**: nessuna policy documentata per auto-delete account/data. `deleted_at` column exists ma nessuna pulizia automatica
- **Bounded queries**: `_select()` wrapper usa LIMIT solo dove scritto esplicitamente. Rischio N+1 non valutato (non critico per ~10-50 decorazioni)

## C. Security Assessment — **WARNING**

- **Input validation**:
  - Username/password: validati (length, uniqueness) ✓
  - Decoration item_id: lookup contro catalogo ✓
  - **Chat/tags/memos**: nessuna validazione (v1/docs/CONSOLIDATED_PROJECT_REPORT.md sez 6). Demo-safe perche feature non ancora live, ma tabelle cloud gia dichiarate
- **Auth strength**:
  - PBKDF2-style via HashingContext SHA-256 **10.000 iterazioni** (`auth_manager.gd:115+`). **Sotto standard OWASP 2023** (raccomandato 600k+ per SHA-256)
  - Salt 16 byte random ✓
  - Legacy migration da sha256 non salted → upgrade on login ✓
- **Secrets handling**:
  - **B-019 CRITICO**: Supabase `refresh_token` in `user://supabase_session.cfg` PLAINTEXT. Attacco locale = session theft
  - **B-020**: `supabase_config.gd:13-14` non valida HTTPS scheme — MITM possibile se user mette `http://`
  - AppLogger **senza redaction** — context dict loggabile in chiaro (potenziali token se passati come context)
- **STRIDE**:
  - Tampering: HMAC-SHA256 su save ✓
  - Repudiation: audit_log dichiarata in Supabase ma schema non definita
  - Information disclosure: logs plaintext ✓⚠
  - DoS: log buffer unbounded (B-018) — `AppLogger._log_buffer` cresce indefinito se flush fallisce

## D. Observability — **WARNING**

- **Structured logging**: ✓ JSON Lines con session_id, timestamp, level, source, context
- **Rotation**: ✓ 5 MB x 5 file = 25 MB max
- **Flush**: ✓ timer 2s + NOTIFICATION_WM_CLOSE_REQUEST
- **Redaction**: ✗ nessuna (rischio leak password hash / token in context)
- **SLI/SLO**: non definiti formalmente. Non critico per desktop app
- **Alert thresholds**: N/A (app standalone)
- **Silent failures bypass logger**:
  - `local_database._execute()` non logga SQL errors (B-014 dead var conferma lo strumento era previsto ma non usato)
  - `_find_item_data()` ritorna `{}` senza log (B-002 root cause)

## E. Integration Contracts — **WARNING**

- **Service boundaries**:
  - Gioco ↔ Supabase (REST + Auth)
  - Gioco ↔ filesystem (save_data, logs, config)
- **Timeout**: `SUPABASE_REQUEST_TIMEOUT = 15.0s` ✓
- **Retry**: max 5, **NO exponential backoff** (B-021). Retry a intervalli fissi 120s → amplifica errori transienti
- **Circuit breaker**: ✗ assente. Se Supabase giu, client continua a provare (rate-limited da server, ma spreca retry budget)
- **Backward compat**: save-data v1→v5 migrations documentate ✓. Nessun downgrade path
- **Consumer compat**: nessun consumer esterno del gioco

## F. Capacity — **PASS**

- **FPS**: 60 focused / 15 unfocused — sobrio, ben calibrato
- **Log disk**: 25 MB max hard cap ✓
- **Inventory**: capacita per account 50 (hardcoded `local_database.gd:111`). Adatto a scope
- **Decorazioni per stanza**: nessun limite hard, ma pratico < 100. Nessun problema perf osservato
- **Sync queue**: nessun limite size table. Rischio teorico di crescita unbounded se offline a lungo, ma pratico < 1000 entry/sessione
- **HTTP concurrency**: 1 in-flight per SupabaseClient (serial queue). Safe

## G. Project-Specific Invariants — **BLOCK**

Il `CONSOLIDATED_PROJECT_REPORT.md` sezione 9.2 dichiara esplicitamente:

> "Max file: 500 righe (gdlint)"

**Violazioni presenti**:
- `local_database.gd` — **810 righe** (62% sopra limite)
- `save_manager.gd` — **523 righe** (4.6% sopra limite)

Altri invariant violations:
- Autoload chain order: progetto dichiara 9 autoload; runtime ne ha **10** (StressManager non in docs)
- Numero segnali: presentazione dice 43, app docs dicono 41 (appendice B del report), explore agent ne conta 51 — **divergenza non risolta**

**VERDICT BLOCK**: violazione invariant documentato (max 500 righe) richiede refactor o update della regola prima di nuovi PR. Per la demo di domani, accettabile come debito tecnico dichiarato, non BLOCK operativo.

---

## Sintesi verdetti

| Sezione | Verdict | Note |
|---|---|---|
| A. Failure Mode | WARNING | Silent failures in DB + Save, B-001 gameplay |
| B. Data Impact | WARNING | Cloud schema non versionata, migration DROP non atomica |
| C. Security | WARNING | B-019 token plaintext P1, PBKDF2 iter basse, no redaction |
| D. Observability | WARNING | Buone strutture, silent failures bypass logger |
| E. Integration | WARNING | Retry senza exp backoff, no circuit breaker |
| F. Capacity | PASS | Limiti ragionevoli, nessun rischio osservato |
| G. Invariants | BLOCK (tecnico) | 2 file sforano 500 righe; debito noto |

**Verdict globale pre-demo**: procedere con fix dei 3 BLOCKER gameplay (B-001, B-002, B-003). Invariant violations sono debito da dichiarare a valutazione, non bloccano demo. Security WARNING va dichiarata esplicitamente nella presentazione (compliance roadmap).
