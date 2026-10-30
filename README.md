# Hasani Books Payroll Portal

**Employee management, attendance, payroll, payslips, branch operations and statutory reporting.**

> **Project status:** Neon-backed application architecture implemented in the current repository. Production deployment, end-to-end verification and historical employee-photo migration must be checked independently.  
> **Application:** Flutter (Android, iOS and Web)  
> **Backend:** Node.js, Express, PostgreSQL (`pg`), Prisma where applicable  
> **Primary database:** Neon PostgreSQL  
> **Hosting:** Render (backend; web deployment supported)  
> **Push notifications:** Firebase Cloud Messaging  
> **License:** Proprietary

## Overview

Hasani Payroll provides three principal roles:

- **Administrator:** Employee and branch management, payroll generation and history, attendance oversight, overtime approvals, statutory reporting, exports, EA Forms and system administration.
- **Branch user:** Branch-scoped attendance, rosters, overtime requests, daily reports and branch workflows.
- **Employee:** Self-service information, requests, notifications and available payslips.

The application processes sensitive employee and payroll information. Authorization must be enforced by the backend and database, not only by hidden UI controls.

## Current architecture

```text
Flutter Android / iOS / Web
    |
    | HTTPS + authenticated bearer JWT
    v
Node.js / Express API (Render)
    |-- Login, account recovery, JWT and role/branch checks
    |-- /api/data: PostgREST-compatible adapter for existing Flutter queries
    |-- Dedicated attendance, payroll and reporting endpoints
    |-- /api/employee-photos/:employeeId: private image API
    |-- /api/notifications/send: notification API
    |
    +--> Neon PostgreSQL
    |      |-- Employees, branches, attendance and payroll
    |      |-- Rosters, requests, EA Forms and notifications
    |      |-- Daily Report PIN hashes and authorization policies
    |      `-- app_private.employee_photos (private photo bytes)
    |
    `--> Firebase Cloud Messaging (push, when configured)
```

### Supabase migration status

The current Flutter client uses `lib/services/neon_api.dart` and the authenticated Node API. Its legacy `SupabaseService` class name is retained for compatibility, but its `database` client is initialized against the Node `/api/data` endpoint rather than a Supabase endpoint. The current Flutter dependency list does not include the Supabase SDK.

**Do not confuse source-code migration with production cutover.** Existing deployed clients may still run older builds until redeployed. Historical Supabase employee photos require a separate data-copy and validation process. Older `supabase/` migrations, filenames and comments may remain for historical reference; their presence alone does not mean the current client is calling Supabase.

**Employee photos currently use private Neon PostgreSQL storage, not Cloudflare R2.** R2-related configuration or earlier PR groundwork does not change the active `/api/employee-photos/:employeeId` implementation described in `backend/src/neon-employee-photos.js`.

## Key features

| Module | Scope |
|---|---|
| Employee and branch management | Employee profiles, branch assignment and status |
| Attendance | Daily entry, submission, review and overtime-related data |
| Rosters | Monthly and daily scheduling |
| Payroll | Monthly generation, calculation, review and history |
| Payslips | Employee payslip availability and PDF generation |
| Requests | Employee, leave and overtime workflows |
| Daily Reports | Branch-scoped access with saved PIN verification |
| EA Forms | Employee statutory tax forms |
| Exports | Payroll Excel, RHB bank format and statutory exports |
| Notifications | Neon inbox and optional Firebase push |
| Employee photos | Private, authenticated Neon photo API |

### Payroll calculation safeguards

Payroll calculation logic lives primarily in `lib/services/attendance_payroll_service.dart`. Preserve established business rules for authorized OT, public holidays, unpaid leave, working-time shortages and EPF/SOCSO/EIS contributions. Store and calculate work duration in **minutes**, not decimal representations of `HH:MM`.

Example: `1:23` is **83 minutes**, not 1.23 hours.

Never modify payroll formulas, statutory schedules or historical payroll records without confirming the relevant business rule and adding regression tests. Payroll periods are normalized to the first day of the selected month in the existing workflow.

## Repository layout

