-- ============================================================
-- Shree Shyam Services — Supabase schema
-- Run this in Supabase Dashboard > SQL Editor
-- ============================================================

-- ---------- BOOKINGS ----------
create table if not exists public.bookings (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  customer_name text not null,
  phone text not null,
  service_type text not null,       -- 'ac-repair','ac-installation','refrigerator-repair','washing-machine-repair','amc'
  appliance_brand text,
  address text not null,
  area text,
  preferred_date date,
  preferred_slot text,              -- 'morning','afternoon','evening'
  notes text,
  status text not null default 'new', -- 'new','confirmed','in-progress','completed','cancelled'
  assigned_technician text,
  final_amount numeric,
  admin_notes text
);

-- ---------- CONTACT MESSAGES ----------
create table if not exists public.contact_messages (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name text not null,
  phone text not null,
  message text not null,
  status text not null default 'unread'  -- 'unread','read','replied'
);

-- ---------- ADMIN USERS ----------
-- Links Supabase auth.users to an "admin" role. Add rows manually after
-- an admin signs up once via Supabase Auth (email/password).
create table if not exists public.admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- ROW LEVEL SECURITY — locked down by default, opened deliberately.
-- This is the step that was missed on the last project (open RLS on
-- `profiles`), so every table below is explicit about who can do what.
-- ============================================================

alter table public.bookings enable row level security;
alter table public.contact_messages enable row level security;
alter table public.admin_users enable row level security;

-- Helper: is the current authenticated user an admin?
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.admin_users where id = auth.uid()
  );
$$;

-- BOOKINGS policies
-- Public (anon) users can INSERT a booking (the booking form), but cannot
-- read, update, or delete any booking — including their own, since there's
-- no customer login yet. This prevents anyone from listing all bookings.
create policy "anon can insert bookings"
  on public.bookings for insert
  to anon
  with check (true);

-- Only admins can read/update/delete bookings.
create policy "admin can select bookings"
  on public.bookings for select
  to authenticated
  using (public.is_admin());

create policy "admin can update bookings"
  on public.bookings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "admin can delete bookings"
  on public.bookings for delete
  to authenticated
  using (public.is_admin());

-- CONTACT MESSAGES policies (same pattern)
create policy "anon can insert contact messages"
  on public.contact_messages for insert
  to anon
  with check (true);

create policy "admin can select contact messages"
  on public.contact_messages for select
  to authenticated
  using (public.is_admin());

create policy "admin can update contact messages"
  on public.contact_messages for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ADMIN_USERS policies — nobody can self-promote to admin via the API.
-- Rows are only ever inserted manually by you by editing the table
-- inside the Supabase Dashboard (Table Editor), never via the app.
create policy "admin can read admin_users"
  on public.admin_users for select
  to authenticated
  using (public.is_admin());

-- No insert/update/delete policy is created for admin_users at all —
-- meaning even a logged-in admin cannot change it through the API.
-- This is intentional: promoting a new admin is a manual, deliberate
-- action you take in the dashboard, not something the app can do.

-- ============================================================
-- SETUP STEPS (do these after running the SQL above)
-- ============================================================
-- 1. In Supabase Dashboard > Authentication > Users, create yourself as a
--    user with your email + a password (this is your admin login).
-- 2. Copy that user's UUID (shown in the Users table).
-- 3. Run:  insert into public.admin_users (id, full_name) values ('PASTE-UUID-HERE', 'Your Name');
-- 4. That's it — only this user can log into /admin/index.html and see bookings.
-- 5. To add a second admin/technician login later, repeat steps 1–3.
