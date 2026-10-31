import test from 'node:test';
import assert from 'node:assert/strict';
import {employeeLeaveView} from '../src/employee-leave-balances.js';
import {installDataApi} from '../src/data-api.js';

test('employee payload keeps AL but removes MC outside admin without mutating source',()=>{
 const original={employee_id:'E1',annual_leave_balance:10.5,medical_leave_balance:14};
 for(const role of ['EMPLOYEE','BRANCH']) {
   const view=employeeLeaveView(original,role);
   assert.equal(view.annual_leave_balance,10.5);assert.equal('medical_leave_balance' in view,false);
 }
 assert.equal(employeeLeaveView(original,'ADMIN').medical_leave_balance,14);
 assert.equal(original.medical_leave_balance,14);assert.equal(employeeLeaveView(null,'EMPLOYEE'),null);
});
test('generic employee reads omit MC and employee balance writes are rejected',async()=>{
 let handler,sql='';
 const client={query:async statement=>{sql=statement;return {rows:[]};},release(){}};
 const pool={query:async statement=>({rows:statement.includes('information_schema')?
   [{column_name:'employee_id',udt_name:'text'},{column_name:'annual_leave_balance',udt_name:'numeric'},{column_name:'medical_leave_balance',udt_name:'numeric'}]:[{attname:'employee_id'}]}),connect:async()=>client};
 installDataApi({post(){},all(path,auth,fn){handler=fn;}},{pool,authenticate(){}});
 const response=()=>({code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;},set(){},end(){}});
 let selected='';client.query=async statement=>{if(statement.startsWith('SELECT')&&statement.includes('employees'))selected=statement;return {rows:[]};};
 const base={params:{table:'employees'},user:{role:'EMPLOYEE',username:'E1',employeeId:'E1'},get:()=>'',auth:{app_metadata:{}}};
 const res=response();await handler({...base,method:'GET',originalUrl:'/api/data/employees?select=*'},res);
 assert.match(selected,/annual_leave_balance/);assert.doesNotMatch(selected,/medical_leave_balance/);
 const denied=response();await handler({...base,method:'PATCH',originalUrl:'/api/data/employees?employee_id=eq.E1',body:{annual_leave_balance:100}},denied);
 assert.equal(denied.code,400);
});
