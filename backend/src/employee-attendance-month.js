// Employee sheets follow the employee after transfer; branch lists retain their
// historical branch filter. Authorize the current employee before reading rows.
export function installEmployeeAttendanceMonthApi(app, {authenticate, pool}) {
  app.get('/api/attendance/employee-month', authenticate, async (req, res) => {
    const role = String(req.user?.role ?? '').trim().toUpperCase();
    if (!['ADMIN', 'BRANCH', 'EMPLOYEE'].includes(role))
      return res.status(403).json({ok:false,message:'Access denied.'});
    const employeeId = String(req.query.employee_id ?? '').trim();
    const year = Number(req.query.year), month = Number(req.query.month);
    if (!employeeId || employeeId.length > 100 || !Number.isInteger(year) || year < 2000 || year > 2100 ||
        !Number.isInteger(month) || month < 1 || month > 12)
      return res.status(400).json({ok:false,message:'Invalid attendance selection.'});
    if (role === 'EMPLOYEE' && employeeId !== String(req.user.employeeId ?? req.user.employee_id ?? '').trim())
      return res.status(403).json({ok:false,message:'Access denied.'});
    try {
      const result = await pool.query('SELECT employee_id, branch_id FROM public.employees WHERE employee_id=$1 LIMIT 1', [employeeId]);
      const employee = result.rows[0];
      if (!employee) return res.status(404).json({ok:false,message:'Employee not found.'});
      const branch = String(employee.branch_id ?? '').trim().toUpperCase();
      const userBranch = String(req.user.branchId ?? req.user.branch_id ?? '').trim().toUpperCase();
      if (role === 'BRANCH' && (!branch || !userBranch || branch !== userBranch))
        return res.status(403).json({ok:false,message:'Branch access denied.'});
      const rows = await pool.query(`SELECT to_jsonb(a) AS data FROM public.attendance a
        WHERE a.employee_id=$1 AND a.attendance_date >= make_date($2,$3,1)
          AND a.attendance_date < (make_date($2,$3,1) + INTERVAL '1 month')
        ORDER BY a.attendance_date`, [employeeId,year,month]);
      return res.json({ok:true,attendance:rows.rows.map(row=>row.data)});
    } catch (error) {
      console.error('EMPLOYEE ATTENDANCE MONTH ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Attendance is temporarily unavailable.'});
    }
  });
}
