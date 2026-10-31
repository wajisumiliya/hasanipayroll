import assert from 'node:assert/strict';
import test from 'node:test';
import { compileTableQuery, withDatabaseIdentity } from '../src/data-api.js';
const columns = new Map([['employee_id','text'],['period','date'],['id','uuid'],['status','text'],['is_submitted','bool'],['approved_ot_minutes','int4'],['is_public_holiday','bool'],['details','jsonb']]);
const compile=(method,search='',body,prefer='')=>compileTableQuery({table:'attendance',method,params:new URLSearchParams(search),body,prefer,columns,primaryKey:['id']});

test('date range, OR and NOT NULL filters preserve attendance query semantics',()=>{
  const query=compile('GET','employee_id=in.(A,B)&period=gte.2026-10-01&or=(is_submitted.eq.true,approved_ot_minutes.not.is.null,is_public_holiday.eq.true)&order=employee_id.asc,period.desc&limit=1000&offset=1000');
  assert.deepEqual(query.values,['A','B','2026-10-01','true','true']);
  assert.match(query.sql,/NOT \("approved_ot_minutes" IS NULL\)/);
  assert.match(query.sql,/LIMIT 1000 OFFSET 1000/);
});
test('all user values remain parameters, including SQL-looking text',()=>{
  const raw="x'); DROP TABLE employees; --";
  const query=compile('GET',new URLSearchParams({employee_id:'eq.'+raw}).toString());
  assert.equal(query.values[0],raw);assert.ok(!query.sql.includes(raw));
});
test('identifiers and operators cannot inject SQL',()=>{
  for(const search of ['unknown=eq.value','employee_id=execute.value','order=employee_id;DROP TABLE employees','limit=1;SELECT 1']) assert.throws(()=>compile('GET',search));
  assert.throws(()=>compileTableQuery({table:'app_user',method:'GET',params:new URLSearchParams(),columns}));
});
test('upserts use conflict keys and serialize JSON fields',()=>{
  const query=compile('POST','on_conflict=id',[{id:'one',details:{a:1}},{id:'two',details:{a:2}}],'resolution=merge-duplicates');
  assert.match(query.sql,/ON CONFLICT \("id"\) DO UPDATE/);
  assert.deepEqual(query.values,['one','{"a":1}','two','{"a":2}']);
});
test('unfiltered updates and deletes are rejected',()=>{
  assert.throws(()=>compile('PATCH','',{status:'absent'}));assert.throws(()=>compile('DELETE'));
});
test('a failed request rolls back and releases the connection',async()=>{
  const calls=[];const client={async query(sql){calls.push(sql);},release(){calls.push('release');}};
  await assert.rejects(withDatabaseIdentity({connect:async()=>client},{sub:'employee'},async()=>{throw new Error('write rejected');}));
  assert.deepEqual(calls,['BEGIN',"SELECT set_config('request.jwt.claims', $1, true)",'SET LOCAL ROLE authenticated','ROLLBACK','release']);
});
test('successful identity scopes end at commit before releasing a pooled connection',async()=>{
  const calls=[];const client={async query(sql){calls.push(sql);},release(){calls.push('release');}};
  assert.equal(await withDatabaseIdentity({connect:async()=>client},{sub:'employee'},async()=>42),42);
  assert.deepEqual(calls.slice(-2),['COMMIT','release']);
});

test('payroll can include unpaid statuses without submission or unpaid flags',()=>{
  const query=compile('GET',new URLSearchParams({
    or:'(is_submitted.eq.true,status.in.(UL-UNPAID,UL,UNPAID,UNPAID LEAVE))',
  }).toString());
  assert.deepEqual(query.values,['true','UL-UNPAID','UL','UNPAID','UNPAID LEAVE']);
  assert.match(query.sql,/ OR /);
  assert.match(query.sql,/"status" IN/);
});
