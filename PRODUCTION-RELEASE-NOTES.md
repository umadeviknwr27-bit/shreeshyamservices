# Shree Shyam Services — deployment package

This archive combines the latest supplied AMC update, earlier booking/security fixes, and a correction to the homepage appliance count. It is **not production-certified**: live Supabase permissions, actual form submissions, uploads, admin roles, payments, and deployment headers have not been tested in this environment.

## Required before switching production traffic
1. Back up current site and database. Review existing schema/migrations; **do not blindly rerun schema.sql** on an active database.
2. If not already applied, review and apply `supabase/security-hardening.sql` after confirming the `schema.sql` and `ops-upgrade.sql` schema objects exist. Test SQL in a staging Supabase project first.
3. Confirm Supabase URL and public anon key in `assets/js/main.js` match your project. Never put a service-role key in frontend code.
4. Review and approve AMC plan scope, prices, discounts, exclusions and cancellation policy. AMC page is enquiry-led, not online contract checkout.
5. Run staging smoke tests: repair booking, contact message, AMC enquiry, scrap quote with photo, admin login and permissions, scrap photo access, AMC contract creation/renewal, phone and WhatsApp links, mobile navigation.
6. Confirm live HTTPS, sitemap/robots, security headers and analytics/conversion events; then deploy to production.
7. The homepage statistic may be overwritten by the `page_content` CMS key `home_stats_1_value`; update the matching CMS value in admin if it still shows '3'.

## Scope limits
No automated payments or automatic customer WhatsApp reminders. Scrap purchasing remains an enquiry/admin-managed workflow, not a full inventory and payout ledger. Do not treat an untested upload as proof of successful customer enquiry delivery.
