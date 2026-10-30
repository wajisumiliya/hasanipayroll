# Modern admin dashboard

The selected **B — Ivory & Champagne** design is implemented for the admin portal.
Warm ivory backgrounds, white softly elevated panels, charcoal text, champagne
accents, and a dark espresso sidebar replace the earlier blue treatment.
Desktop uses a 232 px sidebar and white account header. Below 850 px the full
navigation moves into a matching drawer, with Home, Attendance, Payroll, and
More available in bottom navigation. Employee and branch portal themes are
unchanged. The existing Hasani Books logo is used.

The overview includes reporting month/year and branch controls and an always-visible
three-column/two-row desktop library for Payroll, EPF, SOCSO, EIS, HRDF, and Payroll
Summary. Cards retain independent preview/export handlers and official agency marks.
Payroll shows net payroll; Payroll Summary shows gross payroll; EPF, SOCSO, and EIS
show the selected records' employee-plus-employer totals. HRDF shows its existing
1% levy rate and links to the eligibility/levy report, without inventing a total.
Below the library, the desktop left column contains a grouped workforce snapshot,
payroll comparison, and Late Report preview. The right column contains attendance,
admin approvals, and celebrations.
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

### Detailed analytics

The dashboard now reads eight saved payroll months from the authenticated Neon
admin overview API. Missing months show “No saved payroll”; they are not zero
points or interpolated history. The selected month and branch apply to payroll
composition, salary comparisons and branch totals. Each saved trend month opens
an employee breakdown. Salary comparisons require an employee record in both
adjacent months, use the existing base-pay calculation and distinguish saved
base changes from approved increments. Payroll net is derived from the existing
gross calculation minus the eight itemised employee deduction fields.

Attendance is explicitly today's Malaysia date, independent of the payroll
selector. Missing attendance stays unavailable. Not checked in is not absence;
late uses recorded status, and off/leave includes rest days. Branch monitoring
shows total and active employees, gross/net, today's unique active check-ins and
saved payroll record counts. Distribution includes all scoped employee records,
including inactive staff, and lists every branch rather than truncating to five.

HRDF displays the calculated one-percent eligible levy base using the same
exclusions and attendance deductions as the existing HRDF report. Payroll,
summary and HRDF previews now read Neon rather than requesting all Supabase
payroll history, and honour the selected branch. Existing statutory report and
export actions remain available.
