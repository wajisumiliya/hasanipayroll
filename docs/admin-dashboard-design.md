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
composition. Each saved trend month opens an employee breakdown. Payroll net
is derived from the existing gross calculation minus the eight itemised employee
deduction fields.

Salary analytics, attendance monitoring, branch monitoring and branch
distribution are removed from the dashboard at the user's request. Payroll
reports and More management tools render their contents directly, without
collapsible wrappers. The separate detailed payroll breakdown remains expandable.

HRDF displays the calculated one-percent eligible levy base using the same
exclusions and attendance deductions as the existing HRDF report. Payroll,
summary and HRDF previews now read Neon rather than requesting all Supabase
payroll history, and honour the selected branch. Existing statutory report and
export actions remain available.

The saved gross payroll trend is displayed as eight coloured vertical bars,
with month labels, exact RM values, and an amount axis. It scrolls horizontally
on narrow cards to keep labels readable. Missing months have no bar. Clicking a
saved month continues to open its employee breakdown. Country flags, the live
clock, and the five workforce category cards now sit under the top dashboard
controls, above the KPI row. They reuse the original employee-list callbacks
and selected-branch counts; the detailed payroll panel no longer duplicates them.

The duplicated payroll sections are replaced with the four supplied activity
cards, preserving the reference's two-column arrangement, circular category icons,
colour themes, four summary tiles, table headings, row badges and footer bars.
On narrow screens the cards stack and their record rows scroll horizontally.

Attendance Late includes employees with at least three recorded late arrival
days in the selected payroll month. Each compact employee row is clickable and
shows days and total late hours. Detail lists the arrival dates, scheduled start,
actual check-in and minutes; excess breaks never inflate late-arrival hours.
Summary late days and late rate describe the listed threshold group; total
employees is the active branch/staff scope. Missing timings remain unavailable.

Increment List now reads maintained inc_details schedules from the authenticated
Neon dashboard API's employee_salary_defaults join. A valid positive scheduled
increment matching the selected payroll month identifies eligibility without
requiring generated payroll. Inactive and out-of-scope employees are excluded.
Existing increment amount validation (RM50–1000 in RM50 steps) is retained.
Effective is a scheduled month, not an invented exact approval date. Average
percentage remains unavailable unless all eligible employees have a saved prior
payroll baseline. Deploy the backend along with the new Flutter web build.

Birthdays and work anniversaries use Malaysia's current date, today through five
days ahead, regardless of the payroll selector. The window crosses month/year
boundaries and clamps February 29 to the last day of February in other years.
Only active scoped employees are listed, and service years must be completed.
The event summary's This Week/This Month counts are subsets of this same window.
Calendar chips on these two cards display the current month, without changing
the required five-day window. View All uses the same record filters.
