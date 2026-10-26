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
be in progress; missing previous records are listed separately, not treated as
proof of improvement. Comparisons reflect saved attendance, not guaranteed
complete submissions.

## Rosters and incomplete data

Daily roster assignments override the existing weekly/monthly roster convention
(days 1–7 are week 1, 8–14 week 2, etc.). OFF, leave, and public-holiday statuses
follow the attendance sheet's non-working-day rules. Recorded break pairs
(morning, afternoon, and the evening/OT break column) take precedence over the
stored daily total. Legacy rows without pairs use `break_minutes`. Overnight
break periods and shifts are supported.

Incomplete-record sections identify the employee, branch, date, and precise
issues: missing roster, invalid/missing shift start, break allowance, check-in,
break duration, or an unmatched break start/end. Independently measurable events
still count: an incomplete break does not suppress a known late arrival. Unknown
values are never assumed to be zero. Completely blank, non-working days are not
invented as missing records. This reports incomplete **saved rows**, not entirely
absent attendance dates. Complete records in Attendance/Roster, then refresh.

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

PDF and Excel export the selected month and branch. They include summaries,
severity, previous counts, detailed event timings, current reviews and reasons,
reviewer names/times, review history, and incomplete current/previous records.
Excel has Summary, Events, Incomplete records, and Review history sheets. Values
and notes are written as literal cells, never evaluated as formulas. PDF supports
multiple pages with repeated table headings and page numbers; bundled fonts
support Latin names and typographic punctuation without a font network request.

## API and deployment

- `GET /api/attendance/late-report?year=2026&month=10`
- `POST /api/attendance/late-report/reviews` with branch_id, employee_id, date,
  type, fingerprint, status, reason_code, reason.

Both endpoints require an authenticated ADMIN with attendance access; employee,
branch, reviewer-preview, and requests-only accounts receive HTTP 403 before queries. Recorded branches preserve historical
locations when employees transfer. Saved attendance includes submitted and
unsubmitted rows and does not omit inactive employees' historical events.

Deploy backend and client together. Backend startup applies the idempotent
`20261026_late_report_reviews.sql` migration through the existing schema-version
runner. The private review table is inaccessible to public/anon/authenticated
Data API roles and is not in the public table allowlist. No external service,
new credential, or scheduled job is required. A web deployment updates the browser
UI; Android needs a client release for the new screen.
