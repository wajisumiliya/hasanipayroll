import test from 'node:test';
import assert from 'node:assert/strict';
import {buildApprovedOtReport,installApprovedOtReportApi} from '../src/approved-ot-report.js';
import {renderLateReport} from '../src/late-report-export.js';
const row=(id,date,minutes,extra={})=>({employee_id:id,name:'Employee '+id,branch_id:'A',attendance_date:date,approved_ot_minutes:minutes,basic_salary:'2600',epf_category:'normal1',eis_applicable:true,...extra});
const build=(rows,extra={})=>buildApprovedOtReport(rows,{year:2026,month:10,...extra});
test('approved OT aggregates unique employee dates and uses payable payroll rates',()=>{
  const rows=[row('E1','2026-10-01',60),row('E1','2026-10-01',60),row('E1','2026-10-02',90),
    row('E2','2026-10-03',null,{overtime_minutes:120,ot_authorized:true}),row('E3','2026-10-03',29),
    row('HED1016','2026-10-01',120),row('E4','2026-09-30',60)];
  assert.deepEqual(build(rows),[{employee_id:'E1',name:'Employee E1',approved_minutes:150,approved_hours:2.5,ot_amount:50}]);
});
test('weekly roster including overnight allocation controls rate and unknown salaries remain unknown',()=>{
  const rows=build([row('E1','2026-10-01',60,{shift_start:'22:00:00',shift_end:'06:00:00',break_minutes:60}),
    row('E2','2026-10-01',60,{basic_salary:null}),row('E3','2026-10-01',60,{basic_salary:100})]);
  assert.equal(rows[0].ot_amount,21.4);assert.equal(rows[1].ot_amount,null);assert.equal(rows[2].ot_amount,0);
});
test('OT report keeps month, branch, employee and local/foreign selections',()=>{
  const rows=[row('E1','2026-10-01',60),row('E2','2026-10-01',60,{branch_id:'B',address:'FRN'})];
  assert.deepEqual(build(rows,{branchId:'B'}).map(r=>r.employee_id),['E2']);
  assert.deepEqual(build(rows,{staffScope:'local'}).map(r=>r.employee_id),['E1']);
  assert.deepEqual(build(rows,{staffScope:'foreign'}).map(r=>r.employee_id),['E2']);
  assert.deepEqual(build(rows,{employeeIds:new Set() }),[]);
});
const response=()=>({code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}});
function api(){let handler,payload;const queries=[];
  installApprovedOtReportApi({get(path,auth,fn){assert.equal(path,'/api/attendance/approved-ot-report');handler=fn;}},
    {authenticate:()=>{},pool:{async query(sql,params){queries.push({sql,params});return {rows:sql.includes('FROM public.attendance')?[row('E1','2026-10-01',60)]:[{id:'A',name:'ALOR SETAR'}]};}},
      renderExport:async data=>{payload=data;return Buffer.from('pdf');}});
  return {queries,get payload(){return payload;},async run(user,query={year:2026,month:10},auth={}){const res=response();await handler({user,query,auth},res);return res;}};
}
test('OT API guards roles, reviewer, request scope and invalid input before querying',async()=>{
  for(const role of ['BRANCH','EMPLOYEE','']){const a=api();assert.equal((await a.run({role})).code,403);assert.equal(a.queries.length,0);}
  for(const app_metadata of [{is_reviewer:true},{staff_scope:'requests'}]){const a=api();assert.equal((await a.run({role:'ADMIN'},undefined,{app_metadata})).code,403);}
  const a=api();assert.equal((await a.run({role:'ADMIN'},{year:2026,month:13})).code,400);assert.equal(a.queries.length,0);
  assert.equal((await a.run({role:'ADMIN'},{year:2026,month:10,employees:'bad'})).code,400);
});
test('OT PDF API preserves report scope and queries only selected approval inputs',async()=>{
  const a=api();const res=await a.run({role:'ADMIN'},{year:2026,month:10,branch_id:'A',employees:'["E1"]',format:'pdf'});
  assert.equal(res.code,200);assert.equal(res.body.file_base64,Buffer.from('pdf').toString('base64'));
  assert.equal(a.payload.view,'ot-summary');assert.equal(a.payload.reports[0].ot_amount,20);
  assert.deepEqual(a.queries[0].params,['2026-10-01',2026,10,'A',['E1']]);
  assert.equal(a.payload.branchLabel,'ALOR SETAR');
});
test('OT PDFs include empty and dense selections on one real A4 page',async()=>{
  for(const reports of [[],build(Array.from({length:100},(_,i)=>row('E'+i,'2026-10-01',60)))]){
    const bytes=await renderLateReport({format:'pdf',view:'ot-summary',year:2026,month:10,reports,branchLabel:'All branches'});
    assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
    assert.equal((bytes.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,1);
  }
});

test('OT API SQL uses saved approvals, weekly allocations and payroll-period basic pay', {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL}, async()=>{
  const {default:pg}=await import('pg');const {readFile}=await import('node:fs/promises');
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_ot_report_test');url.pathname='/hasani_ot_report_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  try{
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    await pool.query(`INSERT INTO branches(id,name) VALUES('A','ALOR SETAR');
      INSERT INTO employees(employee_id,name,branch_id) VALUES('OT1','OT Employee','A');
      INSERT INTO employee_salary_defaults(employee_id,basic_salary,epf_category,eis_applicable) VALUES('OT1',2600,'normal1',true);
      INSERT INTO monthly_rosters(branch_id,employee_id,roster_year,roster_month,week_number,shift_start,shift_end,break_minutes)
        VALUES('A','OT1',2026,10,1,'09:00','17:30',60),('A','OT1',2026,10,2,'09:00','18:00',60);
      INSERT INTO attendance(id,employee_id,branch_id,attendance_date,approved_ot_minutes,overtime_minutes)
        VALUES('a1','OT1','A','2026-10-01',60,60),('a2','OT1','A','2026-10-08',60,60),('a3','OT1','A','2026-10-03',NULL,120);`);
    let handler;installApprovedOtReportApi({get(path,auth,fn){handler=fn;}},{authenticate:()=>{},pool});
    const run=async()=>{const res=response();await handler({user:{role:'ADMIN'},query:{year:2026,month:10},auth:{}},res);assert.equal(res.code,200);return res.body.reports;};
    assert.equal((await run())[0].approved_minutes,120);assert.equal((await run())[0].ot_amount,38.8);
    await pool.query("INSERT INTO payroll(id,employee_id,period,basic_salary) VALUES('p1','OT1','2026-10-01',2860)");
    assert.equal((await run())[0].ot_amount,42.6);
  }finally{await pool.end();await bootstrap.query('DROP DATABASE hasani_ot_report_test WITH (FORCE)');await bootstrap.end();}
});
