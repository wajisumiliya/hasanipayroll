# Early Out approval system — review package

Status: implemented locally for review. No commit, push, deployment or production
migration has been performed. The only schema execution was against disposable
local PostgreSQL test databases with synthetic employees.

## Existing architecture

- Flutter calculates attendance payroll in AttendancePayrollService. Net-working
  shortage, including Early Out, already feeds late_deduction. Checkout grace,
  daily/hourly rates, monthly RM10 waiver and ten-sen rounding already exist.
- AttendanceDialog also calculates attendance/print previews; batch print uses
  AttendanceBatchPrintService. Payslips use saved payroll values.
- Express uses authenticated JWT identities and pg for the imported Neon
  public.attendance, daily_rosters, monthly_rosters and payroll tables. The
  repository's Prisma PayrollRecord is a different legacy model; this feature
  does not run Prisma db push or replace the imported schema.
- No Early Out approval table existed. Existing Late Report reviews approve late
  arrivals only and are deliberately not reused as Early Out permission.

## New workflow and authorization

Early Out appears in the admin and account navigation. It lists employee ID,
name, recorded branch, attendance date, scheduled/actual checkout, required/worked
hours, raw shortage, eligible Early Out duration, current approval status,
approved duration, approver, timestamp, remarks and Review action. Month/year,
branch ID, employee ID, status, search, 20-row pagination and refresh are supported.
Text search/ID filters apply when submitted with Enter.

Only authenticated Admin or Accounts can decide. Existing account users are
ADMIN with attendance staff scope (or the account username); explicit ACCOUNT /
ACCOUNTS roles are also recognized. Branches/employees, reviewers and request-only
administrators cannot approve/reject. Staff scopes remain checked on the server.

The backend derives each event from current attendance, daily/weekly shift rules
and salary-rule target flags. Missing schedules/checkouts on recorded Early Out
rows remain visible, but approval is disabled until evidence is corrected.
Approval requires submitted attendance and a matching employee/date/fingerprint.
A partial duration cannot exceed the eligible Early Out portion.

Decisions are append-only. Each contains server-derived actor ID, role, database
timestamp, duration, remarks, attendance snapshot and request ID. ActivityLog uses
the existing public.branch_activity_logs table. A PostgreSQL transaction, per-day
advisory lock, attendance row lock, request-ID uniqueness and expected revision
prevent duplicate/conflicting decisions. Idempotent retries return the original
result. Timing/shift changes invalidate old approvals instead of transferring
permission to a different event. No historical records are auto-approved.

## Calculation and payroll cutoff

The user approved freezing approvals at payroll generation. The context endpoint
uses a database-clock cutoff with full timestamp precision; every generated row
stores that cutoff and the decisions actually considered in early_out_snapshot.
Later approvals do not update existing payroll or payslips.

Existing eligible shortage = max(0, required net minutes - worked net minutes
- existing checkout grace). Eligible Early Out portion = min(eligible shortage,
max(0, scheduled checkout - actual checkout - existing checkout grace)). Only
current matching approved minutes, capped to that portion, are subtracted.
Pending, rejected, missing or stale approvals exempt zero. Late arrival and break
shortage beyond the approved portion remain deductible. The same helper powers
generation and previews. The existing late_deduction field is reused: no second
Early Out charge is added. Existing leave, PH, FRN, HED1007, management, temporary
and support exemptions remain.

Example with required 8h, worked 6h, checkout 2h early: existing 15-minute grace
leaves 105 eligible minutes. Full approval exempts 105 and leaves zero deduction.
Pending/rejected/missing approval leaves 105 eligible. At RM5,200 basic, the
existing local basic/26/8 hourly rule gives RM43.80 after current rounding. A
45-minute partial approval leaves 60 deductible minutes = RM25.00. If another
60 minutes are missing because of lateness, approving all 105 Early Out minutes
still leaves those 60 minutes deductible. Existing monthly RM10 waiver applies.
The grace/rounding rules are retained, not replaced with a new Early Out formula.

## Existing/manual/finalized payroll

