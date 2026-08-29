# Hasani Books Payroll Portal

Flutter-based payroll, attendance, employee, branch and employee self-service portal for Hasani Books.

> **Repository:** `wajisumiliya/hasanipayroll`  
> **Application:** Hasani Books Payroll Portal  
> **Version declared in `pubspec.yaml`:** `1.0.0+1`

---

## 1. What this project contains

The repository contains a Flutter application with three user portals:

- **Admin**
- **Branch**
- **Employee**

The current codebase integrates:

- Supabase / PostgreSQL data access
- Firebase initialization and Firebase Cloud Messaging
- Employee management
- Branch management
- Attendance management
- Monthly payroll generation
- Salary defaults and salary rules
- Overtime request/authorization workflow
- EPF, SOCSO and EIS calculations
- Public-holiday payroll
- Unpaid and late/short-working deductions
- Payslip PDF generation and printing
- Payroll Excel export
- RHB/statutory Excel exports
- Employee notifications
- First-login OTP/password flow

---

## 2. Technology stack

### Flutter

The application is written in Dart/Flutter.

`pubspec.yaml` currently declares:

- Dart SDK: `>=3.5.0 <4.0.0`
- Flutter Material UI
- `intl`
- `supabase_flutter`
- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`
- `pdf`
- `printing`
- `excel`
- `archive`
- `file_saver`
- `csv`
- `file_picker`
- `http`
- `shared_preferences`

### Backend

The repository also contains a separate Node.js backend under `backend/`.

Current backend stack:

- Node.js
- Express 5
- Prisma 7
- PostgreSQL
- `pg`
- JWT
- bcrypt/bcryptjs
- Nodemailer
- Multer
- CORS

Backend scripts currently include:

```bash
npm run dev
npm start
npm run db:generate
npm run db:push
npm run db:studio
```

The Flutter application, however, contains substantial direct Supabase access through `lib/screens/supabase_service.dart`. Treat the Flutter/Supabase path and the Node/Prisma backend as two components of the repository rather than assuming every feature uses the Node API.

---

# 3. Project structure

```text
hasanipayroll/
│
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
│
├── assets/
│   ├── hasani_books_logo.jpg
│   └── payroll_export_template.xlsx
│
├── backend/
│   ├── prisma/
│   │   └── schema.prisma
│   ├── src/
│   │   ├── server.js
│   │   └── scripts/
│   ├── data/
│   ├── package.json
│   └── prisma.config.ts
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
├── .github/
│   └── workflows/
│       └── android.yml
│
├── test/
│   └── widget_test.dart
│
├── pubspec.yaml
├── pubspec.lock
├── hasani_payroll.dump
├── LICENSE
└── README.md
```

---

# 4. Application startup

`lib/main.dart` initializes:

```text
Flutter
  ↓
Supabase
  ↓
Firebase
  ↓
Notification service
  ↓
Restore application session
  ↓
Select portal based on logged-in role
```

The application routes users to:

```text
ADMIN    → AdminDashboard
BRANCH   → BranchPortal
EMPLOYEE → EmployeePortal
```

If there is no valid restored session, the login screen is shown.

---

# 5. Authentication

The login screen implements:

- Employee ID / username login
- Session restoration
- Role-based portal routing
- First-login detection
- OTP verification
- Password creation after first-login verification
- Password update
- Logout

The code recognizes the application roles:

```text
ADMIN
BRANCH
EMPLOYEE
```

The repository also contains a Node/Prisma `app_user` model with:

- username
- email
- password hash
- role
- active state
- first-login password-change state
- OTP hash
- OTP expiry
- OTP attempts
- login timestamps

---

# 6. Admin portal

`lib/screens/admin_dashboard.dart` provides the main administrative workspace.

Current areas include:

- Dashboard
- Employee management
- Branch management
- Department filtering
- Payroll
- Attendance review
- Employee details
- Payroll history
- Payroll generation
- Payroll Excel export
- RHB Layout export

The dashboard obtains employee, branch, payroll and attendance information through `SupabaseService`.

---

# 7. Branch portal

`lib/screens/branch_dashboard.dart` provides branch-level employee and attendance functionality.

Current branch functionality includes:

- Viewing employees belonging to the branch
- Branch employee filtering
- Opening attendance sheets
- Viewing employee attendance
- Refreshing branch data

Branch access should be restricted by the application's authorization/database policies.

---

# 8. Employee portal

`lib/screens/employee_portal.dart` provides employee self-service functionality.

The portal includes access to employee/payroll information and payslips, together with password management and notification-related functionality.

Employees should only be allowed to access records belonging to their own employee account.

---

# 9. Attendance

Attendance is handled primarily by:

```text
lib/screens/attendance_dialog.dart
lib/screens/supabase_service.dart
lib/models/attendance.dart
```

Attendance records contain working and break information such as:

```text
Employee ID
Branch ID
Attendance Date
Status
Check In
Check Out

