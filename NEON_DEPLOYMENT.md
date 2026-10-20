# Completing the Neon cutover

The Flutter client uses the existing Node API for login and data. Remaining
PostgREST-shaped queries go to `/api/data` on that same backend and use the
existing backend access token. There is no Supabase SDK, provider URL/key,
Edge Function call, or database fallback. Existing service class names are
retained so screens do not need unrelated rewrites.

## Render deployment

1. Deploy the backend first with its existing Neon `DATABASE_URL`, authentication
   secrets, build command and `npm start`. The database URL must use the owner
   role: startup applies `backend/migrations/20261020_neon_application_api.sql`
   once in a transaction. This restores missing application RPCs and row access
   policies over the imported tables; it does not import or rewrite payroll rows.
   A private migration record prevents repeat execution on restart.
2. On the **frontend** Render service, keep **Build Command** as `npm install`
   and **Publish Directory** as `build/web`. The root package now runs
   `bash scripts/render-build-web.sh` after installation, compiling Flutter.
   You can also use that script directly as the Build Command. The backend
   keeps its separate `backend/package.json` and existing build command.
3. If using a different backend domain, set frontend `API_BASE_URL` before the
   build. It defaults to `https://hasaniworkhub.onrender.com`. Keep the frontend
   domain in the backend's existing CORS allowlist.
4. Redeploy the frontend after the backend is healthy. Reload the browser and
   sign in again to refresh its session. A previous prebuilt `build/web` bundle
   will continue to call the old provider until it is rebuilt and served.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NEON_DATA_API_URL`, and a separate Data API
JWT signing key are not used by this Flutter connection. Do not run `prisma db
push` against the imported production schema to deploy this change.

## Photos and notifications

Photos are stored as optimized image bytes in private Neon table
`app_private.employee_photos`. The backend creates this table at startup.
No R2 account, storage API key or additional Render variable is needed.
Authenticated `/api/employee-photos/:employeeId` requests return bytes only
when the caller can see that employee through existing Neon row policies.
Only administrators within their existing employee scope may upload/delete.
JPEG, PNG and WebP uploads are limited to 512 KB; the app optimizes to 480 px.

Existing Supabase photo files must be copied separately. See
[photo migration instructions](backend/docs/neon-employee-photos.md).

## Access controls

The generic adapter exposes only the tables and RPCs used by the app, validates
identifiers and parameterizes values. Each transaction sets the verified server
identity then switches to the `authenticated` database role, enforcing employee
and branch row policies. Application accounts, PIN hashes and device tokens are
not exposed as generic tables. Existing dedicated Neon APIs remain in place.

CI checks the migration against a schema-only local Postgres fixture, including
cross-employee/branch access denial, and builds the Flutter web client.
