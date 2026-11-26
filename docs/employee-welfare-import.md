Employee welfare in annual Payslip Summary

Deploy the backend and rebuild Flutter web. Backend startup creates the private
employee_welfare table automatically. No payroll or employee data is changed.

Open Employee Payslips > Payslip Summary > Import Welfare Excel. Select the
original welfare workbook or the updated workbook. The first worksheet must have
Date, EMPLOYEE_CODE, NAME, Particulars (Purticulars is accepted), and Amount.
Ref 1 and Project are retained when present. Maximum workbook size is 1 MB.

Review the ready and pending counts, then import the matched entries. Employee
codes take precedence. A missing code can match only one exact employee name
(case and repeated whitespace are ignored). Similar names and ambiguous matches
stay pending. Missing amounts stay pending rather than becoming zero. The
import preview validates against the live employee list and the administrator's
payroll scope, including historical/inactive employees.

Choose the employee and year. Welfare dates show DD/MM/YYYY; saved payroll bonuses
continue to identify the payroll month. Both appear in the Welfare/Gift/Bonus
section of the screen, PDF, and Excel. Welfare-only years are selectable.

Identical repeat uploads are skipped. Existing imported transactions are not
overwritten. Correcting an already imported transaction needs a separate
correction rather than importing another financial amount as a new transaction.
Rows without a match can be completed in the workbook and uploaded again.

The workbook is uploaded to an authenticated payroll-admin endpoint. It is not
bundled into public web assets or committed to the repository.
