# Employee Payslips directory

Employee Payslips follows the supplied cream/navy reference and uses the original
Hasani Books asset. Four metric cards display total employee, active/inactive and
all-period payslip counts. Month/year, branch/status and name/ID/IC search controls
sit above Employee List, Payslip History and Payslip Summary tabs. The employee
grid is replaced by a navy-header table with photos, employee IDs, branch/status
pills, all-period counts, View/Payslips actions and ten-row numbered pagination.
Only the current page's employee photos are built. Narrow screens scroll tables
horizontally and wrap the toolbar.

Employee List keeps full historical counts, matching the reference, even when a
summary period is chosen. Payslip Summary uses the selected month/year and excludes
employees without a record in that period. History reuses the existing year-wise
payslip view, including individual viewing/printing and publication controls.
View retrieves the authenticated employee record on demand; no new backend query
or privilege is introduced. The original active-default status preference is
retained. Changing search/branch/status clears the selected history employee.

Excel/PDF export captures the current filtered list/history/summary, across all
pages. Directory counts are labelled all periods; history exports use the chosen
year; summary exports contain the selected month. PDF exports include the original
Books logo. These are reports of the displayed view, not a replacement for the
existing individual payslip printing actions. Duplicate export clicks are blocked.
All values come from existing employee/payroll data; no payroll is generated or
published by the redesign.

Dart formatter/parser and diff checks passed. Flutter widget tests cover ten-row
pagination and selected-month summary filtering. Flutter execution is unavailable
in this workspace; run locally/CI and rebuild Flutter web to apply the page.
