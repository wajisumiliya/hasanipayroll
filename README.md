# Hasani Books Payroll Portal

A Flutter-based payroll, attendance, branch-management and employee self-service system for Hasani Books.

> Repository: `wajisumiliya/hasanipayroll`  
> Flutter package: `hasani_payroll_portal`  
> Version: `1.0.0+1`  
> Main app: Flutter  
> Data/API: Supabase + Node/Express/Prisma  
> Platforms: Android, iOS, Web, Windows, macOS, Linux

---

## 1. Purpose of this README

This document is intended to make the project easy to understand for:

- future developers,
- AI coding assistants,
- administrators,
- maintainers,
- testers,
- and anyone debugging payroll or attendance behavior.

Before changing payroll calculations, attendance rules, authentication, database fields, or exports, read the relevant sections below.

---

# 2. High-level architecture

The repository currently contains **two important backend/data paths**.

```text
Flutter Application
│
├── Direct Supabase access
│   ├── employees
│   ├── attendance
│   ├── payroll
│   ├── employee_salary_defaults
│   ├── monthly_rosters
│   ├── branches
│   └── other operational tables/RPCs
│
└── Node / Express API
    ├── authentication
    ├── JWT
    ├── first-login OTP
    ├── password management
    ├── branch/admin accounts
    ├── notifications
    └── Prisma / PostgreSQL models
```

This distinction is very important.

The Flutter application still contains substantial direct Supabase access through:

```text
lib/screens/supabase_service.dart
```

Authentication and some account operations use the Node API through:

```text
lib/services/app_service.dart
```

Do **not** assume that changing only the Prisma schema changes the Supabase schema used by the Flutter application.

---

# 3. Main user roles

The application supports three roles:

```text
ADMIN
BRANCH
EMPLOYEE
```

## ADMIN

Main responsibilities include:

- employee management,
- branch management,
- attendance review,
- OT authorization,
- payroll generation,
- payroll history,
- exports,
- payslip-related operations,
- reviewing branch activity,
- salary and statutory configuration.

## BRANCH

Main responsibilities include:

- viewing employees assigned to the branch,
- entering attendance,
- maintaining attendance statuses,
- requesting OT,
- viewing employee attendance,
- managing roster-related operations.

## EMPLOYEE

Main responsibilities include:

- employee self-service,
- payroll/payslip access,
- password management,
- notifications and personal payroll information.

---

# 4. Application startup

Main entry point:

```text
lib/main.dart
```

Startup flow:

```text
Flutter initializes
        ↓
Supabase initializes
        ↓
Firebase initializes
        ↓
Notification service initializes
        ↓
Saved application session is restored
        ↓
User role is checked
        ↓
ADMIN    → AdminDashboard
BRANCH   → BranchPortal
EMPLOYEE → EmployeePortal
No user  → LoginScreen
```

Important startup classes:

```text
lib/main.dart
lib/services/app_service.dart
lib/screens/supabase_service.dart
lib/services/notification_service.dart
```

---

# 5. Important project structure

```text
hasanipayroll/
│
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   │
│   ├── models/
│   │   ├── attendance.dart
│   │   └── payroll.dart
│   │
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── admin_dashboard.dart
│   │   ├── branch_dashboard.dart
│   │   ├── employee_portal.dart
│   │   ├── attendance_dialog.dart
│   │   └── supabase_service.dart
│   │
│   ├── services/
│   │   ├── app_service.dart
│   │   ├── attendance_payroll_service.dart
│   │   ├── payroll_supabase_service.dart
│   │   ├── pdf_service.dart
│   │   └── notification_service.dart
│   │
│   └── widgets/
│       └── shared_attendance_sheet.dart
│
├── backend/
│   ├── prisma/
│   │   └── schema.prisma
│   ├── src/
│   │   ├── server.js
│   │   └── scripts/
│   ├── package.json
│   └── prisma.config.ts
│
├── assets/
│   ├── hasani_books_logo.jpg
│   └── payroll_export_template.xlsx
│
├── .github/
│   └── workflows/
│       └── android.yml
│
├── test/
│   └── widget_test.dart
│
├── web/
├── android/
├── ios/
├── windows/
├── linux/
├── macos/
├── pubspec.yaml
├── pubspec.lock
├── LICENSE
└── README.md
```

