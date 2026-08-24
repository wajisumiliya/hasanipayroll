# Hasani Books Payroll Portal

A complete payroll and employee management application developed for Hasani Books.

The system provides separate portals for:
- Admin
- Branch
- Employee

It supports employee management, payroll management, attendance, payslips, first-login OTP verification, password management, notifications and PDF/printing functionality.

---

## 🚀 Features

### 👨‍💼 Admin Portal

Administrators can:
- Manage employees
- Add new employees
- Edit employee information
- Activate/deactivate employees
- Manage branches
- Manage departments
- Manage payroll
- Manage attendance
- View employee information
- View payroll history
- Manage salary information
- Manage allowances
- Manage deductions
- Manage EPF
- Manage SOCSO
- Manage EIS
- Manage employee contributions
- Manage employer contributions
- Generate payslips
- Print payslips
- Export payroll information
- Manage employee access
- Send employee notifications

### 🏢 Branch Portal

Branch users can:
- View employees assigned to their branch
- View employee information
- Manage branch attendance
- View payroll information
- Manage branch-related employee records
- View new joiners
- Filter employees by department
- View employee status

Branch users should be restricted to their assigned branch.

### 👤 Employee Portal

Employees can:
- Login using their employee account
- Complete first-login verification
- Verify OTP
- Create a new password
- View personal information
- View payroll history
- View payslips
- Download payslips
- Print payslips
- View attendance
- View salary information
- Receive notifications
- Update their password

Employees should only be able to access their own information.

---

# 🔐 Authentication

The application supports:
- Username / Employee ID login
- Role-based portal access
- First-login OTP verification
- Password creation
- Password update
- Session restoration
- Admin authentication
- Branch authentication
- Employee authentication

### User Roles

```text
ADMIN
BRANCH
EMPLOYEE
```

---

# 📱 Supported Platforms

The Flutter application is designed for:
- Android
- iOS
- Web
- Windows
- macOS
- Linux

The primary deployment target is Android.

---

# 🛠 Technology Stack

## Frontend
- Flutter
- Dart
- Material 3

## Database
- Supabase
- PostgreSQL

## Backend
- Node.js
- Express.js
- REST API

## Authentication
- Supabase
- Application authentication
- OTP verification

## Notifications
- Firebase Cloud Messaging
- Flutter Local Notifications

## Documents
- PDF
- Printing
- CSV import/export

---

# 📂 Project Structure

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
│   └── hasani_books_logo.jpg
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── models/
│   │   └── payroll.dart
│   │
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── admin_dashboard.dart
│   │   ├── branch_dashboard.dart
│   │   ├── employee_portal.dart
│   │   └── supabase_service.dart
│   │
│   └── services/
│       ├── app_service.dart
│       ├── pdf_service.dart
│       └── notification_service.dart
│
├── supabase/
│   └── schema.sql
│
├── .github/
│   └── workflows/
│
├── pubspec.yaml
└── README.md
```

---

# 🗄 Database

The application uses Supabase PostgreSQL.

Main data areas include:

```text
app_user
employees
payroll
attendance
```

Additional tables may be used for:

```text
notifications
OTP verification
employee records
salary records
payslips
device tokens
```

---

# 👥 Employee Information

Employee records can contain:

```text
Employee ID
Name
Designation
Department
Email
Phone
IC Number
Bank Code
Bank Account
Address
Joining Date
Branch
Active/Inactive Status
```

Sensitive employee information must be protected using database-level security policies.

---

# 💰 Payroll

Payroll records support information such as:

```text
Employee
Payroll Month
Basic Salary
Allowance
Gross Salary
Deduction
EPF
SOCSO
EIS
Employee Contribution
Employer Contribution
Net Salary
```

Payroll history can be stored for previous months and years.

---

# 📅 Attendance

Attendance management supports employee attendance records.

Typical information includes:

```text
Employee
Date
Status
Check In
Check Out
Working Hours
Remarks
Branch
```

Possible attendance statuses include:

```text
Present
Absent
Leave
MC
Late
Half Day
Off Day
```

---

# 📄 Payslips

The application supports payslip generation using PDF.

Employees can:
- View payslips
- Download payslips
- Print payslips
- Access previous payroll periods

Administrators can generate payslips for employees.

---

# 🔔 Notifications

Firebase Cloud Messaging is used for push notifications.

Examples:

```text
Salary Credited
Payslip Available
Salary Increment
Important Announcement
Attendance Notification
Company Announcement
```

Example:

```text
Salary Credited

Your salary for August 2026 has been credited.
```

---

# 🔑 First Login

New employees can be required to complete first-login verification.

The flow is:

```text
Employee Login
      ↓
First Login Detected
      ↓
Request OTP
      ↓
OTP Sent
      ↓
