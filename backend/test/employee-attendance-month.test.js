import test from 'node:test';
import assert from 'node:assert/strict';
import {installEmployeeAttendanceMonthApi} from '../src/employee-attendance-month.js';
function api(){
  const calls=[]; let handler;
  const attendance=[{employee_id:'HED2064',branch_id:'JITRA',attendance_date:'2026-10-01',check_in:'09:00',is_submitted:true},
    {employee_id:'HED2064',branch_id:'ASTANA',attendance_date:'2026-10-21',check_in:'09:30',is_submitted:false}];
  installEmployeeAttendanceMonthApi({get(path,auth,fn){assert.equal(path,'/api/attendance/employee-month');handler=fn;}},
    {authenticate(){},pool:{async query(sql,params){calls.push({sql,params});return sql.includes('public.employees')
      ? {rows:[{employee_id:'HED2064',branch_id:'ASTANA'}]} : {rows:attendance.map(data=>({data}))};}}});
  return {calls,async run(user,query={employee_id:'HED2064',year:2026,month:10}){
    const res={code:200,status(n){this.code=n;return this;},json(body){this.body=body;return this;}};
    await handler({user,query},res);return res;
  }};
}
test('destination branch loads both source submitted rows and destination draft rows without changing them',async()=>{
  const a=api();const res=await a.run({role:'BRANCH',branchId:' astana '});
  assert.equal(res.code,200);assert.equal(res.body.attendance.length,2);
  assert.equal(res.body.attendance[0].branch_id,'JITRA');assert.equal(res.body.attendance[0].is_submitted,true);
  assert.equal(res.body.attendance[1].is_submitted,false);
  assert.deepEqual(a.calls[1].params,['HED2064',2026,10]);
  assert.match(a.calls[1].sql,/a.employee_id=\$1/);assert.match(a.calls[1].sql,/< \(make_date/);
  assert.doesNotMatch(a.calls[1].sql,/branch_id|INSERT|UPDATE|DELETE/i);
});
test('source and unrelated branches cannot read the transferred employee sheet',async()=>{
  for(const branchId of ['JITRA','OTHER','']){const a=api();assert.equal((await a.run({role:'BRANCH',branchId})).code,403);assert.equal(a.calls.length,1);}
});
test('admin and own employee may read; another employee and unknown roles cannot',async()=>{
  for(const user of [{role:'ADMIN'},{role:'EMPLOYEE',employeeId:'HED2064'}]){assert.equal((await api().run(user)).code,200);}
  for(const user of [{role:'EMPLOYEE',employeeId:'OTHER'},{role:'GUEST'}]){const a=api();assert.equal((await a.run(user)).code,403);assert.equal(a.calls.length,0);}
});
test('invalid month and employee are rejected before SQL',async()=>{
  for(const query of [{employee_id:'',year:2026,month:10},{employee_id:'HED2064',year:2026,month:13}]){
    const a=api();assert.equal((await a.run({role:'ADMIN'},query)).code,400);assert.equal(a.calls.length,0);
  }
});
