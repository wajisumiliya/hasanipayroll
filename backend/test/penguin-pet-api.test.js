import test from 'node:test';
import assert from 'node:assert/strict';
import { installPenguinPetApi } from '../src/penguin-pet-api.js';

test('penguin endpoints require authentication middleware', () => {
 const routes=[];
 const app={get:(...args)=>routes.push(args),post:(...args)=>routes.push(args)};
 const auth=(_req,_res,next)=>next();
 installPenguinPetApi(app,{pool:{},authenticate:auth});
 assert.deepEqual(routes.map(x=>x[0]),[
  '/api/employee/penguin',
  '/api/employee/penguin/feed',
  '/api/employee/penguin/play',
 ]);
 assert.ok(routes.every(x=>x[1]===auth));
});
test('unauthorized role cannot access penguin or database', async()=>{
 const routes=[];
 const app={get:(...args)=>routes.push(args),post:(...args)=>routes.push(args)};
 installPenguinPetApi(app,{pool:{connect:()=>{throw Error('database should not be called')}},authenticate:(_r,_s,next)=>next()});
 for(const route of routes){
  let status,body;
  const res={status(code){status=code;return this},json(value){body=value;return this}};
  await route[2]({user:{role:'ADMIN',employeeId:'E001'}},res);
  assert.equal(status,403);
  assert.equal(body.ok,false);
 }
});
