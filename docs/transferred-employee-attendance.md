# Attendance sheets after transfer

Individual employee-month attendance sheets now load by employee ID and month,
after the backend authorizes access against the employee's current branch.
This includes rows recorded under previous branches in the same month. Historical
branch IDs, submitted flags and attendance values are returned without mutation.
Branch-wide attendance listings retain their existing scope. Former/unrelated
branches cannot use the employee-specific lookup after transfer. Employee users
can read only their own sheet; admins retain their existing access.

The new endpoint is /api/attendance/employee-month. Deploy the backend and rebuild
Flutter web together. No migration or resubmission of historical attendance is
required. Existing sheet submission locks still apply to the returned rows.
Historical roster selection and payroll calculations are unchanged.

Related Node checks: 16 passed, one optional database integration check skipped.
Dart parser/format and backend syntax checks passed. Flutter execution needs local
verification. No production attendance was accessed or modified during this fix.
