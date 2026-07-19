-- ============================================================
-- TESTIMONIALS — additive migration only.
-- Safe to run on its own even though the rest of schema.sql
-- was already applied. Run this whole file once in the SQL Editor.
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

update public.page_content
set content = content || jsonb_build_object(
  'home_testimonials_eyebrow', 'Customer Reviews',
  'home_testimonials_heading', 'What our customers say'
)
where page_key = 'home' and not (content ? 'home_testimonials_heading');