Morning Break In / Out
Afternoon Break In / Out
Evening Break In / Out

Work Minutes
Break Minutes
Net Working Minutes

Overtime Minutes
Overtime Duration
OT Requested
OT Authorized
```

The database status handling in the current Flutter service allows:

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

---

# 10. Net working time

The current attendance service calculates:

```text
NET WORKING TIME
= TOTAL WORKING TIME - TOTAL BREAK TIME
```

Break time is the sum of:

```text
Morning break
+ Afternoon break
+ Evening break
```

The attendance service explicitly treats the evening fields as break information rather than automatically treating them as overtime.

The calculated values are stored as minutes and display durations, including:

```text
work_minutes
break_minutes
net_working_minutes
work_duration
break_duration
net_working_duration
```

---

# 11. Working-hour rules

The current payroll service contains these main working targets:

### `epf_category = normal1`

Target:

```text
7:30 NET
```

### `eis_applicable = false`

Target:

```text
10:30 NET
```

and overtime is not paid under this rule.

### Other applicable employees

Target:

```text
7:30 NET
```

The exact salary rule is loaded from the employee salary defaults configuration.

---

# 12. Overtime workflow

The current system separates:

```text
OT Requested
OT Authorized
```

The intended workflow is:

```text
Branch records attendance
        ↓
Branch requests OT
        ↓
Admin reviews / authorizes OT
        ↓
Approved OT becomes payable payroll OT
```

The attendance service stores OT-related minutes and authorization state.

### Current calculation basis

For the 7:30 target:

```text
7:30 = 450 minutes
```

Extra net working time is:

```text
NET WORKING MINUTES - 450
```

Approved OT is then carried into monthly payroll.

The current attendance-save implementation also contains a break-fulfilment and extra-minute eligibility check before saving calculated OT. Therefore, if changing OT eligibility rules in future, update the calculation in `supabase_service.dart` and the payroll service together so the attendance and payroll layers remain synchronized.

---

# 13. Payroll generation

The main payroll calculation service is:

```text
lib/services/attendance_payroll_service.dart
```

The service generates monthly payroll from employee salary defaults plus submitted attendance.

Payroll generation includes:

- Basic salary
- FW salary
- Allowances
- Overtime
- Cuti Umum
- Late/short-working deduction
- Unpaid deduction
- EPF employee/employer
- SOCSO employee/employer
- EIS employee/employer
- Other payroll fields
- Net payroll amount

Existing payroll can be updated when the generation flow is configured to overwrite existing records.

---

# 14. Unpaid leave

The current business rule is:

```text
If employee_salary_defaults.eis_applicable = false:
    Unpaid per day = Basic Salary / 28

Otherwise:
    Unpaid per day = Basic Salary / 26
```

Therefore:

```text
UNPAID DEDUCTION
= DAILY UNPAID RATE × UNPAID DAYS
```

An attendance row marked as unpaid is handled as an unpaid day in payroll.

---

# 15. Late / short-working deduction

The payroll service calculates shortage against the employee's required net working target.

The calculation is based on the employee's basic salary and required working hours.

The current monthly rule is:

```text
If total late/short-working deduction < RM5:
    Deduction = RM0

If total late/short-working deduction >= RM5:
    Deduct the calculated amount
```

Unpaid and public-holiday rows are excluded from the normal late/short-working calculation.

---

# 16. Public holiday / Cuti Umum

The current payroll implementation uses:

```text
Cuti Umum
= Basic Salary / 26 × 2 × number of worked public holidays
```

Example:

```text
Basic Salary = RM1,700
1 public holiday worked