Generation never silently recalculates payroll when an approval is recorded.
For generated draft snapshots, matching previously calculated amounts may be
regenerated through the existing authorized overwrite workflow. Manual overrides
and legacy records without a trustworthy baseline are preserved conservatively.
PCB, zakat and advances remain as saved. Unpaid and statutory override baselines
are also checked. Generation completion warns when attendance deductions were
preserved; unknown legacy values are not assumed to be automatic calculations.

Edit Payroll has Review Early Out. It previews the current calculated amount,
requires confirmation before replacing a current late/shortage deduction, keeps
other manual deductions, and still requires Save Payroll. Reset cancels pending
snapshot changes. Automatic statutory amounts use the existing calculation;
manual statutory overrides remain protected. Saved payslips continue to use the
single saved late_deduction, avoiding duplicate charges.

Published/finalized/paid records are blocked from regeneration in Flutter and by
a database trigger, including ordinary attempts to reopen a locked record. An
approval can still be recorded for audit, but the locked payroll remains intact.
An authorized adjustment must be separately reviewed in an open payroll period
using the existing manual adjustment fields and remarks linking the decision;
this feature never posts such an adjustment automatically.

## Required migration — approval pending

backend/migrations/20261102_early_out_approvals.sql:
1. Adds app_private.early_out_decisions and lookup/unique indexes.
2. Adds nullable public.payroll.early_out_snapshot JSONB; existing rows unchanged.
3. Adds append-only approval protection and locked-payroll write protection.

The migration is intentionally NOT registered in ensureApplicationSchema or any
startup/deployment hook. No production migration has run. Review/approve the SQL,
back up and validate staging before applying it to an approved database. Apply
before enabling the new frontend/backend together. It is idempotent and was
executed twice against the local fixture. No employee salary UPDATE/bulk SQL is
part of this migration. Without installation, the API returns an explicit
migration-required error and payroll generation fails closed rather than ignoring
approval verification. Existing clients tolerate the nullable extra payroll field.

## Changed files

- backend/migrations/20261102_early_out_approvals.sql
- backend/src/early-out-api.js, early-out-calculation.js, server.js
- lib/screens/early_out_page.dart, admin_dashboard.dart, attendance_dialog.dart
- lib/services/early_out_calculation.dart, attendance_payroll_service.dart,
  attendance_batch_print_service.dart, app_service.dart
- test/early_out_calculation_test.dart, early_out_page_test.dart
- backend/test/early-out.test.js
- .gitignore: allow this specific reviewable SQL migration.
- This review report.

Test-only maintenance, uncovered by running the complete suite:
- backend/test/data-api-postgres.test.js now asserts the already-approved policy
  excluding approved late arrivals and checks that raw audit evidence still exists.
- backend/test/fixtures/database-cleanup.js and three consumers
  (attendance-batch-print, mystery-egg-reminder, payroll-increment-sync tests) wait
  for closing PostgreSQL fixture connections before dropping disposable DBs.
  They no longer force-terminate closing clients. No tests are skipped/bypassed.

## Validation

- Full Flutter suite: 272 passed.
- Full backend suite with local PostgreSQL integration enabled: 203 passed,
  0 failed, 0 skipped. The final focused Early Out run also passed all 8 tests.
- Default flutter analyze: 0 errors; repository warning/info diagnostics remain
  and make the default command nonzero. New Early Out files are separately
  checked rather than suppressing those diagnostics.
- Backend syntax, Dart formatting and git diff checks pass.

Initial full-backend failures were resolved, not skipped: one stale Late Report
assertion was corrected to the previously approved rule; forced teardown of
closing local DB connections was replaced by a connection-drain check.
Tests cover Admin/Accounts, pending/rejected/missing/full/partial/stale decisions,
wrong employee/date/month, concurrency, idempotency, persisted audit, exact cutoff,
recalculation, existing payroll immutability, finalized/paid protection, manual
amount protection, filters/pagination and approval-form validation. Full Flutter
and backend suites were run; PostgreSQL-backed tests used a local disposable
postgres:17 container, not Neon production.

Flutter available here is 3.44.0; the original repository lockfile is unchanged.
Its locally resolved test dependencies differ from the repository's newer Flutter
3.47 lock by four SDK-pinned transitive packages. Re-run locked CI on the project's
configured Flutter version before release. Default flutter analyze is reported
honestly: existing repository warning/info diagnostics are not suppressed or
fixed by unrelated production changes.
