# Shree Shyam Services — source-code fixes

This update hardens the existing static HTML/CSS/JavaScript + Supabase project. It is not a full security certification and has not been connected to or tested against the live Supabase project.

## Changes made

1. Public booking and scrap forms now submit without requesting the inserted database row back. This removes the conflict between public inserts and the intentionally private bookings table. Success messages no longer expose a database booking ID.
2. Public booking payloads no longer send `status`; the database default sets it to `new`.
3. CMS-managed public page content is passed through a small HTML allowlist. Script tags, event handlers, inline styles, embedded content and unsafe URL protocols are not retained.
4. Admin booking phone values are rendered as `tel:` links only after extracting digits and validating a plausible length. Booking date/slot values are escaped before insertion into the admin table.
5. Scrap photo fallback folder names now follow the UUID path pattern used by the hardened storage policy.
6. Added `supabase/security-hardening.sql` to restrict anonymous inserts to customer fields, normalize phone numbers for rate limiting, validate key input lengths, and narrow anonymous scrap-photo upload paths.
7. Updated the base schema and ops-upgrade SQL with the safer insert/spam-guard/storage rules for future setup.

## Required Supabase action before deployment

1. Back up the Supabase database and note the current policies.
2. In Supabase Dashboard → SQL Editor, run `supabase/security-hardening.sql` after the existing `schema.sql` and `ops-upgrade.sql` have been applied.
3. Confirm the SQL completes without errors. Do not deploy the frontend until this migration succeeds, because the scrap form now relies on the column-level grant for `photo_paths`.
4. Deploy the updated website files.
5. Submit one test booking, one contact message and one scrap quote with a photo. Confirm each appears in the admin dashboard and that the photo is visible to an authenticated admin only.
6. Confirm an anonymous visitor cannot select, update or delete bookings, and cannot set status/payment/admin-only columns through the API.

## Important notes

- The booking success page does not display a booking ID because the public browser must not be allowed to read private booking rows. Admins can find the new request in the dashboard.
- The database-level `security-hardening.sql` migration is essential. Frontend changes alone cannot enforce column permissions or server-side validation.
- A public anon/publishable Supabase key in browser code is expected for a Supabase frontend. Never put a `service_role` key or database password in frontend files.
- This ZIP was checked with JavaScript syntax validation. Live database permissions, actual form delivery, admin authentication, storage access and hosting headers still require deployment-side tests.
