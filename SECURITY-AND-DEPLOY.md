# Security and deployment gate

## Before deployment
- [ ] Confirm `config.js` contains only the Supabase URL and publishable key. Never use `service_role` or secret keys in browser code.
- [ ] Run and review `sql/schema.sql` in the intended Supabase project. Do not blindly rerun on a production database without reviewing migration impact.
- [ ] Test active/discharged patient filtering with non-production dummy records. Confirm the patient's clinical history remains available in the archive.
- [ ] Test RLS using separate nurse and admin accounts. Current prototype staff policies allow all active staff to see shared records; they are not ward-scoped.
- [ ] Configure custom SMTP and test signup, confirmation, and password reset. Sending limits are not unlimited.
- [ ] Enable MFA for administrators; review authentication rate limits, site URL, and allowed redirect URLs.
- [ ] Establish backups, recovery drills, incident response, audit review, and staff offboarding.
- [ ] Get hospital clinical, legal, privacy, and security approval before entering real patient information.

## Encryption statement
This prototype uses HTTPS for transport and Supabase platform protections. It is **not end-to-end encrypted**: the backend processes readable clinical records. E2EE requires a separately designed client-side cryptography and key-management system; do not advertise E2EE for this build.
