import crypto from 'node:crypto';

const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const allowed = req => ['ADMIN','BRANCH'].includes(String(req.user?.role ?? '').toUpperCase())
  && !['attendance','requests'].includes(String(req.auth?.app_metadata?.staff_scope ?? ''));

export function installQrAttendanceApi(app, pool, authenticate) {
  app.post('/api/qr-attendance/issue', authenticate, async (req,res) => {
    if (String(req.user?.role ?? '').toUpperCase() !== 'ADMIN' || !allowed(req))
      return res.status(403).json({ok:false,message:'Admin required.'});
    const employeeId = String(req.body?.employee_id ?? '').trim();
    if (!employeeId || employeeId.length > 80) return res.status(400).json({ok:false,message:'Invalid employee.'});
    const token = 'HBQR1_' + crypto.randomBytes(32).toString('base64url');
    try {
      const employee = await pool.query('SELECT employee_id, is_active FROM public.employees WHERE employee_id=$1 LIMIT 1',[employeeId]);
      if (!employee.rows.length || !employee.rows[0].is_active) return res.status(404).json({ok:false,message:'Active employee not found.'});
      await pool.query(`INSERT INTO public.qr_attendance_credentials(employee_id,token_hash,issued_at,revoked_at)
        VALUES($1,$2,now(),NULL) ON CONFLICT(employee_id)
        DO UPDATE SET token_hash=EXCLUDED.token_hash,issued_at=now(),revoked_at=NULL`,[employeeId,sha256(token)]);
      res.json({ok:true,employee_id:employeeId,qr_value:token,message:'Print this QR once. Reissuing invalidates the old QR.'});
    } catch(err) {console.error('QR issue failed',err.message);res.status(503).json({ok:false,message:'QR storage unavailable.'});}
  });

  app.post('/api/qr-attendance/scan', authenticate, async (req,res) => {
    if (!allowed(req)) return res.status(403).json({ok:false,message:'Branch or admin access required.'});
    const token = String(req.body?.qr_value ?? '').trim();
    if (!/^HBQR1_[A-Za-z0-9_-]{43}$/.test(token)) return res.status(400).json({ok:false,message:'Invalid QR code.'});
    const branch = String(req.user?.branchId ?? req.user?.branch_id ?? '').trim();
    if (!branch) return res.status(403).json({ok:false,message:'Assigned branch required.'});
    const client=await pool.connect();
    try {
      await client.query('BEGIN');
      const found=await client.query(`SELECT e.employee_id,e.name,e.branch_id,e.is_active
        FROM public.qr_attendance_credentials c JOIN public.employees e ON e.employee_id=c.employee_id
        WHERE c.token_hash=$1 AND c.revoked_at IS NULL LIMIT 1`,[sha256(token)]);
      const emp=found.rows[0];
      if (!emp || !emp.is_active) {await client.query('ROLLBACK');return res.status(404).json({ok:false,message:'QR is unknown or revoked.'});}
      if (String(emp.branch_id).toUpperCase()!==branch.toUpperCase()) {await client.query('ROLLBACK');return res.status(403).json({ok:false,message:'Employee belongs to a different branch.'});}
      // Serialized per employee across kiosks: prevents parallel scans choosing the same action.
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[emp.employee_id]);
      const previous=await client.query(`SELECT action,scanned_at FROM public.qr_attendance_events WHERE employee_id=$1
        ORDER BY scanned_at DESC,id DESC LIMIT 1`,[emp.employee_id]);
      const last=previous.rows[0];
      const nowResult=await client.query('SELECT now() AS ts');
      const timestamp=nowResult.rows[0].ts;
      if (last && timestamp.getTime()-new Date(last.scanned_at).getTime()<60000) {
        await client.query('ROLLBACK');return res.status(429).json({ok:false,message:'Duplicate scan blocked. Wait at least 60 seconds.'});
      }
      // One IN and one OUT per Malaysia calendar day; no automatic override of payroll attendance.
      const dayResult = await client.query("SELECT to_char((now() AT TIME ZONE 'Asia/Kuala_Lumpur')::date,'YYYY-MM-DD') AS day");
      const day = dayResult.rows[0].day;
      const today=await client.query(`SELECT action FROM public.qr_attendance_events WHERE employee_id=$1
        AND (scanned_at AT TIME ZONE 'Asia/Kuala_Lumpur')::date=$2::date
        ORDER BY scanned_at DESC,id DESC LIMIT 1`,[emp.employee_id,day]);
      if (today.rows[0]?.action==='OUT') {await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Today is completed. Contact supervisor for corrections.'});}
      const action=today.rows[0]?.action==='IN'?'OUT':'IN';
      const event=await client.query(`INSERT INTO public.qr_attendance_events(employee_id,branch_id,action,scanned_by)
        VALUES($1,$2,$3,$4) RETURNING id,scanned_at`,[emp.employee_id,emp.branch_id,action,String(req.user?.username ?? req.auth?.sub ?? 'branch')]);
      await client.query('COMMIT');
      res.json({ok:true,employee_id:emp.employee_id,name:emp.name,branch_id:emp.branch_id,action,scanned_at:event.rows[0].scanned_at,event_id:event.rows[0].id});
    } catch(err) {await client.query('ROLLBACK').catch(()=>{});console.error('QR scan failed',err.message);res.status(503).json({ok:false,message:'Attendance scan unavailable. No confirmation was saved.'});}
    finally {client.release();}
  });
}
