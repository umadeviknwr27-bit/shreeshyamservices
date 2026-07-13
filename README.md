# Shree Shyam Services — Setup Guide

## What's built (MVP)
- Public site: Home, About, Services (5 pages), Pricing, Areas We Serve, Contact, Privacy Policy, Terms
- Working booking form → saves to Supabase `bookings` table
- Working contact form → saves to Supabase `contact_messages` table
- Admin dashboard (`/admin/index.html`) — login, view/filter bookings, view contact messages, assign technician/amount/notes, generate payment links, manage office location, manage payment details, edit all site text
- Site-wide content management (**Site Content** tab) — nearly every headline, price, and description on every page (home, about, pricing, all 5 service pages, services overview) is editable from admin with no code changes. Terms & Privacy Policy are intentionally left as static legal text.
- Business info (phone numbers, WhatsApp number, address, hours, social media links) is also admin-editable and updates everywhere it's used (nav, footer, schema markup)
- Logo and favicon (**Branding** tab) — upload your own, replaces the text "SS" badge and default browser tab icon instantly
- Social icons (Facebook, Instagram, YouTube, Google Reviews) in both the top bar and footer — only appear once you add a link for them
- Online payments (`/pay.html`) — manual UPI/QR, Bank Transfer, and PayTM cards (no payment gateway, no fees) with a WhatsApp-screenshot confirmation flow; admin marks bookings paid manually and can generate a fixed-amount link per booking
- Office map on Contact + Areas We Serve pages — address and coordinates are editable from admin (**Office Location** tab), not hardcoded, so no code changes needed to update it
- RLS policies locked down correctly from the start (see `supabase/schema.sql`)

## Not yet built (flagged earlier, still open)
- Technician dashboard (separate build — GPS/status/photo upload)
- Customer login/dashboard (currently guest-only booking)
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

## Step 2.5 — Set your office location
The map on the Contact and Areas We Serve pages reads its pin from Supabase,
not hardcoded coordinates. Easiest way: log into `/admin/index.html` → **Office
Location** tab → enter your latitude/longitude (right-click the spot on Google
Maps to copy them) → Save. No redeploy needed — it updates instantly.

## Step 2.6 — Editing site text (Site Content tab)
Almost every headline, price, and description across the site — Home, About,
Pricing, the Services overview, and all 5 individual service pages — is
editable from `/admin/index.html` → **Site Content** tab:
1. Pick a page from the dropdown.
2. Edit any field. Short fields are plain text boxes; longer ones (or ones
   containing tags like `<br/>`) are text areas — leave any tags in place
   unless you mean to change formatting.
3. Click **Save Page Content**. Changes are live immediately, no redeploy.

There's also a **Business Info** entry in that same dropdown — phone numbers,
WhatsApp number, address, and hours — which updates the nav, footer, and
booking-confirmation messages everywhere they appear.

**Not editable here, by design:** Terms & Conditions and Privacy Policy are
left as static legal text, since getting that wording right matters and a
freeform text box isn't the right tool for it — ask your developer if those
ever need to change. Everything else on the public site is fair game.

## Step 2.7 — Logo, favicon, and social icons
1. Log into `/admin/index.html` → **Branding** tab.
2. Upload a logo (replaces the "SS" text badge in the header) and/or a
   favicon (replaces the browser tab icon) — both update instantly, site-wide.
3. For social icons, go to **Site Content** tab → **Business Info** → paste
   in your Facebook, Instagram, YouTube, and/or Google Business profile URLs.
   Icons appear in the top bar and footer automatically — only for whichever
   links you've actually filled in.

**How it works, if you're curious:** every editable element in the HTML has
a `data-ck="some_key"` attribute. The `page_content` table in Supabase stores
`{page_key: 'home', content: {some_key: 'the text'}}` rows, and `main.js`
copies each value onto its matching element when the page loads. This means
adding more editable fields later is just: add a `data-ck` attribute to an
element in the HTML, add a matching key in Supabase, and it shows up in the
Site Content tab automatically — no new admin code needed.

## Step 3 — Deploy to Vercel
1. Push this folder to a GitHub repo.
2. Import the repo in Vercel → Framework preset: **Other** (static site) → Deploy.
3. Add your domain (`shreeshyamservices.in`) in Vercel → Domains.

## Step 4 — Set up online payments (UPI / Bank / PayTM — no gateway, no fees)
There's no payment gateway involved — customers pay you directly via UPI, bank
transfer, or PayTM, then send a screenshot on WhatsApp for you to confirm.
1. Log into `/admin/index.html` → **Payment Settings** tab.
2. Fill in whichever methods you want to offer:
   - **UPI ID** (e.g. `yourname@upi`) + the name you want shown to payers — this
     generates a scannable QR code automatically, no image upload needed.
   - **PayTM Number** — shown with its own QR and numbered steps.
   - **Bank Name / Account Number / IFSC / Account Holder Name** — shown as a
     plain table for NEFT transfers. Leave these blank if you don't want to
     offer bank transfer at all — that card just won't show up.
3. Save. `/pay.html` updates instantly — no redeploy needed.
4. **Optional — upload your own QR code image** instead of the auto-generated
   one (e.g. a screenshot of your bank/UPI app's QR): in the same tab, use the
   **UPI QR Code Image** / **PayTM QR Code Image** upload fields. This needs a
   Supabase Storage bucket called `site-assets`, which the schema SQL creates
   automatically (public bucket, admin-only upload). Note: an uploaded image
   is static and won't auto-fill the amount the way the generated QR does —
   the page still shows "Please pay ₹X" as text either way.
5. When a customer pays and sends a screenshot, open the booking in the
   **Bookings** tab and click the **Unpaid** button to flip it to **Paid**
   (click again to undo if needed).
6. To collect payment for one specific booking: set that booking's **Amount
   (₹)** field, click **Copy Payment Link**, and share it on WhatsApp — it
   opens `/pay.html` with that amount pre-filled into the UPI QR code and
   shown on-screen ("Please pay ₹X for booking #42").

## Step 5 — Cloudflare DNS (avoid the SSL loop issue from ZoomFly)
- If you point Cloudflare DNS at Vercel, set the DNS record proxy status to **DNS only (grey cloud)**, not proxied (orange cloud) — otherwise you'll hit SSL/redirect loops, same class of issue as the Vercel config conflict on ZoomFly.
- Alternatively, skip Cloudflare proxying entirely for now and just use Cloudflare as a DNS host; Vercel already provides SSL and a CDN.

## Step 6 — Google Business Profile (do this in parallel, not after launch)
Can be set up and collecting reviews before the website is even live:
- Business name: Shree Shyam Services
- Category: Air Conditioning Repair Service (primary); Appliance/Refrigerator/Washing Machine Repair Service (secondary)
- Address, phone, hours, service area: Dwarka, West Delhi
- Add photos of technicians/vehicle/work as you get them

## Step 7 — SEO basics
- Submit sitemap to Google Search Console once live (each page already has a title + meta description)
- The homepage has LocalBusiness schema markup built in — verify it in Google's Rich Results Test after deploy

---

## Pricing & warranty note
Pricing (`pricing.html`) is based on current Delhi NCR market rates (Urban Company, Icoolfix, Sahil Service, July 2026) — adjust up/down once you've run a few real jobs and know your actual margins and technician costs. Warranty terms (30-day labor, 7-day gas refill, 90-day parts) match common local practice; edit `pricing.html` and `terms.html` if you want different terms.
