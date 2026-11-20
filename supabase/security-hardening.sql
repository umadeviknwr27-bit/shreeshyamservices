-- Security hardening migration for Shree Shyam Services.
-- Run in Supabase SQL Editor after the existing schema.sql and ops-upgrade.sql.
-- Safe to re-run. Public visitors may submit customer fields only; workflow,
-- payment and assignment fields remain controlled by the admin/database.

-- Remove broad table-level INSERT grants, then grant only customer-submitted columns.
revoke insert on table public.bookings from public, anon, authenticated;
grant insert (
  customer_name, phone, service_type, appliance_brand, address, area,
  preferred_date, preferred_slot, notes, photo_paths
) on table public.bookings to anon;

revoke insert on table public.contact_messages from public, anon, authenticated;
grant insert (name, phone, message) on table public.contact_messages to anon;

-- Normalize phone numbers and enforce basic server-side validation and limits.
create or replace function public.limit_public_inserts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
      or length(coalesce(new.service_type, '')) > 80
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
    if length(trim(coalesce(new.name, ''))) < 2
      or length(coalesce(new.name, '')) > 120
      or length(coalesce(new.message, '')) > 2000 then
      raise exception 'Some message details are invalid or too long.';
    end if;
    if (select count(*) from public.contact_messages
        where regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = normalized_phone
          and created_at > now() - interval '10 minutes') >= 3 then
      raise exception 'Too many messages — please call us directly.';
    end if;
  end if;
  return new;
end;
$$;

-- Restrict anonymous photo uploads to generated UUID folders and expected filenames.
drop policy if exists "anon can upload scrap photos" on storage.objects;
create policy "anon can upload scrap photos"
  on storage.objects for insert to anon
  with check (
    bucket_id = 'scrap-photos'
    and name ~* '^[0-9a-f-]{36}/[1-3]\.(jpg|png|webp)$'
  );
