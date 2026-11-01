// Historical payroll amounts remain available for trends and increment checks.
// Large generated remarks are needed only for the selected month's editor.
export const dashboardPayrollQuery = `SELECT
  CASE WHEN p.period >= make_date($1,$2,1) THEN to_jsonb(p)
       ELSE to_jsonb(p) - 'remarks' END AS row,
  p.period >= make_date($1,$2,1) AS selected
  FROM public.payroll p
  WHERE p.period >= (make_date($1,$2,1) - INTERVAL '7 months')
    AND p.period < (make_date($1,$2,1) + INTERVAL '1 month')
  ORDER BY p.employee_id ASC`;

// Preserve frequencies used for payroll branch attribution without transferring
// 28–31 copies of the same employee/branch pair over the database connection.
export const payrollAttendanceQuery = `SELECT employee_id, branch_id, COUNT(*)::int AS attendance_count
  FROM public.attendance
  WHERE attendance_date >= make_date($1,$2,1)
    AND attendance_date < (make_date($1,$2,1) + INTERVAL '1 month')
  GROUP BY employee_id, branch_id`;

// Keep the established Flutter response shape, including for clients already
// deployed. Only the database wire representation is grouped.
export function expandAttendanceCounts(rows) {
  return rows.flatMap(({employee_id,branch_id,attendance_count}) =>
    Array.from({length:Number(attendance_count)},()=>({employee_id,branch_id})));
}
