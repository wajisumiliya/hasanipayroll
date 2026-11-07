const key = value => String(value ?? '').trim().toUpperCase();
export function salaryReportAdmin(req) {
  const meta=req.auth?.app_metadata??{};
  return String(req.user?.role??'').toLowerCase()==='admin'&&!meta.is_reviewer
    && !['attendance','requests'].includes(meta.staff_scope);
}
export function salaryReportScope(req) {
  const scope=req.auth?.app_metadata?.staff_scope;
  return ['local','foreign'].includes(scope)?scope:null;
}
const scopedEmployee=`($2::text IS NULL OR ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN')=($2='foreign'))`;
export function assignmentRange(body={}) {
  const employee=key(body.employee_id),branch=String(body.branch_id??'').trim();
  const from=String(body.from_month??''),through=String(body.through_month??'');
  const valid=v=>/^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(v);
  const month=v=>Number(v.slice(0,4))*12+Number(v.slice(5));
  if(!employee||employee.length>100||branch.length>100||!valid(from)||!valid(through)
    ||month(through)<month(from)||month(through)-month(from)>=120) return null;
  return {employee,branch,from:from+'-01',through:through+'-01'};
}
export function installSalaryReportAssignmentsApi(app,{pool,authenticate}) {
  const path='/api/reports/salary/branch-assignments';
  app.get(path,authenticate,async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const year=Number(req.query.start_year??2025);
    if(!Number.isInteger(year)||year<2000||year>2099)return res.status(400).json({ok:false,message:'Invalid reporting period.'});
    try {
      const args=[year,salaryReportScope(req)];
      const [employees,branches,assignments]=await Promise.all([
        pool.query(`SELECT DISTINCT e.employee_id,e.name FROM public.employees e
          JOIN public.payroll p ON p.employee_id=e.employee_id
          LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
          WHERE p.period>=make_date($1,7,1) AND p.period<make_date($1,7,1)+INTERVAL '1 year'
          AND ${scopedEmployee} ORDER BY e.employee_id`,args),
        pool.query('SELECT id,name FROM public.branches ORDER BY name'),
        pool.query(`SELECT a.employee_id,a.branch_id,to_char(a.period,'YYYY-MM') AS month
          FROM app_private.salary_report_branch_assignments a
          JOIN public.employees e ON e.employee_id=a.employee_id
          LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
          WHERE a.period>=make_date($1,7,1) AND a.period<make_date($1,7,1)+INTERVAL '1 year'
          AND ${scopedEmployee} ORDER BY a.employee_id,a.period`,args),
      ]);
      res.set?.('Cache-Control','no-store');
      return res.json({ok:true,employees:employees.rows,branches:branches.rows,assignments:assignments.rows});
    } catch(error) {
      console.error('SALARY ASSIGNMENTS READ ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load report branch assignments. Please retry.'});
    }
  });
  const mutate=remove=>async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const range=assignmentRange(req.body);
    if(!range||(!remove&&!range.branch))return res.status(400).json({ok:false,message:'Select an employee, branch and valid month range (up to 120 months).'});
    let client;
    try {
      client=await pool.connect();await client.query('BEGIN');
      const employee=await client.query(`SELECT e.employee_id FROM public.employees e
        LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
        WHERE e.employee_id=$1 AND ${scopedEmployee}`,[range.employee,salaryReportScope(req)]);
      if(!employee.rowCount){await client.query('ROLLBACK');return res.status(404).json({ok:false,message:'Employee unavailable in your payroll scope.'});}
      let result;
      if(remove){
        result=await client.query(`DELETE FROM app_private.salary_report_branch_assignments
          WHERE employee_id=$1 AND period BETWEEN $2::date AND $3::date RETURNING period`,[range.employee,range.from,range.through]);
      }else{
        const branch=await client.query('SELECT id FROM public.branches WHERE id=$1',[range.branch]);
        if(!branch.rowCount){await client.query('ROLLBACK');return res.status(400).json({ok:false,message:'Select a valid branch.'});}
        // The primary key rejects overlapping months, including concurrent saves.
        // One statement + transaction means a partially overlapping range saves nothing.
        result=await client.query(`INSERT INTO app_private.salary_report_branch_assignments(employee_id,period,branch_id,assigned_by)
          SELECT $1,m::date,$4,$5 FROM generate_series($2::date,$3::date,INTERVAL '1 month') m RETURNING period`,
          [range.employee,range.from,range.through,range.branch,String(req.user?.id??req.user?.username??'payroll-admin')]);
      }
      await client.query('COMMIT');
      return res.json({ok:true,months:result.rowCount});
    }catch(error){
      if(client)await client.query('ROLLBACK').catch(()=>{});
      if(error.code==='23505')return res.status(409).json({ok:false,message:'This employee already has an assignment in that range. Remove the existing assignments before saving a replacement.'});
      console.error('SALARY ASSIGNMENTS SAVE ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to save report branch assignments. Please retry.'});
    }finally{client?.release();}
  };
  app.post(path,authenticate,mutate(false));
  app.delete(path,authenticate,mutate(true));
}
