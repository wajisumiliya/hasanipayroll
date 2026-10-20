import assert from 'node:assert/strict';
import test from 'node:test';
import { presignEmployeePhoto } from '../src/r2-employee-photos.js';

test('R2 signatures are scoped by object, method, content type and expiration',()=>{
  const fixture={R2_ACCOUNT_ID:'0123456789abcdef0123456789abcdef',R2_BUCKET:'fixture-photos',R2_ACCESS_KEY_ID:'fixture-key',R2_SECRET_ACCESS_KEY:'fixture-secret'};
  const previous=Object.fromEntries(Object.keys(fixture).map(key=>[key,process.env[key]]));
  Object.assign(process.env,fixture);
  try {
    const signatures=new Set();
    for(const method of ['GET','PUT','DELETE']) {
      const signed=presignEmployeePhoto({employeeId:'FIX_E1',method,contentType:'image/jpeg'});
      const url=new URL(signed.url);
      assert.equal(url.pathname,'/fixture-photos/employee-photos/FIX_E1/profile');
      assert.equal(url.searchParams.get('X-Amz-Expires'),'300');
      assert.equal(url.searchParams.get('X-Amz-SignedHeaders'),method==='PUT'?'content-type;host':'host');
      assert.equal(signed.objectKey,'employee-photos/FIX_E1/profile');
      assert.ok(!signed.url.includes('fixture-secret'));
      signatures.add(url.searchParams.get('X-Amz-Signature'));
    }
    assert.equal(signatures.size,3);
    assert.throws(()=>presignEmployeePhoto({employeeId:'../other',method:'GET'}));
    assert.throws(()=>presignEmployeePhoto({employeeId:'FIX_E1',method:'PUT',contentType:'text/html'}));
  } finally {
    for(const [key,value] of Object.entries(previous)) {
      if(value===undefined) delete process.env[key]; else process.env[key]=value;
    }
  }
});
