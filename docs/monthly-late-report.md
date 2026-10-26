# Monthly Late Report

Open **Admin → Attendance → Late Report**. The selected attendance month is
carried into the report; month arrows, the branch selector, and Refresh update
the view. Expand an employee to inspect all qualifying events in that month.

The report includes employees with **at least three occurrences per branch**:

- One occurrence per arrival after the scheduled start, with no grace period.
- One occurrence per day whose total recorded breaks exceed the allocated daily
  break allowance. Several break periods on one day are summed, not counted
  individually.
- Both may count on the same date. Two late arrivals and two exceeded break days
  therefore count as four occurrences, including when they fall on two dates.

Details show dates, scheduled/actual arrival, allowed/actual break minutes, and
minutes late or over allowance. Summary minutes add arrival delays and break
excess, not all time spent on breaks. Exactly the allowed break time does not count.

Daily roster assignments override the existing weekly/monthly roster convention
(days 1–7 are week 1, 8–14 week 2, etc.). OFF, leave, and public-holiday statuses
follow the attendance sheet's non-working-day rules. Recorded break pairs
(morning, afternoon, and the evening/OT break column) take precedence over the
stored daily break total; legacy records without pairs use `break_minutes`.
Overnight break periods and overnight shifts are supported. Records with missing
shift or allowance details are flagged and excluded instead of assuming a shift.
Complete those rosters and refresh before treating the report as complete.

The read-only `/api/attendance/late-report?year=2026&month=10` endpoint requires
an authenticated ADMIN role. Employee and branch accounts receive HTTP 403.
It uses recorded attendance branches, so a later employee transfer does not
reassign historical occurrences. It includes saved attendance, whether or not
submitted; no employee activity status filter removes historical records.
No deductions, attendance edits, notifications, schema changes, or scheduled jobs
are performed by this report.

Deploy the backend and Flutter client together for this new endpoint and screen.
A web deployment supplies the browser UI; an Android release is needed for the
new screen in the native application.
