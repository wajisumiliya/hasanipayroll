import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeAttendanceWrite} from '../src/attendance-status.js';
import {buildAttendanceUpserts} from '../src/attendance-batch.js';
import {buildStatusReport} from '../src/attendance-status-report.js';
import {buildLateReport} from '../src/late-report.js';
test('old app replacement-holiday writes normalize without mutating the input',()=>{
 const row={employee_id:'E1',status:'PH-GUNTI'};
 assert.equal(normalizeAttendanceWrite(row).status,'PH-GANTI');assert.equal(row.status,'PH-GUNTI');
 assert.equal(normalizeAttendanceWrite({status:'PH-GANTI'}).status,'PH-GANTI');
});
test('UL is saved as unpaid through the batched attendance path',()=>{
 const [query]=buildAttendanceUpserts([{employee_id:'E1',attendance_date:'2026-10-01',status:'UL'}]);
 assert.match(query.sql,/is_unpaid/);assert.ok(query.values.includes('UL'));assert.ok(query.values.includes(true));
});
test('unpaid report includes only UL and excludes legacy unpaid status or flags',()=>{
 const row={attendance:{employee_id:'E1',branch_id:'A',attendance_date:'2026-10-01',status:'UL'},employee:{name:'Employee'}};
 const reports=buildStatusReport([row,row,{...row,attendance:{...row.attendance,attendance_date:'2026-10-02',status:'UNPAID'}}],{status:'UNPAID'});
 assert.equal(reports.length,1);assert.equal(reports[0].count,1);
 assert.equal(buildStatusReport([row],{status:'MC'}).length,0);
 assert.equal(buildStatusReport([{...row,attendance:{...row.attendance,status:'Present',is_unpaid:true}}],{status:'UNPAID'}).length,0);
});
test('UL is not accidentally counted as late arrival or excess break',()=>{
 const result=buildLateReport({attendance:[1,2,3].map(d=>({employee_id:'E1',branch_id:'A',attendance_date:`2026-10-0${d}`,status:'UL',check_in:'10:00',break_minutes:120})),
   daily:[],monthly:[{employee_id:'E1',branch_id:'A',roster_year:2026,roster_month:10,week_number:1,shift_start:'09:00',break_minutes:60}],employees:[],year:2026,month:10});
 assert.equal(result.reports.length,0);
});