Enter OTP
      ↓
Verify OTP
      ↓
Create New Password
      ↓
Employee Portal
```

---

# 🌐 Backend

The application can communicate with the payroll backend through a REST API.

Default production API:

```text
https://hasaniworkhub.onrender.com/
```

The API URL can be configured using:

```text
API_BASE_URL
```

Example:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api-url.com
```

---

# ⚙️ Installation

## 1. Clone Repository

```bash
git clone https://github.com/wajisumiliya/hasanipayroll.git
```

Go to the project:

```bash
cd hasanipayroll
```

## 2. Install Flutter Dependencies

```bash
flutter pub get
```

## 3. Check Flutter

```bash
flutter doctor
```

---

# ▶️ Run Application

## Android

Connect an Android device or start an emulator.

```bash
flutter devices
```

Run:

```bash
flutter run
```

## Chrome / Web

```bash
flutter run -d chrome
```

---

# 🏗 Build Android APK

For a release APK:

```bash
flutter build apk --release
```

Generated APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# 📦 Build Android App Bundle

For Google Play Store:

```bash
flutter build appbundle --release
```

Generated AAB:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# 🌐 Build Web

```bash
flutter build web --release
```

Output:

```text
build/web/
```

---

# 🔥 Firebase Setup

Firebase is used for push notifications.

Required Firebase configuration files must be present for the platforms being built.

Android normally requires:

```text
google-services.json
```

Flutter Firebase configuration is generated/configured through:

```text
firebase_options.dart
```

Do not commit private Firebase service-account credentials to GitHub.

---

# 🟦 Supabase Setup

Create a Supabase project and configure the required PostgreSQL database.

The application requires the Supabase URL and public client key.

The Supabase client should be configured using public/publishable credentials.

### Important

Never place a Supabase:

```text
service_role
secret key
private key
```

inside the Flutter application.

Only public/publishable credentials should be exposed to the client.

---

# 🔒 Security

Payroll information is sensitive.

The application should use Supabase Row Level Security (RLS).

Recommended access model:

```text
ADMIN
  ↓
All authorized payroll data

BRANCH
  ↓
Only assigned branch data

EMPLOYEE
  ↓
Only own employee/payroll data
```

Database security must be enforced by PostgreSQL/Supabase policies and not only by Flutter UI restrictions.

---

# 🛡 Recommended RLS Rules

## Employees

Employees should only access their own employee record.

Branch users should only access employees belonging to their branch.

Administrators should have appropriate administrative access.

## Payroll

Employees:
```text
SELECT own payroll
```

Branch users:
```text
SELECT payroll belonging to their branch
```

Administrators:
```text
FULL authorized access
```

## Attendance

Employees:
```text
VIEW own attendance
```

Branch users:
```text
VIEW/manage attendance for their branch
```

Administrators:
```text
MANAGE authorized attendance records
```

---

# 🔐 Password Security

Passwords must never be stored as plain text in production.

Recommended architecture:

```text
Flutter
   ↓
Authentication Service
   ↓
Authenticated User
   ↓
Supabase RLS
   ↓
Payroll Data
```

Do not expose passwords through employee or payroll queries.

---

# 🧪 Testing

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Check dependencies:

```bash
flutter pub outdated
```

Check connected devices:

```bash
flutter devices
```

---

# 🧹 Code Quality

Before creating a production release:

```bash
flutter analyze
flutter test
flutter build apk --release
```

All critical errors should be resolved before deployment.

---

# 🚀 Production Checklist

Before publishing:

- [ ] Flutter analyzer passes
- [ ] All tests pass
- [ ] Android release build succeeds
- [ ] Supabase database configured
- [ ] RLS enabled
- [ ] RLS policies tested
- [ ] Admin permissions tested
- [ ] Branch permissions tested
- [ ] Employee permissions tested
- [ ] Password security verified
- [ ] OTP flow tested
- [ ] Firebase notifications tested
- [ ] Salary notification tested
- [ ] Payslip generation tested
- [ ] PDF printing tested
- [ ] Employee data protection verified
- [ ] Production API tested
- [ ] Database backup configured
- [ ] Firebase production configuration verified
- [ ] App icon configured
- [ ] Application version updated
- [ ] Android signing configured
- [ ] Google Play release tested

---

# 📈 Version

Current application version:

```text
1.0.0+1
```

---

# 🏢 About

**Hasani Books Payroll Portal**

An employee and payroll management platform designed for managing:

- Employees
- Branches
- Payroll
- Attendance
- Payslips
- Notifications
- Employee self-service

---

# 📞 Support

For application support and system administration, contact the Hasani Books system administrator.

---

# 📜 License

This project is proprietary software developed for Hasani Books.

Unauthorized copying, distribution, modification or commercial use is prohibited.