---

# 6. Flutter technology stack

`pubspec.yaml` currently includes:

```text
Flutter
Dart >=3.5.0 <4.0.0

supabase_flutter 2.15.4
firebase_core
firebase_messaging
flutter_local_notifications

http
shared_preferences

pdf
printing

excel
csv
file_picker
file_saver
archive
intl
```

The application is configured for Android, iOS and Web, with Flutter desktop platform folders also present.

---

# 7. Node backend

Backend location:

```text
backend/
```

Main server:

```text
backend/src/server.js
```

Current backend stack includes:

```text
Node.js
Express 5
PostgreSQL
Prisma 7
pg
JWT
bcrypt
helmet
express-rate-limit
cors
nodemailer
multer
dotenv
```

Useful commands:

```bash
cd backend
npm install

npm run dev
npm start

npm run db:generate
npm run db:push
npm run db:studio
```

Additional branch-user helper:

```bash
npm run user:create-frn
```

---

# 8. Authentication

Application authentication logic is mainly coordinated by:

```text
lib/services/app_service.dart
lib/screens/login_screen.dart
backend/src/server.js
```

Default API base URL currently used by Flutter:

```text
https://hasaniworkhub.onrender.com/
```

It can be overridden at build/runtime with:

```text
API_BASE_URL
```

The application stores the current application user/session information locally using `shared_preferences`.

Authentication features include:

- username / employee ID login,
- role-based portal routing,
- JWT-based backend authentication,
- first-login detection,
- first-login OTP,
- OTP verification,
- new-password creation,
- change password,
- logout,
- session restore.

---

# 9. First-login OTP flow

Typical first-login sequence:

```text
User enters username + temporary/current password
        ↓
Backend identifies first-login account
        ↓
Flutter receives FIRST_LOGIN_OTP_REQUIRED
        ↓
User requests OTP
        ↓
OTP sent to registered email
        ↓
User enters 6-digit OTP
        ↓
OTP verified
        ↓
User creates new password
        ↓
Normal portal access
```

Backend environment configuration is required for email delivery.

Typical variables include:

```text
SMTP_USER
SMTP_PASSWORD
SMTP_HOST
SMTP_FROM
```

The backend also supports several compatible Gmail/email variable aliases.

Never commit real SMTP passwords.

---

# 10. Supabase

Main Flutter Supabase service:

```text
lib/screens/supabase_service.dart
```

The app currently contains a Supabase project URL and a **publishable/anonymous client key** in this file.

A publishable/anon key is intended for client-side usage, but its safety depends on correct database authorization.

## Critical rule

Never place a Supabase:

```text
service_role key
secret server key
database password
```

inside Flutter code.

Authorization must be enforced by database RLS/policies or secure backend APIs.

---

# 11. Core Supabase tables used by Flutter

The exact production schema should be treated as authoritative, but the Flutter code uses data structures including:

```text
employees
branches
attendance
payroll
employee_salary_defaults
monthly_rosters
branch_activity_logs
```

There may be additional operational tables/RPC functions.

A notable admin RPC currently referenced is:

```text
admin_branch_activity_logs
```

---

# 12. Employees

Employee information used by the Flutter/Supabase application includes fields such as:

```text
employee_id
name
designation
department
email
new_ic_no
bank_code
bank_account
epf_no
socso_no
address
joining_date
is_active
branch_id
```

Employee identity and bank data are also used by payroll and export functionality.

Treat IC, passport, bank, EPF, SOCSO and salary information as sensitive.

---

# 13. Salary defaults

Monthly payroll starts from:

```text
employee_salary_defaults
```

Important fields include:

```text
employee_id
basic_salary
fw_salary
elaun_kedatangan
elaun_perkhidmatan
elaun_kerajinan
epf_category
eis_applicable
```

