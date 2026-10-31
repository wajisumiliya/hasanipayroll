import test from 'node:test';
import assert from 'node:assert/strict';
import {installEmployeeEditorApi} from '../src/employee-editor.js';
function response(){return {code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}};}
function route(pool) {let handler;installEmployeeEditorApi({get:(path,auth,fn)=>{handler=fn;}},{authenticate:()=>{},pool});return handler;}
test('edit data is one joined query with full existing defaults and no writes',async()=>{
 let calls=0;
 const handler=route({query:async(sql,params)=>{
   calls++;assert.match(sql,/LEFT JOIN public.employee_salary_defaults/);assert.doesNotMatch(sql,/information_schema|INSERT|UPDATE/);
   assert.deepEqual(params,['E1']);return {rows:[{employee:{employee_id:'E1',name:'Employee'},salary_defaults:{basic_salary:2500,epf_enabled:false}}]};
 }});
 const res=response();await handler({user:{role:'ADMIN'},params:{employeeId:' e1 '}},res);
 assert.equal(calls,1);assert.equal(res.body.salary_defaults.basic_salary,2500);assert.equal(res.body.salary_defaults.epf_enabled,false);
});
test('denies non-admin, reviewer and restricted scopes without querying',async()=>{
 const handler=route({query:async()=>{throw Error('Must not query');}});
 for(const req of [{user:{role:'EMPLOYEE'}},{user:{role:'BRANCH'}},{user:{role:'ADMIN'},auth:{app_metadata:{is_reviewer:true}}},
   {user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'attendance'}}},{user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'requests'}}}]) {
   const res=response();await handler({...req,params:{employeeId:'E1'}},res);assert.equal(res.code,403);
 }
});
test('validates IDs, handles missing defaults, and enforces local/foreign scope',async()=>{
 const handler=route({query:async()=>({rows:[{employee:{employee_id:'E1',address:'FRN'},salary_defaults:null}]})});
 const bad=response();await handler({user:{role:'ADMIN'},params:{employeeId:"' OR 1=1"}},bad);assert.equal(bad.code,400);
 const denied=response();await handler({user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'local'}},params:{employeeId:'E1'}},denied);assert.equal(denied.code,403);
 const ok=response();await handler({user:{role:'ADMIN'},auth:{app_metadata:{staff_scope:'foreign'}},params:{employeeId:'E1'}},ok);assert.deepEqual(ok.body.salary_defaults,{});
});
