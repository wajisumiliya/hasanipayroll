# Monthly Late Report

Open **Admin → Attendance → Late Report**. The selected attendance month is
carried into the report. Month arrows, the branch selector, and Refresh update
the view. Expand an employee to inspect events and review them individually.

## Counting and severity

The report includes employees with **at least three occurrences per branch**:

- One occurrence per arrival after the scheduled start, with no grace period.
- One occurrence per day whose total recorded breaks exceed the allocated daily
  allowance. Several break periods on one day are summed, not counted individually.
- Both may count on the same date. Two late arrivals and two exceeded break days
  count as four occurrences, including when they fall on two dates.

Summary cards show flagged employees, their arrival and break occurrences, and
excess minutes. Totals apply to the selected branch/month and flagged employees
only. Severity is Low (yellow, 3–4), Medium (orange, 5–6), or High (red, 7+), with
text labels as well as colour. Detail rows show the date, scheduled/actual arrival,
allowed/actual break duration, and excess minutes. Exactly the allowance does not
count. Break excess minutes exclude the permitted portion of the break.

Monthly comparisons use the same employee's recorded branch in the previous
calendar month, including previous totals below the three-occurrence threshold.
January correctly compares the previous December. The current month may still
be in progress. Comparisons reflect saved attendance, not guaranteed complete
submissions.

## Rosters and incomplete data

Daily roster assignments override the existing weekly/monthly roster convention
(days 1–7 are week 1, 8–14 week 2, etc.). OFF, leave, and public-holiday statuses
follow the attendance sheet's non-working-day rules. Recorded break pairs
(morning, afternoon, and the evening/OT break column) take precedence over the
stored daily total. Legacy rows without pairs use `break_minutes`. Overnight
break periods and shifts are supported.

Independently measurable events still count: an incomplete break does not suppress
a known late arrival. Unknown values are not assumed to be zero. Incomplete current
or previous records are not listed on the screen, sent in the report response,
or included in exports.

## Admin reviews and audit history

Review each event with a status (Reviewed, Approved, Correction required, Pending),
a category (Transport delay, Approved late arrival / break, Incorrect attendance,
Other), and a required 3–1000 character note. The server records the authenticated
reviewer's identity and timestamp. Times display as Malaysia time (MYT / UTC+8).

Each save appends a new audit entry with the exact attendance timing snapshot;
no API overwrites or deletes old reviews. Review history shows every revision.
Changed arrival/break timings invalidate an earlier review and show **Needs
re-review**. Saving a stale event is rejected; refresh before reviewing again.
Approval or correction flags do **not** remove occurrences, edit attendance,
make deductions, or send messages. Correct attendance separately if appropriate.

## Exports

PDF and Excel export only flagged employees for the selected month and branch.
They include summaries, severity, previous counts, detailed event timings,
current reviews/reasons, reviewer names/times, and review history. There are no
incomplete-record sections or sheets. Excel has Summary, Events, and Review
history sheets; strings are literal values, not formulas. PDF supports multiple
pages, page numbers, and bundled fonts without a font-network request.

Generation runs in a Node worker thread using PDFKit and ExcelJS, not in Flutter
or the HTTP event loop. Only filtered report data reaches the worker. Up to two
workers run concurrently, with a 30-second deadline and a 256 MB heap limit per
worker. Errors/timeouts release capacity and the app re-enables export buttons.
The client asynchronously downloads the completed file through its authenticated
API and saves it using the existing file-save flow. Month/branch navigation stays
available while the export runs; the file retains the selection at click time.

## API and deployment

- `GET /api/attendance/late-report?year=2026&month=10`
- `GET /api/attendance/late-report/export?year=2026&month=10&format=pdf`
  (format is pdf or xlsx; optional branch_id restricts to one branch).
- `POST /api/attendance/late-report/reviews` with branch_id, employee_id, date,
  type, fingerprint, status, reason_code, reason.

All endpoints require an authenticated ADMIN with attendance access; employee,
branch, reviewer-preview, and requests-only accounts receive HTTP 403 before queries. Recorded branches preserve historical
locations when employees transfer. Saved attendance includes submitted and
unsubmitted rows and does not omit inactive employees' historical events.

Deploy backend and client together. Backend startup applies the idempotent
`20261026_late_report_reviews.sql` migration through the existing schema-version
runner. The private review table is inaccessible to public/anon/authenticated
Data API roles and is not in the public table allowlist. No external service,
new credential, or scheduled job is required. A web deployment updates the browser
UI; Android needs a client release for the new screen.

### Dashboard late-attendance summary print

The dashboard card includes Print PDF beneath the employee flash cards. It opens
the system/browser print dialog with an A4 landscape Hasani Payroll attendance
summary: employee ID/name, branch, payroll month, accumulated main late time,
arrival count, accumulated excess-break time, break count, totals and notes.
Count columns are pink, the header is navy, and each page repeats the heading.
The first-five preview does not limit the PDF: all qualifying arrival-count >=3
rows within the selected branch and displayed employee/staff scope are exported.
The existing combined-occurrence report and its Excel/PDF exports remain separate.

The authenticated export endpoint accepts view=attendance-summary with format=pdf
and an optional JSON employees selection (bounded to 1000 IDs). It generates the
summary in the existing worker queue with time/heap/concurrency limits. The UI
shows a busy state, permits navigation and reports failures without freezing.

Saved Late / Late + Early Out statuses now retain arrival occurrences even where
legacy daily/monthly rosters or check-in times are unavailable. Such events have
unknown minutes, never a guessed shift or zero duration. The card/PDF show a dash
for unknown accumulated time and the PDF explains it. Known roster timings still
take precedence. No roster is borrowed from another branch. The underlying query
continues to load the whole selected month across all branches. Preview rows now
show their branch and the card note states preview/full employee and branch counts.
Production branch counts require verification after deploying the backend and web.

### Combined dashboard threshold and absence reports

The dashboard card, full list and summary PDF now consistently include employees
with main late arrivals + over-allocated-break occurrences >= 3. Examples 2+1,
1+2, 0+3 and 3+0 all qualify; 1+1 does not. Two different issue types on one date
count as two occurrences, so the tile now says Total Occurrences, not Late Days.
Rows show the combined count with separate main/break counts and separate minutes.
Clicking an employee includes both arrival and break timing details. Unknown legacy
main durations remain unavailable; they are never presented as zero minutes.

MC Report and Unpaid Report buttons sit beside Print PDF. Each opens a selected
month/branch/staff-scope list with employee ID/name, branch, day count and dates,
and a Print PDF action. MC/medical-leave statuses and unpaid/unpaid-leave statuses
or explicit saved is_unpaid flags drive these lists. Counts deduplicate dates per
employee/branch. No leave or payroll records are created or changed.

GET /api/attendance/status-report requires administrator authentication, validates
period/status/branch/employee selections and enforces restricted staff scopes.
The PDF uses the existing limited background worker service. Deploy the backend
and rebuild Flutter web together. Automated backend tests cover all four threshold
combinations, invalid/unauthorized status requests, scope, distinct dates and PDFs.