Payroll generation can be skipped when an employee has no salary-default record.

Before generating payroll, make sure the employee's salary/statutory configuration is valid.

---

# 14. Attendance

Important attendance-related code:

```text
lib/screens/attendance_dialog.dart
lib/screens/supabase_service.dart
lib/services/attendance_payroll_service.dart
lib/models/attendance.dart
```

Typical attendance data includes:

```text
employee_id
branch_id
attendance_date
status

check_in
check_out

morning_break_in
morning_break_out
afternoon_break_in
afternoon_break_out
evening_break_in
evening_break_out

work_minutes
break_minutes
net_working_minutes

work_duration
break_duration
net_working_duration

ot_requested
ot_authorized
overtime_minutes
overtime_duration

is_submitted
```

Exact names should always be confirmed against the current database before migrations.

---

# 15. Attendance statuses

The system uses leave/work statuses including:

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

Payroll impact is not identical for all statuses.

Important concepts:

```text
OFF     → normally no working-time shortage deduction
UNPAID  → unpaid deduction
PH      → special public-holiday treatment
MC/PL/
AL/EL   → follow current payroll/attendance service logic
```

Do not change status names casually because database constraints and payroll logic may depend on exact stored values.

---

# 16. Net working time

Attendance calculations use net working minutes.

Conceptually:

```text
TOTAL WORKING TIME
      - TOTAL BREAK TIME
      = NET WORKING TIME
```

Break time can include:

```text
morning break
afternoon break
evening break
```

The code stores and uses time in minutes for calculations.

Avoid converting values such as:

```text
1 hour 23 minutes
```

to:

```text
1.23 hours
```

because `1.23` decimal hours is not 1 hour 23 minutes.

---

# 17. Monthly rosters

The current code supports:

```text
monthly_rosters
```

Roster lookup is based on:

```text
branch_id
employee_id
roster_year
roster_month
week_number
```

The application can load roster rows using:

```text
SupabaseService.getMonthlyRosters(...)
```

and upsert roster rows with a conflict key equivalent to:

```text
branch_id,
employee_id,
roster_year,
roster_month,
week_number
```

## Important

Payroll calculation now checks the employee's assigned roster when determining working targets.

If no roster exists, payroll falls back to the employee salary-rule target.

Therefore, attendance, roster and payroll logic must remain synchronized.

---

# 18. Payroll generation

Main calculation service:

```text
lib/services/attendance_payroll_service.dart
```

Primary entry point:

```text
AttendancePayrollService.generateMonthlyPayroll(...)
```

Typical flow:

```text
Admin selects month
        ↓
Admin selects employees
        ↓
Employee record is loaded
        ↓
Salary defaults are loaded
        ↓
Submitted/payroll-impact attendance is loaded
        ↓
Monthly roster is loaded if available
        ↓
OT / shortage / unpaid / PH values are calculated
        ↓
EPF / SOCSO / EIS are calculated
        ↓
Payroll row is inserted or updated
```

The payroll period is normalized to:

```text
first day of selected month
```

Example:

```text
September 2026
→ 2026-09-01
```

---

# 19. Current working-time targets

The current payroll service documents the following fallback salary-rule targets:

## `epf_category = normal1`

```text
Required net working time = 7 hours 30 minutes
                           = 450 minutes
```

## `eis_applicable = false`

```text
Required net working time = 10 hours 30 minutes
                           = 630 minutes
```

Under that rule, overtime is not paid.

## Other applicable employees

```text
Required net working time = 7 hours 30 minutes
                           = 450 minutes
```

## Roster priority

If an assigned roster exists, the roster's daily target can override the fallback target.

Always inspect current code before changing these rules.

---

# 20. Overtime

OT workflow:

```text
Branch enters attendance
        ↓
Branch requests OT
        ↓
Admin reviews
        ↓
Admin authorizes OT
        ↓
Only authorized OT becomes payroll OT
```

The payroll service accepts authorized values stored as forms equivalent to:

```text
true
"true"
"1"
"yes"
```

