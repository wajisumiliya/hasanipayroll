import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import express from 'express';
import {createReadResponseCache} from '../src/read-response-cache.js';

async function fixture(t,options={}) {
  let clock=0,reads=0,version=0,fail=false,hold=null;
  const cache=createReadResponseCache({...options,now:()=>clock});
  const app=express();app.use(cache.writeInvalidation);
  app.get('/read',(req,res,next)=>{
    if(req.get('role')!=='ADMIN')return res.sendStatus(403);
    req.user={role:'ADMIN',id:req.get('identity')??'one'};next();
  },cache.middleware,async(req,res)=>{
    reads++;const current=version;
    if(hold)await hold;
    if(fail)return res.status(503).json({ok:false});
    res.json({version:current,payload:'x'.repeat(100)});
  });
  app.post('/save',(req,res)=>{version++;res.json({ok:true});});
  const server=app.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(()=>{server.closeAllConnections();server.close();});
  const base=`http://127.0.0.1:${server.address().port}`;
  return {cache,get reads(){return reads;},setClock(v){clock=v;},setFail(v){fail=v;},setHold(v){hold=v;},
    async read(query='',headers={}){const res=await fetch(base+'/read'+query,{headers:{role:'ADMIN',...headers}});return {status:res.status,body:await res.text()};},
    async save(){await fetch(base+'/save',{method:'POST'});}};
}
test('identical authorized reads share cached response until TTL expires',async t=>{
  const f=await fixture(t);const a=await f.read();assert.deepEqual(await f.read(),a);assert.equal(f.reads,1);
  f.setClock(30_001);await f.read();assert.equal(f.reads,2);
});
test('identity, query and authorization checks are preserved on cache hits',async t=>{
  const f=await fixture(t);await f.read('?month=10');await f.read('?month=11');
  await f.read('?month=10',{identity:'two'});assert.equal(f.reads,3);
  assert.equal((await f.read('?month=10',{role:'BRANCH'})).status,403);assert.equal(f.reads,3);
});
test('concurrent requests coalesce into one read',async t=>{
  const f=await fixture(t);let release;f.setHold(new Promise(done=>{release=done;}));
  const requests=[f.read(),f.read(),f.read()];
  // Wait until the first request reaches the held loader.
  while(f.reads===0)await new Promise(done=>setImmediate(done));
  release();await Promise.all(requests);assert.equal(f.reads,1);
});
test('successful write clears cached models immediately',async t=>{
  const f=await fixture(t);await f.read();await f.save();
  assert.equal(JSON.parse((await f.read()).body).version,1);assert.equal(f.reads,2);
});
test('read started before a write cannot repopulate stale cache',async t=>{
  const f=await fixture(t);let release;f.setHold(new Promise(done=>{release=done;}));
  const old=f.read();while(f.reads===0)await new Promise(done=>setImmediate(done));
  await f.save();release();await old;f.setHold(null);
  assert.equal(JSON.parse((await f.read()).body).version,1);assert.equal(f.reads,2);
});
test('failed reads are not cached',async t=>{
  const f=await fixture(t);f.setFail(true);assert.equal((await f.read()).status,503);
  f.setFail(false);assert.equal((await f.read()).status,200);assert.equal(f.reads,2);
});
test('entry count and response size limits keep caching bounded',async t=>{
  const f=await fixture(t,{maxEntries:1});await f.read('?a=1');await f.read('?a=2');await f.read('?a=1');assert.equal(f.reads,3);
  const large=await fixture(t,{maxBytes:20});await large.read();await large.read();assert.equal(large.reads,2);
});
