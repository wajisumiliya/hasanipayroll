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

function api(pool, renderExport) {
  const routes = {};
  installLateReportApi({get:(path,auth,fn)=>{routes[path.endsWith('/export')?'export':'get']=fn;},post:(path,auth,fn)=>{routes.post=fn;}}, {authenticate:()=>{},pool,renderExport});
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
    if(sql.includes('FROM public.branches')) return {rows:[{id:'A',name:'ALOR SETAR'},{id:'B',name:'ASTANA'}]};
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

test('report and export exclude thousands of incomplete rows and keep selected branch/month',async()=>{
 const incomplete=Array.from({length:5000},(_,i)=>({...day(1,'09:05'),employee_id:`M${i}`,branch_id:'B'}));
 const pool=fakePool([...Array.from({length:3},(_,i)=>day(i+1,'09:05')),...incomplete]);
 let payload;
 const routes=api(pool,async data=>{payload=data;return Buffer.from('test-file');});
 const res=response();await routes.get({user:{role:'ADMIN'},query:{year:2026,month:10}},res);
 assert.equal(res.body.reports.length,1);assert.equal('missing_records' in res.body,false);assert.equal('previous_missing_records' in res.body,false);
 const file=response();await routes.export({user:{role:'ADMIN'},query:{year:2026,month:10,format:'xlsx',branch_id:'A'}},file);
 assert.equal(file.body.ok,true);assert.equal(Buffer.from(file.body.file_base64,'base64').toString(),'test-file');
 assert.equal(payload.branchLabel,'ALOR SETAR');assert.equal(payload.reports.length,1);assert.equal(payload.month,10);
 assert.equal('missing_records' in payload,false);assert.equal(JSON.stringify(payload).includes('Missing roster'),false);
});
test('export rejects invalid formats, periods, and unknown branches',async()=>{
 const pool=fakePool(),routes=api(pool,async()=>{throw Error('Must not render');});
 for(const query of [{year:2026,month:13,format:'pdf'},{year:2026,month:10,format:'csv'}]) {
   const res=response();await routes.export({user:{role:'ADMIN'},query},res);assert.equal(res.code,400);
 }
 assert.equal(pool.calls.length,0);
 const res=response();await routes.export({user:{role:'ADMIN'},query:{year:2026,month:10,format:'pdf',branch_id:'unknown'}},res);assert.equal(res.code,404);
});

test('saved late statuses retain legacy branches without rosters and never invent minutes',()=>{
 const attendance=[];
 for(const branch of ['SP-EDAR','ALOR SETAR','AMANJAYA']) for(let d=1;d<=3;d++)
   attendance.push({...day(d,'09:10'),branch_id:branch,employee_id:branch,status:'Late'});
 const result=buildLateReport({attendance,daily:[],monthly:[{...roster,branch_id:'SP-EDAR',employee_id:'SP-EDAR'}],
   employees:[],year:2026,month:10});
 assert.equal(result.reports.length,3);
 for(const r of result.reports)assert.equal(r.arrival_count,3);
 const legacy=result.reports.find(r=>r.branch_id==='AMANJAYA');
 assert.equal(legacy.events[0].minutes,null);assert.equal(legacy.total_minutes_known,false);
 assert.equal(result.reports.find(r=>r.branch_id==='SP-EDAR').total_minutes,30);
});
test('summary PDF request applies arrival threshold and employee selection',async()=>{
 let payload;
 const routes=api(fakePool([1,2,3].map(d=>day(d,'09:05'))),async data=>{payload=data;return Buffer.from('summary');});
 const res=response();
 await routes.export({user:{role:'ADMIN'},query:{year:2026,month:10,format:'pdf',view:'attendance-summary',employees:'["E1"]'}},res);
 assert.equal(res.body.ok,true);assert.equal(payload.view,'attendance-summary');assert.equal(payload.reports.length,1);
 const excluded=response();
 await routes.export({user:{role:'ADMIN'},query:{year:2026,month:10,format:'pdf',view:'attendance-summary',employees:'[]'}},excluded);
 assert.equal(payload.reports.length,0);
 const invalid=response();
 await routes.export({user:{role:'ADMIN'},query:{year:2026,month:10,format:'pdf',view:'attendance-summary',employees:'not-json'}},invalid);
 assert.equal(invalid.code,400);
});

test('every main/break combination totalling three meets the threshold',()=>{
 const cases=[
   [day(1,'09:05',61),day(2,'09:05',60)],
   [day(1,'09:05',61),day(2,'09:00',61)],
   [day(1,'09:00',61),day(2,'09:00',61),day(3,'09:00',61)],
   [day(1,'09:05',60),day(2,'09:05',60),day(3,'09:05',60)],
 ];
 for(const rows of cases) {const result=report(rows).reports;assert.equal(result.length,1);assert.equal(result[0].count,3);}
 assert.equal(report([day(1,'09:05',61)]).reports.length,0);
});

test('saved shift snapshots retain exact late minutes after roster removal',()=>{
 const rows=[1,2,3].map(d=>({...day(d,'09:35'),status:'Late',scheduled_shift_start:'09:00:00',scheduled_shift_end:'18:00:00'}));
 const result=report(rows,{monthly:[]}).reports[0];
 assert.equal(result.arrival_count,3);assert.equal(result.total_minutes,105);assert.equal(result.total_minutes_known,true);
});
test('valid weekly shift fills a missing daily shift and valid alternate check-in is used',()=>{
 const rows=[1,2,3].map(d=>({...day(d,'-'),working_in:'09:10',status:'Late'}));
 const daily=[1,2,3].map(d=>({...roster,roster_date:`2026-10-0${d}`,shift_start:null,shift_end:null}));
 const result=report(rows,{daily,monthly:[{...roster,shift_start:'09:00:00.000'}]}).reports[0];
 assert.equal(result.total_minutes,30);assert.equal(result.events[0].actual,'09:10');
});
test('explicit 12-hour times and midnight snapshots calculate without assumed defaults',()=>{
 const rows=[1,2,3].map(d=>({...day(d,'12:10 AM'),status:'Late',scheduled_shift_start:'10:00 PM',scheduled_shift_end:'06:00 AM'}));
 const result=report(rows,{monthly:[]}).reports[0];assert.equal(result.total_minutes,390);
 const missing=report(rows.map(r=>({...r,scheduled_shift_start:null,scheduled_shift_end:null})),{monthly:[]}).reports[0];
 assert.equal(missing.events[0].minutes,null);
});

test('explicit saved late minutes are retained when a legacy roster is gone',()=>{
 const result=report([1,2,3].map(d=>({...day(d,'09:35'),status:'Late',late_minutes:35})),{monthly:[]}).reports[0];
 assert.equal(result.total_minutes,105);assert.equal(result.events[0].source,'saved_late_minutes');
});
