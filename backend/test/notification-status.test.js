import test from 'node:test';
import assert from 'node:assert/strict';
import {firebaseConfigurationStatus} from '../src/notification-status.js';
import {installNotificationApi} from '../src/notification-api.js';

test('configuration diagnostics distinguish missing, invalid and wrong-project credentials without secrets',()=>{
  assert.equal(firebaseConfigurationStatus({}).status,'not_configured');
  for(const raw of ['{broken','{}','null']) assert.equal(firebaseConfigurationStatus({FIREBASE_SERVICE_ACCOUNT_JSON:raw}).status,'invalid_configuration');
  const account={project_id:'hasani-payroll',client_email:'private-account@example.test',private_key:'DO_NOT_RETURN_PRIVATE_KEY'};
  for(const raw of [JSON.stringify(account),JSON.stringify(JSON.stringify(account))]){
    const result=firebaseConfigurationStatus({FIREBASE_SERVICE_ACCOUNT_JSON:raw});
    assert.deepEqual(result,{status:'configured'});
    assert.ok(!JSON.stringify(result).includes('PRIVATE_KEY'));
    assert.ok(!JSON.stringify(result).includes(account.client_email));
  }
  assert.equal(firebaseConfigurationStatus({FIREBASE_SERVICE_ACCOUNT:JSON.stringify({...account,project_id:'wrong-project'})}).status,'project_mismatch');
});

function setup(){
  let handler;const queries=[];
  installNotificationApi({get(path,auth,fn){assert.equal(path,'/api/notifications/status');handler=fn;},post(){}},
    {authenticate:()=>{},env:{},pool:{async query(sql,values){
      queries.push({sql,values});
      if(sql.includes('FROM public.employees'))return {rows:[{employee_id:'HED2073'}]};
      if(sql.includes('GROUP BY platform'))return {rows:[{platform:'android',count:1}]};
      if(sql.includes('FROM public.payroll p'))return {rows:[{payroll_month:'2026-10',is_published:true,available:true,inbox_saved:false,push_queued:false}]};
      if(sql.includes('pg_trigger'))return {rows:[{ready:true}]};
      return {rows:[{payroll_month:'2026-10',last_status:'failed',last_error_codes:['SENDER_ID_MISMATCH'],attempts:1}]};
    }}});
  return {queries,async run(user={role:'admin'},auth={},employee_id='HED2073'){
    const res={code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}};
    await handler({user,auth,query:{employee_id}},res);return res;
  }};
}
test('only full administrators may inspect delivery status',async()=>{
  for(const [user,auth]of [[{role:'employee'},{}],[{role:'branch'},{}],[{role:'admin'},{app_metadata:{is_reviewer:true}}],
    [{role:'admin'},{app_metadata:{staff_scope:'attendance'}}],[{role:'admin'},{app_metadata:{staff_scope:'requests'}}]]){
    const api=setup();assert.equal((await api.run(user,auth)).code,403);assert.equal(api.queries.length,0);
  }
});
test('status exposes useful publication and device metadata without tokens or salary',async()=>{
  const api=setup();const res=await api.run();
  assert.equal(res.code,200);assert.equal(res.body.devices.android,1);assert.equal(res.body.devices.total,1);
  assert.equal(res.body.publication_notifications_ready,true);
  assert.equal(res.body.payroll[0].inbox_saved,false);
  assert.deepEqual(res.body.recent[0].last_error_codes,['SENDER_ID_MISMATCH']);
  assert.ok(api.queries.every(q=>! /\b(INSERT|UPDATE|DELETE)\b/i.test(q.sql)));
  assert.ok(api.queries.every(q=>! /\btoken\b|basic_salary|net_pay/.test(q.sql)));
});
test('missing employee selection is rejected before database access',async()=>{
  const api=setup();assert.equal((await api.run(undefined,{},'')).code,400);assert.equal(api.queries.length,0);
});
