# Shree Shyam Services — Setup Guide

## What's built (MVP)
- Public site: Home, About, Services (5 pages), Pricing, Areas We Serve, Contact, Privacy Policy, Terms
- Working booking form → saves to Supabase `bookings` table
- Working contact form → saves to Supabase `contact_messages` table
- Admin dashboard (`/admin/index.html`) — login, view/filter bookings, update status
- RLS policies locked down correctly from the start (see `supabase/schema.sql`)

## Not yet built (flagged earlier, still open)
- Technician dashboard (separate build — GPS/status/photo upload)
- Customer login/dashboard (currently guest-only booking)
- Razorpay payment integration
- Blog pages (folder structure ready, content not written)
- Real logo (currently text-based brand mark — swap in once you share the logo file)

---

## Step 1 — Create your Supabase project
1. Go to supabase.com → New Project.
2. Once created, go to **SQL Editor** → paste the entire contents of `supabase/schema.sql` → Run.
3. Go to **Project Settings → API** → copy your **Project URL** and **anon public key**.
4. Open `assets/js/main.js` and replace:
   ```js
   const SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL";
   const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
   ```

## Step 2 — Create your admin login
1. In Supabase Dashboard → **Authentication → Users** → Add User → enter your email + a password.
2. Copy that user's UUID from the Users table.
3. Back in **SQL Editor**, run:
   ```sql
   insert into public.admin_users (id, full_name) values ('PASTE-UUID-HERE', 'Your Name');
   ```
4. You can now log in at `/admin/index.html` with that email/password.

## Step 3 — Deploy to Vercel
1. Push this folder to a GitHub repo.
2. Import the repo in Vercel → Framework preset: **Other** (static site) → Deploy.
3. Add your domain (`shreeshyamservices.in`) in Vercel → Domains.

## Step 4 — Cloudflare DNS (avoid the SSL loop issue from ZoomFly)
- If you point Cloudflare DNS at Vercel, set the DNS record proxy status to **DNS only (grey cloud)**, not proxied (orange cloud) — otherwise you'll hit SSL/redirect loops, same class of issue as the Vercel config conflict on ZoomFly.
- Alternatively, skip Cloudflare proxying entirely for now and just use Cloudflare as a DNS host; Vercel already provides SSL and a CDN.

## Step 5 — Google Business Profile (do this in parallel, not after launch)
Can be set up and collecting reviews before the website is even live:
- Business name: Shree Shyam Services
- Category: Air Conditioning Repair Service (primary); Appliance/Refrigerator/Washing Machine Repair Service (secondary)
- Address, phone, hours, service area: Dwarka, West Delhi
- Add photos of technicians/vehicle/work as you get them

## Step 6 — SEO basics
- Submit sitemap to Google Search Console once live (each page already has a title + meta description)
- The homepage has LocalBusiness schema markup built in — verify it in Google's Rich Results Test after deploy

---

## Pricing & warranty note
Pricing (`pricing.html`) is based on current Delhi NCR market rates (Urban Company, Icoolfix, Sahil Service, July 2026) — adjust up/down once you've run a few real jobs and know your actual margins and technician costs. Warranty terms (30-day labor, 7-day gas refill, 90-day parts) match common local practice; edit `pricing.html` and `terms.html` if you want different terms.
