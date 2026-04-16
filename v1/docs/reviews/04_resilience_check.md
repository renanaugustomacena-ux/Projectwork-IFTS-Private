# Resilience Audit — Relax Room

**Modules Audited:** 5 (SupabaseClient+HTTP, LocalDatabase, SaveManager, AppLogger, AudioManager) | **Issues:** 12 | CRITICAL: 0 | HIGH: 5 | MEDIUM: 5 | LOW: 2

---

## SupabaseClient + SupabaseHttp — I/O type: **HTTP**

### 1. Timeout Discipline — **PASS**

* **`supabase_http.gd:8,20`** — `REQUEST_TIMEOUT = 15.0` impostato esplicito su `HTTPRequest.timeout`
  **Status:** PASS — ogni request ha timeout bounded

### 2. Retry Discipline — **WARNING**

* **`supabase_client.gd:53`** — `SUPABASE_MAX_RETRY = 5` bounded ✓
  **Severity:** — (pass)

* **No exponential backoff (B-021)**
  **Category:** Retry
  **Severity:** HIGH — retry a intervalli fissi 120s (sync timer). Su errore transiente, amplifica carico server e spreca retry budget
  **Fix:** implementare backoff `delay = min(60, 2^attempt) + random(0, 2)` (jitter). Overriding sync interval durante recovery

* **Retry su 4xx non-retriable**
  **Category:** Retry
  **Severity:** HIGH — 404 (relation error) e 400 (validation) non sono transienti; retry inutile
  **Evidence:** `supabase_client.gd:249-253` logga warning + skip su 404 ✓ MA queue item non marcato con retry_count++, rimane e ritenta
  **Fix:** dead-letter queue per item con 4xx persistenti; non contare come retry

* **Idempotenza retry**
  **Category:** Retry
  **Severity:** MEDIUM — upsert operation idempotente (INSERT ON CONFLICT) ✓; DELETE idempotente ✓. Safe

### 3. Backpressure & Flow Control — **FAIL**

* **`supabase_http.gd:12`** — `_queue: Array[Dictionary] = []` **UNBOUNDED**
  **Category:** Backpressure
  **Severity:** HIGH — se app offline per ore con molte azioni, queue cresce indefinitamente in RAM
  **Fix:** cap `MAX_QUEUE = 500`; drop oldest o reject nuove request

* **`supabase_http.gd:7`** — `MAX_CONCURRENT = 3` pool size
  **Status:** PASS — connection pool bounded ✓

* **SQLite sync_queue table** — **nessun LIMIT** in insert
  **Category:** Backpressure
  **Severity:** MEDIUM — offline prolungato riempie tabella. Non critico su disco (< 1 MB per 10k entry), ma flush su reconnect puo essere lento
  **Fix:** cap a 10k entry; oldest dropped con AppLogger.warn

### 4. Circuit Breaker — **FAIL**

* **Nessun circuit breaker implementato**
  **Category:** Circuit Breaker
  **Severity:** HIGH — se Supabase down per minuti, client continua a sparare request fallimentari (rate-limited server-side ma spreca banda + budget retry)
  **Fix pre-demo:** accettabile data scope desktop app. Post-demo: implementare circuit `CLOSED → OPEN (5 fail/60s) → HALF_OPEN (1 probe/60s)`. Stato esposto via `cloud_connection_changed` signal

### 5. Graceful Degradation — **PASS**

* **Offline-first architecture** ✓
  **Status:** PASS — gioco 100% funzionale senza Supabase; config `supabase_config.gd` ritorna false se mancante, client stub no-op

* **Stato degradato esposto a utente**
  **Severity:** MEDIUM — `cloud_connection_changed` signal emesso, ma nessun toast UI persistente "offline mode"
  **Fix:** badge in HUD angolo con stato sync (online/offline/syncing)

### 6. Resource Ownership — **PASS**

* **`supabase_client.gd:462`** — `_http.request_completed.disconnect` in cleanup ✓
* **File handles Godot** — GDScript auto-close su scope exit (FileAccess ref-counted) ✓

---

## LocalDatabase — I/O type: **DB (SQLite)**

### 1. Timeout Discipline — **WARNING**

* **No statement timeout per query**
  **Category:** Timeout
  **Severity:** MEDIUM — SQLite busy_timeout default varia; se altro processo lock, query puo bloccare main thread
  **Fix:** `_db.query("PRAGMA busy_timeout = 5000")` dopo open

### 2. Retry Discipline — **PASS**

* **No retry automatico su SQL fail** — `_execute` logga e ritorna false ✓
  **Status:** PASS — caller decide se ritentare

