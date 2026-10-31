import test from 'node:test';
import assert from 'node:assert/strict';
import {buildStatusReport,installAttendanceStatusReportApi,applyMcBalances} from '../src/attendance-status-report.js';
import {renderLateReport} from '../src/late-report-export.js';
const row=(employee_id,date,status,extra={})=>({attendance:{employee_id,attendance_date:date,branch_id:'A',status,...extra},employee:{name:employee_id,address:'LOCAL'}});
const records=[row('E1','2026-10-01','MC'),row('E1','2026-10-01','MC'),row('E1','2026-10-02','MC'),row('E2','2026-10-03','UNPAID'),row('E3','2026-10-04','Present',{is_unpaid:true}),row('E4','2026-10-05','Present'),row('E5','2026-10-06','UL-UNPAID')];
test('MC and UL-UNPAID-only unpaid lists use unique employee dates',()=>{
 const mc=buildStatusReport(records,{status:'MC'});assert.equal(mc.length,1);assert.equal(mc[0].count,2);
 assert.equal(buildStatusReport(records,{status:'UNPAID'}).length,1);
 assert.equal(buildStatusReport(records,{status:'MC',branchId:'B'}).length,0);
 assert.equal(buildStatusReport(records,{status:'MC',staffScope:'foreign'}).length,0);
 assert.equal(buildStatusReport(records,{status:'UNPAID',employeeIds:new Set(['E5'])})[0].employee_id,'E5');
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
   if(sql.includes('app_private.employee_mc_openings'))return {rows:[{employee_id:'E1',opening_month:'2026-10-01',balance:10,prior_taken:0,current_taken:2}]};
   if(sql.includes('FROM public.attendance')) {assert.equal(params[0],'2026-10-01');return {rows:records};}
   return {rows:[{id:'A',name:'ALOR SETAR'}]};
 }},renderExport:async data=>{payload=data;return Buffer.from('pdf');}});
 const query={year:2026,month:10,status:'MC',branch_id:'A',employees:'["E1"]'};
 const res=response();await handler({user:{role:'ADMIN'},query},res);assert.equal(res.body.reports[0].count,2);assert.equal(res.body.reports[0].opening_mc,10);assert.equal(res.body.reports[0].closing_mc,8);
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

test('MC and unpaid PDFs retain a dense full selection on exactly one A4 page',async()=>{
 for(const status of ['MC','UNPAID']) {
   const reports=Array.from({length:100},(_,i)=>({employee_id:`E${i}`,name:`Long employee name ${i}`,branch_id:'A',count:31,
     dates:Array.from({length:31},(_,d)=>`2026-10-${String(d+1).padStart(2,'0')}`)}));
   const bytes=await renderLateReport({view:'status-summary',format:'pdf',status,year:2026,month:10,reports,branches:{A:'ALOR SETAR'},branchLabel:'All branches'});
   const content=bytes.toString('latin1');
   assert.equal((content.match(/\/Type \/Page\b/g)??[]).length,1);
   assert.match(content,/\/MediaBox \[0 0 (595\.28 841\.89|841\.89 595\.28)\]/);
 }
});

test('MC opening minus usage closes the month and preserves unknown balances',()=>{
 const reports=[{employee_id:'E1',branch_id:'A',count:5,dates:['2026-10-01','2026-10-02','2026-10-03','2026-10-04','2026-10-05']}];
 const source=[{employee_id:'E1',opening_month:'2026-10-01',balance:10,prior_taken:0,current_taken:5}];
 const october=applyMcBalances(reports,source)[0];
 assert.equal(october.opening_mc,10);assert.equal(october.mc_taken,5);assert.equal(october.closing_mc,5);
 assert.deepEqual(applyMcBalances(reports,source)[0],october); // Printing twice never deducts twice.
 const november=applyMcBalances(reports,[{...source[0],prior_taken:5,current_taken:2}])[0];
 assert.equal(november.opening_mc,5);assert.equal(november.closing_mc,3);
 assert.equal(applyMcBalances(reports,[])[0].opening_mc,null);
 assert.equal(applyMcBalances(reports,[])[0].closing_mc,null);
 assert.equal(applyMcBalances(reports,[{...source[0],current_taken:12}])[0].closing_mc,-2);
});
test('MC balances are per employee across branch transfers without duplicate employees',()=>{
 const result=applyMcBalances([
   {employee_id:'E1',branch_id:'A',dates:['2026-10-01'],count:1},
   {employee_id:'E1',branch_id:'B',dates:['2026-10-01','2026-10-02'],count:2}
 ],[{employee_id:'E1',balance:10,current_taken:2,prior_taken:0}]);
 assert.equal(result.length,1);assert.equal(result[0].count,2);assert.equal(result[0].closing_mc,8);
 assert.deepEqual(result[0].branch_ids,['A','B']);
});
