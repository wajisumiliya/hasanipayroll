import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {assignmentRange,installSalaryReportAssignmentsApi} from '../src/salary-report-assignments.js';
import {installSalaryReportApi} from '../src/salary-report.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
function routes(pool){
 const handlers={};const app={get(p,a,f){handlers['GET '+p]=f;},post(p,a,f){handlers['POST '+p]=f;},delete(p,a,f){handlers['DELETE '+p]=f;}};
 installSalaryReportAssignmentsApi(app,{pool,authenticate(){}});
 installSalaryReportApi(app,{pool,authenticate(){},renderExport:async()=>Buffer.from('export')});
 return async(method='GET',body={},scope=null,role='admin',path='/api/reports/salary/branch-assignments')=>{
  const res={code:200,status(c){this.code=c;return this;},json(b){this.body=b;return this;},set(){}};
  await handlers[method+' '+path]({body,query:{start_year:2025,...body},user:{role,id:'TEST-ADMIN'},auth:{app_metadata:typeof scope==='object'?scope:{staff_scope:scope}}},res);
  return res;
 };
}
test('assignment validation handles invalid months, reversed ranges and excessive ranges',()=>{
 assert.deepEqual(assignmentRange({employee_id:' e1 ',branch_id:'B',from_month:'2025-07',through_month:'2026-06'}),{employee:'E1',branch:'B',from:'2025-07-01',through:'2026-06-01'});
 assert.ok(assignmentRange({employee_id:'E1',branch_id:'B',from_month:'2099-07',through_month:'2100-06'}));
 for(const fields of [{from_month:'2025-13'}, {from_month:'2026-07'}, {through_month:'2200-01'}, {employee_id:''}, {from_month:'2020-01',through_month:'2030-01'}])
  assert.equal(assignmentRange({employee_id:'E1',branch_id:'B',from_month:'2025-07',through_month:'2026-06',...fields}),null);
});
test('assignment reads and writes require a payroll admin before any database access',async()=>{
 const run=routes({query(){assert.fail('Must not query');},connect(){assert.fail('Must not connect');}});
 for(const method of ['GET','POST','DELETE']){
  for(const role of ['employee','branch','reviewer']) assert.equal((await run(method,{},null,role)).code,403);
  for(const scope of [{is_reviewer:true},{staff_scope:'attendance'},{staff_scope:'requests'}])assert.equal((await run(method,{},scope)).code,403);
 }
 assert.equal((await run('POST',{})).code,400);
 assert.equal((await run('GET',{start_year:1999})).code,400);
});
test('real assignments persist atomically, enforce scopes, preserve BAS025 and drive report grouping',
 {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
 assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
 const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_salary_assignments_test');
 url.pathname='/hasani_salary_assignments_test';const pool=new pg.Pool({connectionString:url.toString()});
 try{
  await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
  await pool.query(`CREATE SCHEMA app_private;
   INSERT INTO branches(id,name) VALUES('A','AMANJAYA'),('B','GURUN');
   INSERT INTO employees(employee_id,name,branch_id,joining_date,address) VALUES
    ('E1','Local','A','2024-01-01',''),('E2','Foreign','A','2024-01-01','FRN'),('BAS025','Historical','A','2024-01-01','');
   INSERT INTO payroll(id,employee_id,period,basic_salary) VALUES
    ('P1','E1','2025-07-01',2000),('P2','E1','2025-08-01',2100),('P3','E2','2025-07-01',1700),('P4','BAS025','2025-07-01',2200);`);
  const migration=await readFile(new URL('../migrations/20261107_salary_report_branch_assignments.sql',import.meta.url),'utf8');
  await pool.query(migration);await pool.query(migration);
  assert.equal((await pool.query("SELECT count(*)::int n FROM app_private.salary_report_branch_assignments WHERE employee_id='BAS025'")).rows[0].n,12);
  const run=routes(pool),body={employee_id:'E1',branch_id:'B',from_month:'2025-07',through_month:'2025-07'};
  assert.equal((await run('POST',body,'local')).body.months,1);
  assert.equal((await run('POST',{...body,through_month:'2025-08'},'local')).code,409);
  assert.equal((await pool.query("SELECT count(*)::int n FROM app_private.salary_report_branch_assignments WHERE employee_id='E1'")).rows[0].n,1);
  assert.equal((await run('POST',{...body,employee_id:'E2'},'local')).code,404);
  assert.equal((await run('DELETE',{...body,employee_id:'E2'},'local')).code,404);
  assert.equal((await run('POST',{...body,from_month:'2025-08',through_month:'2025-08',branch_id:'MISSING'})).code,400);
  assert.equal((await run('POST',{...body,employee_id:'E2'},'foreign')).code,200);
  const local=await run('GET',{},'local');
  assert.deepEqual(local.body.employees.map(e=>e.employee_id),['BAS025','E1']);
  assert.ok(local.body.assignments.every(a=>a.employee_id!=='E2'));
  const report=(await run('GET',{},null,'admin','/api/reports/salary')).body.report;
  assert.equal(report.branches.find(b=>b.id==='B').rows.find(e=>e.employee_id==='E1').values[0],2000);
  assert.equal(report.branches.find(b=>b.id==='A').rows.find(e=>e.employee_id==='E1').values[1],2100);
  const concurrent={...body,from_month:'2025-09',through_month:'2025-10'};
  const results=await Promise.all([run('POST',concurrent),run('POST',concurrent)]);
  assert.deepEqual(results.map(r=>r.code).sort(),[200,409]);
  assert.equal((await run('DELETE',body,'local')).body.months,1);
  const restored=(await run('GET',{},null,'admin','/api/reports/salary')).body.report;
  assert.equal(restored.branches.find(b=>b.id==='A').rows.find(e=>e.employee_id==='E1').values[0],2000);
  // The historical correction is editable, not a hidden fallback.
  assert.equal((await run('DELETE',{employee_id:'BAS025',from_month:'2025-07',through_month:'2026-06'})).body.months,12);
  const after=(await run('GET',{},null,'admin','/api/reports/salary')).body.report;
  assert.equal(after.branches.find(b=>b.id==='A').rows.find(e=>e.employee_id==='BAS025').values[0],2200);
  assert.equal((await pool.query("SELECT branch_id FROM employees WHERE employee_id='E1'")).rows[0].branch_id,'A');
  assert.equal((await pool.query("SELECT basic_salary::float FROM payroll WHERE id='P1'")).rows[0].basic_salary,2000);
 }finally{await pool.end();await dropFixtureDatabase(bootstrap,'hasani_salary_assignments_test');await bootstrap.end();}
});
