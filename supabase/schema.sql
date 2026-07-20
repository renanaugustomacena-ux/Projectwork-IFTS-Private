-- =============================================================================
-- Relax Room — Supabase cloud schema (schema: public)
-- =============================================================================
-- Source of truth for the 5 tables the game client pushes during sync.
--
-- DERIVED FROM THE CLIENT MAPPER:
--   v1/scripts/utils/supabase_mapper.gd
-- Every column below mirrors a key emitted by that mapper (plus surrogate
-- ids / defaults). Any change to the mapper payloads MUST be reflected here,
-- and vice versa. See supabase/README.md for the apply procedure.
--
-- Client behavior this schema supports (v1/scripts/autoload/supabase_client.gd):
--   * profiles / user_currency / user_settings / music_preferences:
--     one row per user, upserted via PostgREST with
--     "Prefer: resolution=merge-duplicates" — conflict target is the PRIMARY
--     KEY, hence user_id is the PK on all four tables.
--   * room_decorations: the client DELETEs all rows for the user
--     (user_id=eq.<uid>) and re-inserts the current set. Rows carry no natural
--     unique key (the same item can be placed twice in one room), so a
--     surrogate uuid PK is used and user_id is indexed for the bulk delete
--     and for RLS.
--
-- The file is idempotent (IF NOT EXISTS / DROP POLICY IF EXISTS): safe to
-- re-run against an existing project.
--
-- Requires PostgreSQL 13+ (gen_random_uuid() in core); Supabase satisfies
-- this. auth.users and the anon/authenticated roles are provisioned by
-- Supabase itself.
--
-- Last synced with the mapper: 2026-07-20.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

-- profiles — SupabaseMapper.profile_to_cloud()
create table if not exists public.profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null default '',
    avatar_character_id text not null default 'male_old',
    avatar_outfit_id text not null default '',
    current_room_id text not null default 'cozy_studio',
    current_theme text not null default 'modern',
    locale text not null default 'en',
    updated_at timestamptz not null default now()
);

-- user_currency — SupabaseMapper.currency_to_cloud()
create table if not exists public.user_currency (
    user_id uuid primary key references auth.users (id) on delete cascade,
    coins bigint not null default 0,
    total_earned bigint not null default 0,
    updated_at timestamptz not null default now()
);

-- user_settings — SupabaseMapper.settings_to_cloud()
-- Note: "language" is intentionally absent — the mapper routes it to
-- profiles.locale, not to this table.
create table if not exists public.user_settings (
    user_id uuid primary key references auth.users (id) on delete cascade,
    display_mode text not null default 'windowed',
    mini_mode_position text not null default 'bottom_right',
    master_volume double precision not null default 0.8,
    music_volume double precision not null default 0.6,
    ambience_volume double precision not null default 0.4,
    updated_at timestamptz not null default now()
);

-- music_preferences — SupabaseMapper.music_to_cloud()
-- active_ambience is a JSON array of ambience id strings.
create table if not exists public.music_preferences (
    user_id uuid primary key references auth.users (id) on delete cascade,
    current_track_index integer not null default 0,
    playlist_mode text not null default 'shuffle',
    active_ambience jsonb not null default '[]'::jsonb,
    updated_at timestamptz not null default now()
);

-- room_decorations — SupabaseMapper.decorations_to_cloud()
-- Many rows per user; surrogate PK (see header for rationale).
create table if not exists public.room_decorations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    room_id text not null default 'cozy_studio',
    theme text not null default 'modern',
    item_id text not null default '',
    position_x double precision not null default 0,
    position_y double precision not null default 0,
    z_index integer not null default 0,
    rotation_deg double precision not null default 0,
    flipped boolean not null default false,
    updated_at timestamptz not null default now()
);

-- Supports both the client's DELETE ... user_id=eq.<uid> and the RLS filter.
create index if not exists room_decorations_user_id_idx
    on public.room_decorations (user_id);

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
-- Owner-only access on every table: a row is visible/writable only to the
-- authenticated user whose auth.uid() matches its user_id. auth.uid() is
-- wrapped in a scalar subselect so the planner evaluates it once per query
-- instead of once per row (Supabase RLS performance guidance).

alter table public.profiles enable row level security;
alter table public.user_currency enable row level security;
alter table public.user_settings enable row level security;
alter table public.music_preferences enable row level security;
alter table public.room_decorations enable row level security;

-- profiles ---------------------------------------------------------------
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
    for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
    for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own on public.profiles
    for delete to authenticated
    using ((select auth.uid()) = user_id);

-- user_currency ----------------------------------------------------------
drop policy if exists user_currency_select_own on public.user_currency;
create policy user_currency_select_own on public.user_currency
    for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists user_currency_insert_own on public.user_currency;
create policy user_currency_insert_own on public.user_currency
    for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists user_currency_update_own on public.user_currency;
create policy user_currency_update_own on public.user_currency
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists user_currency_delete_own on public.user_currency;
create policy user_currency_delete_own on public.user_currency
    for delete to authenticated
    using ((select auth.uid()) = user_id);

-- user_settings ----------------------------------------------------------
drop policy if exists user_settings_select_own on public.user_settings;
create policy user_settings_select_own on public.user_settings
    for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists user_settings_insert_own on public.user_settings;
create policy user_settings_insert_own on public.user_settings
    for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists user_settings_update_own on public.user_settings;
create policy user_settings_update_own on public.user_settings
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists user_settings_delete_own on public.user_settings;
create policy user_settings_delete_own on public.user_settings
    for delete to authenticated
    using ((select auth.uid()) = user_id);

-- music_preferences ------------------------------------------------------
drop policy if exists music_preferences_select_own on public.music_preferences;
create policy music_preferences_select_own on public.music_preferences
    for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists music_preferences_insert_own on public.music_preferences;
create policy music_preferences_insert_own on public.music_preferences
    for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists music_preferences_update_own on public.music_preferences;
create policy music_preferences_update_own on public.music_preferences
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists music_preferences_delete_own on public.music_preferences;
create policy music_preferences_delete_own on public.music_preferences
    for delete to authenticated
    using ((select auth.uid()) = user_id);

-- room_decorations -------------------------------------------------------
drop policy if exists room_decorations_select_own on public.room_decorations;
create policy room_decorations_select_own on public.room_decorations
    for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists room_decorations_insert_own on public.room_decorations;
create policy room_decorations_insert_own on public.room_decorations
    for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists room_decorations_update_own on public.room_decorations;
create policy room_decorations_update_own on public.room_decorations
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists room_decorations_delete_own on public.room_decorations;
create policy room_decorations_delete_own on public.room_decorations
    for delete to authenticated
    using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------
-- Default-deny for anon: these tables are reachable only with a user JWT.
-- RLS would already return zero rows for anon (auth.uid() is null), but
-- revoking the table privileges removes the surface entirely.

revoke all on table
    public.profiles,
    public.user_currency,
    public.user_settings,
    public.music_preferences,
    public.room_decorations
from anon;

grant select, insert, update, delete on table
    public.profiles,
    public.user_currency,
    public.user_settings,
    public.music_preferences,
    public.room_decorations
to authenticated;
