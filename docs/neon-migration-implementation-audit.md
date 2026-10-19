# Neon migration implementation audit

Status: **in progress — not ready to merge as the completed migration**

This audit is based on the current `feature/full-neon-migration` branch and read-only inspection of the connected Neon schema.

## Confirmed repository dependencies on Supabase

Flutter code still depends directly on Supabase in these areas:

- Startup: `lib/main.dart` calls `SupabaseService.initialize()`.
- Authentication and data loading: `lib/services/app_service.dart` still uses `Supabase.instance.client` for users, employees, payroll, attendance, storage auth, and RPC calls.
- Data service: `lib/screens/supabase_service.dart` still accesses employees, payroll, attendance, branches, rosters, requests, notifications, and storage.
- Payroll generation: `lib/services/attendance_payroll_service.dart` directly reads/writes payroll, employees, salary defaults, attendance, and rosters.
- Notification registration: `lib/services/notification_service.dart` calls the Supabase RPC `register_notification_device`.
- Photos: `lib/widgets/employee_photo.dart` creates Supabase Storage signed URLs.
- Realtime: EA forms, attendance, payroll, and employee notifications subscribe to Supabase Realtime.
- Additional code: `lib/services/payroll_supabase_service.dart` and other screens still import or call Supabase APIs.

Removing only the package or startup initialization now would break runtime code. Each operation needs a corresponding authenticated backend endpoint or a supported replacement (for example Firebase for push delivery, not as a database).

## Confirmed Neon schema differences

The connected Neon database has physical tables including `app_user`, `employees`, `payroll`, `attendance`, `branches`, `employee_salary_defaults`, `monthly_rosters`, `daily_rosters`, `employee_requests`, `leave_requests`, `overtime_requests`, `employee_ea_forms`, and notification tables.

The current Prisma schema contains models `app_user`, `Employee`, `PayrollRecord`, `SalaryIncrement`, `DeviceToken`, `Notification`, `NotificationRecipient`, and `Announcement`. It does not yet model all the existing Neon tables and several fields/keys differ. For example, Neon `employees` uses `employee_id` as its primary key; Neon `app_user` uses `username` as its primary key and does not have the `id` column assumed in several backend queries. The Neon `payroll` columns also differ from the Prisma `PayrollRecord` field set.

Do not run `prisma db push` against this database as a shortcut: it may attempt schema changes that are not a safe representation of the existing payroll data.

## Required implementation order

1. Align Prisma models/field mappings with the real Neon schema, or deliberately use parameterized SQL for tables that do not fit the legacy Prisma models.
2. Fix backend authentication and user queries to use the actual Neon `app_user` key and columns. Keep passwords hashed and all account lookups authenticated/authorized.
3. Implement and test backend APIs for employees, payroll, attendance, salary defaults, branches, rosters, leave/OT requests, EA forms, notifications, photo upload/serving, and the RPCs currently used by Flutter.
4. Replace every direct Supabase database, storage, RPC, and realtime call in Flutter with those APIs or an explicit replacement.
5. Remove `supabase_flutter`, Supabase initialization, and obsolete Supabase deployment artifacts only after the replacement paths are complete.
6. Run backend tests, Flutter analyze/tests/build, and validate a staging login, payroll view/import, attendance, and photo flow against Neon.
7. Merge only after CI passes and the old Flutter application is verified against the Neon-backed backend.

## Safety status

- This audit is documentation only.
- No production database schema/data was modified.
- No production deployment was changed.
- This PR is intentionally draft and is not the completed migration.
