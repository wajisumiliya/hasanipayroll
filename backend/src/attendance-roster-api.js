import {withCanonicalBranchId} from './attendance-batch.js';

export function installAttendanceRosterApi(app, {authenticate,pool}) {
app.post("/api/attendance-sheet/rosters", authenticate, async (req, res) => {
  const role = String(req.user?.role ?? "").toUpperCase();
  if ((role === "ADMIN" && (req.auth?.app_metadata?.is_reviewer || req.auth?.app_metadata?.staff_scope === 'requests')) || !["ADMIN", "BRANCH"].includes(role)) return res.status(403).json({ok:false,message:"Access denied."});
  const rows = req.body?.rosters;
  if (!Array.isArray(rows) || !rows.length || rows.length > 31) return res.status(400).json({ok:false,message:"Invalid roster rows."});
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    for (const row of rows) {
      const employeeId = String(row?.employee_id ?? "").trim();
      const date = String(row?.roster_date ?? "");
      if (!employeeId || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        await client.query("ROLLBACK");
        return res.status(400).json({ok:false,message:"Invalid employee or date."});
      }
      const employee = await client.query("SELECT branch_id FROM public.employees WHERE employee_id=$1 LIMIT 1",[employeeId]);
      if (!employee.rows.length) { await client.query("ROLLBACK"); return res.status(404).json({ok:false,message:"Employee not found."}); }
      const branchId = String(employee.rows[0].branch_id ?? "").trim();
      if (role === "BRANCH" && branchId.toLowerCase() !== String(req.user.branchId ?? req.user.branch_id ?? "").trim().toLowerCase()) {
        await client.query("ROLLBACK");return res.status(403).json({ok:false,message:"Branch access denied."});
      }
      if (role === 'BRANCH') {
        const attendance = await client.query('SELECT is_submitted FROM public.attendance WHERE employee_id=$1 AND attendance_date=$2::date FOR UPDATE', [employeeId,date]);
        if (attendance.rows.some(item => item.is_submitted === true)) {
          await client.query('ROLLBACK');
          return res.status(403).json({ok:false,message:'Submitted rosters can only be corrected by admin or account users.'});
        }
      }
      // The employee row is authoritative; client branch values can be stale
      // or formatted differently for different branches.
      const trustedRow = withCanonicalBranchId(row, branchId);
      const allowed = ["branch_id","employee_id","roster_date","assignment_type","shift_start","shift_end","break_minutes","updated_at"];
      const fields = allowed.filter(k=>Object.hasOwn(trustedRow,k));
      const values = fields.map(k=>trustedRow[k]);
      const placeholders = fields.map((_,i)=>"$"+(i+1));
      const update = fields.filter(k=>!["branch_id","employee_id","roster_date"].includes(k)).map(k=>k+"=EXCLUDED."+k).join(",");
      await client.query("INSERT INTO public.daily_rosters ("+fields.join(",")+") VALUES ("+placeholders.join(",")+") ON CONFLICT (branch_id,employee_id,roster_date) DO UPDATE SET "+update,values);
    }
    await client.query("COMMIT");
    return res.json({ok:true});
  } catch(error) {
    await client.query("ROLLBACK").catch(()=>{});
    console.error("NEON ROSTER WRITE ERROR:",error.message);
    return res.status(503).json({ok:false,message:'Unable to save roster. Please retry.'});
  } finally {client.release();}
});
}
