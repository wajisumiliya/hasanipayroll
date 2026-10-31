# PR #228 audit and implementation record

Base reviewed: feature/live-qr-attendance at fec63a5 (PR #228 head fetched through
the Git pull ref). Main at 721985b is already an ancestor. All six original PR
files were inspected, along with JWT authentication, branch navigation,
attendance batch upserts, Attendance Sheet load/save mapping, late reports,
photo authorization, payroll calculations and schema migrations.

## Pilot findings

- Calendar-day IN/OUT reset could create two IN events across midnight and could
  not represent breaks or split shifts.
- No idempotency key: an uncertain retry could create a new transition after the
  fixed 60-second guard elapsed.
- Credential reissue replaced the only hash without a visible issuance history;
  there were no management, revocation or card-printing screens.
- No registered scanner station/session, supervised verification, endpoint-specific
  rate limiting, rejected-scan audit, branch monitoring or admin reconciliation.
- No automated tests; QR tables were manual SQL with no live-schema preflight.
- Catching a database/commit failure claimed no confirmation was saved, although
  a commit acknowledgement can be lost after the event is durably recorded.
- Existing morning/afternoon pairs are BREAK start/end, not work sessions. A naive
  IN/OUT-to-morning/afternoon mapping would change hours and late/break deductions.

## Implemented backend safeguards

Manual additive v2 migration retains pilot events and credentials. Raw punch
updates/deletes are blocked; approved corrections remain separate. Per-employee
and per-request transaction advisory locks serialize events and idempotent
retries. Registered stations, expiring operator-bound sessions, server-clock
punches, branch/employee status checks, single-use photo-verification tickets,
revocable credentials, endpoint limits and audit records are enforced server-side.

Work dates remain anchored to the opening IN, including after-midnight IN where
an assigned previous-day overnight roster establishes its shift date. A maximum
open-session age triggers review and never generates an OUT. A small indexed
presence table tracks older unmatched IN sessions without repeatedly aggregating
the entire event ledger during dashboard polling.

Reconciliation previews exact source events and a fingerprint. Only an explicit
admin approval can copy a complete, unambiguous workday into draft attendance.
Submission/OT locks are checked under transaction locks and again during upsert;
leave/special statuses, transfer conflicts and existing OT data require manual
review. Check-in/out span the workday; the gaps between sessions fill the existing
break fields. Overtime flags/approvals are never created. Original punches,
corrections, prior attendance, approved mapping and operator identity are audited.

## Verification boundaries

A disposable PostgreSQL 16 database is used for executable migration (including a
repeat application), locking, concurrency, authorization, idempotency, correction,
reconciliation, audit and export tests. Fixtures match the attendance columns
used by the application. No production Neon credentials were available and no
production database was read or changed. The read-only preflight must be run on
the actual staging schema and representative existing records before enabling.

QR endpoints default to disabled. Enable QR_ATTENDANCE_ENABLED=true only after
explicitly approved database migration and staging acceptance. The SQL is not
registered in automatic application startup migrations.

GitHub GraphQL API access returned Forbidden in this environment. Git branch/PR
refs can be read and the feature branch can be pushed. PR description update text
will be kept in this branch if API access remains unavailable. Do not merge main
or deploy this feature before Flutter checks and actual Neon staging validation.