Approved OT is calculated above the applicable daily net target.

## Important

OT should remain represented internally in minutes where possible.

Regression example:

```text
Net work = 8:53
Target   = 7:30

8:53 = 533 minutes
7:30 = 450 minutes

OT = 533 - 450
   = 83 minutes
   = 1 hour 23 minutes
```

This is not:

```text
1.23 decimal hours
```

---

# 21. Public holiday / Cuti Umum

The current payroll service documents:

```text
cuti_umum
= Basic Salary / 26 × 2
```

for each worked public holiday.

Example:

```text
Basic Salary = RM1,700

RM1,700 / 26 × 2
= RM130.77
```

Two qualifying public holidays:

```text
RM130.77 × 2
= RM261.54
```

Public-holiday attendance is treated separately from normal shortage calculations.

---

# 22. Statutory wage

The current payroll service defines statutory wage as:

```text
basic_salary
    - cuti_umum
    = statutory_wage
```

That statutory wage is then passed into:

```text
EPF
SOCSO
EIS
```

logic.

This ordering is unusual enough that future developers should **not change it without confirming the intended payroll rule**.

---

# 23. EPF

The current payroll service has two modes.

## `epf_category = normal`

The code currently documents:

```text
Employee EPF = statutory wage × 2%
Employer EPF = statutory wage × 2%
```

## Other categories

Other EPF categories use an embedded EPF contribution schedule.

The service comments state that the supplied statutory schedules were embedded rather than guessed from arbitrary percentages.

Before replacing or updating the schedule, verify the official statutory table intended for the payroll period.

---

# 24. SOCSO

The payroll service currently uses:

```text
SOCSO FIRST CATEGORY
```

with an embedded contribution schedule.

The resulting values are stored as:

```text
payroll.socso_employee
payroll.socso_employer
```

Do not change to another contribution category unless the business rule is intentionally changed.

---

# 25. EIS

The key employee setting is:

```text
employee_salary_defaults.eis_applicable
```

If:

```text
eis_applicable = false
```

then:

```text
EIS employee = 0
EIS employer = 0
```

Otherwise, the embedded EIS schedule is used.

---

# 26. Unpaid leave

UNPAID days are calculated from attendance.

The current implementation should always be treated as the source of truth for the exact divisor because this rule has changed during development.

When modifying unpaid calculations:

1. inspect `attendance_payroll_service.dart`,
2. verify the intended salary divisor,
3. add a regression test,
4. compare against a manually calculated employee example.

---

# 27. Late / short-working deduction

Payroll calculates shortage using the applicable daily working target.

The current implementation now also considers roster targets where available.

Public holiday and unpaid handling are separated from ordinary working-time shortage calculations.

When modifying shortage rules, inspect all of:

```text
lib/services/attendance_payroll_service.dart
lib/screens/supabase_service.dart
lib/screens/attendance_dialog.dart
monthly_rosters logic
```

Do not update only the UI.

---

# 28. Payroll overwrite behavior

Payroll generation supports:

```text
overwriteExisting = true
```

When enabled, existing payroll values for the employee/month can be overwritten.

This is useful for recalculation, but it means payroll generation is a sensitive operation.

Recommended practice:

```text
1. verify attendance,
2. verify salary defaults,
3. verify roster,
4. test one employee,
5. verify output,
6. then run full branch/month payroll.
```

---

# 29. Payroll fields

The app works with payroll values including:

## Earnings

```text
basic salary
fw salary
attendance allowance
service allowance
diligence allowance
overtime
cuti umum
other configured earnings
```

## Employee deductions

```text
EPF
SOCSO
EIS
PCB
zakat
advance
loan
unpaid
late/short-working
other deductions
```

## Employer contributions

```text
EPF employer
SOCSO employer
EIS employer
```

## Identity / bank information

```text
new IC number
bank code
bank account
bank name
```

---

# 30. Payroll exports

Admin export functionality exists in:

```text
lib/screens/admin_dashboard.dart
```

The project also contains:

```text
assets/payroll_export_template.xlsx
```

