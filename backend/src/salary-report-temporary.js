import {assignmentRange,salaryReportAdmin,salaryReportScope} from './salary-report-assignments.js';

// Existing employees follow the same current local/FRN scope as real payroll.
// Historical-only employees use their explicitly entered classification.
export const temporaryReportScopeSql=`($2::text IS NULL OR CASE WHEN e.employee_id IS NULL THEN t.staff_scope
  WHEN ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN') THEN 'foreign' ELSE 'local' END=$2)`;
export function temporaryPayrollInput(body={}) {
  const range=assignmentRange(body);
  if(!range||!range.branch)return null;
  const start=new Date(range.from),end=new Date(range.through);
  if((end.getUTCFullYear()-start.getUTCFullYear())*12+end.getUTCMonth()-start.getUTCMonth()>11)return null;
  const fields=['basic_salary','allowances','other_earnings','deductions'];
  const money={};
  for(const field of fields){
    const raw=body[field]??0;
    if(typeof raw!=='number'&&typeof raw!=='string')return null;
    const text=String(raw).trim();
    if(!/^\d+(\.\d{1,2})?$/.test(text))return null;
    const value=Number(text);
    if(!Number.isFinite(value)||value>9999999999.99)return null;
    money[field]=value;
  }
  if((body.employee_name!=null&&typeof body.employee_name!=='string')||(body.notes!=null&&typeof body.notes!=='string'))return null;
  const name=String(body.employee_name??'').trim(),notes=String(body.notes??'').trim();
  const scope=String(body.staff_scope??'');
  if(name.length>200||notes.length>2000||!['local','foreign'].includes(scope))return null;
  return {...range,...money,name,notes,scope};
}
export function installSalaryReportTemporaryApi(app,{pool,authenticate}) {
  const path='/api/reports/salary/temporary-payroll';
  app.get(path,authenticate,async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const year=Number(req.query.start_year??2025),scope=salaryReportScope(req);
    if(!Number.isInteger(year)||year<2000||year>2099)return res.status(400).json({ok:false,message:'Invalid reporting period.'});
    try{
      const [employees,branches,entries]=await Promise.all([
        pool.query(`SELECT e.employee_id,e.name,CASE WHEN ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN') THEN 'foreign' ELSE 'local' END AS staff_scope
          FROM public.employees e LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
          WHERE ($1::text IS NULL OR ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN')=($1='foreign')) ORDER BY e.employee_id`,[scope]),
        pool.query('SELECT id,name FROM public.branches ORDER BY name'),
        pool.query(`SELECT t.*,to_char(t.period,'YYYY-MM') AS month,COALESCE(e.name,t.employee_name) AS display_name,
          EXISTS(SELECT 1 FROM public.payroll p WHERE p.employee_id=t.employee_id AND p.period>=t.period AND p.period<t.period+INTERVAL '1 month') AS has_saved_payroll
          FROM app_private.salary_report_temporary_payroll t
          LEFT JOIN public.employees e ON e.employee_id=t.employee_id
          LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
          WHERE t.period>=make_date($1,7,1) AND t.period<make_date($1,7,1)+INTERVAL '1 year'
          AND ${temporaryReportScopeSql} ORDER BY t.employee_id,t.period`,[year,scope]),
      ]);
      res.set?.('Cache-Control','no-store');
      return res.json({ok:true,employees:employees.rows,branches:branches.rows,entries:entries.rows,staff_scope:scope});
    }catch(error){
      console.error('TEMPORARY SALARY READ ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load temporary reconciliation payroll. Please retry.'});
    }
  });
  const mutate=method=>async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const remove=method==='DELETE',update=method==='PUT',input=remove?assignmentRange(req.body):temporaryPayrollInput(req.body);
    if(!input||(update&&input.from!==input.through))return res.status(400).json({ok:false,message:'Enter an employee, branch, classification, valid month range (up to 12 months), and non-negative amounts with at most two decimals.'});
    const scope=salaryReportScope(req);let client;
    try{
      client=await pool.connect();await client.query('BEGIN');
      await client.query("SELECT pg_advisory_xact_lock(hashtext('salary-report-temp:'||$1))",[input.employee]);
      const master=await client.query(`SELECT e.name,CASE WHEN ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN') THEN 'foreign' ELSE 'local' END AS staff_scope
        FROM public.employees e LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id WHERE e.employee_id=$1`,[input.employee]);
      const previous=await client.query('SELECT DISTINCT staff_scope FROM app_private.salary_report_temporary_payroll WHERE employee_id=$1',[input.employee]);
      const oldScopes=new Set(previous.rows.map(row=>row.staff_scope));
      const employee=master.rows[0];
      const forbidden=employee?scope&&employee.staff_scope!==scope:scope&&[...oldScopes].some(value=>value!==scope);
      if(forbidden){await client.query('ROLLBACK');return res.status(404).json({ok:false,message:'Employee unavailable in your payroll scope.'});}
      let result;
      if(remove){
        result=await client.query('DELETE FROM app_private.salary_report_temporary_payroll WHERE employee_id=$1 AND period BETWEEN $2::date AND $3::date RETURNING period',[input.employee,input.from,input.through]);
        if(!result.rowCount){await client.query('ROLLBACK');return res.status(404).json({ok:false,message:'Temporary entry not found.'});}
      }else{
        const classification=employee?.staff_scope??input.scope,name=String(employee?.name??'').trim()||input.name;
        if(!name){await client.query('ROLLBACK');return res.status(400).json({ok:false,message:'Enter the historical employee name.'});}
        if(scope&&classification!==scope){await client.query('ROLLBACK');return res.status(403).json({ok:false,message:'Select an employee in your payroll scope.'});}
        if(!employee&&oldScopes.size&&(!oldScopes.has(classification)||oldScopes.size>1)){
          await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Keep the same employee classification as their other temporary entries.'});
        }
        const branch=await client.query('SELECT id FROM public.branches WHERE id=$1',[input.branch]);
        if(!branch.rowCount){await client.query('ROLLBACK');return res.status(400).json({ok:false,message:'Select a valid branch.'});}
        const actual=await client.query(`SELECT 1 FROM public.payroll WHERE employee_id=$1 AND period>=$2::date AND period<$3::date+INTERVAL '1 month' LIMIT 1`,[input.employee,input.from,input.through]);
        if(actual.rowCount){await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Saved payroll already exists in this range. Temporary entries can only fill missing months.'});}
        const values=[input.employee,input.from,input.through,name,input.branch,classification,input.basic_salary,input.allowances,input.other_earnings,input.deductions,input.notes,String(req.user?.id??req.user?.username??'payroll-admin')];
        result=update?await client.query(`UPDATE app_private.salary_report_temporary_payroll SET employee_name=$4,branch_id=$5,staff_scope=$6,basic_salary=$7,allowances=$8,other_earnings=$9,deductions=$10,notes=$11,updated_by=$12,updated_at=now()
          WHERE employee_id=$1 AND period=$2::date AND period=$3::date RETURNING period`,values):
          await client.query(`INSERT INTO app_private.salary_report_temporary_payroll(employee_id,period,employee_name,branch_id,staff_scope,basic_salary,allowances,other_earnings,deductions,notes,created_by,updated_by)
            SELECT $1,m::date,$4,$5,$6,$7,$8,$9,$10,$11,$12,$12 FROM generate_series($2::date,$3::date,INTERVAL '1 month') m RETURNING period`,values);
        if(!result.rowCount){await client.query('ROLLBACK');return res.status(404).json({ok:false,message:'Temporary entry not found. Refresh and try again.'});}
      }
      await client.query('COMMIT');return res.json({ok:true,months:result.rowCount});
    }catch(error){
      if(client)await client.query('ROLLBACK').catch(()=>{});
      if(error.code==='23505')return res.status(409).json({ok:false,message:'A temporary entry already exists in this range. Edit the entry or remove it before adding a replacement.'});
      console.error('TEMPORARY SALARY SAVE ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to save temporary reconciliation payroll. Please retry.'});
    }finally{client?.release();}
  };
  app.post(path,authenticate,mutate('POST'));
  app.put(path,authenticate,mutate('PUT'));
  app.delete(path,authenticate,mutate('DELETE'));
}
