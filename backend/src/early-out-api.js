import {buildEarlyOutEvents,approverRole,key} from './early-out-calculation.js';
const date=v=>v instanceof Date?v.toISOString().slice(0,10):String(v??'').slice(0,10);
const validPeriod=(y,m)=>Number.isInteger(y)&&y>=2000&&y<=2100&&Number.isInteger(m)&&m>=1&&m<=12;
async function load(client,year,month,employeeIds=null,cutoff=null){
 let pending=Promise.resolve();
 const query=(...args)=>{if(typeof client.release!=='function')return client.query(...args);const result=pending.then(()=>client.query(...args));pending=result.catch(()=>{});return result;};
 const start=`${year}-${String(month).padStart(2,'0')}-01`;
 const selected=employeeIds?.length?employeeIds:null;
 const [people,salary,attendance,daily,monthly,decisions]=await Promise.all([
  query('SELECT employee_id,name,branch_id,address,is_management_staff,is_temp_staff,is_support_staff FROM public.employees WHERE ($1::text[] IS NULL OR employee_id=ANY($1))',[selected]),
  query('SELECT employee_id,address,epf_category,eis_applicable FROM public.employee_salary_defaults WHERE ($1::text[] IS NULL OR employee_id=ANY($1))',[selected]),
  query("SELECT to_jsonb(a) data FROM public.attendance a WHERE attendance_date >= $1::date AND attendance_date < ($1::date+INTERVAL '1 month') AND ($2::text[] IS NULL OR employee_id=ANY($2))",[start,selected]),
  query("SELECT to_jsonb(r) data FROM public.daily_rosters r WHERE roster_date >= $1::date AND roster_date < ($1::date+INTERVAL '1 month') AND ($2::text[] IS NULL OR employee_id=ANY($2))",[start,selected]),
  query('SELECT to_jsonb(r) data FROM public.monthly_rosters r WHERE roster_year=$1 AND roster_month=$2 AND ($3::text[] IS NULL OR employee_id=ANY($3))',[year,month,selected]),
  query("SELECT *,attendance_date::text FROM app_private.early_out_decisions WHERE attendance_date >= $1::date AND attendance_date < ($1::date+INTERVAL '1 month') AND approved_at <= COALESCE($2::timestamptz,clock_timestamp()) AND ($3::text[] IS NULL OR employee_id=ANY($3)) ORDER BY id DESC",[start,cutoff,selected])
 ]);
 return buildEarlyOutEvents({employees:people.rows,salaries:salary.rows,attendance:attendance.rows.map(r=>r.data),daily:daily.rows.map(r=>r.data),monthly:monthly.rows.map(r=>r.data),decisions:decisions.rows});
}
function scoped(req,event){const scope=req.auth?.app_metadata?.staff_scope;if(!['local','foreign'].includes(scope))return true;return scope==='foreign'?event.foreign:!event.foreign;}
const fail=(res,error)=>{console.error('EARLY OUT:',error.message);return res.status(503).json({ok:false,message:error.code==='42P01'||error.code==='42703'?'Early Out migration is awaiting installation. No payroll was changed.':'Early Out is temporarily unavailable. No payroll was changed.'});};
export function installEarlyOutApi(app,{authenticate,pool}){
 app.get('/api/attendance/early-out',authenticate,async(req,res)=>{
  if(!approverRole(req))return res.status(403).json({ok:false,message:'Admin or Accounts access required.'});
  const year=Number(req.query.year),month=Number(req.query.month),page=Number(req.query.page??1),limit=Number(req.query.limit??20),status=key(req.query.status??'ALL');
  if(!validPeriod(year,month)||!Number.isInteger(page)||page<1||!Number.isInteger(limit)||limit<1||limit>100||!['ALL','PENDING','APPROVED','REJECTED'].includes(status))return res.status(400).json({ok:false,message:'Invalid Early Out filters.'});
  try{const events=await load(pool,year,month);const search=key(req.query.search);
   const filtered=events.filter(e=>scoped(req,e)&&(!req.query.branch_id||key(e.branch_id)===key(req.query.branch_id))&&(!req.query.employee_id||key(e.employee_id)===key(req.query.employee_id))&&(status==='ALL'||e.approval_status===status)&&(!search||key(e.employee_id+' '+e.name+' '+e.branch_id).includes(search))).sort((a,b)=>b.attendance_date.localeCompare(a.attendance_date)||key(a.branch_id).localeCompare(key(b.branch_id))||key(a.employee_id).localeCompare(key(b.employee_id)));
   res.set?.('Cache-Control','no-store');return res.json({ok:true,records:filtered.slice((page-1)*limit,page*limit),total:filtered.length,page,limit});
  }catch(error){return fail(res,error);}
 });
 app.get('/api/attendance/early-out/payroll-context',authenticate,async(req,res)=>{
  const role=key(req.user?.role);if(!approverRole(req)&&!['BRANCH','EMPLOYEE'].includes(role))return res.status(403).json({ok:false,message:'Access denied.'});
  const year=Number(req.query.year),month=Number(req.query.month);let ids;
  try{ids=JSON.parse(String(req.query.employees??'[]'));if(!Array.isArray(ids)||!ids.length||ids.length>500||ids.some(id=>typeof id!=='string'||!id.trim()||id.length>100))throw Error();}catch{return res.status(400).json({ok:false,message:'Select 1–500 employees.'});}
  if(!validPeriod(year,month))return res.status(400).json({ok:false,message:'Invalid period.'});
  try{
   const people=await pool.query('SELECT employee_id,branch_id FROM public.employees WHERE employee_id=ANY($1::text[])',[ids]);
   if(people.rows.length!==new Set(ids).size||people.rows.some(e=>role==='BRANCH'?key(e.branch_id)!==key(req.user.branchId??req.user.branch_id):role==='EMPLOYEE'?e.employee_id!==String(req.user.employeeId??req.user.employee_id):false))return res.status(403).json({ok:false,message:'Employee access denied.'});
   const clock=await pool.query('SELECT clock_timestamp()::text AS cutoff');const cutoff=String(clock.rows[0].cutoff);const loaded=await load(pool,year,month,ids,cutoff);if(loaded.some(e=>!scoped(req,e)))return res.status(403).json({ok:false,message:'Employee scope denied.'});const events=loaded;
   res.set?.('Cache-Control','no-store');return res.json({ok:true,cutoff,events});
  }catch(error){return fail(res,error);}
 });
 app.post('/api/attendance/early-out/decision',authenticate,async(req,res)=>{
  const role=approverRole(req),actor=String(req.user?.id??req.user?.username??'').trim();
  if(!role||!actor)return res.status(403).json({ok:false,message:'Admin or Accounts approval required.'});
  const b=req.body??{},when=String(b.attendance_date??''),parsed=new Date(when+'T00:00:00Z');
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(b.request_id??''))||!/^\d{4}-\d{2}-\d{2}$/.test(when)||!Number.isFinite(parsed.getTime())||date(parsed.toISOString())!==when||!validPeriod(parsed.getUTCFullYear(),parsed.getUTCMonth()+1)||typeof b.employee_id!=='string'||!b.employee_id.trim()||!['APPROVED','REJECTED'].includes(b.status)||!/^\d+$/.test(String(b.expected_revision??''))||!/^[a-f0-9]{64}$/.test(String(b.fingerprint??''))||!Number.isInteger(b.approved_minutes)||b.approved_minutes<0||typeof b.remarks!=='string'||b.remarks.trim().length<3||b.remarks.length>1000)return res.status(400).json({ok:false,message:'Invalid decision, duration or remarks.'});
  const client=await pool.connect();try{
   await client.query('BEGIN');await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[b.employee_id+'|'+when]);
   await client.query('SELECT employee_id FROM public.attendance WHERE employee_id=$1 AND attendance_date=$2::date FOR UPDATE',[b.employee_id,when]);
   const replay=await client.query('SELECT * FROM app_private.early_out_decisions WHERE request_id=$1',[b.request_id]);
   if(replay.rows.length){const r=replay.rows[0];if(r.employee_id!==b.employee_id||date(r.attendance_date)!==when||r.status!==b.status||Number(r.approved_minutes)!==b.approved_minutes||r.fingerprint!==b.fingerprint||r.remarks!==b.remarks.trim()||r.approver_user_id!==actor){await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Request ID already used for a different decision.'});}await client.query('COMMIT');return res.json({ok:true,decision:r,replayed:true,payroll_updated:false});}
   const events=await load(client,parsed.getUTCFullYear(),parsed.getUTCMonth()+1,[b.employee_id]);const e=events.find(e=>e.attendance_date===when);
   if(!e||!scoped(req,e)||!e.is_submitted){await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Submitted Early Out record not available.'});}
   if(e.fingerprint!==b.fingerprint||e.revision!==String(b.expected_revision)){await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'Attendance or approval changed. Refresh before reviewing.'});}
   if(e.approval_status===b.status&&Number(e.approved_minutes)===b.approved_minutes){await client.query('ROLLBACK');return res.status(409).json({ok:false,message:'This exact decision is already recorded.'});}
   if((b.status==='APPROVED'&&(b.approved_minutes<1||b.approved_minutes>e.eligible_early_minutes))||(b.status==='REJECTED'&&b.approved_minutes!==0)){await client.query('ROLLBACK');return res.status(400).json({ok:false,message:'Approved duration exceeds eligible Early Out shortfall.'});}
   const result=await client.query(`INSERT INTO app_private.early_out_decisions(request_id,employee_id,attendance_date,branch_id,fingerprint,status,approved_minutes,approver_role,approver_user_id,remarks,attendance_snapshot) VALUES($1,$2,$3::date,$4,$5,$6,$7,$8,$9,$10,$11::jsonb) RETURNING *,attendance_date::text`,[b.request_id,b.employee_id,when,e.branch_id,e.fingerprint,b.status,b.approved_minutes,role,actor,b.remarks.trim(),JSON.stringify(e)]);
   await client.query("INSERT INTO public.branch_activity_logs(branch_id,action,employee_id,employee_name,details) VALUES($1,$2,$3,$4,$5::jsonb)",[e.branch_id,'EARLY_OUT_'+b.status,e.employee_id,e.name,JSON.stringify({decision_id:result.rows[0].id,approver_role:role,approver_user_id:actor,approved_minutes:b.approved_minutes})]);
   await client.query('COMMIT');return res.json({ok:true,decision:result.rows[0],payroll_updated:false,message:'Decision saved. Existing payroll is unchanged; review and regenerate drafts or arrange an authorized adjustment for locked payroll.'});
  }catch(error){await client.query('ROLLBACK').catch(()=>{});return fail(res,error);}finally{client.release();}
 });
}
