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
