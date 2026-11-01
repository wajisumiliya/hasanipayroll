import {renderLateReport} from './late-report-export.js';
const key=value=>String(value??'').trim().toUpperCase();
const clock=value=>{const m=/^(\d{1,2}):(\d{2})/.exec(String(value??''));return m&&+m[1]<24&&+m[2]<60?+m[1]*60 + +m[2]:null;};
const applicable=value=>!['FALSE','0','NO','N','NOT APPLICABLE'].includes(key(value));

export function buildApprovedOtReport(rows,{year,month,branchId='',staffScope='',employeeIds=null}={}) {
  const prefix=`${year}-${String(month).padStart(2,'0')}-`,seen=new Set(),employees=new Map();
  for(const row of rows){
    const id=key(row.employee_id),date=String(row.attendance_date??'').slice(0,10);
    const minutes=Number(row.approved_ot_minutes);
    if(!id||id==='HED1016'||!date.startsWith(prefix)||!Number.isInteger(minutes)||minutes<30||minutes>1440)continue;
    if(branchId&&key(row.branch_id)!==key(branchId))continue;
    if(employeeIds&&!employeeIds.has(id))continue;
    const foreign=key(row.address).includes('FRN');
    if(staffScope==='local'&&foreign||staffScope==='foreign'&&!foreign)continue;
    const identity=id+'|'+date;if(seen.has(identity))continue;seen.add(identity);
    const current=employees.get(id)??{employee_id:id,name:row.name??id,approved_minutes:0,raw_amount:0,amount_known:true};
    current.approved_minutes+=minutes;
    const basic=row.basic_salary==null?NaN:Number(row.basic_salary);
    let target=key(row.epf_category)==='NORMAL1'||applicable(row.eis_applicable)?450:630;
    const start=clock(row.shift_start),end=clock(row.shift_end),breakMinutes=Number(row.break_minutes??0);
    if(start!=null&&end!=null&&Number.isFinite(breakMinutes)&&breakMinutes>=0){
      const net=((end-start+1440)%1440||1440)-breakMinutes;if(net>0)target=net;
    }
    if(!Number.isFinite(basic)||basic<0)current.amount_known=false;
    else {const amount=(minutes/60)*(basic/26/(target/60))*1.5;if(amount>5)current.raw_amount+=amount;}
    employees.set(id,current);
  }
  return [...employees.values()].map(({raw_amount,amount_known,...row})=>({...row,
    approved_hours:row.approved_minutes/60,ot_amount:amount_known?Math.round((raw_amount+Number.EPSILON)*10)/10:null}))
    .sort((a,b)=>String(a.name).localeCompare(String(b.name))||a.employee_id.localeCompare(b.employee_id));
}

export function installApprovedOtReportApi(app,{authenticate,pool,renderExport=renderLateReport}) {
  app.get('/api/attendance/approved-ot-report',authenticate,async(req,res)=>{
    const scope=req.auth?.app_metadata?.staff_scope??'';
    if(key(req.user?.role)!=='ADMIN'||req.auth?.app_metadata?.is_reviewer||scope==='requests')
      return res.status(403).json({ok:false,message:'Administrator access required.'});
    const year=Number(req.query.year),month=Number(req.query.month),branchId=String(req.query.branch_id??'').trim(),format=String(req.query.format??'');
    if(!Number.isInteger(year)||year<2000||year>2100||!Number.isInteger(month)||month<1||month>12||branchId.length>100||!['','pdf'].includes(format))
      return res.status(400).json({ok:false,message:'Invalid OT report selection.'});
    let employeeIds=null;
    try{if(req.query.employees!=null){const ids=JSON.parse(String(req.query.employees));
      if(!Array.isArray(ids)||ids.length>1000||ids.some(id=>typeof id!=='string'||id.length>100))throw Error();
      employeeIds=new Set(ids.map(key));}}
    catch{return res.status(400).json({ok:false,message:'Invalid employee selection.'});}
    try{
      const start=`${year}-${String(month).padStart(2,'0')}-01`;
      const [source,branchRows]=await Promise.all([
        pool.query(`SELECT a.employee_id,a.attendance_date::text,a.branch_id,a.approved_ot_minutes,e.name,
          CONCAT_WS(' ',e.address,d.address) AS address,
          COALESCE(p.basic_salary,d.basic_salary)::text AS basic_salary,d.epf_category,d.eis_applicable,
          r.shift_start,r.shift_end,r.break_minutes
          FROM public.attendance a JOIN public.employees e ON e.employee_id=a.employee_id
          LEFT JOIN public.employee_salary_defaults d ON d.employee_id=a.employee_id
          LEFT JOIN public.payroll p ON p.employee_id=a.employee_id AND p.period=$1::date
          LEFT JOIN public.monthly_rosters r ON r.employee_id=a.employee_id AND LOWER(TRIM(r.branch_id))=LOWER(TRIM(a.branch_id))
            AND r.roster_year=$2 AND r.roster_month=$3 AND r.week_number=((EXTRACT(DAY FROM a.attendance_date)::int-1)/7+1)
          WHERE a.attendance_date >= $1::date AND a.attendance_date < ($1::date+INTERVAL '1 month')
            AND a.approved_ot_minutes >= 30
            AND ($4::text='' OR UPPER(TRIM(a.branch_id))=UPPER(TRIM($4)))
            AND ($5::text[] IS NULL OR UPPER(TRIM(a.employee_id))=ANY($5::text[]))
          ORDER BY a.employee_id,a.attendance_date`,[start,year,month,branchId,employeeIds?[...employeeIds]:null]),
        pool.query('SELECT id,name FROM public.branches')]);
      const branches=Object.fromEntries(branchRows.rows.map(b=>[key(b.id),b.name==='SUNGAI PETANI'?'SP-EDAR':b.name]));
      if(branchId&&!Object.hasOwn(branches,key(branchId)))return res.status(404).json({ok:false,message:'Branch not found.'});
      const reports=buildApprovedOtReport(source.rows,{year,month,branchId,staffScope:scope,employeeIds});
      const payload={format:'pdf',view:'ot-summary',year,month,reports,branchLabel:branchId?branches[key(branchId)]:'All branches'};
      if(format==='pdf'){const bytes=await renderExport(payload);return res.json({ok:true,file_base64:bytes.toString('base64')});}
      return res.json({ok:true,year,month,reports,branchLabel:payload.branchLabel});
    }catch(error){console.error('APPROVED OT REPORT ERROR:',error.message);return res.status(503).json({ok:false,message:'Unable to load approved OT report.'});}
  });
}
