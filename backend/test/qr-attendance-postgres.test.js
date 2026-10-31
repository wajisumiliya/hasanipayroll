import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {once} from 'node:events';
import express from 'express';
import pg from 'pg';
import {installQrAttendanceApi} from '../src/qr-attendance.js';
import {dayMY} from '../src/qr-attendance-core.js';

const url=process.env.QR_TEST_DATABASE_URL;
test('QR attendance PostgreSQL integration (isolated disposable database only)',{skip:!url},async t=>{
  const parsed=new URL(url);
  assert.equal(parsed.hostname,'127.0.0.1');assert.equal(parsed.port,'55432');assert.equal(parsed.pathname,'/hasani_qr_test');
  const pool=new pg.Pool({connectionString:url});
  let server,base;
  await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
  await pool.query(`CREATE TABLE public.employees(employee_id text PRIMARY KEY,name text,branch_id text,is_active boolean,address text);
    CREATE TABLE public.branches(id text PRIMARY KEY,name text);
    CREATE TABLE public.attendance(id bigserial PRIMARY KEY,employee_id text REFERENCES employees(employee_id),branch_id text,attendance_date date,
      check_in text,check_out text,status text,morning_in text,morning_out text,afternoon_in text,afternoon_out text,
      work_minutes numeric,net_working_minutes numeric,break_minutes numeric,is_submitted boolean DEFAULT false,
      ot_authorized boolean DEFAULT false,approved_ot_minutes integer,overtime_in text,overtime_out text,
      UNIQUE(employee_id,attendance_date));
    CREATE TABLE public.daily_rosters(employee_id text,branch_id text,roster_date date,shift_start time,shift_end time,break_minutes integer,assignment_type text);
    CREATE TABLE public.monthly_rosters(employee_id text,branch_id text,roster_year integer,roster_month integer,week_number integer,shift_start time,shift_end time,break_minutes integer);`);
  const migration=await readFile(new URL('../sql/qr-attendance.sql',import.meta.url),'utf8');
  await pool.query(migration);await pool.query(migration);
  t.after(async()=>{if(server)await new Promise(resolve=>server.close(resolve));await pool.end();});
  async function start(){
    if(server)await new Promise(resolve=>server.close(resolve));
    const app=express();app.use(express.json());
    const auth=(req,res,next)=>{req.user={role:req.headers['x-role']??'BRANCH',username:req.headers['x-user']??'branch-a',branchId:req.headers['x-branch']??'A'};req.auth={app_metadata:{staff_scope:req.headers['x-scope']??'',is_reviewer:req.headers['x-reviewer']==='true'}};next();};
    installQrAttendanceApi(app,pool,auth,{enabled:true});
    server=app.listen(0,'127.0.0.1');await once(server,'listening');base='http://127.0.0.1:'+server.address().port;
    await pool.query(`TRUNCATE qr_attendance_attempts,qr_attendance_verifications,qr_attendance_reconciliations,qr_attendance_corrections,
      qr_attendance_audit,qr_attendance_events,qr_attendance_sessions,qr_attendance_stations,qr_attendance_credentials,attendance,daily_rosters,monthly_rosters,employees,branches RESTART IDENTITY CASCADE`);
    await pool.query(`INSERT INTO branches VALUES('A','ALOR SETAR'),('B','GURUN');
      INSERT INTO employees VALUES('E1','Employee One','A',true,'Malaysia'),('E2','Employee Two','B',true,'Malaysia'),('E3','Inactive','A',false,'Malaysia'),('E4','Foreign','A',true,'FRN');`);
  }
  async function api(path,body,headers={}){
    const res=await fetch(base+'/api/qr-attendance'+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...headers},...(body===undefined?{}:{body:JSON.stringify(body)})});
    return {status:res.status,...await res.json()};
  }
  const admin={'x-role':'ADMIN','x-user':'admin'};
  async function setup(verification=false){
    await start();
    const station=await api('/stations',{branch_id:'A',label:'USB scanner',verification_required:verification,min_interval_seconds:1},admin);assert.equal(station.ok,true);
    const session=await api('/session',{station_id:station.id});assert.equal(session.ok,true);
    const card=await api('/issue',{employee_id:'E1'},admin);assert.equal(card.ok,true);
    return {session_id:session.id,qr_value:card.qr_value};
  }
  const punch=body=>api('/scan',{request_id:crypto.randomUUID(),...body});
  await t.test('authorization, branch isolation, active employee checks and hashed-only credentials',async()=>{
    const data=await setup();
    assert.equal((await api('/issue',{employee_id:'E1'})).status,403);
    assert.equal((await api('/issue',{employee_id:'E3'},admin)).code,'INACTIVE_EMPLOYEE');
    const other=await api('/issue',{employee_id:'E2'},admin);
    assert.equal((await punch({...data,qr_value:other.qr_value})).code,'WRONG_BRANCH');
    assert.equal((await punch(data)).ok,true);
    const list=await api('/employees',undefined,admin);assert.ok(!JSON.stringify(list).includes(data.qr_value));assert.ok(!JSON.stringify(list).includes('token_hash'));
    assert.notEqual((await pool.query('SELECT token_hash FROM qr_attendance_credentials WHERE employee_id=$1',['E1'])).rows[0].token_hash,data.qr_value);
    assert.equal((await api('/scan',{...data,request_id:crypto.randomUUID()},{'x-role':'EMPLOYEE'})).status,403);
    assert.equal((await api('/dashboard?branch_id=B')).status,403);
    assert.equal((await api('/employees',undefined,{...admin,'x-scope':'foreign'})).employees.length,1);
  });
  await t.test('concurrent same-id retries commit exactly once; new rapid scans are rejected and audited',async()=>{
    const data=await setup(),request_id=crypto.randomUUID();
    const results=await Promise.all(Array.from({length:8},()=>api('/scan',{...data,request_id})));
    assert.ok(results.every(result=>result.ok));assert.equal(new Set(results.map(r=>r.event_id)).size,1);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM qr_attendance_events')).rows[0].n,1);
    const rapid=await punch(data);assert.equal(rapid.code,'RAPID_SCAN');
    const lookup=await api(`/requests/${request_id}?session_id=${data.session_id}`);assert.equal(lookup.event_id,results[0].event_id);
    const missing=await api(`/requests/${crypto.randomUUID()}?session_id=${data.session_id}`);assert.equal(missing.state,'NOT_FOUND');
    const audit=await api('/audit');assert.ok(audit.audit.some(a=>a.action==='PUNCH_IN'));
    const dashboard=await api('/dashboard');assert.equal(dashboard.totals.rejected,1);
  });
  await t.test('concurrent different request identifiers cannot record multiple transitions',async()=>{
    const data=await setup();const results=await Promise.all(Array.from({length:6},()=>punch(data)));
    assert.equal(results.filter(r=>r.ok).length,1);assert.equal(results.filter(r=>r.code==='RAPID_SCAN').length,5);
  });
  await t.test('supervised confirmation is credential/session bound and single-use',async()=>{
    const data=await setup(true);
    assert.equal((await punch(data)).code,'VERIFICATION_REQUIRED');
    const preview=await api('/preview',data);assert.equal(preview.employee.employee_id,'E1');
    const recorded=await punch({...data,verification_token:preview.verification_token});assert.equal(recorded.ok,true);
    assert.equal((await pool.query('SELECT verified_by FROM qr_attendance_events')).rows[0].verified_by,'branch-a');
  });
  await t.test('reissue and revocation immediately reject old cards and preserve issuance history',async()=>{
    const data=await setup();const newCard=await api('/issue',{employee_id:'E1'},admin);
    assert.equal((await punch(data)).code,'UNKNOWN_QR');
    assert.equal((await api('/revoke',{employee_id:'E1'},admin)).ok,true);
    assert.equal((await punch({...data,qr_value:newCard.qr_value})).code,'REVOKED_QR');
    const audit=await api('/audit',undefined,admin);assert.ok(audit.audit.some(a=>a.action==='CARD_REISSUED'));assert.ok(audit.audit.some(a=>a.action==='CARD_REVOKED'));
  });
  await t.test('expired/revoked scanner sessions and different operators cannot punch',async()=>{
    const data=await setup();
    assert.equal((await api('/scan',{...data,request_id:crypto.randomUUID()},{'x-user':'different'})).code,'SESSION_EXPIRED');
    await api('/session/revoke',{session_id:data.session_id});assert.equal((await punch(data)).code,'SESSION_EXPIRED');
  });
  async function seedWork(){
    const data=await setup();const now=new Date();const date=dayMY(new Date(now-7200000));
    await pool.query(`INSERT INTO qr_attendance_events(employee_id,branch_id,action,scanned_at,scanned_by,work_date)
      VALUES('E1','A','IN',clock_timestamp()-INTERVAL '2 hours','seed',$1),('E1','A','OUT',clock_timestamp()-INTERVAL '1 hour','seed',$1)`,[date]);
    return {...data,date};
  }
  await t.test('admin reconciliation copies reviewed draft times without authorizing OT; submitted rows are protected',async()=>{
    const {date}=await seedWork();const query=`?employee_id=E1&date=${date}`;
    const preview=await api('/reconciliation'+query,undefined,admin);assert.equal(preview.proposal.valid,true);
    assert.equal((await api('/reconcile',{employee_id:'E1',date,fingerprint:preview.proposal.fingerprint})).status,403);
    const saved=await api('/reconcile',{employee_id:'E1',date,fingerprint:preview.proposal.fingerprint},admin);assert.equal(saved.ok,true);assert.equal(saved.attendance.ot_authorized,false);assert.equal(saved.attendance.approved_ot_minutes,null);assert.equal(saved.attendance.is_submitted,false);
    await pool.query('UPDATE attendance SET is_submitted=true');
    assert.equal((await api('/reconcile',{employee_id:'E1',date,fingerprint:preview.proposal.fingerprint},admin)).code,'ATTENDANCE_LOCKED');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM qr_attendance_reconciliations')).rows[0].n,1);
  });
  await t.test('OT-approved and special-status drafts cannot be overwritten; stale proposal is rejected',async()=>{
    const {date}=await seedWork();const preview=await api(`/reconciliation?employee_id=E1&date=${date}`,undefined,admin);
    assert.equal((await api('/reconcile',{employee_id:'E1',date,fingerprint:'old'},admin)).code,'STALE_PROPOSAL');
    await pool.query("INSERT INTO attendance(employee_id,branch_id,attendance_date,status,ot_authorized) VALUES('E1','A',$1,'Present',true)",[date]);
    assert.equal((await api('/reconcile',{employee_id:'E1',date,fingerprint:preview.proposal.fingerprint},admin)).code,'ATTENDANCE_LOCKED');
    await pool.query("UPDATE attendance SET ot_authorized=false,status='MC'");
    assert.equal((await api('/reconcile',{employee_id:'E1',date,fingerprint:preview.proposal.fingerprint},admin)).code,'STATUS_CONFLICT');
  });
  await t.test('missing OUT can be requested, admin-approved and reconciled without changing raw timestamps',async()=>{
    const data=await setup();const timestamp=new Date(Date.now()-7200000),date=dayMY(timestamp);
    await pool.query("INSERT INTO qr_attendance_events(employee_id,branch_id,action,scanned_at,scanned_by,work_date) VALUES('E1','A','IN',$1,'seed',$2)",[timestamp,date]);
    const correction=await api('/corrections',{employee_id:'E1',date,action:'OUT',corrected_at:new Date(Date.now()-3600000).toISOString(),reason:'Supervisor verified missing checkout'});assert.equal(correction.ok,true);
    assert.equal((await api('/corrections/review',{id:correction.id,approved:true})).status,403);
    assert.equal((await api('/corrections/review',{id:correction.id,approved:true},admin)).ok,true);
    const preview=await api(`/reconciliation?employee_id=E1&date=${date}`,undefined,admin);assert.equal(preview.proposal.valid,true);assert.equal(preview.events.length,2);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM qr_attendance_events')).rows[0].n,1);
    await assert.rejects(pool.query("UPDATE qr_attendance_events SET action='OUT'"),/immutable/);
  });
  await t.test('invalid corrections roll back approval and preserve a pending audit trail',async()=>{
    const {date}=await seedWork();
    const correction=await api('/corrections',{employee_id:'E1',date,action:'OUT',corrected_at:new Date(Date.now()-1800000).toISOString(),reason:'Invalid extra checkout test'});
    const result=await api('/corrections/review',{id:correction.id,approved:true},admin);assert.equal(result.code,'IMPOSSIBLE_CORRECTION');
    assert.equal((await pool.query('SELECT status FROM qr_attendance_corrections WHERE id=$1',[correction.id])).rows[0].status,'PENDING');
  });
  await t.test('PDF and Excel exports honor branch/date filters and render real files',async()=>{
    const {date}=await seedWork();
    for(const format of ['pdf','xlsx']) {
      const data=await api(`/export?date=${date}&format=${format}`);assert.equal(data.ok,true);
      const bytes=Buffer.from(data.file_base64,'base64');assert.equal(bytes.subarray(0,format==='pdf'?5:2).toString(),format==='pdf'?'%PDF-':'PK');
    }
    assert.equal((await api('/export?format=pdf&branch_id=B')).status,403);
  });
});
