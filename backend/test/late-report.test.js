import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLateReport,installLateReportApi} from '../src/late-report.js';
const roster = {branch_id:'A',employee_id:'E1',roster_year:2026,roster_month:10,week_number:1,shift_start:'09:00',shift_end:'18:00',break_minutes:60};
const day = (d,check_in='09:00',break_minutes=60) => ({branch_id:'A',employee_id:'E1',attendance_date:`2026-10-0${d}`,check_in,break_minutes});
const report = (rows,extra={}) => buildLateReport({attendance:rows,daily:[],monthly:[roster],employees:[{employee_id:'E1',name:'Employee A'}],year:2026,month:10,...extra});
test('two arrivals plus two exceeded break days count as four, with exact minutes',()=>{
 const r=report([day(1,'09:10',75),day(2,'09:05',80)]).reports[0];
 assert.equal(r.count,4); assert.equal(r.arrival_count,2); assert.equal(r.break_count,2); assert.equal(r.total_minutes,50);
 assert.deepEqual(r.events.map(e=>e.minutes),[10,15,5,20]);
});
test('threshold includes exactly three but excludes two; deduplicates days',()=>{
 assert.equal(report([day(1,'09:01'),day(2,'09:01')]).reports.length,0);
 assert.equal(report([day(1,'09:01'),day(2,'09:01'),day(3,'09:01'),day(3,'09:01')]).reports[0].count,3);
});
test('daily roster overrides weekly, off days and exact allowance do not count',()=>{
 const result=report([day(1,'09:20',65),day(2,'09:20',65),day(3,'09:00',60)],{
 daily:[{...roster,roster_date:'2026-10-01',shift_start:'09:30',break_minutes:70},{...roster,roster_date:'2026-10-02',assignment_type:'OFF'}]});
 assert.equal(result.reports.length,0);assert.equal(result.missing_schedules,0);
});
test('separate branches, other months excluded, missing schedules reported',()=>{
 const r=report([day(1,'09:10'),{...day(2,'09:10'),branch_id:'B'}, {...day(3,'09:10'),attendance_date:'2026-09-03'}]);
 assert.equal(r.reports.length,0);assert.equal(r.missing_schedules,1);
});
test('uses actual break pairs, including overnight pairs',()=>{
 const rows=[1,2,3].map(d=>({...day(d),morning_in:'23:30',morning_out:'00:45'}));
 const r=report(rows).reports[0];assert.equal(r.count,3);assert.equal(r.total_minutes,45);
});
test('overnight arrival 00:10 after 22:00 is 130 minutes late',()=>{
 const r=report([1,2,3].map(d=>day(d,'00:10')),{monthly:[{...roster,shift_start:'22:00',shift_end:'06:00'}]}).reports[0];
 assert.equal(r.total_minutes,390);
});
test('three late arrivals alone and three break excesses alone qualify',()=>{
 assert.equal(report([1,2,3].map(d=>day(d,'09:05'))).reports[0].arrival_count,3);
 assert.equal(report([1,2,3].map(d=>day(d,'09:00',61))).reports[0].break_count,3);
});