Exports include payroll and statutory/bank layouts.

Common export types include:

```text
RHB Layout
EPF
EIS
SOCSO
Payroll Excel
```

Because these files can contain salary, IC and banking information, they must be handled as confidential payroll data.

---

# 31. RHB layout

Typical fields:

```text
NAME
NEW_IC_NO
BANK_ACCOUNT
NETAMOUNT
SELECTED PAYROLL MONTH
```

Before sending a bank file:

- verify employee name,
- verify IC,
- verify bank account,
- verify net amount,
- verify selected month,
- check for employees without bank-account details.

---

# 32. Statutory exports

## EPF

Typical fields:

```text
NAME
NEW_IC_NO
EPF_NO
EMPLOYEE EPF AMOUNT
EMPLOYER EPF AMOUNT
NETAMOUNT
```

## EIS

Typical fields:

```text
NAME
NEW_IC_NO
EMPLOYEE EIS AMOUNT
EMPLOYER EIS AMOUNT
```

## SOCSO

Typical fields:

```text
NAME
NEW_IC_NO
EMPLOYEE SOCSO AMOUNT
EMPLOYER SOCSO AMOUNT
```

Always verify the exported values against the payroll row for the selected month.

---

# 33. Payslips

Payslip generation is handled primarily by:

```text
lib/services/pdf_service.dart
```

The app uses:

```text
pdf
printing
```

Payslips may include:

```text
basic salary
allowances
OT
public holiday
EPF
SOCSO
EIS
unpaid
other deductions
net pay
employer contributions
```

Whenever payroll fields change, review the PDF mapping as well.

---

# 34. Firebase notifications

Firebase-related files include:

```text
lib/firebase_options.dart
lib/services/notification_service.dart
web/firebase-messaging-sw.js
android/app/google-services.json
```

The backend Prisma schema contains notification-related models including:

```text
DeviceToken
Notification
NotificationRecipient
Announcement
```

Notification types currently include:

```text
SALARY_CREDITED
SALARY_INCREMENT
ANNOUNCEMENT
COMMON_UPDATE
PAYROLL
SYSTEM
```

---

# 35. Prisma models

The backend Prisma schema currently defines models including:

```text
app_user
Employee
PayrollRecord
SalaryIncrement
DeviceToken
Notification
NotificationRecipient
Announcement
```

User roles:

```text
ADMIN
EMPLOYEE
BRANCH
```

## Important architecture warning

Prisma's `Employee` and `PayrollRecord` models are **not automatically the same schema** as the Supabase tables directly used by Flutter.

Before any schema migration, determine which production path owns the data.

---

# 36. Security-sensitive information

This system processes highly sensitive employee information.

Protect:

```text
passwords
JWT secrets
OTP information
employee IC/passport
bank accounts
salary
EPF numbers
SOCSO numbers
payroll deductions
payroll exports
database credentials
SMTP credentials
Firebase server credentials
```

Never commit:

```text
.env
backend/.env
database passwords
JWT_SECRET
ADMIN_PASSWORD
FRN_BRANCH_PASSWORD
SMTP_PASSWORD
Supabase service_role keys
Firebase service-account JSON
private API keys
production database dumps
```

---

# 37. Security design rules

## Frontend hiding is not authorization

Do not rely only on:

```text
if user.isAdmin
```

or hidden buttons to protect payroll data.

Authorization should be enforced at:

```text
database RLS
secure RPC
backend API
role validation
```

## Expected access model

```text
ADMIN
→ authorized payroll and company-wide administration

BRANCH
→ only authorized branch data

EMPLOYEE
→ only own employee/payroll information
```

---

# 38. Local Flutter setup

Check Flutter:

```bash
flutter doctor
```

Install dependencies:

```bash
flutter pub get
```

Run Chrome:

```bash
flutter run -d chrome
```

Run another connected target:

```bash
flutter devices
flutter run
```

---

# 39. Build Web

```bash
flutter build web --release
```

Output:

```text
build/web/
```

---

# 40. Build Android

