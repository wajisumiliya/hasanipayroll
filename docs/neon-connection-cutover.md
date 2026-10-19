# Neon connection cutover

Status: connection wiring prepared; production cutover blocked by database and hosting configuration.

## Connection contract

The Flutter database client is selected by `NEON_DATA_API_URL` at build time.
Every Flutter table query and RPC uses `SupabaseService.database`, including
AppService employee writes, attendance, account listings, and garden RPCs.
An empty URL preserves the existing Supabase build; it does not enable Neon.
Never put a PostgreSQL connection string or database password in a Flutter define.

The existing Node backend remains the identity provider. Its `accessToken` is
used for Node API requests and legacy Supabase services. Its separate RS256
`dataAccessToken` is used only for Neon Data API requests. Login and first-login
password creation already issue this token when configured; `/api/auth/me` now
reissues it during session restoration. Flutter persists both tokens, clears
database authorization on logout, and rejects a Neon login without a data token.

Supabase Storage, Edge Functions for push delivery, and Realtime remain separate
dependencies. Importing PostgreSQL tables does not migrate those services. This
change alone is not a complete removal of Supabase.

## Verified target, 2026-10-19

- Project: `autumn-unit-60993710` / Hasani Payroll Temporary.
- Branch: `br-plain-math-a1dzfyv2` / main.
- Database: `hasani_payroll` (not `neondb`).
- Read-only `SELECT current_database(), current_user` succeeded.
- The Data API is not provisioned on this database.
- All 30 public tables have row security disabled; do not expose them through
  the Data API with default broad grants.
- The 11 RPCs called by Flutter are absent:
  `admin_branch_activity_logs`, `approve_employee_request`,
  `change_daily_report_pin`, `get_employee_garden`,
  `record_employee_garden_visit`, `register_notification_device`,
  `schedule_monthly_payslip_release`, `set_employee_active_status`,
  `tend_employee_garden`, `transfer_staff`, `verify_daily_report_pin`.
- Trigger functions are present. Trigger-function parity is different from
  application RPC parity. Garden wrappers additionally depend on the aquarium
  functions, which are absent too.

These observations are from the connected database, not assumptions about the
import. No production schema or payroll records were modified.

## Required before enabling the build

1. Restore and adapt the application's RPCs, identity helpers, and role/row
   access policies on an isolated Neon development branch. Their existing
   definitions are in `supabase/migrations`. Do not replay all historical
   migrations against imported payroll: some contain data changes and cron or
   Supabase-specific dependencies. Test admin, branch, request-admin, attendance
   admin, employee, and reviewer scopes, including negative access checks.
2. Configure the backend Render service's `DATABASE_URL` with the Neon pooled
   connection for `hasani_payroll`. Set a server-only RSA private key in
   `DATA_API_JWT_PRIVATE_KEY`; keep its key ID and issuer stable. No database
   URL or signing key belongs in Git or Flutter. Do not run `prisma db push`:
   the committed legacy Prisma schema differs from the imported tables.
3. Verify `https://hasaniworkhub.onrender.com/.well-known/jwks.json` publishes
   the matching public verification key. Provision Neon Data API with external
   authentication using that JWKS URL, only after privileges and row access
   policies pass tests. Never enable anonymous access to payroll tables.
4. Rebuild the original Flutter application, not `NEON_PREVIEW`:

   ```sh
   flutter build web --release \
     --dart-define=API_BASE_URL=https://hasaniworkhub.onrender.com \
     --dart-define=NEON_DATA_API_URL=<verified-Neon-Data-API-URL>
   ```

   Verify the Render service's linked Git branch, build command, and publish
   directory. This repository tracks `build/web`; a service publishing those
   existing assets will not pick up a Dart source change without a fresh build.
5. Run Flutter analysis/tests and web/Android builds. Verify login, session
   restoration, logout, dashboard, attendance, rosters, requests, payroll,
   payslips, and exports against staging. Confirm browser database traffic goes
   to Neon and an employee cannot access another employee's data.
6. Migrate photo storage, push dispatch, and live updates separately if the
   requirement is to remove every Supabase dependency. A Neon Data API endpoint
   does not provide Supabase Storage, Functions, or Realtime endpoints.

## Validation in this workspace

- `node --check backend/src/server.js`: passed.
- `node backend/test/identity.test.js`: all eight existing tests passed.
- Added Flutter tests for separate token selection, missing Neon credentials,
  legacy compatibility, and clearing authorization on logout.
- Flutter/Dart SDKs are unavailable here, and the workspace network proxy is
  unreachable. Flutter analysis, tests, and builds must run in GitHub CI before
  merging. Live Neon application flows remain unverified.

Keep the change on a draft branch until these prerequisites are satisfied.
Render automatically deploys GitHub changes; merging to its deployment branch
before the prerequisites are met is not a verified cutover.
