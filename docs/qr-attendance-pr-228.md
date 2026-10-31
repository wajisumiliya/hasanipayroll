QR scans now record audited, branch-authorized, server-clock attendance events in
the existing Hasani Payroll portals. The pilot's calendar-day reset and unprotected
retries are replaced with overnight work sessions, transaction locks and durable
idempotency receipts. Raw events stay separate from payroll until an administrator
reviews and approves a protected Attendance Sheet draft mapping.

- Admin Employee QR Cards: secure individual/bulk issuance, photo/name/ID/branch,
  reissue/revoke history, A4 printing and PDF download with bundled fonts.
- Branch scanner: registered station and expiring operator session, HID Enter,
  photo supervision, kiosk view, Malaysia 12-hour display and pending-result
  recovery. Safe cancellation prevents a delayed original request from punching.
- Admin/branch monitoring: scoped date/search/branch views, overnight OUT and older
  unmatched IN, roster-based late/early review, photos, audit and PDF/XLSX exports.
- Audited corrections (including related requests reviewed together), immutable
  originals, source fingerprints, draft-only reconciliation and submission/OT
  conflict checks. No automatic attendance submission or overtime authorization.

Validation: 240 Flutter tests passed; 147 backend tests passed, 7 unrelated DB
integration tests skipped. Local PostgreSQL 16 migration/reapplication, concurrency,
retry/cancel races, authorization, corrections, enum/time schema, protected draft
mapping and real exports pass. Native Dart formatting and Node syntax checks pass.
Analysis has zero compile errors/new QR diagnostics; 94 baseline warnings/lints
remain versus 95 on main under the same Flutter 3.44.0 toolchain. The checked-in
lockfile and generated web/watermark artifacts are not changed.

**Do not merge or enable production yet.** QR_ATTENDANCE_ENABLED defaults false.
The SQL in backend/sql/qr-attendance.sql is manual and additive, not a startup
migration. Run the read-only preflight on the actual staging database, review and
apply the migration with approval, register a station, then validate a physical
Windows 2D HID scanner and the end-to-end approval/submission/payroll workflow.
Obtain separate explicit approval before production database migration/deployment.
No actual Neon credentials or physical scanner were available in this task.

Reconciliation supports complete workdays under 24 hours with up to two breaks;
other sequences, existing OT, special statuses or branch conflicts stay available
for manual review. Static cards do not prove the holder's identity. Polling is
15 seconds while visible; rate limiting is per process until a shared store is
configured for horizontal scaling. Full setup, migration, hardware and recovery
instructions: docs/live-qr-attendance.md. Audit: docs/qr-attendance-audit.md.

PR: https://github.com/wajisumiliya/hasanipayroll/pull/228

The implementation also preserves the separately requested main increment fix
1cd645d: October selects April only and shows basic salary plus total allowances.

The dedicated QR attendance workflow runs the full backend suite with a disposable
PostgreSQL service and Flutter formatting/tests/web compilation. Its analysis step
continues to fail compile errors while tolerating the separately documented existing
warnings/lints. No deployment step or production database credentials are present.
GitHub Actions execution still needs confirmation after the branch push.

## Files changed

- `.github/workflows/qr-attendance.yml`
- `assets/qr_fonts/DejaVu-LICENSE.txt`
- `assets/qr_fonts/DejaVuSans-Bold.ttf`
- `assets/qr_fonts/DejaVuSans.ttf`
- `backend/.env.example`
- `backend/sql/qr-attendance.sql`
- `backend/src/late-report-export-worker.js`
- `backend/src/qr-attendance-core.js`
- `backend/src/qr-attendance-export-renderer.js`
- `backend/src/qr-attendance-export.js`
- `backend/src/qr-attendance.js`
- `backend/src/scripts/check-qr-schema.js`
- `backend/src/server.js`
- `backend/test/qr-attendance-api.test.js`
- `backend/test/qr-attendance-postgres.test.js`
- `backend/test/qr-attendance.test.js`
- `docs/live-qr-attendance.md`
- `docs/qr-attendance-audit.md`
- `docs/qr-attendance-pr-228.md`
- `lib/screens/admin_dashboard.dart`
- `lib/screens/branch_dashboard.dart`
- `lib/screens/employee_qr_cards_page.dart`
- `lib/screens/live_qr_attendance_page.dart`
- `lib/screens/qr_attendance_page.dart`
- `lib/screens/qr_station_dialog.dart`
- `lib/services/neon_api.dart`
- `lib/services/qr_attendance_service.dart`
- `lib/services/qr_card_pdf_service.dart`
- `lib/widgets/qr_attendance/employee_photo.dart`
- `pubspec.yaml`
- `test/qr_attendance_page_test.dart`
- `test/qr_attendance_service_test.dart`
- `test/qr_card_pdf_service_test.dart`