```text
lib/
  main.dart
  screens/
    admin_dashboard.dart
    branch_dashboard.dart
    employee_portal.dart
    attendance_dialog.dart
    supabase_service.dart       # legacy name; Node/Neon-backed adapter
  services/
    neon_api.dart               # API base URL, JWT and authenticated requests
    app_service.dart
    attendance_payroll_service.dart
    payroll_supabase_service.dart # legacy filename
    notification_service.dart
    pdf_service.dart
  widgets/
    employee_photo.dart
backend/
  src/
    server.js                   # Express API, auth and dedicated endpoints
    data-api.js                 # authenticated PostgREST-shaped Neon adapter
    neon-employee-photos.js     # private photo bytes and authorization
    notification-api.js        # Neon inbox and Firebase push
    application-schema.js      # application schema initialization
  migrations/
  prisma/
  test/
  docs/
test/
assets/
android/
ios/
web/
.github/workflows/
NEON_DEPLOYMENT.md
```

## Prerequisites

- Flutter SDK and compatible Dart SDK (check CI and `pubspec.yaml` for the exact version)
- Node.js and npm compatible with the backend dependencies
- A Neon PostgreSQL database and its server-side connection URL
- A Render service or equivalent HTTPS host for the Node API
- Firebase project configuration if push notifications are required

## Local setup

### Flutter

```bash
flutter doctor
flutter pub get
flutter run -d chrome
```

For the normal local workflow from the repository root:

```bash
# Terminal 1: start the API (requires backend/.env)
npm run backend:dev

# Terminal 2: open the Flutter dashboard in Chrome against that API
npm run preview
```

In VS Code, select **Hasani Payroll - Local Chrome** in Run and Debug. The
matching **Hasani: Start local backend** task is available from **Run Task**.
Both use `http://127.0.0.1:5001`, so local previewing does not require a push
or consume GitHub Actions minutes.

The frontend API URL is configured through a Dart environment definition. The current default is `https://hasaniworkhub.onrender.com`.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR-BACKEND.example
```

Use the correct API domain for each environment. Do not embed database passwords or privileged service credentials in Flutter builds.

### Node backend

```bash
cd backend
npm install
# Set environment variables in your local secret manager or untracked .env
npm run dev
```

See `backend/.env.example` for available settings. At minimum, a production deployment requires a valid `DATABASE_URL`, strong `JWT_SECRET`, and the applicable frontend/CORS configuration. Other login, OTP, email and review-account settings depend on enabled features.

**Do not commit `.env` files or real secrets.** Do not run `prisma db push` against the imported production database as a substitute for reviewed migrations.

## API and authorization

- Flutter authenticates with the Node backend and sends its bearer JWT on protected requests.
- `lib/services/neon_api.dart` provides authenticated JSON and photo requests.
- `backend/src/data-api.js` provides a constrained `/api/data/:table` adapter and `/api/data/rpc/:name` for permitted operations.
- The data adapter sets database identity claims and uses PostgreSQL's `authenticated` role so row-level policies can apply.
- Dedicated endpoints enforce additional admin, branch and employee scope checks.
- Do not broaden table allowlists, bypass role checks, disable policies or expose account/password/PIN tables to fix client errors.

A `PGRST...` error code can also come from the compatibility adapter; the error prefix alone does **not** prove a live Supabase request. Investigate the actual request URL and server response.

## Employee photos

The current active backend routes are:

```text
GET    /api/employee-photos/:employeeId
PUT    /api/employee-photos/:employeeId
DELETE /api/employee-photos/:employeeId
```

Photos are held privately in Neon's `app_private.employee_photos` table and are served through authenticated Node endpoints. The backend accepts JPEG, PNG and WebP with a 512 KB maximum and checks image signatures. Upload/delete are restricted to authorized administrators. The Flutter widget requests private image bytes and caches them within the active session.

Historical photos stored in Supabase Storage are **not automatically copied** merely because this API exists. Follow `backend/docs/neon-employee-photos.md` to migrate and verify those files before retiring the historical storage.

## Notifications

The application uses a Neon-backed inbox and the Node endpoint:

```text
POST /api/notifications/send
```

Firebase Cloud Messaging push delivery requires `FIREBASE_SERVICE_ACCOUNT_JSON` (or `FIREBASE_SERVICE_ACCOUNT`) on the backend. If absent, the notification may still be saved in Neon while push delivery is unavailable. Device token registration uses an authenticated database RPC.

Never put Firebase service-account private keys in Flutter or GitHub.

## Attendance, payroll and Daily Report

- **Attendance:** Confirm employee selection, branch scoping, submission, review and date/month filtering.
- **Generate Payroll:** Confirm active employee selection, attendance readiness, roster rules, calculation, authorized OT and safe overwrite behavior.
- **Payslips:** Confirm payroll availability, employee authorization, correct period and PDF output.
- **Daily Report:** Confirm saved PIN verification, correct branch context, lockout/error messages and existing PIN compatibility. Never reset PINs as an undocumented workaround.

A passing build does not establish that these flows work in production. Test with authorized accounts in a safe environment and avoid destructive tests against live payroll records.

## Testing and builds

Before pushing, run the repository-level local checks:

```bash
# Formatting, analysis and Flutter tests (also used by the optional hook)
npm run check:quick