### 3. Backpressure — **PASS**

* **Serial query execution** — no concorrenza lato GDScript
  **Status:** PASS — single-threaded, no contention

### 6. Resource Ownership — **WARNING**

* **Transaction wrapper** — `_on_save_requested` usa BEGIN/COMMIT/ROLLBACK ✓
* **WAL mode** — `PRAGMA journal_mode=WAL` ✓
* **FK check warning** — se FK disabled, solo warning, non fallisce
  **Category:** Resources
  **Severity:** LOW
  **Fix:** fail-fast se FK=off

---

## SaveManager — I/O type: **Filesystem**

### 1. Timeout Discipline — **PASS**

* **FileAccess sincrono Godot** — no timeout concept, blocca finche OS risponde
  **Status:** PASS per desktop local disk; degraded su slow network drive (non use-case)

### 2. Retry Discipline — **WARNING**

* **Nessun retry su write fail**
  **Category:** Retry
  **Severity:** MEDIUM — se disco full / permission denied su `save_data.json`, log error ma utente perde auto-save
  **Fix:** retry 1 volta dopo 500ms; se fallisce ancora, toast UI "save fail: check disk space"

### 5. Graceful Degradation — **PASS**

* **Backup chain** — primary corrotto → backup → default ✓
* **HMAC mismatch** — log warning, return null, utente riparte pulito con default (drastico ma safe)
  **Severity:** LOW — accettabile; alternativa "continue with tamper data?" insicura
  **Status:** PASS

### 6. Resource Ownership — **PASS**

* **Atomic write pattern** — temp file + rename ✓
* **Backup pre-write** ✓
* **FileAccess ref-counted** — auto-close su scope exit ✓

---

## AppLogger — I/O type: **Filesystem**

### 3. Backpressure — **FAIL (B-018)**

* **`logger.gd:20`** — `_log_buffer: Array[String]` **UNBOUNDED**
  **Category:** Backpressure / Resources
  **Severity:** HIGH — se flush disk fail (disk full), buffer cresce senza limiti, OOM risk dopo long session
  **Fix:** cap `MAX_BUFFER = 10000`; drop-oldest con `push_warning` quando pieno

* **`logger.gd:130`** — commento "fallback mantiene ultimi 100 messaggi"
  **Status:** Contraddittorio con observation sopra; verificare se cap esiste ma e da 100 (troppo basso) o non esiste
  **Fix:** chiarire implementazione, allineare cap realistico

### 6. Resource Ownership — **WARNING**

* **Log file rotation** — 5 MB x 5 file = 25 MB bounded ✓
* **File handle persistente** — `_log_file` tenuto aperto durante session
  **Category:** Resources
  **Severity:** MEDIUM — se app crash, ultimo buffer perso (no sync OS). FLUSH_INTERVAL 2s mitiga ma race possibile
  **Fix:** `_log_file.flush()` dopo ogni 10 write critiche (ERROR level)

---

## AudioManager — I/O type: **Filesystem (audio load)**

### 1. Timeout Discipline — **PASS**

* **`audio_manager.gd:165`** — `FileAccess.open` sync, no timeout
  **Status:** PASS — file locali, carico on-demand

### 6. Resource Ownership — **WARNING**

* **Crossfade** — 2 AudioStreamPlayer attivi durante fade
  **Category:** Resources
  **Severity:** MEDIUM — se crossfade interrotto (stop brusco), stream orfani non stop-patiti?
  **Fix:** verificare `_stop_both()` in teardown

---

## Sintesi top HIGH pre-demo

| # | Module | Issue | Fix time |
|---|---|---|---|
| 1 | Logger B-018 | Buffer unbounded | 10 min |
| 2 | SupabaseHttp | Queue unbounded | 10 min |
| 3 | Supabase | Backoff + dead-letter 4xx | 30 min |
| 4 | SQLite | busy_timeout pragma | 5 min |

### Post-demo backlog

- Circuit breaker Supabase
- HUD badge sync status
- SaveManager retry + toast
- Logger flush esplicito su ERROR
- Circuit breaker + health probe

### Confronto con `CONSOLIDATED_PROJECT_REPORT.md`

- **Conferma B-018** logger buffer unbounded
- **Conferma B-021** no exp backoff
- **Nuovo**: queue `_queue` in SupabaseHttp unbounded (non tracciato)
- **Nuovo**: SQLite busy_timeout mancante
- **Nuovo**: AudioManager crossfade cleanup edge case

**Aggiornamento necessario**: aggiungere B-025 (HTTP queue unbounded) e B-026 (SQLite busy_timeout) al tracker.