APK:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

App Bundle:

```bash
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# 41. GitHub Actions

Current Android workflow:

```text
.github/workflows/android.yml
```

The workflow:

```text
checkout
   ↓
install Flutter 3.47.0 stable
   ↓
flutter create --platforms=android .
   ↓
flutter pub get
   ↓
flutter build apk --release
   ↓
flutter build appbundle --release
   ↓
upload APK + AAB artifacts
```

Triggers:

```text
push to main
manual workflow_dispatch
```

---

# 42. Automated testing

Current Flutter test location:

```text
test/widget_test.dart
```

The repository should maintain automated regression tests for payroll rules.

Priority tests:

```text
login smoke test
role routing
attendance minute calculation
roster target calculation
OT authorization
OT minute conversion
public holiday
unpaid
late/shortage
EPF
SOCSO
EIS
net salary
payroll overwrite
RHB export
EPF export
EIS export
SOCSO export
mobile layout
```

A Playwright browser test suite is also recommended for the Flutter web application.

---

# 43. Critical regression examples

## OT minutes

```text
8:53 net
- 7:30 target
= 1:23 OT
= 83 minutes
```

Expected representation:

```text
83 minutes
```

not:

```text
1.23 decimal hours
```

## Public holiday

```text
Basic = RM1,700

1,700 / 26 × 2
= RM130.77
```

## EIS disabled

```text
eis_applicable = false

employee EIS = RM0
employer EIS = RM0
```

## EPF normal category

```text
epf_category = normal

employee EPF = 2% of statutory wage
employer EPF = 2% of statutory wage
```

---

# 44. Safe workflow for payroll-rule changes

When changing payroll logic:

```text
1. Read current business requirement
        ↓
2. Inspect attendance_payroll_service.dart
        ↓
3. Inspect Supabase attendance logic
        ↓
4. Inspect roster logic
        ↓
5. Inspect admin/branch UI
        ↓
6. Update calculation
        ↓
7. Add regression test
        ↓
8. Test one employee manually
        ↓
9. Compare expected vs actual
        ↓
10. Test export/payslip
        ↓
11. Run flutter analyze
        ↓
12. Run flutter test
        ↓
13. Commit
```

Never change a payroll formula solely because a UI value looks wrong without tracing the source data.

---

# 45. Safe workflow for attendance changes

When modifying attendance:

```text
Attendance UI
    ↓
Supabase save/update logic
    ↓
Stored minute fields
    ↓
Submitted/authorized flags
    ↓
Roster rules
    ↓
Payroll service
    ↓