1,700 / 26 × 2
= RM130.77
```

For two worked public holidays:

```text
1,700 / 26 × 2 × 2
= RM261.54
```

Public-holiday attendance is excluded from normal shortage deduction.

---

# 17. OFF and leave statuses

The attendance UI/database supports statuses including:

```text
OFF
MC
PL
AL
EL
PH
UNPAID
```

Payroll treatment is controlled by the attendance flags and payroll service rules.

In particular:

- **OFF** should not create a normal working-time deduction.
- **Public holiday** is handled separately when the employee worked.
- **UNPAID** creates an unpaid-day deduction.
- Other leave/medical statuses should follow the attendance/payroll rules implemented in the current service.

---

# 18. EPF, SOCSO and EIS

The payroll service calculates employee and employer statutory contributions.

The current service documents:

### EPF

EPF calculation uses the configured EPF schedule.

### SOCSO

SOCSO uses the **first category** schedule in the current payroll implementation.

### EIS

If:

```text
employee_salary_defaults.eis_applicable = false
```

the payroll service sets EIS employee/employer contributions to zero.

Otherwise the configured EIS schedule is used.

The payroll service contains the statutory schedules used by the application; update those schedules carefully when statutory rates/tables change.

---

# 19. Payroll data

The Flutter payroll model contains fields including:

### Earnings

```text
basicSalary
fwSalary
elaunKedatangan
elaunPerkhidmatan
elaunKerajinan
overtime
bonus
commission
otherEarnings
housingAllowance
travelAllowance
cutiUmum
```

### Employee deductions

```text
epfEmployee
socsoEmployee
eisEmployee
pcb
zakat
advanceDeduction
loanDeduction
unpaidLeave
otherDeductionAmount
```

### Employer contributions

```text
epfEmployer
socsoEmployer
eisEmployer
```

### Banking / employee information

```text
newIcNo
bankCode
bankAccount
bankName
```

The model exposes calculated totals such as:

```text
totalEarnings
totalDeductions
netPay
totalEmployerContribution
totalEmployerCost
```

---

# 20. Excel exports

The Admin dashboard currently contains payroll Excel export functionality using the `excel` package.

There is also an RHB/statutory export action.

## RHB Layout

One click generates the RHB and statutory files for the selected payroll month.

### RHB file

```text
RHB_Layout_YYYY_MM.xlsx
```

Headers:

```text
NAME
NEW_IC_NO
BANK_ACCOUNT
NETAMOUNT
SELECTED PAYROLL MONTH
```

### EPF file

```text
EPF_YYYY_MM.xlsx
```

Headers:

```text
NAME
NEW_IC_NO
EPF_NO
EMPLOYEE EPF AMOUNT
EMPLOYER EPF AMOUNT
NETAMOUNT
```

### EIS file

```text
EIS_YYYY_MM.xlsx
```

Headers:

```text
NAME
NEW_IC_NO
EMPLOYEE EIS AMOUNT
EMPLOYER EIS AMOUNT
```

### SOCSO file

```text
SOSCO_YYYY_MM.xlsx
```

Headers:

```text
NAME
NEW_IC_NO
EMPLOYEE SOCSO AMOUNT
EMPLOYER SOCSO AMOUNT
```

The export obtains employee identity/bank information from the `employees` table and payroll contribution/net information from `payroll`.

---

# 21. Existing payroll template export

The repository also contains:

```text
assets/payroll_export_template.xlsx
```

The Admin dashboard has an export routine that loads and normalizes this template before creating a branch payroll Excel export.

This is separate from the four RHB/statutory files described above.

---

# 22. Payslips

Payslip generation is implemented in:

```text
lib/services/pdf_service.dart
```

The PDF service uses the `pdf` package and the `printing` package.

Payslip information includes payroll earnings and deductions such as:

```text
Basic salary
Allowances
Overtime
Cuti Umum
EPF
SOCSO
EIS
Unpaid leave
Other deductions
Net pay
Employer contributions
```

The employee portal can display/print payroll-related information through the application's payslip functionality.

---

# 23. Notifications

`lib/services/notification_service.dart` initializes Firebase Cloud Messaging and local notifications.

The application includes notification handling for foreground/background notification scenarios.

The backend Prisma schema also contains notification-related entities:

```text
Notification
NotificationRecipient
DeviceToken
Announcement
```

Supported notification types include:

```text
SALARY_CREDITED
SALARY_INCREMENT
ANNOUNCEMENT
COMMON_UPDATE
PAYROLL
SYSTEM
```

---

# 24. Employee and database information

The repository's Flutter Supabase service works with employee information including:

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
address
joining_date
is_active
branch_id
socso_no
```

