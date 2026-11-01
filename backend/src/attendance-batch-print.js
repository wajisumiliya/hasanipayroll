// Batch print reads only saved attendance and the rate inputs required by PDFs.
export function installAttendanceBatchPrintApi(app,{authenticate,pool}) {
  app.get('/api/attendance-sheet/print-batch',authenticate,async(req,res)=>{
    const role=String(req.user?.role??'').toUpperCase();
    if(!['ADMIN','BRANCH'].includes(role)||req.auth?.app_metadata?.is_reviewer||req.auth?.app_metadata?.staff_scope==='requests')return res.status(403).json({ok:false,message:'Admin or branch access required.'});
    const year=Number(req.query.year),month=Number(req.query.month),branch=String(req.query.branch_id??'').trim();
    let ids;
    try{ids=JSON.parse(String(req.query.employees??''));
      if(!Array.isArray(ids)||!ids.length||ids.length>100||ids.some(id=>typeof id!=='string'||!id.trim()||id.length>100))throw Error();
      ids=[...new Set(ids.map(id=>id.trim()))];
    }catch{return res.status(400).json({ok:false,message:'Select between 1 and 100 employees.'});}
    if(!branch||branch.length>100||!Number.isInteger(year)||year<2000||year>2100||!Number.isInteger(month)||month<1||month>12)
      return res.status(400).json({ok:false,message:'Invalid attendance print selection.'});
    if(role==='BRANCH'&&branch.toUpperCase()!==String(req.user.branchId??req.user.branch_id??'').trim().toUpperCase())
      return res.status(403).json({ok:false,message:'Branch access denied.'});
    try{
      const employees=await pool.query(`SELECT employee_id,name,branch_id,department,to_jsonb(e)->>'section' AS section,address,
        to_jsonb(e)->>'employment_status' AS employment_status,
        to_jsonb(e)->>'is_management_staff' AS is_management_staff,
        to_jsonb(e)->>'is_temp_staff' AS is_temp_staff,
        to_jsonb(e)->>'is_support_staff' AS is_support_staff
        FROM public.employees e WHERE employee_id=ANY($1::text[]) AND LOWER(TRIM(branch_id))=LOWER(TRIM($2))`,[ids,branch]);
      if(employees.rows.length!==ids.length)return res.status(403).json({ok:false,message:'One or more selected employees are outside this branch or unavailable.'});
      const scope=req.auth?.app_metadata?.staff_scope;
      if(['local','foreign'].includes(scope)&&employees.rows.some(e=>String(e.address??'').toUpperCase().includes('FRN')!==(scope==='foreign')))
        return res.status(403).json({ok:false,message:'Employee selection is outside your staff scope.'});
      const start=`${year}-${String(month).padStart(2,'0')}-01`;
      const [attendance,salaries,payroll,monthly,daily]=await Promise.all([
        pool.query(`SELECT to_jsonb(a) AS data FROM public.attendance a WHERE employee_id=ANY($1::text[])
          AND attendance_date >= $2::date AND attendance_date < ($2::date+INTERVAL '1 month') ORDER BY employee_id,attendance_date`,[ids,start]),
        pool.query('SELECT employee_id,basic_salary,fw_salary,address,epf_category,eis_applicable FROM public.employee_salary_defaults WHERE employee_id=ANY($1::text[])',[ids]),
        pool.query(`SELECT employee_id,overtime,late_deduction,unpaid_deduction FROM public.payroll WHERE employee_id=ANY($1::text[])
          AND period >= $2::date AND period < ($2::date+INTERVAL '1 month')`,[ids,start]),
        pool.query(`SELECT to_jsonb(r) AS data FROM public.monthly_rosters r WHERE employee_id=ANY($1::text[])
          AND roster_year=$2 AND roster_month=$3`,[ids,year,month]),
        pool.query(`SELECT to_jsonb(r) AS data FROM public.daily_rosters r WHERE employee_id=ANY($1::text[])
          AND roster_date >= $2::date AND roster_date < ($2::date+INTERVAL '1 month')`,[ids,start])]);
      return res.json({ok:true,employees:employees.rows,attendance:attendance.rows.map(r=>r.data),salaries:salaries.rows,
        payroll:payroll.rows,monthly_rosters:monthly.rows.map(r=>r.data),daily_rosters:daily.rows.map(r=>r.data)});
    }catch(error){console.error('ATTENDANCE BATCH PRINT ERROR:',error.message);return res.status(503).json({ok:false,message:'Unable to load attendance for printing.'});}
  });
}
