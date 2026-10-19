# Neon migration audit — Flutter compatibility

## Status

The `neon-dev` branch contains a Node.js/Express API backed by PostgreSQL through Prisma and the `pg` adapter. The Flutter app is **not yet fully migrated**: it still initializes Supabase in `lib/main.dart` and `lib/screens/supabase_service.dart`, and it still performs direct Supabase queries in both `SupabaseService` and `AppService`.

This audit intentionally does not change production payroll behavior or database data.

## Confirmed current boundaries

### Flutter
- `lib/main.dart` calls `SupabaseService.initialize()` during startup.
- `lib/screens/supabase_service.dart` owns the Supabase client and direct reads/writes for employees, payroll, attendance, rosters, requests, notifications, reports, photos, and branch activity.
- `lib/services/app_service.dart` calls the backend for authentication-related requests, but also queries Supabase directly for users, employees, salary defaults, payroll, attendance and branch activity.
- `pubspec.yaml` still includes `supabase_flutter`.

### Backend API currently exposed in `backend/src/server.js`
- `GET /health`
- Authentication: `POST /api/auth/login`, `POST /api/auth/change-password`, forgot-password verification/reset, `GET /api/auth/me`, user lookup, OTP and set-password routes.
- Admin employee account/status routes.
- Admin payroll read/import/delete routes and employee payroll reads.

### Neon
- The connected Neon project `Hasani Payroll Temporary` has a ready default branch.
- The database includes tables for `employees`, `branches`, `attendance`, `payroll`, `employee_salary_defaults`, `monthly_rosters`, `daily_rosters`, `overtime_requests`, `leave_requests`, `employee_requests`, `app_notifications`, `notification_reads`, and additional import/report tables.
- Table presence alone does not prove that the current backend schema, API contracts, permissions, or production data are aligned.

## Why a base-URL swap is insufficient

The existing Flutter client makes PostgREST-style calls directly against Supabase and relies on Supabase Storage, Realtime, RPCs, and RLS behavior. The current backend does not expose compatible endpoints for every one of these operations. Replacing the URL or disabling Supabase initialization now would break existing screens and workflows.

## Migration phases

### Phase 1 — inventory and parity
1. Inventory every direct Supabase table query, Storage operation, Realtime subscription, and RPC used by Flutter.
2. Map each operation to a documented API endpoint and verify its authorization and response shape.
3. Compare the live Neon schema with the required data contract without changing production data.
4. Add API contract tests and a non-production integration-test configuration.

### Phase 2 — backend compatibility layer
1. Add explicit, typed endpoints for one workflow at a time.
2. Enforce JWT identity, role, branch scope, and employee scope server-side.
3. Keep payroll formulas and statutory contribution rules in the existing tested Flutter service until a separate, validated migration is approved.
4. Add transaction and regression tests for all writes.

### Phase 3 — Flutter adapter
1. Introduce a typed API client with a configured `API_BASE_URL`.
2. Migrate authentication/session handling and one workflow at a time.
3. Preserve existing Supabase-backed features until their replacement endpoints and storage/realtime alternatives pass tests.
4. Do not bundle server secrets or a Neon connection string in the Flutter app.

### Phase 4 — staged verification
1. Run `flutter pub get`, `dart format --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test`.
2. Build the existing Android APK/AAB and web target.
3. Run integration tests against a dedicated Neon development branch and synthetic data.
4. Verify login, attendance, roster, OT, payroll calculation, payroll save/history, payslip, and statutory exports before switching any production traffic.

### Phase 5 — release
1. Confirm backup and rollback plan.
2. Deploy the backend with secrets configured in the hosting platform.
3. Test the existing app against the staged API before Play Store release.
4. Keep the existing production Supabase path available until all required features have passed parity checks.

## Acceptance checklist

- [ ] No unapproved direct Supabase database calls remain in migrated workflows.
- [ ] No production credentials are included in Flutter or Git.
- [ ] All API routes enforce role and record-level authorization.
- [ ] Payroll and statutory regression tests pass.
- [ ] Neon schema/data mapping verified for each migrated table.
- [ ] Existing Android and web builds succeed.
- [ ] Login, attendance, rosters, requests, notifications, payslips and exports pass staged tests.
- [ ] Rollback plan tested before production cutover.

## Current decision

Do not merge a change that disables Supabase initialization or points all screens to the current API until endpoint parity has been implemented and verified. The current branch is suitable for isolated backend/API work and compile checks, not yet for a full production cutover.
