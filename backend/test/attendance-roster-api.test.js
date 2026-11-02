import test from 'node:test';
import assert from 'node:assert/strict';
import {installAttendanceRosterApi} from '../src/attendance-roster-api.js';
function api(submitted=true){let handler;const calls=[];
 const client={async query(sql,params){calls.push({sql,params});if(sql.includes('FROM public.employees'))return {rows:[{branch_id:'A'}]};if(sql.includes('FROM public.attendance'))return {rows:[{is_submitted:submitted}]};return {rows:[]};},release(){}};
 installAttendanceRosterApi({post(path,auth,fn){assert.equal(path,'/api/attendance-sheet/rosters');handler=fn;}},{authenticate(){},pool:{async connect(){return client;}}});
 return {calls,async run(user,auth={}){const res={code:200,status(n){this.code=n;return this;},json(b){this.body=b;return this;}};
 await handler({user,auth,body:{rosters:[{employee_id:'E1',branch_id:'CLIENT',roster_date:'2026-10-01',assignment_type:'SHIFT',shift_start:'10:00',shift_end:'19:00',break_minutes:60}]}},res);return res;}};
}
test('admin and account can correct a submitted daily roster without rewriting attendance',async()=>{
 for(const app_metadata of [{},{staff_scope:'attendance'}]){
  const a=api();assert.equal((await a.run({role:'ADMIN'},{app_metadata})).code,200);
  const write=a.calls.find(q=>q.sql.startsWith('INSERT INTO public.daily_rosters'));assert.ok(write);assert.equal(write.params[0],'A');
  assert.ok(a.calls.every(q=>! /(?:UPDATE|INSERT INTO|DELETE FROM) public\.attendance/.test(q.sql)));
 }
});
test('branch cannot edit submitted roster, but can save its unsubmitted roster',async()=>{
 const locked=api();assert.equal((await locked.run({role:'BRANCH',branchId:'A'})).code,403);assert.ok(!locked.calls.some(q=>q.sql.startsWith('INSERT')));
 assert.equal((await api(false).run({role:'BRANCH',branchId:'A'})).code,200);
 assert.equal((await api(false).run({role:'BRANCH',branchId:'B'})).code,403);
});
test('employee, reviewer and request-only users cannot correct rosters',async()=>{
 for(const [user,auth] of [[{role:'EMPLOYEE'},{}],[{role:'ADMIN'},{app_metadata:{is_reviewer:true}}],[{role:'ADMIN'},{app_metadata:{staff_scope:'requests'}}]]){
  const a=api();assert.equal((await a.run(user,auth)).code,403);assert.equal(a.calls.length,0);
 }
});
