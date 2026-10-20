import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiCorsOptions } from '../src/api-cors.js';

test('browser preflights allow PostgREST table reads, payroll upserts, edits and RPCs',async()=>{
  const {default:express}=await import('express');
  const {default:cors}=await import('cors');
  const app=express();
  app.use(cors(createApiCorsOptions(['https://hasanihub.onrender.com'],{log:{warn(){}}})));
  app.get('/api/data/payroll',(_req,res)=>res.status(401).json({message:'Authentication required'}));
  app.use((error,_req,res,_next)=>res.status(403).json({message:error.message}));
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const base=`http://127.0.0.1:${server.address().port}`;
  try {
    for(const method of ['GET','POST','PATCH','DELETE','HEAD']) {
      const requested=['authorization','content-type','x-client-info','prefer','accept-profile','content-profile','range','range-unit'];
      const response=await fetch(base+'/api/data/payroll',{method:'OPTIONS',headers:{
        Origin:'https://hasanihub.onrender.com','Access-Control-Request-Method':method,
        'Access-Control-Request-Headers':requested.join(','),
      }});
      assert.equal(response.status,200);
      assert.equal(response.headers.get('access-control-allow-origin'),'https://hasanihub.onrender.com');
      const allowed=response.headers.get('access-control-allow-headers').toLowerCase().split(',').map(x=>x.trim());
      assert.ok(requested.every(header=>allowed.includes(header)),`${method} browser preflight must allow every SDK header`);
      assert.ok(response.headers.get('access-control-allow-methods').split(',').includes(method));
    }
    const unauthorized=await fetch(base+'/api/data/payroll',{headers:{Origin:'https://hasanihub.onrender.com'}});
    assert.equal(unauthorized.status,401); // CORS never bypasses authentication.
    const blocked=await fetch(base+'/api/data/payroll',{method:'OPTIONS',headers:{
      Origin:'https://unlisted.example','Access-Control-Request-Method':'POST',
    }});
    assert.equal(blocked.status,403);
    assert.equal(blocked.headers.get('access-control-allow-origin'),null);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
