# Supabase Schema — Versioning

> **Stato**: stub. Awaiting user-provided `pg_dump --schema-only` dal Supabase
> dashboard (15 tabelle cloud).

## Connection info

- **Project ref**: `dofkdywubnhonxqpsmsh`
- **Region**: `eu-central-1`
- **API URL**: `https://dofkdywubnhonxqpsmsh.supabase.co`
- **Publishable key**: `sb_publishable_cZywbZxGNzmbEufVuL2O_g_BMGwNmI-` (nuovo naming; safe per repo pubblico, protetto da RLS)
- **Postgres conn**: `postgresql://postgres:<PASSWORD>@db.dofkdywubnhonxqpsmsh.supabase.co:5432/postgres`

Il gioco legge la publishable key da `user://config.cfg` (generato al primo
avvio o fornito dall'utente). **Non è un secret** — le Supabase publishable
keys sono progettate per essere embeddabili in client code, con sicurezza
garantita da Row Level Security (RLS) policies lato DB.

## Scope

Versionare la DDL del database cloud Supabase (15 tabelle dichiarate nei doc
ma mai tracked in repo). Senza DDL in git, impossibile ricostruire il DB
cloud da zero in caso di incident o staging environment. Task B-032.

## Come contribuire il dump

Opzione A — Supabase CLI (raccomandata):

```bash
# Dal progetto locale con supabase CLI installato
supabase db dump --schema-only > supabase/migrations/0001_initial.sql
# oppure per snapshot specifico:
supabase db dump --data-only --schema public > supabase/migrations/seed.sql
```

Opzione B — SQL Editor dashboard:

1. Accedi al dashboard Supabase del progetto
2. SQL Editor -> nuova query
3. `SELECT pg_get_ddl_from_database('public');` (o via Database -> Schema)
4. Copia l'output in `supabase/migrations/0001_initial.sql`
5. Aggiungi RLS policies separate se non incluse

## Struttura cartella (target)

```
supabase/
├── README.md               (questo file)
├── migrations/
│   ├── 0001_initial.sql    15 tabelle cloud + RLS policies
│   └── (future incrementali)
└── seed.sql                (opzionale: dati demo per dev local)
```

## 15 tabelle cloud attese (dai doc e mapper)

Basato su `v1/scripts/utils/supabase_mapper.gd` + documentazione storica:

1. `profiles` — display_name, avatar_character_id, current_room, locale
2. `accounts_cloud` — mirror account locali
3. `characters_cloud` — mirror character (avatar fields)
4. `inventory_cloud` — mirror inventario
5. `rooms_cloud` — mirror rooms
6. `placed_decorations_cloud` — mirror decorazioni
7. `user_settings` — volumi, lingua, display_mode
8. `music_preferences` — track index, playlist mode, ambience
9. `user_currency` — coins + lifetime earnings
10. `room_decorations` — array decorazioni cross-device
11. `save_snapshots` — JSON blob backup periodici
12. `friends` — relazioni user-user (bidirectional)
13. `friend_requests` — pending requests
14. `leaderboard_entries` — score pubblici
15. `telemetry_events` — analytics opt-in

Tutte con `user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE` e RLS
policy `USING (auth.uid() = user_id)`.

## CI validation

Una volta versionato il dump, il validator `ci/validate_db_schema.py` verra`
esteso per validare anche il SQL Supabase (sintassi Postgres + presenza RLS
su ogni table con user_id).

## Vedi anche

- [v1/data/README.md](../v1/data/README.md) — schema SQLite locale (9 tabelle)
- [AUDIT_REPORT 2026-04-23](../AUDIT_REPORT_2026-04-23.md) — § 4.7.3 supabase schema audit
