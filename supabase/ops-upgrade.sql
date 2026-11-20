-- ============================================================
-- Ops upgrade: spam guard, scrap seller records + photos, AMC contract tracker.
-- Run ONCE in Supabase SQL Editor AFTER scrap-and-amc-update.sql. Safe to re-run.
-- ============================================================

-- 1) Scrap purchase records + photo paths on bookings
alter table public.bookings add column if not exists seller_id_ref text;
alter table public.bookings add column if not exists photo_paths text[];

-- 2) Spam guard — runs as definer so it can count rows even though anon cannot read them.
create or replace function public.limit_public_inserts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  normalized_phone text;
begin
  normalized_phone := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
  if length(normalized_phone) < 10 or length(normalized_phone) > 15 then
    raise exception 'Please enter a valid phone number.';
  end if;
  new.phone := normalized_phone;
  if tg_table_name = 'bookings' then
    if length(trim(coalesce(new.customer_name, ''))) < 2
      or length(coalesce(new.customer_name, '')) > 120
      or length(coalesce(new.address, '')) > 500
      or length(coalesce(new.notes, '')) > 2000 then
      raise exception 'Some booking details are invalid or too long.';
    end if;
    if (select count(*) from public.bookings
        where regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = normalized_phone
          and created_at > now() - interval '10 minutes') >= 3 then
      raise exception 'Too many requests — please call us directly.';
    end if;
  elsif tg_table_name = 'contact_messages' then
    if length(coalesce(new.message, '')) > 2000 or length(new.name) > 120 then
      raise exception 'Some message details are invalid or too long.';
    end if;
    if (select count(*) from public.contact_messages
        where regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = normalized_phone
          and created_at > now() - interval '10 minutes') >= 3 then
      raise exception 'Too many messages — please call us directly.';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists bookings_spam_guard on public.bookings;
create trigger bookings_spam_guard before insert on public.bookings
  for each row execute function public.limit_public_inserts();
drop trigger if exists contact_spam_guard on public.contact_messages;
create trigger contact_spam_guard before insert on public.contact_messages
  for each row execute function public.limit_public_inserts();

-- 3) Private bucket for scrap photos: anyone may upload (images only, 3 MB max); only admins can view/delete.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scrap-photos', 'scrap-photos', false, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "anon can upload scrap photos" on storage.objects;
create policy "anon can upload scrap photos" on storage.objects for insert to anon
  with check (
    bucket_id = 'scrap-photos'
    and name ~* '^[0-9a-f-]{36}/[1-3]\.(jpg|png|webp)$'
  );
drop policy if exists "admin can read scrap photos" on storage.objects;
create policy "admin can read scrap photos" on storage.objects for select to authenticated
  using (bucket_id = 'scrap-photos' and public.is_admin());
drop policy if exists "admin can delete scrap photos" on storage.objects;
create policy "admin can delete scrap photos" on storage.objects for delete to authenticated
  using (bucket_id = 'scrap-photos' and public.is_admin());

-- 4) AMC contract tracker (admin-only)
create table if not exists public.amc_contracts (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  customer_name text not null,
  phone text not null,
  address text,
  plan text not null,
  appliances text,
  start_date date not null,
  end_date date not null,
  visits_total int not null default 2,
  visits_done int not null default 0,
  amount_paid numeric,
  status text not null default 'active',   -- 'active','cancelled'
  notes text
);
alter table public.amc_contracts enable row level security;
drop policy if exists "admin full access amc" on public.amc_contracts;
create policy "admin full access amc" on public.amc_contracts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
