# Payroll Excel selection dialog

RHB Layout opens Generate Payroll Excel Files with the original Hasani Books
logo, Month then Year selectors, and a pale blue panel containing Branch Payroll,
RHB Layout, EPF, SOCSO, EIS and HRDF checkboxes. All six start selected. Generate Selected
Files exports only those chosen, disables when empty, and locks choices while busy.

Branch Payroll uses the existing formatted all-branches payroll workbook; the
other choices use the existing statutory/HRDF report exporters. Inputs are saved
payroll for the selected month. Files are built before downloads start, then saved
as separate XLSX files. Allow multiple downloads in the browser. No ZIP is made.
Individual RHB bank-format exports elsewhere remain available with their existing
bank columns. No payroll or database values are modified.

Dart parse/format and diff checks pass. The dialog test verifies selected-file
capture and duplicate-action prevention. Flutter tests require local execution.
Rebuild web after pulling to see the updated dialog.

RHB Layout uses the existing bank export with `only: rhb` and produces one
SALARY workbook per eligible branch, retaining bank columns, account exclusions,
net amounts and branch filenames. These are separate from Branch Payroll and are
collected before saving any selected file.
