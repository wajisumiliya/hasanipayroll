# Hasani Payroll Live USB QR Attendance

Feature branch: `feature/live-qr-attendance`. PR: https://github.com/wajisumiliya/hasanipayroll/pull/228

This module runs inside the existing Flutter Branch/Admin portals and Node API.
It is **disabled by default** (`QR_ATTENDANCE_ENABLED=false`). No production QR
migration or deployment has been performed. Do not merge or enable production
until actual Neon staging compatibility and a physical scanner are verified.

## Screens and workflow

- Admin → Employee QR Cards: employee ID/name/photo/branch, individual or bulk
  generation/reissue (up to 100), immediate revocation, issuance history, A4 print
  and PDF download. A reissued card invalidates the previous credential immediately.
- Admin → Live QR Attendance: branch/date/search filters, current IN/OUT, calendar-
  date punches (including overnight OUT), missing OUT, roster-based late/early
  departure, raw/effective history, rejected scans, audit, PDF/Excel export,
  correction approval and reviewed Attendance Sheet mapping.
- Branch → QR Scanner: registered station/session, HID Enter capture, autofocus,
  photo/name/employee ID/branch, server-confirmed IN/OUT in 12-hour Malaysia time,
  configurable supervisor verification and a kiosk display.
- Branch → QR Attendance: own-branch monitoring, history/photos/summaries, exports
  and correction requests. Other branches cannot be selected or accessed.

Raw QR scans never automatically change attendance or payroll. An administrator
reviews a proposal and approves a draft mapping; the normal Attendance Sheet
submission and existing payroll calculations remain in control.

## Credential and scanner security

QR payloads are `HBQR1_` plus 32 cryptographically random bytes encoded base64url.
Only SHA-256 hashes are stored; raw tokens are returned only by issuance, then
held in memory to create the printable PDF. They never appear in employee list,
monitoring, audit or history APIs. Cards contain no IC/bank information in their
QR payload. PDFs intentionally contain the issued QR and must be handled privately.
QR tables are excluded from the generic data API, with PUBLIC/anon/authenticated
SQL access revoked. Existing protected photo endpoints perform photo delivery.

Only JWT-authenticated BRANCH operators can punch. They must use an enabled
registered station in their assigned branch and an unexpired operator-bound
12-hour scanner session. Admin/reviewer/employee roles cannot bypass the scanner
session by posting employee IDs or timestamps. Local/foreign admin employee scope
also applies to credential management, corrections and record review.

Station defaults: minimum 60 seconds between punches; multiple work sessions
allowed; supervisor photo verification required; unmatched IN older than 36 hours
requires review. Administrators can configure these policies. The age threshold
**rejects ambiguity and never creates an automatic OUT**. Verification uses a
single-use, two-minute credential/session-bound ticket and records the operator.
A static QR can be shared: it identifies a credential, not the person holding it.
The supervisor must compare the person with the photo; do not confirm absent or
unrecognizable photos. Disable supervision only after deciding the identity risk.

Per-employee and per-request PostgreSQL advisory transaction locks, unique
(session_id,request_id) receipts and server timestamps prevent concurrent double
punches. Endpoint rate limits run after authentication. In-memory rate limits are
per server process; use a shared rate-limit store before horizontally scaling.

## Work dates, breaks and reconciliation

Scanned timestamps are PostgreSQL `clock_timestamp()` timestamptz values. Work
calendar dates and display use Asia/Kuala_Lumpur. The next punch closes the latest
open IN, even after midnight. A first IN after midnight can use the previous work
date only when an assigned previous-day overnight roster establishes that shift.
Daily roster overrides weekly roster. Unknown schedules are not invented.

The original Attendance Sheet morning/afternoon pairs are BREAK start/end fields.
Reconciliation spans the day with check_in/check_out and maps gaps between work
sessions into those break fields. Gross, net and break minutes are derived from
UTC intervals. The preview lists all events and exact proposed values; approval
requires an unchanged fingerprint. No overtime fields or approvals are created.

Only complete alternating IN/OUT sequences with at most two breaks (three work
sessions) and a span under 24 hours can map automatically. Extra breaks, longer
workdays, leave/special-status conflicts, existing OT timing/requests, historical
branch conflicts and submitted/OT-approved attendance require manual review in
the existing workflow. Raw punches remain available, including unsupported cases.
Existing locks are checked on the selected row and again in the conflict upsert.

Manual corrections are requests with reasons. Only an administrator can approve
or reject them. Corrections may adjust/void a raw event or add a missing punch;
the original event is immutable. Related requests for one employee can be approved
atomically (up to 20) to remove an accidental IN/OUT pair. Sequence validation
rejects new ambiguity; it permits progressive repair of older pilot inconsistencies.
Historical branch closure can be corrected by admin before an employee transfer;
the existing admin employee-branch assignment authorizes subsequent branch scans.
Correcting submitted/OT-approved workdays requires the existing admin unlock
workflow; no QR endpoint silently bypasses it.

## Uncertain network results

Success is shown only after a committed event response with event ID. If a POST
result is uncertain, the scanner retains the same request ID and checks its
receipt before allowing retry. Browser storage contains only request/session/
employee identifiers, never the QR token or verification ticket. Reloading or
signing back into the same operator account recovers that receipt.