# All quick checks, backend tests and a release Flutter web compilation
npm run check

# One-time setup: reject future pushes when quick checks fail
npm run hooks:install
```

The hook is intentionally opt-in because Git does not activate repository
hooks after cloning. You can bypass it for an exceptional push with
`git push --no-verify`, but the full local check is recommended before opening
or merging a pull request.

### Flutter

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

### Backend

```bash
cd backend
npm test
```

### Required release checks

1. Verify administrator, branch and employee JWT login/session renewal and unauthorized access rejection.
2. Verify employee and branch data isolation through the Node API and Neon policies.
3. Confirm attendance entry, employee lists and monthly attendance readiness.
4. Generate test payroll and confirm calculation totals without altering production payroll.
5. Generate and open payslips, verify correct employee and month.
6. Unlock Daily Report with existing authorized branch PINs and check lockout behavior.
7. Verify employee photo read/upload/delete and historical photo migration coverage.
8. Verify notification inbox delivery and Firebase push when configured.
9. Verify backend and Flutter deployment versions, environment variables, CORS and database backups.
10. Check GitHub Actions, backend tests and end-to-end results before declaring production ready.

## Deployment

See **[NEON_DEPLOYMENT.md](NEON_DEPLOYMENT.md)** for the current deployment process.

Recommended order:

1. Back up Neon and verify migrations/schema policies.
2. Deploy the backend with the correct Neon `DATABASE_URL`, JWT settings and secrets.
3. Verify backend health and authenticated API responses.
4. Build and deploy the Flutter web/mobile release using the intended `API_BASE_URL`.
5. Sign in again to refresh sessions and test every business-critical workflow.
6. Only retire legacy provider infrastructure after data parity, photo migration and live traffic verification.

Do not assume that merging a PR deploys Render, updates an installed Android app or replaces an older web bundle.

## Security and privacy

The application handles salary, identity documents, bank details, payroll exports, PINs and employee photos. Keep all sensitive information confidential. Restrict database credentials to the backend, use HTTPS, maintain least-privilege roles and enforce access server-side. Review Neon RLS and table grants before changing any policy.

Never commit JWT secrets, `DATABASE_URL`, SMTP passwords, Firebase service-account JSON, employee passwords, PINs, private photo data or production database dumps.

## Known verification items

- Confirm the deployed frontend and backend run the latest Neon-backed code.
- Complete and reconcile historical employee-photo migration.
- Validate JWT and PostgreSQL row policies across admin, branch and employee accounts.
- Confirm payroll generation, payslip PDF, attendance and Daily Report PINs with live-like test cases.
- Verify Firebase push credentials and actual device delivery.
- Audit remaining legacy Supabase references and external services before decommissioning.

**Status terminology:** "Implemented" means code exists; "CI passed" means automated checks passed; "Production verified" requires authenticated end-to-end testing on the deployed version. These are not interchangeable.

## License

Proprietary software. Refer to `LICENSE` for authoritative terms. Unauthorized copying, distribution, publication, resale or sublicensing is prohibited.
