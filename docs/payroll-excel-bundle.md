# Payroll Excel selection dialog

RHB Layout opens Generate Payroll Excel Files with the original Hasani Books
logo, Month then Year selectors, and a pale blue panel containing Branch Payroll,
RHB Layout, EPF, SOCSO, EIS and HRDF checkboxes. All seven start selected. Generate Selected
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

Payroll Summary PDF is also selectable in the RHB dialog. It opens the existing
print/save PDF preview for the selected month. Its bottom reconciliation shows
original EPF/SOCSO/EIS totals (employee plus employer), less amounts belonging to
employees missing registration numbers, and net payable. EPF uses EPF/ KWSP
number; SOCSO and EIS use SOCSO number. Empty, dash, N/A, NA, NULL and zero are
treated as missing. Original branch totals and saved payroll net pay stay intact.
