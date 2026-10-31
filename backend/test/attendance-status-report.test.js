import test from 'node:test';
import assert from 'node:assert/strict';
import {buildStatusReport,installAttendanceStatusReportApi} from '../src/attendance-status-report.js';
import {renderLateReport} from '../src/late-report-export.js';
const row=(employee_id,date,status,extra={})=>({attendance:{employee_id,attendance_date:date,branch_id:'A',status,...extra},employee:{name:employee_id,address:'LOCAL'}});
const records=[row('E1','2026-10-01','MC'),row('E1','2026-10-01','MC'),row('E1','2026-10-02','MC'),row('E2','2026-10-03','UNPAID'),row('E3','2026-10-04','Present',{is_unpaid:true}),row('E4','2026-10-05','Present')];
test('MC and unpaid lists use saved statuses/flags and unique employee dates',()=>{
 const mc=buildStatusReport(records,{status:'MC'});assert.equal(mc.length,1);assert.equal(mc[0].count,2);
 assert.equal(buildStatusReport(records,{status:'UNPAID'}).length,2);
 assert.equal(buildStatusReport(records,{status:'MC',branchId:'B'}).length,0);
 assert.equal(buildStatusReport(records,{status:'MC',staffScope:'foreign'}).length,0);
 assert.equal(buildStatusReport(records,{status:'UNPAID',employeeIds:new Set(['E3'])})[0].employee_id,'E3');
});
function response(){return {code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}};}
test('status API guards roles and validates selection before querying',async()=>{
 let handler;installAttendanceStatusReportApi({get:(path,auth,fn)=>handler=fn},{authenticate:()=>{},pool:{query:async()=>{throw Error('Must not query');}}});
 for(const role of ['BRANCH','EMPLOYEE']) {const res=response();await handler({user:{role},query:{}},res);assert.equal(res.code,403);}
 const res=response();await handler({user:{role:'ADMIN'},query:{year:2026,month:13,status:'MC'}},res);assert.equal(res.code,400);
});
test('status API preserves month/branch selection for JSON and PDF',async()=>{
 let handler,payload;
 installAttendanceStatusReportApi({get:(path,auth,fn)=>handler=fn},{authenticate:()=>{},pool:{query:async(sql,params)=>{
   if(sql.includes('FROM public.attendance')) {assert.equal(params[0],'2026-10-01');return {rows:records};}
   return {rows:[{id:'A',name:'ALOR SETAR'}]};
 }},renderExport:async data=>{payload=data;return Buffer.from('pdf');}});
 const query={year:2026,month:10,status:'MC',branch_id:'A',employees:'["E1"]'};
 const res=response();await handler({user:{role:'ADMIN'},query},res);assert.equal(res.body.reports[0].count,2);
 const file=response();await handler({user:{role:'ADMIN'},query:{...query,format:'pdf'}},file);
 assert.equal(payload.view,'status-summary');assert.equal(payload.status,'MC');assert.equal(payload.branchLabel,'ALOR SETAR');assert.equal(file.body.file_base64,Buffer.from('pdf').toString('base64'));
});
test('status PDF renders real documents including empty selections',async()=>{
 for(const status of ['MC','UNPAID']) {
   const bytes=await renderLateReport({view:'status-summary',format:'pdf',status,year:2026,month:10,
     reports:buildStatusReport(records,{status}),branches:{A:'ALOR SETAR'},branchLabel:'All branches'});
   assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
 }
});
