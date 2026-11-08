import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import ExcelJS from 'exceljs';
import {temporaryPayrollInput,installSalaryReportTemporaryApi} from '../src/salary-report-temporary.js';
import {buildSalaryReport,installSalaryReportApi} from '../src/salary-report.js';
import {renderLateReport} from '../src/late-report-export.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
const input={employee_id:'OLD1',employee_name:'Historical Employee',branch_id:'B',staff_scope:'local',from_month:'2025-07',through_month:'2025-07',basic_salary:2000,allowances:250,other_earnings:0,deductions:50,notes:'Historical payslip checked'};
function routes(pool){
 const handlers={};const app={};for(const method of ['get','post','put','delete'])app[method]=(p,a,f)=>handlers[method.toUpperCase()+' '+p]=f;
 installSalaryReportTemporaryApi(app,{pool,authenticate(){}});
 installSalaryReportApi(app,{pool,authenticate(){},renderExport:renderLateReport});
 return async(method='GET',body={},scope=null,role='admin',path='/api/reports/salary/temporary-payroll')=>{
  const res={code:200,status(c){this.code=c;return this;},json(b){this.body=b;return this;},set(){}};
  await handlers[method+' '+path]({body,query:{start_year:2025,...body},user:{role,id:'TEST-ADMIN'},auth:{app_metadata:typeof scope==='object'?scope:{staff_scope:scope}}},res);return res;
 };
}
test('temporary payroll validates precision, ranges, classification and finite nonnegative components',()=>{
 assert.equal(temporaryPayrollInput(input).basic_salary,2000);
 for(const extra of [{basic_salary:-1},{allowances:'1.234'},{basic_salary:Infinity},{deductions:'NaN'},{other_earnings:{}},{staff_scope:'unknown'},{branch_id:''},{through_month:'2026-07'},{notes:'x'.repeat(2001)},{employee_name:{}}])
  assert.equal(temporaryPayrollInput({...input,...extra}),null);
 assert.ok(temporaryPayrollInput({...input,through_month:'2026-06',basic_salary:'0.00'}));
});
test('all temporary payroll endpoints deny non-payroll admins before accessing data',async()=>{
 const run=routes({query(){assert.fail('Must not query');},connect(){assert.fail('Must not connect');}});
 for(const method of ['GET','POST','PUT','DELETE']){
  for(const role of ['employee','branch','reviewer'])assert.equal((await run(method,input,null,role)).code,403);
  for(const scope of [{is_reviewer:true},{staff_scope:'attendance'},{staff_scope:'requests'}])assert.equal((await run(method,input,scope)).code,403);
 }
 assert.equal((await run('POST',{})).code,400);
 assert.equal((await run('PUT',{...input,through_month:'2025-08'})).code,400);
 assert.equal((await run('GET',{start_year:1999})).code,400);
});
test('report merges historical-only employees, respects branch assignments and never double counts a real month',async()=>{
 const build=extra=>buildSalaryReport({startYear:2025,employees:[{employee_id:'E1',name:'Existing',branch_id:'A',is_active:true}],
  payroll:[{employee_id:'E1',period:'2025-07-01',basic_salary:2100}],branches:[{id:'A',name:'A'},{id:'B',name:'B'}],
  temporaryPayroll:[{employee_id:'E1',employee_name:'Existing',month:'2025-07',branch_id:'B',amount:9999},
   {employee_id:'E1',employee_name:'Existing',month:'2025-08',branch_id:'B',amount:2200},
   {employee_id:'OLD1',employee_name:'Historical Employee',month:'2025-07',branch_id:'B',amount:0},
   {employee_id:'OLD1',employee_name:'Historical Employee',month:'2025-08',branch_id:'B',amount:2300}],...extra});
 const r=build();assert.equal(r.employee_count,2);assert.equal(r.temporary_count,3);
 assert.equal(r.branches[0].rows[0].values[0],2100);
 const b=r.branches.find(b=>b.id==='B');assert.deepEqual(b.rows.find(e=>e.employee_id==='E1').values.slice(0,2),[null,2200]);
 assert.deepEqual(b.rows.find(e=>e.employee_id==='OLD1').values.slice(0,3),[0,2300,null]);
 assert.deepEqual(b.rows.find(e=>e.employee_id==='OLD1').temporary_months,['2025-07','2025-08']);
 const moved=build({assignments:[{employee_id:'E1',month:'2025-08',branch_id:'A'}]});
 assert.equal(moved.branches[0].rows[0].values[1],2200);
 const xlsx=await renderLateReport({view:'salary-report',format:'xlsx',report:r});
 const book=new ExcelJS.Workbook();await book.xlsx.load(xlsx);
 const sheet=book.worksheets.find(s=>s.name==='B');
 assert.equal(sheet.getCell('D7').value,0);assert.equal(sheet.getCell('E7').value,2300);
 assert.match(sheet.getCell('E7').note,/Temporary historical reconciliation/);
 const pdf=await renderLateReport({view:'salary-report',format:'pdf',report:r});
 assert.equal(pdf.subarray(0,5).toString(),'%PDF-');assert.equal((pdf.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,2);
 assert.throws(()=>build({temporaryPayroll:[{employee_id:'OLD1',month:'2025-07',branch_id:'B',amount:10},{employee_id:'OLD1',month:'2025-07',branch_id:'B',amount:20}]}),/duplicate OLD1/);
});
test('real temporary payroll CRUD supports missing and inactive employees, scopes and actual-payroll precedence',
 {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
 assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
 const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_salary_temporary_test');url.pathname='/hasani_salary_temporary_test';
 const pool=new pg.Pool({connectionString:url.toString()});
 try{
  await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
  await pool.query(`CREATE SCHEMA app_private;
   INSERT INTO branches(id,name) VALUES('A','AMANJAYA'),('B','GURUN');
   INSERT INTO employees(employee_id,name,branch_id,joining_date,address,is_active) VALUES('E1','Existing Employee','A','2024-01-01','',false),('FRN','Foreign Employee','A','2024-01-01','FRN',true);`);
  for(const migration of ['20261107_salary_report_branch_assignments.sql','20261108_salary_report_temporary_payroll.sql'])await pool.query(await readFile(new URL('../migrations/'+migration,import.meta.url),'utf8'));
  const run=routes(pool);
  assert.equal((await run('POST',{...input,through_month:'2025-08'},'local')).body.months,2);
  assert.equal((await pool.query("SELECT count(*)::int n FROM employees WHERE employee_id='OLD1'")).rows[0].n,0);
  assert.equal((await pool.query('SELECT count(*)::int n FROM payroll')).rows[0].n,0);
  assert.equal((await run('POST',{...input,through_month:'2025-09'},'local')).code,409);
  assert.equal((await pool.query("SELECT count(*)::int n FROM app_private.salary_report_temporary_payroll WHERE employee_id='OLD1'")).rows[0].n,2);
  assert.equal((await run('POST',{...input,employee_id:'E1',employee_name:''},'local')).code,200);
  const existing=(await run('GET',{},'local')).body;
  assert.equal(existing.employees.find(e=>e.employee_id==='E1').name,'Existing Employee');
  assert.equal(existing.entries.find(e=>e.employee_id==='E1').employee_name,'Existing Employee');
  assert.equal((await run('POST',{...input,employee_id:'FRN'},'local')).code,404);
  assert.equal((await run('POST',{...input,employee_id:'OLD-FRN',staff_scope:'foreign'},'local')).code,403);
  assert.equal((await run('POST',{...input,employee_id:'OLD-FRN',staff_scope:'foreign'},'foreign')).code,200);
  assert.equal((await run('DELETE',{...input,employee_id:'OLD-FRN'},'local')).code,404);
  assert.equal((await run('PUT',{...input,employee_id:'OLD-FRN'},'local')).code,404);
  assert.ok((await run('GET',{},'local')).body.entries.every(e=>e.employee_id!=='OLD-FRN'));
  assert.equal((await run('PUT',{...input,basic_salary:2100},'local')).code,200);
  assert.equal((await run('PUT',{...input,employee_id:'MISSING'},'local')).code,404);
  const report=(await run('GET',{},'local','admin','/api/reports/salary')).body.report;
  assert.equal(report.employee_count,2);assert.equal(report.temporary_count,3);
  assert.deepEqual(report.branches[0].rows.find(e=>e.employee_id==='OLD1').values.slice(0,2),[2300,2200]);
  assert.equal((await run('GET',{format:'xlsx'},'local','admin','/api/reports/salary')).code,200);
  assert.equal((await run('GET',{format:'pdf'},'local','admin','/api/reports/salary')).code,200);
  const creates=await Promise.all([run('POST',{...input,employee_id:'RACE'}),run('POST',{...input,employee_id:'RACE'})]);
  assert.deepEqual(creates.map(r=>r.code).sort(),[200,409]);
  await pool.query("INSERT INTO employees(employee_id,name,branch_id,joining_date) VALUES('OLD1','Now Registered','A','2024-01-01'); INSERT INTO payroll(id,employee_id,period,basic_salary) VALUES('P1','OLD1','2025-07-01',2500)");
  assert.equal((await run('PUT',input,'local')).code,409);
  assert.equal((await run('POST',input,'local')).code,409);
  const after=(await run('GET',{},'local','admin','/api/reports/salary')).body.report;
  assert.equal(after.branches.find(b=>b.id==='A').rows.find(e=>e.employee_id==='OLD1').values[0],2500);
  assert.equal(after.branches.find(b=>b.id==='B').rows.find(e=>e.employee_id==='OLD1').values[0],null);
  assert.equal((await run('GET',{},'local')).body.entries.find(e=>e.employee_id==='OLD1'&&e.month==='2025-07').has_saved_payroll,true);
  assert.equal((await run('DELETE',input,'local')).body.months,1);
  assert.equal((await pool.query("SELECT basic_salary::float FROM payroll WHERE id='P1'")).rows[0].basic_salary,2500);
  assert.equal((await pool.query("SELECT branch_id FROM employees WHERE employee_id='E1'")).rows[0].branch_id,'A');
 }finally{await pool.end();await dropFixtureDatabase(bootstrap,'hasani_salary_temporary_test');await bootstrap.end();}
});
