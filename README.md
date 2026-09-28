# Hasani Books Payroll Portal

Production payroll, attendance, roster, employee self-service, branch operations and statutory export system for Hasani Books.

> **Flutter:** 3.47.0 stable · **Dart:** 3.13.0  
> **Primary data platform:** Supabase  
> **Additional backend:** Node.js / Express / Prisma  
> **Mobile CI:** GitHub Actions  
> **License:** Proprietary

## Overview

Hasani Payroll supports three application roles:

- **Admin** — company-wide employee, attendance, OT, payroll, statutory, export and administrative operations.
- **Branch** — branch employee attendance, roster, OT requests and branch operations.
- **Employee** — self-service portal, attendance information, requests, notifications and payslips.

This is a production payroll system. Payroll, attendance and statutory rules must not be changed from assumptions. Inspect the current implementation, confirm the business rule and add regression coverage before modifying calculations.

## Architecture

```text
Flutter application
├── Direct Supabase access
│   ├── employees
│   ├── branches
│   ├── attendance
│   ├── payroll
│   ├── employee_salary_defaults
│   ├── monthly_rosters
│   ├── daily_rosters
│   ├── requests / notifications
│   └── operational RPCs
│
├── Supabase Realtime
│   ├── attendance updates
│   ├── employee notifications
│   └── EA form changes
│
├── Supabase Storage
│   └── employee-photos
│
├── Firebase
│   └── push notifications
│
└── Node / Express / Prisma backend
    ├── authentication
    ├── JWT
    ├── first-login OTP
    ├── password management
    └── account operations
```

Flutter still accesses important production data directly through `lib/screens/supabase_service.dart`. The Node/Prisma schema is not automatically the same schema as the Supabase tables used directly by Flutter.

## Main features

The application currently includes employee and branch management, attendance entry/review, monthly and daily rosters, OT requests and authorization, leave/request workflows, monthly payroll generation, payroll history, payslips, employee notifications, EA forms, daily reports, branch activity auditing, employee photos, RHB bank export and EPF/SOCSO/EIS statutory exports.

## Project structure

```text
lib/
├── main.dart
├── models/
├── screens/
│   ├── login_screen.dart
│   ├── admin_dashboard.dart
│   ├── branch_dashboard.dart
│   ├── employee_portal.dart
│   ├── attendance_dialog.dart
│   └── supabase_service.dart
├── services/
│   ├── app_service.dart
│   ├── attendance_payroll_service.dart
│   ├── payroll_supabase_service.dart
│   ├── notification_service.dart
│   └── pdf_service.dart
└── widgets/
    ├── employee_photo.dart
    └── shared_attendance_sheet.dart

backend/
├── prisma/schema.prisma
└── src/

supabase/
└── migrations/

.github/workflows/
└── android.yml

test/
assets/
android/
ios/
web/
windows/
linux/
macos/
```

## Core Supabase data

Important production tables include:

```text
employees
branches
attendance
payroll
employee_salary_defaults
monthly_rosters
daily_rosters
branch_activity_logs
app_notifications
notification_reads
```

Additional request, reporting and operational tables/RPCs are used by individual modules. The production database schema and committed migrations are authoritative for exact column definitions.

### Sensitive data

The system processes salary, IC/passport, bank-account, EPF, SOCSO, attendance and payroll information. Access must be enforced through appropriate RLS, secure RPCs and/or backend authorization. Hiding a button in Flutter is not authorization.

Never commit service-role keys, database passwords, JWT secrets, SMTP passwords, Firebase service-account credentials, production dumps or other server secrets.

## Employee photos

Employee photo metadata is stored with employee records and image objects are stored in the `employee-photos` Supabase Storage bucket.

The current migration configures this bucket for public read access while upload/update/delete operations remain restricted by policy. Because reads are public, the Flutter `EmployeePhoto` widget uses public object URLs rather than generating an individual signed URL for every displayed employee.

If employee-photo privacy requirements change, update the Storage policy and Flutter access strategy together. Do not simply make the widget use signed URLs without considering list-page request volume.

## Attendance

Important code:

```text
lib/screens/attendance_dialog.dart
lib/screens/supabase_service.dart
lib/services/attendance_payroll_service.dart
lib/models/attendance.dart
```

Common statuses include:

```text
Present
Late
Absent
OFF
MC
PL
AL
EL
PH
UNPAID
```

Do not rename stored statuses casually. Database constraints, reporting and payroll calculations may depend on the exact values.

Working-time calculations use minutes. Never treat `1:23` as `1.23` decimal hours. One hour and 23 minutes is 83 minutes.

### Realtime and request efficiency

Read-only employee attendance uses Supabase Realtime for changes with a five-minute fallback refresh. Do not restore aggressive polling. Attendance list queries should remain date/month scoped and asynchronous work should not be recreated from Flutter `build()` methods.

## Rosters

Monthly roster lookup uses branch, employee, year, month and week information. Payroll can use an assigned roster target before falling back to the employee salary-rule target.

Attendance, roster and payroll logic therefore need to remain synchronized.

## Payroll

Main calculation service:

```text
lib/services/attendance_payroll_service.dart
```

Primary monthly flow:

```text
Select payroll month / employees
        ↓
Load employee + salary defaults
        ↓
Load payroll-impact attendance
        ↓
Load applicable roster
        ↓
Calculate OT / PH / unpaid / shortage
        ↓
Calculate statutory contributions
        ↓
Insert or update payroll
```

The payroll period is normalized to the first day of the selected month.

### Overtime

OT must be authorized before becoming payroll OT. Calculations should remain minute-based.

Regression example:

