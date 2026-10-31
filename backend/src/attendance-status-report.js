import {renderLateReport} from './late-report-export.js';
const key=v=>String(v??'').trim().toUpperCase();
export function buildStatusReport(records,{status,branchId='',staffScope='',employeeIds=null}) {
  const groups=new Map();
  for(const {attendance:a,employee:e={}} of records) {
    const saved=key(a.status);
    const unpaid=saved==='UL';
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
export function applyMcBalances(reports,balances) {
  const byId=new Map(balances.map(r=>[key(r.employee_id),r]));
  const grouped=new Map();
  for(const r of reports) {
    const id=key(r.employee_id);
    if(!grouped.has(id))grouped.set(id,{...r,dates:new Set(),branch_ids:new Set()});
    const group=grouped.get(id);r.dates.forEach(d=>group.dates.add(d));group.branch_ids.add(r.branch_id);
  }
  return [...grouped.values()].map(r=>{
    const balance=byId.get(key(r.employee_id));
    const opening=balance?.balance==null?null:Math.round((Number(balance.balance)-Number(balance.prior_taken??0))*100)/100;
    const taken=Number(balance?.current_taken??r.dates.size);
    return {...r,dates:[...r.dates].sort(),branch_ids:[...r.branch_ids],count:r.dates.size,
      opening_mc:opening,mc_taken:taken,closing_mc:opening==null?null:Math.round((opening-taken)*100)/100,
      mc_opening_month:balance?.opening_month??null};
  });
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
            AND (CASE WHEN $2::text='MC'
              THEN UPPER(TRIM(COALESCE(to_jsonb(a)->>'status',''))) IN ('MC','MEDICAL LEAVE')
              ELSE UPPER(TRIM(COALESCE(to_jsonb(a)->>'status','')))='UL' END)`,[start,status]),
        pool.query('SELECT id,name FROM public.branches')]);
      const branches=Object.fromEntries(branchRows.rows.map(b=>[key(b.id),b.name==='SUNGAI PETANI'?'SP-EDAR':b.name]));
      if(branchId&&!Object.hasOwn(branches,key(branchId)))return res.status(404).json({ok:false,message:'Branch not found.'});
      let reports=buildStatusReport(data.rows,{status,branchId,staffScope:scope,employeeIds});
      if(status==='MC'&&reports.length) {
        const balances=await pool.query(`SELECT e.employee_id, o.opening_month, o.balance,
            COUNT(DISTINCT a.attendance_date) FILTER (WHERE a.attendance_date < $1::date) AS prior_taken,
            COUNT(DISTINCT a.attendance_date) FILTER (WHERE a.attendance_date >= $1::date) AS current_taken
          FROM public.employees e
          LEFT JOIN LATERAL (SELECT opening_month,balance FROM app_private.employee_mc_openings
            WHERE employee_id=e.employee_id AND opening_month <= $1::date ORDER BY opening_month DESC LIMIT 1) o ON true
          LEFT JOIN public.attendance a ON a.employee_id=e.employee_id
            AND a.attendance_date >= COALESCE(o.opening_month,$1::date)
            AND a.attendance_date < ($1::date + INTERVAL '1 month')
            AND UPPER(TRIM(COALESCE(a.status,''))) IN ('MC','MEDICAL LEAVE')
          WHERE e.employee_id=ANY($2::text[]) GROUP BY e.employee_id,o.opening_month,o.balance`,
          [start,[...new Set(reports.map(r=>r.employee_id))]]);
        reports=applyMcBalances(reports,balances.rows).map(r=>({...r,branch_names:r.branch_ids.map(id=>branches[key(id)]??id).join(' / ')}));
      }
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
