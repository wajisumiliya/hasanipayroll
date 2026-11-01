// Read-only monetary inputs for attendance PDFs. Branch users are authorized
// against the employee's server-side branch before any salary data is read.
export function installAttendancePrintContextApi(app, {authenticate, pool}) {
  app.get('/api/attendance-sheet/print-context', authenticate, async (req, res) => {
    const role = String(req.user?.role ?? '').trim().toUpperCase();
    if (!['ADMIN', 'BRANCH'].includes(role))
      return res.status(403).json({ok:false,message:'Attendance printing is available to admin and branch users.'});
    const employeeId = String(req.query.employee_id ?? '').trim();
    const year = Number(req.query.year), month = Number(req.query.month);
    if (!employeeId || employeeId.length > 100 || !Number.isInteger(year) || year < 2000 || year > 2100 ||
        !Number.isInteger(month) || month < 1 || month > 12)
      return res.status(400).json({ok:false,message:'Invalid attendance print selection.'});
    try {
      const employees = await pool.query('SELECT employee_id, branch_id FROM public.employees WHERE employee_id=$1 LIMIT 1', [employeeId]);
      const employee = employees.rows[0];
      if (!employee) return res.status(404).json({ok:false,message:'Employee not found.'});
      const branchId = String(employee.branch_id ?? '').trim();
      const userBranch = String(req.user.branchId ?? req.user.branch_id ?? '').trim();
      if (role === 'BRANCH' && (!branchId || !userBranch || branchId.toUpperCase() !== userBranch.toUpperCase()))
        return res.status(403).json({ok:false,message:'Branch access denied.'});
      const [salary, payroll, rosters] = await Promise.all([
        pool.query('SELECT basic_salary, address, epf_category, eis_applicable FROM public.employee_salary_defaults WHERE employee_id=$1 LIMIT 1', [employeeId]),
        pool.query(`SELECT overtime, late_deduction, unpaid_deduction FROM public.payroll
          WHERE employee_id=$1 AND period >= make_date($2,$3,1)
            AND period < (make_date($2,$3,1) + INTERVAL '1 month')`, [employeeId,year,month]),
        pool.query(`SELECT to_jsonb(r) AS data FROM public.monthly_rosters r
          WHERE employee_id=$1 AND LOWER(TRIM(branch_id))=LOWER(TRIM($2))
            AND roster_year=$3 AND roster_month=$4 ORDER BY week_number`, [employeeId,branchId,year,month]),
      ]);
      if (payroll.rows.length > 1)
        return res.status(409).json({ok:false,message:'Duplicate payroll records require admin review before printing.'});
      return res.json({ok:true,branch_id:branchId,salary:salary.rows[0] ?? null,
        payroll:payroll.rows[0] ?? null,monthly_rosters:rosters.rows.map(row=>row.data)});
    } catch (error) {
      console.error('ATTENDANCE PRINT CONTEXT ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Attendance print values are temporarily unavailable.'});
    }
  });
}
