# DevSecOps Gate — Relax Room (full 7-phase)

**Phases Evaluated:** 7/7 | **Issues:** 14 | CRITICAL: 0 | HIGH: 6 | MEDIUM: 5 | LOW: 3

---

## Phase 1: Planning (Threat Model) — **WARNING**

- **Finding:** Nessun threat model STRIDE formalizzato per componente.
  **Severity:** MEDIUM
  **Evidence:** `v1/docs/` contiene guide di ruolo ma nessun `THREAT_MODEL.md` o STRIDE worksheet
  **Remediation:** Aggiungere sezione STRIDE in `v1/docs/GUIDE_RENAN_SUPERVISOR.md` con mapping per SignalBus, SaveManager, SupabaseClient, AuthManager

- **Finding:** Risk register parziale (bug tracker OK, security non separata).
  **Severity:** MEDIUM
  **Evidence:** `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` sez. 2 traccia 22 bug, 2 security (B-019, B-020); ok ma mescolati con bug funzionali
  **Remediation:** Estrarre security issues in `SECURITY.md` separato con CVSS scoring

## Phase 2: Design (Secure Architecture) — **WARNING**

- **Finding:** Zero-trust incompleto — boundary chat/tags/memos senza validazione.
  **Severity:** HIGH
  **Evidence:** `CONSOLIDATED_PROJECT_REPORT.md` sez 6; tabelle Supabase `chat_messages`, `memos`, `journal_entries` dichiarate ma nessun validator client-side prima di insert
  **Remediation:** Implementare sanitize_user_text() con length cap + char allowlist prima di ogni insert cloud

- **Finding:** API rate limiting solo server-side (Supabase default).
  **Severity:** MEDIUM
  **Evidence:** `supabase_client.gd` non implementa token bucket client; status 429 logged ma retry continua (`supabase_client.gd:254-255` — B-021)
  **Remediation:** Exponential backoff con jitter su 429/5xx

- **Finding:** Data classification non documentata.
  **Severity:** MEDIUM
  **Evidence:** nessun marker su quali tabelle contengono PII (email, birthday in `accounts`)
  **Remediation:** Aggiungere tag inline nei commenti DDL: `-- classification: PII`

## Phase 3: Implementation (Secure Coding) — **PASS with advisories**

- **Finding:** **Zero hardcoded secrets** nel codice sorgente.
  **Severity:** — (pass)
  **Evidence:** grep `(api_key|password|token|secret)\s*=\s*["']` su `v1/` → 0 match reali
  **Remediation:** N/A

- **Finding:** **SQL injection impossibile** — tutte le query parametrizzate.
  **Severity:** — (pass)
  **Evidence:** `local_database.gd` usa `?` placeholder su 100% query (righe 306, 313, 328, 354, 424, 431, 475 ecc.)
  **Remediation:** N/A

- **Finding:** Silent SQL errors in `_execute()` wrapper.
  **Severity:** HIGH
  **Evidence:** `local_database.gd:519` non chiama AppLogger.error. B-014 dead var `_last_select_error` conferma intento mancato
  **Remediation:** `_execute()` deve loggare error via `AppLogger.error("LocalDatabase", "sql_failed", {sql: ..., bindings: ..., error: ...})` e ritornare bool

- **Finding:** **Log redaction assente** — context dict puo contenere token/password.
  **Severity:** HIGH
  **Evidence:** `logger.gd:102` serializza context tale-quale via `JSON.stringify`. Nessuna sanitizzazione
  **Remediation:** Lista chiavi sensibili `["password", "token", "jwt", "refresh_token", "password_hash", "hmac_key"]` redactate a `"***"` prima di stringify

- **Finding:** PBKDF2 iter count **10k** — sotto OWASP 2023 (raccomandato ≥600k).
  **Severity:** HIGH
  **Evidence:** `auth_manager.gd` descritto nel report runtime; HashingContext SHA-256 iterato 10.000 volte
  **Remediation:** Portare a 100.000+ iterazioni. Migration on-login con password existing upgrade

- **Finding:** Random salt usa `randi()` / `Crypto.generate_random_bytes()`?
  **Severity:** MEDIUM
  **Evidence:** da verificare: salt 16 byte in formato `v2:salt_hex:hash_hex`
  **Remediation:** Confermare uso `Crypto.generate_random_bytes(16)` (CSPRNG); NON `randi()`

## Phase 4: Testing & Validation — **FAIL**

- **Finding:** **Test coverage 0%** — 48 test originali rimossi, GdUnit4 non installato.
  **Severity:** HIGH
  **Evidence:** `v1/tests/README.md`, report runtime sez. 10
  **Remediation:** Pre-demo: impossibile ripristinare. Post-demo: re-introdurre almeno `test_auth_manager` (security-critical) e `test_save_manager`

- **Finding:** Nessun fixture con credenziali reali ✓.
  **Severity:** — (pass)
  **Evidence:** `v1/tests/unit/` vuoto; nessun file `.cfg` test-specific committato
  **Remediation:** N/A

