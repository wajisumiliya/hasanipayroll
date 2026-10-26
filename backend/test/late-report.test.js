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
test('API denies non-admin and invalid periods before querying data',async()=>{
 let handler;let queried=false;
 installLateReportApi({get:(path,auth,fn)=>{handler=fn;}},{authenticate:()=>{},pool:{query:()=>{queried=true;}}});
 const response={status(n){this.code=n;return this;},json(v){this.body=v;return this;}};
 for(const role of ['EMPLOYEE','BRANCH']) {await handler({user:{role},query:{year:2026,month:10}},response);assert.equal(response.code,403);}
 await handler({user:{role:'ADMIN'},query:{year:2026,month:13}},response);assert.equal(response.code,400);assert.equal(queried,false);
});
test('admin API loads the selected period and returns computed report',async()=>{
 let handler;const queries=[];
 const responses=[{rows:[1,2,3].map(d=>({data:day(d,'09:05')}))},{rows:[]},{rows:[{data:roster}]},{rows:[{employee_id:'E1',name:'Employee A'}]}];
 installLateReportApi({get:(path,auth,fn)=>{handler=fn;}},{authenticate:()=>{},pool:{query:async(sql,params)=>{queries.push({sql,params});return responses.shift();}}});
 const response={status(n){this.code=n;return this;},json(v){this.body=v;return this;}};
 await handler({user:{role:'ADMIN'},query:{year:'2026',month:'10'}},response);
 assert.equal(response.body.ok,true);assert.equal(response.body.reports[0].count,3);
 assert.deepEqual(queries[0].params,['2026-10-01']);assert.deepEqual(queries[2].params,[2026,10]);
});
test('three late arrivals alone and three break excesses alone qualify',()=>{
 assert.equal(report([1,2,3].map(d=>day(d,'09:05'))).reports[0].arrival_count,3);
 assert.equal(report([1,2,3].map(d=>day(d,'09:00',61))).reports[0].break_count,3);
});
