-- ============================================================
-- PRICING ITEMS — single source of truth for every price shown
-- on the site (homepage teaser, individual service pages, and the
-- main Pricing page all read from this one table). Managed from
-- Admin -> Pricing. Safe to run on its own or as part of schema.sql.
-- ============================================================
create table if not exists public.pricing_items (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  category text not null,
  item_label text not null,
  price_text text not null,
  description text,
  sort_order int not null default 0,
  show_on_homepage boolean not null default false,
  service_page text
);

alter table public.pricing_items enable row level security;

drop policy if exists "anyone can read pricing items" on public.pricing_items;
create policy "anyone can read pricing items"
  on public.pricing_items for select
  to anon, authenticated
  using (true);

drop policy if exists "admin can insert pricing items" on public.pricing_items;
create policy "admin can insert pricing items"
  on public.pricing_items for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update pricing items" on public.pricing_items;
create policy "admin can update pricing items"
  on public.pricing_items for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete pricing items" on public.pricing_items;
create policy "admin can delete pricing items"
  on public.pricing_items for delete
  to authenticated
  using (public.is_admin());

-- Seed with the current live prices ONLY if the table is empty, so this
-- never overwrites prices you've already edited via the admin. If you
-- ever delete every single row on purpose, re-running this will restore
-- these starting defaults.
insert into public.pricing_items (category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
select * from (values
  ('Visit Charge', 'Inspection / Diagnosis Visit', '₹199', 'Waived if you proceed with the repair. Charged only for visit + diagnosis if you decide not to continue.', 1, true, null),
  ('AC Repair & Service', 'General Service — Split AC', '₹499+', 'Foam jet clean, filter wash', 2, true, 'ac-repair'),
  ('AC Repair & Service', 'General Service — Window AC', '₹399+', null, 3, false, 'ac-repair'),
  ('AC Repair & Service', 'Gas Refill — Split AC', '₹2,200+', '1.5 ton split, R32/R410A', 4, true, 'ac-repair'),
  ('AC Repair & Service', 'Gas Refill — Window AC', '₹1,800+', null, 5, false, 'ac-repair'),
  ('AC Repair & Service', 'PCB / Electronic Repair', '₹1,500 – ₹3,500', 'Depends on brand &amp; fault', 6, false, 'ac-repair'),
  ('AC Repair & Service', 'Compressor Repair/Replace', '₹4,500 – ₹9,500', null, 7, false, 'ac-repair'),
  ('AC Installation & Uninstallation', 'Split AC Installation', '₹1,499+', 'Standard copper piping', 8, true, 'ac-installation'),
  ('AC Installation & Uninstallation', 'Window AC Installation', '₹799+', null, 9, false, 'ac-installation'),
  ('AC Installation & Uninstallation', 'Split AC Uninstallation', '₹599', 'For shifting / storage', 10, false, 'ac-installation'),
  ('AC Installation & Uninstallation', 'Window AC Uninstallation', '₹399', null, 11, false, 'ac-installation'),
  ('Refrigerator Repair', 'Diagnosis / General Check', '₹299+', null, 12, false, 'refrigerator-repair'),
  ('Refrigerator Repair', 'Gas Charging', '₹1,800 – ₹2,800', null, 13, false, 'refrigerator-repair'),
  ('Refrigerator Repair', 'Compressor Repair/Replace', '₹3,500 – ₹6,000', 'Genuine part cost extra', 14, false, 'refrigerator-repair'),
  ('Washing Machine Repair', 'Diagnosis / General Check', '₹299+', null, 15, false, 'washing-machine-repair'),
  ('Washing Machine Repair', 'Drum Motor / Drainage Repair', '₹800 – ₹2,000', null, 16, false, 'washing-machine-repair'),
  ('Washing Machine Repair', 'PCB Repair', '₹1,200 – ₹2,500', null, 17, false, 'washing-machine-repair'),
  ('Annual Maintenance Contract (AMC)', '1 Split/Window AC', '₹1,999/year', null, 18, false, 'amc'),
  ('Annual Maintenance Contract (AMC)', 'Each Additional AC', '₹1,499/year', null, 19, false, 'amc')
) as v(category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
where not exists (select 1 from public.pricing_items);