- **Finding:** Validatori CI coprono schema/format/lint, **non security-specific**.
  **Severity:** MEDIUM
  **Evidence:** `ci/validate_*.py` → solo JSON/sprite/crossref/schema DB. Nessun secret scanning, nessun dependency CVE check
  **Remediation:** Aggiungere job `secret-scan` con `detect-secrets` o `gitleaks`; job `dep-audit` con `safety check`

## Phase 5: Deployment (Pipeline Security) — **WARNING**

- **Finding:** **`.pre-commit-config.yaml` MANCANTE**.
  **Severity:** HIGH
  **Evidence:** `ls -la .pre-commit-config.yaml` → "No such file"; `CONSOLIDATED_PROJECT_REPORT.md` sez 9.4 dichiara pre-commit come prassi ma file non esiste
  **Remediation:** Creare `.pre-commit-config.yaml` con hooks: gdtoolkit (gdformat + gdlint), detect-secrets, trailing-whitespace, end-of-file-fixer

- **Finding:** `.gitignore` copre correttamente `.env`, `*.key`, `*.pem`, `*.db`, `.import/`, `.godot/`, `export/`.
  **Severity:** — (pass)
  **Evidence:** `.gitignore` righe 24-30, 36-38
  **Remediation:** N/A

- **Finding:** Git history **nessun secret reale** leakato.
  **Severity:** — (pass)
  **Evidence:** `git log --all -p | grep -E "anon_key.*eyJ"` → solo placeholder `"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."` (JWT header standard + truncato) in docs di esempio; URL `xxxxxxxxxxxx.supabase.co` placeholder
  **Remediation:** N/A

- **Finding:** Build artifacts esclusi correttamente.
  **Severity:** — (pass)
  **Evidence:** `.godot/`, `export/`, `.import/`, `.mono/` tutti in `.gitignore`
  **Remediation:** N/A

## Phase 6: Monitoring & Response — **WARNING**

- **Finding:** Auth failures loggati con context.
  **Severity:** — (pass)
  **Evidence:** AuthManager AppLogger.error/warn usati per rate limit + lockout + login fail
  **Remediation:** N/A

- **Finding:** Silent SQL failures bypassano logger.
  **Severity:** HIGH (duplicato Phase 3)
  **Evidence:** `local_database._execute()` no log
  **Remediation:** Vedi Phase 3

- **Finding:** Incident response — "cosa e successo?" parzialmente rispondibile.
  **Severity:** MEDIUM
  **Evidence:** AppLogger JSON Lines + session_id permette ricostruzione flow; ma silent DB fail + log rotazione 25MB rendono possibili ciechi
  **Remediation:** Aumentare livello log DB a INFO per tutte le query in debug build; fix B-014+B-018

- **Finding:** Log buffer unbounded se flush fallisce (B-018).
  **Severity:** MEDIUM
  **Evidence:** `logger.gd:20, 121-143` — `_log_buffer` Array senza cap
  **Remediation:** Cap a 10.000 entries; drop-oldest quando pieno

## Phase 7: Continuous Improvement — **WARNING**

- **Finding:** TODO/FIXME di sicurezza **minimi e non critici**.
  **Severity:** LOW
  **Evidence:** `grep TODO|FIXME|BUG` → 5 match totali; 1 TODO architetturale `game_manager.gd:120` (feature non-security), 1 BUG segnalato in `GUIDE_ELIA_DATABASE.md:396` (non security)
  **Remediation:** Mantenere tracker separato per security

- **Finding:** Dipendenze Python **pin non stretto**.
  **Severity:** MEDIUM
  **Evidence:** `.github/workflows/ci.yml` usa `gdtoolkit>=4,<5` → range minor, non patch pinning
  **Remediation:** Aggiungere `requirements-ci.txt` con pin exact + `pip-compile`

- **Finding:** Dipendenze Godot addons **senza CVE scanning**.
  **Severity:** LOW
  **Evidence:** `v1/addons/godot-sqlite/` (v4.7, MIT) e `v1/addons/virtual_joystick/` (no version metadata visibile)
  **Remediation:** Aggiungere job CI che confronta addon versions contro CVE DB (manuale accettabile)

- **Finding:** Nessuna SBOM generata.
  **Severity:** LOW
  **Evidence:** No `sbom.json`, no tool setup (syft/cyclonedx)
  **Remediation:** Opzionale per desktop app piccola; skip finche progetto non entra in compliance framework

---

### Overall Verdict: **CONDITIONAL PASS**

**Blocking Issues:** 0 critical (0 secrets leakati, 0 SQL injection, 0 eval/exec)
**Advisories:** 14 (6 HIGH, 5 MEDIUM, 3 LOW)

### Top 5 pre-demo actionable

1. **Fix silent SQL errors** (`local_database._execute`) — 30 min
2. **Log redaction** per password/token nei context — 20 min
3. **Creare `.pre-commit-config.yaml`** stub minimo — 15 min
4. **Documentare B-019 plaintext token nella slide security** (trasparenza onesta) — 5 min
5. **PBKDF2 iter 10k → 100k** + migration on-login — 40 min

### Post-demo roadmap

- Test suite re-introduction (auth + save minimo)
- Dependency pinning stretto
- STRIDE worksheet per componente
- Secret-scan CI job
