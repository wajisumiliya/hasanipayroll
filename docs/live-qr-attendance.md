# Live USB QR attendance (pilot)

## Status
Feature branch only. Not deployed, and Neon migration must be applied before use. This is a pilot event ledger, not yet a replacement for the existing Attendance Sheet or payroll calculation.

## Requirements
- USB 2D QR reader configured as USB HID keyboard, append Enter suffix.
- Windows PC with Hasani Payroll in a focused browser tab.
- Authenticated active branch account assigned to the same branch as the employee.
- Existing Node backend with Neon DB connectivity.

## Database migration
Apply `backend/sql/qr-attendance.sql` to Neon using your approved database migration workflow and a credential that can create tables. Backup first.

## Provision an employee QR
Only an authenticated administrator can call `POST /api/qr-attendance/issue` with JSON `{"employee_id":"EMP001"}` and a bearer token. The API returns `qr_value` **once**. Encode that value as a QR code, print, and issue it to the employee. Store no IC numbers or names in the QR code. Reissue immediately invalidates prior QR. Keep the issued credential secret. A card can be shared, so add supervised photo confirmation for higher assurance.

## Punch flow
Branch portal > QR Scanner > focus input > scan. The scanner sends token then Enter. The backend hashes the token, matches an active employee and branch, serializes concurrent scans, rejects repeats within 60s, and records Malaysia-local daily IN then OUT, with timestamp generated in PostgreSQL. After OUT, additional scans require supervisor correction.

## Important limitations
- This pilot has **one IN and one OUT per Malaysia calendar day**. Split shifts, breaks, overnight shifts, and holidays need additional rule design before company-wide launch.
- Scan events go to `public.qr_attendance_events`, and intentionally **do not** overwrite `public.attendance`. Admin reconciliation and approved transfer into attendance sheets are a separate follow-up.
- Scanner needs an authenticated, attended terminal with a focused input; do not use this as a publicly exposed kiosk without dedicated device authentication.
- QR cards alone do not prove the person holding them is the correct employee.
- Configure network/TLS and protect the printed token.

## Acceptance checks before merging
1. Apply migration to a staging Neon database.
2. Issue QR for one active test employee; scan IN and OUT in that branch.
3. Confirm PostgreSQL server timestamp and branch match.
4. Reject old/reissued/unknown QR codes and other-branch scans.
5. Reject rapid duplicate scan and third daily scan.
6. Verify branch and employee portals do not gain admin provisioning access.
7. Run `flutter analyze`, `flutter test`, `npm --prefix backend test`, and backend syntax checks in CI.
8. Verify old attendance and payroll unaffected; review API rate limits and scanner device verification.
