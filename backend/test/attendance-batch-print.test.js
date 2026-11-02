import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import {installAttendanceBatchPrintApi} from '../src/attendance-batch-print.js';
const response=()=>({code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}});
function api({employees=[{employee_id:'E1',name:'Employee One',branch_id:'A',address:''}],pool=null}={}){
  const queries=[];let handler;
  installAttendanceBatchPrintApi({get(path,auth,fn){assert.equal(path,'/api/attendance-sheet/print-batch');handler=fn;}},
    {authenticate:()=>{},pool:pool??{async query(sql,params){queries.push({sql,params});
      if(sql.includes('FROM public.employees'))return {rows:employees};
      if(sql.includes('FROM public.attendance'))return {rows:[{data:{employee_id:'E1',attendance_date:'2026-10-01',status:'Present'}}]};
      return {rows:[]};}}});
  return {queries,async run(user={role:'ADMIN'},query={employees:'["E1"]',branch_id:'A',year:2026,month:10},auth={}){const res=response();await handler({user,query,auth},res);return res;}};
}
test('admin and owning branch receive one combined read-only batch',async()=>{
  for(const user of [{role:'ADMIN'},{role:'BRANCH',branchId:'A'}]){
    const a=api();const res=await a.run(user);assert.equal(res.code,200);assert.equal(res.body.employees.length,1);assert.equal(res.body.attendance.length,1);
    assert.equal(a.queries.length,6);assert.ok(a.queries.every(q=>! /\b(INSERT|UPDATE|DELETE)\b/i.test(q.sql)));
    assert.deepEqual(a.queries[1].params,[['E1'],'2026-10-01']);
  }
});
test('batch denies unauthorized roles, another branch and absent employee identities',async()=>{
  const a=api();assert.equal((await a.run({role:'EMPLOYEE'})).code,403);assert.equal(a.queries.length,0);
  assert.equal((await a.run({role:'BRANCH',branchId:'B'})).code,403);assert.equal(a.queries.length,0);
  const unavailable=api({employees:[]});assert.equal((await unavailable.run()).code,403);assert.equal(unavailable.queries.length,1);
});
test('batch validates all selectors and enforces local/foreign staff scope',async()=>{
  for(const employees of ['[]','bad','[1]',JSON.stringify(Array(101).fill('E1'))]){
    const a=api();assert.equal((await a.run({role:'ADMIN'},{employees,year:2026,month:10,branch_id:'A'})).code,400);assert.equal(a.queries.length,0);
  }
  for(const app_metadata of [{is_reviewer:true},{staff_scope:'requests'}]){const a=api();assert.equal((await a.run({role:'ADMIN'},undefined,{app_metadata})).code,403);assert.equal(a.queries.length,0);}
  const scoped=api();assert.equal((await scoped.run({role:'ADMIN'},undefined,{app_metadata:{staff_scope:'foreign'}})).code,403);
  assert.equal(scoped.queries.length,1);
});
test('actual batch SQL reads selected employees and only their selected month', {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
  const {default:pg}=await import('pg');const {readFile}=await import('node:fs/promises');
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_batch_print_test');url.pathname='/hasani_batch_print_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  try{
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    await pool.query(`INSERT INTO branches(id,name) VALUES('A','A'),('B','B');
      INSERT INTO employees(employee_id,name,branch_id) VALUES('E1','One','A'),('E2','Two','A'),('E3','Three','B');
      INSERT INTO attendance(id,employee_id,branch_id,attendance_date) VALUES('a1','E1','A','2026-10-01'),('a2','E2','A','2026-10-01'),('a3','E1','A','2026-09-01');
      INSERT INTO employee_salary_defaults(employee_id,basic_salary) VALUES('E1',2000),('E2',2500);
      INSERT INTO payroll(id,employee_id,period,overtime) VALUES('p1','E1','2026-10-01',20);`);
    const a=api({pool});const res=await a.run({role:'ADMIN'},{employees:'["E1","E2"]',branch_id:'A',year:2026,month:10});
    assert.equal(res.code,200);assert.equal(res.body.employees.length,2);assert.equal(res.body.attendance.length,2);assert.equal(res.body.payroll[0].overtime,'20.00');
    assert.equal((await a.run({role:'ADMIN'},{employees:'["E1","E3"]',branch_id:'A',year:2026,month:10})).code,403);
  }finally{await pool.end();await dropFixtureDatabase(bootstrap, 'hasani_batch_print_test');await bootstrap.end();}
});
