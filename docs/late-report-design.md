# Late report presentation

Late Report now follows the compact reference layout: clock-icon heading,
responsive top toolbar, navy PDF action, lightly tinted metric cards with subtle
waves, pill filters and a separate search field. The employee table stretches to
the available width, uses a navy header and compact separated rows, and adds row
numbers, employee photos/initials, branch badges, severity/review pills and action
icons. Small screens retain horizontal table scrolling and stacked controls.

View and review actions open the existing event detail panel; the green check is
not an immediate approval. Actual review still uses the existing reason/status
form and save handler. Calendar opens the read-only attendance sheet for the row's
employee and selected payroll month. More actions offers the same operations.
Month arrows, month selection, branch/search/severity filtering, refresh, event
history and PDF/Excel exports remain connected to the existing handlers.

The existing employee metadata query additionally returns photo URL, address and
department for the affected report rows. The address is needed by the read-only
attendance print calculator; no photo bytes or salary data are added to the late
report query. Attendance totals, review rules and database writes are unchanged.

Dart formatter/parser and diff checks passed. All 26 existing backend late-report
tests passed. Added a Flutter regression test verifying the new review action
opens details without saving/approving anything. Flutter execution is unavailable
in this workspace. Deploy the backend for employee photo metadata and rebuild
Flutter web to apply the visual changes.
