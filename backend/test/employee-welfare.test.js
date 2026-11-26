import test from 'node:test';
import assert from 'node:assert/strict';
import ExcelJS from 'exceljs';
import {readFile} from 'node:fs/promises';
import {previewWelfare,installEmployeeWelfareApi} from '../src/employee-welfare.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
async function workbook(rows){const book=new ExcelJS.Workbook();const sheet=book.addWorksheet('Welfare');sheet.addRow(['Date','EMPLOYEE_CODE','Ref 1','NAME','Particulars','Project','Amount']);sheet.addRows(rows);return Buffer.from(await book.xlsx.writeBuffer());}
const item=['2026-03-15','E1','REF1','Sample Employee','Staff welfare','A',1000.25];
const employees=[{employee_id:'E1',name:'Sample Employee'},{employee_id:'E2',name:'Second Employee'}];
function routes(pool){
 const handlers={};installEmployeeWelfareApi({get(p,a,f){handlers['GET']=f;},post(p,a,f){handlers['POST']=f;}},{pool,authenticate(){}});
 return async(method,body={},scope=null,role='admin')=>{
  const response={code:200,status(c){this.code=c;return this;},set(){},json(body){this.body=body;return this;}};
  await handlers[method]({body,user:{id:'admin',role},auth:{app_metadata:typeof scope==='string'?{staff_scope:scope}:scope??{}}},response);return response;
 };
}
test('welfare import preserves exact dates, cents, separate transactions and stable repeat keys',async()=>{
 const bytes=await workbook([item,[...item.slice(0,4),'Other gift','A',500],item]);
 const first=await previewWelfare(bytes,employees),again=await previewWelfare(bytes,employees);
 assert.equal(first.entries.length,3);assert.equal(new Set(first.entries.map(e=>e.source_key)).size,3);
 assert.deepEqual(first,again);assert.equal(first.entries[0].payment_date,'2026-03-15');assert.equal(first.entries[0].amount,1000.25);
});
test('unique exact names may match; ambiguous, unknown employees and missing amounts stay pending',async()=>{
 const bytes=await workbook([
  ['15/03/2026','','',' sample   employee ','Gift','A',100],
  ['2026-03-15','','','Sam','Gift','A',100],
  ['2026-03-15','','','Second Employee','Gift','A',100],
  ['2026-03-15','E1','','Sample Employee','Gift','A',null],
  ['2026-02-30','E1','','Sample Employee','Gift','A',100],
  ['2026-03-15','UNKNOWN','','Sample Employee','Gift','A',100],
 ]);
 const result=await previewWelfare(bytes,[...employees,{employee_id:'E3',name:'Second Employee'}]);
 assert.equal(result.entries.length,1);assert.equal(result.entries[0].employee_id,'E1');assert.equal(result.pending.length,5);
});
test('welfare endpoints reject non-payroll admins before database access',async()=>{
 const run=routes({query(){assert.fail('No access');},connect(){assert.fail('No access');}});
 for(const method of ['GET','POST'])for(const role of ['employee','branch','reviewer'])assert.equal((await run(method,{},null,role)).code,403);
 for(const scope of ['attendance','requests',{is_reviewer:true}])assert.equal((await run('GET',{},scope)).code,403);
});
test('real welfare imports are transactional, scoped and idempotent without changing payroll',
 {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
 assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
 const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_welfare_test');url.pathname='/hasani_welfare_test';
 const pool=new pg.Pool({connectionString:url.toString()});
 try{
  await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
  await pool.query("CREATE SCHEMA app_private; INSERT INTO branches(id,name) VALUES('A','A'); INSERT INTO employees(employee_id,name,branch_id,address) VALUES('E1','Sample Employee','A',''),('FRN','Foreign Employee','A','FRN');");
  await pool.query(await readFile(new URL('../migrations/20261126_employee_welfare.sql',import.meta.url),'utf8'));
  const run=routes(pool);const file_base64=(await workbook([item,['2026-03-15','FRN','','Foreign Employee','Gift','A',500]])).toString('base64');
  const preview=await run('POST',{file_base64},'local');assert.equal(preview.body.ready,1);assert.equal(preview.body.pending.length,1);
  assert.equal((await pool.query('SELECT count(*)::int n FROM app_private.employee_welfare')).rows[0].n,0);
  assert.equal((await run('POST',{file_base64,commit:true},'local')).body.imported,1);
  assert.equal((await run('POST',{file_base64,commit:true},'local')).body.already_imported,1);
  assert.equal((await run('GET',{},'local')).body.entries.length,1);assert.equal((await run('GET',{},'foreign')).body.entries.length,0);
  assert.equal((await pool.query('SELECT count(*)::int n FROM payroll')).rows[0].n,0);
 }finally{await pool.end();await dropFixtureDatabase(bootstrap,'hasani_welfare_test');await bootstrap.end();}
});
