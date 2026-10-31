import {renderLateReport} from './late-report-export.js';
const key=v=>String(v??'').trim().toUpperCase();
export function buildStatusReport(records,{status,branchId='',staffScope='',employeeIds=null}) {
  const groups=new Map();
  for(const {attendance:a,employee:e={}} of records) {
    const saved=key(a.status);
    const unpaid=['UNPAID','UNPAID LEAVE'].includes(saved)||['TRUE','T','1'].includes(key(a.is_unpaid));
    if(status==='MC'?!['MC','MEDICAL LEAVE'].includes(saved):!unpaid)continue;
    if(branchId&&key(a.branch_id)!==key(branchId))continue;
    const foreign=key(e?.address).includes('FRN');
    if((staffScope==='local'&&(!e||foreign))||(staffScope==='foreign'&&(!e||!foreign)))continue;
    if(employeeIds&&!employeeIds.has(key(a.employee_id)))continue;
    const id=key(a.branch_id)+'|'+key(a.employee_id);
    if(!groups.has(id))groups.set(id,{employee_id:a.employee_id,name:e?.name??a.employee_id,branch_id:a.branch_id,dates:new Set()});
    groups.get(id).dates.add(String(a.attendance_date).slice(0,10));
  }
  return [...groups.values()].map(r=>({...r,dates:[...r.dates].sort(),count:r.dates.size}))
    .sort((a,b)=>key(a.branch_id).localeCompare(key(b.branch_id))||String(a.name).localeCompare(String(b.name)));
}
export function installAttendanceStatusReportApi(app,{authenticate,pool,renderExport=renderLateReport}) {
  app.get('/api/attendance/status-report',authenticate,async(req,res)=>{
    const scope=req.auth?.app_metadata?.staff_scope??'';
    if(key(req.user?.role)!=='ADMIN'||req.auth?.app_metadata?.is_reviewer||scope==='requests')return res.status(403).json({ok:false,message:'Administrator access required.'});
    const year=Number(req.query.year),month=Number(req.query.month),status=key(req.query.status);
    const branchId=String(req.query.branch_id??'').trim(),format=String(req.query.format??'');
    if(!Number.isInteger(year)||year<2000||year>2100||!Number.isInteger(month)||month<1||month>12||!['MC','UNPAID'].includes(status)||!['','pdf'].includes(format)||branchId.length>100)
      return res.status(400).json({ok:false,message:'Invalid attendance report selection.'});
    let employeeIds=null;
    try {
      if(req.query.employees!=null) {
        const ids=JSON.parse(String(req.query.employees));
        if(!Array.isArray(ids)||ids.length>1000||ids.some(id=>typeof id!=='string'||id.length>100))throw Error();
        employeeIds=new Set(ids.map(key));
      }
    } catch{return res.status(400).json({ok:false,message:'Invalid employee selection.'});}
    try {
      const start=`${year}-${String(month).padStart(2,'0')}-01`;
      const [data,branchRows]=await Promise.all([
        pool.query(`SELECT to_jsonb(a) AS attendance, to_jsonb(e) AS employee
          FROM public.attendance a LEFT JOIN public.employees e ON e.employee_id=a.employee_id
          WHERE a.attendance_date >= $1::date AND a.attendance_date < ($1::date + INTERVAL '1 month')
            AND (UPPER(TRIM(COALESCE(to_jsonb(a)->>'status',''))) IN ('MC','MEDICAL LEAVE','UNPAID','UNPAID LEAVE')
              OR LOWER(COALESCE(to_jsonb(a)->>'is_unpaid','')) IN ('true','t','1'))`,[start]),
        pool.query('SELECT id,name FROM public.branches')]);
      const branches=Object.fromEntries(branchRows.rows.map(b=>[key(b.id),b.name==='SUNGAI PETANI'?'SP-EDAR':b.name]));
      if(branchId&&!Object.hasOwn(branches,key(branchId)))return res.status(404).json({ok:false,message:'Branch not found.'});
      const reports=buildStatusReport(data.rows,{status,branchId,staffScope:scope,employeeIds});
      const branchLabel=branchId?branches[key(branchId)]:'All branches';
      if(format==='pdf') {
        const bytes=await renderExport({format:'pdf',view:'status-summary',year,month,status,reports,branches,branchLabel});
        return res.json({ok:true,file_base64:bytes.toString('base64')});
      }
      return res.json({ok:true,status,year,month,reports,branches,branchLabel});
    } catch(error) {
      console.error('ATTENDANCE STATUS REPORT ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load attendance report. Please retry.'});
    }
  });
}