The supplied database schema for `employees` uses `employee_id` as the primary key and links `branch_id` to the `branches` table.

For EPF export, the employee EPF number is taken from the employee record.

---

# 25. Supabase

The primary Flutter data-access class is:

```text
lib/screens/supabase_service.dart
```

It provides operations for:

- Authentication
- Employee records
- Branch records
- Payroll
- Attendance
- OT authorization
- Monthly attendance rows
- Employee/branch filtering
- Payroll-related data access

The project contains direct Supabase client initialization in the Flutter application.

### Security requirement

Do not expose Supabase service-role/secret credentials in the Flutter client.

Use only credentials intended for client-side use and enforce authorization with database policies.

---

# 26. Node / Prisma backend

The repository additionally contains:

```text
backend/
```

The Prisma schema currently defines entities including:

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

The backend `PayrollRecord` model contains payroll information including:

```text
basicSalary
overtime
EPF
SOCSO
EIS
grossSalary
netSalary
totalDeductions
unpaidLeave
bank information
payment status
```

The Node backend is therefore a separate persistence/API component and its Prisma schema should be kept synchronized with any production PostgreSQL schema actually used by the Flutter application.

---

# 27. Important repository architecture note

There are currently **two database/backend representations** in the repository:

1. Flutter's direct Supabase/PostgreSQL access.
2. A Node.js/Prisma/PostgreSQL backend under `backend/`.

Before changing database structures, confirm which database path is being used by the production deployment.

Do not assume that changing only `backend/prisma/schema.prisma` automatically changes the Supabase schema used by the Flutter application.

---

# 28. Installation

## Requirements

Install:

- Flutter
- Dart SDK compatible with `pubspec.yaml`
- Android SDK for Android builds
- Node.js/npm if the backend is used
- A configured Supabase project
- Firebase configuration for notification-enabled builds

Check Flutter:

```bash
flutter doctor
```

---

# 29. Install Flutter dependencies

From the project root:

```bash
flutter pub get
```

---

# 30. Run Flutter application

### Chrome

```bash
flutter run -d chrome
```

### Android

Check devices:

```bash
flutter devices
```

Then:

```bash
flutter run
```

---

# 31. Build Android

### APK

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle

```bash
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# 32. Build Web

```bash
flutter build web --release
```

Output:

```text
build/web/
```

---

# 33. Run backend

If the Node/Prisma backend is required:

```bash
cd backend
npm install
```

Generate Prisma client:

```bash
npm run db:generate
```

Development:

```bash
npm run dev
```

Production-style start:

```bash
npm start
```

Prisma database commands:

```bash
npm run db:push
npm run db:studio
```

Configure the backend environment variables required by `backend/src/server.js` and Prisma before starting the server.

---

# 34. Firebase

The repository contains:

```text
lib/firebase_options.dart
web/firebase-messaging-sw.js
android/app/google-services.json
```

Firebase is initialized during application startup.

Do not commit private Firebase service-account credentials or other server-side secrets.

---

# 35. GitHub Actions

The repository contains:

```text
.github/workflows/android.yml
```

The current workflow:

1. Checks out the repository.
2. Installs Flutter stable `3.47.0`.
3. Regenerates Android platform files.
4. Runs `flutter pub get`.
5. Builds a release APK.
6. Builds a release AAB.
7. Uploads both artifacts.

Workflow trigger:

```text
push to main
```

and manual:

```text
workflow_dispatch
```

---

# 36. Testing and code checks

Run:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

The repository currently contains a basic widget smoke test under:

```text
test/widget_test.dart
```

The current test is a template-style counter test and should be replaced/expanded with payroll-specific tests before treating it as comprehensive application coverage.

Recommended payroll tests include:

```text
OT minutes
Net working minutes
Unpaid deduction
Late deduction
Public holiday
EPF
SOCSO
EIS
Net salary
```

---

# 37. Recommended payroll test examples

### Public holiday

For:

```text
Basic salary = RM1,700
PH worked = 1 day
```

Expected:

```text
1,700 / 26 × 2 = RM130.77
```

### Unpaid

If `eis_applicable = false`:

```text
Unpaid per day = Basic Salary / 28
```

Otherwise:

```text
Unpaid per day = Basic Salary / 26
```

### OT

For a 7:30 net target:

```text
8:53 net
= 533 minutes

