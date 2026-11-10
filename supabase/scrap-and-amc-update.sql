-- ============================================================
-- Scrap buying + multi-appliance AMC — run ONCE in Supabase SQL Editor.
-- Safe to re-run. No table changes; scrap requests reuse `bookings`
-- (service_type = 'scrap-ac' / 'scrap-refrigerator' / 'scrap-washing-machine' / 'scrap-multiple').
-- !! Prices below are STARTING PLACEHOLDERS — confirm with the client, then edit in Admin > Pricing.
-- ============================================================

-- AMC plans (existing 2 AC rows keep their sort_order 18/19 and any price edits you made)
insert into public.pricing_items (category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
select * from (values
  ('Annual Maintenance Contract (AMC)', 'AC Comprehensive Plan',        '₹3,999/year', null, 32, false, 'amc'),
  ('Annual Maintenance Contract (AMC)', 'Fridge Care Plan',             '₹999/year',   null, 33, false, 'amc'),
  ('Annual Maintenance Contract (AMC)', 'Fridge Comprehensive Plan',    '₹2,499/year', null, 34, false, 'amc'),
  ('Annual Maintenance Contract (AMC)', 'Washer Care Plan',             '₹899/year',   null, 35, false, 'amc'),
  ('Annual Maintenance Contract (AMC)', 'Washer Comprehensive Plan',    '₹1,999/year', null, 36, false, 'amc')
) as v(category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
where not exists (select 1 from public.pricing_items where service_page = 'amc' and item_label = 'AC Comprehensive Plan');

-- Existing AC rows: rename to match the new plan names (only if untouched)
update public.pricing_items set item_label = 'AC Care Plan — 1 AC'
  where service_page = 'amc' and item_label = '1 Split/Window AC';
update public.pricing_items set item_label = 'AC Care Plan — Each Additional AC'
  where service_page = 'amc' and item_label = 'Each Additional AC';

-- Scrap buying: shown as "quote on inspection" so no wrong number goes live.
-- Change price_text to e.g. 'Up to ₹5,000' from Admin > Pricing once the client decides.
insert into public.pricing_items (category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
select * from (values
  ('Scrap Buying (We Buy Old Appliances)', 'Old AC (split / window)',  'Best price on inspection', 'Depends on brand, tonnage, age and condition', 37, false, 'scrap-buying'),
  ('Scrap Buying (We Buy Old Appliances)', 'Old Refrigerator',          'Best price on inspection', 'Single-door, double-door, side-by-side',       38, false, 'scrap-buying'),
  ('Scrap Buying (We Buy Old Appliances)', 'Old Washing Machine',       'Best price on inspection', 'Semi-auto, top-load, front-load',              39, false, 'scrap-buying'),
  ('Scrap Buying (We Buy Old Appliances)', 'Home Pickup',               'Free',                     'Across Dwarka & West Delhi',                   40, false, 'scrap-buying')
) as v(category, item_label, price_text, description, sort_order, show_on_homepage, service_page)
where not exists (select 1 from public.pricing_items where service_page = 'scrap-buying');

-- Editable page text (merged, so existing edits are kept)
insert into public.page_content (page_key, content) values
  ('service_scrap_buying', jsonb_build_object(
    'svc_scrap_eyebrow', 'Sell Old Appliances',
    'svc_scrap_title', 'Sell your old AC, fridge or washing machine — we collect it from your door.',
    'svc_scrap_lead', 'Working or not working, we buy it. Free home pickup across Dwarka &amp; West Delhi, with a fair price quoted after a quick inspection.',
    'svc_scrap_what_heading', 'What we buy',
    'svc_scrap_item_1_title', 'Old Air Conditioners',
    'svc_scrap_item_1_desc', 'Split and window ACs of any brand and tonnage — running, repairable or completely dead.',
    'svc_scrap_item_2_title', 'Old Refrigerators',
    'svc_scrap_item_2_desc', 'Single-door, double-door and side-by-side units, with or without a working compressor.',
    'svc_scrap_item_3_title', 'Old Washing Machines',
    'svc_scrap_item_3_desc', 'Semi-automatic, fully automatic top-load and front-load machines.',
    'svc_scrap_how_heading', 'How it works',
    'svc_scrap_step_1_title', '1. Tell us what you have',
    'svc_scrap_step_1_desc', 'Fill the form below or send photos on WhatsApp — brand, age and condition is enough.',
    'svc_scrap_step_2_title', '2. We inspect &amp; quote',
    'svc_scrap_step_2_desc', 'Our technician checks the appliance and gives you a price on the spot. No obligation to sell.',
    'svc_scrap_step_3_title', '3. Pickup &amp; payment',
    'svc_scrap_step_3_desc', 'If you agree, we take it away the same visit and pay you immediately.',
    'svc_scrap_price_note', 'Final price depends on brand, age, size and working condition, and is confirmed after inspection.',
    'svc_scrap_form_heading', 'Get your free quote',
    'svc_scrap_cta_heading', 'Clear out the old. Get paid for it.'
  )),
  ('service_amc', jsonb_build_object(
    'svc_amc_ac_heading', 'Air Conditioner AMC',
    'svc_amc_fridge_heading', 'Refrigerator AMC',
    'svc_amc_washer_heading', 'Washing Machine AMC',
    'svc_amc_terms_note', '*Covered parts and exclusions (such as compressor, PCB, drum motor, or damage from misuse) are listed in the AMC terms shared at sign-up. Ask us on WhatsApp for the full list.'
  )),
  ('services_index', jsonb_build_object(
    'svcidx_9_title', 'Sell Your Old Appliances',
    'svcidx_9_desc', 'We buy old and non-working ACs, refrigerators and washing machines — free home pickup.',
    'svcidx_5_desc', 'Yearly plans for AC, refrigerator and washing machine — scheduled services, waived visit charge.'
  )),
  ('home', jsonb_build_object(
    'home_service_10_title', 'Sell Your Old Appliances',
    'home_service_10_desc', 'We buy old and non-working AC, refrigerator and washing machine with free home pickup.'
  ))
on conflict (page_key) do update
  set content = public.page_content.content || excluded.content,
      updated_at = now();
