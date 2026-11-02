import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {earlyOutEvent,buildEarlyOutEvents,approverRole} from '../src/early-out-calculation.js';
import {installEarlyOutApi} from '../src/early-out-api.js';
const employee={employee_id:'E1',name:'Employee',branch_id:'A'};
const roster={branch_id:'A',employee_id:'E1',shift_start:'09:00',shift_end:'18:00',break_minutes:60,week_number:1,roster_year:2026,roster_month:10};
const attendance={employee_id:'E1',branch_id:'A',attendance_date:'2026-10-01',check_in:'09:00',check_out:'16:00',net_working_minutes:360,status:'Early Out',is_submitted:true};
const event=(overrides={},decision=null)=>earlyOutEvent({attendance:{...attendance,...overrides},employee,roster,decision});
test('Early Out portion preserves 15-minute grace and is capped by actual eligible shortfall',()=>{
 const e=event();assert.equal(e.required_minutes,480);assert.equal(e.worked_minutes,360);assert.equal(e.early_minutes,120);assert.equal(e.shortage_minutes,105);assert.equal(e.eligible_early_minutes,105);
 assert.equal(event({net_working_minutes:450}).eligible_early_minutes,15);
 assert.equal(event({net_working_minutes:300}).eligible_early_minutes,105);
});
test('12-hour times normalize consistently and missing schedules remain visible but cannot be approved',()=>{
 const result=earlyOutEvent({attendance:{...attendance,check_out:'4:00 PM',check_in:'9:00 AM'},employee,roster:{...roster,shift_start:'9:00 AM',shift_end:'6:00 PM'}});
 assert.equal(result.eligible_early_minutes,105);assert.equal(result.check_out,'16:00');
 const incomplete=earlyOutEvent({attendance,employee,roster:{}});assert.equal(incomplete.eligible_early_minutes,0);assert.ok(incomplete.review_blocked_reason);
});
test('Admin and Accounts approval exempts only matching duration; pending, rejected and stale do not',()=>{
 const e=event();for(const role of ['ADMIN','ACCOUNTS']){
  const approved=event({}, {id:1,status:'APPROVED',approved_minutes:45,fingerprint:e.fingerprint,approver_role:role});assert.equal(approved.approved_minutes,45);assert.equal(approved.approver_role,role);
 }
 for(const decision of [null,{id:1,status:'REJECTED',approved_minutes:0,fingerprint:e.fingerprint},{id:1,status:'APPROVED',approved_minutes:105,fingerprint:'wrong'}])assert.equal(event({},decision).approved_minutes,0);
 assert.equal(event({check_out:'15:30'},{id:1,status:'APPROVED',approved_minutes:105,fingerprint:e.fingerprint}).approval_status,'PENDING');
});
test('management, temporary, support, FRN, employee exception and leave/PH retain exemptions',()=>{
 for(const flags of [{is_management_staff:true},{is_temp_staff:true},{is_support_staff:true},{address:'FRN'},{employee_id:'HED1007'}])assert.equal(earlyOutEvent({attendance,employee:{...employee,...flags},roster}).eligible_early_minutes,0);
 for(const change of [{status:'MC'},{status:'UL-UNPAID'},{is_public_holiday:true},{net_working_minutes:0}])assert.equal(event(change).eligible_early_minutes,0);
});
test('daily roster outranks weekly; decision cannot move to another employee/date',()=>{
 const first=event();const rows=buildEarlyOutEvents({attendance:[attendance,{...attendance,attendance_date:'2026-10-02'}],employees:[employee],monthly:[roster],daily:[{...roster,roster_date:'2026-10-01',shift_end:'16:00'}],decisions:[{id:1,employee_id:'OTHER',attendance_date:'2026-10-02',status:'APPROVED',approved_minutes:105,fingerprint:first.fingerprint}]});
 assert.equal(rows.length,1);assert.equal(rows[0].attendance_date,'2026-10-02');assert.equal(rows[0].approved_minutes,0);
});
test('backend approval authority is limited to authenticated admin/accounts and not reviewer/request staff',()=>{
 assert.equal(approverRole({user:{role:'ADMIN',username:'boss'}}),'ADMIN');assert.equal(approverRole({user:{role:'ADMIN',username:'account'}}),'ACCOUNTS');assert.equal(approverRole({user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'attendance'}}}),'ACCOUNTS');
 for(const req of [{},{user:{role:'BRANCH'}},{user:{role:'EMPLOYEE'}},{user:{role:'ADMIN'},auth:{app_metadata:{is_reviewer:true}}},{user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'requests'}}}])assert.equal(approverRole(req),null);
});
function routes(pool){const handlers={};installEarlyOutApi({get(path,auth,fn){handlers[path]=fn;},post(path,auth,fn){handlers[path]=fn;}},{authenticate(){},pool});return handlers;}
function response(){return {code:200,status(n){this.code=n;return this;},set(){return this;},json(body){this.body=body;return this;}};}
test('branch/employee approval requests are denied before DB access',async()=>{
 const handlers=routes({connect(){throw Error('must not read');}});
 for(const role of ['BRANCH','EMPLOYEE']){const res=response();await handlers['/api/attendance/early-out/decision']({user:{role}},res);assert.equal(res.code,403);}
});
test('migration, duplicate/conflict protection, cross-month cutoff, audit, saved/finalized payroll',{skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');const {readFile}=await import('node:fs/promises');
 const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
 const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_early_out_test');url.pathname='/hasani_early_out_test';const pool=new pg.Pool({connectionString:url.toString()});
 try{
  await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
  const migration=await readFile(new URL('../migrations/20261102_early_out_approvals.sql',import.meta.url),'utf8');await pool.query(migration);await pool.query(migration);
  await pool.query("INSERT INTO public.employees(employee_id,name,branch_id) VALUES('E1','Employee','A')");
  await pool.query("INSERT INTO public.employee_salary_defaults(employee_id,basic_salary,epf_category,eis_applicable) VALUES('E1',5200,'normal1',true)");
  await pool.query("INSERT INTO public.monthly_rosters(branch_id,employee_id,roster_year,roster_month,week_number,shift_start,shift_end,break_minutes) VALUES('A','E1',2026,10,1,'09:00','18:00',60)");
  await pool.query("INSERT INTO public.attendance(employee_id,branch_id,attendance_date,check_in,check_out,net_working_minutes,status,is_submitted) VALUES('E1','A','2026-10-01','09:00','16:00',360,'Early Out',true)");
  await pool.query("INSERT INTO public.payroll(employee_id,period,late_deduction) VALUES('E1','2026-10-01',43.8)");
  const api=routes(pool);const admin={role:'ADMIN',username:'boss'};
  const get=async(user=admin,month=10)=>{const res=response();await api['/api/attendance/early-out/payroll-context']({user,query:{year:2026,month,employees:'["E1"]'}},res);assert.equal(res.code,200);return res.body;};
  const post=async(body,user=admin)=>{const res=response();await api['/api/attendance/early-out/decision']({user,body},res);return res;};
  const before=await get();assert.equal(before.events[0].approved_minutes,0);assert.equal((await get(admin,11)).events.length,0);
  const e=before.events[0],request={request_id:randomUUID(),employee_id:'E1',attendance_date:'2026-10-01',fingerprint:e.fingerprint,expected_revision:e.revision,status:'APPROVED',approved_minutes:45,remarks:'Approved early departure'};
  const approved=await post(request);assert.equal(approved.code,200);assert.equal(approved.body.payroll_updated,false);
  const retry=await post(request);assert.equal(retry.code,200);assert.equal(retry.body.replayed,true);
  assert.equal((await post({...request,request_id:randomUUID()})).code,409);
  assert.equal((await post({...request,approved_minutes:60})).code,409);
  assert.equal((await pool.query('SELECT count(*)::int n FROM app_private.early_out_decisions')).rows[0].n,1);
  assert.equal((await pool.query("SELECT count(*)::int n FROM public.branch_activity_logs WHERE action='EARLY_OUT_APPROVED'")).rows[0].n,1);
  const frozen=await pool.query('SELECT approved_minutes FROM app_private.early_out_decisions WHERE approved_at <= $1::timestamptz',[before.cutoff]);assert.equal(frozen.rows.length,0);
  const after=await get();assert.equal(after.events[0].approved_minutes,45);
  assert.equal(Number((await pool.query('SELECT late_deduction FROM public.payroll')).rows[0].late_deduction),43.8);
  const account={role:'ADMIN',username:'account'};const second=await post({...request,request_id:randomUUID(),expected_revision:after.events[0].revision,approved_minutes:105},account);assert.equal(second.code,200);assert.equal(second.body.decision.approver_role,'ACCOUNTS');
  await assert.rejects(pool.query("UPDATE app_private.early_out_decisions SET remarks='changed'"),/append-only/);
  await pool.query('UPDATE public.payroll SET is_published=true');
  await assert.rejects(pool.query('UPDATE public.payroll SET late_deduction=0'),/requires an authorized adjustment/);
  await assert.rejects(pool.query('UPDATE public.payroll SET is_published=false'),/cannot be reopened/);
  await pool.query("UPDATE public.attendance SET check_out='15:30' WHERE employee_id='E1'");
  assert.equal((await get()).events[0].approved_minutes,0);
  assert.equal((await post({...request,request_id:randomUUID(),expected_revision:second.body.decision.id.toString()})).code,409);
  const changed=(await get()).events.find(e=>e.attendance_date==='2026-10-01');
  const rejected=await post({...request,request_id:randomUUID(),fingerprint:changed.fingerprint,expected_revision:changed.revision,status:'REJECTED',approved_minutes:0},account);
  assert.equal(rejected.code,200);assert.equal((await get()).events[0].approval_status,'REJECTED');
  await pool.query("INSERT INTO public.attendance(employee_id,branch_id,attendance_date,check_in,check_out,net_working_minutes,status,is_submitted) VALUES('E1','A','2026-10-02','09:00','16:00',360,'Early Out',true)");
  const other=(await get()).events.find(e=>e.attendance_date==='2026-10-02');
  const concurrent={...request,attendance_date:other.attendance_date,fingerprint:other.fingerprint,expected_revision:other.revision};
  const outcomes=await Promise.all([post({...concurrent,request_id:randomUUID()}),post({...concurrent,request_id:randomUUID()},account)]);
  assert.deepEqual(outcomes.map(r=>r.code).sort(),[200,409]);
  await pool.query('ALTER TABLE public.payroll ADD COLUMN is_paid boolean DEFAULT false, ADD COLUMN status text, ADD COLUMN paid_at timestamptz');
  await pool.query("INSERT INTO public.payroll(employee_id,period,late_deduction,is_paid,status) VALUES('E1','2026-11-01',40,true,'paid'),('E1','2026-12-01',40,false,'finalized')");
  await assert.rejects(pool.query("UPDATE public.payroll SET late_deduction=0 WHERE period='2026-11-01'"),/requires an authorized adjustment/);
  await assert.rejects(pool.query("UPDATE public.payroll SET is_paid=false,status='draft' WHERE period='2026-11-01'"),/cannot be reopened/);
  await assert.rejects(pool.query("UPDATE public.payroll SET late_deduction=0 WHERE period='2026-12-01'"),/requires an authorized adjustment/);

  const forbidden=response();await api['/api/attendance/early-out/payroll-context']({user:{role:'BRANCH',branchId:'B'},query:{year:2026,month:10,employees:'["E1"]'}},forbidden);assert.equal(forbidden.code,403);
 }finally{await pool.end();await bootstrap.query('DROP DATABASE hasani_early_out_test');await bootstrap.end();}
});