`NOT_FOUND` is not proof that an in-flight request cannot commit. Retrying must
rescan the original employee card and retain the original request ID. A safe
cancellation endpoint uses the same transaction lock: it either returns the
already committed event or writes a rejection tombstone preventing any delayed
original request from recording later. Status lookup/cancellation remain available
to the same authenticated operator after scanner-session expiry/revocation.
Never clear browser storage or create a new request merely because a request timed
out. Resolve or safely cancel it, then renew the scanner session if required.

## Database rollout (manual approval required)

1. Keep the new backend disabled with `QR_ATTENDANCE_ENABLED=false`, replacing
   the pilot API before migration so the old calendar-day scanner cannot write.
2. Back up the staging database and use its actual backend credentials. In the
   backend directory, run `node src/scripts/check-qr-schema.js --base-only`.
   This is read-only and checks existing attendance/employee columns, clocks,
   boolean submission locks and the unique employee/date key.
3. Review and manually apply `backend/sql/qr-attendance.sql` to **staging** using
   your approved SQL workflow. It retains pilot credentials/events; v2 adds
   station/session, attempt, verification, audit, correction, reconciliation and
   presence tables, indexes, an effective-event view and a raw immutability trigger.
   The work-date backfill preserves the pilot's recorded Malaysia calendar date;
   inspect old overnight inconsistencies rather than silently rewriting them.
4. Run `node src/scripts/check-qr-schema.js` using the staging backend role.
   Confirm schema/permissions, immutable raw events and required indexes. The
   migration operator must own these tables or grant the backend its required
   service permissions; never grant QR tables to browser SQL roles.
5. Enable the flag on **staging**, register a station, issue sample cards, and test
   the full matrix below, including existing real-schema enums and submit locks.
6. Obtain explicit production migration/deployment approval. Repeat approved
   backup, disabled-backend rollout, SQL/preflight and acceptance in production.
   Enable only after validation. No QR SQL is registered in automatic startup
   migrations and this branch must not be merged merely because fixtures pass.

No production database credentials were available in this task. Local PostgreSQL
schema fixtures were tested; actual Neon compatibility remains a rollout gate.
Do not delete event, attempt or audit history without a separately approved
retention policy. Expired verification-ticket cleanup can be planned separately.

## Windows USB HID setup

1. Use a **2D QR** USB scanner; a 1D-only barcode reader cannot read these cards.
2. Connect it to Windows and use the manufacturer's setup barcodes to select
   USB HID/keyboard mode, a matching keyboard layout (normally US), and an Enter
   suffix. Disable Caps Lock and avoid text transformations. CR/LF double suffixes
   are handled by the software busy guard, but Enter-only is preferred.
3. Test typing with a dummy setup QR such as `HASANI-SCANNER-TEST` in Notepad.
   Do not test live employee credentials in shared documents, chat or logs.
4. Sign into the existing Branch Portal, open QR Scanner, choose the registered
   branch station and start its session. Scan a sample issued employee card.
5. If supervision is enabled, compare the person's photo and confirm. Confirm
   that the screen shows the employee, IN/OUT, Malaysia server time and event ID.
   A scanner beep alone is not server confirmation. Wait for Ready before the
   next employee; the input refocuses automatically after each resolved scan.
6. Open the kiosk display to hide portal navigation. Press **F11** in the Windows
   browser for browser fullscreen. Keep the tab active; return focus to the scan
   input after Alt-Tab, browser prompts or another application takes keyboard focus.
7. If no characters arrive, check USB, scanner power, HID mode, focus and suffix.
   The app cannot physically detect disconnection and does not claim it can.
   If characters differ, check layout/Caps Lock; reissue truly invalid/revoked cards.
8. For timeout/backend/database errors, use Check pending request result. Resolve
   or safely cancel before retrying. There is no offline clock or automatic local
   timestamp queue. Request an audited manual correction for a verified missed punch.

## Verification and limits

- Automated PostgreSQL tests cover additive migration/reapplication, hashed cards,
  issuance/revocation, auth/scope/branch isolation, employee inactivity/expiry,
  clock override rejection, sessions/verification, concurrency/idempotency,
  cancel/scan races, correction/transfer/batch review, immutable originals,
  protected attendance, enum/time-column compatibility and real PDF/XLSX export.
- Flutter tests cover HID Enter, server-confirmed success, Malaysia time, mandatory
  supervision, no false success on uncertainty, recovery/retry IDs, cancellation,
  small viewport and individual/100-card PDF pagination.
- No physical Windows USB scanner, production Neon or real employee identity was
  available for acceptance. Reports use current roster data; unknown schedules
  show not established. Existing pilot anomalies require administrator review.
- Monitoring polls every 15 seconds only while visible/foreground, avoiding overlap.
  Older open sessions use indexed presence. UI history shows the latest 200 punches
  and 100 attempts; exports include the selected workday events and latest 1000
  attempts. Audit is date-filtered/latest 1000; card history is latest 200.

See [audit and implementation record](qr-attendance-audit.md) and
[PR update and validation](qr-attendance-pr-228.md) for final check results and files.
