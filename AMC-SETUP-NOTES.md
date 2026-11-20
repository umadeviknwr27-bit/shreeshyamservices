# AMC page and admin workflow update

## What changed
- Rebuilt `/services/amc.html` as a responsive AMC landing page with five enquiry-led plans: AC Basic Care, AC Premium Care, Refrigerator Care, Washing Machine Care, and Family Home Care.
- Plan cards describe the proposed preventive-maintenance scope, exclusions, eligibility and booking flow.
- Public prices are intentionally not hard-coded. The earlier suggested amounts (AC Basic ₹1,499; AC Premium ₹2,499; Refrigerator ₹1,499; Washing Machine ₹1,499; Family ₹3,999) are draft commercial recommendations only and should be approved after technician-cost and service-area checks.
- AMC CTAs prefill `/book-service.html?service=amc&plan=...`.
- The booking form now reveals AMC-specific fields for preferred plan, appliance type, model, age and condition when AMC is selected.
- AMC details are stored in the existing `bookings.notes` field so no new public database table or anonymous write policy is needed.
- Admin AMC form now supports a configurable visit allowance and contract notes.
- Admin AMC list displays a 60-day renewal review summary and highlights contracts expiring within 60 days.
- Admin renewal action starts the renewed contract the day after the previous expiry date; visit count resets after confirmation.
- WhatsApp renewal follow-up remains a manual action from the admin panel. No customer message is sent automatically.

## Database compatibility
The existing `public.amc_contracts` table in `supabase/ops-upgrade.sql` already contains `visits_total`, `visits_done`, `amount_paid` and `notes`. No additional AMC schema migration is required for these page/admin changes, provided that the existing ops upgrade has been applied.

## Before publishing
1. Confirm actual plan prices and profitability with the business owner.
2. Confirm the number and exact scope of preventive visits for each plan.
3. Confirm whether the labour discount is approved and define its exclusions.
4. Have the business owner approve written cancellation, rescheduling, payment and warranty terms.
5. Deploy to staging and test one AMC enquiry, one manually created contract, visit completion, renewal and WhatsApp link.
6. Confirm the admin user can access `amc_contracts` through the existing `public.is_admin()` policy.

## Important
The landing page is enquiry-led and does not collect online payment or activate a contract automatically. Admin must verify eligibility, share the final written scope/quote, confirm payment, and then create/activate the contract in the admin dashboard.
