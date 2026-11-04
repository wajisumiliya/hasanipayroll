import {renderLateReport} from './late-report-export.js';

export const salaryReportNote='All saved earnings minus PCB, Zakat, advance, loan, unpaid, late and other deductions. EPF, EIS and SOCSO employee deductions are excluded. Blank cells mean no eligible saved payroll; 0.00 is a saved zero.';
export const salaryReportBranchNote='Uses the saved payroll branch when present; otherwise the employee current payroll branch, then attendance branch.';
const key=v=>String(v??'').trim().toUpperCase();
const round=v=>Math.round((v+Number.EPSILON)*100)/100;
function number(row,...fields){
  const field=fields.find(f=>row[f]!=null);
  const raw=field==null?0:row[field];
  if(typeof raw==='string'&&!raw.trim())return 0;
  const value=typeof raw==='number'?raw:Number(String(raw).replaceAll(',','').trim());
  if(!Number.isFinite(value))throw new Error(`Invalid ${field} for ${row.employee_id??row.employeeId}.`);
  return value;
}
export function salaryReportAmount(row){
  const basic=number(row,'basic_salary','basicSalary'),fw=number(row,'fw_salary','fwSalary');
  // Follow existing payroll's FW salary replacement; never add duplicate bases.
  const earnings=(fw!==0?fw:basic)+
    number(row,'elaun_kedatangan','elaunKedatangan')+
    number(row,'elaun_perkhidmatan','elaunPerkhidmatan')+
    number(row,'elaun_kerajinan','elaunKerajinan')+
    number(row,'elaun_makanan','elaunMakanan')+
    number(row,'housing_allowance','housingAllowance')+
    number(row,'travel_allowance','travelAllowance')+
    number(row,'overtime')+number(row,'bonus')+number(row,'commission')+
    number(row,'other_earnings','otherEarnings')+number(row,'cuti_umum','cutiUmum');
  const deductions=number(row,'pcb')+number(row,'zakat')+
    number(row,'advance','advance_deduction','advanceDeduction')+
    number(row,'loan_deduction','loanDeduction')+
    number(row,'unpaid_deduction','unpaid_leave','unpaidLeave','unpaidDeduction')+
    number(row,'late_deduction','lateDeduction')+
    number(row,'other_deduction','other_deduction_amount','otherDeduction','otherDeductionAmount');
  return round(earnings-deductions);
}
function dateOnly(value){
  if(!value)return null;
  const date=new Date(value);if(!Number.isFinite(date.getTime()))return null;
  // Employment timestamps are Malaysian dates; date-only values remain dates.
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value))?String(value):
    new Date(date.getTime()+8*3600000).toISOString().slice(0,10);
}
function activeInMonth(employee,month){
  const start=month+'-01',next=new Date(start+'T00:00:00Z');next.setUTCMonth(next.getUTCMonth()+1);
  const joined=dateOnly(employee.joining_date??employee.joiningDate);
  if(joined&&joined>=next.toISOString().slice(0,10))return false;
  const resigned=dateOnly(employee.resigned_at??employee.resignedAt);
  if(resigned)return resigned>=start;
  return employee.is_active===true||String(employee.is_active??employee.isActive).toLowerCase()==='true';
}
export function buildSalaryReport({startYear,employees,payroll,branches,branchId=''}){
  const months=Array.from({length:12},(_,i)=>{
    const d=new Date(Date.UTC(startYear,6+i,1));
    return {key:d.toISOString().slice(0,7),label:`${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getUTCMonth()]} ${d.getUTCFullYear()}`};
  });
  const employeeMap=new Map(employees.map(e=>[key(e.employee_id??e.employeeId),e]));
  const groups=new Map(),seen=new Set();
  for(const row of payroll){
    const date=String(row.period??'').slice(0,7),index=months.findIndex(m=>m.key===date);
    if(index<0)continue;
    const id=key(row.employee_id??row.employeeId),employee=employeeMap.get(id);
    if(!employee)throw new Error(`Missing employee details for ${id}.`);
    if(!activeInMonth(employee,date))continue;
    const branch=key(row.payroll_branch_id)||key(row.branch_id)||key(employee.payroll_branch_id)||key(employee.branch_id)||'UNASSIGNED';
    const unique=id+'|'+date;
    if(seen.has(unique))throw new Error(`Duplicate payroll for ${id}, ${date}. Resolve it before exporting.`);
    seen.add(unique);
    if(branchId&&branch!==key(branchId))continue;
    if(!groups.has(branch))groups.set(branch,new Map());
    const members=groups.get(branch);
    if(!members.has(id))members.set(id,{employee_id:id,name:String(employee.name??id),values:Array(12).fill(null)});
    members.get(id).values[index]=salaryReportAmount(row);
  }
  const branchNames=new Map(branches.map(b=>[key(b.id),String(b.name??b.id)]));
  const result=[...groups].map(([id,members])=>{
    const rows=[...members.values()].sort((a,b)=>a.employee_id.localeCompare(b.employee_id));
    return {id,name:branchNames.get(id)??id,rows,
      totals:months.map((_,i)=>round(rows.reduce((sum,r)=>sum+Math.round((r.values[i]??0)*100),0)/100))};
  }).sort((a,b)=>a.name.localeCompare(b.name)||a.id.localeCompare(b.id));
  return {start_year:startYear,months,branches:result,note:salaryReportNote,branch_note:salaryReportBranchNote,
    employee_count:new Set(result.flatMap(b=>b.rows.map(r=>r.employee_id))).size};
}

