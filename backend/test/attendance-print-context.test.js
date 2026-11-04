import test from 'node:test';
import assert from 'node:assert/strict';
import {installAttendancePrintContextApi} from '../src/attendance-print-context.js';
function setup({branch='A',exists=true,payroll=[]}={}) {
  const calls=[];let handler;
  const authenticate=()=>{};
  installAttendancePrintContextApi({get(path,auth,fn){
    assert.equal(path,'/api/attendance-sheet/print-context');assert.equal(auth,authenticate);handler=fn;
  }},{authenticate,pool:{async query(sql,values){
    calls.push({sql,values});
    if(sql.includes('FROM public.employees'))return {rows:exists?[{employee_id:'E1',branch_id:branch}]:[]};
    if(sql.includes('employee_salary_defaults'))return {rows:[{basic_salary:2600,address:'',epf_category:'normal1',eis_applicable:true}]};
    if(sql.includes('FROM public.payroll'))return {rows:payroll};
    return {rows:[{data:{branch_id:branch,week_number:1}}]};
  }}});
  return {calls,async run(user,query={employee_id:'E1',year:'2026',month:'10'}){
    const res={statusCode:200,status(code){this.statusCode=code;return this;},json(body){this.body=body;return this;}};
    await handler({user,query},res);return res;
  }};
}
test('admin can print an employee from any branch without payroll',async()=>{
  const api=setup();const res=await api.run({role:'ADMIN'});
  assert.equal(res.statusCode,200);assert.equal(res.body.salary.basic_salary,2600);
  assert.equal(res.body.payroll,null);assert.equal(res.body.monthly_rosters.length,1);
  assert.ok(api.calls.every(({sql})=>! /\b(insert|update|delete)\b/i.test(sql)));
});
test('branch can print own employee with saved monetary amounts',async()=>{
  const saved={basic_salary:1700,overtime:200,late_deduction:10,unpaid_deduction:83.87};
  const api=setup({payroll:[saved]});const res=await api.run({role:'BRANCH',branchId:' a '});
  assert.equal(res.statusCode,200);assert.deepEqual(res.body.payroll,saved);
  assert.deepEqual(api.calls[2].values,['E1',2026,10]);
  assert.match(api.calls[2].sql,/SELECT basic_salary,/);
});
test('cross-branch and missing branch identities cannot read print salaries',async()=>{
  for(const user of [{role:'BRANCH',branchId:'B'},{role:'BRANCH'}]){
    const api=setup();assert.equal((await api.run(user)).statusCode,403);assert.equal(api.calls.length,1);
  }
});
test('employee and unrecognized roles cannot use branch/admin print values',async()=>{
  for(const role of ['EMPLOYEE','ATTENDANCE_ADMIN','OTHER','']){
    const api=setup();assert.equal((await api.run({role})).statusCode,403);assert.equal(api.calls.length,0);
  }
});
test('invalid print selection rejected before database query',async()=>{
  const api=setup();assert.equal((await api.run({role:'ADMIN'},{employee_id:'E1',year:'2026',month:'13'})).statusCode,400);
  assert.equal(api.calls.length,0);
});
test('missing employee and duplicate payroll give explicit errors',async()=>{
  const missing=setup({exists:false});assert.equal((await missing.run({role:'ADMIN'})).statusCode,404);
  const duplicate=setup({payroll:[{},{}]});assert.equal((await duplicate.run({role:'ADMIN'})).statusCode,409);
});
