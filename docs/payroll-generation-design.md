# Generate Payroll selection design

Generate Payroll uses the original Hasani Books logo, cream/navy/gold styling,
numbered payroll-period/file/branch sections, selectable branch tiles and live
branch/employee counts. The period fields select month/year; file choices are
Branch Payroll, EPF, SOCSO, EIS and HRDF. Active employees are counted and branches
with no eligible employees are disabled. The dialog adapts to narrower screens.

Generate captures a copy of the selected branch IDs, month and file types, then
opens the existing employee readiness screen across those branches. Employees
with missing submissions remain blocked unless attendance-exempt under existing
rules. Existing employee selection, overwrite option and final generation
confirmation remain mandatory. Selection checkboxes alone do not write payroll.

After the result screen, selected files are built from successfully generated
employee IDs only. Branch Payroll reuses the formatted payroll workbook exporter;
EPF/SOCSO/EIS reuse existing statutory layouts; HRDF reuses its existing summary
and levy calculations. The files are collected in one ZIP to avoid browser
multiple-download blocks. Empty generation results do not export unrelated
payroll. File generation failures report that payroll was saved rather than
presenting them as a payroll rollback/failure. A blocking progress dialog keeps
the captured month stable during exports. Existing standalone exports retain
their normal download behavior when no file-collection callback is supplied.

No backend/migration or payroll-calculation change is introduced. Employee/branch
read scope remains authenticated. New scoped report parameters filter the saved
month to generated employee IDs; HRDF's interactive dashboard branch filter is
ignored only when an explicit employee-ID set is supplied. Other report callers
keep their existing filters.

Dart formatter/parser and diff checks passed. Flutter widget tests cover branch/
file selection capture and disabled generation with no selected branches. Flutter
execution is unavailable in this workspace; run tests locally/CI and rebuild
Flutter web to apply this design and workflow.

## Employee readiness dialog

The follow-on employee selector now uses the same cream/navy design and original
Hasani Books header, with month/branch/employee information tiles, readiness banner,
All/Ready/Follow-up/Submitted filters, ID/name search and a compact white list.
Staff exemptions appear as management/temporary/support badges. Submitted means
at least one submitted day; it does not bypass the complete-attendance readiness
requirement. Follow-up employees retain their expandable missing-day explanation
and cannot be checked for generation.

Select all visible employees applies only to ready IDs in the current filtered
results; deselecting them preserves hidden selections. The footer shows selected
employee count, Cancel and Generate Payroll. The replace-existing option is in a
separate tinted panel. Existing overwrite confirmation, exemption rules and payroll
writes are unchanged. Small screens use an outer scroll area and bounded employee
list so the additional controls remain reachable.

Selection helper tests cover incomplete submitted attendance being unselectable,
hidden selection retention, and ID/name filtering. Dart formatter/parser checks
pass; Flutter tests still need local/CI execution. Rebuild Flutter web to apply.