function api(pool) {
  const routes = {};
  installLateReportApi({get:(path,auth,fn)=>{routes.get=fn;},post:(path,auth,fn)=>{routes.post=fn;}}, {authenticate:()=>{},pool});
  return routes;
}
function response() {return {status(n){this.code=n;return this;},json(v){this.body=v;return this;}};}
function fakePool(current=[day(1,'09:05'),day(2,'09:05'),day(3,'09:05')], previous=[], reviews=[]) {
  const calls=[];
  return {calls,async query(sql,params=[]) {
    calls.push({sql,params});
    if(sql.includes('INSERT INTO app_private.late_report_reviews')) return {rows:[{id:100,reviewed_by:params[9],reviewed_at:'2026-10-26T01:00:00Z'}]};
    if(sql.includes('FROM public.attendance')) return {rows:(params[0]==='2026-10-01'?current:previous).map(data=>({data}))};
    if(sql.includes('FROM public.daily_rosters')) return {rows:[]};
    if(sql.includes('FROM public.monthly_rosters')) return {rows:[{data:{...roster,roster_year:params[0],roster_month:params[1]}}]};
    if(sql.includes('FROM public.employees')) return {rows:[{employee_id:'E1',name:'Employee A'}]};
    if(sql.includes('FROM app_private.late_report_reviews')) return {rows:reviews};
    throw Error('Unexpected SQL');
  }};
}
test('both API routes deny branch and employee access before querying',async()=>{
 const pool=fakePool(), routes=api(pool);
 for(const role of ['EMPLOYEE','BRANCH']) for(const route of Object.values(routes)) {
   const res=response();await route({user:{role},query:{year:2026,month:10}},res);assert.equal(res.code,403);
 }
 assert.equal(pool.calls.length,0);
});
test('API validates month and year before querying',async()=>{
 const pool=fakePool(),routes=api(pool);
 for(const query of [{year:2026,month:13},{year:1999,month:10},{year:'x',month:10}]) {
   const res=response();await routes.get({user:{role:'ADMIN'},query},res);assert.equal(res.code,400);
 }
 assert.equal(pool.calls.length,0);
});
test('previous counts below threshold are retained and January compares December',async()=>{
 const pool=fakePool(undefined,[{...day(1,'09:05'),attendance_date:'2026-09-01'},{...day(2,'09:05'),attendance_date:'2026-09-02'}]);
 const routes=api(pool),res=response();
 await routes.get({user:{role:'ADMIN'},query:{year:2026,month:10}},res);
 assert.equal(res.body.reports[0].previous_count,2);assert.equal(res.body.reports[0].change,1);
 const january=response();await routes.get({user:{role:'ADMIN'},query:{year:2026,month:1}},january);
 assert.deepEqual(january.body.previous_period,{year:2025,month:12});
 assert.ok(pool.calls.some(c=>c.params[0]==='2025-12-01'));
});
test('missing data lists names, dates, precise issues, and retains independently measurable arrival',()=>{
 const result=report([day(1,'09:05'),{...day(2,'09:05'),morning_in:'12:00',morning_out:''},{...day(3,'09:05'),branch_id:'B'}],{minimum:0});
 assert.equal(result.missing_records.length,2);
 assert.ok(result.missing_records.some(r=>r.employee_id==='E1'&&r.date==='2026-10-02'&&r.issues.includes('Incomplete break start/end')));
 assert.ok(result.missing_records.some(r=>r.branch_id==='B'&&r.issues.includes('Missing roster')));
 assert.equal(result.reports[0].count,2);
});
test('missing check-in and missing allowance are flagged without inventing zero values',()=>{
 const result=report([{...day(1),check_in:'',status:'Present'},day(2)],{monthly:[{...roster,break_minutes:null}],minimum:0});
 assert.ok(result.missing_records[0].issues.includes('Missing or invalid check-in'));
 assert.ok(result.missing_records[0].issues.includes('Missing or invalid break allowance'));
});
test('severity boundaries are 3/5/7; approvals preserve counts and changed timing invalidates review',()=>{
 for(const count of [3,4,5,6,7,8]) {
   const rows=Array.from({length:count},(_,i)=>({...day(1,'09:01'),attendance_date:`2026-10-${String(i+1).padStart(2,'0')}`}));
   const daily=rows.map(r=>({...roster,roster_date:r.attendance_date}));
   const result=report(rows,{daily});
   assert.equal(result.reports[0].severity,count>=7?'high':count>=5?'medium':'low');
 }
 const rows=[1,2,3].map(d=>day(d,'09:05'));
 const original=report(rows).reports[0].events[0];
 const review={id:1,branch_id:'A',employee_id:'E1',event_date:'2026-10-01',event_type:'arrival',event_fingerprint:original.fingerprint,status:'approved',reason:'Approved by manager'};
 const reviewed=report(rows,{reviews:[review]}).reports[0];
 assert.equal(reviewed.count,3);assert.equal(reviewed.events[0].review.status,'approved');
 const changed=report([day(1,'09:10'),...rows.slice(1)],{reviews:[review]}).reports[0].events[0];
 assert.equal(changed.review,null);assert.equal(changed.review_outdated,true);assert.equal(changed.review_history.length,1);
});
test('review validates input and rejects stale fingerprints',async()=>{
 const pool=fakePool(),route=api(pool).post;
 const base={branch_id:'A',employee_id:'E1',date:'2026-10-01',type:'arrival',fingerprint:'a'.repeat(64),status:'approved',reason_code:'transport',reason:'Train delayed'};
 for(const changes of [{reason:'x'},{date:'2026-02-31'},{status:'delete'},{reason_code:'invented'},{fingerprint:'bad'}]) {
   const res=response();await route({user:{role:'ADMIN',username:'admin1'},body:{...base,...changes}},res);assert.equal(res.code,400);
 }
 assert.equal(pool.calls.length,0);
 const res=response();await route({user:{role:'ADMIN',username:'admin1'},body:base},res);assert.equal(res.code,409);
 assert.ok(!pool.calls.some(c=>c.sql.startsWith('INSERT')));
});
test('review stores authenticated identity, snapshot, and a new audit row; never updates attendance',async()=>{
 const pool=fakePool(),route=api(pool).post;
 const original=report([1,2,3].map(d=>day(d,'09:05'))).reports[0].events[0];
 const body={branch_id:'A',employee_id:'E1',date:'2026-10-01',type:'arrival',fingerprint:original.fingerprint,status:'approved',reason_code:'transport',reason:'Train delayed',reviewed_by:'spoofed'};
 for(let n=0;n<2;n++) {
   const res=response();await route({user:{role:'ADMIN',username:'actual-admin'},body},res);assert.equal(res.body.ok,true);
 }
 const writes=pool.calls.filter(c=>c.sql.startsWith('INSERT'));
 assert.equal(writes.length,2);assert.equal(writes[0].params[9],'actual-admin');
 assert.equal(JSON.parse(writes[0].params[5]).minutes,5);
 assert.ok(!pool.calls.some(c=>/UPDATE|DELETE/.test(c.sql)));
});

test('explicit absences and empty days do not invent incomplete working records',()=>{
 const result=report([{...day(1),check_in:'-',status:'Absent',break_minutes:0}, {...day(2),check_in:'',status:'',break_minutes:0}]);
 assert.equal(result.missing_records.length,0);assert.equal(result.reports.length,0);
});

test('reviewer preview and requests-only admin accounts cannot read or review employee reports',async()=>{
 const pool=fakePool(),routes=api(pool);
 for(const metadata of [{is_reviewer:true},{staff_scope:'requests'}]) for(const route of Object.values(routes)) {
   const res=response();await route({user:{role:'ADMIN'},auth:{app_metadata:metadata},query:{year:2026,month:10}},res);assert.equal(res.code,403);
 }
 assert.equal(pool.calls.length,0);
});
