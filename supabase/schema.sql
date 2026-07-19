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

-- ---------- PAYMENT TRACKING (manual) ----------
-- No payment gateway is used — customers pay via UPI/Bank Transfer/PayTM
-- shown on /pay.html and send a screenshot on WhatsApp. You then mark the
-- booking as paid yourself from the admin dashboard.
alter table public.bookings add column if not exists payment_status text not null default 'unpaid'; -- 'unpaid','paid'
alter table public.bookings add column if not exists amount_paid numeric;

-- Dropping the old Razorpay-based payments table if you ran an earlier
-- version of this schema — no longer used now that payments are manual.
drop table if exists public.payments;

-- ============================================================
-- ROW LEVEL SECURITY — locked down by default, opened deliberately.
-- This is the step that was missed on the last project (open RLS on
-- `profiles`), so every table below is explicit about who can do what.
-- ============================================================

alter table public.bookings enable row level security;
alter table public.contact_messages enable row level security;
alter table public.admin_users enable row level security;

-- ---------- SITE SETTINGS (single row) ----------
-- Holds the office location AND payment details, both managed from the
-- admin dashboard instead of being hardcoded anywhere. Public pages read
-- this to render the map and the Pay Online page; only an admin can change it.
create table if not exists public.site_settings (
  id smallint primary key default 1,
  business_address text,
  latitude numeric,
  longitude numeric,
  upi_id text,
  upi_payee_name text,
  upi_qr_url text,
  paytm_number text,
  paytm_qr_url text,
  bank_name text,
  account_number text,
  ifsc_code text,
  account_holder_name text,
  logo_url text,
  favicon_url text,
  updated_at timestamptz not null default now(),
  constraint site_settings_singleton check (id = 1)
);

-- Migration-safe: adds the columns if you already ran an earlier version of
-- this schema and the create table above no-op'd.
alter table public.site_settings add column if not exists logo_url text;
alter table public.site_settings add column if not exists favicon_url text;

insert into public.site_settings (id, business_address, upi_payee_name, paytm_number)
values (1, 'B1/46 Bharat Vihar, Kakrola, near Deepika International School, Sector 14, Dwarka, New Delhi', 'Shree Shyam Services', '+919599459187')
on conflict (id) do nothing;

alter table public.site_settings enable row level security;

-- ---------- STORAGE (for uploaded QR code images) ----------
-- Public bucket so uploaded QR codes are viewable on /pay.html without auth.
insert into storage.buckets (id, name, public)
values ('site-assets', 'site-assets', true)
on conflict (id) do nothing;

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
drop policy if exists "anon can insert bookings" on public.bookings;
create policy "anon can insert bookings"
  on public.bookings for insert
  to anon
  with check (true);

-- Only admins can read/update/delete bookings.
drop policy if exists "admin can select bookings" on public.bookings;
create policy "admin can select bookings"
  on public.bookings for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admin can update bookings" on public.bookings;
create policy "admin can update bookings"
  on public.bookings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete bookings" on public.bookings;
create policy "admin can delete bookings"
  on public.bookings for delete
  to authenticated
  using (public.is_admin());

-- CONTACT MESSAGES policies (same pattern)
drop policy if exists "anon can insert contact messages" on public.contact_messages;
create policy "anon can insert contact messages"
  on public.contact_messages for insert
  to anon
  with check (true);

drop policy if exists "admin can select contact messages" on public.contact_messages;
create policy "admin can select contact messages"
  on public.contact_messages for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admin can update contact messages" on public.contact_messages;
create policy "admin can update contact messages"
  on public.contact_messages for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ADMIN_USERS policies — nobody can self-promote to admin via the API.
-- Rows are only ever inserted manually by you by editing the table
-- inside the Supabase Dashboard (Table Editor), never via the app.
drop policy if exists "admin can read admin_users" on public.admin_users;
create policy "admin can read admin_users"
  on public.admin_users for select
  to authenticated
  using (public.is_admin());

-- No insert/update/delete policy is created for admin_users at all —
-- meaning even a logged-in admin cannot change it through the API.
-- This is intentional: promoting a new admin is a manual, deliberate
-- action you take in the dashboard, not something the app can do.

