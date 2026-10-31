import crypto from 'node:crypto';
import rateLimit from 'express-rate-limit';
import {hashQr,credential,validQr,validUuid,dayMY,clockMY,bool,QrError,nextPunch,newWorkDate,attendanceProposal} from './qr-attendance-core.js';
import {buildLateReport} from './late-report.js';
import {renderQrExport} from './qr-attendance-export.js';

const upper = value => String(value??'').trim().toUpperCase();
const actor = req => String(req.user?.username??req.auth?.sub??'');
const role = req => upper(req.user?.role);
const scope = req => req.auth?.app_metadata?.staff_scope??'';
const isAdmin = req => role(req)==='ADMIN' && !req.auth?.app_metadata?.is_reviewer && scope(req)!=='requests';
const isBranch = req => role(req)==='BRANCH' && !!branchOf(req);
const branchOf = req => String(req.user?.branchId??req.user?.branch_id??'').trim();
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const employeeSelect = 'e.employee_id,e.name,e.branch_id,e.is_active,e.address';
function ensureEmployeeScope(req,employee) {
  if (!employee) throw new QrError('NOT_FOUND','Employee not found.',404);
  if (isBranch(req) && upper(employee.branch_id)!==upper(branchOf(req))) throw new QrError('WRONG_BRANCH','Employee belongs to a different branch.',403);
  const foreign=upper(employee.address).includes('FRN');
  if ((scope(req)==='local'&&foreign)||(scope(req)==='foreign'&&!foreign)) throw new QrError('EMPLOYEE_SCOPE','Employee is outside this account scope.',403);
}
const publicEmployee = e => ({employee_id:e.employee_id,name:e.name,branch_id:e.branch_id,is_active:e.is_active});
async function employeeLock(client,id) { await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',['qr-employee:'+id]); }
async function audit(client,req,action,employeeId,branchId,details={}) {
  await client.query('INSERT INTO public.qr_attendance_audit(employee_id,branch_id,operator,action,details) VALUES($1,$2,$3,$4,$5)',[employeeId,branchId,actor(req),action,JSON.stringify(details)]);
}
async function transaction(pool,callback) {
  const client=await pool.connect();
  try {await client.query('BEGIN');const value=await callback(client);await client.query('COMMIT');return value;}
  catch(error){await client.query('ROLLBACK').catch(()=>{});throw error;} finally {client.release();}
}
async function session(client,req,id,readOnly=false) {
  if (!validUuid(id)) throw new QrError('SESSION_REQUIRED','Start a registered scanner session first.',403);
  const found=await client.query(`SELECT s.id AS session_id,s.operator,t.* FROM public.qr_attendance_sessions s
    JOIN public.qr_attendance_stations t ON t.id=s.station_id WHERE s.id=$1 AND s.operator=$2
    AND ($3 OR (s.revoked_at IS NULL AND s.expires_at>clock_timestamp() AND t.enabled)) FOR SHARE OF s,t`,[id,actor(req),readOnly]);
  const station=found.rows[0];
  if (!station||upper(station.branch_id)!==upper(branchOf(req))) throw new QrError('SESSION_EXPIRED','Scanner session expired or revoked. Start a new session.',403);
  return station;
}
async function qrEmployee(client,req,token) {
  if (!validQr(token)) throw new QrError('INVALID_QR','Invalid QR. Use a Hasani-issued card.',400);
  const found=await client.query(`SELECT ${employeeSelect} FROM public.qr_attendance_credentials c
    JOIN public.employees e ON e.employee_id=c.employee_id WHERE c.token_hash=$1`,[hashQr(token)]);
  if (!found.rows[0]) throw new QrError('UNKNOWN_QR','Unknown QR card. Ask an administrator to issue a card.',404);
  await employeeLock(client,found.rows[0].employee_id);
  const current=await client.query(`SELECT ${employeeSelect},c.revoked_at,c.expires_at FROM public.qr_attendance_credentials c
    JOIN public.employees e ON e.employee_id=c.employee_id WHERE c.token_hash=$1 FOR SHARE OF c,e`,[hashQr(token)]);
  const e=current.rows[0];
  if (!e||e.revoked_at||(e.expires_at&&new Date(e.expires_at)<=new Date())) throw new QrError('REVOKED_QR','QR card is revoked or expired. Request a replacement.',410);
  ensureEmployeeScope(req,e);
  if (!bool(e.is_active)) throw new QrError('INACTIVE_EMPLOYEE','Inactive employees cannot record attendance.',403);
  return e;
}
async function effective(client,id,date=null) {
  return (await client.query(`SELECT *,work_date::text FROM public.qr_attendance_effective_events WHERE employee_id=$1
    ${date?'AND work_date=$2::date':''} ORDER BY scanned_at,event_key`,date?[id,date]:[id])).rows;
}
async function attemptResponse(client,attempt) {
  if (attempt.status==='REJECTED') return {ok:false,code:attempt.code,message:attempt.message,http_status:attempt.http_status,request_id:attempt.request_id,attempt_recorded:true};
  const result=await client.query(`SELECT v.id AS event_id,v.action,v.scanned_at,v.work_date::text,e.employee_id,e.name,e.branch_id
    FROM public.qr_attendance_events v JOIN public.employees e ON e.employee_id=v.employee_id WHERE v.id=$1`,[attempt.event_id]);
  return {ok:true,...result.rows[0],request_id:attempt.request_id,replayed:true,attempt_recorded:true};
}
async function refreshPresence(client,id) {
  await client.query(`INSERT INTO public.qr_attendance_presence(employee_id,branch_id,action,work_date,scanned_at,raw_id,event_key)
    SELECT employee_id,branch_id,action,work_date,scanned_at,raw_id,event_key FROM public.qr_attendance_effective_events WHERE employee_id=$1
    ORDER BY scanned_at DESC,event_key DESC LIMIT 1 ON CONFLICT(employee_id) DO UPDATE
    SET branch_id=EXCLUDED.branch_id,action=EXCLUDED.action,work_date=EXCLUDED.work_date,scanned_at=EXCLUDED.scanned_at,raw_id=EXCLUDED.raw_id,event_key=EXCLUDED.event_key`,[id]);
  // If every raw punch was voided, there is no current presence to display.
  await client.query('DELETE FROM public.qr_attendance_presence WHERE employee_id=$1 AND NOT EXISTS(SELECT 1 FROM public.qr_attendance_effective_events WHERE employee_id=$1)',[id]);
}
function handler(pool,permission,callback) {
  return async(req,res)=>{
    if (!permission(req)) return res.status(403).json({ok:false,code:'ACCESS_DENIED',message:'Authorized administrator or branch scanner access required.'});
    try {const result=await callback(req);res.status(result.http_status??200).json(result);}
    catch(error) {
      if (error instanceof QrError) return res.status(error.status).json({ok:false,code:error.code,message:error.message});
      console.error('QR attendance operation failed:',error.code??'unavailable');
      res.status(503).json({ok:false,code:'UNAVAILABLE',message:'QR service unavailable. For a submitted scan, check its request status before retrying.'});
    }
  };
}
function validDate(value) {
  return datePattern.test(value)&&Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;
}
function selection(req) {
  const date=String(req.query.date??dayMY(new Date()));
  if (!validDate(date)) throw new QrError('INVALID_DATE','Invalid report date.',400);
  const branch=isBranch(req)?branchOf(req):String(req.query.branch_id??'').trim();
  if (isBranch(req)&&req.query.branch_id&&upper(req.query.branch_id)!==upper(branch)) throw new QrError('WRONG_BRANCH','Branch access denied.',403);
  return {date,branch};
}

export function installQrAttendanceApi(app,pool,authenticate,{exportReport=renderQrExport,enabled=false}={}) {
  if (!enabled) {
    app.use('/api/qr-attendance',authenticate,(_req,res)=>res.status(503).json({ok:false,code:'QR_DISABLED',message:'QR attendance is disabled until the approved migration and staging checks are completed.'}));
    return;
  }
  const manage=rateLimit({windowMs:60000,limit:30,standardHeaders:true,legacyHeaders:false,message:{ok:false,code:'RATE_LIMITED',message:'Too many QR requests. Wait before trying again.'}});
  const scanLimit=rateLimit({windowMs:60000,limit:120,standardHeaders:true,legacyHeaders:false,message:{ok:false,code:'RATE_LIMITED',message:'Too many QR requests. Wait before trying again.'}});
  const readLimit=rateLimit({windowMs:60000,limit:180,standardHeaders:true,legacyHeaders:false,message:{ok:false,code:'RATE_LIMITED',message:'Too many QR requests. Wait before trying again.'}});
  const get=(path,permission,fn)=>app.get('/api/qr-attendance'+path,authenticate,readLimit,handler(pool,permission,fn));
  const post=(path,permission,fn,limiter=manage)=>app.post('/api/qr-attendance'+path,authenticate,limiter,handler(pool,permission,fn));

  get('/employees',isAdmin,async req=>{
    const q=String(req.query.q??'').trim().slice(0,100);
    const rows=await pool.query(`SELECT ${employeeSelect},c.issued_at,c.revoked_at,c.expires_at
      FROM public.employees e LEFT JOIN public.qr_attendance_credentials c ON c.employee_id=e.employee_id
      WHERE ($1='' OR e.employee_id ILIKE $2 OR e.name ILIKE $2) ORDER BY e.name`,[q,'%'+q+'%']);
    const employees=rows.rows.filter(e=>{
      try {ensureEmployeeScope(req,e);return true;}catch{return false;}
    }).filter(e=>!req.query.branch_id||upper(e.branch_id)===upper(req.query.branch_id));
    return {ok:true,employees:employees.map(e=>({...publicEmployee(e),issued_at:e.issued_at,revoked_at:e.revoked_at,expires_at:e.expires_at}))};
  });
  post('/issue',isAdmin,async req=>{
    const ids=req.body?.employee_ids??[req.body?.employee_id];
    if (!Array.isArray(ids)||!ids.length||ids.length>100||ids.some(id=>typeof id!=='string'||!id.trim()||id.length>80)||new Set(ids).size!==ids.length)
      throw new QrError('INVALID_EMPLOYEES','Choose 1 to 100 unique employees.',400);
    return transaction(pool,async client=>{
      const cards=[];
      for(const id of [...ids].sort()) {
        await employeeLock(client,id);
        const e=(await client.query(`SELECT ${employeeSelect} FROM public.employees e WHERE e.employee_id=$1 FOR SHARE`,[id])).rows[0];
        ensureEmployeeScope(req,e);
        if (!bool(e.is_active)) throw new QrError('INACTIVE_EMPLOYEE','Only active employees can receive a QR card.',409);
        const token=credential();
        const previous=await client.query('SELECT issued_at,revoked_at FROM public.qr_attendance_credentials WHERE employee_id=$1',[id]);
        await client.query(`INSERT INTO public.qr_attendance_credentials(employee_id,token_hash,issued_at,issued_by,revoked_at)
          VALUES($1,$2,clock_timestamp(),$3,NULL) ON CONFLICT(employee_id) DO UPDATE
          SET token_hash=EXCLUDED.token_hash,issued_at=EXCLUDED.issued_at,issued_by=EXCLUDED.issued_by,revoked_at=NULL,expires_at=NULL`,[id,hashQr(token),actor(req)]);
        await audit(client,req,previous.rowCount?'CARD_REISSUED':'CARD_ISSUED',id,e.branch_id,{previous_issued_at:previous.rows[0]?.issued_at??null});
        cards.push({...publicEmployee(e),qr_value:token});
      }
      return {ok:true,cards,...(cards.length===1?cards[0]:{}),message:'Credentials are shown once. Reissuing immediately invalidates the previous card.'};
    });
  });
  post('/revoke',isAdmin,async req=>transaction(pool,async client=>{
    const id=String(req.body?.employee_id??'');await employeeLock(client,id);
    const e=(await client.query(`SELECT ${employeeSelect} FROM public.employees e WHERE e.employee_id=$1`,[id])).rows[0];ensureEmployeeScope(req,e);
    await client.query('UPDATE public.qr_attendance_credentials SET revoked_at=clock_timestamp() WHERE employee_id=$1 AND revoked_at IS NULL',[id]);
    await audit(client,req,'CARD_REVOKED',id,e.branch_id);return {ok:true};
  }));
  get('/credentials/:employeeId/history',isAdmin,async req=>{
    const id=req.params.employeeId;
    const e=(await pool.query(`SELECT ${employeeSelect} FROM public.employees e WHERE employee_id=$1`,[id])).rows[0];ensureEmployeeScope(req,e);
    const rows=await pool.query("SELECT id,action,operator,details,created_at FROM public.qr_attendance_audit WHERE employee_id=$1 AND action IN ('CARD_ISSUED','CARD_REISSUED','CARD_REVOKED') ORDER BY id DESC LIMIT 200",[id]);
    return {ok:true,history:rows.rows};
  });
  get('/stations',req=>isAdmin(req)||isBranch(req),async req=>{
    const result=await pool.query(`SELECT id,branch_id,label,enabled,min_interval_seconds,max_open_hours,allow_multiple_sessions,verification_required
      FROM public.qr_attendance_stations WHERE ($1='' OR upper(branch_id)=upper($1)) ORDER BY branch_id,label`,[isBranch(req)?branchOf(req):'']);
    return {ok:true,stations:result.rows};
  });
  post('/stations',isAdmin,async req=>transaction(pool,async client=>{
    const body=req.body??{},id=body.id??crypto.randomUUID(),branch=String(body.branch_id??'').trim(),label=String(body.label??'').trim();
    const min=Number(body.min_interval_seconds??60),max=Number(body.max_open_hours??36);
    if (!validUuid(id)||!branch||!label||label.length>80||!Number.isInteger(min)||min<1||min>3600||!Number.isInteger(max)||max<1||max>168)
      throw new QrError('INVALID_STATION','Supply a branch, label and valid station policy.',400);
    if (!(await client.query('SELECT id FROM public.branches WHERE upper(id::text)=upper($1)',[branch])).rowCount) throw new QrError('UNKNOWN_BRANCH','Unknown branch.',400);
    const existing=(await client.query('SELECT branch_id FROM public.qr_attendance_stations WHERE id=$1 FOR UPDATE',[id])).rows[0];
    if (existing&&upper(existing.branch_id)!==upper(branch)) throw new QrError('STATION_BRANCH','Create a new station instead of changing its branch.',409);
    await client.query(`INSERT INTO public.qr_attendance_stations(id,branch_id,label,min_interval_seconds,max_open_hours,allow_multiple_sessions,verification_required,enabled,created_by)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT(id) DO UPDATE SET label=EXCLUDED.label,min_interval_seconds=EXCLUDED.min_interval_seconds,
      max_open_hours=EXCLUDED.max_open_hours,allow_multiple_sessions=EXCLUDED.allow_multiple_sessions,verification_required=EXCLUDED.verification_required,enabled=EXCLUDED.enabled`,
      [id,branch,label,min,max,body.allow_multiple_sessions!==false,body.verification_required!==false,body.enabled!==false,actor(req)]);
    await audit(client,req,'STATION_POLICY',null,branch,{station_id:id,min_interval_seconds:min,max_open_hours:max,verification_required:body.verification_required!==false,enabled:body.enabled!==false});
    return {ok:true,id};
  }));
  post('/session',isBranch,async req=>transaction(pool,async client=>{
    if (!validUuid(req.body?.station_id)) throw new QrError('INVALID_STATION','Choose a registered station.',400);
    const station=(await client.query('SELECT * FROM public.qr_attendance_stations WHERE id=$1 AND enabled FOR SHARE',[req.body.station_id])).rows[0];
    if (!station||upper(station.branch_id)!==upper(branchOf(req))) throw new QrError('WRONG_BRANCH','Station is unavailable for this branch.',403);
    const id=crypto.randomUUID();
    const row=(await client.query('INSERT INTO public.qr_attendance_sessions(id,station_id,operator) VALUES($1,$2,$3) RETURNING id,expires_at',[id,station.id,actor(req)])).rows[0];
    await audit(client,req,'SESSION_STARTED',null,station.branch_id,{session_id:id,station_id:station.id});
    return {ok:true,...row,station};
  }));
  post('/session/revoke',req=>isAdmin(req)||isBranch(req),async req=>transaction(pool,async client=>{
    const id=req.body?.session_id;
    if (!validUuid(id)) throw new QrError('INVALID_SESSION','Invalid session.',400);
    const result=await client.query(`UPDATE public.qr_attendance_sessions SET revoked_at=clock_timestamp() WHERE id=$1
      AND ($2 OR operator=$3) RETURNING station_id`,[id,isAdmin(req),actor(req)]);
    if (!result.rowCount) throw new QrError('NOT_FOUND','Session not found.',404);
    await audit(client,req,'SESSION_REVOKED',null,isBranch(req)?branchOf(req):null,{session_id:id});return {ok:true};
  }));
  post('/preview',isBranch,async req=>transaction(pool,async client=>{
    const station=await session(client,req,req.body?.session_id);
    const token=String(req.body?.qr_value??'').trim();
    let e;
    try { e=await qrEmployee(client,req,token); }
    catch(error) {
      if (!(error instanceof QrError)) throw error;
      await audit(client,req,'PREVIEW_REJECTED',null,station.branch_id,{code:error.code,message:error.message});
      return {ok:false,http_status:error.status,code:error.code,message:error.message};
    }
    const ticket=crypto.randomBytes(32).toString('base64url');
    await client.query('INSERT INTO public.qr_attendance_verifications(ticket_hash,session_id,employee_id,credential_hash) VALUES($1,$2,$3,$4)',[hashQr(ticket),req.body.session_id,e.employee_id,hashQr(token)]);
    return {ok:true,employee:publicEmployee(e),verification_token:ticket,verification_required:station.verification_required};
  }),scanLimit);
  post('/scan',isBranch,async req=>{
    const body=req.body??{},requestId=body.request_id,sessionId=body.session_id,token=String(body.qr_value??'').trim();
    if (!validUuid(requestId)) throw new QrError('REQUEST_ID_REQUIRED','A unique scan request identifier is required.',400);
    return transaction(pool,async client=>{
      const station=await session(client,req,sessionId);
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',['qr-request:'+sessionId+':'+requestId]);
      const old=(await client.query('SELECT * FROM public.qr_attendance_attempts WHERE session_id=$1 AND request_id=$2',[sessionId,requestId])).rows[0];
      if (old) {
        if (old.credential_hash!==hashQr(token)) throw new QrError('REQUEST_CONFLICT','This request identifier belongs to a different scan.',409);
        return attemptResponse(client,old);
      }
      let employee=null,result;
      try {
        employee=await qrEmployee(client,req,token);
        const now=(await client.query('SELECT clock_timestamp() AS ts')).rows[0].ts;
        const presence=(await client.query('SELECT *,work_date::text FROM public.qr_attendance_presence WHERE employee_id=$1',[employee.employee_id])).rows[0];
        const previous=presence??(await client.query(`SELECT *,work_date::text FROM public.qr_attendance_effective_events
          WHERE employee_id=$1 ORDER BY scanned_at DESC,event_key DESC LIMIT 1`,[employee.employee_id])).rows[0];
        const next=nextPunch(previous,now,station);
        if (next.action==='IN') {
          const previousDate=new Date(Date.parse(dayMY(now))-86400000).toISOString().slice(0,10);
          const daily=(await client.query('SELECT to_jsonb(r) AS data FROM public.daily_rosters r WHERE employee_id=$1 AND upper(branch_id)=upper($2) AND roster_date=$3::date LIMIT 1',[employee.employee_id,employee.branch_id,previousDate])).rows[0]?.data;
          const weekly=daily?null:(await client.query('SELECT to_jsonb(r) AS data FROM public.monthly_rosters r WHERE employee_id=$1 AND upper(branch_id)=upper($2) AND roster_year=$3 AND roster_month=$4 AND week_number=$5 LIMIT 1',
            [employee.employee_id,employee.branch_id,Number(previousDate.slice(0,4)),Number(previousDate.slice(5,7)),Math.floor((Number(previousDate.slice(8))-1)/7)+1])).rows[0]?.data;
          next.work_date=newWorkDate(now,daily??weekly);
          if (!station.allow_multiple_sessions&&previous?.action==='OUT'&&String(previous.work_date).slice(0,10)===next.work_date) throw new QrError('DAY_COMPLETE','This station permits one session per work date.');
        }

        if (station.verification_required) {
          const ticketHash=hashQr(String(body.verification_token??''));
          const verified=await client.query(`UPDATE public.qr_attendance_verifications SET used_at=clock_timestamp()
            WHERE ticket_hash=$1 AND session_id=$2 AND employee_id=$3 AND credential_hash=$4
            AND used_at IS NULL AND expires_at>clock_timestamp() RETURNING ticket_hash`,[ticketHash,sessionId,employee.employee_id,hashQr(token)]);
          if (!verified.rowCount) throw new QrError('VERIFICATION_REQUIRED','Supervisor photo verification is required. Scan again and confirm the employee.',403);
        }
        const event=(await client.query(`INSERT INTO public.qr_attendance_events(employee_id,branch_id,action,scanned_at,scanned_by,session_id,request_id,work_date,paired_event_id,verified_by)
          VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id,scanned_at`,[employee.employee_id,employee.branch_id,next.action,now,actor(req),sessionId,requestId,next.work_date,next.paired_event_id,station.verification_required?actor(req):null])).rows[0];
        await client.query(`INSERT INTO public.qr_attendance_presence(employee_id,branch_id,action,work_date,scanned_at,raw_id,event_key)
          VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(employee_id) DO UPDATE SET branch_id=EXCLUDED.branch_id,action=EXCLUDED.action,
          work_date=EXCLUDED.work_date,scanned_at=EXCLUDED.scanned_at,raw_id=EXCLUDED.raw_id,event_key=EXCLUDED.event_key`,[employee.employee_id,employee.branch_id,next.action,next.work_date,now,event.id,'E'+event.id]);
        result={ok:true,code:'RECORDED',message:'Attendance recorded.',...publicEmployee(employee),...next,event_id:event.id,scanned_at:event.scanned_at,request_id:requestId};
        await audit(client,req,'PUNCH_'+next.action,employee.employee_id,employee.branch_id,{event_id:event.id,request_id:requestId,session_id:sessionId,verified:station.verification_required});
      } catch(error) {
        if (!(error instanceof QrError)) throw error;
        result={ok:false,code:error.code,message:error.message,http_status:error.status,request_id:requestId};
      }
      await client.query(`INSERT INTO public.qr_attendance_attempts(session_id,request_id,credential_hash,employee_id,branch_id,operator,status,code,message,http_status,event_id)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,[sessionId,requestId,hashQr(token),employee?.employee_id??null,station.branch_id,actor(req),result.ok?'ACCEPTED':'REJECTED',result.code,result.message,result.http_status??200,result.event_id??null]);
      result.attempt_recorded=true;
      return result;
    });
  },scanLimit);
  post('/requests/cancel',isBranch,async req=>transaction(pool,async client=>{
    const station=await session(client,req,req.body?.session_id,true),id=req.body?.request_id;
    if(!validUuid(id))throw new QrError('INVALID_REQUEST','Invalid request identifier.',400);
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',['qr-request:'+req.body.session_id+':'+id]);
    const previous=(await client.query('SELECT * FROM public.qr_attendance_attempts WHERE session_id=$1 AND request_id=$2',[req.body.session_id,id])).rows[0];
    if(previous?.status==='ACCEPTED')return attemptResponse(client,previous);
    if(!previous)await client.query(`INSERT INTO public.qr_attendance_attempts(session_id,request_id,credential_hash,branch_id,operator,status,code,message,http_status)
      VALUES($1,$2,$3,$4,$5,'REJECTED','CANCELLED','Request cancelled without recording a punch.',409)`,[req.body.session_id,id,hashQr('cancelled:'+id),station.branch_id,actor(req)]);
    await audit(client,req,'SCAN_CANCELLED',null,station.branch_id,{request_id:id,session_id:req.body.session_id});
    return {ok:true,cancelled:true,request_id:id,attempt_recorded:true};
  }));
  get('/requests/:requestId',isBranch,async req=>transaction(pool,async client=>{
    await session(client,req,req.query.session_id,true);
    if (!validUuid(req.params.requestId)) throw new QrError('INVALID_REQUEST','Invalid request identifier.',400);
    const attempt=(await client.query('SELECT * FROM public.qr_attendance_attempts WHERE session_id=$1 AND request_id=$2',[req.query.session_id,req.params.requestId])).rows[0];
    return attempt?attemptResponse(client,attempt):{ok:true,state:'NOT_FOUND',message:'No committed result yet. Retry only the original request identifier.'};
  }));

  get('/dashboard',req=>isAdmin(req)||isBranch(req),async req=>dashboard(pool,req));
  get('/export',req=>isAdmin(req)||isBranch(req),async req=>{
    if (!['pdf','xlsx'].includes(req.query.format)) throw new QrError('INVALID_FORMAT','Choose PDF or Excel.',400);
    const data=await dashboard(pool,req);
    const bytes=await exportReport({...data,format:req.query.format});
    return {ok:true,file_base64:bytes.toString('base64')};
  });
  get('/audit',req=>isAdmin(req)||isBranch(req),async req=>{
    const {date,branch}=selection(req);
    const rows=await pool.query(`SELECT a.id,a.employee_id,a.branch_id,a.operator,a.action,a.details,a.created_at
      FROM public.qr_attendance_audit a LEFT JOIN public.employees e ON e.employee_id=a.employee_id
      WHERE (a.created_at AT TIME ZONE 'Asia/Kuala_Lumpur')::date=$1::date AND ($2='' OR upper(a.branch_id)=upper($2))
      AND ($3 NOT IN ('local','foreign') OR ($3='local' AND COALESCE(e.address,'') NOT ILIKE '%FRN%') OR ($3='foreign' AND e.address ILIKE '%FRN%'))
      ORDER BY a.id DESC LIMIT 1000`,[date,branch,scope(req)]);
    return {ok:true,audit:rows.rows};
  });
  get('/reconciliation',isAdmin,async req=>{
    const id=String(req.query.employee_id??''),date=String(req.query.date??'');
    if (!validDate(date)) throw new QrError('INVALID_DATE','Select the work date.',400);
    const e=(await pool.query(`SELECT ${employeeSelect} FROM public.employees e WHERE employee_id=$1`,[id])).rows[0];ensureEmployeeScope(req,e);
    const events=await effective(pool,id,date),proposal=attendanceProposal(events);
    const current=(await pool.query('SELECT to_jsonb(a) AS data FROM public.attendance a WHERE employee_id=$1 AND attendance_date=$2::date',[id,date])).rows[0]?.data??null;
    return {ok:true,employee:publicEmployee(e),events,proposal,current};
  });
  post('/reconcile',isAdmin,async req=>transaction(pool,async client=>{
    const id=String(req.body?.employee_id??''),date=String(req.body?.date??'');
    if (!validDate(date)) throw new QrError('INVALID_DATE','Invalid work date.',400);
    await employeeLock(client,id);
    const e=(await client.query(`SELECT ${employeeSelect} FROM public.employees e WHERE employee_id=$1 FOR SHARE`,[id])).rows[0];ensureEmployeeScope(req,e);
    const events=await effective(client,id,date),proposal=attendanceProposal(events);
    if (!proposal.valid) throw new QrError('INCOMPLETE_PUNCHES',proposal.issues.join('. '));
    if (proposal.fingerprint!==req.body?.fingerprint) throw new QrError('STALE_PROPOSAL','Punches changed. Review the proposal again.');
    if (events.some(event=>upper(event.branch_id)!==upper(e.branch_id))) throw new QrError('TRANSFER_REVIEW','Historical branch differs. Review the transfer manually in the Attendance Sheet.');
    const previous=(await client.query('SELECT to_jsonb(a) AS data FROM public.attendance a WHERE employee_id=$1 AND attendance_date=$2::date FOR UPDATE',[id,date])).rows[0]?.data??null;
    if (previous&&(bool(previous.is_submitted)||bool(previous.ot_authorized)||previous.approved_ot_minutes!=null)) throw new QrError('ATTENDANCE_LOCKED','Submitted or OT-approved attendance cannot be overwritten.');
    if (previous&&(bool(previous.ot_requested)||['overtime_in','overtime_out','overtime_minutes','approved_ot_minutes'].some(field=>previous[field]!=null&&!['','-','0'].includes(String(previous[field]))))) throw new QrError('OT_REVIEW','Existing overtime timing or an OT request requires manual Attendance Sheet review.');
    if (previous?.status&&!['PRESENT','LATE'].includes(upper(previous.status))) throw new QrError('STATUS_CONFLICT','Existing leave or special status requires manual Attendance Sheet review.');
    const cols=(await client.query("SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='attendance'")).rows.map(r=>r.column_name);
    const needed=['employee_id','branch_id','attendance_date','check_in','check_out','work_minutes','break_minutes','is_submitted','ot_authorized','approved_ot_minutes'];
    if (needed.some(field=>!cols.includes(field))) throw new QrError('SCHEMA_REVIEW','Attendance schema lacks required lock or time fields. Validate staging compatibility before reconciliation.');
    const values={employee_id:id,branch_id:e.branch_id,attendance_date:date,...proposal.fields};
    if (!previous) values.status='Present';
    const keys=Object.keys(values).filter(field=>cols.includes(field));
    const updates=keys.filter(field=>!['employee_id','branch_id','attendance_date','status'].includes(field)).map(field=>`"${field}"=EXCLUDED."${field}"`).join(',');
    const result=await client.query(`INSERT INTO public.attendance (${keys.map(k=>'"'+k+'"').join(',')}) VALUES(${keys.map((_,i)=>'$'+(i+1)).join(',')})
      ON CONFLICT(employee_id,attendance_date) DO UPDATE SET ${updates}
      WHERE COALESCE(attendance.is_submitted,false)=false AND COALESCE(attendance.ot_authorized,false)=false AND attendance.approved_ot_minutes IS NULL
      AND COALESCE(to_jsonb(attendance)->>'ot_requested','false') NOT IN ('true','1')
      AND COALESCE(to_jsonb(attendance)->>'overtime_in','') IN ('','-') AND COALESCE(to_jsonb(attendance)->>'overtime_out','') IN ('','-')
      AND upper(COALESCE(attendance.status::text,'')) IN ('','PRESENT','LATE') AND upper(attendance.branch_id)=upper(EXCLUDED.branch_id)
      RETURNING to_jsonb(attendance) AS data`,keys.map(k=>values[k]));
    if (!result.rowCount) throw new QrError('ATTENDANCE_LOCKED','Attendance changed or was submitted. Refresh and review.');
    await client.query(`INSERT INTO public.qr_attendance_reconciliations(employee_id,branch_id,work_date,fingerprint,source_events,previous_attendance,approved_attendance,approved_by)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(employee_id,work_date,fingerprint) DO NOTHING`,[id,e.branch_id,date,proposal.fingerprint,JSON.stringify(events),previous?JSON.stringify(previous):null,JSON.stringify(result.rows[0].data),actor(req)]);
    await audit(client,req,'RECONCILED',id,e.branch_id,{work_date:date,fingerprint:proposal.fingerprint});return {ok:true,attendance:result.rows[0].data};
  }));
  post('/corrections',req=>isAdmin(req)||isBranch(req),async req=>transaction(pool,async client=>{
    const body=req.body??{},id=String(body.employee_id??''),date=String(body.date??''),action=upper(body.action),reason=String(body.reason??'').trim(),timestamp=new Date(body.corrected_at);
    if (!validDate(date)||!['IN','OUT','VOID'].includes(action)||reason.length<5||reason.length>1000||!Number.isFinite(timestamp.getTime())||timestamp>new Date()) throw new QrError('INVALID_CORRECTION','Supply a past timestamp, work date, action and reason of at least five characters.',400);
    if (action==='VOID'&&!body.event_id) throw new QrError('INVALID_CORRECTION','VOID requires an original event.',400);
    const e=(await client.query(`SELECT ${employeeSelect} FROM public.employees e WHERE employee_id=$1`,[id])).rows[0];ensureEmployeeScope(req,e);
    const eventId=body.event_id??null;
    const correctionBranch=isAdmin(req)?String(body.branch_id??e.branch_id):e.branch_id;
    if (upper(correctionBranch)!==upper(e.branch_id)&&!(await client.query('SELECT id FROM public.qr_attendance_events WHERE employee_id=$1 AND work_date=$2::date AND upper(branch_id)=upper($3) LIMIT 1',[id,date,correctionBranch])).rowCount) throw new QrError('TRANSFER_REVIEW','No original punches establish this historical branch.',400);
    if (eventId&&!(await client.query('SELECT id FROM public.qr_attendance_events WHERE id=$1 AND employee_id=$2 AND work_date=$3::date AND upper(branch_id)=upper($4)',[eventId,id,date,correctionBranch])).rowCount) throw new QrError('INVALID_EVENT','Original event does not match this employee, branch and work date.',400);
    const row=(await client.query(`INSERT INTO public.qr_attendance_corrections(employee_id,branch_id,work_date,event_id,action,corrected_at,reason,requested_by)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,[id,correctionBranch,date,eventId,action,timestamp,reason,actor(req)])).rows[0];
    await audit(client,req,'CORRECTION_REQUESTED',id,correctionBranch,{correction_id:row.id,reason});return {ok:true,id:row.id};
  }));
  get('/corrections',req=>isAdmin(req)||isBranch(req),async req=>{
    const {date,branch}=selection(req);
    const result=await pool.query(`SELECT c.* FROM public.qr_attendance_corrections c JOIN public.employees e ON e.employee_id=c.employee_id
      WHERE c.work_date=$1::date AND ($2='' OR upper(c.branch_id)=upper($2))
      AND ($3 NOT IN ('local','foreign') OR ($3='local' AND COALESCE(e.address,'') NOT ILIKE '%FRN%') OR ($3='foreign' AND e.address ILIKE '%FRN%')) ORDER BY id DESC`,[date,branch,scope(req)]);
    return {ok:true,corrections:result.rows};
  });
  post('/corrections/review',isAdmin,async req=>transaction(pool,async client=>{
    const ids=req.body?.ids??[req.body?.id],approved=req.body?.approved===true;
    if (!Array.isArray(ids)||!ids.length||ids.length>20||ids.some(id=>!/^\d+$/.test(String(id)))||new Set(ids.map(String)).size!==ids.length||typeof req.body?.approved!=='boolean') throw new QrError('INVALID_REVIEW','Choose up to 20 corrections and an explicit approve or reject action.',400);
    const candidate=(await client.query('SELECT employee_id FROM public.qr_attendance_corrections WHERE id=$1',[ids[0]])).rows[0];
    if (!candidate) throw new QrError('NOT_FOUND','Correction not found.',404);
    await employeeLock(client,candidate.employee_id);
    const corrections=(await client.query('SELECT c.*,c.work_date::text FROM public.qr_attendance_corrections c WHERE c.id=ANY($1::bigint[]) ORDER BY c.work_date,c.id FOR UPDATE',[ids])).rows;
    if(corrections.length!==ids.length||corrections.some(c=>c.employee_id!==candidate.employee_id))throw new QrError('INVALID_REVIEW','Review one employee at a time.',400);
    const e=(await client.query(`SELECT ${employeeSelect} FROM public.employees e WHERE employee_id=$1`,[candidate.employee_id])).rows[0];ensureEmployeeScope(req,e);
    for(const c of corrections) {
      if(c.status!=='PENDING')throw new QrError('ALREADY_REVIEWED','A correction was already reviewed.');
      const current=(await client.query('SELECT to_jsonb(a) AS data FROM public.attendance a WHERE employee_id=$1 AND attendance_date=$2::date FOR UPDATE',[c.employee_id,c.work_date])).rows[0]?.data;
      if(approved&&current&&(bool(current.is_submitted)||bool(current.ot_authorized)||current.approved_ot_minutes!=null))throw new QrError('ATTENDANCE_LOCKED','Unlock through the existing administrator workflow before correcting submitted or approved attendance.');
    }
    const before=approved?await effective(client,candidate.employee_id):[];
    await client.query('UPDATE public.qr_attendance_corrections SET status=$2,reviewed_by=$3,reviewed_at=clock_timestamp() WHERE id=ANY($1::bigint[])',[ids,approved?'APPROVED':'REJECTED',actor(req)]);
    if(approved) {
      const after=await effective(client,candidate.employee_id);
      const issues=events=>events.reduce((count,event,index)=>count+(event.action!==(index%2?'OUT':'IN')?1:0)+
        (index&&new Date(event.scanned_at)<=new Date(events[index-1].scanned_at)?1:0)+
        (index%2&&(event.work_date!==events[index-1].work_date||upper(event.branch_id)!==upper(events[index-1].branch_id))?1:0),0);
      const afterIssues=issues(after);
      if(afterIssues&&afterIssues>=issues(before))throw new QrError('IMPOSSIBLE_CORRECTION','Correction would create an impossible IN/OUT sequence. Review related corrections together.');
      await refreshPresence(client,candidate.employee_id);
    }
    for(const c of corrections)await audit(client,req,approved?'CORRECTION_APPROVED':'CORRECTION_REJECTED',c.employee_id,c.branch_id,{correction_id:c.id,reason:c.reason,batch:ids});
    return {ok:true};
  }));
}

async function dashboard(pool,req) {
  const {date,branch}=selection(req),q=upper(req.query.q);
  const [eventRows,attemptRows,daily,monthly,previewRejects]=await Promise.all([
    pool.query(`SELECT v.*,v.work_date::text,e.name,e.address,e.is_active FROM public.qr_attendance_effective_events v
      JOIN public.employees e ON e.employee_id=v.employee_id WHERE (v.work_date=$1::date OR (v.employee_id,v.work_date) IN (
        SELECT employee_id,work_date FROM public.qr_attendance_events WHERE scanned_at>=($1::date::timestamp AT TIME ZONE 'Asia/Kuala_Lumpur') AND scanned_at<(($1::date+1)::timestamp AT TIME ZONE 'Asia/Kuala_Lumpur')
        UNION SELECT employee_id,work_date FROM public.qr_attendance_corrections WHERE status='APPROVED' AND corrected_at>=($1::date::timestamp AT TIME ZONE 'Asia/Kuala_Lumpur') AND corrected_at<(($1::date+1)::timestamp AT TIME ZONE 'Asia/Kuala_Lumpur')
      ) OR ($3 AND EXISTS (SELECT 1 FROM public.qr_attendance_presence p WHERE p.employee_id=v.employee_id AND p.action='IN' AND p.work_date=v.work_date AND p.work_date<$1::date))) AND ($2='' OR upper(v.branch_id)=upper($2)) ORDER BY v.scanned_at`,[date,branch,date===dayMY(new Date())]),
    pool.query(`SELECT a.request_id,a.employee_id,a.branch_id,a.operator,a.code,a.message,a.status,a.attempted_at,count(*) FILTER (WHERE a.status='REJECTED') OVER() AS rejected_total FROM public.qr_attendance_attempts a
      LEFT JOIN public.employees e ON e.employee_id=a.employee_id WHERE (a.attempted_at AT TIME ZONE 'Asia/Kuala_Lumpur')::date=$1::date
      AND ($2='' OR upper(a.branch_id)=upper($2)) AND ($3 NOT IN ('local','foreign') OR ($3='local' AND COALESCE(e.address,'') NOT ILIKE '%FRN%') OR ($3='foreign' AND e.address ILIKE '%FRN%'))
      ORDER BY attempted_at DESC LIMIT 1000`,[date,branch,scope(req)]),
    pool.query("SELECT to_jsonb(r) AS data FROM public.daily_rosters r WHERE roster_date BETWEEN $1::date-INTERVAL '7 days' AND $1::date",[date]),
    pool.query("SELECT to_jsonb(r) AS data FROM public.monthly_rosters r WHERE (roster_year=EXTRACT(YEAR FROM $1::date) AND roster_month=EXTRACT(MONTH FROM $1::date)) OR (roster_year=EXTRACT(YEAR FROM ($1::date-INTERVAL '1 month')) AND roster_month=EXTRACT(MONTH FROM ($1::date-INTERVAL '1 month')))",[date]),
    pool.query(`SELECT id,branch_id,operator,details->>'code' AS code,COALESCE(details->>'message','Card validation rejected.') AS message,created_at AS attempted_at,count(*) OVER() AS total_count FROM public.qr_attendance_audit WHERE action='PREVIEW_REJECTED'
      AND (created_at AT TIME ZONE 'Asia/Kuala_Lumpur')::date=$1::date AND ($2='' OR upper(branch_id)=upper($2)) ORDER BY id DESC LIMIT 1000`,[date,branch]),
  ]);
  const events=eventRows.rows.filter(e=>{
    try {ensureEmployeeScope(req,e);return !q||upper(e.employee_id+' '+e.name).includes(q);}catch{return false;}
  }).map(({address,...row})=>row);
  const groups=new Map();
  for(const e of events) {const id=upper(e.employee_id)+'|'+e.work_date+'|'+upper(e.branch_id);if(!groups.has(id))groups.set(id,[]);groups.get(id).push(e);}
  const employees=[...groups.values()].map(rows=>{
    const first=rows[0],last=rows.at(-1),proposal=attendanceProposal(rows);
    return {employee_id:first.employee_id,name:first.name,branch_id:first.branch_id,action:last.action,
      first_in:first.scanned_at,last_punch:last.scanned_at,work_date:first.work_date,punch_count:rows.length,
      missing_out:last.action==='IN'&&first.work_date<dayMY(new Date()),issues:proposal.issues,
      proposal_valid:proposal.valid,fingerprint:proposal.fingerprint,net_minutes:proposal.fields?.net_working_minutes??null};
  });
  const lateReports=[...new Set(employees.map(e=>e.work_date.slice(0,7)))].flatMap(period=>buildLateReport({attendance:employees.map(e=>({employee_id:e.employee_id,branch_id:e.branch_id,attendance_date:e.work_date,status:'Present',check_in:clockMY(e.first_in),break_minutes:0})),
    daily:daily.rows.map(r=>r.data),monthly:monthly.rows.map(r=>r.data),employees,year:Number(period.slice(0,4)),month:Number(period.slice(5,7)),minimum:0}).reports);
  for(const e of employees) {
    const arrival=lateReports.filter(r=>upper(r.employee_id)===upper(e.employee_id)&&upper(r.branch_id)===upper(e.branch_id)).flatMap(r=>r.events).find(event=>event.type==='arrival'&&event.date===e.work_date);
    e.late_minutes=arrival?.minutes??null;
    const dailyRoster=daily.rows.map(r=>r.data).find(r=>upper(r.employee_id)===upper(e.employee_id)&&upper(r.branch_id)===upper(e.branch_id)&&String(r.roster_date).slice(0,10)===e.work_date);
    const weeklyRoster=monthly.rows.map(r=>r.data).find(r=>upper(r.employee_id)===upper(e.employee_id)&&upper(r.branch_id)===upper(e.branch_id)&&Number(r.roster_year)===Number(e.work_date.slice(0,4))&&Number(r.roster_month)===Number(e.work_date.slice(5,7))&&Number(r.week_number)===Math.floor((Number(e.work_date.slice(8))-1)/7)+1);
    const roster=dailyRoster??weeklyRoster;
    const start=/^(\d{2}):(\d{2})/.exec(String(roster?.shift_start??''));
    const end=/^(\d{2}):(\d{2})/.exec(String(roster?.shift_end??''));
    e.early_minutes=null;
    if (start&&end&&!['OFF','MC','AL','EL','PL','UNPAID','UL','UL-UNPAID','PH','PH-OFF','PH-SPL','MEDICAL LEAVE'].includes(upper(roster?.assignment_type))) {
      const startMin=Number(start[1])*60+Number(start[2]),endMin=Number(end[1])*60+Number(end[2]);
      let scheduledEnd=new Date(e.work_date+'T'+end[0]+':00+08:00');
      if(endMin<=startMin)scheduledEnd=new Date(scheduledEnd.getTime()+86400000);
      if(e.action==='IN'&&scheduledEnd<new Date())e.missing_out=true;
      if(e.action==='OUT')e.early_minutes=Math.max(0,Math.floor((scheduledEnd-new Date(e.last_punch))/60000));
    }

  }
  for(const e of employees)if(e.action==='IN'&&!e.missing_out)e.issues=e.issues.map(issue=>issue==='Missing OUT'?'Open work session':issue);
  const currentByEmployee=new Map();
  for(const e of employees){const previous=currentByEmployee.get(e.employee_id);if(!previous||new Date(e.last_punch)>new Date(previous.last_punch))currentByEmployee.set(e.employee_id,e);}
  const current=[...currentByEmployee.values()],matchingIds=new Set(employees.map(e=>upper(e.employee_id)));
  const attempts=[...attemptRows.rows,...previewRejects.rows.map(row=>({...row,status:'REJECTED',employee_id:null,request_id:'preview-'+row.id}))].filter(a=>!q||upper(a.employee_id).includes(q)||matchingIds.has(upper(a.employee_id))).sort((a,b)=>new Date(b.attempted_at)-new Date(a.attempted_at)).slice(0,1000);
  return {ok:true,date,branch:branch||'All branches',employees,events,attempts,
    totals:{in:current.filter(e=>e.action==='IN').length,out:current.filter(e=>e.action==='OUT').length,punches:events.filter(event=>dayMY(event.scanned_at)===date).length,
      missing:employees.filter(e=>e.missing_out).length,late:employees.filter(e=>e.late_minutes>0).length,rejected:q?attempts.filter(a=>a.status==='REJECTED').length:Number(attemptRows.rows[0]?.rejected_total??0)+Number(previewRejects.rows[0]?.total_count??0)}};
}
