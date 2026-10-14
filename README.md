# SBAR Shift Handover — Full-stack starter

This project rebuilds the supplied HTML/JavaScript prototype into a Supabase-connected nursing handover application. The original pasted frontend is preserved under `reference/` for comparison.

## Included modules

- Email/password sign-in and account request flow
- Admin / Nurse profile roles (new sign-ups default to Nurse)
- Patient directory with MR number, ward, floor, room, bed, diagnosis, allergies and clinical status
- Shift-wise nursing assessment and notes (Morning / Evening / Night)
- Vital-sign observations and history
- Medication round records with scheduled and actual administration times and omission statuses
- Investigations, lab results, invoice/accession reference and optional secure report URL
- Structured SBAR handover and incoming-nurse acknowledgement
- Care tasks and completion tracking
- Discharge-planning checklist
- PostgreSQL schema, Row Level Security policies and audit triggers
- Responsive navy/teal design

## Important limitations

This is a starter implementation for evaluation and further development, not a certified electronic health record. It does not establish JCI accreditation or clinical safety compliance. It currently provides simple role-based access for a single organization; ward-level assignment restrictions, advanced medication-order verification, formal clinical escalation rules, validated audit retention, secure report-file storage, backup/recovery drills and institutional approval still need to be designed and tested before clinical use.

Use synthetic/demo patient data only until the hospital authorizes deployment and privacy/security review is complete. Do not store lab portal passwords or access secrets in the app. The `report_url` field should point only to a hospital-approved access-controlled report location.

## Step 1 — Create a Supabase project

1. Open [Supabase](https://supabase.com/) and create a project.
2. Open **SQL Editor** in the project dashboard.
3. Copy the complete contents of `sql/schema.sql`, paste it into a new SQL query and run it.
4. In **Project Settings → API Keys** (or the project's Connect dialog), copy the Project URL and the **publishable** key (older projects may call this the `anon` key).
5. Open `config.js` and replace `YOUR_PROJECT_ID` and `YOUR_SUPABASE_PUBLISHABLE_KEY` with your actual values.
6. Never paste a `service_role` or secret key into `config.js`, GitHub, or browser code. RLS is essential for protecting data.

Supabase references:
- JavaScript client: https://supabase.com/docs/reference/javascript/auth
- Securing data / RLS: https://supabase.com/docs/guides/database/secure-data
- API keys: https://supabase.com/docs/guides/getting-started/api-keys

## Step 2 — Run locally

Because the app uses JavaScript modules, open the project folder in VS Code and start a local static server. For example, install the **Live Server** extension and click **Go Live** from `index.html`. Do not simply open the HTML as a `file://` URL.

1. Open `index.html` through Live Server.
2. Choose **Request account** and create an account with an email you control.
3. If email confirmation is enabled, confirm the email first.
4. After signup, the database trigger creates a Nurse profile by default.
5. To promote the first approved administrator, open Supabase **Authentication → Users**, copy that user's UUID, then run this in SQL Editor (replace the placeholder):

```sql
update public.profiles
set role = 'admin'
where id = 'AUTH-USER-UUID-HERE';
```

6. Sign out and sign in again. Admin-only navigation will now be visible. Staff should never share accounts.

If sign-up is configured to require email confirmation, the app may not establish a session until the user confirms. Keep account approval and email confirmation settings consistent with hospital policy.

## Step 3 — Free online hosting with GitHub Pages

1. Create a GitHub repository for the project.
2. Upload all files and folders, including `index.html`, `styles.css`, `app.js`, `config.js`, and `sql/schema.sql`.
3. Open repository **Settings → Pages**.
4. Under build/deployment, choose **Deploy from a branch**, select `main` and `/ (root)`, then Save.
5. Wait for GitHub Pages to publish and open the displayed URL.
6. In Supabase **Authentication → URL Configuration**, add your GitHub Pages URL to the allowed Site URL / Redirect URLs as appropriate.
7. Test sign-in, sign-out, and database access with both Nurse and Admin accounts.

Free hosting and free database tiers have usage limits and availability constraints. Do not treat a public GitHub repository as private storage for patient data; the frontend source may be public. Data access must be enforced by Supabase Auth and database RLS, not by hiding UI buttons.

## Basic smoke test checklist

- [ ] Anonymous user cannot read patient records.
- [ ] New account gets the `nurse` role, not `admin`.
- [ ] Nurse can sign in and see only active-staff records allowed by the current policies.
- [ ] Nurse cannot read audit logs or change profile roles.
- [ ] Admin can view staff profiles and audit logs.
- [ ] Add a demo patient and confirm it persists after reload and from another signed-in device.
- [ ] Save a nursing note, vitals, medication record, investigation, SBAR, task and discharge plan.
- [ ] Acknowledge a handover and complete a task.
- [ ] Confirm audit log entries are generated for inserts/updates.
- [ ] Verify backup and recovery and test access rules before any real clinical use.

## Clinical and security notes

- The app does not replace clinical judgment, prescriptions, hospital protocols, or authorized discharge decisions.
- Risk status is manually selected; this starter does not calculate an Early Warning Score or make automated clinical decisions.
- Medication records are documentation, not prescribing or barcode medication administration.
- A secure report URL is only a reference; this starter does not upload or encrypt lab files itself.
- The RLS schema gives active nurses broad read/write access to the shared ward dataset because only Admin and Nurse roles were requested. Before clinical use, restrict records by ward/assignment and have a qualified database/security reviewer validate every policy.
- Audit logs store row snapshots for traceability. Restrict them to authorized admins, define retention rules, and assess whether all captured fields are appropriate for your institution.


## Update: discharge archive, refreshed theme, and security limitations

- Active patients now exclude rows with `discharged_at` set. The Active patients list includes a Discharge action with a confirmation prompt.
- The Discharged patients view lists archived patients and discharge timestamps. Patient records are retained; they are not deleted. Setting the discharge plan status to `Discharged` also archives that patient.
- The interface palette has been changed to a violet/slate theme.
- The configured `config.js` contains this project's Supabase URL and browser publishable key. Publishable keys are intended for client-side use only when Row Level Security (RLS) policies are correctly configured. Never expose a secret/service-role key.

### Important encryption and production limitations

This build is **not end-to-end encrypted (E2EE)**. Supabase HTTPS/TLS protects data in transit and the hosted database has platform-managed encryption at rest, but the backend can still process/read the clinical data under its access permissions. True E2EE requires a separate cryptographic design, client-side encryption/decryption, secure key distribution and recovery, and changes to search, audit, and workflows; it must not be represented as enabled in this prototype.

This project is not certified for hospital/production use. Before real patient records: obtain hospital/security/privacy approval, validate local clinical workflows, test RLS with multiple roles, restrict access by ward/assignment as required, enable MFA for administrators, configure custom SMTP, set up monitoring and backups/recovery, and arrange an independent security review. Do not use real patient data until these steps are complete.

### Email rate limits

The built-in Supabase Auth email service is limited (currently 2 emails/hour). Custom SMTP can increase this, but no provider offers unlimited sending without conditions; SMTP provider quotas and anti-abuse limits still apply. Configure Authentication → Emails → SMTP Settings with credentials from your verified email provider. Do not commit SMTP passwords or server-side secrets to this repository.