-- SITE_SETTINGS policies — public pages need to read this to render the
-- office map, so anon (and authenticated) can select. Only admins can update.
drop policy if exists "anyone can read site settings" on public.site_settings;
create policy "anyone can read site settings"
  on public.site_settings for select
  to anon, authenticated
  using (true);

drop policy if exists "admin can update site settings" on public.site_settings;
create policy "admin can update site settings"
  on public.site_settings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- STORAGE policies for the site-assets bucket (QR code uploads etc.)
drop policy if exists "public can read site-assets" on storage.objects;
create policy "public can read site-assets"
  on storage.objects for select
  to public
  using (bucket_id = 'site-assets');

drop policy if exists "admin can upload site-assets" on storage.objects;
create policy "admin can upload site-assets"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'site-assets' and public.is_admin());

drop policy if exists "admin can update site-assets" on storage.objects;
create policy "admin can update site-assets"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'site-assets' and public.is_admin());

drop policy if exists "admin can delete site-assets" on storage.objects;
create policy "admin can delete site-assets"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'site-assets' and public.is_admin());

-- ============================================================
-- PAGE CONTENT (generic CMS) — every editable piece of text on the site
-- lives here as {page_key, content: {key: value}}. Any element in the
-- HTML with a data-ck="some_key" attribute gets its content replaced by
-- content.some_key at page load (see applyPageContent() in main.js).
-- Adding a new editable field anywhere is just: add a data-ck attribute in
-- the HTML + a matching key here — no code changes needed.
-- ============================================================
create table if not exists public.page_content (
  page_key text primary key,
  content jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.page_content enable row level security;

drop policy if exists "anyone can read page content" on public.page_content;
create policy "anyone can read page content"
  on public.page_content for select
  to anon, authenticated
  using (true);

drop policy if exists "admin can update page content" on public.page_content;
create policy "admin can update page content"
  on public.page_content for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can insert page content" on public.page_content;
create policy "admin can insert page content"
  on public.page_content for insert
  to authenticated
  with check (public.is_admin());

-- Seed data — matches the current site copy exactly, so nothing visually
-- changes until you edit something from admin's Site Content tab.
insert into public.page_content (page_key, content) values
  ('business_info', jsonb_build_object(
    'name', 'Shree Shyam Services',
    'phone_1', '+91 9599459187',
    'phone_2', '+91 7011509629',
    'whatsapp', '919599459187',
    'address', 'B1/46 Bharat Vihar, Kakrola, near Deepika International School, Sector 14, Dwarka, New Delhi',
    'hours', '10:00 AM – 10:00 PM, All 7 days',
    'facebook_url', '',
    'instagram_url', '',
    'youtube_url', '',
    'google_url', ''
  )),
  ('home', jsonb_build_object(
    'home_hero_eyebrow', 'Dwarka &amp; West Delhi · Same-Day Service',
    'home_hero_title', 'Your AC stopped cooling.<br/>We start the fix today.',
    'home_hero_lead', 'AC, refrigerator and washing machine repair from technicians who show you the price before they touch a screw. No inflated gas-refill quotes, no vanishing after the advance.',
    'home_trust_1_value', '₹199',
    'home_trust_1_label', 'Visit Charge Only',
    'home_trust_2_value', '30-Day',
    'home_trust_2_label', 'Service Warranty',
    'home_trust_3_value', '10AM–10PM',
    'home_trust_3_label', '7 Days a Week',
    'home_stats_1_value', '3',
    'home_stats_1_label', 'Appliances We Repair',
    'home_stats_2_value', '10+',
    'home_stats_2_label', 'Areas Covered',
    'home_stats_3_value', '₹199',
    'home_stats_3_label', 'Diagnosis Visit',
    'home_stats_4_value', '30-Day',
    'home_stats_4_label', 'Service Warranty',
    'home_whatwefix_eyebrow', 'What we fix',
    'home_whatwefix_heading', 'Three appliances. One technician you can trust.',
    'home_service_1_title', 'AC Repair &amp; Service',
    'home_service_1_desc', 'Gas refill, cooling issues, PCB repair, split &amp; window AC — general service or full diagnosis.',
    'home_service_2_title', 'Refrigerator Repair',
    'home_service_2_desc', 'Not cooling, gas leaks, compressor issues, unusual noise — single-door and double-door units.',
    'home_service_3_title', 'Washing Machine Repair',
    'home_service_3_desc', 'Drum motor, drainage, spin cycle, PCB faults — front-load and top-load machines.',
    'home_service_4_title', 'AC Installation',
    'home_service_4_desc', 'New split or window AC installation, uninstallation for shifting, copper piping included.',
    'home_service_5_title', 'Annual Maintenance (AMC)',
    'home_service_5_desc', 'Two scheduled services a year, priority booking, and a waived visit charge for the whole year.'
  ) || jsonb_build_object(
    'home_service_6_title', 'Not sure what''s wrong?',
    'home_service_6_desc', 'Describe the problem on WhatsApp — we''ll tell you likely cause and rough cost before booking.',
    'home_howit_1_title', '1. Book',
    'home_howit_1_desc', 'Tell us the appliance and issue — online, by call, or WhatsApp. Takes under a minute.',
    'home_howit_2_title', '2. Diagnose',
    'home_howit_2_desc', 'A technician visits, inspects the appliance, and quotes the exact repair cost before starting.',
    'home_howit_3_title', '3. Fix &amp; Warranty',
    'home_howit_3_desc', 'Repair is completed same-visit wherever possible, backed by a written service warranty.',
    'home_pricing_eyebrow', 'Straight pricing',
    'home_pricing_heading', 'No surprise bill at the end',
    'home_pricing_subtext', 'Starting prices for the most common calls we get. Final cost depends on tonnage, brand, and parts needed — always confirmed before work starts.',
    'home_price_1_label', 'AC Gas Refill',
    'home_price_1_amount', '₹2,200<span class="unit">+</span>',
    'home_price_1_desc', '1.5 ton split, R32/R410A',
    'home_price_2_label', 'AC General Service',
    'home_price_2_amount', '₹499<span class="unit">+</span>',
    'home_price_2_desc', 'Split AC, foam jet clean',
    'home_price_3_label', 'Split AC Installation',
    'home_price_3_amount', '₹1,499<span class="unit">+</span>',
    'home_price_3_desc', 'Standard copper piping',
    'home_price_4_label', 'Visit / Diagnosis',
    'home_price_4_amount', '₹199',
    'home_price_4_desc', 'Waived if repair is booked',
    'home_area_eyebrow', 'Service area',
    'home_area_heading', 'Currently serving Dwarka &amp; West Delhi',
    'home_area_text', 'Sector 6 · Sector 7 · Sector 10 · Sector 12 · Sector 14 · Sector 22 · Uttam Nagar · Najafgarh',
    'home_office_eyebrow', 'Visit us',
    'home_office_heading', 'Our office'
  )),
  ('about', jsonb_build_object(
    'about_hero_eyebrow', 'About Us',
    'about_hero_title', 'Local technicians, straight answers',
    'about_hero_lead', 'Shree Shyam Services is based in Sector 14, Dwarka — we repair and install ACs, refrigerators and washing machines across Dwarka and West Delhi.',
    'about_why_heading', 'Why we started',
    'about_why_text', 'Most appliance repair calls in Delhi end the same way — an inflated gas-refill quote, a technician who disappears after taking an advance, or a "repair" that breaks again in a week. We built Shree Shyam Services to fix that: one number to call, a technician who tells you the price before touching anything, and a warranty we actually honour.',
    'about_how_heading', 'How we work',
    'about_how_text', 'Every job starts with a diagnosis, not a guess. You''re told the likely cause and the cost range before we book a slot, and the final price is confirmed again on-site before any repair begins. No surprises on the bill.',
    'about_where_heading', 'Where we work',
    'about_where_text', 'B1/46 Bharat Vihar, Kakrola, near Deepika International School, Sector 14, Dwarka, New Delhi — serving Dwarka and West Delhi, 10 AM to 10 PM, all 7 days.'
  )),
  ('pricing', jsonb_build_object(
    'pricing_hero_eyebrow', 'Pricing',
    'pricing_hero_title', 'Prices you can check before we arrive',
    'pricing_hero_lead', 'Starting rates for Dwarka &amp; West Delhi. Final cost depends on tonnage, brand and parts required — always confirmed and agreed with you before repair work begins.',
    'pricing_section_1_heading', 'Visit Charge',
    'pricing_row_1_label', 'Inspection / Diagnosis Visit',
    'pricing_row_1_amount', '₹199',
    'pricing_row_1_desc', 'Waived if you proceed with the repair. Charged only for visit + diagnosis if you decide not to continue.',
    'pricing_section_2_heading', 'AC Repair &amp; Service',
    'pricing_row_2_label', 'General Service — Split AC',
    'pricing_row_2_amount', '₹499<span class="unit">+</span>',
    'pricing_row_3_label', 'General Service — Window AC',
    'pricing_row_3_amount', '₹399<span class="unit">+</span>',
    'pricing_row_4_label', 'Gas Refill — Split AC',
    'pricing_row_4_amount', '₹2,200<span class="unit">+</span>',
    'pricing_row_5_label', 'Gas Refill — Window AC',
    'pricing_row_5_amount', '₹1,800<span class="unit">+</span>',
    'pricing_row_6_label', 'PCB / Electronic Repair',
    'pricing_row_6_amount', '₹1,500 – ₹3,500',
    'pricing_row_7_label', 'Compressor Repair/Replace',
    'pricing_row_7_amount', '₹4,500 – ₹9,500',
    'pricing_section_3_heading', 'AC Installation &amp; Uninstallation',
    'pricing_row_8_label', 'Split AC Installation',
    'pricing_row_8_amount', '₹1,499<span class="unit">+</span>',
    'pricing_row_9_label', 'Window AC Installation',
    'pricing_row_9_amount', '₹799<span class="unit">+</span>'
  ) || jsonb_build_object(
    'pricing_row_10_label', 'Split AC Uninstallation',
    'pricing_row_10_amount', '₹599',
    'pricing_row_11_label', 'Window AC Uninstallation',
    'pricing_row_11_amount', '₹399',
    'pricing_section_4_heading', 'Refrigerator Repair',
    'pricing_row_12_label', 'Diagnosis / General Check',
    'pricing_row_12_amount', '₹299<span class="unit">+</span>',
    'pricing_row_13_label', 'Gas Charging',
    'pricing_row_13_amount', '₹1,800 – ₹2,800',
    'pricing_row_14_label', 'Compressor Repair/Replace',
    'pricing_row_14_amount', '₹3,500 – ₹6,000',
    'pricing_section_5_heading', 'Washing Machine Repair',
    'pricing_row_15_label', 'Diagnosis / General Check',
    'pricing_row_15_amount', '₹299<span class="unit">+</span>',
    'pricing_row_16_label', 'Drum Motor / Drainage Repair',
    'pricing_row_16_amount', '₹800 – ₹2,000',
    'pricing_row_17_label', 'PCB Repair',
    'pricing_row_17_amount', '₹1,200 – ₹2,500',
    'pricing_section_6_heading', 'Annual Maintenance Contract (AMC)',
    'pricing_row_18_label', '1 Split/Window AC',
    'pricing_row_18_amount', '₹1,999<span class="unit">/year</span>',
    'pricing_row_19_label', 'Each Additional AC',
    'pricing_row_19_amount', '₹1,499<span class="unit">/year</span>',
    'pricing_warranty_heading', 'Our Warranty Policy'
  )),
  ('contact', jsonb_build_object(
    'contact_hero_eyebrow', 'Contact',
    'contact_hero_title', 'Get in touch'
  )),
  ('areas', jsonb_build_object(
    'areas_hero_eyebrow', 'Areas We Serve',
    'areas_hero_title', 'Dwarka &amp; West Delhi',
    'areas_hero_lead', 'If your area isn''t listed, call or WhatsApp us — we''re expanding coverage regularly.',
    'areas_cta_heading', 'Not in this list?'
  )),
  ('services_index', jsonb_build_object(
    'svcidx_eyebrow', 'Services',
    'svcidx_title', 'Everything we repair, installed and serviced',
    'svcidx_1_title', 'AC Repair &amp; Service',
    'svcidx_1_desc', 'No cooling, gas leaks, PCB faults, foam-jet cleaning for split &amp; window ACs.',
    'svcidx_2_title', 'Refrigerator Repair',
    'svcidx_2_desc', 'Not cooling, gas charging, compressor issues, unusual noise or leaks.',
    'svcidx_3_title', 'Washing Machine Repair',
    'svcidx_3_desc', 'Drum motor, drainage, spin cycle and PCB faults — front &amp; top load.',
    'svcidx_4_title', 'AC Installation',
    'svcidx_4_desc', 'New AC installation, uninstallation for shifting, with proper copper piping.',
    'svcidx_5_title', 'AMC — Annual Maintenance',
    'svcidx_5_desc', 'Two scheduled services a year with a waived visit charge all year round.'
  )),
  ('service_ac_repair', jsonb_build_object(
    'svc_acrepair_eyebrow', 'AC Repair &amp; Service',
    'svc_acrepair_title', 'AC Repair Near Me — Dwarka &amp; West Delhi',
    'svc_acrepair_lead', 'Not cooling, water leaking, strange noise, or just due for a service — our technicians diagnose on the spot and quote before they start.',
    'svc_acrepair_problems_heading', 'Common AC problems we fix',
    'svc_acrepair_problem_1_title', 'Not Cooling',
    'svc_acrepair_problem_1_desc', 'Usually low gas or a blocked filter — diagnosed on the spot.',
    'svc_acrepair_problem_2_title', 'Water Leaking',
    'svc_acrepair_problem_2_desc', 'Blocked drain pipe or improper indoor unit tilt.',
    'svc_acrepair_problem_3_title', 'Strange Noise',
    'svc_acrepair_problem_3_desc', 'Loose panel, fan imbalance, or compressor wear.',
    'svc_acrepair_problem_4_title', 'AC Not Turning On',
    'svc_acrepair_problem_4_desc', 'PCB fault, remote/sensor issue, or power supply problem.',
    'svc_acrepair_problem_5_title', 'Ice Formation on Coil',
    'svc_acrepair_problem_5_desc', 'Sign of low refrigerant or restricted airflow.',
    'svc_acrepair_problem_6_title', 'High Electricity Bill',
    'svc_acrepair_problem_6_desc', 'Dirty filters or coils reducing efficiency — deep clean helps.',
    'svc_acrepair_pricing_heading', 'Pricing',
    'svc_acrepair_price_1_label', 'General Service — Split AC',
    'svc_acrepair_price_1_amount', '₹499<span class="unit">+</span>',
    'svc_acrepair_price_2_label', 'Gas Refill — Split AC',
    'svc_acrepair_price_2_amount', '₹2,200<span class="unit">+</span>',
    'svc_acrepair_price_3_label', 'PCB Repair',
    'svc_acrepair_price_3_amount', '₹1,500 – ₹3,500',
    'svc_acrepair_why_heading', 'Why book with Shree Shyam Services',
    'svc_acrepair_why_1_title', 'Price before repair',
    'svc_acrepair_why_1_desc', 'You approve the cost after diagnosis, before any work starts.',
    'svc_acrepair_why_2_title', '30-day warranty',
    'svc_acrepair_why_2_desc', 'Same-fault warranty on labor, honoured without argument.',
    'svc_acrepair_why_3_title', 'Local &amp; fast',
    'svc_acrepair_why_3_desc', 'Based in Dwarka Sector 14 — we''re usually 20–30 minutes away.',
    'svc_acrepair_cta_heading', 'Book your AC technician now'
  )),
  ('service_ac_installation', jsonb_build_object(
    'svc_acinstall_eyebrow', 'AC Installation',
    'svc_acinstall_title', 'AC Installation &amp; Uninstallation — Dwarka',
    'svc_acinstall_lead', 'New split or window AC installed with proper copper piping and outdoor unit mounting — or safely uninstalled if you''re shifting homes.',
    'svc_acinstall_included_heading', 'What''s included',
    'svc_acinstall_item_1_title', 'Wall Mounting',
    'svc_acinstall_item_1_desc', 'Indoor unit bracket fitted and leveled.',
    'svc_acinstall_item_2_title', 'Outdoor Unit Setup',
    'svc_acinstall_item_2_desc', 'Secure mounting on wall bracket or stand.',
    'svc_acinstall_item_3_title', 'Copper Piping',
    'svc_acinstall_item_3_desc', 'Standard length included, extra piping charged separately.',
    'svc_acinstall_item_4_title', 'Vacuuming &amp; Testing',
    'svc_acinstall_item_4_desc', 'Full system check before we leave.',
    'svc_acinstall_item_5_title', 'Drain Pipe Fitting',
    'svc_acinstall_item_5_desc', 'Proper slope to avoid leaks.',
    'svc_acinstall_item_6_title', 'Safe Uninstallation',
    'svc_acinstall_item_6_desc', 'Gas recovery done properly when shifting.',
    'svc_acinstall_pricing_heading', 'Pricing',
    'svc_acinstall_price_1_label', 'Split AC Installation',
    'svc_acinstall_price_1_amount', '₹1,499<span class="unit">+</span>',
    'svc_acinstall_price_2_label', 'Window AC Installation',
    'svc_acinstall_price_2_amount', '₹799<span class="unit">+</span>',
    'svc_acinstall_price_3_label', 'Uninstallation (Split/Window)',
    'svc_acinstall_price_3_amount', '₹399 – ₹599',
    'svc_acinstall_cta_heading', 'Book your AC installation now'
  )),
  ('service_amc', jsonb_build_object(
    'svc_amc_eyebrow', 'Annual Maintenance Contract',
    'svc_amc_title', 'Stop reacting to breakdowns. Get ahead of them.',
    'svc_amc_lead', 'Two scheduled services a year, a waived visit charge every time you call us, and priority slots when Delhi''s summer gets busy.',
    'svc_amc_plan_1_label', '1 Split/Window AC',
    'svc_amc_plan_1_amount', '₹1,999<span class="unit">/year</span>',
    'svc_amc_plan_2_label', 'Each Additional AC',
    'svc_amc_plan_2_amount', '₹1,499<span class="unit">/year</span>',
    'svc_amc_why_heading', 'Why an AMC makes sense before summer',
    'svc_amc_why_1_title', 'Fewer breakdowns',
    'svc_amc_why_1_desc', 'Scheduled cleaning catches gas leaks and dirt build-up before they cause a no-cooling emergency.',
    'svc_amc_why_2_title', 'Lower electricity bills',
    'svc_amc_why_2_desc', 'A clean, well-serviced AC runs more efficiently.',
    'svc_amc_why_3_title', 'Skip the queue',
    'svc_amc_why_3_desc', 'AMC customers get priority slots during peak summer demand.',
    'svc_amc_cta_heading', 'Set up your AMC today'
  )),
  ('service_fridge_repair', jsonb_build_object(
    'svc_fridge_eyebrow', 'Refrigerator Repair',
    'svc_fridge_title', 'Refrigerator Repair — Dwarka &amp; West Delhi',
    'svc_fridge_lead', 'Single-door, double-door, or side-by-side — not cooling, gas leaks, compressor noise or ice build-up, diagnosed and quoted on the spot.',
    'svc_fridge_problems_heading', 'Common refrigerator problems we fix',
    'svc_fridge_problem_1_title', 'Not Cooling',
    'svc_fridge_problem_1_desc', 'Low gas, faulty thermostat, or blocked vents.',
    'svc_fridge_problem_2_title', 'Water Leaking',
    'svc_fridge_problem_2_desc', 'Blocked defrost drain or door seal issue.',
    'svc_fridge_problem_3_title', 'Excess Frost/Ice',
    'svc_fridge_problem_3_desc', 'Defrost heater or timer fault.',
    'svc_fridge_problem_4_title', 'Compressor Noise',
    'svc_fridge_problem_4_desc', 'Worn compressor or loose mounting.',
    'svc_fridge_problem_5_title', 'Freezer Not Freezing',
    'svc_fridge_problem_5_desc', 'Gas leak or compressor performance drop.',
    'svc_fridge_problem_6_title', 'Door Not Sealing',
    'svc_fridge_problem_6_desc', 'Worn gasket replacement.',
    'svc_fridge_pricing_heading', 'Pricing',
    'svc_fridge_price_1_label', 'Diagnosis / General Check',
    'svc_fridge_price_1_amount', '₹299<span class="unit">+</span>',
    'svc_fridge_price_2_label', 'Gas Charging',
    'svc_fridge_price_2_amount', '₹1,800 – ₹2,800',
    'svc_fridge_price_3_label', 'Compressor Repair/Replace',
    'svc_fridge_price_3_amount', '₹3,500 – ₹6,000',
    'svc_fridge_cta_heading', 'Book your refrigerator technician now'
  )),
  ('service_washing_machine', jsonb_build_object(
    'svc_washer_eyebrow', 'Washing Machine Repair',
    'svc_washer_title', 'Washing Machine Repair — Dwarka &amp; West Delhi',
    'svc_washer_lead', 'Front-load or top-load, semi or fully automatic — drainage, spin cycle, drum motor and PCB faults fixed at your home.',
    'svc_washer_problems_heading', 'Common washing machine problems we fix',
    'svc_washer_problem_1_title', 'Not Draining',
    'svc_washer_problem_1_desc', 'Blocked drain pump or hose.',
    'svc_washer_problem_2_title', 'Not Spinning',
    'svc_washer_problem_2_desc', 'Drum motor or belt issue.',
    'svc_washer_problem_3_title', 'Excess Noise/Vibration',
    'svc_washer_problem_3_desc', 'Unbalanced load sensor or worn bearings.',
    'svc_washer_problem_4_title', 'Not Turning On',
    'svc_washer_problem_4_desc', 'PCB or power supply fault.',
    'svc_washer_problem_5_title', 'Water Leaking',
    'svc_washer_problem_5_desc', 'Door seal, hose, or drain pump gasket.',
    'svc_washer_problem_6_title', 'Won''t Complete Cycle',
    'svc_washer_problem_6_desc', 'Timer or control board fault.',
    'svc_washer_pricing_heading', 'Pricing',
    'svc_washer_price_1_label', 'Diagnosis / General Check',
    'svc_washer_price_1_amount', '₹299<span class="unit">+</span>',
    'svc_washer_price_2_label', 'Drum Motor / Drainage Repair',
    'svc_washer_price_2_amount', '₹800 – ₹2,000',
    'svc_washer_price_3_label', 'PCB Repair',
    'svc_washer_price_3_amount', '₹1,200 – ₹2,500',
    'svc_washer_cta_heading', 'Book your washing machine technician now'
  ))
on conflict (page_key) do nothing;

-- Migration-safe merge for existing projects: if you already ran an earlier
-- version of this schema, the INSERT above no-ops (the row exists) and
-- business_info won't have the new social link keys yet. This adds them
-- without touching anything you've already customized via Site Content.
update public.page_content
set content = content || jsonb_build_object('facebook_url', '', 'instagram_url', '', 'youtube_url', '', 'google_url', '')
where page_key = 'business_info' and not (content ? 'facebook_url');

-- ============================================================
-- TESTIMONIALS — customer reviews shown on the homepage.
-- Admin-managed (add/edit/delete/publish from the dashboard).
-- Only published rows are visible to the public; unpublished rows
-- stay in the admin's list so you can draft one before it goes live.
-- No sample rows are seeded here on purpose — displaying invented
-- customer quotes on a live business site would be misleading.
-- ============================================================
create table if not exists public.testimonials (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  customer_name text not null,
  service_type text,
  rating smallint not null default 5 check (rating between 1 and 5),
  quote text not null,
  is_published boolean not null default true,
  sort_order int not null default 0
);

alter table public.testimonials enable row level security;

drop policy if exists "anyone can read published testimonials" on public.testimonials;
create policy "anyone can read published testimonials"
  on public.testimonials for select
  to anon, authenticated
  using (is_published = true);

drop policy if exists "admin can read all testimonials" on public.testimonials;
create policy "admin can read all testimonials"
  on public.testimonials for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admin can insert testimonials" on public.testimonials;
create policy "admin can insert testimonials"
  on public.testimonials for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update testimonials" on public.testimonials;
create policy "admin can update testimonials"
  on public.testimonials for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete testimonials" on public.testimonials;
create policy "admin can delete testimonials"
  on public.testimonials for delete
  to authenticated
  using (public.is_admin());

-- Adds the homepage section heading to the existing 'home' page_content
-- row without touching anything else you've already customized.
update public.page_content
set content = content || jsonb_build_object(
  'home_testimonials_eyebrow', 'Customer Reviews',
  'home_testimonials_heading', 'What our customers say'
)
where page_key = 'home' and not (content ? 'home_testimonials_heading');

-- ============================================================
-- SETUP STEPS (do these after running the SQL above)
-- ============================================================
-- 1. In Supabase Dashboard > Authentication > Users, create yourself as a
--    user with your email + a password (this is your admin login).
-- 2. Copy that user's UUID (shown in the Users table).
-- 3. Run:  insert into public.admin_users (id, full_name) values ('PASTE-UUID-HERE', 'Your Name');
-- 4. That's it — only this user can log into /admin/index.html and see bookings.
-- 5. To add a second admin/technician login later, repeat steps 1–3.
