# Supabase Cloud Backup Schema (push-only)

**Status**: [`schema.sql`](schema.sql) is the versioned, reproducible DDL for
every table the game client pushes. It replaces the earlier stub that waited
for a `pg_dump` from the dashboard (audit ref 4.7.3 / V-008).

> **This is a one-way backup, not cross-device sync.** The client only ever
> writes upward. `SupabaseClient.fetch_table()` exists and is wired into the
> request dispatcher, but nothing anywhere enqueues a `fetch` operation, and the
> cloud-to-local mappers were deleted (B-022) — `supabase_mapper.gd` has
> `*_to_cloud()` functions and nothing in the other direction. Signing in on a
> second machine does **not** download the room; the next push overwrites the
> cloud copy with whatever that machine has locally. Documented as a deliberate
> de-claim (G-007 / V-091), not as a bug to be fixed by this schema.

## Connection info

- **Project ref**: `dofkdywubnhonxqpsmsh`
- **Region**: `eu-central-1`
- **API URL**: `https://dofkdywubnhonxqpsmsh.supabase.co`
- **Publishable key**: `sb_publishable_cZywbZxGNzmbEufVuL2O_g_BMGwNmI-` (new
  naming; safe for a public repo — publishable keys are designed to ship in
  client code, protected by Row Level Security on the DB side)
- **Postgres conn**: `postgresql://postgres:<PASSWORD>@db.dofkdywubnhonxqpsmsh.supabase.co:5432/postgres`

The game reads the publishable key from `user://config.cfg` (generated on
first launch or provided by the user).

## What `schema.sql` contains

The 5 tables the sync engine (`v1/scripts/autoload/supabase_client.gd`)
actually pushes:

| Table | Rows per user | Written via |
|---|---|---|
| `profiles` | 1 (PK `user_id`) | upsert |
| `user_currency` | 1 (PK `user_id`) | upsert |
| `user_settings` | 1 (PK `user_id`) | upsert |
| `music_preferences` | 1 (PK `user_id`) | upsert |
| `room_decorations` | N (surrogate uuid PK) | delete-by-user, then insert |

Each table has: `user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE`,
`updated_at timestamptz DEFAULT now()`, RLS enabled with owner-only
select/insert/update/delete policies (`auth.uid() = user_id`), and grants
limited to the `authenticated` role (`anon` is revoked).

Tables that appeared in older docs but that the client does not write
(friends, leaderboards, telemetry, ...) are intentionally **not** in
`schema.sql`. Add them here the day the client code actually uses them.

Known residual on `room_decorations`: the client's DELETE filter matches on id
only, so cross-tenant isolation rests entirely on the RLS policy — there is no
second `user_id` predicate on the wire (V-079, open).

## Keep in sync with the client mapper

`schema.sql` is **derived by hand from
[`v1/scripts/utils/supabase_mapper.gd`](../v1/scripts/utils/supabase_mapper.gd)** —
the single point of truth for local-to-cloud field mapping. Every key a
`*_to_cloud()` function emits must exist as a column with a compatible type.
The mapper currently exposes exactly five: `profile_to_cloud`,
`decorations_to_cloud`, `currency_to_cloud`, `settings_to_cloud`,
`music_to_cloud` — one per table above, no more and no fewer.

Whenever you touch the mapper (add/rename/remove a payload key, add a new
`*_to_cloud()` function that the sync engine dispatches), you MUST update
`schema.sql` in the same change set, bump the "Last synced with the mapper"
date in its header, and apply the migration to the cloud project.

## How to apply

`schema.sql` is idempotent (`CREATE TABLE IF NOT EXISTS`,
`DROP POLICY IF EXISTS` before each `CREATE POLICY`), so re-running it
against an existing project is safe.

### Option A — Supabase SQL editor (fastest)

1. Open the project dashboard → **SQL Editor** → new query.
2. Paste the full contents of `supabase/schema.sql`.
3. Run. Re-running after future edits is safe.

### Option B — Supabase CLI (`supabase db push`)

The CLI applies files from `supabase/migrations/`, so register the schema as
a migration first:

```bash
supabase link --project-ref dofkdywubnhonxqpsmsh
supabase migration new initial_schema          # creates supabase/migrations/<ts>_initial_schema.sql
cp supabase/schema.sql supabase/migrations/<ts>_initial_schema.sql
supabase db push
```

Future schema changes: create a new incremental migration with only the delta
and `supabase db push` again, keeping `schema.sql` updated as the full
current-state reference.

### Option C — psql

```bash
psql "postgresql://postgres:<PASSWORD>@db.dofkdywubnhonxqpsmsh.supabase.co:5432/postgres" \
  -f supabase/schema.sql
```

## Verifying an environment

After applying, confirm RLS is active on all 5 tables:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('profiles', 'user_currency', 'user_settings',
                    'music_preferences', 'room_decorations');
-- rowsecurity must be true for every row returned
```

## CI validation

`ci/validate_db_schema.py` currently validates the local SQLite schema. A
follow-up can extend it to parse `supabase/schema.sql` and assert RLS is
enabled on every table that has a `user_id` column.

## See also

- [v1/data/README.md](../v1/data/README.md) — local SQLite schema
- [v1/scripts/utils/supabase_mapper.gd](../v1/scripts/utils/supabase_mapper.gd) — payload shapes (source of truth)
- [AUDIT_REPORT 2026-04-23](../AUDIT_REPORT_2026-04-23.md) — § 4.7.3 supabase schema audit