Payroll output
```

A change to one layer can affect all downstream payroll calculations.

---

# 46. Database change checklist

Before altering the database:

- identify whether the table belongs to Supabase direct access or the Node/Prisma path,
- back up production data,
- check Flutter field names,
- check backend Prisma field names,
- check RLS,
- check RPC functions,
- check payroll service queries,
- check exports,
- check payslips,
- test old attendance/payroll rows,
- add migrations rather than manually drifting schemas.

---

# 47. Common troubleshooting

## Flutter cannot connect to Supabase

Check:

```text
internet connectivity
Supabase project availability
project URL
client publishable key
RLS policies
table names
RPC permissions
```

## Login fails

Check:

```text
API_BASE_URL
Render backend availability
DATABASE_URL
JWT secret
account active state
role
password hash
first-login state
CORS
```

## OTP does not arrive

Check:

```text
SMTP configuration
registered user email
SMTP app password
email-provider restrictions
backend logs
OTP resend cooldown
```

## Payroll is wrong

Check in this order:

```text
employee salary defaults
attendance status
is_submitted
net working minutes
roster
OT requested
OT authorized
PH flag/status
unpaid flag/status
EPF category
EIS applicable
statutory schedule
existing payroll overwrite
```

## OT is too high

Check:

```text
minutes vs decimal hours
assigned roster target
fallback target
OT authorization
duplicate attendance rows
break calculation
```

## Branch sees wrong employees

Check:

```text
employee.branch_id
branch alias normalization
logged-in branch ID
RLS/data filtering
```

---

# 48. Branch normalization

`SupabaseService` contains branch-login alias normalization.

Examples include aliases for locations such as:

```text
Sungai Petani
Amanjaya
Alor Setar
Astana
Gurun
Jitra
Prai
Kulim
Langkawi
```

There are also `FRN` login aliases.

If changing branch codes or usernames, review the normalization map first.

---

# 49. Branch activity logging

The app records branch activity through:

```text
branch_activity_logs
```

and can use an admin RPC:

```text
admin_branch_activity_logs
```

Activity records can include:

```text
branch
action
employee
opened time
closed time
details
```

Keep authorization on activity-log viewing restricted to appropriate administrators.

---

# 50. Production checklist

Before a payroll release:

- [ ] Supabase production connection verified
- [ ] Node API production connection verified
- [ ] Admin login tested
- [ ] Branch login tested
- [ ] Employee login tested
- [ ] First-login OTP tested
- [ ] Password change tested
- [ ] Correct branch employees visible
- [ ] Attendance saving tested
- [ ] Attendance submission tested
- [ ] Monthly roster verified
- [ ] Net working minutes verified
- [ ] OT request tested
- [ ] OT authorization tested
- [ ] PH tested
- [ ] UNPAID tested
- [ ] Late/shortage tested
- [ ] EPF tested
- [ ] SOCSO tested
- [ ] EIS tested
- [ ] Payroll generation tested
- [ ] Existing payroll overwrite tested
- [ ] Net salary verified manually
- [ ] Payslip checked
- [ ] RHB export checked
- [ ] EPF export checked
- [ ] EIS export checked
- [ ] SOCSO export checked
- [ ] Missing bank accounts checked
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Android release APK builds
- [ ] Android AAB builds
- [ ] No production secrets committed
- [ ] Database backup exists

---

# 51. Guidance for future AI assistants

When using ChatGPT, Codex, Claude or another coding assistant on this repository, provide this README first.

Tell the assistant:

```text
This is a payroll system.
Do not guess payroll formulas.
Inspect current implementation before changing rules.
Keep attendance, roster and payroll logic synchronized.
Do not expose credentials.
Do not modify production payroll data during testing.
Use a separate branch for significant changes.
Add regression tests for every payroll calculation change.
```

Files that should usually be inspected before payroll work:

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

---

# 52. Current architectural risks / maintenance notes

## Two data representations

Flutter/Supabase and Node/Prisma are both present.

This can create schema drift.

Long-term recommendation:

```text
document one source of truth for every table/domain
```

## Payroll schedules are embedded

EPF, SOCSO and EIS schedules can become outdated when statutory rules change.

Every statutory update should include:

```text
source date
effective payroll month
regression tests
sample manual calculations
```

## Business rules have evolved

Attendance, roster, OT, unpaid and shortage rules have changed during development.

Therefore:

```text
current source code > old chat history > old README
```

Always inspect the latest service before modifying calculations.

---

# 53. Recommended next improvements

Priority engineering improvements:

```text
1. Playwright end-to-end web tests
2. Payroll unit/regression tests
3. CI running analyze + tests
4. Test/staging Supabase project
5. Test payroll employees isolated from production
6. Centralized database migrations
7. Explicit RLS policy documentation
8. Central business-rule constants
9. Versioned statutory contribution tables
10. Clear source-of-truth decision between Supabase and Prisma
```

---

# 54. License

This project is proprietary software.

See:

```text
LICENSE
```

for authoritative license terms.

Do not copy, redistribute, publish, sell, sublicense or incorporate this code elsewhere without authorization from the copyright owner.

---

# Hasani Books Payroll Portal

```text
Employees
   +
Branches
   +
Attendance
   +
Rosters
   +
Overtime
   +
Payroll
   +
EPF / SOCSO / EIS
   +
Payslips
   +
Bank / Statutory Exports
   +
Notifications
```

When in doubt, protect payroll data, verify the business rule manually, and test before generating a full payroll month.