533 - 450
= 83 minutes

83 minutes
= 1 hour 23 minutes
```

This is an important regression test because OT must remain synchronized in **minutes**, rather than accidentally interpreting `1.23` as decimal hours or reusing a stale two-hour value.

---

# 38. Security

Payroll and employee information is sensitive.

Production deployment should enforce authorization at the database/API layer, not only by hiding buttons in Flutter.

Recommended authorization model:

```text
ADMIN
  ↓
Authorized administrative payroll/employee access

BRANCH
  ↓
Authorized assigned-branch access

EMPLOYEE
  ↓
Own employee/payroll access
```

Protect:

- IC/passport numbers
- Bank accounts
- EPF numbers
- SOCSO numbers
- Salary
- Payroll deductions
- Payroll contribution data
- Authentication credentials
- OTP information

Never commit:

```text
service_role keys
private API keys
passwords
JWT signing secrets
Firebase service-account credentials
database passwords
```

---

# 39. Production checklist

Before production deployment:

- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Android release APK builds
- [ ] Android AAB builds
- [ ] Supabase connection verified
- [ ] Database RLS policies verified
- [ ] Admin access verified
- [ ] Branch access verified
- [ ] Employee access verified
- [ ] First-login OTP tested
- [ ] Password creation tested
- [ ] Attendance saving tested
- [ ] Attendance statuses tested
- [ ] Net working minutes tested
- [ ] OT request tested
- [ ] OT authorization tested
- [ ] OT minute synchronization tested
- [ ] Unpaid calculation tested
- [ ] Late deduction tested
- [ ] Public holiday calculation tested
- [ ] EPF tested
- [ ] SOCSO tested
- [ ] EIS tested
- [ ] Payroll overwrite behavior tested
- [ ] Payslip PDF tested
- [ ] RHB Excel tested
- [ ] EPF Excel tested
- [ ] EIS Excel tested
- [ ] SOCSO Excel tested
- [ ] Bank account data verified
- [ ] EPF number data verified
- [ ] Firebase notifications tested
- [ ] Secrets removed from source control
- [ ] Database backup/recovery verified

---

# 40. Known audit observations

This README is based on an audit of the supplied repository snapshot.

### 1. Flutter test is still the default counter smoke test

`test/widget_test.dart` tests a counter UI rather than the payroll application. Payroll-specific automated tests should be added.

### 2. Backend and Flutter data layers are separate

The repository contains both direct Supabase access and a Node/Prisma backend. They should be intentionally synchronized rather than treated as automatically interchangeable.

### 3. OT rule comments and implementation should remain synchronized

The attendance save logic currently contains explicit OT eligibility checks involving break fulfilment and extra minutes. Any future business-rule change should update both:

```text
lib/screens/supabase_service.dart
lib/services/attendance_payroll_service.dart
```

together.

### 4. Payslip field labels should be reviewed

`pdf_service.dart` contains employee/bank-related display mappings that should be reviewed before production release to ensure every label corresponds to the correct database field.

### 5. Database schema source of truth should be documented

The repository contains a PostgreSQL dump and a separate Prisma schema, while the Flutter application directly accesses Supabase. Production should designate one authoritative schema/migration process.

---

# 41. Development workflow

Recommended workflow:

```text
1. Update database/schema
        ↓
2. Update Supabase/data service
        ↓
3. Update payroll calculation service
        ↓
4. Update UI
        ↓
5. Test calculation
        ↓
6. Test Excel/PDF exports
        ↓
7. flutter analyze
        ↓
8. flutter test
        ↓
9. Build release
        ↓
10. Commit and push
```

For payroll calculation changes, always test at least one manually verified employee before generating the complete monthly payroll.

---

# 42. Repository

GitHub:

```text
https://github.com/wajisumiliya/hasanipayroll
```

---

# 43. License

The repository contains a `LICENSE` file. Refer to that file for the authoritative license terms.

---

## Hasani Books Payroll Portal

Payroll • Attendance • Employees • Branches • Payslips • Statutory Contributions • Excel Exports • Notifications