export function installSalaryReportApi(app,{pool,authenticate,renderExport=renderLateReport}){
  app.get('/api/reports/salary',authenticate,async(req,res)=>{
    const metadata=req.auth?.app_metadata??{},role=String(req.user?.role??'').toLowerCase();
    if(role!=='admin'||metadata.is_reviewer||['attendance','requests'].includes(metadata.staff_scope))
      return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const year=Number(req.query.start_year??2025),format=String(req.query.format??'json'),branchId=String(req.query.branch_id??'').trim();
    if(!Number.isInteger(year)||year<2000||year>2099||!['json','pdf','xlsx'].includes(format)||branchId.length>100)
      return res.status(400).json({ok:false,message:'Invalid Salary Report period or format.'});
    try{
      const scope=['local','foreign'].includes(metadata.staff_scope)?metadata.staff_scope:null;
      const predicate=`p.period>=make_date($1,7,1) AND p.period<(make_date($1,7,1)+interval '1 year')
        AND ($2::text IS NULL OR ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN')=($2='foreign'))`;
      const [payroll,employees,branches]=await Promise.all([
        pool.query(`SELECT to_jsonb(p)-ARRAY['remarks','new_ic_no','bank_account','bank_code','bank_name','published_by','payment_reference']::text[] AS data
          FROM public.payroll p JOIN public.employees e ON e.employee_id=p.employee_id
          LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id
          WHERE ${predicate} ORDER BY p.employee_id,p.period`,[year,scope]),
        pool.query(`SELECT DISTINCT e.employee_id,e.name,e.branch_id,to_jsonb(e)->>'payroll_branch_id' AS payroll_branch_id,
          e.joining_date,to_jsonb(e)->>'resigned_at' AS resigned_at,e.is_active
          FROM public.employees e JOIN public.payroll p ON p.employee_id=e.employee_id
          LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id WHERE ${predicate}`,[year,scope]),
        pool.query('SELECT id,name FROM public.branches ORDER BY name'),
      ]);
      const report=buildSalaryReport({startYear:year,payroll:payroll.rows.map(r=>r.data),employees:employees.rows,branches:branches.rows,branchId});
      res.set?.('Cache-Control','no-store');
      if(format==='json')return res.json({ok:true,report});
      if(!report.branches.length)return res.status(400).json({ok:false,message:'No eligible saved payroll for this selection.'});
      const bytes=await renderExport({view:'salary-report',format,report});
      return res.json({ok:true,file_base64:bytes.toString('base64')});
    }catch(error){
      const review=/^(Duplicate payroll|Invalid |Missing employee details)/.test(error.message);
      return res.status(review?409:503).json({ok:false,message:review?error.message:'Salary Report is temporarily unavailable. Please retry.'});
    }
  });
}
