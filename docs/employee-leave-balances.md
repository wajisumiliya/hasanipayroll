# Employee AL and MC balances

Admin Employees > Edit > Leave Balances maintains annual_leave_balance (AL) and
medical_leave_balance (MC), in days, with up to two decimal places. Blank/NULL
means not uploaded and is not equivalent to zero. Both values must be non-negative
and below 10000. These are manually maintained balances; this change does not
apply automatic leave deductions, accrual, carry-forward or annual resets.

The employee dashboard displays only AL, including when no payroll exists. MC
is not included in the employee UI/model, login/profile payload, employee reads,
branch employee/payroll payloads or non-admin generic employee projections.
Non-admin generic writes cannot alter either balance; normal RLS remains active.

## Initial upload

1. Deploy the backend or run backend/migrations/20261031_employee_leave_balances.sql
   in the Neon SQL editor to add the nullable columns and checks. The startup
   migration is idempotent and does not populate or reset existing balances.
2. Open docs/sql/upload-employee-leave-balances.sql. Replace the placeholder IDs
   and example day values with your actual records, then run the full script.
   It checks duplicate/missing IDs and rolls back the transaction on failure.
3. Rebuild/deploy Flutter web. Refresh the employee app to load its current AL.

Do not execute the upload template with unchanged placeholder IDs. SQL uploads
and edits only update employee balance fields; attendance status reports and
payroll amounts are independent.

Backend tests check migration registration, MC redaction and generic read/write
boundaries. Flutter tests cover null/zero/decimal AL values, cached model round
trips and an AL-only card. Flutter runtime verification requires an available SDK.

MC reports now treat the MC entry as an opening balance tied to an opening month,
not a repeatedly decremented number. Edit Employee includes MC opening month
(YYYY-MM). Previously uploaded non-null MC values are anchored to October 2026
as confirmed by the user. Future uploads must specify their intended opening
month; the bulk template now includes it. Opening history is private and retained
per month. MC usage is derived from saved attendance when reporting, including
carry-forward; opening - taken = closing. Reprinting does not alter stored values.
AL stays manually maintained and remains the only employee-dashboard balance.