```text
Net work: 8:53 = 533 minutes
Target:   7:30 = 450 minutes
OT:             = 83 minutes = 1:23
```

Always use the current payroll service as the source of truth for target selection, roster overrides and eligibility.

### Public holiday

The current business rule includes the worked-public-holiday calculation:

```text
Basic Salary / 26 × 2
```

Example:

```text
RM1,700 / 26 × 2 = RM130.77
```

### Unpaid and shortage deductions

UNPAID and short-working/late deductions depend on the current employee rule and attendance/roster data. These rules have evolved during development. Before changing them, inspect the current calculation service and verify with a manual regression example.

### EPF / SOCSO / EIS

The application contains business-specific statutory handling and embedded contribution schedules. Do not replace these with guessed percentages.

Current implementation includes special EPF-category behavior, SOCSO first-category handling and EIS applicability rules. Verify the effective statutory schedule and intended payroll period before changing tables or formulas.

## Payroll exports

Supported workflows include payroll Excel output, RHB bank layout, EPF, SOCSO and EIS exports.

Export files can contain confidential employee identity, bank and salary information. Verify employee identity, bank account, selected payroll month and payroll totals before distribution.

## Payslips

Payslip/PDF generation is primarily handled by:

```text
lib/services/pdf_service.dart
```

Whenever payroll fields or calculations change, review payslip mapping and exports in the same change.

## Notifications

The project uses Firebase notifications plus Supabase notification data. Employee notification changes use Realtime, with a five-minute fallback refresh rather than frequent polling.

Important files include:

```text
lib/services/notification_service.dart
lib/screens/employee_portal.dart
lib/firebase_options.dart
web/firebase-messaging-sw.js
```

## Supabase request optimization

The application has been optimized to reduce unnecessary Supabase log ingestion and API traffic.

Current rules:

- Employee-photo list rendering does not generate one signed-URL request per employee.
- Attendance queries used by dashboards are cached and month/date scoped where appropriate.
- Read-only attendance uses Realtime with a five-minute fallback instead of two-second polling.
- Employee notifications use Realtime with a five-minute fallback instead of 30-second polling.
- High-frequency `FutureBuilder` data is cached in state rather than recreated during every rebuild.
- Monthly roster and admin attendance page loads are cached and explicitly refreshed when needed.
- Realtime-triggered reloads are debounced to avoid duplicate bursts.

When adding new screens, avoid Supabase queries directly from `build()` and avoid short periodic polling unless there is a documented operational requirement.

## Authentication

Authentication/account operations are coordinated mainly by:

```text
lib/services/app_service.dart
lib/screens/login_screen.dart
backend/src/server.js
```

The backend supports role-based login, JWT, first-login handling, OTP verification, password creation/change, logout and session restore.

Do not put server credentials or privileged Supabase keys in Flutter.

## Local development

Install dependencies and verify the Flutter environment:

```bash
flutter doctor
flutter pub get
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run tests and analyzer:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build Android:

```bash
flutter build apk --release
flutter build appbundle --release
```

Build Web:

```bash
flutter build web --release
```

## CI/CD

Android CI is defined in `.github/workflows/android.yml`.

The current validation pipeline performs repository checkout and environment setup, installs dependencies, formats Dart source, verifies formatting is already committed, analyzes source, runs tests, builds the release APK, builds the release AAB, verifies Android artifacts and uploads the artifacts.

A pull request should not be merged when required CI is failing.

## Safe development workflow

For payroll, attendance, roster or statutory changes:

```text
Understand requirement
        ↓
Inspect current source + database schema
        ↓
Trace downstream payroll/export impact
        ↓
Make the smallest safe change
        ↓
Add/update regression tests
        ↓
dart format
        ↓
flutter analyze
        ↓
flutter test
        ↓
build/CI verification
        ↓
review before merge
```

Never modify production payroll data as part of automated testing.

## Database changes

Use migrations and avoid undocumented production schema drift. Before changing a table, determine whether the data belongs to the direct Supabase path, Node/Prisma path or both.

Check RLS/policies, RPCs, Flutter field names, payroll queries, reports, exports and historical compatibility before deploying schema changes.

## Production checklist

Before a payroll release, verify admin/branch/employee login, attendance entry/submission, roster assignment, net working minutes, OT request/authorization, PH, UNPAID, shortage deduction, EPF/SOCSO/EIS, payroll generation/overwrite, payslip, RHB/statutory exports, missing bank-account handling, analyzer/tests, Android builds, production secrets and database backup.

## Guidance for coding assistants

Before changing payroll behavior, inspect at least:

```text
lib/services/attendance_payroll_service.dart
lib/screens/supabase_service.dart
lib/screens/attendance_dialog.dart
lib/screens/admin_dashboard.dart
lib/screens/branch_dashboard.dart
lib/services/app_service.dart
backend/src/server.js
backend/prisma/schema.prisma
```

Rules for AI-assisted changes:

```text
Do not guess payroll formulas.
Do not weaken authorization to make a UI work.
Do not expose credentials.
Keep attendance, roster and payroll behavior synchronized.
Do not test against production payroll data destructively.
Use a separate branch for significant changes.
Add regression coverage for payroll calculation changes.
Verify CI before merging.
```

## Maintenance priorities

Continue strengthening payroll regression tests, end-to-end tests, RLS documentation, migration discipline, statutory schedule versioning and clear ownership between direct Supabase data and Node/Prisma data.

Performance work should be driven by live Supabase/API evidence rather than speculative optimization.

## License

This project is proprietary software. See `LICENSE` for the authoritative terms.

Do not copy, redistribute, publish, sell, sublicense or incorporate this code elsewhere without authorization from the copyright owner.
