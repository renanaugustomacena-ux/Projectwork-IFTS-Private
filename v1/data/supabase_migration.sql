-- Mini Cozy Room — Database Migration
-- From: 11-table therapeutic schema
-- To: 7-table game schema (ACCOUNT, CHARACTER, SHOP, ITEM, CATEGORIA, COLORE, INVENTARIO)
--
-- Execute this in the Supabase SQL Editor (https://supabase.com/dashboard)
-- Project: dofkdywubnhonxqpsmsh (eu-central-1)

-- ============================================================
-- STEP 1: Backup existing tables (safety net)
-- ============================================================
CREATE TABLE IF NOT EXISTS _backup_profiles AS SELECT * FROM profiles;
CREATE TABLE IF NOT EXISTS _backup_user_settings AS SELECT * FROM user_settings;

-- ============================================================
-- STEP 2: Drop old tables
-- ============================================================
DROP TABLE IF EXISTS user_unlocks;
DROP TABLE IF EXISTS user_currency;
DROP TABLE IF EXISTS achievements;
DROP TABLE IF EXISTS journal_entries;
DROP TABLE IF EXISTS mood_entries;
DROP TABLE IF EXISTS room_decorations;
DROP TABLE IF EXISTS memos;
DROP TABLE IF EXISTS todo_items;
DROP TABLE IF EXISTS music_preferences;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS profiles;

-- ============================================================
-- STEP 3: Create new tables
-- ============================================================

-- ACCOUNT (extends auth.users with game-specific data)
CREATE TABLE public.accounts (
    account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auth_uid UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    data_di_iscrizione DATE NOT NULL DEFAULT CURRENT_DATE,
    data_di_nascita DATE NOT NULL,
    mail VARCHAR NOT NULL
);

-- COLORE (color palette entries)
CREATE TABLE public.colore (
    colore_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

-- CATEGORIA (item categories)
CREATE TABLE public.categoria (
    categoria_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

-- SHOP (shop definitions)
CREATE TABLE public.shop (
    shop_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    prezzo_item INTEGER
);

-- ITEM (purchasable items)
CREATE TABLE public.items (
    item_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shop_id INTEGER REFERENCES public.shop(shop_id),
    categoria_id INTEGER REFERENCES public.categoria(categoria_id),
    prezzo INTEGER,
    disponibilita BOOLEAN DEFAULT true,
    colore_id INTEGER REFERENCES public.colore(colore_id)
);

-- INVENTARIO (player inventory)
CREATE TABLE public.inventario (
    inventario_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id INTEGER REFERENCES public.accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER,
    capacita INTEGER DEFAULT 50,
    coins INTEGER DEFAULT 0
);

-- CHARACTER (player character — 1:1 with account)
CREATE TABLE public.characters (
    account_id INTEGER PRIMARY KEY REFERENCES public.accounts(account_id) ON DELETE CASCADE,
    nome VARCHAR,
    genere BOOLEAN,
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0,
    inventario INTEGER REFERENCES public.inventario(inventario_id)
);

-- ============================================================
-- STEP 4: Enable Row Level Security
-- ============================================================
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.colore ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

-- Accounts: users can only access their own data
CREATE POLICY "Users can view own account"
    ON public.accounts FOR SELECT
    USING (auth_uid = auth.uid());

CREATE POLICY "Users can update own account"
    ON public.accounts FOR UPDATE
    USING (auth_uid = auth.uid());

CREATE POLICY "Users can insert own account"
    ON public.accounts FOR INSERT
    WITH CHECK (auth_uid = auth.uid());

-- Characters: users can only access their own character
CREATE POLICY "Users can view own character"
    ON public.characters FOR SELECT
    USING (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

CREATE POLICY "Users can update own character"
    ON public.characters FOR UPDATE
    USING (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

CREATE POLICY "Users can insert own character"
    ON public.characters FOR INSERT
    WITH CHECK (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

-- Inventario: users can only access their own inventory
CREATE POLICY "Users can view own inventory"
    ON public.inventario FOR SELECT
    USING (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

CREATE POLICY "Users can update own inventory"
    ON public.inventario FOR UPDATE
    USING (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

CREATE POLICY "Users can insert own inventory"
    ON public.inventario FOR INSERT
    WITH CHECK (account_id IN (SELECT account_id FROM public.accounts WHERE auth_uid = auth.uid()));

-- Shop, Items, Colore, Categoria: read-only for all authenticated users
CREATE POLICY "Authenticated users can view shop"
    ON public.shop FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view items"
    ON public.items FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view colors"
    ON public.colore FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view categories"
    ON public.categoria FOR SELECT
    USING (auth.role() = 'authenticated');

-- ============================================================
-- STEP 5: Cleanup backup tables (run AFTER verifying migration)
-- ============================================================
-- DROP TABLE IF EXISTS _backup_profiles;
-- DROP TABLE IF EXISTS _backup_user_settings;
