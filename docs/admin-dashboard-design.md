# Modern admin dashboard

The approved navy-and-white dashboard is implemented for the admin portal.
Desktop uses a 232 px sidebar and white account header. Below 850 px the full
navigation moves into a matching drawer, with Home, Attendance, Payroll, and
More available in bottom navigation. Employee and branch portal themes are
unchanged. The existing Hasani Books logo is used.

The overview includes reporting month/year and branch controls, always-visible
individual Payroll, EPF, SOCSO, EIS, HRDF, and Payroll Summary report cards with
their original preview/export handlers and logos, followed by four workforce
cards, payroll totals and comparison bars, an attendance ring, a five-row Late
Report preview, pending admin approvals, and upcoming birthdays/anniversaries.
It becomes one column on narrow screens; metric cards become a two-by-two grid,
and Late Report rows become compact employee cards. Tests cover 320, 768, and
1440 px widths. Month/year selection is grouped in a reporting-period dialog.

Payroll retains the existing calculation and branch attribution rules. Statutory
contributions, detailed payroll drill-downs, and tools remain available under
Detailed payroll breakdown, More management tools, and the complete sidebar.
The report export shortcut opens the existing Reports workflow. Payroll, reports,
and payslip shortcuts carry the selected dashboard month. Existing celebration
notifications still require the existing explicit confirmation dialog.

Workforce totals use the selected attendance branch and the current admin's
existing staff scope. Today's attendance is fetched for the Malaysia calendar
date, independently of the selected payroll month. Check-ins are validated and
deduplicated by employee. Present excludes saved Late statuses; Late, Not checked
in, and saved Off/leave records are separate, non-overlapping ring segments.
Not checked in is a check-in status, not an absence or disciplinary judgment.
Pending leave and overtime counts include pending_admin only; new employee
requests include PENDING. Local/foreign staff scopes remain filtered.

Live activity calls use the existing authenticated Neon/data APIs. Results are
cached per reporting month, Malaysia day, and admin scope. Branch changes filter
those snapshots locally; repeated widget rebuilds do not refetch them. Refresh
and service updates reload the snapshots. Failed activity sources show dashes or
an unavailable message, not false zero counts, and do not block payroll data.

Late Report is accessible directly from admin navigation and its overview card.
Its embedded view retains the selected reporting month and matching branch,
refresh, reviews, and background PDF/Excel exports. No incomplete-record panels
are reintroduced. No schema, payroll calculation, or release-signing changes
are required for this design.
